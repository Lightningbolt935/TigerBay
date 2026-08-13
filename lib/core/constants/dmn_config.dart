/// DesignMyNight (DMN) booking widget configuration.
///
/// Maps Tiger Bay branch names to their DMN venue IDs and provides
/// the responsive booking widget HTML and fallback URLs for in-app reservations.
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

  /// Returns a direct web reservation URL if available for opening in browser.
  static String getDirectBookingUrl(String branchTitle, String venueId) {
    final lower = branchTitle.toLowerCase();
    for (final entry in _directUrls.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }
    return 'https://bookings.designmynight.com/book?venue_id=$venueId';
  }

  /// Builds a fully styled, mobile-optimized HTML embed of the official
  /// DesignMyNight partner widget matching Tiger Bay's luxury dark/gold theme.
  static String getWidgetHtml(String venueId) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Tiger Bay Reservations</title>
  <link rel="stylesheet" type="text/css" href="https://onsass.designmynight.com/?theme=dark&body-text-color=%23ffffff&primary-color=%23C4A35A&background-color=%230D0804">
  <style>
    * {
      box-sizing: border-box;
      -webkit-tap-highlight-color: transparent;
    }
    html, body {
      margin: 0;
      padding: 0;
      width: 100%;
      min-height: 100%;
      background-color: #0D0804;
      color: #ffffff;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    }
    .booking-wrapper {
      padding: 12px 14px 40px;
      max-width: 600px;
      margin: 0 auto;
    }
    /* Fix form inputs, labels & dropdowns for mobile screens */
    select, input, button {
      font-size: 16px !important;
    }
    .dmn-booking-form, .dmn-booking-form-container {
      width: 100% !important;
      max-width: 100% !important;
    }
    /* Popover & modal styling */
    .popover, .modal-content, .dropdown-menu {
      background-color: #1a1410 !important;
      color: #ffffff !important;
      border: 1px solid rgba(196, 163, 90, 0.3) !important;
      border-radius: 12px !important;
      box-shadow: 0 8px 30px rgba(0, 0, 0, 0.7) !important;
    }
    .popover * {
      color: #ffffff !important;
    }
    .btn-primary, button[type="submit"] {
      background-color: #C4A35A !important;
      color: #000000 !important;
      font-weight: 700 !important;
      border-radius: 8px !important;
      border: none !important;
    }
  </style>
</head>
<body>
  <div class="booking-wrapper">
    <script src="https://widgets.designmynight.com/bookings-partner.min.js"
      dmn-booking-form="true"
      venue="$venueId"
      hide-offers="false"
      hide-powered-by="false"
      search-venues="false"
      monday-first="true"
      aria-label="Tigerbay Shisha Lounge booking form">
    </script>
  </div>
</body>
</html>
''';
  }
}
