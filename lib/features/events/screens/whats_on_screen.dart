import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/constants/app_routes.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/data/models/whats_on_event_model.dart';
import 'package:tigerbay_app/features/contact/screens/contact_us_screen.dart';
import 'package:tigerbay_app/features/events/providers/whats_on_provider.dart';
import 'package:tigerbay_app/features/home/providers/home_provider.dart';
import 'package:flutter/services.dart';
import 'package:tigerbay_app/features/packages/screens/packages_screen.dart';
import 'package:tigerbay_app/shared/widgets/apple_touch_feedback.dart';

class WhatsOnScreen extends ConsumerStatefulWidget {
  const WhatsOnScreen({super.key});

  @override
  ConsumerState<WhatsOnScreen> createState() => _WhatsOnScreenState();
}

class _WhatsOnScreenState extends ConsumerState<WhatsOnScreen> {
  int _selectedSegment = 0; // 0 = What's On, 1 = VIP Packages
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'DJ Night',
    'Live Sports',
    'Ladies Night',
    'Live Music',
    'VIP Exclusive',
  ];

  @override
  Widget build(BuildContext context) {
    final selectedBranch = ref.watch(selectedBranchProvider);
    final eventsAsync = ref.watch(whatsOnEventsProvider(selectedBranch?.id));

    return Scaffold(
      backgroundColor: const Color(0xFF0F1012),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141416),
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.flash_on_rounded,
                      color: AppColors.champagneGold,
                      size: 16,
                    ),
                  ),
                ),
              ),
        title: Text(
          _selectedSegment == 0 ? "What's On & Events" : "VIP Packages",
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_unread_rounded,
                color: AppColors.gold),
            tooltip: 'Submit Enquiry',
            onPressed: () => showContactUsModal(
              context,
              initialVenue: selectedBranch,
              initialEnquiryType: 'General Enquiry',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Apple-Style Segmented Capsule Selector ──
          Container(
            color: const Color(0xFF141416),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E24),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppleTouchFeedback(
                      onTap: () {
                        if (_selectedSegment != 0) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedSegment = 0);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _selectedSegment == 0
                              ? AppColors.gold
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: _selectedSegment == 0
                              ? [
                                  BoxShadow(
                                    color: AppColors.gold.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.nightlife_rounded,
                              size: 15,
                              color: _selectedSegment == 0
                                  ? Colors.black
                                  : Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "What's On",
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: _selectedSegment == 0
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _selectedSegment == 0
                                    ? Colors.black
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: AppleTouchFeedback(
                      onTap: () {
                        if (_selectedSegment != 1) {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedSegment = 1);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: _selectedSegment == 1
                              ? AppColors.gold
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: _selectedSegment == 1
                              ? [
                                  BoxShadow(
                                    color: AppColors.gold.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.card_giftcard_rounded,
                              size: 15,
                              color: _selectedSegment == 1
                                  ? Colors.black
                                  : Colors.white70,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'VIP Packages',
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: _selectedSegment == 1
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _selectedSegment == 1
                                    ? Colors.black
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_selectedSegment == 1)
            const Expanded(child: PackagesViewContent())
          else ...[
            // ── Venue Indicator & Category Selector ────────────────────────
            Container(
              padding: const EdgeInsets.only(bottom: 12),
              color: const Color(0xFF141416),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (selectedBranch != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              color: AppColors.gold, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            'Showing entertainment for Tiger Bay ${selectedBranch.title}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: AppColors.gold,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final cat = _categories[index];
                        final isSelected = _selectedCategory == cat;
                        return AppleTouchFeedback(
                          onTap: () => setState(() => _selectedCategory = cat),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.gold
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.gold
                                    : AppColors.glassBorder,
                                width: 0.8,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                cat,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.black
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // ── Events List ────────────────────────────────────────────────
          Expanded(
            child: eventsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                    color: AppColors.gold, strokeWidth: 2),
              ),
              error: (err, _) => Center(
                child: Text(
                  'Could not load events: $err',
                  style: GoogleFonts.poppins(color: AppColors.textSecondary),
                ),
              ),
              data: (events) {
                final filtered = _selectedCategory == 'All'
                    ? events
                    : events
                        .where((e) => e.category == _selectedCategory)
                        .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event_busy_rounded,
                            size: 48, color: AppColors.textHint),
                        const SizedBox(height: 12),
                        Text(
                          'No events in this category yet',
                          style: GoogleFonts.poppins(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final event = filtered[index];
                    return _WhatsOnCard(
                      event: event,
                      branch: selectedBranch,
                    );
                  },
                );
              },
            ),
          ),
          ],
        ],
      ),
    );
  }
}

class _WhatsOnCard extends StatelessWidget {
  final WhatsOnEvent event;
  final Branch? branch;

  const _WhatsOnCard({
    required this.event,
    this.branch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16171B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 0.8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Event Image Banner with Date Tag ──
          Stack(
            children: [
              SizedBox(
                height: 160,
                width: double.infinity,
                child: Image.network(
                  event.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF22242B),
                    child: const Center(
                      child: Icon(Icons.nightlife_rounded,
                          color: AppColors.gold, size: 40),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        const Color(0xFF16171B).withValues(alpha: 0.9),
                      ],
                    ),
                  ),
                ),
              ),
              // Category Chip
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.5),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.flash_on_rounded,
                          color: AppColors.gold, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        event.category.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Time Badge
              Positioned(
                bottom: 12,
                left: 14,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16171B),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border, width: 0.6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded,
                          size: 12, color: AppColors.gold),
                      const SizedBox(width: 4),
                      Text(
                        '${event.dateFormatted} • ${event.timeFormatted}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ── Event Details & Actions ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  event.subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  event.description,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons Row: Reserve Table + Enquire
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => context.push(AppRoutes.booking),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.calendar_today_rounded,
                                  size: 14, color: Colors.black),
                              const SizedBox(width: 6),
                              Text(
                                'RESERVE TABLE',
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(
                              color: AppColors.glassBorder, width: 0.8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => showContactUsModal(
                          context,
                          initialVenue: branch,
                          initialEnquiryType: 'Table Reservation',
                        ),
                        child: Text(
                          'ENQUIRE',
                          style: GoogleFonts.poppins(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
