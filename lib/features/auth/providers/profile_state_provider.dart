import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/supabase_repository.dart';
import 'auth_provider.dart';

export 'auth_provider.dart' show supabaseClientProvider;

// ═══════════════════════════════════════════════════════════════════════════
// TigerBay International — Profile State Provider (Auth-Safe Edition)
// ═══════════════════════════════════════════════════════════════════════════
// Central provider for the authenticated user's profile data.
// CRITICAL: This provider respects the email-confirmation lifecycle.
//   • If auth status is pendingEmailVerification → profile is never loaded.
//   • If a DB read is attempted while email is unconfirmed → an
//     UNCONFIRMED_READ_ATTEMPT error state is surfaced to the UI.
//   • All reads from public.profiles are guarded by the repository's
//     _guardEmailConfirmed() which throws UnconfirmedEmailException.

// ── Singleton providers ───────────────────────────────────────────────────

/// Singleton SupabaseRepository provider.
final supabaseRepositoryProvider = Provider<SupabaseRepository>((ref) {
  return SupabaseRepository(ref.watch(supabaseClientProvider));
});

// ── ProfileLoadStatus enum ────────────────────────────────────────────────

enum ProfileLoadStatus {
  /// Not yet attempted a load.
  idle,

  /// Load in progress.
  loading,

  /// Profile loaded successfully.
  loaded,

  /// UNCONFIRMED_READ_ATTEMPT: email not yet confirmed, DB read blocked.
  unconfirmedReadBlocked,

  /// Profile not found in DB (trigger may not have fired yet).
  notFound,

  /// An error occurred during load.
  error,
}

// ── ProfileState ──────────────────────────────────────────────────────────

class ProfileState {
  final UserProfile? profile;
  final ProfileLoadStatus loadStatus;
  final bool isLoading;
  final String? error;

  const ProfileState({
    this.profile,
    this.loadStatus = ProfileLoadStatus.idle,
    this.isLoading = false,
    this.error,
  });

  /// Whether the profile is available and the user has confirmed email.
  bool get isReady =>
      loadStatus == ProfileLoadStatus.loaded && profile != null;

  /// Whether DB reads are blocked due to unconfirmed email.
  bool get isUnconfirmedReadBlocked =>
      loadStatus == ProfileLoadStatus.unconfirmedReadBlocked;

  ProfileState copyWith({
    UserProfile? profile,
    ProfileLoadStatus? loadStatus,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearProfile = false,
  }) {
    return ProfileState(
      profile: clearProfile ? null : (profile ?? this.profile),
      loadStatus: loadStatus ?? this.loadStatus,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ── ProfileStateNotifier ──────────────────────────────────────────────────

class ProfileStateNotifier extends StateNotifier<ProfileState> {
  final SupabaseRepository _repo;
  final AuthRepository _authRepo;
  final String _userId;
  final AuthStatus _authStatus;

  ProfileStateNotifier({
    required SupabaseRepository repo,
    required AuthRepository authRepo,
    required String userId,
    required AuthStatus authStatus,
  })  : _repo = repo,
        _authRepo = authRepo,
        _userId = userId,
        _authStatus = authStatus,
        super(const ProfileState()) {
    if (_userId.isNotEmpty) {
      _conditionalLoad();
    }
  }

  /// Loads the profile only when the auth status confirms email is verified.
  ///
  /// UNCONFIRMED_READ_ATTEMPT guard: if authStatus is pendingEmailVerification,
  /// we block the DB read and set a clear status so the router and UI can
  /// surface the "check your inbox" screen without touching the database.
  void _conditionalLoad() {
    if (_authStatus == AuthStatus.pendingEmailVerification) {
      debugPrint(
        '[TigerBay ProfileState] UNCONFIRMED_READ_ATTEMPT blocked for '
        'user $_userId. Auth status is pendingEmailVerification. '
        'Skipping public.profiles query.',
      );
      state = state.copyWith(
        loadStatus: ProfileLoadStatus.unconfirmedReadBlocked,
        clearProfile: true,
        clearError: true,
      );
      return;
    }

    if (_authStatus == AuthStatus.authenticated) {
      loadProfile();
    }
  }

  /// Loads the full profile row from public.profiles.
  ///
  /// Guards against unconfirmed reads via the repository layer.
  /// On [UnconfirmedEmailException]: sets [ProfileLoadStatus.unconfirmedReadBlocked].
  /// On [PostgrestException]: surfaces the code and message for debugging.
  Future<void> loadProfile() async {
    if (_userId.isEmpty) return;

    state = state.copyWith(
      isLoading: true,
      loadStatus: ProfileLoadStatus.loading,
      clearError: true,
    );

    try {
      // This call internally calls _guardEmailConfirmed(), throwing
      // UnconfirmedEmailException if email_confirmed_at is null.
      final profile = await _authRepo.getCurrentProfile();

      if (profile == null) {
        // Profile row not yet created — trigger may still be in-flight.
        // This is a transient state, not an error. Return notFound status.
        debugPrint(
          '[TigerBay ProfileState] public.profiles row not found for '
          'user $_userId. Trigger may still be committing.',
        );
        state = state.copyWith(
          isLoading: false,
          loadStatus: ProfileLoadStatus.notFound,
          clearProfile: true,
        );
        return;
      }

      state = state.copyWith(
        profile: profile,
        isLoading: false,
        loadStatus: ProfileLoadStatus.loaded,
        clearError: true,
      );
    } on UnconfirmedEmailException catch (e) {
      // UNCONFIRMED_READ_ATTEMPT: repository confirmed email not yet confirmed.
      debugPrint('[TigerBay ProfileState] UNCONFIRMED_READ_ATTEMPT: $e');
      state = state.copyWith(
        isLoading: false,
        loadStatus: ProfileLoadStatus.unconfirmedReadBlocked,
        clearProfile: true,
        clearError: true,
      );
    } on PostgrestException catch (pgErr) {
      debugPrint(
        '[TigerBay ProfileState] PostgrestException loading profile: '
        'code=${pgErr.code} msg=${pgErr.message}',
      );
      state = state.copyWith(
        isLoading: false,
        loadStatus: ProfileLoadStatus.error,
        error:
            'Profile load failed (${pgErr.code ?? 'DB_ERROR'}): '
            '${pgErr.message}',
      );
    } catch (e) {
      debugPrint('[TigerBay ProfileState] Unexpected profile load error: $e');
      state = state.copyWith(
        isLoading: false,
        loadStatus: ProfileLoadStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> refreshProfile() async => loadProfile();

  /// Updates membership status after paywall activation.
  Future<bool> activateMembership({
    required int tierId,
    required String status,
  }) async {
    if (_userId.isEmpty) return false;

    // Block membership activation if email not confirmed.
    if (_authStatus == AuthStatus.pendingEmailVerification) {
      debugPrint(
        '[TigerBay ProfileState] UNCONFIRMED_READ_ATTEMPT: '
        'activateMembership blocked — email not confirmed.',
      );
      state = state.copyWith(
        error: 'Please confirm your email before activating membership.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repo.updateMembershipStatus(
        userId: _userId,
        tierId: tierId,
        status: status,
      );
      await loadProfile();
      return true;
    } on PostgrestException catch (pgErr) {
      state = state.copyWith(
        isLoading: false,
        error: 'Membership activation failed: ${pgErr.message}',
      );
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

// ── Providers ──────────────────────────────────────────────────────────────

/// Main profile state provider.
/// Rebuilds whenever the auth user or auth status changes.
/// When authStatus is pendingEmailVerification, profile load is blocked.
final profileStateProvider =
    StateNotifierProvider<ProfileStateNotifier, ProfileState>((ref) {
  final user = ref.watch(currentUserProvider);
  final authStatus = ref.watch(authStatusProvider);
  final repo = ref.watch(supabaseRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);

  return ProfileStateNotifier(
    repo: repo,
    authRepo: authRepo,
    userId: user?.id ?? '',
    authStatus: authStatus,
  );
});

// ── Derived convenience providers ─────────────────────────────────────────

/// The full UserProfile object (nullable).
final userProfileProvider = Provider<UserProfile?>((ref) {
  return ref.watch(profileStateProvider).profile;
});

/// The user's current membership status string.
final membershipStatusProvider = Provider<String>((ref) {
  return ref.watch(profileStateProvider).profile?.membershipStatus ?? 'inactive';
});

/// Whether the user has an active paid membership.
final isMembershipActiveProvider = Provider<bool>((ref) {
  final profile = ref.watch(profileStateProvider).profile;
  return profile?.isMembershipActive ?? false;
});

/// Whether the user's membership has expired.
final isMembershipExpiredProvider = Provider<bool>((ref) {
  final profile = ref.watch(profileStateProvider).profile;
  return profile?.isMembershipExpired ?? false;
});

/// The user's current Strips balance.
final stripsBalanceProvider = Provider<int>((ref) {
  return ref.watch(profileStateProvider).profile?.stripsBalance ?? 0;
});

/// Whether DB reads are blocked because email is unconfirmed.
final isProfileReadBlockedProvider = Provider<bool>((ref) {
  return ref.watch(profileStateProvider).isUnconfirmedReadBlocked;
});

/// Realtime stream of the user's profile — pushes live balance and status
/// updates. Only emits when email is confirmed; returns empty stream otherwise.
final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final user = ref.watch(currentUserProvider);
  final authStatus = ref.watch(authStatusProvider);

  // Guard: never subscribe to the profile stream during unconfirmed window.
  if (user == null || authStatus == AuthStatus.pendingEmailVerification) {
    return const Stream.empty();
  }

  final repo = ref.watch(supabaseRepositoryProvider);
  return repo.watchUserProfile(user.id);
});
