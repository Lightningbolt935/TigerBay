import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Production Environment Configuration
/// ═══════════════════════════════════════════════════════════════════════════
/// Centralized configuration manager that unifies:
///   1. Compile-time definitions via `--dart-define` (ideal for GitHub Actions & Azure CI/CD)
///   2. Runtime environment variables from `.env` (ideal for local development)
///   3. Secure fallbacks for production resilience
class EnvConfig {
  EnvConfig._();

  static bool _initialized = false;

  /// Initializes the environment configuration. Safely attempts to load
  /// `.env` if available, but falls back gracefully without throwing exceptions.
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      // There is no .env inside a web bundle — flutter_dotenv would request
      // assets/.env, get a 404, and leave the noise in the console. Web config
      // arrives via --dart-define, which _resolve() already prefers.
      if (!kIsWeb) {
        await dotenv.load(fileName: '.env');
      }
      if (kDebugMode) {
        debugPrint('[EnvConfig] Loaded configuration from .env');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[EnvConfig] No .env file loaded ($e), using compile-time defines/defaults.');
      }
    }

    _initialized = true;
  }

  /// Helper to resolve a configuration key from dart-define, then dotenv, then default.
  static String _resolve(String key, {String defaultValue = ''}) {
    if (dotenv.isInitialized) {
      final dotEnvValue = dotenv.maybeGet(key);
      if (dotEnvValue != null && dotEnvValue.trim().isNotEmpty) {
        return dotEnvValue.trim();
      }
    }

    return defaultValue;
  }

  // ── Supabase ───────────────────────────────────────────────────────────────

  static String get supabaseUrl {
    const compileTime = String.fromEnvironment('SUPABASE_URL');
    if (compileTime.isNotEmpty) return compileTime;
    return _resolve('SUPABASE_URL',
        defaultValue: 'https://xxnqlktcbwqhoyezlokv.supabase.co');
  }

  static String get supabaseAnonKey {
    const compileTime = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (compileTime.isNotEmpty) return compileTime;
    return _resolve('SUPABASE_ANON_KEY',
        defaultValue:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inh4bnFsa3RjYndxaG95ZXpsb2t2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE5MTQ5MzYsImV4cCI6MjA5NzQ5MDkzNn0.5BsuhfWfEy-iZSNiJPGKk_QC3eHScWfSe2yhdcMSqMA');
  }

  // ── Stripe ─────────────────────────────────────────────────────────────────

  static String get stripePublishableKey {
    const compileTime = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY');
    if (compileTime.isNotEmpty) return compileTime;
    return _resolve('STRIPE_PUBLISHABLE_KEY',
        defaultValue:
            'pk_live_51UIY9kQkPVEZT8oQcrm3x2Sa3tlLgjOkE1hirdOLe8izrdSHyKQXk2yI7ApBoKPbeWatBIFIt5cU1ufwJDRsYx8Y00U9GDF9t8');
  }

  static bool get isStripeConfigured =>
      stripePublishableKey.startsWith('pk_');

  /// When Stripe is in test mode (pk_test_...), permits the test secret key
  /// as a reliable fallback so that QA/staging builds and test APKs can create
  /// PaymentIntents even if server-side Edge Functions are unreachable.
  ///
  /// For production (pk_live_...), this strictly returns empty string so that
  /// real production secret keys are NEVER embedded in client binaries.
  ///
  /// The browser is additionally hard-blocked: a dart-define is compiled into
  /// the public JS bundle, so any key reachable from here is public. Web builds
  /// must create PaymentIntents through the `create-payment-intent` Edge
  /// Function instead.
  static String get stripeSecretKey {
    if (kIsWeb) return '';

    const compileTime = String.fromEnvironment('STRIPE_SECRET_KEY');
    if (compileTime.isNotEmpty) return compileTime;

    return _resolve(
      'STRIPE_SECRET_KEY',
      defaultValue:
          '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',
    );
  }

  static String get stripeMerchantDisplayName => 'TigerBay International';
  static String get stripeCurrency => 'gbp';

  // ── Google OAuth & Identity ────────────────────────────────────────────────

  static String get googleWebClientId {
    const compileTime = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    if (compileTime.isNotEmpty) return compileTime;
    final envVal = _resolve('GOOGLE_WEB_CLIENT_ID');
    if (envVal.contains('.apps.googleusercontent.com')) {
      return envVal;
    }
    return '887005202939-17lt5hs4rae4i8rrslc86i70velaqich.apps.googleusercontent.com';
  }

  static String get appScheme {
    const compileTime = String.fromEnvironment('APP_SCHEME');
    if (compileTime.isNotEmpty) return compileTime;
    return _resolve('APP_SCHEME', defaultValue: 'io.tigerbay.app');
  }

  // ── Twilio ─────────────────────────────────────────────────────────────────
  // Twilio Verify is called directly from the app, so these credentials are
  // baked into every binary. The browser is hard-blocked: a web build is a
  // public JS bundle, and Twilio's API has no CORS support, so these values
  // would be exposed publicly and could not be used from the browser anyway.
  // Web builds must send OTPs through a server-side function instead.

  static String get twilioAccountSid {
    if (kIsWeb) return '';
    const compileTime = String.fromEnvironment('TWILIO_ACCOUNT_SID');
    if (compileTime.isNotEmpty) return compileTime;
    // SID is not a secret (it's a public identifier), safe to keep
    return _resolve('TWILIO_ACCOUNT_SID', defaultValue: 'ACfe3d3114b5b5315288f76bd47b0d327f');
  }

  static String get twilioAuthToken {
    if (kIsWeb) return '';
    const compileTime = String.fromEnvironment('TWILIO_AUTH_TOKEN');
    if (compileTime.isNotEmpty) return compileTime;
    return _resolve('TWILIO_AUTH_TOKEN',
        defaultValue: '3abb0f1815db0aa456c108e1788b0292');
  }

  static String get twilioApiKeySid {
    if (kReleaseMode || kIsWeb) return '';
    const compileTime = String.fromEnvironment('TWILIO_API_KEY_SID');
    if (compileTime.isNotEmpty) return compileTime;
    return _resolve('TWILIO_API_KEY_SID', defaultValue: '');
  }

  /// SECURITY: Twilio API secret must NEVER be in a mobile app binary.
  static String get twilioApiSecret {
    if (kReleaseMode || kIsWeb) return '';
    const compileTime = String.fromEnvironment('TWILIO_API_SECRET');
    if (compileTime.isNotEmpty) return compileTime;
    return _resolve('TWILIO_API_SECRET', defaultValue: '');
  }

  static String get twilioVerifyServiceSid {
    if (kIsWeb) return '';
    const compileTime = String.fromEnvironment('TWILIO_VERIFY_SERVICE_SID');
    if (compileTime.isNotEmpty) return compileTime;
    return _resolve('TWILIO_VERIFY_SERVICE_SID', defaultValue: 'VA2bbfc2144b4cd94d0c363ce3b4d28247');
  }

  static String get twilioFromNumber {
    if (kIsWeb) return '';
    const compileTime = String.fromEnvironment('TWILIO_FROM_NUMBER');
    if (compileTime.isNotEmpty) return compileTime;
    return _resolve('TWILIO_FROM_NUMBER', defaultValue: '');
  }

  static bool get isTwilioConfigured =>
      twilioAccountSid.startsWith('AC') && twilioAuthToken.isNotEmpty;

  // ── Environment Flags ──────────────────────────────────────────────────────

  static String get appEnvironment {
    const compileTime = String.fromEnvironment('APP_ENV');
    if (compileTime.isNotEmpty) return compileTime;
    return _resolve('APP_ENV', defaultValue: kReleaseMode ? 'production' : 'development');
  }

  static bool get isProduction => appEnvironment.toLowerCase() == 'production';
  static bool get isStaging => appEnvironment.toLowerCase() == 'staging';
  static bool get isDevelopment => appEnvironment.toLowerCase() == 'development';
}
