import 'package:tigerbay_app/core/config/env_config.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — PayPal Configuration
/// ═══════════════════════════════════════════════════════════════════════════
/// Reads PayPal credentials from EnvConfig (supports .env and dart-define).
class PayPalConfig {
  PayPalConfig._();

  static String get clientId => EnvConfig.paypalClientId;

  static String get secretKey => EnvConfig.paypalClientSecret;

  static String get mode => EnvConfig.paypalMode;

  static bool get isSandbox => EnvConfig.isPayPalSandbox;

  /// PayPal will redirect here after a successful payment.
  /// Must match an allowed return URL registered in your PayPal app dashboard.
  static const String returnUrl =
      'https://tigerbay.io/paypal/return';

  /// PayPal will redirect here if the user cancels.
  static const String cancelUrl =
      'https://tigerbay.io/paypal/cancel';
}
