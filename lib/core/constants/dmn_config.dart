/// DesignMyNight (DMN) booking widget configuration.
///
/// Maps Tiger Bay branch names to their DMN venue IDs and provides
/// the direct booking URLs loaded inside the in-app WebView.
class DmnConfig {
  DmnConfig._();

  // ── Branch → DMN venue ID mapping ─────────────────────────────────────────
  //
  // Keys are lowercase substrings matched against `Branch.title` using
  // `String.contains` for resilience (e.g. "Tiger Bay Hanger Lane" matches
  // the key "hanger lane").

  static const Map<String, String> _venueIds = {
    'hanger lane': '5d5e6db30b108365ab6d9c5f',
    'enfield': '663e2d5f170c331d9b554b3f',
    'hounslow': '6973724f9c12d51f4f2dd402',
    'kingsbury': '5d5e6d8d0b1083654f5080cd',
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
}
