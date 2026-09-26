import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TigerBay International — Register Provider
// ═══════════════════════════════════════════════════════════════════════════
// NOTE: As of migration 09_complete_auth_fix.sql, profile creation is
// handled EXCLUSIVELY by the database trigger handle_new_user().
//
// The old RegisterNotifier that manually upserted into public.profiles
// has been REMOVED. That code was the root cause of:
//   PostgrestException(code: 23503, "profiles_id_fkey")
//
// The two-step registration flow (auth.signUp → profile.upsert) created a
// race condition against the FK commit window. The new architecture is:
//   1. auth.signUp() with home_site_id in metadata
//   2. DB trigger fires on auth.users INSERT → creates profile atomically
//   3. User confirms email via deep link (io.tigerbay.app://login-callback)
//   4. onAuthStateChange fires SIGNED_IN with emailConfirmedAt != null
//   5. AuthNotifier loads profile via getCurrentProfile() (email-guarded)
//
// This file is retained as a thin state holder for the registration form's
// loading and error states only. All business logic lives in AuthNotifier.
// ═══════════════════════════════════════════════════════════════════════════

class RegisterFormState {
  final bool isLoading;
  final String? error;

  const RegisterFormState({
    this.isLoading = false,
    this.error,
  });

  RegisterFormState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return RegisterFormState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class RegisterFormNotifier extends StateNotifier<RegisterFormState> {
  RegisterFormNotifier() : super(const RegisterFormState());

  void setLoading(bool loading) =>
      state = state.copyWith(isLoading: loading);

  void setError(String? error) =>
      state = state.copyWith(error: error);

  void clearError() => state = state.copyWith(clearError: true);
}

final registerFormProvider =
    StateNotifierProvider<RegisterFormNotifier, RegisterFormState>((ref) {
  return RegisterFormNotifier();
});

/// ═══════════════════════════════════════════════════════════════════════════
/// Persistent Registration In-Flight Draft
/// Keeps form data (name, email, phone, password, branch, verification stage)
/// safe across GoRouter route rebuilds or hot updates so state is NEVER lost.
/// ═══════════════════════════════════════════════════════════════════════════
class RegistrationDraft {
  final String fullName;
  final String email;
  final String phone;
  final String password;
  final Branch? homeSite;
  final int stage; // 0: verifyPhone, 1: verifyEmail, 2: completed
  final String? userId;

  const RegistrationDraft({
    this.fullName = '',
    this.email = '',
    this.phone = '',
    this.password = '',
    this.homeSite,
    this.stage = 0,
    this.userId,
  });

  RegistrationDraft copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? password,
    Branch? homeSite,
    int? stage,
    String? userId,
  }) {
    return RegistrationDraft(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      password: password ?? this.password,
      homeSite: homeSite ?? this.homeSite,
      stage: stage ?? this.stage,
      userId: userId ?? this.userId,
    );
  }
}

class RegistrationDraftNotifier extends StateNotifier<RegistrationDraft> {
  RegistrationDraftNotifier() : super(const RegistrationDraft());

  void setDraft({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required Branch homeSite,
    int stage = 0,
    String? userId,
  }) {
    state = RegistrationDraft(
      fullName: fullName,
      email: email,
      phone: phone,
      password: password,
      homeSite: homeSite,
      stage: stage,
      userId: userId,
    );
  }

  void setStage(int stage) {
    state = state.copyWith(stage: stage);
  }

  void setUserId(String userId) {
    state = state.copyWith(userId: userId);
  }

  void clear() {
    state = const RegistrationDraft();
  }
}

final registrationDraftProvider =
    StateNotifierProvider<RegistrationDraftNotifier, RegistrationDraft>((ref) {
  return RegistrationDraftNotifier();
});

