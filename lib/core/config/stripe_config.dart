// TigerBay International — Stripe Configuration (Stub)
// ──────────────────────────────────────────────────────
// flutter_stripe is NOT currently in pubspec.yaml.
// This file is a placeholder so the project structure is preserved.
//
// TO ACTIVATE: see stripe_service.dart for full instructions.
import 'package:tigerbay_app/core/config/env_config.dart';

class StripeConfig {
  StripeConfig._();

  static String get publishableKey => EnvConfig.stripePublishableKey;

  /// True only when a real Stripe key is configured (starts with pk_).
  static bool get isConfigured => EnvConfig.isStripeConfigured;
}
