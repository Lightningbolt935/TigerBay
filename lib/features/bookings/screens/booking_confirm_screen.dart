import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/constants/app_routes.dart';
import 'package:tigerbay_app/core/services/paypal_service.dart';
import 'package:tigerbay_app/data/models/booking_model.dart';
import 'package:tigerbay_app/features/bookings/providers/booking_provider.dart';

// ── Payment method enum ───────────────────────────────────────────────────────
enum _PaymentMethod { paypal, stripe }

// ═══════════════════════════════════════════════════════════════════════════════
// BookingConfirmScreen
// ═══════════════════════════════════════════════════════════════════════════════
// Handles the final deposit payment step before a booking is confirmed.
// - PayPal: fully wired — launches PaypalCheckoutView WebView, then flips
//   booking status to 'upcoming' in Supabase via confirmBookingPaymentPayPal().
// - Stripe: Coming Soon — tab displayed but disabled until pk_test_ key is set.
class BookingConfirmScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> bookingData;

  const BookingConfirmScreen({super.key, required this.bookingData});

  @override
  ConsumerState<BookingConfirmScreen> createState() =>
      _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends ConsumerState<BookingConfirmScreen> {
  _PaymentMethod _selectedMethod = _PaymentMethod.paypal;
  bool _isProcessing = false;

  // TODO(stripe): When Stripe is activated, re-add _stripeAccountId fetch
  // via repo.fetchBranchStripeAccountId(branchId) and pass it to the
  // create-payment-intent edge function as transfer_data_destination.

  @override
  void initState() {
    super.initState();
  }

  // ── PayPal payment flow ───────────────────────────────────────────────────
  Future<void> _handlePayPal() async {
    final bookingId = widget.bookingData['bookingId'] as String? ?? '';
    final depositAmount =
        (widget.bookingData['depositAmount'] as num?)?.toDouble() ?? 20.0;

    setState(() => _isProcessing = true);
    try {
      final paid = await PayPalService.pay(
        context: context,
        amount: depositAmount.toStringAsFixed(2),
        currency: 'GBP',
        description: 'TigerBay Table Deposit',
      );

      if (!mounted) return;

      if (paid) {
        // ── Confirm booking status in Supabase ──────────────────────────────
        // PaypalCheckoutView does not expose the raw order ID directly, so we
        // store a timestamp-prefixed sentinel. Server-side reconciliation via
        // PayPal webhooks should be used for production auditing.
        try {
          final repo = ref.read(bookingRepositoryProvider);
          await repo.confirmBookingPaymentPayPal(
            bookingId: bookingId,
            paypalOrderId: 'paypal_${DateTime.now().millisecondsSinceEpoch}',
          );
        } catch (e) {
          debugPrint('[TigerBay] confirmBookingPaymentPayPal DB update failed: $e');
          // Payment was real — log and continue. Status will be reconciled
          // server-side via PayPal webhook.
        }

        if (!mounted) return;
        _showSuccess();
      } else {
        // User cancelled or PayPal returned an error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment cancelled. No charge was made.'),
              backgroundColor: Colors.black87,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PayPal error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final depositAmount =
        (widget.bookingData['depositAmount'] as num?)?.toDouble() ?? 20.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Confirm Booking',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Deposit info banner ─────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
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
                              color: Colors.black87),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'A £${depositAmount.toStringAsFixed(2)} deposit secures your table. '
                          'Fully refundable if cancelled 24h in advance.',
                          style: TextStyle(
                              color: Colors.grey.shade600,
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

            // ── Payment summary ─────────────────────────────────────────────
            const Text(
              'PAYMENT SUMMARY',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.black45),
            ),
            const SizedBox(height: 14),
            _SummaryRow(
                label: 'Deposit',
                value: '£${depositAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            const _SummaryRow(label: 'Processing fee', value: '£0.00'),
            Divider(color: Colors.grey.shade200, height: 28),
            _SummaryRow(
              label: 'Total due today',
              value: '£${depositAmount.toStringAsFixed(2)}',
              isBold: true,
            ),

            const SizedBox(height: 28),

            // ── Payment method selector ─────────────────────────────────────
            const Text(
              'PAYMENT METHOD',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.black45),
            ),
            const SizedBox(height: 14),

            // PayPal — fully active
            _PaymentMethodTile(
              id: 'paypal_tile',
              icon: Icons.account_balance_wallet_rounded,
              iconColor: const Color(0xFF003087),
              title: 'PayPal',
              subtitle: 'Secure checkout via PayPal',
              selected: _selectedMethod == _PaymentMethod.paypal,
              onTap: () =>
                  setState(() => _selectedMethod = _PaymentMethod.paypal),
            ),
            const SizedBox(height: 10),

            // Stripe — disabled, Coming Soon
            _PaymentMethodTile(
              id: 'stripe_tile',
              icon: Icons.credit_card_rounded,
              iconColor: Colors.black45,
              title: 'Card (Stripe)',
              subtitle: 'Visa, Mastercard, Amex',
              selected: _selectedMethod == _PaymentMethod.stripe,
              disabled: true,
              badge: 'Coming Soon',
              onTap: null,
            ),

            const Spacer(),

            // ── Pay button ──────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _handlePayPal,
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
                          const Icon(Icons.lock_rounded,
                              color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Pay £${depositAmount.toStringAsFixed(2)} with PayPal',
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

  void _showSuccess() {
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
              style: TextStyle(fontSize: 13, color: Colors.black45, height: 1.4),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Refresh bookings provider to show the newly confirmed booking
                  ref.invalidate(userBookingsStreamProvider);
                  Navigator.pop(dialogContext);
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

// ── Payment method tile ───────────────────────────────────────────────────────

class _PaymentMethodTile extends StatelessWidget {
  final String id;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool selected;
  final bool disabled;
  final String? badge;
  final VoidCallback? onTap;

  const _PaymentMethodTile({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.selected,
    this.disabled = false,
    this.badge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.gold.withValues(alpha: 0.05)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.gold : Colors.grey.shade200,
              width: selected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),

              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: disabled ? Colors.black54 : Colors.black87,
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black54,
                                  letterSpacing: 0.4),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),

              // Radio indicator (only for enabled tiles)
              if (!disabled)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          selected ? AppColors.gold : Colors.grey.shade300,
                      width: 2,
                    ),
                    color: selected ? AppColors.gold : Colors.transparent,
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          size: 12, color: Colors.white)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Booking Detail Screen ─────────────────────────────────────────────────────

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
        final booking =
            bookings.where((b) => b.id.toString() == bookingId).firstOrNull;
        if (booking == null) {
          return const Scaffold(
            body: Center(child: Text('Booking not found')),
          );
        }
        return _buildDetail(context, ref, booking);
      },
      loading: () => const Scaffold(
        body: Center(
            child: CircularProgressIndicator(
                color: AppColors.gold, strokeWidth: 2)),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('Error loading booking')),
      ),
    );
  }

  Widget _buildDetail(
      BuildContext context, WidgetRef ref, BookingModel booking) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Booking Details',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
                          color: Colors.black87)),
                  const SizedBox(height: 4),
                  Divider(color: Colors.grey.shade100, height: 24),
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
                  onPressed: () =>
                      context.push('${AppRoutes.myBookings}/new'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black87),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28)),
                  ),
                  child: const Text(
                    'Modify Booking',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Cancel Booking?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          'Your deposit will be refunded within 3-5 business days if cancelled more than 24 hours before.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep It',
                style: TextStyle(
                    color: Colors.black54, fontWeight: FontWeight.w500)),
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

// ── Shared sub-widgets ────────────────────────────────────────────────────────

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
              color: isBold ? Colors.black87 : Colors.grey.shade500,
            )),
        const Spacer(),
        Text(value,
            style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: Colors.black87,
            )),
      ],
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
        Icon(icon, size: 16, color: Colors.grey.shade400),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
      ],
    );
  }
}
