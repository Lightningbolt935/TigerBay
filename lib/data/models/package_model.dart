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
  });

  factory PackageModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
      }
      if (raw is String && raw.isNotEmpty) {
        return raw.split('\n').map((s) => s.replaceAll('•', '').trim()).where((s) => s.isNotEmpty).toList();
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
      id: json['id']?.toString() ?? '0',
      title: (json['title'] as String?) ?? (json['name'] as String?) ?? 'VIP Package',
      subtitle: (json['subtitle'] as String?) ??
          (json['guest_count'] != null
              ? '${json['guest_count']} • Full Service'
              : 'Exclusive VIP Hospitality'),
      description: (json['description'] as String?) ?? '',
      price: p,
      priceFormatted: (json['price_formatted'] as String?) ??
          (p > 0 ? '£${p.toStringAsFixed(0)}' : 'Enquire for Price'),
      imageUrl: validImg,
      badge: json['badge'] as String?,
      guestCount: (json['guest_count'] as String?) ?? '4–8 Guests',
      inclusions: parseList(json['inclusions'] ?? json['features'] ?? json['items']),
      branchId: json['branch_id'] as int?,
      isActive: json['is_active'] as bool? ?? true,
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
        'inclusions': inclusions,
        'branch_id': branchId,
        'is_active': isActive,
      };

  /// Luxury fallback packages curated for Tiger Bay International
  static List<PackageModel> defaultPackages({int? branchId}) {
    final all = [
      const PackageModel(
        id: '201',
        title: 'Tiger VIP Shisha & Bottle Lounge Package',
        subtitle: '4–6 Guests • Priority Velvet Booth',
        description:
            'The signature Tiger Bay evening experience. Settle into our finest velvet booth with handcrafted shisha, sparkler bottle service, and sharing chef platters.',
        price: 150.0,
        priceFormatted: '£150',
        imageUrl:
            'https://images.unsplash.com/photo-1544025162-d76694265947?w=1200&q=80',
        badge: 'MOST POPULAR',
        guestCount: '4–6 Guests',
        inclusions: [
          '2 Premium Exotic Savacco or Al Fakher Shishas',
          'Unlimited natural coconut charcoal & head refresh',
          '1 Bottle of Moët & Chandon Champagne or Premium Spirit',
          '3-Hour VIP Velvet Booth reservation',
          'Complimentary Chef Signature Starter Platter',
        ],
      ),
      const PackageModel(
        id: '202',
        title: 'Birthday & Celebration Extravaganza',
        subtitle: '6–10 Guests • VIP Host & Sparklers',
        description:
            'Celebrate in grandeur. Complete celebration setup with sparkler bottle presentations, multi-tier dessert platters, custom booth decor, and priority venue entry.',
        price: 250.0,
        priceFormatted: '£250',
        imageUrl:
            'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=1200&q=80',
        badge: 'CELEBRATIONS',
        guestCount: '6–10 Guests',
        inclusions: [
          'Dedicated VIP Host & Priority Red Carpet Entrance',
          '3 Luxury Multi-Hose Shishas with fresh fruit heads',
          '2 Bottles of Premium Spirits or Champagne with mixers',
          'Chef Gourmet Grill Platter Feast for the party',
          'Signature Tiger Bay Sparkler Dessert Celebration Tray',
          'Personalized birthday booth display setup',
        ],
      ),
      const PackageModel(
        id: '203',
        title: 'Executive Shisha & Dining Experience',
        subtitle: '2–3 Guests • Intimate Luxury',
        description:
            'A refined, intimate evening for couples or small parties. Features an exotic fresh-fruit shisha setup paired with culinary master grills and handcrafted mocktails.',
        price: 85.0,
        priceFormatted: '£85',
        imageUrl:
            'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=1200&q=80',
        badge: 'DATE NIGHT',
        guestCount: '2–3 Guests',
        inclusions: [
          '1 Exotic Fresh Fruit Head Shisha (Pineapple/Watermelon)',
          'Master Chef Grill Platter for Two',
          '2 Handcrafted Artisan Mocktails or Premium Soft Beverages',
          'Reserved prime booth seating',
        ],
      ),
      const PackageModel(
        id: '204',
        title: 'Royal Gold Private Sector Hire',
        subtitle: '12–30 Guests • Exclusive Sector Access',
        description:
            'Take complete private ownership of a dedicated sector in our heated outdoor canopy or VIP indoor lounge for corporate events, wrap parties, or major family milestones.',
        price: 500.0,
        priceFormatted: '£500+',
        imageUrl:
            'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=1200&q=80',
        badge: 'EXCLUSIVE HIRE',
        guestCount: '12–30 Guests',
        inclusions: [
          'Exclusive roped-off sector access for entire evening',
          'Dedicated Shisha Master & Waitstaff team',
          'Tailored food & drink catering package',
          'Bespoke music & audio control available upon request',
          'Complimentary event photographer coordination',
        ],
      ),
    ];

    if (branchId == null) return all;
    return all.where((p) => p.branchId == null || p.branchId == branchId).toList();
  }
}
