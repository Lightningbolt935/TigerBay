import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/data/models/user_model.dart';
import 'package:tigerbay_app/data/repositories/auth_repository.dart';

// ── Supabase client singleton ──────────────────────────────────────────────

final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

// ── AuthRepository singleton ───────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>(
  (_) => AuthRepository(),
);

// ── AuthStatus enum — drives GoRouter redirect logic ──────────────────────

enum AuthStatus {
  /// Initial state before any auth event has been processed.
  unknown,

  /// User is authenticated and email is confirmed. App is fully accessible.
  authenticated,

  /// User has signed up but email_confirmed_at is still null.
  /// All downstream DB reads must be blocked.
  /// UI must show the verification-pending screen.
  pendingEmailVerification,

  /// No active session. Route to login screen.
  unauthenticated,

  /// Password recovery link was clicked. Route to reset screen.
  passwordRecovery,
}

// ── AuthState ──────────────────────────────────────────────────────────────

class AuthState {
  final AuthStatus status;
  final User? user;
  final UserProfile? profile;
  final bool isLoading;
  final String? error;

  /// Email address stored during the unconfirmed window so the UI can display
  /// "Verification sent to [email]" without reading from the DB.
  final String? pendingEmail;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.profile,
    this.isLoading = false,
    this.error,
    this.pendingEmail,
  });

  /// Whether the user has a confirmed email address.
  bool get isEmailConfirmed => user?.emailConfirmedAt != null;

  /// Convenience — is the user fully authenticated with confirmed email.
  bool get isFullyAuthenticated =>
      status == AuthStatus.authenticated && user != null && isEmailConfirmed;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    UserProfile? profile,
    bool? isLoading,
    String? error,
    String? pendingEmail,
    bool clearUser = false,
    bool clearProfile = false,
    bool clearError = false,
    bool clearPendingEmail = false,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: clearUser ? null : (user ?? this.user),
        profile: clearProfile ? null : (profile ?? this.profile),
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        pendingEmail:
            clearPendingEmail ? null : (pendingEmail ?? this.pendingEmail),
      );
}

// ── AuthNotifier ───────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  StreamSubscription<TigerBayAuthEvent>? _authEventSubscription;

  AuthNotifier(this._repo) : super(const AuthState()) {
    _init();
  }

  // ── Initialization ────────────────────────────────────────────────────────

  void _init() {
    // Seed initial state from the existing session (app cold-start).
    final currentUser = _repo.currentUser;
    if (currentUser != null) {
      if (currentUser.emailConfirmedAt == null) {
        // Existing session but unconfirmed — block DB reads on launch.
        state = state.copyWith(
          status: AuthStatus.pendingEmailVerification,
          user: currentUser,
          pendingEmail: currentUser.email,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: currentUser,
        );
      }
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }

    // Subscribe to the typed auth event stream from the repository.
    _authEventSubscription =
        _repo.onAuthStateChange().listen(_handleAuthEvent, onError: (e) {
      debugPrint('[TigerBay AuthNotifier] Stream error: $e');
      state = state.copyWith(
        error: 'Authentication stream error. Please restart the app.',
        isLoading: false,
      );
    });
  }

  // ── Auth event handler ────────────────────────────────────────────────────

  void _handleAuthEvent(TigerBayAuthEvent event) {
    event.when(
      authenticated: (user, profile) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          profile: profile,
          isLoading: false,
          clearError: true,
          clearPendingEmail: true,
        );
      },
      pendingVerification: (email, userId) {
        // UNCONFIRMED_READ_ATTEMPT: set pending state and block navigation.
        state = state.copyWith(
          status: AuthStatus.pendingEmailVerification,
          pendingEmail: email,
          isLoading: false,
          clearError: true,
          clearProfile: true,
        );
      },
      signedOut: () {
        state = const AuthState(status: AuthStatus.unauthenticated);
      },
      passwordRecovery: () {
        state = state.copyWith(
          status: AuthStatus.passwordRecovery,
          isLoading: false,
        );
      },
      error: (message, errorCode) {
        debugPrint(
          '[TigerBay AuthNotifier] Auth event error '
          'code=$errorCode: $message',
        );
        state = state.copyWith(
          isLoading: false,
          error: message,
        );
      },
    );
  }

  // ── Email + Password sign-up ───────────────────────────────────────────────

  /// Creates an auth user and passes [homeSite] as metadata for the trigger.
  ///
  /// CRITICAL: This method DOES NOT insert into public.profiles.
  /// The database trigger handle_new_user() exclusively owns profile creation.
  ///
  /// After this method succeeds, [state.status] will be
  /// [AuthStatus.pendingEmailVerification] and the UI must show the
  /// verification-pending screen — not navigate to home.
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    required Branch homeSite,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final user = await _repo.registerNewUser(
        email: email,
        password: password,
        homeSiteId: homeSite.id,
        fullName: fullName,
      );

      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          error:
              'Sign-up returned no user. Check email confirmation settings.',
        );
        return false;
      }

      // Set state to pending verification. The onAuthStateChange listener
      // will also fire and confirm this state via _handleAuthEvent.
      // We set it here eagerly so the UI transitions immediately without
      // waiting for the stream event.
      state = state.copyWith(
        status: AuthStatus.pendingEmailVerification,
        user: user,
        pendingEmail: email,
        isLoading: false,
        clearProfile: true,
        clearError: true,
      );

      return true;
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _localizeAuthError(e.message),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  // ── Email + Password sign-in ───────────────────────────────────────────────

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final response = await _repo.signInWithEmail(
        email: email,
        password: password,
      );

      if (response.user == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Sign-in failed. Please check your credentials.',
        );
        return false;
      }

      // ── Register-First Guard ──────────────────────────────────────────
      // Check profiles table BEFORE allowing navigation. If no row exists,
      // the user is signed out and an error is surfaced.
      await _repo.checkProfileExistsOrSignOut();

      // The onAuthStateChange listener handles state update.
      // Set loading false here to unblock the UI immediately.
      state = state.copyWith(isLoading: false);
      return true;
    } on NoProfileExistsException {
      state = state.copyWith(
        isLoading: false,
        error: 'No account exists with this credential. Please register first.',
      );
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _localizeAuthError(e.message),
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return false;
    }
  }

  // ── OTP / Phone ────────────────────────────────────────────────────────────

  Future<void> sendOtp(String phone) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.sendOtp(phone);
    } on AuthException catch (e) {
      state = state.copyWith(error: _localizeAuthError(e.message));
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<bool> verifyOtp({
    required String phone,
    required String token,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await _repo.verifyOtp(phone: phone, token: token);
      if (response.user != null) {
        // ── Register-First Guard ────────────────────────────────────────
        await _repo.checkProfileExistsOrSignOut();
        state = state.copyWith(isLoading: false);
        return true;
      }
      state = state.copyWith(isLoading: false, error: 'OTP verification failed.');
      return false;
    } on NoProfileExistsException {
      state = state.copyWith(
        isLoading: false,
        error: 'No account exists with this credential. Please register first.',
      );
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _localizeAuthError(e.message),
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  // ── Social ─────────────────────────────────────────────────────────────────

  Future<bool> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.signInWithGoogle();

      // ── Register-First Guard ──────────────────────────────────────────
      await _repo.checkProfileExistsOrSignOut();

      state = state.copyWith(isLoading: false);
      return true;
    } on NoProfileExistsException {
      state = state.copyWith(
        isLoading: false,
        error: 'No account exists with this credential. Please register first.',
      );
      return false;
    } on AuthException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _localizeAuthError(e.message),
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<void> signInWithApple() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.signInWithApple();
      // NOTE: Apple OAuth uses signInWithOAuth which opens a browser redirect.
      // The register-first guard for Apple is enforced in the
      // onAuthStateChange stream handler when the SIGNED_IN event arrives
      // after the redirect completes. See _handleAuthEvent → authenticated.
    } on AuthException catch (e) {
      state = state.copyWith(error: _localizeAuthError(e.message));
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> signInWithFacebook() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.signInWithFacebook();
      // NOTE: Facebook OAuth uses signInWithOAuth which opens a browser redirect.
      // The register-first guard for Facebook is enforced in the
      // onAuthStateChange stream handler when the SIGNED_IN event arrives
      // after the redirect completes. See _handleAuthEvent → authenticated.
    } on AuthException catch (e) {
      state = state.copyWith(error: _localizeAuthError(e.message));
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.signOut();
    } catch (e) {
      debugPrint('[TigerBay AuthNotifier] signOut error: $e');
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  // ── Error localization ──────────────────────────────────────────────────────

  String _localizeAuthError(String rawMessage) {
    final m = rawMessage.toLowerCase();
    if (m.contains('invalid login credentials') ||
        m.contains('invalid_credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (m.contains('email already registered') ||
        m.contains('user_already_exists')) {
      return 'This email is already registered. Try signing in instead.';
    }
    if (m.contains('email not confirmed') ||
        m.contains('email_not_confirmed')) {
      return 'Please confirm your email before signing in. '
          'Check your inbox for the verification link.';
    }
    if (m.contains('rate limit') || m.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (m.contains('password should be at least') ||
        m.contains('weak_password')) {
      return 'Password must be at least 6 characters.';
    }
    if (m.contains('network') || m.contains('socket')) {
      return 'No internet connection. Please check your network.';
    }
    return rawMessage;
  }

  void clearError() => state = state.copyWith(clearError: true);

  @override
  void dispose() {
    _authEventSubscription?.cancel();
    super.dispose();
  }
}

// ── Providers ──────────────────────────────────────────────────────────────

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

/// The raw Supabase User object — null when signed out.
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

/// The current auth status — drives GoRouter redirect.
final authStatusProvider = Provider<AuthStatus>((ref) {
  return ref.watch(authProvider).status;
});

/// True when user is fully authenticated with confirmed email.
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isFullyAuthenticated;
});

/// True when email is sent but not yet confirmed.
final isPendingVerificationProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).status ==
      AuthStatus.pendingEmailVerification;
});

/// The email address displayed on the verification pending screen.
final pendingEmailProvider = Provider<String>((ref) {
  return ref.watch(authProvider).pendingEmail ?? '';
});

/// Branch list provider for the home-site dropdown on sign-up and settings.
final branchListForAuthProvider = FutureProvider<List<Branch>>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final response = await client
      .from('branches')
      .select()
      .eq('is_active', true)
      .order('title');
  return (response as List)
      .map((r) => Branch.fromJson(r as Map<String, dynamic>))
      .toList();
});
