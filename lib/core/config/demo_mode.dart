import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Demo Mode
/// ═══════════════════════════════════════════════════════════════════════════
/// A build-time switch for stakeholder demos and internal walkthroughs.
///
/// When enabled, a single master code ([masterOtp]) is accepted anywhere a
/// Twilio Verify code is expected, and SMS delivery failures are downgraded to
/// non-blocking warnings so a demo never stalls on a Twilio quota or sender
/// configuration problem.
///
/// ## This is OFF by default.
///
/// The flag is resolved from `--dart-define=DEMO_MODE=true` first, then from
/// `.env` (`DEMO_MODE=true`), and otherwise stays `false`. It is deliberately
/// *not* a runtime toggle and *not* readable from the network, so a shipped
/// build cannot be flipped on after the fact.
///
/// Enable it for a demo build with:
/// ```bash
/// flutter build web --release --dart-define=DEMO_MODE=true
/// ```
///
/// For the production Vercel deployment, leave `DEMO_MODE` unset — `EnvConfig`
/// and `ci/vercel_build.sh` never pass it.
class DemoMode {
  DemoMode._();

  /// The master code accepted in place of a real SMS one-time password.
  static const String masterOtp = '000000';

  static bool? _cached;

  /// Whether demo affordances are active in this build.
  static bool get isEnabled {
    if (!kReleaseMode) {
      // Debug builds are never a published artifact, so allow the local dev
      // convenience without needing the define.
      return _resolve() ?? true;
    }
    return _cached ??= _resolve() ?? false;
  }

  /// Test seam so the suite can assert both branches.
  // ignore: use_setters_to_change_properties
  static void debugSetEnabled(bool? value) => _cached = value;

  /// Returns `true` when [code] is the master OTP and demo mode is active.
  ///
  /// A code that merely *looks* like the master OTP is rejected when demo mode
  /// is off, so there is no way to satisfy an OTP field with `000000` in a
  /// production build.
  static bool isMasterOtp(String code) =>
      isEnabled && code.trim() == masterOtp;

  static bool? _resolve() {
    const compileTime = String.fromEnvironment('DEMO_MODE');
    if (compileTime.isNotEmpty) {
      return compileTime.toLowerCase() == 'true';
    }
    if (dotenv.isInitialized) {
      final fromEnv = dotenv.maybeGet('DEMO_MODE')?.trim().toLowerCase();
      if (fromEnv == 'true') return true;
      if (fromEnv == 'false') return false;
    }
    return null;
  }

  /// User-facing copy for the demo hint, or `null` when demo mode is off.
  static String? get hint => isEnabled
      ? 'Demo mode — enter $masterOtp to continue without SMS.'
      : null;
}
