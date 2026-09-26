import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Generates a steady, secure QR payload refreshed every 60 seconds.
/// The QR payload remains completely stable during the 60-second window,
/// updating only when the security interval expires.
class QrTimer {
  static const int refreshIntervalSeconds = 60;

  final String userId;
  final String? memberCode;
  final String deviceId;
  final List<String> diningPreferences;
  final String _secret; // from env / Supabase edge function secret

  late StreamController<QrPayload> _controller;
  Timer? _timer;
  int _secondsRemaining = refreshIntervalSeconds;
  String _cachedQrData = '';

  Stream<QrPayload> get stream => _controller.stream;
  int get secondsRemaining => _secondsRemaining;

  QrTimer({
    required this.userId,
    this.memberCode,
    required this.deviceId,
    required String secret,
    this.diningPreferences = const [],
  }) : _secret = secret;

  void start() {
    _controller = StreamController<QrPayload>.broadcast();
    _secondsRemaining = refreshIntervalSeconds;
    _refreshPayload();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _secondsRemaining--;
      if (_secondsRemaining <= 0) {
        _secondsRemaining = refreshIntervalSeconds;
        _refreshPayload();
      } else {
        // Emit tick with the EXACT SAME cached QR string, updating only countdown
        _controller.add(QrPayload(
          qrData: _cachedQrData,
          secondsRemaining: _secondsRemaining,
          generatedAt: DateTime.now(),
        ));
      }
    });
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  void _refreshPayload() {
    final window = _currentWindow();
    final nonce = _generateNonce();
    final displayCode = memberCode ??
        (userId.isNotEmpty
            ? (userId.hashCode.abs() % 900000 + 100000).toString()
            : '100000');
    final data = '$userId:$displayCode:$deviceId:$window:$nonce';
    final signature = _sign(data);

    _cachedQrData = jsonEncode({
      'uid': userId,
      'code': displayCode,
      'did': deviceId,
      'w': window,
      'n': nonce,
      'sig': signature,
      if (diningPreferences.isNotEmpty) 'prefs': diningPreferences,
    });

    _controller.add(QrPayload(
      qrData: _cachedQrData,
      secondsRemaining: _secondsRemaining,
      generatedAt: DateTime.now(),
    ));
  }

  int _currentWindow() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (now ~/ refreshIntervalSeconds) * refreshIntervalSeconds;
  }

  String _sign(String data) {
    final key = utf8.encode(_secret);
    final bytes = utf8.encode(data);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    return digest.toString();
  }

  String _generateNonce() {
    final rand = Random.secure();
    final bytes = List<int>.generate(8, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }
}

class QrPayload {
  final String qrData;
  final int secondsRemaining;
  final DateTime generatedAt;

  const QrPayload({
    required this.qrData,
    required this.secondsRemaining,
    required this.generatedAt,
  });
}
