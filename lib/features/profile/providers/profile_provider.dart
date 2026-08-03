import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
class ProfileState {
  final UserProfile? profile;
  final bool isLoading;
  final bool isSaving;
  final String? error;
  final bool savedSuccessfully;

  const ProfileState({
    this.profile,
    this.isLoading = false,
    this.isSaving = false,
    this.error,
    this.savedSuccessfully = false,
  });

  ProfileState copyWith({
    UserProfile? profile,
    bool? isLoading,
    bool? isSaving,
    String? error,
    bool? savedSuccessfully,
    bool clearError = false,
  }) {
    return ProfileState(
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
      savedSuccessfully: savedSuccessfully ?? this.savedSuccessfully,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final SupabaseClient _supabase;
  final String _userId;

  ProfileNotifier(this._supabase, this._userId) : super(const ProfileState()) {
    _load();
  }

  Future<void> _load() async {
    if (_userId.isEmpty) return;
    state = state.copyWith(isLoading: true);
    try {
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', _userId)
          .single();
      state = state.copyWith(
        profile: UserProfile.fromMap(data),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> updateProfile({
    required String fullName,
    required String email,
    String? phone,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true, savedSuccessfully: false);
    try {
      final data = await _supabase
          .from('profiles')
          .update({
            'full_name': fullName,
            'email': email,
            if (phone != null) 'phone': phone,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _userId)
          .select()
          .single();

      state = state.copyWith(
        profile: UserProfile.fromMap(data),
        isSaving: false,
        savedSuccessfully: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  /// Persists [gender] and [dob] to the `profiles` table.
  /// [dob] is stored as an ISO-8601 date string (YYYY-MM-DD).
  Future<bool> updateGenderDob({
    String? gender,
    DateTime? dob,
  }) async {
    state = state.copyWith(
        isSaving: true, clearError: true, savedSuccessfully: false);
    try {
      final updateMap = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (gender != null) updateMap['gender'] = gender;
      if (dob != null) {
        updateMap['dob'] = dob.toIso8601String().split('T').first;
      }

      final data = await _supabase
          .from('profiles')
          .update(updateMap)
          .eq('id', _userId)
          .select()
          .single();

      state = state.copyWith(
        profile: UserProfile.fromMap(data),
        isSaving: false,
        savedSuccessfully: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  Future<bool> uploadAvatar(String filePath, fileBytes) async {
    try {
      final ext = filePath.split('.').last;
      final path = 'avatars/$_userId.$ext';
      await _supabase.storage.from('avatars').uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
          );
      final url = _supabase.storage.from('avatars').getPublicUrl(path);
      await _supabase
          .from('profiles')
          .update({'avatar_url': url})
          .eq('id', _userId);
      state = state.copyWith(
        profile: state.profile?.copyWith(avatarUrl: url),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void clearSavedFlag() {
    state = state.copyWith(savedSuccessfully: false);
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final user = ref.watch(currentUserProvider);
  return ProfileNotifier(Supabase.instance.client, user?.id ?? '');
});
