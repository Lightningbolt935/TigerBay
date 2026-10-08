import 'package:flutter/foundation.dart';

@immutable
class PackageModel {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final double price;
  final String priceFormatted;
  final String imageUrl;
  final String? badge;
  final String guestCount;
  final List<String> inclusions;
  final int? branchId;
  final bool isActive;
  final int displayOrder;

  const PackageModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.price,
    required this.priceFormatted,
    required this.imageUrl,
    this.badge,
    required this.guestCount,
    required this.inclusions,
    this.branchId,
    this.isActive = true,
    this.displayOrder = 0,
  });

  factory PackageModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      if (raw is String && raw.isNotEmpty) {
        return raw
            .split('\n')
            .map((s) => s.replaceAll('•', '').trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return [];
    }

    final rawPrice = json['price'];
    double p = 0.0;
    if (rawPrice is num) {
      p = rawPrice.toDouble();
    } else if (rawPrice is String) {
      p = double.tryParse(rawPrice.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
    }

    final rawImg = (json['image_url'] as String?) ?? (json['imageUrl'] as String?);
    final validImg = (rawImg != null && rawImg.trim().isNotEmpty)
        ? rawImg.trim()
        : 'https://images.unsplash.com/photo-1544025162-d76694265947?w=1200&q=80';

    return PackageModel(
      id: json['id']?.toString() ?? '',
      title: (json['title'] as String?) ?? (json['name'] as String?) ?? 'VIP Package',
      subtitle: (json['subtitle'] as String?) ??
          (json['guest_count'] != null
              ? '${json['guest_count']} • Full Service'
              : 'Exclusive VIP Hospitality'),
      description: (json['description'] as String?) ?? '',
      price: p,
      priceFormatted: (json['price_formatted'] as String?) ??
          (p > 0 ? '£${p.toStringAsFixed(2)}' : 'Enquire for Price'),
      imageUrl: validImg,
      badge: json['badge'] as String?,
      guestCount: (json['guest_count'] as String?) ?? '4–8 Guests',
      inclusions: parseList(json['items'] ?? json['inclusions'] ?? json['features']),
      branchId: json['branch_id'] is int
          ? json['branch_id']
          : int.tryParse(json['branch_id']?.toString() ?? ''),
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: json['display_order'] is int
          ? json['display_order']
          : int.tryParse(json['display_order']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'description': description,
        'price': price,
        'price_formatted': priceFormatted,
        'image_url': imageUrl,
        'badge': badge,
        'guest_count': guestCount,
        'items': inclusions,
        'branch_id': branchId,
        'is_active': isActive,
        'display_order': displayOrder,
      };

  static List<PackageModel> defaultPackages({int? branchId}) {
    final all = [
      const PackageModel(
        id: 'default-pkg-01',
        title: 'Celebration & Birthday Package',
        subtitle: 'For Groups of 4-8 Guests',
        description:
            'Celebrate your special occasion in style with dedicated lounge service and champagne.',
        price: 150.0,
        priceFormatted: '£150.00',
        imageUrl:
            'https://images.unsplash.com/photo-1544025162-d76694265947?w=1200&q=80',
        badge: 'MOST POPULAR',
        guestCount: '4–8 Guests',
        inclusions: [
          '2x Signature Shishas of your choice',
          '2x Grande Shared Food Platters',
          '1x Bottle of Moët & Chandon Champagne',
          'Birthday sparklers & celebration dessert',
        ],
      ),
    ];

    if (branchId == null) return all;
    return all.where((p) => p.branchId == null || p.branchId == branchId).toList();
  }
}
