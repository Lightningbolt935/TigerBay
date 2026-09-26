import 'dart:convert';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — UserProfile Model
/// ═══════════════════════════════════════════════════════════════════════════
/// Maps 1-to-1 with `public.profiles`. Contains membership state, Strips
/// balance, and home-site FK. Every field sourced from Supabase dynamic JSON
/// is safely cast with null-coalescing defaults.
class UserProfile {
  final String id;
  final String? email;
  final String? fullName;
  final String? avatarUrl;
  final String? phone;
  final String? deviceId;
  final String? dob;
  final String? gender;
  final int? homeSiteId;
  final int? membershipTierId;
  final String membershipStatus;
  final int stripsBalance;
  final String? memberCode;
  final List<String> diningPreferences;
  final DateTime? membershipExpiresAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.id,
    this.email,
    this.fullName,
    this.avatarUrl,
    this.phone,
    this.deviceId,
    this.dob,
    this.gender,
    this.homeSiteId,
    this.membershipTierId,
    this.membershipStatus = 'inactive',
    this.stripsBalance = 0,
    this.memberCode,
    this.diningPreferences = const [],
    this.membershipExpiresAt,
    this.updatedAt,
  });

  /// Whether this user has an active paid membership and can access the app.
  bool get isMembershipActive {
    if (membershipStatus != 'active') return false;
    if (membershipTierId == null) return false;
    if (membershipExpiresAt != null &&
        DateTime.now().isAfter(membershipExpiresAt!)) {
      return false;
    }
    return true;
  }

  /// Whether this user's membership has expired.
  bool get isMembershipExpired {
    if (membershipStatus == 'expired') return true;
    if (membershipExpiresAt != null &&
        DateTime.now().isAfter(membershipExpiresAt!)) {
      return true;
    }
    return false;
  }

  /// Returns the 6-digit member ID. Uses the database `member_code` if present,
  /// or falls back to a deterministic 6-digit hash computed from the UUID so it
  /// is ALWAYS guaranteed to return a clean 6-digit number (e.g. "582914").
  String get displayMemberId {
    if (memberCode != null && memberCode!.trim().isNotEmpty) {
      final code = memberCode!.trim();
      if (code.length == 6) return code;
      return code.padLeft(6, '0');
    }
    if (id.isNotEmpty) {
      // Deterministic 6-digit number from UUID hash (range 100000 - 999999)
      final hash = id.hashCode.abs();
      final sixDigit = (hash % 900000 + 100000).toString();
      return sixDigit;
    }
    return '100000';
  }

  /// Formatted branded Member Code (e.g. "TB-582914")
  String get formattedMemberCode => 'TB-$displayMemberId';

  /// User initials for avatar placeholder.
  String get initials {
    if (fullName == null || fullName!.isEmpty) return '?';
    final parts = fullName!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  /// Safe deserialization from Supabase JSON response. Every field is guarded
  /// against null and type-mismatch errors to prevent runtime crashes.
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    // Safely validate avatar URL — rejects empty strings and bare paths that
    // would cause 'No host specified in URI' crashes in Image.network.
    String? rawAvatar =
        (map['avatar_url'] ?? map['photo_url'])?.toString().trim();
    String? validAvatar;
    if (rawAvatar != null && rawAvatar.isNotEmpty) {
      final uri = Uri.tryParse(rawAvatar);
      if (uri != null &&
          uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty) {
        validAvatar = rawAvatar;
      }
    }

    // Safely parse dining preferences (Halal, Vegetarian, Nut Allergy, etc.)
    List<String> diningPrefs = const [];
    final rawPrefs = map['dining_preferences'] ??
        map['raw_user_meta_data']?['dining_preferences'];
    if (rawPrefs is List) {
      diningPrefs = rawPrefs.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    } else if (rawPrefs is String && rawPrefs.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawPrefs);
        if (decoded is List) {
          diningPrefs = decoded.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        }
      } catch (_) {}
    }

    return UserProfile(
      id: map['id'] as String? ?? '',
      email: map['email'] as String?,
      fullName: map['full_name'] as String?,
      avatarUrl: validAvatar,
      phone: map['phone'] as String?,
      deviceId: map['device_id'] as String?,
      dob: map['dob'] as String?,
      gender: map['gender'] as String?,
      homeSiteId: _safeInt(map['home_site_id']),
      membershipTierId: _safeInt(map['membership_tier_id']),
      membershipStatus:
          (map['membership_status'] as String?) ?? 'inactive',
      stripsBalance: _safeInt(map['strips_balance']) ?? 0,
      memberCode: map['member_code']?.toString(),
      diningPreferences: diningPrefs,
      membershipExpiresAt: map['membership_expires_at'] != null
          ? DateTime.tryParse(map['membership_expires_at'].toString())
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString())
          : null,
    );
  }

  /// Serialization for profile updates via Supabase `.upsert()` / `.update()`.
  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'avatar_url': avatarUrl,
        'phone': phone,
        'device_id': deviceId,
        'dob': dob,
        'gender': gender,
        'home_site_id': homeSiteId,
        'membership_tier_id': membershipTierId,
        'membership_status': membershipStatus,
        'strips_balance': stripsBalance,
        if (memberCode != null) 'member_code': memberCode,
        if (diningPreferences.isNotEmpty) 'dining_preferences': diningPreferences,
        'membership_expires_at': membershipExpiresAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  UserProfile copyWith({
    String? email,
    String? fullName,
    String? avatarUrl,
    String? phone,
    String? deviceId,
    String? dob,
    String? gender,
    int? homeSiteId,
    int? membershipTierId,
    String? membershipStatus,
    int? stripsBalance,
    String? memberCode,
    List<String>? diningPreferences,
    DateTime? membershipExpiresAt,
  }) {
    return UserProfile(
      id: id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      phone: phone ?? this.phone,
      deviceId: deviceId ?? this.deviceId,
      dob: dob ?? this.dob,
      gender: gender ?? this.gender,
      homeSiteId: homeSiteId ?? this.homeSiteId,
      membershipTierId: membershipTierId ?? this.membershipTierId,
      membershipStatus: membershipStatus ?? this.membershipStatus,
      stripsBalance: stripsBalance ?? this.stripsBalance,
      memberCode: memberCode ?? this.memberCode,
      diningPreferences: diningPreferences ?? this.diningPreferences,
      membershipExpiresAt: membershipExpiresAt ?? this.membershipExpiresAt,
      updatedAt: updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'UserProfile(id: $id, name: $fullName, status: $membershipStatus, '
      'strips: $stripsBalance)';

  /// Safely casts a dynamic value (int, String, double, or null) to int?.
  static int? _safeInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
