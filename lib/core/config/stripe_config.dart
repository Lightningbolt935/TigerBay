import 'package:flutter_dotenv/flutter_dotenv.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Stripe Configuration (Scaffold)
/// ═══════════════════════════════════════════════════════════════════════════
/// Stripe is already initialised in main.dart via [Stripe.publishableKey].
/// This config class centralises Stripe settings for when the full
/// payment-sheet integration is wired up.
///
/// TO WIRE UP STRIPE:
///   1. Replace STRIPE_PUBLISHABLE_KEY in .env with a real pk_test_ key
///   2. Deploy the `create-payment-intent` Supabase Edge Function with your
///      Stripe secret key
///   3. Call [StripeService.presentPaymentSheet()] from the confirm screen
class StripeConfig {
  StripeConfig._();

  static String get publishableKey =>
      dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';

  /// True when the key is a Stripe test key (starts with pk_test_ or sb_)
  static bool get isTestMode =>
      publishableKey.startsWith('pk_test_') ||
      publishableKey.startsWith('sb_');
}
