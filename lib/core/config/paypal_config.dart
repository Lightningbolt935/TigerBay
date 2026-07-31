import 'package:flutter_dotenv/flutter_dotenv.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — PayPal Configuration
/// ═══════════════════════════════════════════════════════════════════════════
/// Reads PayPal credentials from .env. Switch PAYPAL_MODE to 'live' for
/// production. Return/cancel URLs are deep-link safe — they match the app
/// scheme defined in AndroidManifest / Info.plist.
class PayPalConfig {
  PayPalConfig._();

  static String get clientId =>
      dotenv.env['PAYPAL_CLIENT_ID'] ?? '';

  static String get secretKey =>
      dotenv.env['PAYPAL_CLIENT_SECRET'] ?? '';

  static String get mode =>
      dotenv.env['PAYPAL_MODE'] ?? 'sandbox';

  static bool get isSandbox => mode == 'sandbox';

  /// PayPal will redirect here after a successful payment.
  /// Must match an allowed return URL registered in your PayPal app dashboard.
  static const String returnUrl =
      'https://tigerbay.io/paypal/return';

  /// PayPal will redirect here if the user cancels.
  static const String cancelUrl =
      'https://tigerbay.io/paypal/cancel';
}
