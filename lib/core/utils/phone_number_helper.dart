/// ═══════════════════════════════════════════════════════════════════════════
/// CountryCode — International Standard Country Dial Model
/// ═══════════════════════════════════════════════════════════════════════════
class CountryCode {
  final String name;
  final String isoCode;
  final String dialCode;
  final String flagEmoji;
  final String example;
  final int minLength;
  final int maxLength;

  const CountryCode({
    required this.name,
    required this.isoCode,
    required this.dialCode,
    required this.flagEmoji,
    required this.example,
    this.minLength = 7,
    this.maxLength = 13,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CountryCode &&
          runtimeType == other.runtimeType &&
          dialCode == other.dialCode &&
          isoCode == other.isoCode;

  @override
  int get hashCode => dialCode.hashCode ^ isoCode.hashCode;

  @override
  String toString() => '$flagEmoji $dialCode ($name)';
}

/// ═══════════════════════════════════════════════════════════════════════════
/// PhoneNumberHelper — E.164 Validation, Trunk Zero Stripping & Parser
/// ═══════════════════════════════════════════════════════════════════════════
class PhoneNumberHelper {
  PhoneNumberHelper._();

  /// Default market for TigerBay is United Kingdom (+44)
  static const CountryCode defaultCountry = CountryCode(
    name: 'United Kingdom',
    isoCode: 'GB',
    dialCode: '+44',
    flagEmoji: '🇬🇧',
    example: '7911 123456',
    minLength: 9,
    maxLength: 10,
  );

  /// Curated list of all supported countries prioritized for hospitality & international guests
  static const List<CountryCode> supportedCountries = [
    CountryCode(name: 'United Kingdom', isoCode: 'GB', dialCode: '+44', flagEmoji: '🇬🇧', example: '7911 123456', minLength: 9, maxLength: 10),
    CountryCode(name: 'United Arab Emirates', isoCode: 'AE', dialCode: '+971', flagEmoji: '🇦🇪', example: '50 123 4567', minLength: 9, maxLength: 9),
    CountryCode(name: 'United States', isoCode: 'US', dialCode: '+1', flagEmoji: '🇺🇸', example: '202 555 0123', minLength: 10, maxLength: 10),
    CountryCode(name: 'Canada', isoCode: 'CA', dialCode: '+1', flagEmoji: '🇨🇦', example: '416 555 0123', minLength: 10, maxLength: 10),
    CountryCode(name: 'India', isoCode: 'IN', dialCode: '+91', flagEmoji: '🇮🇳', example: '98765 43210', minLength: 10, maxLength: 10),
    CountryCode(name: 'Pakistan', isoCode: 'PK', dialCode: '+92', flagEmoji: '🇵🇰', example: '300 1234567', minLength: 10, maxLength: 10),
    CountryCode(name: 'Saudi Arabia', isoCode: 'SA', dialCode: '+966', flagEmoji: '🇸🇦', example: '50 123 4567', minLength: 9, maxLength: 9),
    CountryCode(name: 'Qatar', isoCode: 'QA', dialCode: '+974', flagEmoji: '🇶🇦', example: '3312 3456', minLength: 8, maxLength: 8),
    CountryCode(name: 'Kuwait', isoCode: 'KW', dialCode: '+965', flagEmoji: '🇰🇼', example: '9123 4567', minLength: 8, maxLength: 8),
    CountryCode(name: 'Bahrain', isoCode: 'BH', dialCode: '+973', flagEmoji: '🇧🇭', example: '3612 3456', minLength: 8, maxLength: 8),
    CountryCode(name: 'Oman', isoCode: 'OM', dialCode: '+968', flagEmoji: '🇴🇲', example: '9123 4567', minLength: 8, maxLength: 8),
    CountryCode(name: 'Ireland', isoCode: 'IE', dialCode: '+353', flagEmoji: '🇮🇪', example: '85 123 4567', minLength: 9, maxLength: 9),
    CountryCode(name: 'France', isoCode: 'FR', dialCode: '+33', flagEmoji: '🇫🇷', example: '6 12 34 56 78', minLength: 9, maxLength: 9),
    CountryCode(name: 'Germany', isoCode: 'DE', dialCode: '+49', flagEmoji: '🇩🇪', example: '151 23456789', minLength: 10, maxLength: 11),
    CountryCode(name: 'Spain', isoCode: 'ES', dialCode: '+34', flagEmoji: '🇪🇸', example: '612 34 56 78', minLength: 9, maxLength: 9),
    CountryCode(name: 'Italy', isoCode: 'IT', dialCode: '+39', flagEmoji: '🇮🇹', example: '312 345 6789', minLength: 9, maxLength: 10),
    CountryCode(name: 'Netherlands', isoCode: 'NL', dialCode: '+31', flagEmoji: '🇳🇱', example: '6 12345678', minLength: 9, maxLength: 9),
    CountryCode(name: 'Switzerland', isoCode: 'CH', dialCode: '+41', flagEmoji: '🇨🇭', example: '78 123 45 67', minLength: 9, maxLength: 9),
    CountryCode(name: 'Turkey', isoCode: 'TR', dialCode: '+90', flagEmoji: '🇹🇷', example: '532 123 45 67', minLength: 10, maxLength: 10),
    CountryCode(name: 'Australia', isoCode: 'AU', dialCode: '+61', flagEmoji: '🇦🇺', example: '412 345 678', minLength: 9, maxLength: 9),
    CountryCode(name: 'New Zealand', isoCode: 'NZ', dialCode: '+64', flagEmoji: '🇳🇿', example: '21 123 4567', minLength: 8, maxLength: 10),
    CountryCode(name: 'Singapore', isoCode: 'SG', dialCode: '+65', flagEmoji: '🇸🇬', example: '8123 4567', minLength: 8, maxLength: 8),
    CountryCode(name: 'Malaysia', isoCode: 'MY', dialCode: '+60', flagEmoji: '🇲🇾', example: '12 345 6789', minLength: 9, maxLength: 10),
    CountryCode(name: 'South Africa', isoCode: 'ZA', dialCode: '+27', flagEmoji: '🇿🇦', example: '71 123 4567', minLength: 9, maxLength: 9),
    CountryCode(name: 'Nigeria', isoCode: 'NG', dialCode: '+234', flagEmoji: '🇳🇬', example: '802 123 4567', minLength: 10, maxLength: 10),
    CountryCode(name: 'Kenya', isoCode: 'KE', dialCode: '+254', flagEmoji: '🇰🇪', example: '712 345678', minLength: 9, maxLength: 9),
    CountryCode(name: 'Egypt', isoCode: 'EG', dialCode: '+20', flagEmoji: '🇪🇬', example: '10 1234 5678', minLength: 10, maxLength: 10),
    CountryCode(name: 'Lebanon', isoCode: 'LB', dialCode: '+961', flagEmoji: '🇱🇧', example: '70 123 456', minLength: 7, maxLength: 8),
    CountryCode(name: 'Jordan', isoCode: 'JO', dialCode: '+962', flagEmoji: '🇯🇴', example: '7 9123 4567', minLength: 9, maxLength: 9),
    CountryCode(name: 'Morocco', isoCode: 'MA', dialCode: '+212', flagEmoji: '🇲🇦', example: '612 345678', minLength: 9, maxLength: 9),
    CountryCode(name: 'Iraq', isoCode: 'IQ', dialCode: '+964', flagEmoji: '🇮🇶', example: '790 123 4567', minLength: 10, maxLength: 10),
    CountryCode(name: 'Belgium', isoCode: 'BE', dialCode: '+32', flagEmoji: '🇧🇪', example: '470 12 34 56', minLength: 9, maxLength: 9),
    CountryCode(name: 'Portugal', isoCode: 'PT', dialCode: '+351', flagEmoji: '🇵🇹', example: '912 345 678', minLength: 9, maxLength: 9),
    CountryCode(name: 'Sweden', isoCode: 'SE', dialCode: '+46', flagEmoji: '🇸🇪', example: '70 123 45 67', minLength: 9, maxLength: 9),
    CountryCode(name: 'Norway', isoCode: 'NO', dialCode: '+47', flagEmoji: '🇳🇴', example: '412 34 567', minLength: 8, maxLength: 8),
    CountryCode(name: 'Denmark', isoCode: 'DK', dialCode: '+45', flagEmoji: '🇩🇰', example: '20 12 34 56', minLength: 8, maxLength: 8),
    CountryCode(name: 'Greece', isoCode: 'GR', dialCode: '+30', flagEmoji: '🇬🇷', example: '691 234 5678', minLength: 10, maxLength: 10),
    CountryCode(name: 'Poland', isoCode: 'PL', dialCode: '+48', flagEmoji: '🇵🇱', example: '512 345 678', minLength: 9, maxLength: 9),
    CountryCode(name: 'Austria', isoCode: 'AT', dialCode: '+43', flagEmoji: '🇦🇹', example: '664 1234567', minLength: 10, maxLength: 11),
    CountryCode(name: 'Brazil', isoCode: 'BR', dialCode: '+55', flagEmoji: '🇧🇷', example: '11 91234 5678', minLength: 10, maxLength: 11),
    CountryCode(name: 'Mexico', isoCode: 'MX', dialCode: '+52', flagEmoji: '🇲🇽', example: '55 1234 5678', minLength: 10, maxLength: 10),
    CountryCode(name: 'Japan', isoCode: 'JP', dialCode: '+81', flagEmoji: '🇯🇵', example: '90 1234 5678', minLength: 10, maxLength: 10),
    CountryCode(name: 'Hong Kong', isoCode: 'HK', dialCode: '+852', flagEmoji: '🇭🇰', example: '9123 4567', minLength: 8, maxLength: 8),
    CountryCode(name: 'China', isoCode: 'CN', dialCode: '+86', flagEmoji: '🇨🇳', example: '138 1234 5678', minLength: 11, maxLength: 11),
  ];

  /// Cleans the national number by:
  /// 1. Stripping all non-digits (spaces, dashes, parentheses).
  /// 2. Crucially, removing leading trunk zero '0' (e.g. UK '07986...' -> '7986...').
  static String cleanNationalDigits(String rawInput) {
    String digits = rawInput.replaceAll(RegExp(r'\D'), '');
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return digits;
  }

  /// Converts country dialCode + user input into standard E.164 format for Twilio
  /// e.g. dialCode: "+44", rawInput: "07986 799823" -> "+447986799823"
  static String formatToE164({
    required String dialCode,
    required String nationalInput,
  }) {
    final cleanCode = dialCode.startsWith('+') ? dialCode : '+$dialCode';
    final cleanDigits = cleanNationalDigits(nationalInput);
    return '$cleanCode$cleanDigits';
  }

  /// Parses an existing full E.164 string back into (CountryCode, nationalDigits)
  /// e.g. "+44798679982" -> (United Kingdom, "798679982")
  static (CountryCode country, String nationalDigits) parseE164(String? fullPhone) {
    if (fullPhone == null || fullPhone.trim().isEmpty) {
      return (defaultCountry, '');
    }

    final trimmed = fullPhone.trim();

    // Check sorted by longest dialCode first (+971 before +9 etc.)
    final sorted = List<CountryCode>.from(supportedCountries)
      ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));

    for (final c in sorted) {
      if (trimmed.startsWith(c.dialCode)) {
        final remaining = trimmed.substring(c.dialCode.length);
        return (c, cleanNationalDigits(remaining));
      }
    }

    // Fallback if not matched
    return (defaultCountry, cleanNationalDigits(trimmed));
  }

  /// Validates if the phone number meets the length requirements for the country
  static String? validate({
    required CountryCode country,
    required String nationalInput,
  }) {
    final clean = cleanNationalDigits(nationalInput);
    if (clean.isEmpty) {
      return 'Mobile phone number is required';
    }
    if (clean.length < country.minLength) {
      return 'Number too short for ${country.name} (min ${country.minLength} digits)';
    }
    if (clean.length > country.maxLength) {
      return 'Number too long for ${country.name} (max ${country.maxLength} digits)';
    }
    return null;
  }

  /// Returns a clean formatted display string for UI display (e.g. "+44 7986 799823")
  static String formatDisplay(String? e164Phone) {
    if (e164Phone == null || e164Phone.isEmpty) return '';
    final (country, national) = parseE164(e164Phone);
    if (national.isEmpty) return e164Phone;

    // Apply 3-3-4 or 4-6 spacing if national length allows
    if (national.length == 10) {
      return '${country.dialCode} ${national.substring(0, 4)} ${national.substring(4)}';
    } else if (national.length == 9) {
      return '${country.dialCode} ${national.substring(0, 3)} ${national.substring(3, 6)} ${national.substring(6)}';
    }
    return '${country.dialCode} $national';
  }
}
