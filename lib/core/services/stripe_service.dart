// TigerBay International — Stripe Service (Stub)
// ─────────────────────────────────────────────────
// flutter_stripe is NOT currently in pubspec.yaml.
// This file is a placeholder so the project structure is preserved.
//
// TO ACTIVATE STRIPE:
//   1. Add `flutter_stripe: ^11.0.0` back to pubspec.yaml
//   2. Add your STRIPE_PUBLISHABLE_KEY=pk_test_... to .env
//   3. Add STRIPE_SECRET_KEY=sk_test_... to Supabase project secrets
//   4. Uncomment the Stripe block in supabase/functions/create-payment-intent/index.ts
//   5. Uncomment the Stripe init block in lib/main.dart
//   6. Uncomment this service and wire it into booking_confirm_screen.dart
//
// STUB IMPLEMENTATION — returns false without doing anything.
class StripeService {
  StripeService._();

  /// Stub: always returns false until Stripe is configured.
  static Future<bool> presentPaymentSheet({
    required Object context,
    required String bookingId,
    required String branchId,
    required int amountPence,
    String currency = 'gbp',
  }) async {
    return false;
  }
}
