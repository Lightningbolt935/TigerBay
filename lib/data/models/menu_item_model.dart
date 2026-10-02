import 'dart:convert';

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
  final List<String> images;
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
    this.images = const [],
    required this.category,
    this.isAvailable = true,
    this.discountPercentage = 0,
    this.createdAt,
  });

  /// Whether this item has multiple images for carousel sliding.
  bool get hasMultipleImages => images.length > 1;

  /// Primary display image (first in image list, or single imageUrl fallback).
  String? get primaryImage => images.isNotEmpty ? images.first : imageUrl;

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
    final rawImageUrl = json['image_url']?.toString().trim();
    List<String> parsedImages = [];

    // 1. If stored as a Postgres array or list
    if (json['images'] != null && json['images'] is List) {
      parsedImages = (json['images'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    // 2. Parse comma-separated string or stringified JSON from image_url
    else if (rawImageUrl != null && rawImageUrl.isNotEmpty) {
      if (rawImageUrl.startsWith('[') && rawImageUrl.endsWith(']')) {
        try {
          final decoded = jsonDecode(rawImageUrl);
          if (decoded is List) {
            parsedImages = decoded
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        } catch (_) {
          parsedImages = [rawImageUrl];
        }
      } else if (rawImageUrl.contains(',')) {
        parsedImages = rawImageUrl
            .split(',')
            .map((url) => url.trim())
            .where((url) => url.isNotEmpty)
            .toList();
      } else {
        parsedImages = [rawImageUrl];
      }
    }

    // Ensure single imageUrl returns the clean first URL rather than the comma-separated string
    final primaryUrl =
        parsedImages.isNotEmpty ? parsedImages.first : rawImageUrl;

    return MenuItemModel(
      id: json['id'].toString(),
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      price: _safeDouble(json['price']) ?? 0.0,
      imageUrl: primaryUrl,
      images: parsedImages,
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
        'image_url': images.isNotEmpty ? images.join(', ') : imageUrl,
        'images': images,
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
    List<String>? images,
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
      images: images ?? this.images,
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
