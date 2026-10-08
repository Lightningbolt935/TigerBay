import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/constants/app_routes.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/features/contact/screens/contact_us_screen.dart';
import 'package:tigerbay_app/features/events/providers/whats_on_provider.dart';
import 'package:tigerbay_app/features/home/providers/home_provider.dart';
import 'package:tigerbay_app/features/home/widgets/venue_dashboard_card.dart';
import 'package:tigerbay_app/features/packages/providers/packages_provider.dart';
import 'package:tigerbay_app/shared/widgets/apple_touch_feedback.dart';
import 'package:url_launcher/url_launcher.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Elite Venue Landing Page (Mayfair Luxury Edition)
/// ═══════════════════════════════════════════════════════════════════════════
/// Replaces the cluttered multi-button grid and sprawling text tables with
/// an ultra-clean, high-converting luxury dining & lounge landing experience:
/// 1. Cinematic 380px full-bleed parallax gallery with luxury vignette.
/// 2. Clear visual hierarchy: 1 primary Gold 'Reserve a Table' CTA + 4 sleek
///    concierge actions (Call, WhatsApp, Directions, Concierge).
/// 3. Executive Venue Intelligence Card: Operating hours + location + VIP line
///    with zero clutter and full 7-day schedule modal on demand.
/// 4. "The Tiger Bay Experience" editorial visual showcase (Mixology, Shisha, Cuisine).
/// 5. Live What's On & VIP Packages preview cards.
/// 6. Floating luxury bottom reservation dock.
class VenueLandingScreen extends ConsumerStatefulWidget {
  final Branch? venue;
  final int? branchId;

  const VenueLandingScreen({
    super.key,
    this.venue,
    this.branchId,
  });

  @override
  ConsumerState<VenueLandingScreen> createState() => _VenueLandingScreenState();
}

class _VenueLandingScreenState extends ConsumerState<VenueLandingScreen> {
  late final PageController _pageController;
  int _currentImageIndex = 0;
  Timer? _autoSlideTimer;

  static const List<Map<String, String>> _curatedExperiences = [
    {
      'title': 'Signature Mixology & Cocktails',
      'category': 'DRINKS',
      'url': 'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?w=800&q=80',
      'description': 'Masterfully shaken artisan cocktails and bespoke alcohol-free infusions.',
    },
    {
      'title': 'Savacco VIP Shisha Experience',
      'category': 'SHISHA',
      'url': 'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=800&q=80',
      'description': 'Exclusive Savacco, Starbuzz, and frozen Russian ice-pipe blends.',
    },
    {
      'title': 'Charcoal Tandoor & Indo-Chinese',
      'category': 'CUISINE',
      'url': 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=800&q=80',
      'description': 'Sizzling tandoori grills, rich curries, and spicy Indo-Chinese appetizers.',
    },
    {
      'title': 'Velvet VIP Booths & DJ Nights',
      'category': 'AMBIANCE',
      'url': 'https://images.unsplash.com/photo-1572116469696-31de0f17cc34?w=800&q=80',
      'description': 'Intimate low-lit leather booths with mood lighting and live DJ soundscapes.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final imagesCount = (widget.venue?.effectiveImages.length ?? 3).clamp(1, 10);
      final next = (_currentImageIndex + 1) % imagesCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchesProvider);
    final branches = branchesAsync.valueOrNull ?? Branch.defaultBranches;

    final Branch venue = widget.venue ??
        branches.firstWhere(
          (b) => b.id == widget.branchId,
          orElse: () => ref.watch(selectedBranchProvider) ?? branches.first,
        );

    final images = venue.effectiveImages;
    final eventsAsync = ref.watch(whatsOnEventsProvider(venue.id));
    final packagesAsync = ref.watch(packagesProvider(venue.id));

    return Scaffold(
      backgroundColor: const Color(0xFF090A0C),
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── 1. Cinematic Hero Header ─────────────────────────────────────
              SliverAppBar(
                expandedHeight: 370,
                pinned: true,
                elevation: 0,
                backgroundColor: const Color(0xFF101115),
                leading: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AppleTouchFeedback(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).maybePop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 0.8,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: AppleTouchFeedback(
                      onTap: () => showContactUsModal(context, initialVenue: venue),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.6),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.headset_mic_rounded,
                              color: AppColors.champagneGold,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'VIP Concierge',
                              style: GoogleFonts.poppins(
                                color: AppColors.champagneGold,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 3-Image Carousel
                      PageView.builder(
                        controller: _pageController,
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _currentImageIndex = i),
                        itemBuilder: (context, index) {
                          return CachedNetworkImage(
                            imageUrl: images[index],
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
                              child: const Center(
                                child: Icon(Icons.storefront_rounded, color: AppColors.gold, size: 40),
                              ),
                            ),
                          );
                        },
                      ),

                      // Refined Vignette Gradient
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.5),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.75),
                              const Color(0xFF090A0C),
                            ],
                            stops: const [0.0, 0.25, 0.72, 1.0],
                          ),
                        ),
                      ),

                      // Carousel Indicator dots
                      if (images.length > 1)
                        Positioned(
                          bottom: 95,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(images.length, (idx) {
                                final isSelected = _currentImageIndex == idx;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                  width: isSelected ? 16 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.champagneGold
                                        : Colors.white.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }),
                            ),
                          ),
                        ),

                      // Bottom of Hero: Live Pill + Title + Address
                      Positioned(
                        bottom: 18,
                        left: 20,
                        right: 20,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                buildLiveStatusPill(venue),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.gold.withValues(alpha: 0.35),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    (venue.city ?? 'London').toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                      color: AppColors.champagneGold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tiger Bay ${venue.title}',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
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
                                    venue.addressFormatted,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.85),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // ── 2. Executive Reservation & Concierge Action Dock ────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      // Hero Primary CTA: Reserve Table
                      AppleTouchFeedback(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          context.push(AppRoutes.booking);
                        },
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE5C568), Color(0xFFC9A84C), Color(0xFFA88934)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                CupertinoIcons.calendar_today,
                                color: Color(0xFF121214),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'RESERVE A TABLE & VIP LOUNGE',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                  color: const Color(0xFF121214),
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Color(0xFF121214),
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Curated 4-Item Concierge Capsule Strip
                      Row(
                        children: [
                          Expanded(
                            child: _LuxuryConciergeTile(
                              icon: Icons.phone_in_talk_rounded,
                              label: 'Call',
                              onTap: () => launchVenueCall(context, venue),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _LuxuryConciergeTile(
                              icon: Icons.chat_bubble_rounded,
                              label: 'WhatsApp',
                              onTap: () => launchVenueWhatsApp(context, venue),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _LuxuryConciergeTile(
                              icon: Icons.directions_rounded,
                              label: 'Directions',
                              onTap: () => launchVenueDirections(context, venue),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _LuxuryConciergeTile(
                              icon: Icons.email_outlined,
                              label: 'Concierge',
                              onTap: () => showContactUsModal(context, initialVenue: venue),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── 3. Quick Experience Shortcuts Pills ─────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      _ExperienceFilterPill(
                        icon: Icons.local_bar_rounded,
                        label: 'Cocktails & Mixology',
                        onTap: () => showContactUsModal(context, initialVenue: venue),
                      ),
                      const SizedBox(width: 8),
                      _ExperienceFilterPill(
                        icon: Icons.flash_on_rounded,
                        label: "What's On & DJs",
                        onTap: () => context.push(AppRoutes.whatsOn),
                      ),
                      const SizedBox(width: 8),
                      _ExperienceFilterPill(
                        icon: Icons.card_giftcard_rounded,
                        label: 'VIP Celebration Packages',
                        onTap: () => context.push(AppRoutes.packages),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 18)),

              // ── 4. Executive Venue Details & Operating Hours Card ───────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141519),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Card Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.diamond_outlined,
                                  color: AppColors.champagneGold,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'VENUE INTELLIGENCE',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                    color: AppColors.champagneGold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Mayfair Standard',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),
                        const Divider(color: Color(0xFF22242B), height: 1),
                        const SizedBox(height: 14),

                        // Operating Hours Row
                        _ExecutiveDetailRow(
                          icon: Icons.schedule_rounded,
                          title: 'Operating Hours',
                          subtitle: 'Today: ${venue.todayHoursFormatted}',
                          badgeText: venue.isOpenNow ? 'OPEN' : 'CLOSED',
                          badgeColor: venue.isOpenNow ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          actionLabel: 'Schedule ›',
                          onAction: () => showVenueWeeklyHoursModal(context, venue),
                        ),

                        const SizedBox(height: 12),
                        const Divider(color: Color(0xFF22242B), height: 1),
                        const SizedBox(height: 12),

                        // Address Row
                        _ExecutiveDetailRow(
                          icon: Icons.location_on_rounded,
                          title: 'Address & Valet',
                          subtitle: venue.addressFormatted,
                          actionLabel: 'Directions ›',
                          onAction: () => launchVenueDirections(context, venue),
                        ),

                        const SizedBox(height: 12),
                        const Divider(color: Color(0xFF22242B), height: 1),
                        const SizedBox(height: 12),

                        // Direct Line & Enquiries Row
                        _ExecutiveDetailRow(
                          icon: Icons.phone_rounded,
                          title: 'Direct Reception',
                          subtitle: '${venue.phoneFormatted} • ${venue.supportEmail}',
                          actionLabel: 'Call Now ›',
                          onAction: () => launchVenueCall(context, venue),
                        ),

                        if (venue.effectiveWebsite.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Divider(color: Color(0xFF22242B), height: 1),
                          const SizedBox(height: 12),
                          _ExecutiveDetailRow(
                            icon: Icons.language_rounded,
                            title: 'Official Website',
                            subtitle: venue.effectiveWebsite
                                .replaceFirst('https://', '')
                                .replaceFirst('http://', '')
                                .replaceAll('/', ''),
                            actionLabel: 'Visit ›',
                            onAction: () async {
                              final uri = Uri.parse(venue.effectiveWebsite);
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── 5. "The Tiger Bay Experience" Visual Showcase ──────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'THE TIGER BAY EXPERIENCE',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: AppColors.champagneGold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Artisan Food, Shisha & Lounges',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      AppleTouchFeedback(
                        onTap: () => showContactUsModal(context, initialVenue: venue),
                        child: Text(
                          'Enquire ›',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.champagneGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _curatedExperiences.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final item = _curatedExperiences[index];
                      return _CuratedExperienceCard(item: item);
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── 6. Live What's On & DJ Nights ────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "WHAT'S ON AT ${venue.title.toUpperCase()}",
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: AppColors.champagneGold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Upcoming Live Nights',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      AppleTouchFeedback(
                        onTap: () => context.push(AppRoutes.whatsOn),
                        child: Text(
                          'See All ›',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.champagneGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
                  child: eventsAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (events) {
                      if (events.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF141519),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                            ),
                            child: Center(
                              child: Text(
                                'Curated weekend live DJ sessions announced weekly.',
                                style: GoogleFonts.poppins(fontSize: 12, color: Colors.white60),
                              ),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        itemCount: events.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final e = events[index];
                          return AppleTouchFeedback(
                            onTap: () => context.push(AppRoutes.whatsOn),
                            child: Container(
                              width: 250,
                              decoration: BoxDecoration(
                                color: const Color(0xFF141519),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    height: 110,
                                    width: double.infinity,
                                    child: CachedNetworkImage(
                                      imageUrl: e.imageUrl,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(color: const Color(0xFF1A1A22)),
                                      errorWidget: (_, __, ___) => Container(color: const Color(0xFF1A1A22)),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          e.title,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${e.dateFormatted} • ${e.category}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: AppColors.champagneGold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── 7. VIP Celebration Packages ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VIP PACKAGES & BOOTHS',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: AppColors.champagneGold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Celebrations & Private Lounges',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      AppleTouchFeedback(
                        onTap: () => context.push(AppRoutes.packages),
                        child: Text(
                          'View All ›',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.champagneGold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: 190,
                  child: packagesAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
                    ),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (pkgs) {
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        itemCount: pkgs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final p = pkgs[index];
                          return AppleTouchFeedback(
                            onTap: () => showContactUsModal(
                              context,
                              initialVenue: venue,
                              initialPackage: p.title,
                            ),
                            child: Container(
                              width: 250,
                              decoration: BoxDecoration(
                                color: const Color(0xFF141519),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Stack(
                                    children: [
                                      SizedBox(
                                        height: 100,
                                        width: double.infinity,
                                        child: CachedNetworkImage(
                                          imageUrl: p.imageUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (_, __) => Container(color: const Color(0xFF1A1A22)),
                                          errorWidget: (_, __, ___) => Container(color: const Color(0xFF1A1A22)),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: 6,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.8),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.gold, width: 0.8),
                                          ),
                                          child: Text(
                                            p.priceFormatted,
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.champagneGold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.title,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          p.guestCount,
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              // Bottom padding to clear floating reservation bar
              const SliverToBoxAdapter(child: SizedBox(height: 110)),
            ],
          ),

          // ── Persistent Floating Bottom Reservation Bar ────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1014).withValues(alpha: 0.95),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: venue.isOpenNow ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                venue.isOpenNow ? 'OPEN TONIGHT' : 'OPENS 5:00 PM',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            venue.todayHoursFormatted,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.champagneGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    AppleTouchFeedback(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        context.push(AppRoutes.booking);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Book Table',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.black,
                              size: 15,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Curated Experience Card ───────────────────────────────────────────────────

class _CuratedExperienceCard extends StatelessWidget {
  final Map<String, String> item;

  const _CuratedExperienceCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF141519),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: item['url']!,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: const Color(0xFF1A1A22)),
              errorWidget: (_, __, ___) => Container(color: const Color(0xFF1A1A22)),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                  stops: const [0.3, 1.0],
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
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 0.8),
              ),
              child: Text(
                item['category']!,
                style: GoogleFonts.outfit(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: AppColors.champagneGold,
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
                  item['title']!,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item['description']!,
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    color: Colors.white70,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Luxury Concierge Tile ─────────────────────────────────────────────────────

class _LuxuryConciergeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _LuxuryConciergeTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppleTouchFeedback(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF141519),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.champagneGold, size: 18),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Experience Filter Pill ───────────────────────────────────────────────────

class _ExperienceFilterPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ExperienceFilterPill({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppleTouchFeedback(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF141519),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.3),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.champagneGold, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Executive Detail Row ──────────────────────────────────────────────────────

class _ExecutiveDetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badgeText;
  final Color? badgeColor;
  final String actionLabel;
  final VoidCallback onAction;

  const _ExecutiveDetailRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.badgeColor,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: Icon(icon, color: AppColors.champagneGold, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (badgeText != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: (badgeColor ?? AppColors.gold).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badgeText!,
                        style: GoogleFonts.outfit(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: badgeColor ?? AppColors.gold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        AppleTouchFeedback(
          onTap: onAction,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: Text(
              actionLabel,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.champagneGold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
