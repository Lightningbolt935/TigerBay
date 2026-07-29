import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Implements 1:1 device binding.
/// On first login, the device fingerprint is stored in Supabase
/// against the user account. Subsequent logins verify the device
/// matches — different devices are blocked or flagged for review.
///
/// **Web safety**: All methods early-return on web. The `dart:io` `Platform`
/// class is never accessed — callers must gate invocations with `kIsWeb`.
class DeviceBinding {
  static const String _storageKey = 'tigerbay_device_id';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  /// Returns a stable, unique device identifier.
  /// On web, returns a fallback timestamp-based ID.
  static Future<String> getDeviceId() async {
    // Web has no hardware identifiers — return a timestamp fallback.
    if (kIsWeb) return _fallbackId();

    // Check if we already have a stored ID
    final stored = await _storage.read(key: _storageKey);
    if (stored != null && stored.isNotEmpty) return stored;

    // Generate from hardware identifiers (mobile only).
    // We dynamically query device_info_plus which handles the
    // platform dispatch internally — no need for dart:io Platform here.
    String deviceId;
    final deviceData = await _deviceInfo.deviceInfo;
    final data = deviceData.data;

    // device_info_plus returns a map; extract the best unique identifier.
    if (data.containsKey('identifierForVendor')) {
      // iOS
      deviceId = (data['identifierForVendor'] as String?) ?? _fallbackId();
    } else if (data.containsKey('id')) {
      // Android
      deviceId = data['id'] as String? ?? _fallbackId();
    } else {
      deviceId = _fallbackId();
    }

    await _storage.write(key: _storageKey, value: deviceId);
    return deviceId;
  }

  /// Gets device metadata for display and audit logging.
  /// On web, returns generic web platform info.
  static Future<Map<String, String>> getDeviceInfo() async {
    if (kIsWeb) {
      return {
        'platform': 'Web',
        'model': 'Browser',
        'os_version': 'N/A',
        'name': 'Web Client',
      };
    }

    // Use device_info_plus's cross-platform API instead of dart:io Platform.
    final deviceData = await _deviceInfo.deviceInfo;
    final data = deviceData.data;

    // Detect iOS vs Android based on the keys present in the info map.
    if (data.containsKey('systemVersion')) {
      // iOS device
      return {
        'platform': 'iOS',
        'model': data['model']?.toString() ?? 'Unknown',
        'os_version': data['systemVersion']?.toString() ?? 'Unknown',
        'name': data['name']?.toString() ?? 'Unknown',
      };
    } else {
      // Android device
      final manufacturer = data['manufacturer']?.toString() ?? '';
      final model = data['model']?.toString() ?? 'Unknown';
      return {
        'platform': 'Android',
        'model': '$manufacturer $model'.trim(),
        'os_version': (data['version'] is Map)
            ? (data['version'] as Map)['release']?.toString() ?? 'Unknown'
            : 'Unknown',
        'name': data['device']?.toString() ?? 'Unknown',
      };
    }
  }

  static String _fallbackId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Clears device binding (used on sign-out or account deletion)
  static Future<void> clearBinding() async {
    if (kIsWeb) return;
    await _storage.delete(key: _storageKey);
  }
}
