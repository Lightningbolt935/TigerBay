import 'package:flutter/foundation.dart';

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

  /// Formatted date for display (e.g., "30 Sep 2026").
  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${bookingDate.day} ${months[bookingDate.month - 1]} ${bookingDate.year}';
  }

  /// Formatted time displaying only hours and minutes (e.g., "20:00" or "8:00 PM").
  String get formattedTime {
    if (bookingTime.trim().isEmpty) return '';
    final parts = bookingTime.trim().split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]) ?? 0;
      final minute = parts[1].padLeft(2, '0');
      // For 24-hr format:
      return '${hour.toString().padLeft(2, '0')}:$minute';
      
      // If you prefer 12-hour AM/PM format (e.g., "8:00 PM"), uncomment below:
      // final period = hour >= 12 ? 'PM' : 'AM';
      // final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      // return '$displayHour:$minute $period';
    }
    return bookingTime;
  }

  /// Combines `bookingDate` and `bookingTime` into a single DateTime.
  DateTime get fullDateTime {
    int hour = 0;
    int minute = 0;
    if (bookingTime.isNotEmpty) {
      final parts = bookingTime.split(':');
      if (parts.isNotEmpty) hour = int.tryParse(parts[0]) ?? 0;
      if (parts.length > 1) minute = int.tryParse(parts[1]) ?? 0;
    }
    return DateTime(
      bookingDate.year,
      bookingDate.month,
      bookingDate.day,
      hour,
      minute,
    );
  }

  /// Verifies both status and that the reservation timestamp is strictly in the future.
  bool get isUpcomingFuture {
    if (status != BookingStatus.upcoming) return false;
    return fullDateTime.isAfter(DateTime.now());
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
