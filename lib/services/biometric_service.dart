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

  static const String _biometricEnabledKey = 'tigerbay_biometrics_enabled';

  /// Checks if the device has biometric hardware and enrolled credentials.
  Future<bool> isBiometricAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      return canCheck && isDeviceSupported;
    } on PlatformException catch (e) {
      debugPrint('[TigerBay Biometrics] isBiometricAvailable notice: $e');
      return false;
    }
  }

  /// Returns whether user has enabled biometric login in settings.
  Future<bool> isBiometricEnabled() async {
    try {
      final val = await _storage.read(key: _biometricEnabledKey);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Sets user preference for biometric login.
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _biometricEnabledKey,
      value: enabled ? 'true' : 'false',
    );
  }

  /// Prompts Face ID / Touch ID / Fingerprint.
  Future<bool> authenticate({
    String reason = 'Authenticate to access your TigerBay VIP Lounge & Membership.',
  }) async {
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
    }
  }
}

final biometricServiceProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});
