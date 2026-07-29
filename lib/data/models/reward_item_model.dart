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

  const RewardItem({
    required this.id,
    required this.title,
    required this.description,
    required this.stripsCost,
    this.imageUrl = '',
    this.isActive = true,
  });

  factory RewardItem.fromMap(Map<String, dynamic> map) {
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
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'strips_cost': stripsCost,
        'image_url': imageUrl,
        'is_active': isActive,
      };

  RewardItem copyWith({
    int? id,
    String? title,
    String? description,
    int? stripsCost,
    String? imageUrl,
    bool? isActive,
  }) {
    return RewardItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      stripsCost: stripsCost ?? this.stripsCost,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
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
