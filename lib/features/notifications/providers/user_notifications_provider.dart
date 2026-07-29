import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TigerBay International — User Notifications Provider
// ═══════════════════════════════════════════════════════════════════════════
// Real-time stream of the logged-in user's notifications from the
// `user_notifications` table, ordered newest-first.
// ═══════════════════════════════════════════════════════════════════════════

/// Model for a single user notification row.
class UserNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final String? type;

  const UserNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
    this.type,
  });

  factory UserNotification.fromJson(Map<String, dynamic> json) {
    return UserNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      type: json['type'] as String?,
    );
  }
}

// ── Stream Provider ────────────────────────────────────────────────────────
/// Emits a real-time list of [UserNotification] for the current user.
/// Uses Supabase Realtime `.stream()` so any INSERT / UPDATE to
/// `user_notifications` for this user is reflected immediately.

final userNotificationsStreamProvider =
    StreamProvider<List<UserNotification>>((ref) {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;

  if (userId == null) {
    // Not authenticated — emit empty list.
    return Stream.value(<UserNotification>[]);
  }

  return client
      .from('user_notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .map(
        (rows) => rows
            .map((row) =>
                UserNotification.fromJson(row))
            .toList(),
      );
});

// ── Unread Count (derived) ─────────────────────────────────────────────────
/// Convenience provider that exposes the unread badge count.

final unreadNotificationCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(userNotificationsStreamProvider);
  return notificationsAsync.maybeWhen(
    data: (list) => list.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});

// ── Mark as Read ───────────────────────────────────────────────────────────
/// Updates the `is_read` flag to `true` for a single notification row.

Future<void> markNotificationAsRead(String notificationId) async {
  await Supabase.instance.client
      .from('user_notifications')
      .update({'is_read': true})
      .eq('id', notificationId);
}

/// Marks all notifications for the current user as read.
Future<void> markAllNotificationsAsRead() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;

  await Supabase.instance.client
      .from('user_notifications')
      .update({'is_read': true})
      .eq('user_id', userId)
      .eq('is_read', false);
}
