/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — MenuItem Model
/// ═══════════════════════════════════════════════════════════════════════════
/// Maps to `public.dishes` (or `public.menu_items`). Includes admin-driven
/// percentage discount support for the Beautiful Menu Card widget.
class MenuItemModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final String category;
  final bool isAvailable;
  final int discountPercentage;
  final DateTime? createdAt;

  const MenuItemModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.category,
    this.isAvailable = true,
    this.discountPercentage = 0,
    this.createdAt,
  });

  /// Whether this item has an admin-set discount.
  bool get hasDiscount => discountPercentage > 0;

  /// Calculated discounted price: originalPrice × (1 - discount/100).
  double get discountedPrice => price * (1 - discountPercentage / 100);

  /// Formatted original price.
  String get formattedPrice => '£${price.toStringAsFixed(2)}';

  /// Formatted discounted price.
  String get discountedPriceFormatted =>
      '£${discountedPrice.toStringAsFixed(2)}';

  /// The effective display price (discounted if applicable, else original).
  String get displayPrice =>
      hasDiscount ? discountedPriceFormatted : formattedPrice;

  /// Map the raw category string into a MenuCategory enum for filtering.
  MenuCategory get menuCategory => MenuCategory.fromString(category);

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: json['id'].toString(),
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      price: _safeDouble(json['price']) ?? 0.0,
      imageUrl: json['image_url'] as String?,
      category: (json['category'] as String?) ?? 'food',
      isAvailable: (json['is_available'] as bool?) ?? true,
      discountPercentage: _safeInt(json['discount_percentage']) ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'price': price,
        'image_url': imageUrl,
        'category': category,
        'is_available': isAvailable,
        'discount_percentage': discountPercentage,
        'created_at': createdAt?.toIso8601String(),
      };

  MenuItemModel copyWith({
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    String? category,
    bool? isAvailable,
    int? discountPercentage,
  }) {
    return MenuItemModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      createdAt: createdAt,
    );
  }

  static int? _safeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? _safeDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

enum MenuCategory {
  all('all'),
  food('food'),
  drinks('drinks'),
  shisha('shisha');

  final String value;
  const MenuCategory(this.value);

  static MenuCategory fromString(String s) {
    return MenuCategory.values.firstWhere(
      (e) => e.value == s.toLowerCase(),
      orElse: () => MenuCategory.food,
    );
  }

  String get displayName {
    switch (this) {
      case MenuCategory.all:
        return 'All';
      case MenuCategory.food:
        return 'Food';
      case MenuCategory.drinks:
        return 'Drinks';
      case MenuCategory.shisha:
        return 'Shisha';
    }
  }
}
