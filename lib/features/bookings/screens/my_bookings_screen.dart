import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart'; // 💡 Added missing import
import '../../../data/models/booking_model.dart';
import '../providers/booking_provider.dart';

class MyBookingsScreen extends ConsumerStatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  ConsumerState<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends ConsumerState<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _venueFilter = 'All Venues';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(userBookingsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
              child: Row(
                children: [
                  const Text(
                    'Reservations',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  // Venue filter dropdown
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _venueFilter,
                        isDense: true,
                        icon: Icon(Icons.keyboard_arrow_down,
                            size: 18, color: Colors.grey.shade500),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        onChanged: (v) =>
                            setState(() => _venueFilter = v ?? 'All Venues'),
                        items: const [
                          DropdownMenuItem(
                              value: 'All Venues', child: Text('All Venues')),
                          DropdownMenuItem(
                              value: 'London Mayfair',
                              child: Text('London Mayfair')),
                          DropdownMenuItem(
                              value: 'Tiger Bay', child: Text('Tiger Bay')),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Tabs ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ), // 💡 Properly ends BoxDecoration, leaving TabBar open!
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(3),
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                  labelColor: Colors.black87,
                  unselectedLabelColor: Colors.grey.shade500,
                  tabs: const [
                    Tab(text: 'Upcoming'),
                    Tab(text: 'Past'),
                    Tab(text: 'Cancelled'),
                  ],
                ), // 💡 This properly closes the TabBar widget here
              ),
            ),

            const SizedBox(height: 8),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: bookingsAsync.when(
                data: (bookings) {
                  final upcoming = bookings
                      .where((b) => b.status == BookingStatus.upcoming)
                      .toList();
                  final past = bookings
                      .where((b) => b.status == BookingStatus.past)
                      .toList();
                  final cancelled = bookings
                      .where((b) => b.status == BookingStatus.cancelled)
                      .toList();

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _BookingList(
                        bookings: upcoming,
                        label: 'UPCOMING',
                        showNewButton: true,
                      ),
                      _BookingList(bookings: past, label: 'RECENT HISTORY'),
                      _BookingList(bookings: cancelled, label: 'CANCELLED'),
                    ],
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(
                      color: AppColors.gold, strokeWidth: 2),
                ),
                error: (_, __) => _fallbackList(),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // ── 🛠️ FIXED NAVIGATION ROUTE ────────────────────────────────────────
        onPressed: () =>
            context.push(AppRoutes.booking), // Cleared out string encodings
        backgroundColor: AppColors.gold,
        label: const Text(
          'New Booking',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _fallbackList() {
    return TabBarView(
      controller: _tabController,
      children: const [
        _BookingList(bookings: [], label: 'UPCOMING', showNewButton: true),
        _BookingList(bookings: [], label: 'RECENT HISTORY'),
        _BookingList(bookings: [], label: 'CANCELLED'),
      ],
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<BookingModel> bookings;
  final String label;
  final bool showNewButton;

  const _BookingList({
    required this.bookings,
    required this.label,
    this.showNewButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (bookings.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Colors.black45,
            ),
          ),
          const SizedBox(height: 12),
          ...bookings.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _BookingCard(booking: b),
              )),
        ] else
          _buildEmpty(context),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No ${label.toLowerCase()} reservations',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
    return GestureDetector(
      // Ensure detail parameters are decoupled from path string transforms
      onTap: () => context.push('${AppRoutes.myBookings}/detail/${booking.id}',
          extra: booking),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking.branchName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),

              Divider(color: Colors.grey.shade100, height: 20),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined,
                                size: 13, color: Colors.grey.shade400),
                            const SizedBox(width: 6),
                            Text(
                              '${_months[booking.bookingDate.month]} ${booking.bookingDate.day}, ${booking.bookingDate.year}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 13, color: Colors.grey.shade400),
                            const SizedBox(width: 6),
                            Text(
                              booking.bookingTime,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.group_outlined,
                          size: 14, color: Colors.grey.shade400),
                      const SizedBox(width: 6),
                      Text(
                        '${booking.guestCount} Guests',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
