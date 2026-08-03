import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tigerbay_app/data/models/notification_item.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TigerBay International — User Notifications Provider
// ═══════════════════════════════════════════════════════════════════════════
// Responsibilities:
//  • Fetch historical notifications from `user_notifications` on build.
//  • Subscribe to INSERT + UPDATE events via Supabase Realtime `.stream()`
//    so new broadcasts / birthday wishes arrive instantly.
//  • Optimistic UI updates for markAsRead / markAllAsRead with DB rollback
//    on failure.
// ═══════════════════════════════════════════════════════════════════════════

/// Back-compat alias — keeps existing import references working.
/// New code should prefer [NotificationItem] directly.
typedef UserNotification = NotificationItem;

// ── NotificationService ────────────────────────────────────────────────────

/// Thin service wrapper around the Supabase client.
/// Isolated here so it can be unit-tested or swapped independently.
class NotificationService {
  final _supabase = Supabase.instance.client;

  // 1. Fetch historical notifications (most-recent-first)
  Future<List<NotificationItem>> fetchNotifications() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('user_notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((e) => NotificationItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // 2. Realtime stream — emits full sorted list on INSERT or UPDATE.
  //    RLS on the table ensures each user only sees their own rows.
  Stream<List<NotificationItem>> subscribeToNotifications() {
    final userId = _supabase.auth.currentUser?.id ?? '';
    return _supabase
        .from('user_notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(NotificationItem.fromMap).toList());
  }

  // 3. Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('user_notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('user_id', userId);
  }

  // 4. Mark all notifications as read
  Future<void> markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('user_notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }
}

// ── AsyncNotifier ──────────────────────────────────────────────────────────

class NotificationsNotifier
    extends AsyncNotifier<List<NotificationItem>> {
  SupabaseClient get _client => Supabase.instance.client;
  final _service = NotificationService();

  /// Active realtime subscription — cancelled on dispose.
  StreamSubscription<List<NotificationItem>>? _realtimeSubscription;

  @override
  Future<List<NotificationItem>> build() async {
    // Cancel any stale subscription from a previous build.
    _realtimeSubscription?.cancel();

    // Ensure the subscription is torn down when the notifier is disposed.
    ref.onDispose(() {
      _realtimeSubscription?.cancel();
      _realtimeSubscription = null;
    });

    // Initial fetch from DB.
    final initial = await _service.fetchNotifications();

    // Subscribe to realtime changes. Each emission replaces the full list,
    // so inserts and updates are reflected immediately without a pull-to-refresh.
    _realtimeSubscription = _service
        .subscribeToNotifications()
        .listen((updatedList) {
      state = AsyncData(updatedList);
    });

    return initial;
  }

  // ── Mark a single notification as read ──────────────────────────────────
  /// Instantly updates local state (optimistic), then persists to Supabase.
  /// Rolls back to the previous state if the DB write fails.
  Future<void> markAsRead(String notificationId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    // Snapshot for rollback.
    final previous = state;

    // ── Optimistic update ────────────────────────────────────────────────
    state = state.whenData((notifications) {
      return notifications.map((n) {
        return n.id == notificationId ? n.copyWith(isRead: true) : n;
      }).toList();
    });

    // ── DB write ─────────────────────────────────────────────────────────
    try {
      await _client
          .from('user_notifications')
          .update({'is_read': true})
          .eq('id', notificationId)
          .eq('user_id', userId);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  // ── Mark ALL notifications as read ──────────────────────────────────────
  /// Instantly marks all items read in local state, then persists.
  /// Rolls back on failure.
  Future<void> markAllAsRead() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    final previous = state;

    // ── Optimistic update ────────────────────────────────────────────────
    state = state.whenData(
      (notifications) => notifications.map((n) => n.copyWith(isRead: true)).toList(),
    );

    // ── DB write ─────────────────────────────────────────────────────────
    try {
      await _client
          .from('user_notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);
    } catch (_) {
      state = previous;
      rethrow;
    }
  }

  // ── Manual refresh ───────────────────────────────────────────────────────
  /// Triggers a full re-fetch (e.g. after an error retry).
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_service.fetchNotifications);
  }
}

// ── Main notifications provider ────────────────────────────────────────────
/// Used by the Notifications Screen and any widget that needs the full list.
final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, List<NotificationItem>>(
  NotificationsNotifier.new,
);

// ── Unread count (derived) ─────────────────────────────────────────────────
/// Badge count used by the Bell Icon in the Home header.
/// Automatically recalculates whenever any notification is marked as read
/// or a new notification arrives via realtime.
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notificationsAsync = ref.watch(notificationsProvider);
  return notificationsAsync.maybeWhen(
    data: (notifications) => notifications.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});
