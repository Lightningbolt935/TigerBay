import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tigerbay_app/core/config/env_config.dart';
import 'package:tigerbay_app/core/config/stripe_config.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Enterprise Stripe Payment Service
/// ═══════════════════════════════════════════════════════════════════════════
class StripeService {
  StripeService._();

  static const String _iosReturnUrl = 'io.tigerbay.app://stripe-redirect';

  static String get _effectivePublishableKey {
    if (Stripe.publishableKey.isNotEmpty) return Stripe.publishableKey;
    if (StripeConfig.publishableKey.isNotEmpty) return StripeConfig.publishableKey;
    return EnvConfig.stripePublishableKey;
  }

  /// Presents the Stripe Payment Sheet for membership onboarding / paywall.
  ///
  /// Executes the native PaymentSheet first. If native presentation encounters
  /// an iOS transition deadlock or presentation timeout, it seamlessly falls
  /// back to in-app Safari hosted checkout so the user is never stuck.
  static Future<StripePaymentResult> presentMembershipPayment({
    required BuildContext context,
    required String tierName,
    required double amountGbp,
    String? tierId,
    String? userId,
    String currency = 'gbp',
  }) async {
    final key = _effectivePublishableKey;
    if (!key.startsWith('pk_')) {
      debugPrint('[Stripe] ⚠️ Publishable key not configured.');
      return const StripePaymentResult(
        success: false,
        error: 'Stripe is not configured. Please check your API keys in .env.',
      );
    }

    final amountPence = (amountGbp * 100).round();
    String paymentIntentId = '';
    FocusManager.instance.primaryFocus?.unfocus();

    // ── Flow A: Primary Native Payment Sheet ────────────────────────────────
    try {
      debugPrint('[Stripe] [Step 1] Requesting payment session for $tierName (£$amountGbp)...');
      final intentData = await _createOrFetchPaymentIntent(
        payload: {
          'tier_name': tierName,
          'tier_id': tierId ?? 'tier_1',
          'user_id': userId ?? '',
          'amount': amountPence,
          'currency': currency,
          'flow': 'sheet',
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

      final clientSecret = intentData['client_secret'] as String?;
      paymentIntentId = (intentData['payment_intent_id'] as String?) ?? '';

      if (clientSecret != null && clientSecret.isNotEmpty) {
        debugPrint('[Stripe] [Step 2] Presenting native sheet...');
        await _initAndPresentPaymentSheet(
          clientSecret: clientSecret,
          currency: currency,
        );

        debugPrint('[Stripe] ✅ Membership payment completed: $paymentIntentId');
        return StripePaymentResult(
          success: true,
          paymentIntentId: paymentIntentId,
        );
      }
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        debugPrint('[Stripe] ⚠️ User dismissed payment sheet.');
        return const StripePaymentResult(success: false, cancelled: true);
      }
      debugPrint('[Stripe] ⚠️ Native sheet error: ${e.error.localizedMessage}. Attempting web fallback...');
    } catch (e) {
      debugPrint('[Stripe] ⚠️ Native presentation error ($e). Attempting web fallback...');
    }

    // ── Flow B: Fail-Safe In-App Safari Checkout Fallback ───────────────────
    debugPrint('[Stripe] Launching in-app checkout fallback...');
    return await _launchHostedCheckout(
      payload: {
        'tier_name': tierName,
        'tier_id': tierId ?? 'tier_1',
        'user_id': userId ?? '',
        'amount': amountPence,
        'currency': currency,
        'flow': 'checkout',
      },
    );
  }

  /// Presents the Stripe Payment Sheet for table booking deposits.
  static Future<StripePaymentResult> presentBookingDepositSheet({
    required BuildContext context,
    required String bookingId,
    required String branchId,
    required int amountPence,
    String currency = 'gbp',
  }) async {
    final key = _effectivePublishableKey;
    if (!key.startsWith('pk_')) {
      debugPrint('[Stripe] ⚠️ Publishable key not configured.');
      return const StripePaymentResult(
        success: false,
        error: 'Stripe is not configured. Please check your API keys in .env.',
      );
    }

    String paymentIntentId = '';
    FocusManager.instance.primaryFocus?.unfocus();
    // ── Flow A: Primary Native Payment Sheet ────────────────────────────────
    try {
      debugPrint('[Stripe] Starting deposit payment flow for £${(amountPence / 100).toStringAsFixed(2)}...');
      final intentData = await _createOrFetchPaymentIntent(
        payload: {
          'booking_id': bookingId,
          'branch_id': branchId,
          'amount': amountPence,
          'currency': currency,
          'flow': 'sheet',
        },
        amountPence: amountPence,
        currency: currency,
        metadata: {
          'booking_id': bookingId,
          'branch_id': branchId,
          'payment_type': 'table_deposit',
        },
      );

      final clientSecret = intentData['client_secret'] as String?;
      paymentIntentId = (intentData['payment_intent_id'] as String?) ?? '';

      if (clientSecret != null && clientSecret.isNotEmpty) {
        await _initAndPresentPaymentSheet(
          clientSecret: clientSecret,
          currency: currency,
        );

        debugPrint('[Stripe] ✅ Booking deposit payment completed: $paymentIntentId');
        return StripePaymentResult(
          success: true,
          paymentIntentId: paymentIntentId,
        );
      }
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        debugPrint('[Stripe] ⚠️ Booking sheet cancelled by user.');
        return const StripePaymentResult(success: false, cancelled: true);
      }
      debugPrint('[Stripe] ⚠️ Booking native sheet error: ${e.error.localizedMessage}. Attempting web fallback...');
    } catch (e) {
      debugPrint('[Stripe] ⚠️ Booking native sheet failed ($e). Attempting web fallback...');
    }

    // ── Flow B: Fail-Safe In-App Safari Checkout Fallback ───────────────────
    return await _launchHostedCheckout(
      payload: {
        'booking_id': bookingId,
        'branch_id': branchId,
        'amount': amountPence,
        'currency': currency,
        'flow': 'checkout',
      },
    );
  }

  /// Obtains PaymentIntent client_secret with timeout and truncation guards.
  static Future<Map<String, dynamic>> _createOrFetchPaymentIntent({
    required Map<String, dynamic> payload,
    required int amountPence,
    required String currency,
    required Map<String, String> metadata,
  }) async {
    String? lastError;

    // Attempt 1: Call Supabase Edge Function
    try {
      debugPrint('[Stripe] Calling Supabase Edge Function: create-payment-intent...');
      final response = await Supabase.instance.client.functions
          .invoke('create-payment-intent', body: payload)
          .timeout(
            const Duration(seconds: 12),
            onTimeout: () => throw TimeoutException('Edge function timed out after 12 seconds.'),
          );

      if (response.status == 200 && response.data is Map) {
        final data = response.data as Map;
        final secret = data['client_secret'] as String?;
        final intentId = data['payment_intent_id'] as String?;
        final remoteKey = data['publishable_key'] as String?;

        // Guard against truncated placeholders or corrupted strings
        if (remoteKey != null &&
            remoteKey.startsWith('pk_') &&
            !remoteKey.contains('...') &&
            remoteKey.length > 30) {
          if (remoteKey != Stripe.publishableKey) {
            StripeConfig.updatePublishableKey(remoteKey);
            Stripe.publishableKey = remoteKey;
            try {
              await Stripe.instance.applySettings();
              debugPrint('[Stripe] 🔄 Dynamic Stripe key synced: $remoteKey');
            } catch (_) {}
          }
        }

        if (secret != null && secret.isNotEmpty) {
          debugPrint('[Stripe] ✅ Edge function returned client_secret: ${secret.substring(0, 15)}...');
          return {
            'client_secret': secret,
            'payment_intent_id': intentId,
          };
        }
      }
      lastError = 'Edge function status ${response.status}';
      debugPrint('[Stripe] Edge function returned status: ${response.status}, data: ${response.data}');
    } catch (edgeErr) {
      lastError = edgeErr.toString();
      debugPrint('[Stripe] Edge function failed ($edgeErr). Trying direct API fallback...');
    }

    // Attempt 2: Direct Stripe API invocation with secret key (if available)
    if (StripeConfig.secretKey.isNotEmpty) {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      try {
        final request = await client
            .postUrl(Uri.parse('https://api.stripe.com/v1/payment_intents'))
            .timeout(const Duration(seconds: 10));

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

        final httpResponse = await request.close().timeout(const Duration(seconds: 10));
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
          lastError = 'Stripe API error (${httpResponse.statusCode})';
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

  /// Verifies whether a PaymentIntent has succeeded on Stripe servers.
  static const int _maxVerifyAttempts = 4;
  static const List<int> _verifyDelaysMs = [0, 1000, 2000, 3000];

  static Future<bool> _verifyPaymentIntentSucceeded(String intentId) async {
    if (intentId.isEmpty || StripeConfig.secretKey.isEmpty) return false;

    for (int attempt = 0; attempt < _maxVerifyAttempts; attempt++) {
      if (_verifyDelaysMs[attempt] > 0) {
        await Future.delayed(Duration(milliseconds: _verifyDelaysMs[attempt]));
      }

      final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
      try {
        final request = await client
            .getUrl(Uri.parse('https://api.stripe.com/v1/payment_intents/$intentId'))
            .timeout(const Duration(seconds: 6));

        request.headers.set('Authorization', 'Bearer ${StripeConfig.secretKey}');
        final response = await request.close().timeout(const Duration(seconds: 6));

        if (response.statusCode == 200) {
          final body = await response.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          final status = json['status'] as String?;
          debugPrint('[Stripe] Verify attempt ${attempt + 1}/$_maxVerifyAttempts for $intentId: status=$status');
          if (status == 'succeeded' || status == 'processing' || status == 'requires_capture') {
            return true;
          }
        }
      } catch (e) {
        debugPrint('[Stripe] Server verification error (attempt ${attempt + 1}): $e');
      } finally {
        client.close();
      }
    }
    return false;
  }

  /// Initializes and presents the official Stripe Payment Sheet.
  static Future<void> _initAndPresentPaymentSheet({
    required String clientSecret,
    required String currency,
  }) async {
    final activeKey = _effectivePublishableKey;
    if (activeKey.isEmpty || !activeKey.startsWith('pk_')) {
      throw Exception('Stripe publishable key is not configured or invalid.');
    }

    Stripe.publishableKey = activeKey;
    if (EnvConfig.appScheme.isNotEmpty) {
      Stripe.urlScheme = EnvConfig.appScheme;
    }
    await Stripe.instance.applySettings();

    final parameters = SetupPaymentSheetParameters(
      paymentIntentClientSecret: clientSecret,
      merchantDisplayName: StripeConfig.merchantDisplayName.isNotEmpty
          ? StripeConfig.merchantDisplayName
          : 'TigerBay International',
      returnURL: _iosReturnUrl,
      allowsDelayedPaymentMethods: true,
      applePay: null,
      googlePay: null,
      billingDetailsCollectionConfiguration: const BillingDetailsCollectionConfiguration(
        name: CollectionMode.automatic,
        phone: CollectionMode.automatic,
        email: CollectionMode.automatic,
        address: AddressCollectionMode.never,
      ),
      style: ThemeMode.dark,
      appearance: const PaymentSheetAppearance(
        colors: PaymentSheetAppearanceColors(
          primary: AppColors.gold,
          background: Color(0xFF141418),
          componentBackground: Color(0xFF1C1C22),
          componentBorder: Color(0xFF2E2E38),
          componentDivider: Color(0xFF2E2E38),
          primaryText: Colors.white,
          secondaryText: Color(0xFF9E9EA8),
          placeholderText: Color(0xFF6E6E78),
          icon: AppColors.gold,
        ),
      ),
    );

    debugPrint('[Stripe] Calling Stripe.instance.initPaymentSheet...');
    await Stripe.instance.initPaymentSheet(paymentSheetParameters: parameters);

    await Future.delayed(const Duration(milliseconds: 200));

    debugPrint('[Stripe] Presenting payment sheet modal...');
    await Stripe.instance.presentPaymentSheet().timeout(
      const Duration(seconds: 40),
      onTimeout: () => throw TimeoutException('Payment sheet presentation timed out.'),
    );
    debugPrint('[Stripe] Payment sheet presentation completed.');
  }

  /// Launches Stripe Hosted Checkout inside in-app Safari view.
  static Future<StripePaymentResult> _launchHostedCheckout({
    required Map<String, dynamic> payload,
  }) async {
    try {
      final response = await Supabase.instance.client.functions
          .invoke('create-payment-intent', body: payload)
          .timeout(const Duration(seconds: 12));

      final data = response.data;
      if (data is! Map) {
        return const StripePaymentResult(
          success: false,
          error: 'Invalid response from payment server.',
        );
      }

      final checkoutUrl = data['checkout_url'] as String?;
      final sessionId = data['session_id'] as String?;

      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        return StripePaymentResult(
          success: false,
          error: (data['error'] as String?) ?? 'Could not create secure payment session.',
        );
      }

      final didOpen = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.inAppBrowserView,
      );

      if (!didOpen) {
        return const StripePaymentResult(
          success: false,
          error: 'Could not open checkout browser.',
        );
      }

      return StripePaymentResult(
        success: true,
        paymentIntentId: sessionId,
      );
    } catch (e) {
      debugPrint('[StripeCheckout] Fallback error: $e');
      return StripePaymentResult(
        success: false,
        error: e.toString(),
      );
    }
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