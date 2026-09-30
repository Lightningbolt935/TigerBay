import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:flutter_stripe_web/card_field.dart' show WebCardField;
import 'package:intl/intl.dart';
import 'package:tigerbay_app/core/config/stripe_config.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Web Card Payment Sheet
/// ═══════════════════════════════════════════════════════════════════════════
/// Stripe's native Payment Sheet has no browser implementation: on web,
/// `initPaymentSheet` and `presentPaymentSheet` both raise
/// `WebUnsupportedError` from flutter_stripe_web. The only supported web
/// primitives are `createPaymentMethod` and `confirmPayment`, driven by a
/// Stripe Elements card field.
///
/// This sheet provides that missing web flow. It is a no-op guard on mobile,
/// where callers keep using the native Payment Sheet.
class WebCardPaymentSheet {
  WebCardPaymentSheet._();

  /// Presents the browser card form and confirms the PaymentIntent.
  ///
  /// Returns `null` when the sheet is dismissed without paying.
  static Future<WebPaymentOutcome?> present({
    required BuildContext context,
    required String clientSecret,
    required double amount,
    required String currency,
    required String title,
    String? subtitle,
    String? email,
    String? name,
  }) async {
    if (!kIsWeb) return null;

    return showModalBottomSheet<WebPaymentOutcome>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (sheetContext) => _WebCardPaymentForm(
        clientSecret: clientSecret,
        amount: amount,
        currency: currency,
        title: title,
        subtitle: subtitle,
        email: email,
        name: name,
      ),
    );
  }
}

/// Outcome of a browser card payment attempt.
class WebPaymentOutcome {
  final bool success;
  final bool cancelled;
  final String? error;
  final String? paymentIntentId;

  const WebPaymentOutcome({
    required this.success,
    this.cancelled = false,
    this.error,
    this.paymentIntentId,
  });
}

class _WebCardPaymentForm extends StatefulWidget {
  final String clientSecret;
  final double amount;
  final String currency;
  final String title;
  final String? subtitle;
  final String? email;
  final String? name;

  const _WebCardPaymentForm({
    required this.clientSecret,
    required this.amount,
    required this.currency,
    required this.title,
    this.subtitle,
    this.email,
    this.name,
  });

  @override
  State<_WebCardPaymentForm> createState() => _WebCardPaymentFormState();
}

class _WebCardPaymentFormState extends State<_WebCardPaymentForm> {
  final CardEditController _controller = CardEditController();

  bool _submitting = false;
  String? _error;
  bool _cardComplete = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onCardChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onCardChanged)
      ..dispose();
    super.dispose();
  }

  void _onCardChanged() {
    final complete = _controller.complete;
    if (complete == _cardComplete) return;
    if (!mounted) return;
    setState(() => _cardComplete = complete);
  }

  String get _formattedAmount {
    final symbol = widget.currency.toLowerCase() == 'gbp' ? '£' : '\$';
    return '$symbol${NumberFormat('#,##0.00').format(widget.amount)}';
  }

  Future<void> _pay() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final intent = await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: widget.clientSecret,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails: BillingDetails(
              email: widget.email,
              name: widget.name,
            ),
          ),
        ),
      );

      if (!mounted) return;

      // confirmCardPayment resolves requires_action inline (3DS redirects and
      // returns in-page), so a non-succeeded status here is a real failure.
      final status = intent.status;
      final succeeded = status == PaymentIntentsStatus.Succeeded ||
          status == PaymentIntentsStatus.Processing ||
          status == PaymentIntentsStatus.RequiresCapture;

      if (succeeded) {
        Navigator.of(context).pop(
          WebPaymentOutcome(success: true, paymentIntentId: intent.id),
        );
        return;
      }

      setState(() {
        _submitting = false;
        _error = _describeStatus(status);
      });
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.error.localizedMessage ?? 'Payment failed';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = _describeError(e);
      });
    }
  }

  String _describeStatus(PaymentIntentsStatus status) {
    switch (status) {
      case PaymentIntentsStatus.RequiresPaymentMethod:
        return 'Your card was declined. Please try a different card.';
      case PaymentIntentsStatus.RequiresAction:
        return 'Additional authentication is required to complete this payment.';
      case PaymentIntentsStatus.Canceled:
        return 'This payment was cancelled.';
      case PaymentIntentsStatus.RequiresConfirmation:
      case PaymentIntentsStatus.Succeeded:
      case PaymentIntentsStatus.Processing:
      case PaymentIntentsStatus.RequiresCapture:
      case PaymentIntentsStatus.Unknown:
        return 'Payment could not be completed. Please try again.';
    }
  }

  String _describeError(Object e) {
    // flutter_stripe_web rethrows Stripe.js errors verbatim, which read as
    // opaque to members. Pull out the useful message where one is available.
    final text = e.toString();
    if (text.contains('WebUnsupportedError')) {
      return 'Card payments are not available in this browser.';
    }
    return 'Payment failed. Please check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF141418),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.glassBorder),
        ),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                widget.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              if (widget.subtitle != null && widget.subtitle!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  widget.subtitle!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Amount due',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    _formattedAmount,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Card details',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                // Stripe Elements mounts a platform view, which needs a
                // bounded height. The package default (10px) is too short.
                child: WebCardField(
                  controller: _controller,
                  style: CardStyle(textColor: AppColors.textPrimary),
                  height: 48,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_submitting || !_cardComplete) ? null : _pay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: const Color(0xFF141418),
                    disabledBackgroundColor: AppColors.surfaceLight,
                    disabledForegroundColor: AppColors.textHint,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Color(0xFF141418),
                          ),
                        )
                      : Text(
                          'Pay $_formattedAmount',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Secured by Stripe • ${StripeConfig.merchantDisplayName}',
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 11.5,
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
