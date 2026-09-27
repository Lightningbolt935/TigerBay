import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/services/stripe_service.dart';
import 'package:tigerbay_app/shared/widgets/apple_touch_feedback.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Luxury Native Card Payment Bottom Sheet
/// ═══════════════════════════════════════════════════════════════════════════
/// Uses Flutter-native CardField with CardInputWidget on Android to ensure
/// full-area touch targets (clickable anywhere: middle, center, edges) and
/// instant keyboard autofocus with 0ms lag.
class StripeCardBottomSheet extends StatefulWidget {
  final String clientSecret;
  final String paymentIntentId;
  final String amountFormatted;
  final String title;

  const StripeCardBottomSheet({
    super.key,
    required this.clientSecret,
    required this.paymentIntentId,
    required this.amountFormatted,
    required this.title,
  });

  /// Presents the bottom sheet and returns the [StripePaymentResult].
  static Future<StripePaymentResult> show({
    required BuildContext context,
    required String clientSecret,
    required String paymentIntentId,
    required String amountFormatted,
    required String title,
  }) async {
    final result = await showModalBottomSheet<StripePaymentResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black87,
      isDismissible: true,
      enableDrag: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: StripeCardBottomSheet(
          clientSecret: clientSecret,
          paymentIntentId: paymentIntentId,
          amountFormatted: amountFormatted,
          title: title,
        ),
      ),
    );

    return result ??
        const StripePaymentResult(
          success: false,
          cancelled: true,
        );
  }

  @override
  State<StripeCardBottomSheet> createState() => _StripeCardBottomSheetState();
}

class _StripeCardBottomSheetState extends State<StripeCardBottomSheet> {
  final CardEditController _cardController = CardEditController();
  bool _isCardComplete = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _handlePay() async {
    if (!_isCardComplete || _isLoading) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final intent = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: widget.clientSecret,
        data: const PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(),
        ),
      );

      final status = intent.status;
      if (status == PaymentIntentsStatus.Succeeded ||
          status == PaymentIntentsStatus.RequiresCapture ||
          status == PaymentIntentsStatus.Processing) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          Navigator.of(context).pop(
            StripePaymentResult(
              success: true,
              paymentIntentId: intent.id.isNotEmpty ? intent.id : widget.paymentIntentId,
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Payment status: $status. Please try again.';
        });
      }
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        if (mounted) {
          Navigator.of(context).pop(
            const StripePaymentResult(
              success: false,
              cancelled: true,
            ),
          );
        }
        return;
      }
      setState(() {
        _isLoading = false;
        _errorMessage = e.error.localizedMessage ?? 'Card verification failed.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected payment error occurred. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF131317),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(
          top: BorderSide(color: Color(0xFF2C2C3A), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Drag Handle ────────────────────────────────────────────────
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Header Row ─────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      CupertinoIcons.lock_shield_fill,
                      color: AppColors.gold,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'TigerBay Secure Payment',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.xmark, color: Colors.white54, size: 20),
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Amount Banner ──────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF191922),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL AMOUNT',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.amountFormatted,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppColors.champagneGold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified_user_rounded, color: AppColors.gold, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            '256-bit SSL',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ── Card Details Label ─────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'CARD DETAILS',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(CupertinoIcons.creditcard, size: 12, color: AppColors.gold),
                      const SizedBox(width: 4),
                      Text(
                        'Visa, Mastercard, Amex',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Native CardField (Full Area Touch Target + Instant Autofocus) ─
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B24),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _errorMessage != null
                        ? Colors.redAccent
                        : (_isCardComplete ? AppColors.gold : const Color(0xFF2E2E3E)),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: CardField(
                  controller: _cardController,
                  autofocus: true,
                  enablePostalCode: false,
                  countryCode: 'GB',
                  cursorColor: AppColors.gold,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onCardChanged: (card) {
                    setState(() {
                      _isCardComplete = card?.complete ?? false;
                      if (_errorMessage != null) _errorMessage = null;
                    });
                  },
                ),
              ),

              // ── Error Banner (if any) ──────────────────────────────────────
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // ── Pay Button ─────────────────────────────────────────────────
              AppleTouchFeedback(
                onTap: (_isCardComplete && !_isLoading) ? _handlePay : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 54,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: (_isCardComplete && !_isLoading)
                        ? AppColors.goldGradient
                        : null,
                    color: (_isCardComplete && !_isLoading)
                        ? null
                        : const Color(0xFF262632),
                    borderRadius: BorderRadius.circular(27),
                    boxShadow: (_isCardComplete && !_isLoading)
                        ? [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: _isLoading
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
                              Icon(
                                CupertinoIcons.lock_fill,
                                size: 16,
                                color: (_isCardComplete && !_isLoading)
                                    ? Colors.black
                                    : Colors.white38,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pay ${widget.amountFormatted}',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                  color: (_isCardComplete && !_isLoading)
                                      ? Colors.black
                                      : Colors.white38,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Security Footer ────────────────────────────────────────────
              Center(
                child: Text(
                  'Powered by Stripe • End-to-end encrypted',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
