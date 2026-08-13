/// DesignMyNight (DMN) booking widget configuration.
///
/// Maps Tiger Bay branch names to their official DMN venue IDs and provides
/// direct HTTPS booking URLs for live table reservations.
class DmnConfig {
  DmnConfig._();

  // ── Branch → DMN venue ID mapping ─────────────────────────────────────────
  static const Map<String, String> _venueIds = {
    'hanger lane': '5d5e6db30b108365ab6d9c5f',
    'enfield': '663e2d5f170c331d9b554b3f',
    'hounslow': '6973724f9c12d51f4f2dd402',
    'kingsbury': '5d5e6d8d0b1083654f5080cd',
  };

  /// Direct web booking URLs for browser fallback
  static const Map<String, String> _directUrls = {
    'kingsbury': 'https://www.tigerbayshisha.co.uk/reservation.html',
    'hanger lane': 'https://www.tigerbayhangerlane.co.uk/',
    'enfield': 'https://www.sherekhanrestaurant.com/tigerbay/',
  };

  /// Returns the DMN venue ID for the given [branchTitle], or `null` if the
  /// branch is not configured for online booking.
  static String? getDmnVenueId(String branchTitle) {
    final lower = branchTitle.toLowerCase();
    for (final entry in _venueIds.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Returns the full hosted HTTPS booking URL for the given [venueId].
  /// This loads directly from DesignMyNight with full cookies, SSL, and API support.
  static String getBookingUrl(String venueId) {
    return 'https://bookings.designmynight.com/book?venue_id=$venueId';
  }

  /// Returns a direct web reservation URL if available for opening in browser.
  static String getDirectBookingUrl(String branchTitle, String venueId) {
    final lower = branchTitle.toLowerCase();
    for (final entry in _directUrls.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return 'https://bookings.designmynight.com/book?venue_id=$venueId';
  }
}
