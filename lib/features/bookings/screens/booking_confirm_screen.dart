import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/stripe_service.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/apple_touch_feedback.dart';
import '../providers/booking_provider.dart';

// Re-export BookingDetailScreen so any consumer importing from here keeps working
export 'booking_detail_screen.dart' show BookingDetailScreen;

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Luxury Booking Confirm Screen (Tier-1 Benchmark)
/// ═══════════════════════════════════════════════════════════════════════════
/// Handles the secure deposit payment step before a reservation is confirmed.
/// Uses Stripe Payment Sheet (Apple Pay, Google Pay, Debit/Credit cards).
class BookingConfirmScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> bookingData;

  const BookingConfirmScreen({super.key, required this.bookingData});

  @override
  ConsumerState<BookingConfirmScreen> createState() =>
      _BookingConfirmScreenState();
}

class _BookingConfirmScreenState extends ConsumerState<BookingConfirmScreen> {
  bool _isProcessing = false;

  Future<void> _handleStripePayment() async {
    HapticFeedback.mediumImpact();
    final bookingId = widget.bookingData['bookingId'] as String? ?? '';
    final branchId = widget.bookingData['branchId'] as String? ?? '';
    final depositAmount =
        (widget.bookingData['depositAmount'] as num?)?.toDouble() ?? 20.0;
    final amountPence = (depositAmount * 100).round();

    setState(() => _isProcessing = true);
    try {
      final result = await StripeService.presentBookingDepositSheet(
        context: context,
        bookingId: bookingId,
        branchId: branchId,
        amountPence: amountPence,
        currency: 'gbp',
      );

      if (!mounted) return;

      if (result.success) {
        HapticFeedback.heavyImpact();
        try {
          final repo = ref.read(bookingRepositoryProvider);
          await repo.confirmBookingPayment(
            bookingId: bookingId,
            stripePaymentIntentId: result.paymentIntentId ??
                'pi_${DateTime.now().millisecondsSinceEpoch}',
          );
        } catch (e) {
          debugPrint('[TigerBay] confirmBookingPayment DB update failed: $e');
        }

        if (!mounted) return;
        _showSuccess();
      } else if (result.cancelled) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Payment cancelled. No charge was made.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        HapticFeedback.vibrate();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Payment failed. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment error: $e'),
            backgroundColor: AppColors.error,
          ),
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
              context.go(AppRoutes.home);
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
          'Confirm Reservation',
          style: AppTypography.headline.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Deposit info banner ─────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      CupertinoIcons.shield_fill,
                      color: AppColors.champagneGold,
                      size: 22,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Table Deposit Guarantee',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.champagneGold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'A £${depositAmount.toStringAsFixed(2)} deposit secures your table. 100% refundable if cancelled 24 hours prior.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Payment summary ─────────────────────────────────────────────
              const Text(
                'PAYMENT SUMMARY',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                child: Column(
                  children: [
                    _SummaryRow(
                      label: 'Table Deposit',
                      value: '£${depositAmount.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 10),
                    const _SummaryRow(
                      label: 'Processing Fee',
                      value: '£0.00',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.08),
                        height: 1,
                      ),
                    ),
                    _SummaryRow(
                      label: 'Total Due Today',
                      value: '£${depositAmount.toStringAsFixed(2)}',
                      isBold: true,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Payment method selector ─────────────────────────────────────
              const Text(
                'PAYMENT METHOD',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),

              const _PaymentMethodTile(
                icon: CupertinoIcons.creditcard_fill,
                iconColor: AppColors.champagneGold,
                title: 'Stripe Secure Checkout',
                subtitle: 'Apple Pay, Google Pay, Visa, Mastercard, Amex',
                selected: true,
                badge: 'INSTANT',
              ),

              const Spacer(),

              // ── Pay button ──────────────────────────────────────────────────
              AppleTouchFeedback(
                onTap: _isProcessing ? null : _handleStripePayment,
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.gold, AppColors.champagneGold],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(27),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: _isProcessing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.black,
                            strokeWidth: 2.2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              CupertinoIcons.lock_fill,
                              color: Colors.black,
                              size: 17,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pay £${depositAmount.toStringAsFixed(2)} Deposit',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccess() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 34),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: AppColors.success,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Reservation Confirmed!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your table is reserved. A confirmation receipt and calendar invite have been sent to your email.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            AppleTouchFeedback(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.invalidate(userBookingsStreamProvider);
                Navigator.pop(dialogContext);
                if (context.mounted) {
                  context.go(AppRoutes.myBookings);
                }
              },
              child: Container(
                width: double.infinity,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gold, AppColors.champagneGold],
                  ),
                  borderRadius: BorderRadius.circular(25),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'View My Reservations',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
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

// ── Payment method tile ───────────────────────────────────────────────────────

class _PaymentMethodTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool selected;
  final String? badge;

  const _PaymentMethodTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.selected,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? AppColors.gold : Colors.white.withValues(alpha: 0.08),
          width: selected ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: AppColors.champagneGold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.gold : Colors.white24,
                width: 2,
              ),
              color: selected ? AppColors.gold : Colors.transparent,
            ),
            child: selected
                ? const Icon(
                    CupertinoIcons.checkmark,
                    size: 12,
                    color: Colors.black,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            color: isBold ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isBold ? AppColors.champagneGold : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
