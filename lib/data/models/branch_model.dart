import 'package:flutter/foundation.dart';

@immutable
class Branch {
  final int id;
  final String title;
  final String name;
  final String imageUrl;
  final String? city;
  final String? address;
  final bool isActive;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? openingTime;
  final String? closingTime;
  final String? openingHours;
  final List<String> images;
  final String? description;
  final DateTime? createdAt;

  final String? websiteUrl;
  final String? mapsUrl;

  const Branch({
    required this.id,
    required this.title,
    String? name,
    required this.imageUrl,
    this.city,
    this.address,
    this.isActive = true,
    this.latitude,
    this.longitude,
    this.phone,
    this.whatsapp,
    this.email,
    this.openingTime,
    this.closingTime,
    this.openingHours,
    this.websiteUrl,
    this.mapsUrl,
    this.images = const [],
    this.description,
    this.createdAt,
  }) : name = name ?? title;

  /// Effective address with accurate London fallbacks per venue
  String get addressFormatted {
    if (address != null && address!.trim().isNotEmpty) {
      return address!;
    }
    switch (id) {
      case 3:
        return 'Twyford Abbey Rd, London NW10 7DS';
      case 2:
        return '145–149 The Broadway, Burnt Oak, Edgware, HA8 5EJ';
      case 1:
        return 'High St, Hounslow TW3 1RH';
      case 4:
        return 'Great Cambridge Rd, Enfield EN1 3HN';
      default:
        return '$title, London, United Kingdom';
    }
  }

  /// Effective Latitude for Maps integration
  double get effectiveLatitude {
    if (latitude != null &&
        latitude != 0.0 &&
        (latitude! - 12.82186).abs() > 0.001 &&
        (latitude! - 37.4219983).abs() > 0.001) {
      return latitude!;
    }
    switch (id) {
      case 3:
        return 51.5312; // Hanger Lane
      case 2:
        return 51.6033; // Kingsbury
      case 1:
        return 51.4687; // Hounslow
      case 4:
        return 51.6521; // Enfield
      default:
        return 51.5074; // London Center
    }
  }

  /// Effective Longitude for Maps integration
  double get effectiveLongitude {
    if (longitude != null &&
        longitude != 0.0 &&
        (longitude! - 80.02586).abs() > 0.001 &&
        (longitude! - (-122.084)).abs() > 0.001) {
      return longitude!;
    }
    switch (id) {
      case 3:
        return -0.2891; // Hanger Lane
      case 2:
        return -0.2684; // Kingsbury
      case 1:
        return -0.3610; // Hounslow
      case 4:
        return -0.0655; // Enfield
      default:
        return -0.1278; // London Center
    }
  }

  /// Official phone number for call service
  String get phoneFormatted {
    if (phone != null && phone!.trim().isNotEmpty) {
      return phone!;
    }
    switch (id) {
      case 2:
        return '07488 880203'; // Kingsbury
      case 4:
        return '020 3946 8684'; // Enfield
      case 3:
        return '07927 333319'; // Hangerlane
      case 1:
        return '020 8054 7241'; // Hounslow
      default:
        return '07488 880203';
    }
  }

  /// Clean digits for dialer/WhatsApp URLs
  String get cleanPhoneNumber =>
      phoneFormatted.replaceAll(RegExp(r'[^\d+]'), '');

  /// WhatsApp number (defaults to official Tiger Bay WhatsApp concierge 447598819733 or branch Supabase value)
  String get whatsappNumber =>
      (whatsapp != null && whatsapp!.trim().isNotEmpty)
          ? whatsapp!.replaceAll(RegExp(r'[^\d]'), '')
          : '447598819733';

  /// Generates direct WhatsApp chat URL for this venue
  String whatsappChatUrl({String? customMessage}) {
    final phone = whatsappNumber;
    final venueTitle = title.isNotEmpty ? title : 'Kingsbury';
    final msg = customMessage ?? "Hi I'd like to make a Enquiry for Tigerbay $venueTitle";
    final encoded = Uri.encodeComponent(msg);
    return 'https://api.whatsapp.com/send/?phone=$phone&text=$encoded&type=phone_number&app_absent=0';
  }

  /// Official Website URL
  String get effectiveWebsite {
    if (websiteUrl != null && websiteUrl!.trim().isNotEmpty) {
      return websiteUrl!;
    }
    switch (id) {
      case 2:
        return 'http://www.tigerbayshisha.co.uk/';
      case 4:
        return 'http://www.tigerbayenfield.co.uk/';
      case 3:
        return 'http://www.tigerbayhangerlane.co.uk/';
      case 1:
        return 'http://www.tigerbayhounslow.co.uk/';
      default:
        return 'http://www.tigerbayshisha.co.uk/';
    }
  }

  /// Support and booking email address
  String get supportEmail => 'bookings@tigerbayshisha.co.uk';

  /// Today's opening and closing hours
  String get todayHoursFormatted {
    final now = DateTime.now();
    final weekday = now.weekday; // 1 = Mon, 7 = Sun
    final schedule = weeklySchedule;
    final days = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    return schedule[days[weekday - 1]] ?? (openingHours ?? '12:00 PM – 3:30 AM');
  }

  /// Full weekly timing schedule breakdown matching official venue specs
  Map<String, String> get weeklySchedule {
    switch (id) {
      case 2: // Kingsbury (Sun-Thu: 12pm-3:30am, Fri-Sat: 12pm-05:00am)
        return const {
          'Monday': '12:00 PM – 3:30 AM',
          'Tuesday': '12:00 PM – 3:30 AM',
          'Wednesday': '12:00 PM – 3:30 AM',
          'Thursday': '12:00 PM – 3:30 AM',
          'Friday': '12:00 PM – 5:00 AM',
          'Saturday': '12:00 PM – 5:00 AM',
          'Sunday': '12:00 PM – 3:30 AM',
        };
      case 4: // Enfield (Sun-Wed: 12pm-3:30am, Thu-Sat: 12pm-05:00am)
        return const {
          'Monday': '12:00 PM – 3:30 AM',
          'Tuesday': '12:00 PM – 3:30 AM',
          'Wednesday': '12:00 PM – 3:30 AM',
          'Thursday': '12:00 PM – 5:00 AM',
          'Friday': '12:00 PM – 5:00 AM',
          'Saturday': '12:00 PM – 5:00 AM',
          'Sunday': '12:00 PM – 3:30 AM',
        };
      case 3: // Hangerlane (Sun-Thu: 12pm-3:30am, Fri-Sat: 12pm-4:30am)
        return const {
          'Monday': '12:00 PM – 3:30 AM',
          'Tuesday': '12:00 PM – 3:30 AM',
          'Wednesday': '12:00 PM – 3:30 AM',
          'Thursday': '12:00 PM – 3:30 AM',
          'Friday': '12:00 PM – 4:30 AM',
          'Saturday': '12:00 PM – 4:30 AM',
          'Sunday': '12:00 PM – 3:30 AM',
        };
      case 1: // Hounslow (Sun-Thu: 12pm-3:00am, Fri-Sat: 12pm-4:00am)
        return const {
          'Monday': '12:00 PM – 3:00 AM',
          'Tuesday': '12:00 PM – 3:00 AM',
          'Wednesday': '12:00 PM – 3:00 AM',
          'Thursday': '12:00 PM – 3:00 AM',
          'Friday': '12:00 PM – 4:00 AM',
          'Saturday': '12:00 PM – 4:00 AM',
          'Sunday': '12:00 PM – 3:00 AM',
        };
      default:
        return const {
          'Monday': '12:00 PM – 3:30 AM',
          'Tuesday': '12:00 PM – 3:30 AM',
          'Wednesday': '12:00 PM – 3:30 AM',
          'Thursday': '12:00 PM – 3:30 AM',
          'Friday': '12:00 PM – 5:00 AM',
          'Saturday': '12:00 PM – 5:00 AM',
          'Sunday': '12:00 PM – 3:30 AM',
        };
    }
  }

  /// Live calculation whether the venue is currently open (12:00 PM to late night)
  bool get isOpenNow {
    final now = DateTime.now();
    final hour = now.hour;
    // Venues open at 12:00 PM and stay open until 3:00 AM – 5:00 AM
    if (hour >= 12 || hour < 4) {
      return true;
    }
    return false;
  }

  /// Status badge label with live status
  String get statusBadgeText => isOpenNow ? 'OPEN NOW' : 'OPENS AT 12 PM';


  static const List<String> kingsburyLuxuryImages = [
    'https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=1200&q=80',
    'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=1200&q=80',
    'https://images.unsplash.com/photo-1514933651103-005eec06c04b?w=1200&q=80',
  ];

  /// Effective 3-image carousel URLs for showcasing the venue
  List<String> get effectiveImages {
    if (id == 2) {
      // Flagship Kingsbury: Premium Mayfair VIP lounge imagery
      return kingsburyLuxuryImages;
    }
    // Filter out unwanted spa/meeting room placeholders
    final filtered = images.where((u) => !u.contains('1544161515')).toList();
    if (filtered.isNotEmpty) {
      if (filtered.length >= 3) return filtered.take(3).toList();
      final list = List<String>.from(filtered);
      while (list.length < 3) {
        list.add(imageUrl.isNotEmpty ? imageUrl : list.first);
      }
      return list;
    }
    if (imageUrl.isNotEmpty) {
      return [
        imageUrl,
        _defaultImagesForVenue(id)[1],
        _defaultImagesForVenue(id)[2],
      ];
    }
    return _defaultImagesForVenue(id);
  }

  static List<String> _defaultImagesForVenue(int id) {
    switch (id) {
      case 3: // Hanger Lane
        return const [
          'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=1200&q=80',
          'https://images.unsplash.com/photo-1544025162-d76694265947?w=1200&q=80',
          'https://images.unsplash.com/photo-1578474846511-04ba529f0b88?w=1200&q=80',
        ];
      case 2: // Kingsbury
        return kingsburyLuxuryImages;
      case 1: // Hounslow
        return const [
          'https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=1200&q=80',
          'https://images.unsplash.com/photo-1552566626-52f8b828add9?w=1200&q=80',
          'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=1200&q=80',
        ];
      case 4: // Enfield
        return const [
          'https://images.unsplash.com/photo-1525610553991-2bede1a236e2?w=1200&q=80',
          'https://images.unsplash.com/photo-1560624052-449f5ddf0c31?w=1200&q=80',
          'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=1200&q=80',
        ];
      default:
        return const [
          'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=1200&q=80',
          'https://images.unsplash.com/photo-1544025162-d76694265947?w=1200&q=80',
          'https://images.unsplash.com/photo-1578474846511-04ba529f0b88?w=1200&q=80',
        ];
    }
  }

  /// Google Maps query link
  String get googleMapsUrl {
    if (mapsUrl != null && mapsUrl!.trim().isNotEmpty) {
      return mapsUrl!;
    }
    return 'https://www.google.com/maps/search/?api=1&query=$effectiveLatitude,$effectiveLongitude';
  }

  factory Branch.fromJson(Map<String, dynamic> json) {
    List<String> parseImages(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw
            .map((e) => e.toString().trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      if (raw is String && raw.trim().isNotEmpty) {
        final str = raw.trim();
        if (str.startsWith('[') && str.endsWith(']')) {
          try {
            final inner = str.substring(1, str.length - 1);
            return inner
                .split(',')
                .map((s) => s.replaceAll('"', '').replaceAll("'", '').trim())
                .where((s) => s.isNotEmpty)
                .toList();
          } catch (_) {}
        }
        return str
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return [];
    }

    return Branch(
      id: json['id'] as int,
      title: (json['title'] as String?) ?? (json['name'] as String?) ?? 'Tiger Bay',
      name: (json['name'] as String?) ?? (json['title'] as String?) ?? 'Tiger Bay',
      imageUrl: (json['image_url'] as String?) ?? '',
      city: json['city'] as String?,
      address: json['address'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      phone: (json['phone'] as String?) ?? (json['support_phone'] as String?),
      whatsapp: (json['whatsapp'] as String?) ?? (json['support_whatsapp'] as String?),
      email: (json['email'] as String?) ?? (json['support_email'] as String?),
      openingTime: (json['opening_time'] as String?) ?? (json['opens_at'] as String?),
      closingTime: (json['closing_time'] as String?) ?? (json['closes_at'] as String?),
      openingHours: (json['opening_hours'] as String?) ?? (json['hours'] as String?),
      websiteUrl: json['website_url'] as String?,
      mapsUrl: json['maps_url'] as String?,
      images: parseImages(
        json['images'] ??
            json['gallery_images'] ??
            json['photos'] ??
            json['image_urls'],
      ),
      description: (json['description'] as String?) ?? (json['about'] as String?),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'name': name,
        'image_url': imageUrl,
        'city': city,
        'address': address,
        'is_active': isActive,
        'latitude': latitude,
        'longitude': longitude,
        'phone': phone,
        'whatsapp': whatsapp,
        'email': email,
        'opening_time': openingTime,
        'closing_time': closingTime,
        'opening_hours': openingHours,
        'website_url': websiteUrl,
        'maps_url': mapsUrl,
        'images': images,
        'description': description,
        'created_at': createdAt?.toIso8601String(),
      };

  Branch copyWith({
    int? id,
    String? title,
    String? name,
    String? imageUrl,
    String? city,
    String? address,
    bool? isActive,
    double? latitude,
    double? longitude,
    String? phone,
    String? whatsapp,
    String? email,
    String? openingTime,
    String? closingTime,
    String? openingHours,
    String? websiteUrl,
    String? mapsUrl,
    List<String>? images,
    String? description,
    DateTime? createdAt,
  }) =>
      Branch(
        id: id ?? this.id,
        title: title ?? this.title,
        name: name ?? this.name,
        imageUrl: imageUrl ?? this.imageUrl,
        city: city ?? this.city,
        address: address ?? this.address,
        isActive: isActive ?? this.isActive,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        phone: phone ?? this.phone,
        whatsapp: whatsapp ?? this.whatsapp,
        email: email ?? this.email,
        openingTime: openingTime ?? this.openingTime,
        closingTime: closingTime ?? this.closingTime,
        openingHours: openingHours ?? this.openingHours,
        websiteUrl: websiteUrl ?? this.websiteUrl,
        mapsUrl: mapsUrl ?? this.mapsUrl,
        images: images ?? this.images,
        description: description ?? this.description,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  bool operator ==(Object other) => other is Branch && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Branch(id: $id, title: $title)';

  static const List<Branch> defaultBranches = [
    Branch(
      id: 2,
      title: 'Kingsbury',
      imageUrl: '',
      city: 'London',
      address: '145–149 The Broadway, Burnt Oak, Edgware, HA8 5EJ',
      isActive: true,
      latitude: 51.6033,
      longitude: -0.2684,
      phone: '07488 880203',
      websiteUrl: 'http://www.tigerbayshisha.co.uk/',
      mapsUrl: 'https://maps.google.com/?q=Tigerbay+Kingsbury+HA8+5EJ',
      openingHours: 'Sunday - Thursday : 12pm - 3:30am\nFriday - Saturday : 12pm - 05:00am',
    ),
    Branch(
      id: 4,
      title: 'Enfield',
      imageUrl: '',
      city: 'London',
      address: 'Great Cambridge Rd, Enfield EN1 3HN',
      isActive: true,
      latitude: 51.6521,
      longitude: -0.0655,
      phone: '020 3946 8684',
      websiteUrl: 'http://www.tigerbayenfield.co.uk/',
      mapsUrl: 'https://maps.google.com/?q=Tigerbay+Enfield+EN1+3HN',
      openingHours: 'Sunday - Wednesday : 12pm - 3:30am\nThursday - Saturday : 12pm - 05:00am',
    ),
    Branch(
      id: 3,
      title: 'Hanger Lane',
      imageUrl: '',
      city: 'London',
      address: 'Twyford Abbey Rd, London NW10 7DS',
      isActive: true,
      latitude: 51.5312,
      longitude: -0.2891,
      phone: '07927 333319',
      websiteUrl: 'http://www.tigerbayhangerlane.co.uk/',
      mapsUrl: 'https://maps.google.com/?q=Tigerbay+Hanger+Lane+NW10+7DS',
      openingHours: 'Sunday - Thursday : 12pm - 3:30am\nFriday - Saturday : 12pm - 4:30am',
    ),
    Branch(
      id: 1,
      title: 'Hounslow',
      imageUrl: '',
      city: 'London',
      address: 'High St, Hounslow TW3 1RH',
      isActive: true,
      latitude: 51.4687,
      longitude: -0.3610,
      phone: '020 8054 7241',
      websiteUrl: 'http://www.tigerbayhounslow.co.uk/',
      mapsUrl: 'https://maps.google.com/?q=Tigerbay+Hounslow+TW3+1RH',
      openingHours: 'Sunday - Thursday : 12pm - 3:00am\nFriday - Saturday : 12pm - 4:00am',
    ),
  ];


  static Branch get kingsbury =>
      defaultBranches.firstWhere((b) => b.id == 2, orElse: () => defaultBranches.first);
  static Branch get hangerLane =>
      defaultBranches.firstWhere((b) => b.id == 3, orElse: () => defaultBranches.first);
  static Branch get hounslow =>
      defaultBranches.firstWhere((b) => b.id == 1, orElse: () => defaultBranches.first);
  static Branch get enfield =>
      defaultBranches.firstWhere((b) => b.id == 4, orElse: () => defaultBranches.first);
}
