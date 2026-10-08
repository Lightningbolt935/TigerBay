/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — RewardItem Model
/// ═══════════════════════════════════════════════════════════════════════════
/// Maps 1-to-1 with `public.rewards`. Items available for redemption in the
/// Reward Store using accumulated Strips balance (e.g. Free Drinks, Custom
/// Rewards).
class RewardItem {
  final int id;
  final String title;
  final String description;
  final int stripsCost;
  final String imageUrl;
  final bool isActive;
  final DateTime? expiresAt;
  final int? validDays;
  final DateTime? createdAt;

  const RewardItem({
    required this.id,
    required this.title,
    required this.description,
    required this.stripsCost,
    this.imageUrl = '',
    this.isActive = true,
    this.expiresAt,
    this.validDays,
    this.createdAt,
  });

  /// The effective expiration DateTime for this reward
  DateTime get effectiveExpiresAt {
    if (expiresAt != null) return expiresAt!;
    final base = createdAt ?? DateTime.now();
    final days = validDays ?? 30; // default 30-day auto expiry
    return base.add(Duration(days: days));
  }

  /// Whether this reward is expired
  bool get isExpired => DateTime.now().isAfter(effectiveExpiresAt);

  /// Number of whole days remaining until expiration
  int get daysRemaining {
    final diff = effectiveExpiresAt.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Human-readable auto-expiry status badge
  String get expiryBadgeText {
    if (isExpired) return 'EXPIRED';
    final days = daysRemaining;
    if (days == 0) return 'EXPIRES TODAY';
    if (days == 1) return 'EXPIRES TOMORROW';
    if (days <= 7) return '$days DAYS LEFT';
    return '$days-DAY VALIDITY';
  }

  factory RewardItem.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String && val.isNotEmpty) {
        return DateTime.tryParse(val);
      }
      return null;
    }

    return RewardItem(
      id: _safeInt(map['id']) ?? 0,
      title: (map['title'] as String?) ?? (map['name'] as String?) ?? 'Reward',
      description: (map['description'] as String?) ?? '',
      stripsCost: _safeInt(map['strips_cost']) ??
          _safeInt(map['cost']) ??
          _safeInt(map['required_strips']) ??
          _safeInt(map['stripsCost']) ??
          0,
      imageUrl:
          (map['image_url'] as String?) ?? (map['imageUrl'] as String?) ?? '',
      isActive:
          (map['is_active'] as bool?) ?? (map['isActive'] as bool?) ?? true,
      expiresAt: parseDate(map['expires_at'] ?? map['expiry_date']),
      validDays: _safeInt(map['valid_days'] ?? map['validity_days']),
      createdAt: parseDate(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'strips_cost': stripsCost,
        'image_url': imageUrl,
        'is_active': isActive,
        'expires_at': expiresAt?.toIso8601String(),
        'valid_days': validDays,
        'created_at': createdAt?.toIso8601String(),
      };

  RewardItem copyWith({
    int? id,
    String? title,
    String? description,
    int? stripsCost,
    String? imageUrl,
    bool? isActive,
    DateTime? expiresAt,
    int? validDays,
    DateTime? createdAt,
  }) {
    return RewardItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      stripsCost: stripsCost ?? this.stripsCost,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      expiresAt: expiresAt ?? this.expiresAt,
      validDays: validDays ?? this.validDays,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RewardItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'RewardItem(id: $id, title: $title, cost: $stripsCost)';

  static int? _safeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
