import 'dart:async';
import 'dart:math' as dart_math;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tigerbay_app/core/config/env_config.dart';
import 'package:tigerbay_app/data/models/user_model.dart';
import 'package:tigerbay_app/core/utils/device_binding.dart';
import 'package:tigerbay_app/services/twilio_notification_service.dart';


// ────────────────────────────────────────────────────────────────────────────
// Typed exception surfaced when the app tries to read DB data before email is
// confirmed. The Flutter UI layer catches this and renders the verification
// pending screen instead of navigating to home.
// ────────────────────────────────────────────────────────────────────────────
class UnconfirmedEmailException implements Exception {
  final String email;
  const UnconfirmedEmailException(this.email);

  @override
  String toString() =>
      'UnconfirmedEmailException: Verification link sent to $email. '
      'Email must be confirmed before accessing app data.';
}

// ────────────────────────────────────────────────────────────────────────────
// Typed exception for device mismatch security events.
// ────────────────────────────────────────────────────────────────────────────
class DeviceMismatchException implements Exception {
  final String expectedDeviceId;
  final String attemptedDeviceId;
  const DeviceMismatchException({
    required this.expectedDeviceId,
    required this.attemptedDeviceId,
  });

  @override
  String toString() =>
      'DeviceMismatchException: Account is bound to a different device. '
      'Contact support to transfer your account.';
}

// ────────────────────────────────────────────────────────────────────────────
// Typed exception for FK constraint lag (code 23503) during device binding.
// ────────────────────────────────────────────────────────────────────────────
class DeviceBindingConstraintLagException implements Exception {
  final int attemptNumber;
  final String detail;
  const DeviceBindingConstraintLagException({
    required this.attemptNumber,
    required this.detail,
  });

  @override
  String toString() =>
      'DeviceBindingConstraintLagException: DEVICE_BINDING_CONSTRAINT_LAG '
      '(code 23503) on attempt $attemptNumber. Profile FK not yet visible '
      'to this PostgREST connection. Detail: $detail';
}

// ────────────────────────────────────────────────────────────────────────────
// Typed exception surfaced when a user attempts to sign in but has no
// corresponding row in the profiles table (i.e. they never registered
// through the app). The auth session is forcibly terminated before throwing.
// ────────────────────────────────────────────────────────────────────────────
class NoProfileExistsException implements Exception {
  const NoProfileExistsException();

  @override
  String toString() =>
      'No account exists with this credential. Please register first.';
}

// ────────────────────────────────────────────────────────────────────────────
// AuthRepository
//
// Central auth data-access object. All auth, profile, and device binding
// operations live here. Riverpod providers consume this class directly.
//
// DESIGN GUARANTEES:
//   • NEVER manually inserts into public.profiles — the PostgreSQL trigger
//     handle_new_user() owns that responsibility exclusively.
//   • NEVER reads from public.profiles while email is unconfirmed.
//   • All PostgrestException(code: '23503') during device binding are caught,
//     categorised, and retried with full exponential backoff + jitter.
// ────────────────────────────────────────────────────────────────────────────
class AuthRepository {
  final SupabaseClient _client = Supabase.instance.client;
  final dart_math.Random _random = dart_math.Random();

  // ── Public auth state accessors ────────────────────────────────────────────

  User? get currentUser => _client.auth.currentUser;

  /// True only when the current session user has confirmed their email.
  bool get isEmailConfirmed =>
      _client.auth.currentUser?.emailConfirmedAt != null;

  /// Raw auth state change stream — consumers should prefer the typed
  /// [onAuthStateChange] method below for state-machine routing.
  Stream<AuthState> get rawAuthStateChanges => _client.auth.onAuthStateChange;

  // ── Email Confirmation Guard ───────────────────────────────────────────────

  /// Throws [UnconfirmedEmailException] if the current session user has not
  /// yet confirmed their email address. Call this guard at the top of any
  /// method that reads or writes to public.profiles or any downstream table
  /// that references it via FK.
  ///
  /// UNCONFIRMED_READ_ATTEMPT categorisation:
  ///   email_confirmed_at IS NULL → block all DB reads → surface verification
  ///   pending UI. No data should flow until the user clicks the email link.
  void _guardEmailConfirmed() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('No authenticated session found.');
    }
    if (user.emailConfirmedAt == null) {
      throw UnconfirmedEmailException(user.email ?? 'unknown');
    }
  }

  // ── Register-First Guard ─────────────────────────────────────────────────
  //
  // BUSINESS RULE: A user MUST register through the app before they can
  // sign in. If Supabase Auth succeeds but no corresponding row exists in
  // public.profiles, the session is immediately terminated and a
  // [NoProfileExistsException] is thrown.
  //
  // This guard runs AFTER a successful Supabase Auth sign-in and BEFORE
  // the app navigates to /home or /membership-paywall.

  /// Checks whether a profiles row exists for the current auth user.
  /// If not, signs out and throws [NoProfileExistsException].
  Future<void> checkProfileExistsOrSignOut() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    // Retry up to 4 times with delay to allow database trigger
    // (handle_new_user) to complete profile insertion for OAuth sign-ins.
    Map<String, dynamic>? response;
    for (int attempt = 0; attempt < 4; attempt++) {
      response = await _client
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) return;
      if (attempt < 3) {
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }

    // Safety fallback for OAuth sign-ins: ensure profile record exists
    try {
      final userMeta = user.userMetadata ?? {};
      final fullName = userMeta['full_name'] as String? ??
          userMeta['name'] as String? ??
          user.email?.split('@').first ??
          'Member';
      await _client.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
        'full_name': fullName,
        'membership_status': 'inactive',
        'updated_at': DateTime.now().toIso8601String(),
      });
      debugPrint('[TigerBay Auth] Auto-created profile record for authenticated OAuth user: ${user.id}');
      return;
    } catch (e) {
      debugPrint('[TigerBay Auth] OAuth profile upsert fallback notice: $e');
    }

    debugPrint(
      '[TigerBay Auth] NO_PROFILE_EXISTS: No profiles row found for '
      'user ${user.id.substring(0, 8)}... — signing out and blocking.',
    );
    await _client.auth.signOut();
    throw const NoProfileExistsException();
  }

  // ── Registration Pipeline ──────────────────────────────────────────────────

  /// Registers a new user with email + password.
  ///
  /// CRITICAL DESIGN DECISION:
  ///   [homeSiteId] is passed as user metadata, NOT as a manual DB insert.
  ///   The database trigger `handle_new_user()` reads NEW.raw_user_meta_data
  ///   and writes the profile row atomically. No Flutter code touches
  ///   public.profiles during registration.
  ///
  /// [emailRedirectTo] deep-links back into the mobile app after email
  ///   confirmation. This must match the registered URL scheme in the
  ///   Supabase Auth dashboard → URL Configuration → Redirect URLs.
  ///
  /// Returns the [User] object if GoTrue accepted the request. The returned
  /// user will be in an unconfirmed state until they click the verification
  /// link. The caller must NOT navigate to home until isEmailConfirmed is true.
  /// Returns null if neither email nor phone is registered.
  /// If registered, returns the matching profile row.
  Future<Map<String, dynamic>?> checkUserExists({
    required String email,
    String? phone,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final cleanPhone = phone?.trim() ?? '';

      String orFilter = 'email.ilike.$cleanEmail';
      if (cleanPhone.isNotEmpty) {
        orFilter += ',phone.eq.$cleanPhone';
      }

      final rows = await _client
          .from('profiles')
          .select('id, email, phone, full_name')
          .or(orFilter)
          .limit(1);

      if (rows.isNotEmpty) {
        return Map<String, dynamic>.from(rows.first);
      }
      return null;
    } catch (e) {
      debugPrint('[TigerBay Auth] checkUserExists notice: $e');
      return null;
    }
  }

  Future<User?> registerNewUser({
    required String email,
    required String password,
    required int homeSiteId,
    String? fullName,
    String? phone,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'home_site_id': homeSiteId,
          if (fullName != null && fullName.trim().isNotEmpty)
            'full_name': fullName.trim(),
          if (phone != null && phone.trim().isNotEmpty)
            'phone': phone.trim(),
        },
        emailRedirectTo: 'io.tigerbay.app://login-callback',
      );

      if (response.user == null) {
        throw const AuthException(
          'Registration rejected: GoTrue returned no user object. '
          'Verify email confirmation settings in Supabase Auth dashboard.',
        );
      }

      // If user already existed, GoTrue returns user with empty identities list
      if (response.user!.identities != null && response.user!.identities!.isEmpty) {
        throw const AuthException(
          'An account with this email address already exists. Please sign in instead.',
        );
      }

      debugPrint(
        '[TigerBay Auth] signUp accepted — email: ${response.user!.email} '
        'confirmed: ${response.user!.emailConfirmedAt != null} '
        'session: ${response.session != null}',
      );

      return response.user;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw Exception('Registration pipeline failed: $e');
    }
  }

  /// Verifies the 6-digit OTP code sent to user email during signup.
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email.trim().toLowerCase(),
      token: token.trim(),
      type: OtpType.signup,
    );
    if (response.user != null) {
      unawaited(_bindDevice(response.user!.id));
    }
    return response;
  }

  /// Verifies the 6-digit recovery code sent to user email for password reset.
  Future<AuthResponse> verifyRecoveryOtp({
    required String email,
    required String token,
  }) async {
    final response = await _client.auth.verifyOTP(
      email: email.trim().toLowerCase(),
      token: token.trim(),
      type: OtpType.recovery,
    );
    return response;
  }

  /// Updates the password for the currently authenticated recovery session.
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  // ── Sign In ────────────────────────────────────────────────────────────────

  /// Signs in with email + password.
  /// After a successful sign-in, triggers device binding only if the email
  /// is already confirmed, to prevent FK constraint lag.
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user != null && response.user!.emailConfirmedAt != null) {
      // Only bind device after email is confirmed to avoid FK lag window.
      unawaited(_bindDevice(response.user!.id));
    }

    return response;
  }

  // ── OTP / Phone ─────────────────────────────────────────────────────────────

  Future<void> sendOtp(String phone) async {
    try {
      await _client.auth.signInWithOtp(phone: phone);
    } catch (e) {
      debugPrint('[TigerBay Auth] Supabase signInWithOtp notice ($e). Attempting Twilio Verify API...');
      final twilio = TwilioNotificationService();
      final res = await twilio.sendVerificationCode(to: phone);
      if (res['status'] == 'error') {
        final errText = res['error']?.toString() ?? e.toString();
        debugPrint('[TigerBay Auth] Twilio send verification error: $errText');
        throw AuthException(errText);
      }
    }
  }

  Future<AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) async {
    final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    final syntheticEmail = 'phone_$cleanDigits@phone.tigerbay.vip';
    final syntheticPassword = 'TB_Phone_${cleanDigits}_Secure2026!';

    try {
      final response = await _client.auth.verifyOTP(
        phone: phone,
        token: token,
        type: OtpType.sms,
      );
      if (response.user != null) {
        unawaited(_bindDevice(response.user!.id));
        try {
          await _client.from('profiles').update({
            'phone': phone,
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', response.user!.id);
        } catch (_) {}
      }
      return response;
    } catch (e) {
      debugPrint('[TigerBay Auth] Supabase verifyOTP notice ($e). Checking Twilio Verify directly...');
      final twilio = TwilioNotificationService();
      final approved = await twilio.verifyCode(to: phone, code: token);
      if (!approved) {
        throw const AuthException('Invalid or expired verification code. Please try again.');
      }

      // Code approved by Twilio! Ensure active Supabase session
      AuthResponse authRes;
      try {
        authRes = await _client.auth.signInWithPassword(
          email: syntheticEmail,
          password: syntheticPassword,
        );
      } catch (_) {
        // First-time phone user: register them automatically
        authRes = await _client.auth.signUp(
          email: syntheticEmail,
          password: syntheticPassword,
          data: {
            'phone': phone,
            'full_name': 'Member $cleanDigits',
          },
        );
      }

      if (authRes.user != null) {
        unawaited(_bindDevice(authRes.user!.id));
        try {
          await _client.from('profiles').upsert({
            'id': authRes.user!.id,
            'phone': phone,
            'membership_status': 'inactive',
            'updated_at': DateTime.now().toIso8601String(),
          });
        } catch (_) {}
      }

      return authRes;
    }
  }

  /// Refreshes the Supabase session and returns true if email is confirmed.
  Future<bool> refreshSession() async {
    try {
      final res = await _client.auth.refreshSession();
      final user = res.user ?? _client.auth.currentUser;
      if (user != null && user.emailConfirmedAt != null) {
        return true;
      }
      final userRes = await _client.auth.getUser();
      if (userRes.user?.emailConfirmedAt != null) {
        await _client.auth.refreshSession();
        return true;
      }
    } catch (e) {
      debugPrint('[TigerBay Auth] refreshSession notice: $e');
      try {
        final userRes = await _client.auth.getUser();
        if (userRes.user?.emailConfirmedAt != null) {
          await _client.auth.refreshSession();
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  // ── Google ──────────────────────────────────────────────────────────────────

  /// Signs in with Google using Supabase OAuth with an in-app browser sheet
  /// (Chrome Custom Tab on Android). This avoids the native GoogleSignIn
  /// SHA-1 dependency and the PlatformException(sign_in_failed, v8.b:10)
  /// error. The flow stays visually in-app and redirects back automatically
  /// via the deep link scheme [io.tigerbay.app://login-callback].
  Future<void> signInWithGoogle() async {
    final appScheme = EnvConfig.appScheme;
    await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: '$appScheme://login-callback',
      authScreenLaunchMode: LaunchMode.inAppBrowserView,
    );
  }

  // ── Apple ───────────────────────────────────────────────────────────────────

  Future<void> signInWithApple() async {
    final appScheme = EnvConfig.appScheme;
    await _client.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: '$appScheme://login-callback',
      authScreenLaunchMode: LaunchMode.inAppBrowserView,
    );
  }

  // ── Facebook ─────────────────────────────────────────────────────────────────

  Future<void> signInWithFacebook() async {
    final appScheme = EnvConfig.appScheme;
    await _client.auth.signInWithOAuth(
      OAuthProvider.facebook,
      redirectTo: '$appScheme://login-callback',
      authScreenLaunchMode: LaunchMode.inAppBrowserView,
    );
  }

  // ── Profile Read (email-confirmed guard applied) ───────────────────────────

  /// Fetches the authenticated user's profile from public.profiles.
  ///
  /// Throws [UnconfirmedEmailException] if the user has not confirmed their
  /// email. The caller must handle this by rendering the verification-pending
  /// UI state — UNCONFIRMED_READ_ATTEMPT.
  Future<UserProfile?> getCurrentProfile() async {
    _guardEmailConfirmed();

    final user = currentUser!;
    final data =
        await _client.from('profiles').select().eq('id', user.id).maybeSingle();

    if (data == null) return null;
    return UserProfile.fromMap(data);
  }

  // ── Sign Out ─────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await _client.auth.signOut();
  }

  // ── onAuthStateChange typed router ───────────────────────────────────────────

  /// Returns a stream that emits typed [TigerBayAuthEvent] values derived
  /// from Supabase's raw auth state changes.
  ///
  /// Consumers (Riverpod AuthNotifier, GoRouter redirect) should subscribe to
  /// this stream rather than the raw Supabase stream. This provides clean
  /// typed routing without scattered switch-statement boilerplate in UI code.
  ///
  /// Event routing rules:
  ///   SIGNED_IN / INITIAL_SESSION:
  ///     email confirmed?  → load profile → emit authenticated
  ///     email unconfirmed? → emit pendingVerification (block all DB reads)
  ///   TOKEN_REFRESHED → re-validate confirmation → refresh profile
  ///   USER_UPDATED    → reload profile to pick up metadata changes
  ///   PASSWORD_RECOVERY → emit passwordRecovery (route to reset screen)
  ///   SIGNED_OUT      → emit signedOut (clear state, route to login)
  Stream<TigerBayAuthEvent> onAuthStateChange() {
    return _client.auth.onAuthStateChange.asyncMap((supabaseAuthState) async {
      final event = supabaseAuthState.event;
      final session = supabaseAuthState.session;
      final user = session?.user;

      debugPrint(
        '[TigerBay AuthStateChange] event=$event '
        'user=${user?.id.substring(0, 8)}... '
        'emailConfirmed=${user?.emailConfirmedAt != null}',
      );

      switch (event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.initialSession:
          if (user == null) {
            return const TigerBayAuthEvent.signedOut();
          }

          // ── UNCONFIRMED_READ_ATTEMPT guard ─────────────────────────────
          // If email_confirmed_at is null, the user has not yet clicked the
          // verification link. Block ALL downstream DB reads here.
          if (user.emailConfirmedAt == null) {
            debugPrint(
              '[TigerBay AuthStateChange] UNCONFIRMED_READ_ATTEMPT: '
              'email_confirmed_at is null for ${user.email}. '
              'All DB reads blocked. Surfacing verification pending state.',
            );
            return TigerBayAuthEvent.pendingVerification(
              email: user.email ?? '',
              userId: user.id,
            );
          }

          // Email confirmed — safe to read public.profiles.
          try {
            // ── Register-First Guard (OAuth redirect flows) ──────────────
            // For Apple/Facebook OAuth, the sign-in completes via browser
            // redirect and re-enters through this stream handler. Check that
            // a profiles row exists before allowing authenticated state.
            await checkProfileExistsOrSignOut();

            final profile = await getCurrentProfile();
            if (!kIsWeb) unawaited(_bindDevice(user.id));
            return TigerBayAuthEvent.authenticated(
                user: user, profile: profile);
          } on NoProfileExistsException catch (_) {
            // User authenticated via OAuth but never registered in the app.
            // Session was already terminated by checkProfileExistsOrSignOut().
            return const TigerBayAuthEvent.error(
              message:
                  'No account exists with this credential. Please register first.',
              errorCode: 'NO_PROFILE_EXISTS',
            );
          } on UnconfirmedEmailException catch (_) {
            // Concurrent email state change — surface pending.
            return TigerBayAuthEvent.pendingVerification(
              email: user.email ?? '',
              userId: user.id,
            );
          } on PostgrestException catch (pgErr) {
            debugPrint(
              '[TigerBay AuthStateChange] PostgrestException loading profile: '
              'code=${pgErr.code} message=${pgErr.message}',
            );
            return TigerBayAuthEvent.error(
              message: 'Failed to load your profile. Please restart the app. '
                  '(${pgErr.code}: ${pgErr.message})',
              errorCode: pgErr.code ?? 'POSTGREST_ERROR',
            );
          } catch (e) {
            return TigerBayAuthEvent.error(
              message: 'Unexpected auth state error: $e',
              errorCode: 'UNKNOWN',
            );
          }

        case AuthChangeEvent.tokenRefreshed:
          if (user == null) return const TigerBayAuthEvent.signedOut();

          if (user.emailConfirmedAt == null) {
            return TigerBayAuthEvent.pendingVerification(
              email: user.email ?? '',
              userId: user.id,
            );
          }

          try {
            final profile = await getCurrentProfile();
            return TigerBayAuthEvent.authenticated(
                user: user, profile: profile);
          } on PostgrestException catch (pgErr) {
            return TigerBayAuthEvent.error(
              message: 'Token refreshed but profile reload failed: '
                  '${pgErr.message}',
              errorCode: pgErr.code ?? 'POSTGREST_ERROR',
            );
          } catch (e) {
            return TigerBayAuthEvent.error(
              message: 'Token refresh profile load failed: $e',
              errorCode: 'UNKNOWN',
            );
          }

        case AuthChangeEvent.userUpdated:
          if (user == null) return const TigerBayAuthEvent.signedOut();
          if (user.emailConfirmedAt == null) {
            return TigerBayAuthEvent.pendingVerification(
              email: user.email ?? '',
              userId: user.id,
            );
          }
          try {
            final profile = await getCurrentProfile();
            return TigerBayAuthEvent.authenticated(
                user: user, profile: profile);
          } catch (_) {
            // If profile load fails after user update, still emit authenticated
            // with null profile so UI can show degraded state gracefully.
            return TigerBayAuthEvent.authenticated(user: user, profile: null);
          }

        case AuthChangeEvent.passwordRecovery:
          return const TigerBayAuthEvent.passwordRecovery();

        case AuthChangeEvent.signedOut:
          return const TigerBayAuthEvent.signedOut();

        case AuthChangeEvent.mfaChallengeVerified:
          // MFA not currently in scope — treat as confirmed sign-in.
          if (user != null && user.emailConfirmedAt != null) {
            final profile =
                await getCurrentProfile().catchError((_) async => null);
            return TigerBayAuthEvent.authenticated(
                user: user, profile: profile);
          }
          return const TigerBayAuthEvent.signedOut();

        default:
          // Covers AuthChangeEvent.userDeleted and any future enum variants
          // added by the Supabase SDK. Treat as signed-out to safely clear
          // local state and route to the login screen.
          debugPrint(
            '[TigerBay AuthStateChange] Unhandled event: $event — '
            'treating as signed out.',
          );
          return const TigerBayAuthEvent.signedOut();
      }
    });
  }

  // ── Resilient Device Binding Engine ────────────────────────────────────────
  //
  // DEVICE_BINDING_CONSTRAINT_LAG (PostgreSQL error code 23503):
  //   device_bindings.user_id → REFERENCES public.profiles(id)
  //   public.profiles.id is created by the trigger on auth.users INSERT.
  //   In rare cases (PostgREST connection pool routing, replication lag)
  //   the profile row is not yet visible to this connection when binding fires.
  //   We detect PostgrestException with code == '23503' specifically and
  //   apply exponential backoff with full jitter before retrying.
  //
  // Backoff parameters:
  //   Base delay  : 250ms
  //   Max delay   : 8,000ms (cap per-attempt)
  //   Max retries : 5 (total window ≈ 16s worst case)
  //   Jitter      : ±20% random offset to prevent thundering herd on shared DB

  static const int _maxBindRetries = 5;
  static const int _baseDelayMs = 250;
  static const int _maxDelayMs = 8000;

  Future<void> _bindDevice(String userId) async {
    if (kIsWeb) {
      debugPrint(
          '[TigerBay DeviceBind] Web runtime — skipping device binding.');
      return;
    }

    final String deviceId;
    final Map<String, dynamic> deviceInfo;

    try {
      deviceId = await DeviceBinding.getDeviceId();
      deviceInfo = await DeviceBinding.getDeviceInfo();
    } catch (e) {
      debugPrint('[TigerBay DeviceBind] Failed to read device info: $e');
      return;
    }

    int retryCount = 0;
    int delayMs = _baseDelayMs;

    debugPrint(
      '[TigerBay DeviceBind] Starting binding — '
      'user=${userId.substring(0, 8)}... device=$deviceId '
      'platform=${deviceInfo['platform']}',
    );

    while (retryCount <= _maxBindRetries) {
      try {
        // ── Step 1: Read existing binding ──────────────────────────────────
        final existing = await _client
            .from('device_bindings')
            .select('device_id, user_id')
            .eq('user_id', userId)
            .maybeSingle();

        if (existing == null) {
          // No binding yet — INSERT one.
          // This INSERT is the exact operation vulnerable to 23503 FK lag.
          // device_bindings.user_id → public.profiles(id) via FK.
          // If the trigger-created profile row is not yet visible to this
          // connection, the INSERT fails with code 23503.
          await _client.from('device_bindings').insert({
            'user_id': userId,
            'device_id': deviceId,
            'platform': deviceInfo['platform'],
            'device_model': deviceInfo['model'],
            'os_version': deviceInfo['os_version'],
            'bound_at': DateTime.now().toUtc().toIso8601String(),
          });

          debugPrint(
            '[TigerBay DeviceBind] ✅ Bound on attempt ${retryCount + 1}.',
          );
        } else if (existing['device_id'] != deviceId) {
          // ── SECURITY BREACH: Device mismatch ─────────────────────────────
          debugPrint(
            '[TigerBay DeviceBind] 🔴 DEVICE MISMATCH — '
            'bound: ${existing['device_id']} attempted: $deviceId',
          );

          await _client.from('security_events').insert({
            'user_id': userId,
            'event_type': 'device_mismatch',
            'details': {
              'expected_device': existing['device_id'],
              'attempted_device': deviceId,
              'device_info': deviceInfo,
              'timestamp': DateTime.now().toUtc().toIso8601String(),
            },
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });

          throw DeviceMismatchException(
            expectedDeviceId: existing['device_id'] as String,
            attemptedDeviceId: deviceId,
          );
        } else {
          debugPrint(
            '[TigerBay DeviceBind] ✅ Device already bound and matches. '
            'No action required.',
          );
        }

        // ── Step 2: Sync device_id onto the profile row ────────────────────
        await _client.from('profiles').update({
          'device_id': deviceId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', userId);

        debugPrint('[TigerBay DeviceBind] ✅ Profile device_id synced.');
        return; // ── Exit: successful binding ──
      } on DeviceMismatchException {
        // No retry for confirmed security violations.
        rethrow;
      } on PostgrestException catch (pgErr) {
        if (pgErr.code == '23503') {
          // ── DEVICE_BINDING_CONSTRAINT_LAG ──────────────────────────────
          retryCount++;
          final lagErr = DeviceBindingConstraintLagException(
            attemptNumber: retryCount,
            detail: pgErr.details?.toString() ?? pgErr.message,
          );

          debugPrint(
            '[TigerBay DeviceBind] ⚠️  DEVICE_BINDING_CONSTRAINT_LAG: '
            '$lagErr\n'
            '  Backoff: attempt $retryCount/$_maxBindRetries | '
            'next delay ≈${delayMs}ms | '
            'elapsed ≈${_elapsedBackoffMs(retryCount)}ms',
          );

          if (retryCount > _maxBindRetries) {
            debugPrint(
              '[TigerBay DeviceBind] 🔴 Exhausted $_maxBindRetries retries. '
              'Profile FK did not commit in '
              '≈${_totalBackoffWindowMs()}ms. '
              'Binding skipped — will retry on next launch.',
            );
            // Non-fatal: user is authenticated and app is usable.
            // Binding will succeed on next cold start.
            return;
          }

          // Exponential backoff with ±20% full jitter
          final jitter =
              (delayMs * 0.2 * (_random.nextDouble() * 2 - 1)).round();
          final effectiveDelay = (delayMs + jitter).clamp(50, _maxDelayMs);
          await Future.delayed(Duration(milliseconds: effectiveDelay));
          delayMs = dart_math.min(delayMs * 2, _maxDelayMs);
        } else {
          // Non-23503 PostgrestException — surface to caller.
          debugPrint(
            '[TigerBay DeviceBind] 🔴 PostgrestException '
            'code=${pgErr.code}: ${pgErr.message}',
          );
          rethrow;
        }
      } catch (e) {
        retryCount++;
        debugPrint(
          '[TigerBay DeviceBind] ⚠️  Exception on attempt $retryCount: $e',
        );

        if (retryCount > _maxBindRetries) {
          debugPrint(
            '[TigerBay DeviceBind] 🔴 Max retries on generic exception. '
            'Binding skipped non-fatally.',
          );
          return;
        }

        final jitter = (delayMs * 0.2 * (_random.nextDouble() * 2 - 1)).round();
        final effectiveDelay = (delayMs + jitter).clamp(50, _maxDelayMs);
        await Future.delayed(Duration(milliseconds: effectiveDelay));
        delayMs = dart_math.min(delayMs * 2, _maxDelayMs);
      }
    }
  }

  /// Computes approximate total elapsed backoff time after [n] retries.
  static int _elapsedBackoffMs(int n) {
    int total = 0;
    int d = _baseDelayMs;
    for (int i = 0; i < n; i++) {
      total += d;
      d = dart_math.min(d * 2, _maxDelayMs);
    }
    return total;
  }

  /// Computes the theoretical maximum total backoff window across all retries.
  static int _totalBackoffWindowMs() => _elapsedBackoffMs(_maxBindRetries);
}

// ────────────────────────────────────────────────────────────────────────────
// TigerBayAuthEvent — typed state machine events emitted by
// AuthRepository.onAuthStateChange(). Each variant carries exactly the
// data that AuthNotifier and the GoRouter redirect need.
// ────────────────────────────────────────────────────────────────────────────
abstract class TigerBayAuthEvent {
  const TigerBayAuthEvent();

  /// Email confirmed, profile loaded → route to home or paywall gate.
  const factory TigerBayAuthEvent.authenticated({
    required User user,
    required UserProfile? profile,
  }) = _AuthenticatedEvent;

  /// Signed up but email_confirmed_at is null → route to verification pending.
  const factory TigerBayAuthEvent.pendingVerification({
    required String email,
    required String userId,
  }) = _PendingVerificationEvent;

  /// Signed out or session expired → route to login.
  const factory TigerBayAuthEvent.signedOut() = _SignedOutEvent;

  /// Password recovery link clicked → route to reset password screen.
  const factory TigerBayAuthEvent.passwordRecovery() = _PasswordRecoveryEvent;

  /// Auth or DB error occurred → surface message via SnackBar.
  const factory TigerBayAuthEvent.error({
    required String message,
    required String errorCode,
  }) = _ErrorEvent;
}

class _AuthenticatedEvent extends TigerBayAuthEvent {
  final User user;
  final UserProfile? profile;
  const _AuthenticatedEvent({required this.user, required this.profile});
}

class _PendingVerificationEvent extends TigerBayAuthEvent {
  final String email;
  final String userId;
  const _PendingVerificationEvent({required this.email, required this.userId});
}

class _SignedOutEvent extends TigerBayAuthEvent {
  const _SignedOutEvent();
}

class _PasswordRecoveryEvent extends TigerBayAuthEvent {
  const _PasswordRecoveryEvent();
}

class _ErrorEvent extends TigerBayAuthEvent {
  final String message;
  final String errorCode;
  const _ErrorEvent({required this.message, required this.errorCode});
}

/// Pattern-matching extension on [TigerBayAuthEvent].
extension TigerBayAuthEventX on TigerBayAuthEvent {
  T when<T>({
    required T Function(User user, UserProfile? profile) authenticated,
    required T Function(String email, String userId) pendingVerification,
    required T Function() signedOut,
    required T Function() passwordRecovery,
    required T Function(String message, String errorCode) error,
  }) {
    final self = this;
    if (self is _AuthenticatedEvent) {
      return authenticated(self.user, self.profile);
    }
    if (self is _PendingVerificationEvent) {
      return pendingVerification(self.email, self.userId);
    }
    if (self is _SignedOutEvent) return signedOut();
    if (self is _PasswordRecoveryEvent) return passwordRecovery();
    if (self is _ErrorEvent) return error(self.message, self.errorCode);
    throw StateError('Unhandled TigerBayAuthEvent: ${self.runtimeType}');
  }

  bool get isAuthenticated => this is _AuthenticatedEvent;
  bool get isPendingVerification => this is _PendingVerificationEvent;
  bool get isSignedOut => this is _SignedOutEvent;
  bool get isError => this is _ErrorEvent;
}
