import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Initialise Stripe with publishable key (call once in main.dart)
  static Future<void> init(String publishableKey) async {
    Stripe.publishableKey = publishableKey;
    await Stripe.instance.applySettings();
  }

  /// Present Stripe payment sheet for a deposit.
  /// [clientSecret] comes from the Edge Function that creates the booking.
  Future<PaymentResult> presentDepositSheet({
    required String clientSecret,
    required double amount,
    required String currency,
    required String merchantName,
  }) async {
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantName,
          style: ThemeMode.light,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(0xFFC9A84C),
            ),
            shapes: PaymentSheetShape(
              borderRadius: 14,
            ),
          ),
        ),
      );
      await Stripe.instance.presentPaymentSheet();
      return const PaymentResult(success: true);
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        return const PaymentResult(success: false, cancelled: true);
      }
      return PaymentResult(
        success: false,
        error: e.error.localizedMessage ?? 'Payment failed',
      );
    } catch (e) {
      return PaymentResult(success: false, error: e.toString());
    }
  }

  /// Trigger a refund for a cancelled booking via Edge Function
  Future<bool> refundDeposit({
    required String bookingId,
    required String stripePaymentIntentId,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'refund-deposit',
        body: {
          'booking_id': bookingId,
          'payment_intent_id': stripePaymentIntentId,
        },
      );
      return response.status == 200;
    } catch (e) {
      debugPrint('❌ Refund Function Error: $e');
      return false;
    }
  } // ◄ Make sure this bracket is here to close the function!

  Future<String?> getStripeCustomerId(String userId) async {
    final data = await _supabase
        .from('stripe_customers')
        .select('stripe_customer_id')
        .eq('user_id', userId)
        .maybeSingle();
    return data?['stripe_customer_id'] as String?;
  }
}

class PaymentResult {
  final bool success;
  final bool cancelled;
  final String? error;

  const PaymentResult({
    required this.success,
    this.cancelled = false,
    this.error,
  });
}
