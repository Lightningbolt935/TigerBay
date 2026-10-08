import 'package:flutter/foundation.dart';

@immutable
class WhatsOnEvent {
  final int id;
  final String title;
  final String subtitle;
  final String description;
  final String imageUrl;
  final String dateFormatted;
  final String timeFormatted;
  final int? branchId;
  final String? venueName;
  final String category;
  final bool isFeatured;
  final DateTime? eventDate;

  const WhatsOnEvent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.imageUrl,
    required this.dateFormatted,
    this.timeFormatted = '9:00 PM – Late',
    this.branchId,
    this.venueName,
    this.category = 'Special Event',
    this.isFeatured = false,
    this.eventDate,
  });

  factory WhatsOnEvent.fromJson(Map<String, dynamic> json) {
    return WhatsOnEvent(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      title: (json['title'] as String?) ?? 'Tiger Bay Event',
      subtitle: (json['subtitle'] as String?) ??
          (json['category'] as String?) ??
          'Live Lounge Experience',
      description: (json['description'] as String?) ??
          (json['content'] as String?) ??
          '',
      imageUrl: (json['image_url'] as String?) ??
          (json['imageUrl'] as String?) ??
          '',
      dateFormatted: (json['date_formatted'] as String?) ??
          (json['date'] as String?) ??
          'Every Weekend',
      timeFormatted: (json['time_formatted'] as String?) ??
          (json['time'] as String?) ??
          '9:00 PM – Late',
      branchId: json['branch_id'] as int?,
      venueName: json['venue_name'] as String?,
      category: (json['category'] as String?) ?? 'Special Event',
      isFeatured: (json['is_featured'] as bool?) ??
          (json['is_premium'] as bool?) ??
          false,
      eventDate: json['event_date'] != null
          ? DateTime.tryParse(json['event_date'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'description': description,
        'image_url': imageUrl,
        'date_formatted': dateFormatted,
        'time_formatted': timeFormatted,
        'branch_id': branchId,
        'venue_name': venueName,
        'category': category,
        'is_featured': isFeatured,
        'event_date': eventDate?.toIso8601String(),
      };

  /// Luxury fallback event listings curated for Tiger Bay International
  static List<WhatsOnEvent> defaultEvents({int? branchId}) {
    final all = [
      const WhatsOnEvent(
        id: 101,
        title: 'Weekend Arabic & Afrobeat DJ Sessions',
        subtitle: 'Live Resident DJ & Percussionists',
        description:
            'Immerse in the ultimate weekend luxury vibe with our resident DJs spinning premier Afrobeats, Arabic remixes, and international chartbusters alongside live percussionists.',
        imageUrl:
            'https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=1200&q=80',
        dateFormatted: 'Every Friday & Saturday',
        timeFormatted: '9:30 PM – 2:30 AM',
        category: 'DJ Night',
        isFeatured: true,
      ),
      const WhatsOnEvent(
        id: 102,
        title: 'Premier League & Champions League Live',
        subtitle: 'Giant Ultra-HD 4K Screenings',
        description:
            'Catch every matchday moment in high-energy luxury atmosphere. Watch the biggest football fixtures across multiple ultra-bright laser displays with premium table and shisha service.',
        imageUrl:
            'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?w=1200&q=80',
        dateFormatted: 'Every Matchday & Midweek',
        timeFormatted: 'From 5:00 PM',
        category: 'Live Sports',
        isFeatured: true,
      ),
      const WhatsOnEvent(
        id: 103,
        title: 'Thursday Velvet Ladies Shisha Soirée',
        subtitle: 'Complimentary Mocktails & Master Blends',
        description:
            'An elevated midweek gathering designed exclusively for the ladies. Enjoy master shisha blends crafted with organic fruit heads, complimentary artisan mocktails, and ambient deep house.',
        imageUrl:
            'https://images.unsplash.com/photo-1574096079513-d8259312b785?w=1200&q=80',
        dateFormatted: 'Every Thursday Evening',
        timeFormatted: '6:00 PM – 11:30 PM',
        category: 'Ladies Night',
        isFeatured: false,
      ),
      const WhatsOnEvent(
        id: 104,
        title: 'Sunday Chill & Acoustic Sunset Sessions',
        subtitle: 'Live Instrumentalists & Sunset Shisha',
        description:
            'Wind down your week in pure sophistication. Live acoustic violinists, gentle sax accompaniment, and signature chef dining platters under our heated outdoor pergola.',
        imageUrl:
            'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=1200&q=80',
        dateFormatted: 'Every Sunday',
        timeFormatted: '5:00 PM – 11:00 PM',
        category: 'Live Music',
        isFeatured: false,
      ),
      const WhatsOnEvent(
        id: 105,
        title: 'VIP Saturday Night Fever & Bottle Shows',
        subtitle: 'Sparkler Bottle Service & Velvet Booths',
        description:
            'The pinnacle of London nightlife. Dedicated hostesses, VIP sparkler bottle presentations, signature smoke-bubble mocktails, and high-energy music.',
        imageUrl:
            'https://images.unsplash.com/photo-1492684223066-81342ee5ff30?w=1200&q=80',
        dateFormatted: 'Saturdays',
        timeFormatted: '10:00 PM – 2:30 AM',
        category: 'VIP Exclusive',
        isFeatured: true,
      ),
    ];

    if (branchId == null) return all;
    return all.where((e) => e.branchId == null || e.branchId == branchId).toList();
  }
}
