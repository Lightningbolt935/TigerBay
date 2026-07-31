import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tigerbay_app/core/config/stripe_config.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Stripe Payment Service (Scaffold)
/// ═══════════════════════════════════════════════════════════════════════════
/// Full Stripe Payment Sheet integration — wired up and ready.
/// Requires a deployed `create-payment-intent` Supabase Edge Function.
///
/// TO ENABLE:
///   1. Set a real STRIPE_PUBLISHABLE_KEY (pk_test_...) in .env
///   2. Deploy supabase/functions/create-payment-intent with your secret key
///   3. Uncomment and call [StripeService.presentPaymentSheet()] from screens
///
/// NOTE: Currently PayPal handles all live payments. Stripe will be activated
/// for card payment once the Edge Function is deployed.
class StripeService {
  StripeService._();

  /// Presents the Stripe Payment Sheet for a card payment.
  ///
  /// [bookingId]    — Supabase booking row ID
  /// [branchId]     — Branch ID (used for Stripe Connect transfer)
  /// [amountPence]  — Amount in smallest currency unit (e.g. 2000 = £20.00)
  /// [currency]     — ISO 4217 code (default: 'gbp')
  ///
  /// Returns `true` if payment completed, `false` if cancelled or failed.
  static Future<bool> presentPaymentSheet({
    required BuildContext context,
    required String bookingId,
    required String branchId,
    required int amountPence,
    String currency = 'gbp',
  }) async {
    // ── Guard: skip if key is not a real Stripe key ──────────────────────
    if (StripeConfig.isTestMode && !StripeConfig.publishableKey.startsWith('pk_')) {
      debugPrint('[Stripe] ⚠️ Real publishable key not set — Stripe disabled.');
      return false;
    }

    try {
      // 1. Call Edge Function to get a PaymentIntent client secret
      final response = await Supabase.instance.client.functions.invoke(
        'create-payment-intent',
        body: {
          'booking_id': bookingId,
          'branch_id': branchId,
          'amount': amountPence,
          'currency': currency,
        },
      );

      if (response.status != 200) {
        debugPrint('[Stripe] ❌ Edge function returned ${response.status}');
        return false;
      }

      final clientSecret = response.data['client_secret'] as String?;
      if (clientSecret == null || clientSecret.isEmpty) {
        debugPrint('[Stripe] ❌ No client_secret in response.');
        return false;
      }

      // 2. Init the Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'TigerBay International',
        ),
      );

      // 3. Present the Payment Sheet to the user
      await Stripe.instance.presentPaymentSheet();

      debugPrint('[Stripe] ✅ Payment completed.');
      return true;
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        debugPrint('[Stripe] ⚠️ Payment sheet cancelled by user.');
      } else {
        debugPrint('[Stripe] ❌ StripeException: ${e.error.localizedMessage}');
      }
      return false;
    } catch (e) {
      debugPrint('[Stripe] ❌ Unexpected error: $e');
      return false;
    }
  }
}
