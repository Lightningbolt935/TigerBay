/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — MembershipTier Model
/// ═══════════════════════════════════════════════════════════════════════════
/// Maps 1-to-1 with `public.membership_tiers`. Contains the five paid tiers:
/// Bronze, Silver, Gold, Platinum, Black Diamond. Each tier has a real-money
/// price and a Strips-per-booking multiplier rate.
class MembershipTier {
  final int id;
  final String name;
  final int tierLevel;
  final double price;
  final int stripsPerBooking;
  final List<String> benefits;

  const MembershipTier({
    required this.id,
    required this.name,
    required this.tierLevel,
    required this.price,
    required this.stripsPerBooking,
    required this.benefits,
  });

  /// Safe deserialization from Supabase JSON response.
  factory MembershipTier.fromMap(Map<String, dynamic> map) {
    return MembershipTier(
      id: _safeInt(map['id']) ?? 0,
      name: (map['name'] as String?) ?? 'TIER',
      tierLevel: _safeInt(map['tier_level']) ?? 1,
      price: _safeDouble(map['price']) ?? 0.0,
      stripsPerBooking: _safeInt(map['strips_per_booking']) ?? 1,
      benefits: _safeStringList(map['benefits']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'tier_level': tierLevel,
        'price': price,
        'strips_per_booking': stripsPerBooking,
        'benefits': benefits,
      };

  MembershipTier copyWith({
    int? id,
    String? name,
    int? tierLevel,
    double? price,
    int? stripsPerBooking,
    List<String>? benefits,
  }) {
    return MembershipTier(
      id: id ?? this.id,
      name: name ?? this.name,
      tierLevel: tierLevel ?? this.tierLevel,
      price: price ?? this.price,
      stripsPerBooking: stripsPerBooking ?? this.stripsPerBooking,
      benefits: benefits ?? this.benefits,
    );
  }

  /// Formatted price string for display.
  String get formattedPrice => '£${price.toStringAsFixed(2)}';

  /// Human-readable strips earning description.
  String get stripsRateDescription =>
      'Earns $stripsPerBooking Strip${stripsPerBooking == 1 ? '' : 's'} per reservation';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MembershipTier &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'MembershipTier(id: $id, name: $name, level: $tierLevel, '
      'price: $price, strips: $stripsPerBooking)';

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

  static List<String> _safeStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
}
