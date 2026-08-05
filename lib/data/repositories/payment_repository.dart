// TigerBay International — Payment Repository (Stripe Stub)
// ──────────────────────────────────────────────────────────
// flutter_stripe has been temporarily removed from pubspec.yaml until
// a real Stripe API key is available. This file is a stub that preserves
// the class shape so nothing else in the codebase breaks.
//
// TO ACTIVATE STRIPE: see lib/core/services/stripe_service.dart for full instructions.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Stub: no-op until Stripe is configured.
  static Future<void> init(String publishableKey) async {
    debugPrint('[PaymentRepository] Stripe not configured — init skipped.');
  }

  /// Stub: always returns cancelled until Stripe is configured.
  Future<PaymentResult> presentDepositSheet({
    required String clientSecret,
    required double amount,
    required String currency,
    required String merchantName,
  }) async {
    return const PaymentResult(
      success: false,
      cancelled: true,
      error: 'Stripe not configured yet.',
    );
  }

  /// Trigger a refund for a cancelled booking via Edge Function.
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
  }

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
