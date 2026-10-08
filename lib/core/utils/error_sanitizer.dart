import 'dart:convert';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Error Sanitizer & Humanizer
/// ═══════════════════════════════════════════════════════════════════════════
/// Strips out all technical jargon, raw JSON payloads, developer URLs,
/// and API exception strings, converting them into clean, polite, human-readable
/// English for our VIP guests and testers.
class ErrorSanitizer {
  ErrorSanitizer._();

  /// Converts any exception or error object into user-friendly plain text.
  static String format(dynamic error) {
    if (error == null) return 'An unexpected error occurred. Please try again.';

    String raw = error.toString().trim();

    // 1. Remove Exception prefix wrappers
    if (raw.startsWith('Exception:')) {
      raw = raw.replaceFirst('Exception:', '').trim();
    }
    if (raw.startsWith('AuthException(message:')) {
      raw = raw
          .replaceFirst('AuthException(message:', '')
          .replaceAll(RegExp(r'\)$'), '')
          .trim();
    }

    // 2. Try parsing raw JSON payloads (e.g. from Dio or Supabase API responses)
    if (raw.startsWith('{') && raw.endsWith('}')) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final msg = decoded['message'] ??
              decoded['error_description'] ??
              decoded['error'] ??
              decoded['msg'];
          if (msg != null && msg.toString().isNotEmpty) {
            raw = msg.toString();
          }
        }
      } catch (_) {
        // Not valid JSON, continue with string inspection
      }
    }

    final lower = raw.toLowerCase();

    // ── Twilio Trial / Compliance Restrictions ─────────────────────────────
    if (lower.contains('compliance profile') ||
        lower.contains('trusthub') ||
        lower.contains('unverified numbers') ||
        lower.contains('verified caller id') ||
        lower.contains('21608') ||
        lower.contains('sandbox')) {
      return 'Unable to deliver SMS verification to this phone number. Please check the number or contact guest support.';
    }

    // ── Twilio / SMS Invalid Phone Number ──────────────────────────────────
    if (lower.contains('21211') ||
        lower.contains('not a valid phone number') ||
        lower.contains('invalid to phone number')) {
      return 'Please enter a valid mobile number with country code.';
    }

    // ── Twilio Rate Limiting / Cooldown ────────────────────────────────────
    if (lower.contains('rate limit') ||
        lower.contains('too many requests') ||
        lower.contains('max attempts') ||
        lower.contains('429')) {
      return 'Too many verification attempts. Please wait a few moments before trying again.';
    }

    // ── Authentication & Credentials ───────────────────────────────────────
    if (lower.contains('invalid login credentials') ||
        lower.contains('invalid_credentials')) {
      return 'Incorrect email or password. Please try again.';
    }

    if (lower.contains('email already registered') ||
        lower.contains('user_already_exists') ||
        lower.contains('already in use')) {
      return 'An account with this email already exists. Try signing in instead.';
    }

    if (lower.contains('email not confirmed') ||
        lower.contains('email_not_confirmed')) {
      return 'Please check your inbox and verify your email address to continue.';
    }

    if (lower.contains('weak_password') ||
        lower.contains('password should be at least')) {
      return 'Password must be at least 6 characters long.';
    }

    // ── OTP & Verification Code Validation ─────────────────────────────────
    if (lower.contains('token has expired') ||
        lower.contains('otp expired') ||
        lower.contains('invalid token') ||
        lower.contains('invalid code') ||
        lower.contains('incorrect 6-digit') ||
        lower.contains('incorrect verification code') ||
        lower.contains('20404')) {
      return 'The verification code entered is incorrect or expired. Please check and try again.';
    }

    // ── Network & Connection ───────────────────────────────────────────────
    if (lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('connection timed out') ||
        lower.contains('failed host lookup') ||
        lower.contains('network') ||
        lower.contains('handshakeexception')) {
      return 'Unable to connect to TigerBay. Please check your internet connection.';
    }

    // ── Google / Third-Party Sign-In ───────────────────────────────────────
    if (lower.contains('sign_in_canceled') ||
        lower.contains('canceled') ||
        lower.contains('cancelled') ||
        lower.contains('abort')) {
      return ''; // User cancelled intentionally — no visible error needed
    }

    if (lower.contains('apiexception: 10') ||
        lower.contains('12500') ||
        lower.contains('developer_error')) {
      return 'Google Sign-In is configuring. Please try again in a moment or sign in with email.';
    }

    // ── Remove Any Remaining URLs or API paths ─────────────────────────────
    if (raw.contains('http://') || raw.contains('https://')) {
      raw = raw.replaceAll(RegExp(r'https?://[^\s]+'), '').trim();
    }

    // ── Remove Any JSON or Code-like fragments ─────────────────────────────
    if (raw.contains('{') || raw.contains('}') || raw.contains('":')) {
      return 'Unable to complete your request. Please try again in a few moments.';
    }

    // If cleaned message is still reasonably short and readable, return it
    if (raw.length > 5 && raw.length < 120 && !raw.contains('DioException')) {
      return raw;
    }

    // Friendly generic fallback
    return 'Unable to complete your request. Please check your details and try again.';
  }
}
