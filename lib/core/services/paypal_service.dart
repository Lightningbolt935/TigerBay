import 'package:flutter/material.dart';
import 'package:flutter_paypal_payment/flutter_paypal_payment.dart';
import 'package:tigerbay_app/core/config/paypal_config.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — PayPal Payment Service
/// ═══════════════════════════════════════════════════════════════════════════
/// Wraps [PaypalCheckoutView] (WebView redirect) into a single async call.
/// Returns `true` on successful approval, `false` on cancellation or error.
///
/// Usage:
/// ```dart
/// final paid = await PayPalService.pay(
///   context: context,
///   amount: '20.00',
///   currency: 'GBP',
///   description: 'TigerBay Table Deposit',
/// );
/// ```
class PayPalService {
  PayPalService._();

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
}
