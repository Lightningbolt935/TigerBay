/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — MerchandiseItem Model
/// ═══════════════════════════════════════════════════════════════════════════
/// Represents a single branded merchandise product available for purchase
/// in the TigerBay Merchandise Marketplace. Items can be acquired either
/// for their cash [price] or by redeeming [requiredStrips] Strips Tokens.
class MerchandiseItem {
  /// Unique stable identifier
  final String id;

  /// Display name shown on the card and detail view.
  final String name;

  /// Short marketing copy
  final String description;

  /// Cash retail price in USD/GBP.
  final double price;

  /// Strips Token cost required for a full redemption.
  final int requiredStrips;

  /// Asset path or network URL for the product image.
  final String imageUrl;

  /// Whether the item is currently in stock and available for redemption.
  final bool isAvailable;

  const MerchandiseItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.requiredStrips,
    required this.imageUrl,
    this.isAvailable = true,
  });

  // ── Serialization ───────────────────────────────────────────────────────

  factory MerchandiseItem.fromMap(Map<String, dynamic> map) {
    return MerchandiseItem(
      id: map['id']?.toString() ?? '',
      name: (map['name'] as String?) ??
          (map['title'] as String?) ??
          'Merchandise',
      description: (map['description'] as String?) ?? '',
      price: _safeDouble(map['price']) ?? 0.0,
      requiredStrips: _safeInt(map['required_strips']) ??
          _safeInt(map['strips_cost']) ??
          _safeInt(map['requiredStrips']) ??
          0,
      imageUrl:
          (map['image_url'] as String?) ?? (map['imageUrl'] as String?) ?? '',
      isAvailable: (map['is_available'] as bool?) ??
          (map['is_available_for_redemption'] as bool?) ??
          (map['isAvailable'] as bool?) ??
          true,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'required_strips': requiredStrips,
        'image_url': imageUrl,
        'is_available': isAvailable,
      };

  // ── copyWith ────────────────────────────────────────────────────────────

  MerchandiseItem copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    int? requiredStrips,
    String? imageUrl,
    bool? isAvailable,
  }) {
    return MerchandiseItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      requiredStrips: requiredStrips ?? this.requiredStrips,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  // ── Equality & identity ─────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MerchandiseItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MerchandiseItem(id: $id, name: $name, price: \$$price, strips: $requiredStrips)';

  // ── Private safe-cast helpers ───────────────────────────────────────────

  static double? _safeDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _safeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
