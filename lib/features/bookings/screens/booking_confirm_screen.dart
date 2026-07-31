import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/constants/app_routes.dart';
import 'package:tigerbay_app/core/services/paypal_service.dart';
import 'package:tigerbay_app/data/models/booking_model.dart';
import 'package:tigerbay_app/features/bookings/providers/booking_provider.dart';

class BookingConfirmScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> bookingData;

  const BookingConfirmScreen({super.key, required this.bookingData});

  @override
  ConsumerState<BookingConfirmScreen> createState() =>
      _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends ConsumerState<BookingConfirmScreen> {
  bool _isProcessing = false;

  // Payment method selection — PayPal is default (live), Stripe is scaffolded
  _BookingPaymentMethod _selectedMethod = _BookingPaymentMethod.paypal;

  @override
  Widget build(BuildContext context) {
    final bookingData = widget.bookingData;
    final bookingId = bookingData['bookingId']?.toString() ?? '';
    final depositAmount =
        (bookingData['depositAmount'] as num?)?.toDouble() ?? 20.0;

    final isButtonDisabled = _isProcessing;

    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      appBar: AppBar(
        backgroundColor: AppColors.brandBlack,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Confirm Booking',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded,
                      color: AppColors.gold, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Secure Deposit Required',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'A £${depositAmount.toStringAsFixed(2)} deposit secures your table. Fully refundable if cancelled 24h in advance.',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const Text(
              'PAYMENT SUMMARY',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            _SummaryRow(
                label: 'Deposit',
                value: '£${depositAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            const _SummaryRow(label: 'Processing fee', value: '£0.00'),
            const Divider(color: AppColors.border, height: 28),
            _SummaryRow(
              label: 'Total due today',
              value: '£${depositAmount.toStringAsFixed(2)}',
              isBold: true,
            ),

            const SizedBox(height: 24),

            // ── Payment Method Selector ────────────────────────────────
            const Text(
              'PAY WITH',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),

            // PayPal option
            _PaymentMethodTile(
              method: _BookingPaymentMethod.paypal,
              selected: _selectedMethod,
              onTap: () =>
                  setState(() => _selectedMethod = _BookingPaymentMethod.paypal),
              label: 'PayPal',
              subtitle: 'Sandbox — pay securely via PayPal',
              icon: const _PayPalIconSmall(),
            ),
            const SizedBox(height: 8),

            // Stripe option (scaffolded — coming soon)
            _PaymentMethodTile(
              method: _BookingPaymentMethod.stripe,
              selected: _selectedMethod,
              onTap: null, // disabled until Stripe Edge Function is deployed
              label: 'Card (Stripe)',
              subtitle: 'Coming soon',
              icon: const Icon(Icons.credit_card_rounded,
                  color: AppColors.textSecondary, size: 20),
              disabled: true,
            ),

            const Spacer(),

            // ── Pay Button ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: isButtonDisabled
                    ? null
                    : () => _handlePayment(
                          context: context,
                          bookingId: bookingId,
                          depositAmount: depositAmount,
                        ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  disabledBackgroundColor:
                      AppColors.gold.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_selectedMethod == _BookingPaymentMethod.paypal)
                            const _PayPalIconSmall(),
                          if (_selectedMethod == _BookingPaymentMethod.paypal)
                            const SizedBox(width: 8),
                          Text(
                            _selectedMethod == _BookingPaymentMethod.paypal
                                ? 'Pay £${depositAmount.toStringAsFixed(2)} with PayPal'
                                : 'Pay £${depositAmount.toStringAsFixed(2)} with Card',
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Routes to the PayPal checkout and confirms the booking on success.
  Future<void> _handlePayment({
    required BuildContext context,
    required String bookingId,
    required double depositAmount,
  }) async {
    setState(() => _isProcessing = true);

    // Capture ScaffoldMessenger BEFORE any async gap
    final messenger = ScaffoldMessenger.of(context);

    try {
      // ── PayPal: live sandbox checkout for the table deposit ────────────
      final paid = await PayPalService.pay(
        context: context,
        amount: depositAmount.toStringAsFixed(2),
        currency: 'GBP',
        description: 'TigerBay Table Deposit',
      );

      if (!mounted) return;

      if (paid) {
        // Confirm the booking in the DB (status pending → upcoming)
        await _confirmBookingInDb(bookingId);
        if (!context.mounted) return;
        _showSuccess(context);
      } else {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('PayPal payment was cancelled or failed.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Flips a paid booking from `pending` to `upcoming` so it appears under
  /// "Upcoming" in My Bookings. Demo/fake booking IDs are skipped.
  Future<void> _confirmBookingInDb(String bookingId) async {
    final bookingIdInt = int.tryParse(bookingId);
    if (bookingIdInt == null) {
      debugPrint(
        '[BookingConfirm] Skipping DB confirm for demo booking: $bookingId',
      );
      return;
    }
    try {
      await ref
          .read(bookingRepositoryProvider)
          .confirmBookingPaymentWithPayPal(bookingId: bookingIdInt);
    } catch (error) {
      // Non-blocking: booking stays 'pending' but the user flow completes.
      debugPrint('[BookingConfirm] DB confirm failed (non-blocking): $error');
    }
  }

  void _showSuccess(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.success, size: 36),
            ),
            const SizedBox(height: 16),
            const Text(
              'Booking Confirmed!',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              'A confirmation email and calendar invite have been sent to you.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 13, color: Colors.black45, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // 💡 Force dynamic provider stream cache purge to fetch brand-new DB records instantly
                  ref.invalidate(userBookingsStreamProvider);

                  // 💡 Closes the alert box overlay safely using the localized dialog builder context
                  Navigator.pop(dialogContext);

                  // 💡 Transitions parent screen frame back to the central reservation dashboard
                  if (context.mounted) {
                    context.go(AppRoutes.myBookings);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  elevation: 0,
                ),
                child: const Text(
                  'View My Bookings',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool isBold;
  const _SummaryRow(
      {required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
            )),
        const Spacer(),
        Text(value,
            style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: isBold ? AppColors.gold : AppColors.textPrimary,
            )),
      ],
    );
  }
}

// ── Payment Method Enum ───────────────────────────────────────────────────────
enum _BookingPaymentMethod { paypal, stripe }

// ── Payment Method Tile ───────────────────────────────────────────────────────
class _PaymentMethodTile extends StatelessWidget {
  final _BookingPaymentMethod method;
  final _BookingPaymentMethod selected;
  final VoidCallback? onTap;
  final String label;
  final String subtitle;
  final Widget icon;
  final bool disabled;

  const _PaymentMethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
    required this.label,
    required this.subtitle,
    required this.icon,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == method;
    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.gold : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Radio dot
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isSelected ? AppColors.gold : AppColors.border,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.gold,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              icon,
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
              if (disabled) ...const [
                Spacer(),
                _ComingSoonBadge(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Coming Soon Badge ─────────────────────────────────────────────────────────
class _ComingSoonBadge extends StatelessWidget {
  const _ComingSoonBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Soon',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textHint,
        ),
      ),
    );
  }
}

// ── PayPal Icon (small inline) ────────────────────────────────────────────────
class _PayPalIconSmall extends StatelessWidget {
  const _PayPalIconSmall();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Color(0xFF003087),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('P',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1)),
          ),
        ),
        const SizedBox(width: 1),
        Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: Color(0xFF009CDE),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('P',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 1)),
          ),
        ),
      ],
    );
  }
}

// ── Booking Detail Screen Re-Export Declaration ──────────────────────────────

class BookingDetailScreen extends ConsumerWidget {
  final String bookingId;
  const BookingDetailScreen({super.key, required this.bookingId});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(userBookingsStreamProvider);

    return bookingsAsync.when(
      data: (bookings) {
        final booking = bookings.where((b) => b.id.toString() == bookingId).firstOrNull;
        if (booking == null) {
          return const Scaffold(
            backgroundColor: AppColors.brandBlack,
            body: Center(child: Text('Booking not found', style: TextStyle(color: AppColors.textSecondary))),
          );
        }
        return _buildDetail(context, ref, booking);
      },
      loading: () => const Scaffold(
        backgroundColor: AppColors.brandBlack,
        body: Center(
            child: CircularProgressIndicator(
                color: AppColors.gold, strokeWidth: 2)),
      ),
      error: (_, __) => const Scaffold(
        backgroundColor: AppColors.brandBlack,
        body: Center(child: Text('Error loading booking', style: TextStyle(color: AppColors.textSecondary))),
      ),
    );
  }

  Widget _buildDetail(
      BuildContext context, WidgetRef ref, BookingModel booking) {
    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      appBar: AppBar(
        backgroundColor: AppColors.brandBlack,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Booking Details',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(booking.branchName,
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold)),
                  const SizedBox(height: 4),
                  const Divider(color: AppColors.border, height: 24),
                  _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Date',
                      value:
                          '${_months[booking.bookingDate.month]} ${booking.bookingDate.day}, ${booking.bookingDate.year}'),
                  const SizedBox(height: 12),
                  _DetailRow(
                      icon: Icons.access_time_rounded,
                      label: 'Time',
                      value: booking.bookingTime),
                  const SizedBox(height: 12),
                  _DetailRow(
                      icon: Icons.group_outlined,
                      label: 'Guests',
                      value: '${booking.guestCount} people'),
                ],
              ),
            ),
            const SizedBox(height: 28),
            if (booking.status == BookingStatus.upcoming) ...[
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => context.push('${AppRoutes.myBookings}/new'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.gold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  child: const Text(
                    'Modify Booking',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  onPressed: () => _confirmCancel(context, ref, booking.id),
                  style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28))),
                  child: const Text(
                    'Cancel Booking',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppColors.error),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref, int id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cancel Booking?',
            style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        content: const Text(
          'Your deposit will be refunded within 3-5 business days if cancelled more than 24 hours before.',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep It',
                style: TextStyle(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(bookingNotifierProvider.notifier)
                  .cancelBooking(id);
              if (context.mounted) context.go(AppRoutes.myBookings);
            },
            child: const Text('Cancel',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.gold),
        const SizedBox(width: 10),
        Text(label,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ],
    );
  }
}
