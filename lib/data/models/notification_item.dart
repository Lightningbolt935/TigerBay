// ═══════════════════════════════════════════════════════════════════════════
// TigerBay International — NotificationItem Model
// ═══════════════════════════════════════════════════════════════════════════
// Strong-typed model for rows in the `user_notifications` table.
// Supported types: 'birthday' | 'broadcast' | 'system' | 'promo'

// Sentinel used by copyWith to distinguish "omitted" from explicit null.
const Object _sentinel = Object();

/// Canonical model for a single user_notifications row.
///
/// Use [NotificationItem.fromMap] to deserialize a Supabase row map.
/// [type] defaults to `'broadcast'` when the DB value is null / unknown.
class NotificationItem {
  final String id;
  final String userId;
  final String title;
  final String body;

  /// Notification type gate: 'birthday' | 'broadcast' | 'system' | 'promo'
  final String type;

  /// Optional image/avatar URL. Guaranteed non-empty when non-null.
  final String? imageUrl;

  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.type,
    this.imageUrl,
    required this.isRead,
    required this.createdAt,
  });

  // ── Deserialization ──────────────────────────────────────────────────────

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    // Converts empty strings from Supabase into null so widgets never
    // receive a non-null but blank URL.
    String? sanitizeUrl(dynamic raw) {
      if (raw == null) return null;
      final str = raw.toString().trim();
      return str.isEmpty ? null : str;
    }

    return NotificationItem(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      type: map['type'] as String? ?? 'broadcast',
      imageUrl: sanitizeUrl(map['image_url'] ?? map['avatar_url']),
      isRead: map['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  // ── Serialization (for optimistic updates) ───────────────────────────────

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        if (imageUrl != null) 'image_url': imageUrl,
        'is_read': isRead,
        'created_at': createdAt.toIso8601String(),
      };

  // ── Immutable copy ───────────────────────────────────────────────────────

  NotificationItem copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    String? type,
    Object? imageUrl = _sentinel,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      imageUrl: imageUrl == _sentinel ? this.imageUrl : imageUrl as String?,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationItem &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          isRead == other.isRead;

  @override
  int get hashCode => id.hashCode ^ isRead.hashCode;

  @override
  String toString() =>
      'NotificationItem(id: $id, type: $type, isRead: $isRead, title: $title)';
}
