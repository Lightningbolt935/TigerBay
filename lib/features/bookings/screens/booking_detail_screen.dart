import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/booking_model.dart';
import '../../../shared/widgets/apple_touch_feedback.dart';
import '../providers/booking_provider.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Luxury Booking Detail Screen (Tier-1 Benchmark)
/// ═══════════════════════════════════════════════════════════════════════════
class BookingDetailScreen extends ConsumerStatefulWidget {
  final String bookingId;
  final BookingModel? initialBooking;

  const BookingDetailScreen({
    super.key,
    required this.bookingId,
    this.initialBooking,
  });

  @override
  ConsumerState<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends ConsumerState<BookingDetailScreen> {
  bool _isCancelling = false;

  static const _months = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(userBookingsStreamProvider);

    return bookingsAsync.when(
      data: (bookings) {
        final booking = bookings
                .where((b) => b.id.toString() == widget.bookingId)
                .firstOrNull ??
            widget.initialBooking;

        if (booking == null) {
          return _buildNotFound(context);
        }

        return _buildDetailContent(context, booking);
      },
      loading: () => widget.initialBooking != null
          ? _buildDetailContent(context, widget.initialBooking!)
          : const Scaffold(
              backgroundColor: AppColors.brandBlack,
              body: Center(
                child: CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 2,
                ),
              ),
            ),
      error: (_, __) => widget.initialBooking != null
          ? _buildDetailContent(context, widget.initialBooking!)
          : _buildNotFound(context),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: AppleTouchFeedback(
          onTap: () => context.pop(),
          child: const Icon(
            CupertinoIcons.chevron_back,
            size: 22,
            color: AppColors.textPrimary,
          ),
        ),
        title: Text('Reservation', style: AppTypography.headline),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.question_circle,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Reservation not found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.myBookings),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
              ),
              child: const Text('Back to Reservations'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailContent(BuildContext context, BookingModel booking) {
    final formattedDate =
        '${booking.bookingDate.day} ${_months[booking.bookingDate.month]} ${booking.bookingDate.year}';

    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: AppleTouchFeedback(
          onTap: () {
            HapticFeedback.lightImpact();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.myBookings);
            }
          },
          child: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Icon(
              CupertinoIcons.chevron_back,
              size: 22,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        title: Text(
          'Reservation Details',
          style: AppTypography.headline.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
        children: [
          // ── Main Luxury Card ─────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Venue & Status Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.branchName.isEmpty
                                ? 'Tiger Bay Lounge'
                                : booking.branchName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'REF: #TB-${booking.id.toString().padLeft(5, '0')}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.champagneGold,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusPill(booking.status),
                  ],
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Divider(
                    color: Colors.white.withValues(alpha: 0.08),
                    height: 1,
                  ),
                ),

                // Date, Time, Guests rows
                _DetailRow(
                  icon: CupertinoIcons.calendar,
                  label: 'Date',
                  value: formattedDate,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: CupertinoIcons.time,
                  label: 'Time Slot',
                  value: booking.bookingTime,
                ),
                const SizedBox(height: 14),
                _DetailRow(
                  icon: CupertinoIcons.person_2,
                  label: 'Party Size',
                  value: '${booking.guestCount} Guests',
                ),

                if (booking.specialRequests != null &&
                    booking.specialRequests!.trim().isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(
                      color: Colors.white.withValues(alpha: 0.08),
                      height: 1,
                    ),
                  ),
                  const Text(
                    'SPECIAL REQUESTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Text(
                      booking.specialRequests!.trim(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Deposit & Protection Information ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  CupertinoIcons.shield_lefthalf_fill,
                  color: AppColors.champagneGold,
                  size: 22,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Deposit & Cancellation Policy',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.champagneGold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your reservation deposit is held securely. Cancellations made more than 24 hours prior to booking time are 100% refunded to your original payment method.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.7),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Actions (Upcoming Reservations Only) ─────────────────────────
          if (booking.status == BookingStatus.upcoming) ...[
            // Modify reservation
            AppleTouchFeedback(
              onTap: () {
                HapticFeedback.lightImpact();
                context.push(AppRoutes.booking);
              },
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: AppColors.gold,
                    width: 1.2,
                  ),
                ),
                alignment: Alignment.center,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.pencil,
                      size: 16,
                      color: AppColors.champagneGold,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Modify Reservation',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.champagneGold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Cancel reservation
            AppleTouchFeedback(
              onTap: _isCancelling
                  ? null
                  : () => _confirmCancel(booking.id),
              child: Container(
                width: double.infinity,
                height: 50,
                alignment: Alignment.center,
                child: _isCancelling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.error,
                        ),
                      )
                    : const Text(
                        'Cancel Reservation',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ],
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
          const SizedBox(width: 6),
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

  void _confirmCancel(int id) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 34),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.error.withValues(alpha: 0.12),
              ),
              child: const Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: AppColors.error,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Cancel This Reservation?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your deposit will be automatically refunded to your original payment method within 3-5 business days if cancelled at least 24 hours prior.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            // Confirm cancel button
            AppleTouchFeedback(
              onTap: () async {
                HapticFeedback.heavyImpact();
                Navigator.pop(bottomSheetContext);
                setState(() => _isCancelling = true);
                final success = await ref
                    .read(bookingNotifierProvider.notifier)
                    .cancelBooking(id);
                if (!mounted) return;
                setState(() => _isCancelling = false);
                if (success) {
                  ref.invalidate(userBookingsStreamProvider);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Reservation cancelled. Refund has been initiated.',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: AppColors.surface,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  );
                  context.go(AppRoutes.myBookings);
                }
              },
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(25),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Yes, Cancel Reservation',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Keep booking
            AppleTouchFeedback(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(bottomSheetContext);
              },
              child: Container(
                width: double.infinity,
                height: 48,
                alignment: Alignment.center,
                child: const Text(
                  'Keep Reservation',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.champagneGold),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
