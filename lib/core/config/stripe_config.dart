import 'package:tigerbay_app/core/config/env_config.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Stripe Configuration
/// ═══════════════════════════════════════════════════════════════════════════
class StripeConfig {
  StripeConfig._();

  static String get publishableKey => EnvConfig.stripePublishableKey;
  static String get secretKey => EnvConfig.stripeSecretKey;

  /// True only when a real Stripe key is configured (starts with pk_).
  static bool get isConfigured => EnvConfig.isStripeConfigured;

  /// True when using Stripe test keys (pk_test_).
  static bool get isTestMode => publishableKey.startsWith('pk_test_');

  static const String merchantDisplayName = 'TigerBay International';
  static const String merchantCountryCode = 'GB';
  static const String defaultCurrency = 'gbp';
}
