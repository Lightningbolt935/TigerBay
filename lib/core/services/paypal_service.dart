import 'package:flutter/material.dart';
import 'package:flutter_paypal_payment/flutter_paypal_payment.dart';
import 'package:tigerbay_app/core/config/paypal_config.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — PayPal Payment Service
/// ═══════════════════════════════════════════════════════════════════════════
/// Wraps [PaypalCheckoutView] (WebView redirect) into awaitable async calls.
///
/// • [pay]                     — Generic boolean payment (bookings, etc.)
/// • [presentMembershipPayment]— Membership-specific call that returns a
///                               [PayPalPaymentResult] with the orderId so
///                               it can be recorded for audit purposes.
class PayPalService {
  PayPalService._();

  // ── Generic payment (existing API — do not change signature) ─────────────

  /// Launches the PayPal WebView checkout and waits for the result.
  ///
  /// [amount]      — Decimal string, e.g. '20.00'
  /// [currency]    — ISO 4217 code, e.g. 'GBP' or 'USD'
  /// [description] — Shows on the PayPal order summary page
  ///
  /// Returns `true` if payment was approved, `false` if cancelled/errored.
  static Future<bool> pay({
    required BuildContext context,
    required String amount,
    String currency = 'GBP',
    String description = 'TigerBay Payment',
  }) async {
    bool result = false;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaypalCheckoutView(
          sandboxMode: PayPalConfig.isSandbox,
          clientId: PayPalConfig.clientId,
          secretKey: PayPalConfig.secretKey,
          transactions: [
            {
              'amount': {
                'total': amount,
                'currency': currency,
                'details': {
                  'subtotal': amount,
                  'shipping': '0',
                  'shipping_discount': 0,
                },
              },
              'description': description,
              'item_list': {
                'items': [
                  {
                    'name': description,
                    'quantity': 1,
                    'price': amount,
                    'currency': currency,
                  },
                ],
              },
            },
          ],
          note: 'Contact TigerBay International for refund queries.',
          onSuccess: (params) async {
            debugPrint('[PayPal] ✅ Payment approved: $params');
            result = true;
            if (context.mounted) Navigator.of(context).pop();
          },
          onError: (error) {
            debugPrint('[PayPal] ❌ Payment error: $error');
            result = false;
            if (context.mounted) Navigator.of(context).pop();
          },
          onCancel: () {
            debugPrint('[PayPal] ⚠️ Payment cancelled by user.');
            result = false;
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );

    return result;
  }

  // ── Membership Subscription Payment ─────────────────────────────────────

  /// Presents the PayPal checkout for a membership subscription and returns a
  /// [PayPalPaymentResult] with the orderId for audit recording.
  ///
  /// [tierName]   — Tier display name shown in the PayPal order line-item.
  /// [amountGbp]  — Price in GBP (taken from [MembershipTier.price]).
  ///
  /// Caller workflow:
  ///   1. Await this method.
  ///   2. If `result.success` → call `activateMembership()` and record
  ///      `result.orderId` on the profile row for the audit trail.
  ///   3. If `result.cancelled` → show a soft "Payment cancelled" message.
  ///   4. If `result.error != null` → show the error and allow retry.
  static Future<PayPalPaymentResult> presentMembershipPayment({
    required BuildContext context,
    required String tierName,
    required double amountGbp,
  }) async {
    // Clamp to 2 dp — PayPal rejects values like "9.999999"
    final amount = amountGbp.toStringAsFixed(2);

    final tracker = _ResultTracker();

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaypalCheckoutView(
          sandboxMode: PayPalConfig.isSandbox,
          clientId: PayPalConfig.clientId,
          secretKey: PayPalConfig.secretKey,
          transactions: [
            {
              'amount': {
                'total': amount,
                'currency': 'GBP',
                'details': {
                  'subtotal': amount,
                  'shipping': '0',
                  'shipping_discount': 0,
                },
              },
              'description':
                  'TigerBay $tierName Membership — Monthly Subscription',
              'item_list': {
                'items': [
                  {
                    'name': 'TigerBay $tierName Membership',
                    'quantity': 1,
                    'price': amount,
                    'currency': 'GBP',
                  },
                ],
              },
            },
          ],
          note: 'Thank you for joining TigerBay International!',
          onSuccess: (params) {
            debugPrint('[PayPal] ✅ Membership payment approved: $params');
            final orderId =
                (params['orderID'] ?? params['paymentID'] ?? '') as String;
            tracker.complete(PayPalPaymentResult.success(orderId));
          },
          onError: (error) {
            debugPrint('[PayPal] ❌ Membership payment error: $error');
            tracker.complete(
              PayPalPaymentResult.error(
                error?.toString() ?? 'Payment failed. Please try again.',
              ),
            );
          },
          onCancel: () {
            debugPrint('[PayPal] ⚠️ Membership payment cancelled.');
            tracker.complete(PayPalPaymentResult.cancelled());
          },
        ),
      ),
    );

    // If the user back-gestured without any callback firing, treat as cancel.
    return tracker.resultOrCancelled;
  }
}

// ── Result type for membership payments ──────────────────────────────────

/// Structured result from [PayPalService.presentMembershipPayment].
class PayPalPaymentResult {
  final bool success;
  final bool cancelled;

  /// PayPal order / payment ID — record this in the profile for audit.
  final String? orderId;

  /// Human-readable error (non-null only when success=false, cancelled=false).
  final String? error;

  const PayPalPaymentResult._({
    required this.success,
    required this.cancelled,
    this.orderId,
    this.error,
  });

  factory PayPalPaymentResult.success(String orderId) =>
      PayPalPaymentResult._(success: true, cancelled: false, orderId: orderId);

  factory PayPalPaymentResult.cancelled() =>
      const PayPalPaymentResult._(success: false, cancelled: true);

  factory PayPalPaymentResult.error(String message) =>
      PayPalPaymentResult._(success: false, cancelled: false, error: message);
}

// ── Internal result tracker ───────────────────────────────────────────────

class _ResultTracker {
  PayPalPaymentResult? _result;

  /// Records the first result — subsequent calls are ignored (first-write-wins).
  void complete(PayPalPaymentResult result) {
    _result ??= result;
  }

  PayPalPaymentResult get resultOrCancelled =>
      _result ?? PayPalPaymentResult.cancelled();
}
