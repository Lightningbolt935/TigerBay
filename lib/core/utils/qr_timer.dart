import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Generates a new QR payload every 60 seconds.
/// Each payload is a HMAC-SHA256 signed token containing:
///   userId + timestamp (floored to 60s window) + deviceId
/// This prevents token sharing between sessions or devices.
class QrTimer {
  static const int refreshIntervalSeconds = 60;

  final String userId;
  final String deviceId;
  final String _secret; // from env / Supabase edge function secret

  late StreamController<QrPayload> _controller;
  Timer? _timer;
  int _secondsRemaining = refreshIntervalSeconds;

  Stream<QrPayload> get stream => _controller.stream;
  int get secondsRemaining => _secondsRemaining;

  QrTimer({
    required this.userId,
    required this.deviceId,
    required String secret,
  }) : _secret = secret;

  void start() {
    _controller = StreamController<QrPayload>.broadcast();
    _emitPayload();

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      _secondsRemaining--;
      if (_secondsRemaining <= 0) {
        _secondsRemaining = refreshIntervalSeconds;
        _emitPayload();
      } else {
        // Emit tick with same payload but updated countdown
        _controller.add(_buildPayload(_currentWindow()));
      }
    });
  }

  void dispose() {
    _timer?.cancel();
    _controller.close();
  }

  void _emitPayload() {
    final window = _currentWindow();
    _controller.add(_buildPayload(window));
  }

  int _currentWindow() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (now ~/ refreshIntervalSeconds) * refreshIntervalSeconds;
  }

  QrPayload _buildPayload(int window) {
    final nonce = _generateNonce();
    final data = '$userId:$deviceId:$window:$nonce';
    final signature = _sign(data);

    final payload = jsonEncode({
      'uid': userId,
      'did': deviceId,
      'w': window,
      'n': nonce,
      'sig': signature,
    });

    return QrPayload(
      qrData: payload,
      secondsRemaining: _secondsRemaining,
      generatedAt: DateTime.now(),
    );
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

  QrPayload({
    required this.qrData,
    required this.secondsRemaining,
    required this.generatedAt,
  });
}
