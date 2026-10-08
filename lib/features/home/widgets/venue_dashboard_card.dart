import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/features/contact/screens/contact_us_screen.dart';
import 'package:tigerbay_app/features/venue/screens/venue_landing_screen.dart';
import 'package:tigerbay_app/shared/widgets/apple_touch_feedback.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Venue Dashboard Card (Dark Luxury Edition)
/// ═══════════════════════════════════════════════════════════════════════════
/// Features:
/// 1. Venue Location & Map Integration with one-tap Google/Apple Maps directions.
/// 2. Live Opening & Closing Status badge + Full Weekly Schedule breakdown.
/// 3. Customer Support Service: one-tap Phone Call + WhatsApp/SMS Messaging.
class VenueDashboardCard extends StatelessWidget {
  final Branch venue;
  final VoidCallback? onSwitchVenue;

  const VenueDashboardCard({
    super.key,
    required this.venue,
    this.onSwitchVenue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Venue Header & Live Open/Close Status Row ──────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.storefront_rounded,
                      color: AppColors.gold,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        venue.title,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          buildLiveStatusPill(venue),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              venue.todayHoursFormatted,
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onSwitchVenue != null)
                  AppleTouchFeedback(
                    onTap: onSwitchVenue!,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.border,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Switch',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.gold,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.gold,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── 1.5 3-Image Venue Showcase Strip ─────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: AppleTouchFeedback(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VenueLandingScreen(venue: venue),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    ...venue.effectiveImages.take(3).map(
                      (url) => Container(
                        margin: const EdgeInsets.only(right: 6),
                        width: 44,
                        height: 32,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                        ),
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const ColoredBox(
                            color: Color(0xFF22242B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '3-Image Venue Showcase',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Explore VIP lounge & terrace',
                            style: GoogleFonts.poppins(
                              fontSize: 10.5,
                              color: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppColors.gold,
                      size: 13,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 2. Interactive Map / Location Preview Card ────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () => launchVenueDirections(context, venue),
              child: Container(
                height: 105,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E2129),
                      Color(0xFF14161C),
                      Color(0xFF0F1014),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.border,
                    width: 0.8,
                  ),
                ),
                child: Stack(
                  children: [
                    // Subtle geometric grid background pattern
                    CustomPaint(
                      size: const Size(double.infinity, 105),
                      painter: _MapGridPainter(),
                    ),

                    // Location content overlay
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          // Glowing pin icon
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.brandRed.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.brandRed,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brandRed.withValues(alpha: 0.4),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Address text
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  venue.addressFormatted,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Tap for Google Maps & Directions',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Open in Maps pill button
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.directions_rounded,
                                  color: Colors.black,
                                  size: 15,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Map',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── 3. Call Now, Get Directions, Support & Contact Us ─────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // Call Now
                Expanded(
                  child: AppleTouchFeedback(
                    onTap: () => launchVenueCall(context, venue),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.phone_in_talk_rounded,
                            color: Colors.black,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Call Now',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Directions
                Expanded(
                  child: AppleTouchFeedback(
                    onTap: () => launchVenueDirections(context, venue),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.border,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.directions_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Directions',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Support (WhatsApp + SMS)
                AppleTouchFeedback(
                  onTap: () => showCustomerSupportModal(context, venue),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E281E),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF34C759).withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Color(0xFF34C759),
                        size: 17,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Contact Us & Enquiries
                AppleTouchFeedback(
                  onTap: () => showContactUsModal(context, initialVenue: venue),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.mail_outline_rounded,
                        color: AppColors.gold,
                        size: 17,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Full Weekly Timings Schedule Modal trigger
                AppleTouchFeedback(
                  onTap: () => showVenueWeeklyHoursModal(context, venue),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.border,
                        width: 1,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.access_time_rounded,
                        color: AppColors.textSecondary,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Global Helper: Live Open/Closed Status Badge (High-End Frosted Luxury) ───
Widget buildLiveStatusPill(Branch venue, {bool isCompact = false}) {
  final isOpen = venue.isOpenNow;
  final indicatorColor =
      isOpen ? const Color(0xFF10B981) : const Color(0xFFF59E0B);

  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: isCompact ? 7 : 10,
      vertical: isCompact ? 3 : 5,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFF0F0F13).withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: AppColors.gold.withValues(alpha: 0.35),
        width: 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isCompact ? 4.5 : 5.5,
          height: isCompact ? 4.5 : 5.5,
          decoration: BoxDecoration(
            color: indicatorColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: indicatorColor.withValues(alpha: 0.5),
                blurRadius: 4,
                spreadRadius: 0.5,
              ),
            ],
          ),
        ),
        SizedBox(width: isCompact ? 4 : 5.5),
        Text(
          isCompact ? (isOpen ? 'OPEN' : 'CLOSED') : venue.statusBadgeText,
          style: GoogleFonts.outfit(
            fontSize: isCompact ? 8.5 : 9.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.95),
            letterSpacing: 1.0,
          ),
        ),
      ],
    ),
  );
}

// ── Global Helper: Launch Directions in Maps ──────────────────────────────────
Future<void> launchVenueDirections(BuildContext context, Branch venue) async {
  final lat = venue.effectiveLatitude;
  final lng = venue.effectiveLongitude;
  final title = Uri.encodeComponent('Tiger Bay ${venue.title}');

  final googleMapsUrl = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$title',
  );
  final geoUrl = Uri.parse('geo:$lat,$lng?q=$lat,$lng($title)');

  try {
    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(geoUrl)) {
      await launchUrl(geoUrl, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(
        Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
        mode: LaunchMode.externalApplication,
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening Maps: ${venue.addressFormatted}'),
          backgroundColor: AppColors.surface,
        ),
      );
    }
  }
}

// ── Global Helper: Call Venue Directly ────────────────────────────────────────
Future<void> launchVenueCall(BuildContext context, Branch venue) async {
  final cleanPhone = venue.cleanPhoneNumber;
  final telUri = Uri(scheme: 'tel', path: cleanPhone);

  try {
    if (await canLaunchUrl(telUri)) {
      await launchUrl(telUri);
    } else {
      throw 'Cannot dial';
    }
  } catch (_) {
    if (context.mounted) {
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            venue.title,
            style: GoogleFonts.poppins(color: Colors.white),
          ),
          content: Text(
            'Phone: ${venue.phoneFormatted}',
            style: GoogleFonts.poppins(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK', style: TextStyle(color: AppColors.gold)),
            ),
          ],
        ),
      );
    }
  }
}

// ── Global Helper: Chat via WhatsApp ──────────────────────────────────────────
Future<void> launchVenueWhatsApp(
  BuildContext context,
  Branch venue, {
  String? customMessage,
}) async {
  final cleanPhone = venue.whatsappNumber;
  final venueTitle = venue.title.isNotEmpty ? venue.title : 'Kingsbury';
  final defaultMsg = "Hi I'd like to make a Enquiry for Tigerbay $venueTitle";
  final text = customMessage ?? defaultMsg;
  final encoded = Uri.encodeComponent(text);

  // 1. Client specified official WhatsApp API format
  final apiUri = Uri.parse(
    'https://api.whatsapp.com/send/?phone=$cleanPhone&text=$encoded&type=phone_number&app_absent=0',
  );

  // 2. Native WhatsApp scheme
  final nativeUri = Uri.parse('whatsapp://send?phone=$cleanPhone&text=$encoded');

  try {
    if (await canLaunchUrl(nativeUri)) {
      await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
      return;
    }
  } catch (_) {}

  try {
    if (await canLaunchUrl(apiUri)) {
      await launchUrl(apiUri, mode: LaunchMode.externalApplication);
      return;
    }
  } catch (_) {}

  // 3. Fallback wa.me
  final waMe = Uri.parse('https://wa.me/$cleanPhone?text=$encoded');
  try {
    if (await canLaunchUrl(waMe)) {
      await launchUrl(waMe, mode: LaunchMode.externalApplication);
    }
  } catch (_) {}
}

// ── Global Helper: Customer Support Concierge Modal (Call + Msg) ──────────────
void showCustomerSupportModal(BuildContext context, Branch venue) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF14161C),
    barrierColor: Colors.black.withValues(alpha: 0.8),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: AppColors.gold,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer Support & Concierge',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Direct line for Tiger Bay ${venue.title}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 1. WhatsApp Chat Option (Message Service)
            _SupportOptionTile(
              icon: Icons.chat_rounded,
              iconColor: const Color(0xFF25D366),
              title: 'Chat on WhatsApp',
              subtitle: 'Instant messaging with reception concierge',
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await launchVenueWhatsApp(context, venue);
              },
            ),
            const SizedBox(height: 10),

            // 2. Direct Phone Call Option (Call Service)
            _SupportOptionTile(
              icon: Icons.phone_rounded,
              iconColor: const Color(0xFF34C759),
              title: 'Call Reception',
              subtitle: venue.phoneFormatted,
              onTap: () {
                Navigator.of(sheetCtx).pop();
                launchVenueCall(context, venue);
              },
            ),
            const SizedBox(height: 10),

            // 3. SMS Message Option (Message Service)
            _SupportOptionTile(
              icon: Icons.sms_rounded,
              iconColor: AppColors.gold,
              title: 'Send SMS Text',
              subtitle: 'Direct mobile message service',
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                final smsUri = Uri(
                  scheme: 'sms',
                  path: venue.cleanPhoneNumber,
                );
                if (await canLaunchUrl(smsUri)) {
                  await launchUrl(smsUri);
                }
              },
            ),
            const SizedBox(height: 10),

            // 4. Email Concierge Option
            _SupportOptionTile(
              icon: Icons.email_rounded,
              iconColor: const Color(0xFF007AFF),
              title: 'Email Concierge',
              subtitle: venue.supportEmail,
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                final mailUri = Uri(
                  scheme: 'mailto',
                  path: venue.supportEmail,
                  query: 'subject=TigerBay%20${venue.title}%20Inquiry',
                );
                if (await canLaunchUrl(mailUri)) {
                  await launchUrl(mailUri);
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Global Helper: Venue Weekly Hours Modal ──────────────────────────────────
void showVenueWeeklyHoursModal(BuildContext context, Branch venue) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF14161C),
    barrierColor: Colors.black.withValues(alpha: 0.8),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Opening & Closing Hours',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Tiger Bay ${venue.title}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.gold,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                buildLiveStatusPill(venue),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border, width: 0.8),
              ),
              child: Column(
                children: venue.weeklySchedule.entries.map((entry) {
                  final isToday = _isDayToday(entry.key);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppColors.gold.withValues(alpha: 0.1)
                          : Colors.transparent,
                      border: Border(
                        bottom: BorderSide(
                          color: AppColors.border.withValues(alpha: 0.4),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              entry.key,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight:
                                    isToday ? FontWeight.w700 : FontWeight.w500,
                                color: isToday ? AppColors.gold : Colors.white,
                              ),
                            ),
                            if (isToday) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.gold,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'TODAY',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          entry.value,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight:
                                isToday ? FontWeight.w700 : FontWeight.w400,
                            color:
                                isToday ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

bool _isDayToday(String day) {
  final now = DateTime.now();
  switch (now.weekday) {
    case DateTime.monday:
      return day == 'Monday';
    case DateTime.tuesday:
      return day == 'Tuesday';
    case DateTime.wednesday:
      return day == 'Wednesday';
    case DateTime.thursday:
      return day == 'Thursday';
    case DateTime.friday:
      return day == 'Friday';
    case DateTime.saturday:
      return day == 'Saturday';
    case DateTime.sunday:
      return day == 'Sunday';
    default:
      return false;
  }
}

class _SupportOptionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SupportOptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppleTouchFeedback(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textHint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.04)
      ..strokeWidth = 1.0;

    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
