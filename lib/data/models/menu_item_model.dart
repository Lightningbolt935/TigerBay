import 'dart:convert';

class ItemVariant {
  final String id;
  final String name;
  final double price;

  const ItemVariant({
    required this.id,
    required this.name,
    required this.price,
  });

  String get formattedPrice => '£${price.toStringAsFixed(2)}';

  factory ItemVariant.fromJson(Map<String, dynamic> json) {
    return ItemVariant(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: MenuItemModel.safeDouble(json['price']) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
      };
}

class ItemAddon {
  final String id;
  final String name;
  final double price;

  const ItemAddon({
    required this.id,
    required this.name,
    required this.price,
  });

  String get formattedPrice => '+£${price.toStringAsFixed(2)}';

  factory ItemAddon.fromJson(Map<String, dynamic> json) {
    return ItemAddon(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      price: MenuItemModel.safeDouble(json['price']) ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
      };
}

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — MenuItem Model
/// ═══════════════════════════════════════════════════════════════════════════
class MenuItemModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final List<String> images;
  final String category;
  final String? subcategory;
  final String? categoryId;
  final int? branchId;
  final bool isAvailable;
  final int discountPercentage;
  final List<ItemVariant> variants;
  final List<ItemAddon> addons;
  final DateTime? createdAt;

  const MenuItemModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    this.images = const [],
    required this.category,
    this.subcategory,
    this.categoryId,
    this.branchId,
    this.isAvailable = true,
    this.discountPercentage = 0,
    this.variants = const [],
    this.addons = const [],
    this.createdAt,
  });

  List<String> get imageUrls => images;
  bool get hasMultipleImages => images.length > 1;
  String? get primaryImage => images.isNotEmpty ? images.first : imageUrl;
  bool get hasVariants => variants.isNotEmpty;
  bool get hasAddons => addons.isNotEmpty;
  bool get hasDiscount => discountPercentage > 0;
  double get discountedPrice => price * (1 - discountPercentage / 100);
  String get formattedPrice => '£${price.toStringAsFixed(2)}';
  String get discountedPriceFormatted =>
      '£${discountedPrice.toStringAsFixed(2)}';
  String get displayPrice =>
      hasDiscount ? discountedPriceFormatted : formattedPrice;
  MenuCategory get menuCategory => MenuCategory.fromString(category);

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    final rawImageUrl = json['image_url']?.toString().trim();
    List<String> parsedImages = [];

    if (json['images'] != null && json['images'] is List) {
      parsedImages = (json['images'] as List)
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (rawImageUrl != null && rawImageUrl.isNotEmpty) {
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

    final primaryUrl =
        parsedImages.isNotEmpty ? parsedImages.first : rawImageUrl;

    List<ItemVariant> parsedVariants = [];
    if (json['variants'] != null && json['variants'] is List) {
      parsedVariants = (json['variants'] as List)
          .whereType<Map<String, dynamic>>()
          .map((v) => ItemVariant.fromJson(v))
          .toList();
    }

    List<ItemAddon> parsedAddons = [];
    if (json['addons'] != null && json['addons'] is List) {
      parsedAddons = (json['addons'] as List)
          .whereType<Map<String, dynamic>>()
          .map((a) => ItemAddon.fromJson(a))
          .toList();
    }

    return MenuItemModel(
      id: json['id'].toString(),
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      price: safeDouble(json['price']) ?? 0.0,
      imageUrl: primaryUrl,
      images: parsedImages,
      category: (json['category'] as String?) ?? 'food',
      subcategory: json['subcategory'] as String?,
      categoryId: json['category_id']?.toString(),
      branchId: json['branch_id'] is int
          ? json['branch_id'] as int
          : int.tryParse(json['branch_id']?.toString() ?? ''),
      isAvailable: (json['is_available'] as bool?) ?? true,
      discountPercentage: safeInt(json['discount_percentage']) ?? 0,
      variants: parsedVariants,
      addons: parsedAddons,
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
        'subcategory': subcategory,
        'category_id': categoryId,
        'branch_id': branchId,
        'is_available': isAvailable,
        'discount_percentage': discountPercentage,
        'variants': variants.map((v) => v.toJson()).toList(),
        'addons': addons.map((a) => a.toJson()).toList(),
        'created_at': createdAt?.toIso8601String(),
      };

  MenuItemModel copyWith({
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    List<String>? images,
    String? category,
    String? subcategory,
    String? categoryId,
    int? branchId,
    bool? isAvailable,
    int? discountPercentage,
    List<ItemVariant>? variants,
    List<ItemAddon>? addons,
  }) {
    return MenuItemModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      categoryId: categoryId ?? this.categoryId,
      branchId: branchId ?? this.branchId,
      isAvailable: isAvailable ?? this.isAvailable,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      variants: variants ?? this.variants,
      addons: addons ?? this.addons,
      createdAt: createdAt,
    );
  }

  static int? safeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static double? safeDouble(dynamic value) {
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
  dessert('dessert'),
  shisha('shisha');

  final String value;
  const MenuCategory(this.value);

  static MenuCategory fromString(String s) {
    final lower = s.toLowerCase().trim();
    if (lower == 'starters' || lower == 'starter' || lower == 'food') {
      return MenuCategory.food;
    }
    if (lower == 'drinks' || lower == 'drink' || lower == 'beverages') {
      return MenuCategory.drinks;
    }
    if (lower == 'dessert' || lower == 'desserts' || lower == 'sweet') {
      return MenuCategory.dessert;
    }
    if (lower == 'shisha' || lower == 'hookah') {
      return MenuCategory.shisha;
    }
    if (lower == 'all') {
      return MenuCategory.all;
    }
    return MenuCategory.food;
  }

  String get displayName {
    switch (this) {
      case MenuCategory.all:
        return 'All';
      case MenuCategory.food:
        return 'Food';
      case MenuCategory.drinks:
        return 'Drinks';
      case MenuCategory.dessert:
        return 'Dessert';
      case MenuCategory.shisha:
        return 'Shisha';
    }
  }
}
