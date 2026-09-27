import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tigerbay_app/core/config/stripe_config.dart';
import 'package:tigerbay_app/shared/widgets/stripe_card_bottom_sheet.dart';

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

    String paymentIntentId = '';
    FocusManager.instance.primaryFocus?.unfocus();

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
      paymentIntentId = intentData['payment_intent_id'] ?? '';
      final sessionError = intentData['error'];

      if (clientSecret == null || clientSecret.isEmpty) {
        return StripePaymentResult(
          success: false,
          error: sessionError != null && sessionError.isNotEmpty
              ? 'Could not create payment session: $sessionError'
              : 'Could not create secure payment session. Please try again.',
        );
      }

      // 2. Present TigerBay native Card Payment Sheet (Full Area Touch Target + Instant Keyboard Autofocus)
      if (!context.mounted) {
        return const StripePaymentResult(success: false, cancelled: true);
      }
      final sheetResult = await StripeCardBottomSheet.show(
        context: context,
        clientSecret: clientSecret,
        paymentIntentId: paymentIntentId,
        amountFormatted: '£${(amountPence / 100).toStringAsFixed(2)}',
        title: 'Table Reservation Deposit',
      );

      return sheetResult;
    } on StripeException catch (e) {
      if (paymentIntentId.isNotEmpty) {
        final isPaid = await _verifyPaymentIntentSucceeded(paymentIntentId);
        if (isPaid) {
          debugPrint('[Stripe] ✅ PaymentIntent verified as succeeded on Stripe server despite sheet close: $paymentIntentId');
          return StripePaymentResult(
            success: true,
            paymentIntentId: paymentIntentId,
          );
        }
      }

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
      if (paymentIntentId.isNotEmpty) {
        final isPaid = await _verifyPaymentIntentSucceeded(paymentIntentId);
        if (isPaid) {
          debugPrint('[Stripe] ✅ PaymentIntent verified as succeeded on Stripe server despite exception: $paymentIntentId');
          return StripePaymentResult(
            success: true,
            paymentIntentId: paymentIntentId,
          );
        }
      }
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
    String paymentIntentId = '';
    FocusManager.instance.primaryFocus?.unfocus();

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
      paymentIntentId = intentData['payment_intent_id'] ?? '';
      final sessionError = intentData['error'];

      if (clientSecret == null || clientSecret.isEmpty) {
        return StripePaymentResult(
          success: false,
          error: sessionError != null && sessionError.isNotEmpty
              ? 'Could not create payment session: $sessionError'
              : 'Could not create secure payment session. Please try again.',
        );
      }

      // 2. Present TigerBay native Card Payment Sheet (Full Area Touch Target + Instant Keyboard Autofocus)
      if (!context.mounted) {
        return const StripePaymentResult(success: false, cancelled: true);
      }
      final sheetResult = await StripeCardBottomSheet.show(
        context: context,
        clientSecret: clientSecret,
        paymentIntentId: paymentIntentId,
        amountFormatted: '£${amountGbp.toStringAsFixed(2)}',
        title: '$tierName Membership',
      );

      return sheetResult;
    } on StripeException catch (e) {
      if (paymentIntentId.isNotEmpty) {
        final isPaid = await _verifyPaymentIntentSucceeded(paymentIntentId);
        if (isPaid) {
          debugPrint('[Stripe] ✅ Membership PaymentIntent verified as succeeded on Stripe server despite sheet close: $paymentIntentId');
          return StripePaymentResult(
            success: true,
            paymentIntentId: paymentIntentId,
          );
        }
      }

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
      if (paymentIntentId.isNotEmpty) {
        final isPaid = await _verifyPaymentIntentSucceeded(paymentIntentId);
        if (isPaid) {
          debugPrint('[Stripe] ✅ Membership PaymentIntent verified as succeeded on Stripe server despite exception: $paymentIntentId');
          return StripePaymentResult(
            success: true,
            paymentIntentId: paymentIntentId,
          );
        }
      }
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
        final remoteKey = data['publishable_key'] as String?;

        if (remoteKey != null && remoteKey.startsWith('pk_')) {
          if (remoteKey != StripeConfig.publishableKey) {
            StripeConfig.updatePublishableKey(remoteKey);
            Stripe.publishableKey = remoteKey;
            try {
              await Stripe.instance.applySettings();
              debugPrint('[Stripe] 🔄 Dynamic Stripe key switched to: ${StripeConfig.isTestMode ? "TEST MODE" : "PRODUCTION LIVE MODE"} ($remoteKey)');
            } catch (_) {}
          }
        }

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
          'payment_method_types[0]': 'card',
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

  /// Verifies with Stripe API whether a PaymentIntent has actually been paid.
  ///
  /// Uses retry-with-backoff because Stripe Link completes payment in an
  /// external browser tab. When the deep-link returns the app to foreground,
  /// the Flutter SDK immediately throws StripeException(Cancelled) — but
  /// Stripe's servers may not yet have propagated the 'succeeded' status.
  /// We poll up to [_maxVerifyAttempts] times to handle this race condition.
  static const int _maxVerifyAttempts = 4;
  static const List<int> _verifyDelaysMs = [0, 1000, 2000, 3000];

  static Future<bool> _verifyPaymentIntentSucceeded(String intentId) async {
    if (intentId.isEmpty || StripeConfig.secretKey.isEmpty) return false;

    for (int attempt = 0; attempt < _maxVerifyAttempts; attempt++) {
      // Wait before each attempt (first attempt is immediate).
      if (_verifyDelaysMs[attempt] > 0) {
        await Future.delayed(Duration(milliseconds: _verifyDelaysMs[attempt]));
      }

      final client = HttpClient();
      try {
        final request = await client.getUrl(
          Uri.parse('https://api.stripe.com/v1/payment_intents/$intentId'),
        );
        request.headers.set('Authorization', 'Bearer ${StripeConfig.secretKey}');
        final response = await request.close();
        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          final status = json['status'] as String?;
          debugPrint('[Stripe] Verify attempt ${attempt + 1}/$_maxVerifyAttempts '
              'for $intentId: status=$status');
          if (status == 'succeeded' ||
              status == 'processing' ||
              status == 'requires_capture') {
            return true;
          }
          // If still requires_payment_method or requires_action → not paid yet,
          // keep retrying.
        }
      } catch (e) {
        debugPrint('[Stripe] Server verification error (attempt ${attempt + 1}): $e');
      } finally {
        client.close();
      }
    }

    debugPrint('[Stripe] ❌ PaymentIntent $intentId not confirmed '
        'after $_maxVerifyAttempts attempts.');
    return false;
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
