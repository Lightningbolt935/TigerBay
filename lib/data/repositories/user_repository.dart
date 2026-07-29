import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class UserRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<UserProfile?> getProfile(String userId) async {
    final data = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) return null;
    return UserProfile.fromMap(data);
  }

  Future<UserProfile> updateProfile({
    required String userId,
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
  }) async {
    // Only update columns that exist in public.profiles schema
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (fullName != null) updates['full_name'] = fullName;
    if (email != null) updates['email'] = email;
    if (phone != null) updates['phone'] = phone;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

    final data = await _supabase
        .from('profiles')
        .update(updates)
        .eq('id', userId)
        .select()
        .single();

    return UserProfile.fromMap(data);
  }

  /// Upload avatar to Supabase Storage, return public URL
  Future<String> uploadAvatar({
    required String userId,
    required List<int> bytes,
    required String extension,
  }) async {
    final path = 'avatars/$userId.$extension';
    await _supabase.storage.from('avatars').uploadBinary(
          path,
          Uint8List.fromList(bytes),
          fileOptions: FileOptions(
            contentType: 'image/$extension',
            upsert: true,
          ),
        );
    return _supabase.storage.from('avatars').getPublicUrl(path);
  }

  /// Delete account: removes auth user, cascades to all tables via FK
  Future<void> deleteAccount(String userId) async {
    await _supabase.functions.invoke(
      'delete-account',
      body: {'user_id': userId},
    );
  }

  Stream<UserProfile?> watchProfile(String userId) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) =>
            rows.isEmpty ? null : UserProfile.fromMap(rows.first));
  }
}
