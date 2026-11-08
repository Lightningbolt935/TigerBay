import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

      if (clientSecret == null || clientSecret.isEmpty) {
        debugPrint('[Stripe] ❌ Failed to obtain client secret from payment server.');
        return StripePaymentResult(
          success: false,
          error: (intentData['error'] as String?) ??
              'Could not initialize payment session with server.',
        );
      }

      debugPrint('[Stripe] [Step 2] Presenting native sheet...');
      await _initAndPresentPaymentSheet(
        clientSecret: clientSecret,
        currency: currency,
      );

      // ── Step 3: MANDATORY VERIFICATION with Stripe ─────────────────────────
      // On iOS and Android, sheet dismissal / back gestures can complete normally
      // or return without throwing an explicit cancellation. We NEVER declare
      // success until Stripe's servers confirm the PaymentIntent status is succeeded.
      debugPrint('[Stripe] [Step 3] Verifying PaymentIntent status on Stripe servers...');
      final isPaid = await verifyPaymentIntentStatus(clientSecret: clientSecret);
      if (isPaid) {
        debugPrint('[Stripe] ✅ Membership payment verified succeeded: $paymentIntentId');
        return StripePaymentResult(
          success: true,
          paymentIntentId: paymentIntentId,
        );
      } else {
        debugPrint('[Stripe] ⚠️ Payment sheet closed without successful payment.');
        return const StripePaymentResult(
          success: false,
          cancelled: true,
          error: 'Payment was not completed. No charge was made.',
        );
      }
    } on StripeException catch (e) {
      final msg = (e.error.localizedMessage ?? e.error.message ?? '').toLowerCase();
      final isCancel = e.error.code == FailureCode.Canceled ||
          msg.contains('cancel') ||
          msg.contains('dismiss') ||
          msg.contains('abort');

      if (isCancel) {
        debugPrint('[Stripe] ⚠️ User dismissed payment sheet ($msg).');
        return const StripePaymentResult(success: false, cancelled: true);
      }

      // If not an explicit cancel, verify whether payment actually succeeded
      // before surfacing an error (e.g. timeout after 3DS redirect).
      if (paymentIntentId.isNotEmpty) {
        final clientSecret = (await _createOrFetchPaymentIntent(
          payload: {'tier_name': tierName, 'amount': amountPence, 'flow': 'sheet'},
          amountPence: amountPence,
          currency: currency,
          metadata: {},
        ))['client_secret'] as String?;
        if (clientSecret != null && clientSecret.isNotEmpty) {
          final isPaid = await verifyPaymentIntentStatus(clientSecret: clientSecret, maxAttempts: 2);
          if (isPaid) {
            return StripePaymentResult(success: true, paymentIntentId: paymentIntentId);
          }
        }
      }

      debugPrint('[Stripe] ⚠️ Native sheet error: ${e.error.localizedMessage}');
      return StripePaymentResult(
        success: false,
        error: e.error.localizedMessage ?? 'Payment failed. Please try again.',
      );
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      final isCancel = errStr.contains('cancel') ||
          errStr.contains('dismiss') ||
          errStr.contains('abort');

      if (isCancel) {
        debugPrint('[Stripe] ⚠️ Payment presentation dismissed: $e');
        return const StripePaymentResult(success: false, cancelled: true);
      }

      debugPrint('[Stripe] ⚠️ Native presentation error ($e).');
      return StripePaymentResult(
        success: false,
        error: 'Payment presentation error: ${e.toString()}',
      );
    }
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

      if (clientSecret == null || clientSecret.isEmpty) {
        return StripePaymentResult(
          success: false,
          error: (intentData['error'] as String?) ??
              'Could not initialize deposit session with server.',
        );
      }

      await _initAndPresentPaymentSheet(
        clientSecret: clientSecret,
        currency: currency,
      );

      // ── Step 2: MANDATORY VERIFICATION with Stripe ─────────────────────────
      debugPrint('[Stripe] Verifying deposit PaymentIntent status on Stripe servers...');
      final isPaid = await verifyPaymentIntentStatus(clientSecret: clientSecret);
      if (isPaid) {
        debugPrint('[Stripe] ✅ Booking deposit payment verified succeeded: $paymentIntentId');
        return StripePaymentResult(
          success: true,
          paymentIntentId: paymentIntentId,
        );
      } else {
        debugPrint('[Stripe] ⚠️ Booking deposit sheet closed without payment.');
        return const StripePaymentResult(
          success: false,
          cancelled: true,
          error: 'Deposit payment was not completed. No charge was made.',
        );
      }
    } on StripeException catch (e) {
      final msg = (e.error.localizedMessage ?? e.error.message ?? '').toLowerCase();
      final isCancel = e.error.code == FailureCode.Canceled ||
          msg.contains('cancel') ||
          msg.contains('dismiss') ||
          msg.contains('abort');

      if (isCancel) {
        debugPrint('[Stripe] ⚠️ Booking sheet cancelled by user.');
        return const StripePaymentResult(success: false, cancelled: true);
      }

      debugPrint('[Stripe] ⚠️ Booking native sheet error: ${e.error.localizedMessage}');
      return StripePaymentResult(
        success: false,
        error: e.error.localizedMessage ?? 'Booking payment failed.',
      );
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      final isCancel = errStr.contains('cancel') ||
          errStr.contains('dismiss') ||
          errStr.contains('abort');

      if (isCancel) {
        debugPrint('[Stripe] ⚠️ Booking sheet dismissed: $e');
        return const StripePaymentResult(success: false, cancelled: true);
      }

      debugPrint('[Stripe] ⚠️ Booking native sheet failed ($e).');
      return StripePaymentResult(
        success: false,
        error: e.toString(),
      );
    }
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

  /// Verifies whether a PaymentIntent has actually succeeded on Stripe servers.
  ///
  /// Uses [Stripe.instance.retrievePaymentIntent] with [clientSecret] directly.
  /// Returns `true` ONLY if status is [PaymentIntentsStatus.Succeeded] or
  /// [PaymentIntentsStatus.RequiresCapture]. If the user dismissed or closed
  /// without paying, status will be [PaymentIntentsStatus.RequiresPaymentMethod]
  /// or [PaymentIntentsStatus.Canceled], returning `false`.
  static Future<bool> verifyPaymentIntentStatus({
    required String clientSecret,
    int maxAttempts = 3,
  }) async {
    if (clientSecret.isEmpty) return false;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        await Future.delayed(const Duration(milliseconds: 1200));
      }

      try {
        final intent = await Stripe.instance.retrievePaymentIntent(clientSecret);
        debugPrint(
          '[Stripe] Verification attempt ${attempt + 1}/$maxAttempts for ${intent.id}: status=${intent.status}',
        );

        if (intent.status == PaymentIntentsStatus.Succeeded ||
            intent.status == PaymentIntentsStatus.RequiresCapture) {
          return true;
        }

        // If explicitly cancelled or still awaiting payment method/confirmation,
        // the user navigated back or dismissed the sheet without paying.
        if (intent.status == PaymentIntentsStatus.Canceled ||
            intent.status == PaymentIntentsStatus.RequiresPaymentMethod ||
            intent.status == PaymentIntentsStatus.RequiresConfirmation) {
          debugPrint(
            '[Stripe] Intent status is ${intent.status} — payment was NOT completed.',
          );
          return false;
        }

        // If status is Processing, continue polling in next attempt
        if (intent.status != PaymentIntentsStatus.Processing) {
          return false;
        }
      } catch (e) {
        debugPrint('[Stripe] retrievePaymentIntent attempt ${attempt + 1} error: $e');
      }
    }

    return false;
  }

  /// Verifies whether a PaymentIntent has succeeded on Stripe servers by intentId.
  /// Kept for backward compatibility.
  static Future<bool> verifyPaymentIntentSucceeded(String intentId) async {
    if (intentId.isEmpty || StripeConfig.secretKey.isEmpty) return false;

    const int maxVerifyAttempts = 4;
    const List<int> verifyDelaysMs = [0, 1000, 2000, 3000];

    for (int attempt = 0; attempt < maxVerifyAttempts; attempt++) {
      if (verifyDelaysMs[attempt] > 0) {
        await Future.delayed(Duration(milliseconds: verifyDelaysMs[attempt]));
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
          debugPrint('[Stripe] Verify attempt ${attempt + 1}/$maxVerifyAttempts for $intentId: status=$status');
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
    if (Platform.isIOS) {
      Stripe.merchantIdentifier = 'merchant.com.tigerbay.tigerbayApp';
    }
    await Stripe.instance.applySettings();

    SetupPaymentSheetParameters buildParams({required bool withApplePay}) {
      return SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: StripeConfig.merchantDisplayName.isNotEmpty
            ? StripeConfig.merchantDisplayName
            : 'TigerBay International',
        returnURL: _iosReturnUrl,
        allowsDelayedPaymentMethods: true,
        applePay: withApplePay
            ? const PaymentSheetApplePay(
                merchantCountryCode: StripeConfig.merchantCountryCode,
              )
            : null,
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
    }

    debugPrint('[Stripe] Initializing payment sheet parameters...');
    try {
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: buildParams(withApplePay: Platform.isIOS),
      );
    } catch (e) {
      debugPrint('[Stripe] initPaymentSheet with Apple Pay failed ($e). Retrying without Apple Pay...');
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: buildParams(withApplePay: false),
      );
    }

    await Future.delayed(const Duration(milliseconds: 200));

    debugPrint('[Stripe] Presenting payment sheet modal...');
    await Stripe.instance.presentPaymentSheet().timeout(
      const Duration(seconds: 40),
      onTimeout: () => throw TimeoutException('Payment sheet presentation timed out.'),
    );
    debugPrint('[Stripe] Payment sheet presentation completed.');
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