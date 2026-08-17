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
      await dotenv.load(fileName: '.env');
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
    return _resolve('STRIPE_PUBLISHABLE_KEY', defaultValue: '');
  }

  static bool get isStripeConfigured =>
      stripePublishableKey.startsWith('pk_');

  // ── PayPal ─────────────────────────────────────────────────────────────────

  static String get paypalClientId {
    const compileTime = String.fromEnvironment('PAYPAL_CLIENT_ID');
    if (compileTime.isNotEmpty) return compileTime;
    return _resolve('PAYPAL_CLIENT_ID',
        defaultValue:
            'ATw_FSQNby393C2MysXL2HaT6y_GHvYgz8vDu3_H11FfVfeDG2UrrJrE3ItAdgDtPQSrpw6cYGjVjCp5');
  }

  static String get paypalClientSecret {
    const compileTime = String.fromEnvironment('PAYPAL_CLIENT_SECRET');
    if (compileTime.isNotEmpty) return compileTime;
    return _resolve('PAYPAL_CLIENT_SECRET',
        defaultValue:
            'ECgSnr_l-UV086zWcXOBi4zNgt_VJ-kbXQhY5rHa_EsHkzYqCcJCaIPBgltE-Pd3kFGPGfFxiySUj3ff');
  }

  static String get paypalMode {
    const compileTime = String.fromEnvironment('PAYPAL_MODE');
    if (compileTime.isNotEmpty) return compileTime;
    return _resolve('PAYPAL_MODE', defaultValue: 'sandbox');
  }

  static bool get isPayPalSandbox => paypalMode.toLowerCase() == 'sandbox';

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
