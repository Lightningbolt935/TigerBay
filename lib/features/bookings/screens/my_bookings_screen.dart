import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/models/branch_model.dart';
import '../../../features/home/providers/home_provider.dart';
import '../../../shared/widgets/apple_touch_feedback.dart';
import '../providers/booking_provider.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Luxury Reservations Screen (Tier-1 Benchmark)
/// ═══════════════════════════════════════════════════════════════════════════
class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _venueFilter = 'All Lounges';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        HapticFeedback.selectionClick();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(userBookingsStreamProvider);
    final branchesAsync = ref.watch(branchesProvider);

    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top Header ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Row(
                children: [
                  if (Navigator.of(context).canPop()) ...[
                    AppleTouchFeedback(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(AppRoutes.home);
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(
                          CupertinoIcons.chevron_back,
                          size: 24,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                  Text(
                    'Reservations',
                    style: AppTypography.headline.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // ── Dynamic Lounge Filter ────────────────────────────────
                  branchesAsync.maybeWhen(
                    data: (branches) => _buildVenueDropdown(branches),
                    orElse: () => _buildVenueDropdown(const []),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Modern Luxury Tab Selector ──────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                height: 44,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  labelColor: AppColors.champagneGold,
                  unselectedLabelColor: AppColors.textSecondary,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Upcoming'),
                    Tab(text: 'Past'),
                    Tab(text: 'Cancelled'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Reservations List Content ───────────────────────────────────
            Expanded(
              child: RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.surface,
                onRefresh: () async {
                  HapticFeedback.lightImpact();
                  try {
                    await Supabase.instance.client.functions.invoke(
                      'sync-collins-bookings',
                    );
                  } catch (_) {}
                  ref.invalidate(userBookingsStreamProvider);
                },
                child: bookingsAsync.when(
                  data: (allBookings) {
                    // Apply venue filter if set
                    final filtered = _venueFilter == 'All Lounges'
                        ? allBookings
                        : allBookings.where((b) {
                            return b.branchName.toLowerCase().contains(
                                  _venueFilter.toLowerCase(),
                                );
                          }).toList();

                    final upcoming = filtered
                        .where((b) => b.status == BookingStatus.upcoming)
                        .toList();
                    final past = filtered
                        .where((b) => b.status == BookingStatus.past)
                        .toList();
                    final cancelled = filtered
                        .where((b) => b.status == BookingStatus.cancelled)
                        .toList();

                    return TabBarView(
                      controller: _tabController,
                      children: [
                        _BookingList(
                          bookings: upcoming,
                          label: 'UPCOMING RESERVATIONS',
                          status: BookingStatus.upcoming,
                        ),
                        _BookingList(
                          bookings: past,
                          label: 'PREVIOUS VISITS',
                          status: BookingStatus.past,
                        ),
                        _BookingList(
                          bookings: cancelled,
                          label: 'CANCELLED BOOKINGS',
                          status: BookingStatus.cancelled,
                        ),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 2,
                    ),
                  ),
                  error: (_, __) => _fallbackList(),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AppleTouchFeedback(
        onTap: () {
          HapticFeedback.mediumImpact();
          context.push(AppRoutes.booking);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.gold, AppColors.champagneGold],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.plus, color: Colors.black, size: 18),
              SizedBox(width: 8),
              Text(
                'Reserve a Table',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVenueDropdown(List<Branch> branches) {
    final loungeItems = <String>['All Lounges'];
    for (final b in branches) {
      if (b.title.isNotEmpty && !loungeItems.contains(b.title)) {
        loungeItems.add(b.title);
      }
    }
    // Fallback if empty
    if (loungeItems.length == 1) {
      loungeItems.addAll(['Kingsbury', 'Hanger Lane']);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: loungeItems.contains(_venueFilter) ? _venueFilter : 'All Lounges',
          isDense: true,
          dropdownColor: AppColors.surface,
          icon: const Icon(
            CupertinoIcons.chevron_down,
            size: 14,
            color: AppColors.champagneGold,
          ),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.champagneGold,
          ),
          onChanged: (v) {
            HapticFeedback.lightImpact();
            setState(() => _venueFilter = v ?? 'All Lounges');
          },
          items: loungeItems.map((name) {
            return DropdownMenuItem<String>(
              value: name,
              child: Text(
                name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _fallbackList() {
    return TabBarView(
      controller: _tabController,
      children: const [
        _BookingList(
          bookings: [],
          label: 'UPCOMING RESERVATIONS',
          status: BookingStatus.upcoming,
        ),
        _BookingList(
          bookings: [],
          label: 'PREVIOUS VISITS',
          status: BookingStatus.past,
        ),
        _BookingList(
          bookings: [],
          label: 'CANCELLED BOOKINGS',
          status: BookingStatus.cancelled,
        ),
      ],
    );
  }
}

// ── Booking List Widget ───────────────────────────────────────────────────────

class _BookingList extends StatelessWidget {
  final List<BookingModel> bookings;
  final String label;
  final BookingStatus status;

  const _BookingList({
    required this.bookings,
    required this.label,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return _buildEmpty(context);
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 88),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ...bookings.map(
          (b) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _BookingCard(booking: b),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final String title;
    final String description;
    final IconData icon;

    switch (status) {
      case BookingStatus.upcoming:
        title = 'No Upcoming Reservations';
        description =
            'Reserve a VIP table, private dining booth, or shisha lounge spot with instant confirmation.';
        icon = CupertinoIcons.calendar_badge_plus;
      case BookingStatus.past:
        title = 'No Past Reservations';
        description =
            'Your previous dining and lounge experiences at Tiger Bay will appear here.';
        icon = CupertinoIcons.clock;
      case BookingStatus.cancelled:
        title = 'No Cancelled Reservations';
        description = 'You currently have no cancelled bookings.';
        icon = CupertinoIcons.clear_circled;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surface,
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Icon(
                icon,
                size: 32,
                color: AppColors.champagneGold,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            if (status == BookingStatus.upcoming) ...[
              const SizedBox(height: 24),
              AppleTouchFeedback(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push(AppRoutes.booking);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.gold,
                      width: 1.2,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        CupertinoIcons.compass,
                        size: 16,
                        color: AppColors.champagneGold,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Explore Lounges',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.champagneGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Luxury Booking Card ───────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  const _BookingCard({required this.booking});

  static const _months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    return AppleTouchFeedback(
      onTap: () {
        HapticFeedback.lightImpact();
        context.push(
          '${AppRoutes.bookingDetail}/${booking.id}',
          extra: booking,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row: Venue Name & Status Capsule ───────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      booking.branchName.isEmpty
                          ? 'Tiger Bay Lounge'
                          : booking.branchName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusPill(booking.status),
                ],
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Divider(
                  color: Colors.white.withValues(alpha: 0.06),
                  height: 1,
                ),
              ),

              // ── Details Row: Date, Time, Guests ────────────────────────
              Row(
                children: [
                  // Date
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          CupertinoIcons.calendar,
                          size: 15,
                          color: AppColors.champagneGold,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            '${booking.bookingDate.day} ${_months[booking.bookingDate.month]} ${booking.bookingDate.year}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Time
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.time,
                        size: 15,
                        color: AppColors.champagneGold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        booking.bookingTime,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 14),

                  // Guests
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.person_2,
                        size: 15,
                        color: AppColors.champagneGold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${booking.guestCount}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(width: 10),

                  // Trailing Chevron
                  const Icon(
                    CupertinoIcons.chevron_forward,
                    size: 16,
                    color: Colors.white30,
                  ),
                ],
              ),

              if (booking.specialRequests != null &&
                  booking.specialRequests!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        CupertinoIcons.chat_bubble_text,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          booking.specialRequests!.trim(),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill(BookingStatus status) {
    final Color badgeColor;
    final String label;

    switch (status) {
      case BookingStatus.upcoming:
        badgeColor = AppColors.success;
        label = 'CONFIRMED';
      case BookingStatus.past:
        badgeColor = Colors.white54;
        label = 'VISITED';
      case BookingStatus.cancelled:
        badgeColor = AppColors.error;
        label = 'CANCELLED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}
