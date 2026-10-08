import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/constants/app_routes.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/data/models/booking_model.dart';
import 'package:tigerbay_app/features/bookings/providers/booking_provider.dart';
import 'package:tigerbay_app/features/home/providers/home_provider.dart';
import 'package:tigerbay_app/features/home/providers/newsfeed_provider.dart';
import 'package:tigerbay_app/features/home/widgets/venue_dashboard_card.dart';
import 'package:tigerbay_app/features/notifications/providers/user_notifications_provider.dart';
import 'package:tigerbay_app/features/venue/screens/venue_landing_screen.dart';
import 'package:tigerbay_app/shared/widgets/apple_touch_feedback.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Decluttered Luxury Lounges & Venue Hub
/// ═══════════════════════════════════════════════════════════════════════════
/// Replaces the cluttered multi-carousel dashboard with a focused, elite
/// Mayfair London lounge showcase:
/// - 3-Image auto-sliding venue hero with live status badge.
/// - 4 Direct actions: Call Reception, WhatsApp Concierge, Directions, Contact Us.
/// - Operating hours & official website access.
/// - Interactive London Lounges Map with live pins for Kingsbury, Enfield,
///   Hanger Lane, and Hounslow.
/// - Curated luxury shortcuts to dedicated "What's On" & "VIP Packages" tabs.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);
    final selectedBranch = ref.watch(selectedBranchProvider);

    final bookingsAsync = ref.watch(userBookingsStreamProvider);
    final upcomingBooking = bookingsAsync.valueOrNull
        ?.where((b) => b.status == BookingStatus.upcoming)
        .firstOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── 1. Top Luxury Brand Bar ─────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                child: Row(
                  children: [
                    // Brand Logo + Title
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.brandRed.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                'assets/images/tigerbay_logo.png',
                                width: 34,
                                height: 34,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.pets,
                                  size: 26,
                                  color: AppColors.brandRed,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'TigerBay',
                                  style: GoogleFonts.poppins(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                    color: AppColors.brandRed,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'INTERNATIONAL',
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 2.2,
                                    color: AppColors.champagneGold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Notification Bell
                    AppleTouchFeedback(
                      onTap: () => context.push(AppRoutes.notifications),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF141418),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 0.8,
                          ),
                        ),
                        child: Center(
                          child: Badge(
                            isLabelVisible:
                                ref.watch(unreadNotificationCountProvider) > 0,
                            label: Text(
                              '${ref.watch(unreadNotificationCountProvider)}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            backgroundColor: AppColors.brandRed,
                            child: const Icon(
                              Icons.notifications_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // VIP Concierge Support
                    AppleTouchFeedback(
                      onTap: () {
                        final currentVenue = selectedBranch ??
                            (branchesAsync.valueOrNull?.isNotEmpty == true
                                ? branchesAsync.valueOrNull!.first
                                : Branch.defaultBranches.first);
                        showCustomerSupportModal(context, currentVenue);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF141418),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.6),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.support_agent_rounded,
                            color: AppColors.champagneGold,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 6)),

            // ── 2. Venue Showcase Hero: 3-Image Auto-Sliding Carousel ───────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: branchesAsync.when(
                  data: (branchList) {
                    final currentVenue = selectedBranch ??
                        (branchList.isNotEmpty ? branchList.first : null);
                    if (currentVenue == null) return const SizedBox.shrink();
                    return _VenueHeroCarouselCard(
                      venue: currentVenue,
                      onSwitchVenue: () => showVenueSelectorSheet(
                        context,
                        branches: branchList,
                        selected: currentVenue,
                        onSelected: (b) => ref
                            .read(selectedBranchProvider.notifier)
                            .changeBranch(b),
                      ),
                    );
                  },
                  loading: () => Container(
                    height: 255,
                    decoration: BoxDecoration(
                      color: const Color(0xFF141418),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 14)),

            // ── 3. Four Direct Lounge Action Buttons ─────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: branchesAsync.when(
                  data: (branchList) {
                    final currentVenue = selectedBranch ??
                        (branchList.isNotEmpty ? branchList.first : Branch.defaultBranches.first);
                    return _FourDirectActionsRow(venue: currentVenue);
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            // ── 4. Upcoming Booking Pass (If active) ────────────────────────
            if (upcomingBooking != null) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: _UpcomingBookingPass(
                    booking: upcomingBooking,
                    onTap: () => context.push(
                      '${AppRoutes.bookingDetail}/${upcomingBooking.id}',
                      extra: upcomingBooking,
                    ),
                  ),
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 18)),

            // ── 5. Lounge & Restaurant Gallery Section ───────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: branchesAsync.when(
                  data: (branchList) {
                    final currentVenue = selectedBranch ??
                        (branchList.isNotEmpty ? branchList.first : Branch.defaultBranches.first);
                    return _GallerySection(venue: currentVenue);
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
            ),

            // Clears floating bottom navigation dock
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }
}

// ── 3-Image Venue Hero Carousel Card ──────────────────────────────────────────

class _VenueHeroCarouselCard extends StatefulWidget {
  final Branch venue;
  final VoidCallback onSwitchVenue;

  const _VenueHeroCarouselCard({
    required this.venue,
    required this.onSwitchVenue,
  });

  @override
  State<_VenueHeroCarouselCard> createState() => _VenueHeroCarouselCardState();
}

class _VenueHeroCarouselCardState extends State<_VenueHeroCarouselCard> {
  late final PageController _pageController;
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final images = widget.venue.effectiveImages;
      if (images.length <= 1) return;
      final nextPage = (_currentPage + 1) % images.length;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.venue.effectiveImages;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VenueLandingScreen(venue: widget.venue),
        ),
      ),
      child: Container(
        height: 255,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: -2,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Auto-sliding 3-Image Gallery
          PageView.builder(
            controller: _pageController,
            itemCount: images.length,
            onPageChanged: (idx) => setState(() => _currentPage = idx),
            itemBuilder: (context, idx) {
              return CachedNetworkImage(
                imageUrl: images[idx],
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: const Color(0xFF141418),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF141418),
                  child: const Icon(Icons.storefront, color: AppColors.gold),
                ),
              );
            },
          ),

          // Cinematic Vignette Overlay
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.35),
                  Colors.black.withValues(alpha: 0.1),
                  Colors.black.withValues(alpha: 0.92),
                ],
                stops: const [0.0, 0.38, 1.0],
              ),
            ),
          ),

          // Top Floating Bar: Status Pill + Switch Venue Button
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                buildLiveStatusPill(widget.venue),
                AppleTouchFeedback(
                  onTap: widget.onSwitchVenue,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.5),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Switch Venue',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.champagneGold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.champagneGold,
                          size: 15,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Bar: Title, Address, Hours Badge, and 3-Image Indicators
          Positioned(
            bottom: 12,
            left: 16,
            right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Tiger Bay ${widget.venue.title}',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 13,
                            color: AppColors.champagneGold,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.venue.addressFormatted,
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Operating Hours interactive badge inside the Hero Card
                      AppleTouchFeedback(
                        onTap: () => showVenueWeeklyHoursModal(context, widget.venue),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.schedule_rounded,
                                size: 12,
                                color: AppColors.champagneGold,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Hours: ${widget.venue.todayHoursFormatted}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '• Schedule ›',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.champagneGold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Indicator dots
                if (images.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        images.length,
                        (idx) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.only(left: 4),
                          width: _currentPage == idx ? 16 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentPage == idx
                                ? AppColors.champagneGold
                                : Colors.white54,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

// ── 4 Direct Lounge Actions ───────────────────────────────────────────────────

class _FourDirectActionsRow extends StatelessWidget {
  final Branch venue;

  const _FourDirectActionsRow({required this.venue});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 1. Reserve Table (Primary Luxury Action)
        Expanded(
          child: _ActionButton(
            icon: CupertinoIcons.calendar_today,
            label: 'Reserve',
            isPrimary: true,
            onTap: () => context.push(AppRoutes.booking),
          ),
        ),
        const SizedBox(width: 8),

        // 2. Call Reception
        Expanded(
          child: _ActionButton(
            icon: Icons.phone_in_talk_rounded,
            label: 'Call',
            onTap: () => launchVenueCall(context, venue),
          ),
        ),
        const SizedBox(width: 8),

        // 3. WhatsApp Concierge (Luxury Sleek Action)
        Expanded(
          child: _ActionButton(
            icon: Icons.chat_bubble_rounded,
            label: 'WhatsApp',
            onTap: () => launchVenueWhatsApp(context, venue),
          ),
        ),
        const SizedBox(width: 8),

        // 4. Directions / Map
        Expanded(
          child: _ActionButton(
            icon: Icons.directions_rounded,
            label: 'Map',
            onTap: () => launchVenueDirections(context, venue),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return AppleTouchFeedback(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [
                    Color(0xFFE5C378),
                    Color(0xFFC79E38),
                    Color(0xFFA17C18),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isPrimary ? null : const Color(0xFF141418),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isPrimary
                ? AppColors.gold
                : AppColors.gold.withValues(alpha: 0.28),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: isPrimary
                  ? AppColors.gold.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.4),
              blurRadius: isPrimary ? 12 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isPrimary ? Colors.black : AppColors.champagneGold,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: isPrimary ? FontWeight.w800 : FontWeight.w600,
                color: isPrimary ? Colors.black : Colors.white,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Gallery Section (Curated Moments & Feed) ──────────────────────────────────

class _GallerySection extends ConsumerWidget {
  final Branch venue;

  const _GallerySection({required this.venue});

  static const List<Map<String, String>> defaultShowcase = [
    {
      'title': 'Signature Cocktails & Mixology',
      'category': 'DRINKS',
      'url': 'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?w=800&q=80',
      'description': 'Masterfully crafted signature cocktails and mocktails shaken to perfection.',
    },
    {
      'title': 'Tandoori Grills & Indo-Chinese',
      'category': 'CUISINE',
      'url': 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=800&q=80',
      'description': 'Authentic charcoal tandoor platters and spicy Indo-Chinese appetizers.',
    },
    {
      'title': 'Savacco VIP Shisha Experience',
      'category': 'SHISHA',
      'url': 'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=800&q=80',
      'description': 'Exclusive Savacco, Starbuzz, and frozen ice pipe shisha blends.',
    },
    {
      'title': 'Late Night Velvet Booths',
      'category': 'AMBIANCE',
      'url': 'https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=800&q=80',
      'description': 'Intimate low-lit Mayfair leather booths with mood lighting and live DJ soundscapes.',
    },
    {
      'title': 'Gourmet Artisan Burgers & Loaded Fries',
      'category': 'LATE NIGHT',
      'url': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800&q=80',
      'description': 'Late-night cravings served until 3:30 AM / 5:00 AM nightly.',
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(newsFeedStreamProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Renamed to simply "GALLERY" with luxury typography
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      color: AppColors.champagneGold,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'GALLERY',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Moments & Ambiance',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.champagneGold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Horizontal Gallery Cards
          feedAsync.when(
            data: (feedItems) {
              final List<_GalleryCardData> cards = [];

              for (final f in feedItems) {
                if (f.imageUrl != null && f.imageUrl!.isNotEmpty) {
                  cards.add(_GalleryCardData(
                    title: f.title,
                    subtitle: f.previewText.isNotEmpty ? f.previewText : f.timeAgoLabel,
                    badge: 'FEED POST',
                    imageUrl: f.imageUrl!,
                    isFeedPost: true,
                  ));
                }
              }

              for (final item in defaultShowcase) {
                cards.add(_GalleryCardData(
                  title: item['title']!,
                  subtitle: item['description']!,
                  badge: item['category']!,
                  imageUrl: item['url']!,
                  isFeedPost: false,
                ));
              }

              return SizedBox(
                height: 210,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: cards.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, idx) => _GalleryPhotoCard(card: cards[idx]),
                ),
              );
            },
            loading: () => SizedBox(
              height: 210,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: defaultShowcase.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, idx) {
                  final item = defaultShowcase[idx];
                  return _GalleryPhotoCard(
                    card: _GalleryCardData(
                      title: item['title']!,
                      subtitle: item['description']!,
                      badge: item['category']!,
                      imageUrl: item['url']!,
                      isFeedPost: false,
                    ),
                  );
                },
              ),
            ),
            error: (_, __) => SizedBox(
              height: 210,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: defaultShowcase.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, idx) {
                  final item = defaultShowcase[idx];
                  return _GalleryPhotoCard(
                    card: _GalleryCardData(
                      title: item['title']!,
                      subtitle: item['description']!,
                      badge: item['category']!,
                      imageUrl: item['url']!,
                      isFeedPost: false,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryCardData {
  final String title;
  final String subtitle;
  final String badge;
  final String imageUrl;
  final bool isFeedPost;

  const _GalleryCardData({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.imageUrl,
    required this.isFeedPost,
  });
}

class _GalleryPhotoCard extends StatelessWidget {
  final _GalleryCardData card;

  const _GalleryPhotoCard({required this.card});

  @override
  Widget build(BuildContext context) {
    return AppleTouchFeedback(
      onTap: () => _showPhotoDetailModal(context, card),
      child: Container(
        width: 195,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A20),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: card.isFeedPost
                ? AppColors.gold.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: card.isFeedPost ? 1.0 : 0.8,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: card.imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: const Color(0xFF18181E),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 2,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: const Color(0xFF18181E),
                  child: const Icon(Icons.image_not_supported_rounded, color: Colors.white30),
                ),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.15),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: card.isFeedPost
                      ? AppColors.gold
                      : Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  card.badge,
                  style: GoogleFonts.outfit(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: card.isFeedPost ? Colors.black : AppColors.champagneGold,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    card.title,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.subtitle,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showPhotoDetailModal(BuildContext context, _GalleryCardData card) {
  HapticFeedback.lightImpact();
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF141418),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: card.imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    card.badge,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              card.title,
              style: GoogleFonts.playfairDisplay(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              card.subtitle,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

// ── Upcoming Booking Pass ─────────────────────────────────────────────────────

class _UpcomingBookingPass extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onTap;

  const _UpcomingBookingPass({
    required this.booking,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppleTouchFeedback(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF141418),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.35),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.25),
                ),
              ),
              child: const Icon(
                CupertinoIcons.calendar_today,
                color: AppColors.champagneGold,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'CONFIRMED TABLE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          booking.branchName,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.champagneGold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${booking.formattedDate} at ${booking.bookingTime}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${booking.guestCount} Guests • Tap for Pass & Details',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_forward,
              color: AppColors.champagneGold,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Venue Selector Bottom Sheet ───────────────────────────────────────────────

void showVenueSelectorSheet(
  BuildContext context, {
  required List<Branch> branches,
  required Branch? selected,
  required ValueChanged<Branch> onSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF141418),
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
                const Icon(
                  CupertinoIcons.location_solid,
                  color: AppColors.champagneGold,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Select TigerBay Venue',
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: branches.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, index) {
                  final b = branches[index];
                  final bool isSelected = selected?.id == b.id;

                  return AppleTouchFeedback(
                    onTap: () {
                      onSelected(b);
                      Navigator.pop(sheetCtx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.gold.withValues(alpha: 0.14)
                            : const Color(0xFF1A1A22),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.gold
                              : Colors.white.withValues(alpha: 0.08),
                          width: isSelected ? 1.5 : 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        b.title,
                                        style: GoogleFonts.poppins(
                                          color: isSelected
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    buildLiveStatusPill(b, isCompact: true),
                                  ],
                                ),
                                if (b.city != null && b.city!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    b.city!,
                                    style: GoogleFonts.poppins(
                                      color: isSelected
                                          ? AppColors.champagneGold
                                          : AppColors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: AppColors.gold,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.black,
                                size: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}