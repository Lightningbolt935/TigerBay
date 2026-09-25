import 'package:flutter/foundation.dart';
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

      var profile = UserProfile.fromMap(data);
      final authUser = _supabase.auth.currentUser;
      final authEmail = authUser?.email ?? authUser?.userMetadata?['email'] as String?;
      final authName = authUser?.userMetadata?['full_name'] as String? ??
          authUser?.userMetadata?['name'] as String? ??
          authUser?.userMetadata?['user_name'] as String?;
      final authAvatar = authUser?.userMetadata?['avatar_url'] as String? ??
          authUser?.userMetadata?['picture'] as String?;

      final Map<String, dynamic> backfill = {};
      if ((profile.email == null || profile.email!.isEmpty) && authEmail != null && authEmail.isNotEmpty) {
        profile = profile.copyWith(email: authEmail);
        backfill['email'] = authEmail;
      }
      if ((profile.fullName == null || profile.fullName!.isEmpty) && authName != null && authName.isNotEmpty) {
        profile = profile.copyWith(fullName: authName);
        backfill['full_name'] = authName;
      }
      if ((profile.avatarUrl == null || profile.avatarUrl!.isEmpty) && authAvatar != null && authAvatar.isNotEmpty) {
        profile = profile.copyWith(avatarUrl: authAvatar);
        backfill['avatar_url'] = authAvatar;
      }

      if (backfill.isNotEmpty) {
        // Sync any discovered metadata back to profiles table
        _supabase.from('profiles').update(backfill).eq('id', _userId).then((_) {}, onError: (_) {});
      }

      state = state.copyWith(
        profile: profile,
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
    String? gender,
    DateTime? dob,
    int? homeSiteId,
  }) async {
    state = state.copyWith(isSaving: true, clearError: true, savedSuccessfully: false);
    try {
      final updateMap = <String, dynamic>{
        'full_name': fullName,
        'email': email,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (phone != null) updateMap['phone'] = phone;
      if (gender != null) updateMap['gender'] = gender;
      if (homeSiteId != null) updateMap['home_site_id'] = homeSiteId;
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

  Future<bool> uploadAvatar(String fileName, Uint8List fileBytes) async {
    state = state.copyWith(isSaving: true, error: null);
    try {
      final rawExt = fileName.split('.').last.toLowerCase();
      final ext = (rawExt == 'png' || rawExt == 'webp' || rawExt == 'jpeg')
          ? rawExt
          : 'jpg';
      final mimeType = ext == 'png'
          ? 'image/png'
          : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
      final path = 'avatars/$_userId.$ext';

      await _supabase.storage.from('avatars').uploadBinary(
            path,
            fileBytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: true),
          );
      final rawUrl = _supabase.storage.from('avatars').getPublicUrl(path);
      // Append cache-busting timestamp so UI refreshes immediately
      final url = '$rawUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      await _supabase
          .from('profiles')
          .update({'avatar_url': url})
          .eq('id', _userId);

      state = state.copyWith(
        isSaving: false,
        profile: state.profile?.copyWith(avatarUrl: url),
      );
      return true;
    } catch (e) {
      debugPrint('[ProfileProvider] Error uploading avatar: $e');
      state = state.copyWith(isSaving: false, error: e.toString());
      return false;
    }
  }

  void clearSavedFlag() {
    state = state.copyWith(savedSuccessfully: false);
  }

  /// Apple Guideline 5.1.1(v) Compliant Account Deletion
  Future<bool> deleteAccount() async {
    if (_userId.isEmpty) return false;
    state = state.copyWith(isSaving: true, error: null);
    try {
      final res = await _supabase.functions.invoke(
        'delete-account',
        body: {'user_id': _userId},
      );
      if (res.status >= 400) {
        await _supabase.from('profiles').delete().eq('id', _userId);
      }
      await _supabase.auth.signOut();
      state = const ProfileState();
      return true;
    } catch (e) {
      debugPrint('[ProfileProvider] Error invoking delete-account: $e');
      try {
        await _supabase.from('profiles').delete().eq('id', _userId);
        await _supabase.auth.signOut();
        state = const ProfileState();
        return true;
      } catch (inner) {
        state = state.copyWith(
          isSaving: false,
          error: 'Could not delete account. Please contact support.',
        );
        return false;
      }
    }
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final user = ref.watch(currentUserProvider);
  return ProfileNotifier(Supabase.instance.client, user?.id ?? '');
});
