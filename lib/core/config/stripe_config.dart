import 'package:tigerbay_app/core/config/env_config.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Stripe Configuration
/// ═══════════════════════════════════════════════════════════════════════════
class StripeConfig {
  StripeConfig._();

  static String _dynamicPublishableKey = '';

  /// Allows hot-switching to live production Stripe keys without rebuilding the app binary.
  static void updatePublishableKey(String newKey) {
    if (newKey.startsWith('pk_')) {
      _dynamicPublishableKey = newKey;
    }
  }

  static String get publishableKey =>
      _dynamicPublishableKey.isNotEmpty ? _dynamicPublishableKey : EnvConfig.stripePublishableKey;
  static String get secretKey => EnvConfig.stripeSecretKey;

  /// True only when a real Stripe key is configured (starts with pk_).
  static bool get isConfigured => publishableKey.startsWith('pk_');

  /// True when using Stripe test keys (pk_test_).
  static bool get isTestMode => publishableKey.startsWith('pk_test_');

  static const String merchantDisplayName = 'TigerBay International';
  static const String merchantCountryCode = 'GB';
  static const String defaultCurrency = 'gbp';

  /// Custom URL scheme used by Stripe for automatic redirects (Link, 3DS, etc.)
  static String get returnURL => '${EnvConfig.appScheme}://safepay';
}
