// TigerBay International — Stripe Configuration (Stub)
// ──────────────────────────────────────────────────────
// flutter_stripe is NOT currently in pubspec.yaml.
// This file is a placeholder so the project structure is preserved.
//
// TO ACTIVATE: see stripe_service.dart for full instructions.
import 'package:flutter_dotenv/flutter_dotenv.dart';

class StripeConfig {
  StripeConfig._();

  static String get publishableKey =>
      dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';

  /// True only when a real Stripe key is configured (starts with pk_).
  static bool get isConfigured => publishableKey.startsWith('pk_');
}
