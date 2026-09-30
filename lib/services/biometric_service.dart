import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Luxury Biometric Authentication Service
/// Handles Face ID / Touch ID / Fingerprint verification for VIP members.
/// ═══════════════════════════════════════════════════════════════════════════

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// `local_auth` ships no web implementation, so every entry point below is a
  /// safe no-op in the browser. Without these guards the plugin throws
  /// `MissingPluginException`, which would strand members on the login screen
  /// (see `splash_screen.dart`, where a failed biometric check signs the user out).
  static bool get _isSupported => !kIsWeb;

  static const String _biometricEnabledKey = 'tigerbay_biometrics_enabled';

  /// Checks if the device has biometric hardware and enrolled credentials.
  Future<bool> isBiometricAvailable() async {
    if (!_isSupported) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on PlatformException catch (e) {
      debugPrint('[TigerBay Biometrics] isBiometricAvailable notice: $e');
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Returns whether user has enabled biometric login in settings.
  Future<bool> isBiometricEnabled() async {
    if (!_isSupported) return false;
    try {
      final val = await _storage.read(key: _biometricEnabledKey);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Sets user preference for biometric login.
  Future<void> setBiometricEnabled(bool enabled) async {
    if (!_isSupported) return;
    try {
      await _storage.write(
        key: _biometricEnabledKey,
        value: enabled ? 'true' : 'false',
      );
    } catch (_) {
      // Preference is best-effort; never block the caller.
    }
  }

  /// Prompts Face ID / Touch ID / Fingerprint.
  Future<bool> authenticate({
    String reason = 'Authenticate to access your TigerBay VIP Lounge & Membership.',
  }) async {
    if (!_isSupported) return false;
    try {
      final available = await isBiometricAvailable();
      if (!available) return false;

      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('[TigerBay Biometrics] Authentication error: $e');
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});
