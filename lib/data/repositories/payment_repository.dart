import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tigerbay_app/core/config/stripe_config.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Payment Repository
/// ═══════════════════════════════════════════════════════════════════════════
class PaymentRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Initializes Stripe with publishable key.
  static Future<void> init(String publishableKey) async {
    if (publishableKey.startsWith('pk_')) {
      Stripe.publishableKey = publishableKey;
      Stripe.merchantIdentifier = 'merchant.io.tigerbay.app';
      await Stripe.instance.applySettings();
      debugPrint('[PaymentRepository] Stripe initialized successfully.');
    }
  }

  /// Presents the Stripe deposit payment sheet for an already-obtained client secret.
  ///
  /// Includes server-side PaymentIntent verification: if the user completes
  /// payment on Link / 3DS and then closes the sheet (back gesture), Stripe
  /// throws [StripeException(Cancelled)] even though the charge succeeded.
  /// We detect this by querying the PaymentIntent status directly from Stripe.
  Future<PaymentResult> presentDepositSheet({
    required String clientSecret,
    required double amount,
    required String currency,
    required String merchantName,
  }) async {
    // Extract the PaymentIntent ID from the client secret (format: pi_xxx_secret_xxx)
    final paymentIntentId = clientSecret.contains('_secret_')
        ? clientSecret.split('_secret_').first
        : '';

    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: merchantName.isNotEmpty
              ? merchantName
              : StripeConfig.merchantDisplayName,
          returnURL: StripeConfig.returnURL,
          paymentMethodOrder: const ['card'],
          style: ThemeMode.dark,
        ),
      );

      await Stripe.instance.presentPaymentSheet();
      return PaymentResult(success: true, paymentIntentId: paymentIntentId);
    } on StripeException catch (e) {
      // Before reporting cancelled/failed, verify the actual status on Stripe's
      // server. This handles the case where the user paid via Link and pressed back.
      if (paymentIntentId.isNotEmpty) {
        final isPaid = await _verifyPaymentIntentSucceeded(paymentIntentId);
        if (isPaid) {
          debugPrint('[PaymentRepository] ✅ PaymentIntent verified succeeded on '
              'server despite sheet close: $paymentIntentId');
          return PaymentResult(
              success: true, paymentIntentId: paymentIntentId);
        }
      }

      if (e.error.code == FailureCode.Canceled) {
        return const PaymentResult(success: false, cancelled: true);
      }
      return PaymentResult(
        success: false,
        error: e.error.localizedMessage ?? 'Payment failed',
      );
    } catch (e) {
      if (paymentIntentId.isNotEmpty) {
        final isPaid = await _verifyPaymentIntentSucceeded(paymentIntentId);
        if (isPaid) {
          debugPrint('[PaymentRepository] ✅ PaymentIntent verified succeeded on '
              'server despite exception: $paymentIntentId');
          return PaymentResult(
              success: true, paymentIntentId: paymentIntentId);
        }
      }
      return PaymentResult(success: false, error: e.toString());
    }
  }

  /// Queries the Stripe REST API to verify whether a PaymentIntent has
  /// actually been charged (status == 'succeeded' | 'processing').
  ///
  /// Uses retry-with-backoff because Stripe Link completes payment in an
  /// external browser tab. When the deep-link returns the app to foreground,
  /// the Flutter SDK immediately throws StripeException(Cancelled) — but
  /// Stripe's servers may not yet have propagated the 'succeeded' status.
  /// We poll up to 4 times (immediately, then +1s, +2s, +3s) to handle
  /// this race condition.
  static const int _maxVerifyAttempts = 4;
  static const List<int> _verifyDelaysMs = [0, 1000, 2000, 3000];

  static Future<bool> _verifyPaymentIntentSucceeded(String intentId) async {
    final secretKey = StripeConfig.secretKey;
    if (intentId.isEmpty || secretKey.isEmpty) return false;

    for (int attempt = 0; attempt < _maxVerifyAttempts; attempt++) {
      if (_verifyDelaysMs[attempt] > 0) {
        await Future.delayed(Duration(milliseconds: _verifyDelaysMs[attempt]));
      }

      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('https://api.stripe.com/v1/payment_intents/$intentId'),
        );
        request.headers.set('Authorization', 'Bearer $secretKey');
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          final status = json['status'] as String?;
          debugPrint(
              '[PaymentRepository] Verify attempt ${attempt + 1}/$_maxVerifyAttempts '
              '$intentId: status=$status');
          if (status == 'succeeded' ||
              status == 'processing' ||
              status == 'requires_capture') {
            return true;
          }
          // Keep retrying if not yet succeeded.
        }
      } catch (e) {
        debugPrint(
            '[PaymentRepository] Verification error (attempt ${attempt + 1}): $e');
      } finally {
        client.close();
      }
    }

    debugPrint('[PaymentRepository] ❌ PaymentIntent $intentId not confirmed '
        'after $_maxVerifyAttempts attempts.');
    return false;
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
  final String? paymentIntentId;

  const PaymentResult({
    required this.success,
    this.cancelled = false,
    this.error,
    this.paymentIntentId,
  });
}
