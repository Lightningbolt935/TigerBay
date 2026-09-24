import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tigerbay_app/core/config/stripe_config.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Stripe Payment Service
/// ═══════════════════════════════════════════════════════════════════════════
/// Provides native Stripe Payment Sheet processing for table booking deposits
/// and membership activations. Supports Apple Pay, Google Pay, and credit/debit cards.
class StripeService {
  StripeService._();

  /// Presents the Stripe Payment Sheet for a table booking deposit.
  ///
  /// [bookingId]    — Supabase booking row ID
  /// [branchId]     — Branch ID (for location context / Stripe Connect)
  /// [amountPence]  — Amount in smallest currency unit (e.g. 2000 = £20.00)
  /// [currency]     — ISO 4217 code (default: 'gbp')
  static Future<StripePaymentResult> presentBookingDepositSheet({
    required BuildContext context,
    required String bookingId,
    required String branchId,
    required int amountPence,
    String currency = 'gbp',
  }) async {
    if (!StripeConfig.isConfigured) {
      debugPrint('[Stripe] ⚠️ Publishable key not configured.');
      return const StripePaymentResult(
        success: false,
        error: 'Stripe is not configured. Please check your API keys.',
      );
    }

    try {
      // 1. Obtain PaymentIntent client_secret
      final intentData = await _createOrFetchPaymentIntent(
        payload: {
          'booking_id': bookingId,
          'branch_id': branchId,
          'amount': amountPence,
          'currency': currency,
        },
        amountPence: amountPence,
        currency: currency,
        metadata: {
          'booking_id': bookingId,
          'branch_id': branchId,
          'payment_type': 'table_deposit',
        },
      );

      final clientSecret = intentData['client_secret'];
      final paymentIntentId = intentData['payment_intent_id'] ?? '';
      final sessionError = intentData['error'];

      if (clientSecret == null || clientSecret.isEmpty) {
        return StripePaymentResult(
          success: false,
          error: sessionError != null && sessionError.isNotEmpty
              ? 'Could not create payment session: $sessionError'
              : 'Could not create secure payment session. Please try again.',
        );
      }

      // 2. Initialize the Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: StripeConfig.merchantDisplayName,
          applePay: const PaymentSheetApplePay(
            merchantCountryCode: StripeConfig.merchantCountryCode,
          ),
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: StripeConfig.merchantCountryCode,
            testEnv: true,
          ),
          style: ThemeMode.dark,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: AppColors.gold,
              background: AppColors.surface,
              componentBackground: AppColors.surfaceLight,
              primaryText: Colors.white,
              secondaryText: AppColors.textSecondary,
              placeholderText: AppColors.textHint,
            ),
            shapes: PaymentSheetShape(
              borderRadius: 16,
              borderWidth: 1,
            ),
          ),
        ),
      );

      // 3. Present the Payment Sheet to user
      await Stripe.instance.presentPaymentSheet();

      debugPrint('[Stripe] ✅ Booking deposit payment completed: $paymentIntentId');
      return StripePaymentResult(
        success: true,
        paymentIntentId: paymentIntentId,
      );
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        debugPrint('[Stripe] ⚠️ Payment sheet cancelled by user.');
        return const StripePaymentResult(
          success: false,
          cancelled: true,
        );
      }
      debugPrint('[Stripe] ❌ StripeException: ${e.error.localizedMessage}');
      return StripePaymentResult(
        success: false,
        error: e.error.localizedMessage ?? 'Payment failed',
      );
    } catch (e) {
      debugPrint('[Stripe] ❌ Unexpected error presenting payment sheet: $e');
      return StripePaymentResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Presents the Stripe Payment Sheet for membership onboarding / paywall.
  ///
  /// [tierName]   — Membership tier name (e.g. "Gold", "VIP")
  /// [amountGbp]  — Membership price in pounds (e.g. 50.00)
  /// [tierId]     — Membership tier database identifier
  /// [userId]     — Supabase user ID
  static Future<StripePaymentResult> presentMembershipPayment({
    required BuildContext context,
    required String tierName,
    required double amountGbp,
    String? tierId,
    String? userId,
    String currency = 'gbp',
  }) async {
    if (!StripeConfig.isConfigured) {
      debugPrint('[Stripe] ⚠️ Publishable key not configured.');
      return const StripePaymentResult(
        success: false,
        error: 'Stripe is not configured. Please check your API keys.',
      );
    }

    final amountPence = (amountGbp * 100).round();

    try {
      // 1. Obtain PaymentIntent client_secret
      final intentData = await _createOrFetchPaymentIntent(
        payload: {
          'user_id': userId,
          'tier_id': tierId,
          'tier_name': tierName,
          'amount': amountPence,
          'currency': currency,
        },
        amountPence: amountPence,
        currency: currency,
        metadata: {
          'tier_name': tierName,
          'tier_id': tierId ?? '',
          'user_id': userId ?? '',
          'payment_type': 'membership_subscription',
        },
      );

      final clientSecret = intentData['client_secret'];
      final paymentIntentId = intentData['payment_intent_id'] ?? '';
      final sessionError = intentData['error'];

      if (clientSecret == null || clientSecret.isEmpty) {
        return StripePaymentResult(
          success: false,
          error: sessionError != null && sessionError.isNotEmpty
              ? 'Could not create payment session: $sessionError'
              : 'Could not create secure payment session. Please try again.',
        );
      }

      // 2. Initialize the Payment Sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: StripeConfig.merchantDisplayName,
          applePay: const PaymentSheetApplePay(
            merchantCountryCode: StripeConfig.merchantCountryCode,
          ),
          googlePay: const PaymentSheetGooglePay(
            merchantCountryCode: StripeConfig.merchantCountryCode,
            testEnv: true,
          ),
          style: ThemeMode.dark,
          appearance: const PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: AppColors.gold,
              background: AppColors.surface,
              componentBackground: AppColors.surfaceLight,
              primaryText: Colors.white,
              secondaryText: AppColors.textSecondary,
              placeholderText: AppColors.textHint,
            ),
            shapes: PaymentSheetShape(
              borderRadius: 16,
              borderWidth: 1,
            ),
          ),
        ),
      );

      // 3. Present the Payment Sheet to user
      await Stripe.instance.presentPaymentSheet();

      debugPrint('[Stripe] ✅ Membership payment completed: $paymentIntentId');
      return StripePaymentResult(
        success: true,
        paymentIntentId: paymentIntentId,
      );
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        debugPrint('[Stripe] ⚠️ Membership payment sheet cancelled by user.');
        return const StripePaymentResult(
          success: false,
          cancelled: true,
        );
      }
      debugPrint('[Stripe] ❌ StripeException: ${e.error.localizedMessage}');
      return StripePaymentResult(
        success: false,
        error: e.error.localizedMessage ?? 'Payment failed',
      );
    } catch (e) {
      debugPrint('[Stripe] ❌ Unexpected error presenting membership sheet: $e');
      return StripePaymentResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Creates a PaymentIntent by first attempting the Supabase Edge Function,
  /// and gracefully falling back to direct Stripe API invocation if the
  /// edge function is unavailable or returning an error.
  static Future<Map<String, String?>> _createOrFetchPaymentIntent({
    required Map<String, dynamic> payload,
    required int amountPence,
    required String currency,
    required Map<String, String> metadata,
  }) async {
    String? lastError;

    // Attempt 1: Call Supabase Edge Function
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create-payment-intent',
        body: payload,
      );

      if (response.status == 200 && response.data is Map) {
        final data = response.data as Map;
        final secret = data['client_secret'] as String?;
        final intentId = data['payment_intent_id'] as String?;
        if (secret != null && secret.isNotEmpty) {
          return {
            'client_secret': secret,
            'payment_intent_id': intentId,
          };
        }
      }
      lastError = 'Edge function status ${response.status}';
      debugPrint('[Stripe] Edge function returned status: ${response.status}, payload: ${response.data}');
    } catch (edgeErr) {
      lastError = edgeErr.toString();
      debugPrint('[Stripe] Edge function call failed ($edgeErr), attempting direct API fallback...');
    }

    // Attempt 2: Resilient direct Stripe API invocation with secret key
    if (StripeConfig.secretKey.isNotEmpty) {
      final client = HttpClient();
      try {
        final request = await client.postUrl(
          Uri.parse('https://api.stripe.com/v1/payment_intents'),
        );
        request.headers.set('Authorization', 'Bearer ${StripeConfig.secretKey}');
        request.headers.set('Content-Type', 'application/x-www-form-urlencoded');

        final formParams = <String, String>{
          'amount': amountPence.toString(),
          'currency': currency.toLowerCase(),
          'automatic_payment_methods[enabled]': 'true',
        };

        metadata.forEach((k, v) {
          if (v.isNotEmpty) {
            formParams['metadata[$k]'] = v;
          }
        });

        final bodyStr = formParams.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');

        request.write(bodyStr);
        final httpResponse = await request.close();
        final responseBody = await httpResponse.transform(utf8.decoder).join();

        if (httpResponse.statusCode == 200) {
          final jsonMap = jsonDecode(responseBody) as Map<String, dynamic>;
          final secret = jsonMap['client_secret'] as String?;
          final id = jsonMap['id'] as String?;
          if (secret != null && secret.isNotEmpty) {
            debugPrint('[Stripe] Direct API fallback succeeded: $id');
            return {
              'client_secret': secret,
              'payment_intent_id': id,
            };
          }
        } else {
          lastError = 'Stripe API status ${httpResponse.statusCode}';
          debugPrint('[Stripe] Direct API fallback failed: $responseBody');
        }
      } catch (directErr) {
        lastError = directErr.toString();
        debugPrint('[Stripe] Direct API invocation error: $directErr');
      } finally {
        client.close();
      }
    }

    return {
      'client_secret': null,
      'payment_intent_id': null,
      'error': lastError,
    };
  }
}

/// Structured result from Stripe payment operations.
class StripePaymentResult {
  final bool success;
  final bool cancelled;
  final String? error;
  final String? paymentIntentId;

  const StripePaymentResult({
    required this.success,
    this.cancelled = false,
    this.error,
    this.paymentIntentId,
  });
}
