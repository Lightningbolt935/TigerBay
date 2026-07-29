/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — BookingModel
/// ═══════════════════════════════════════════════════════════════════════════
/// Maps to `public.bookings`. Updated to use int PKs/FKs matching BIGINT
/// columns, separate booking_time field, and strips_awarded flag.
class BookingModel {
  final int id;
  final String userId;
  final int branchId;
  final String branchName;
  final DateTime bookingDate;
  final String bookingTime;
  final int guestCount;
  final BookingStatus status;
  final bool stripsAwarded;
  final String? specialRequests;
  final DateTime createdAt;

  const BookingModel({
    required this.id,
    required this.userId,
    required this.branchId,
    this.branchName = '',
    required this.bookingDate,
    required this.bookingTime,
    required this.guestCount,
    required this.status,
    this.stripsAwarded = false,
    this.specialRequests,
    required this.createdAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: _safeInt(json['id']) ?? 0,
      userId: (json['user_id'] as String?) ?? '',
      branchId: _safeInt(json['branch_id']) ?? 0,
      branchName: (json['branch_name'] as String?) ?? '',
      bookingDate: json['booking_date'] != null
          ? DateTime.tryParse(json['booking_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      bookingTime: (json['booking_time'] as String?) ?? '',
      guestCount: _safeInt(json['guest_count']) ?? 1,
      status: BookingStatus.fromString(
          (json['status'] as String?) ?? 'upcoming'),
      stripsAwarded: (json['strips_awarded'] as bool?) ?? false,
      specialRequests: json['special_requests'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'branch_id': branchId,
        'branch_name': branchName,
        'booking_date': bookingDate.toIso8601String().substring(0, 10),
        'booking_time': bookingTime,
        'guest_count': guestCount,
        'status': status.value,
        'strips_awarded': stripsAwarded,
        'special_requests': specialRequests,
        'created_at': createdAt.toIso8601String(),
      };

  BookingModel copyWith({
    BookingStatus? status,
    bool? stripsAwarded,
    String? specialRequests,
  }) {
    return BookingModel(
      id: id,
      userId: userId,
      branchId: branchId,
      branchName: branchName,
      bookingDate: bookingDate,
      bookingTime: bookingTime,
      guestCount: guestCount,
      status: status ?? this.status,
      stripsAwarded: stripsAwarded ?? this.stripsAwarded,
      specialRequests: specialRequests ?? this.specialRequests,
      createdAt: createdAt,
    );
  }

  /// Formatted date for display.
  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${bookingDate.day} ${months[bookingDate.month - 1]} ${bookingDate.year}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookingModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  static int? _safeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

enum BookingStatus {
  upcoming('upcoming'),
  past('past'),
  cancelled('cancelled');

  final String value;
  const BookingStatus(this.value);

  static BookingStatus fromString(String s) {
    return BookingStatus.values.firstWhere(
      (e) => e.value == s.toLowerCase(),
      orElse: () => BookingStatus.upcoming,
    );
  }

  String get displayName => value[0].toUpperCase() + value.substring(1);
}
