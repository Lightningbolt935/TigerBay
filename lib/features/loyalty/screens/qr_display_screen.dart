import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/qr_timer.dart';
import '../../../data/repositories/loyalty_repository.dart';
import '../../auth/providers/auth_provider.dart';

class QrDisplayScreen extends ConsumerStatefulWidget {
  const QrDisplayScreen({super.key});

  @override
  ConsumerState<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends ConsumerState<QrDisplayScreen> {
  QrTimer? _qrTimer;
  String _qrData = '';
  int _secondsRemaining = 60;
  StreamSubscription<QrPayload>? _sub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    final secret = await LoyaltyRepository()
        .generateQrSecret(user.id)
        .catchError((_) => 'fallback_${user.id}');

    _qrTimer = QrTimer(userId: user.id, deviceId: 'device', secret: secret);
    _qrTimer!.start();
    _sub = _qrTimer!.stream.listen((p) {
      if (mounted) {
        setState(() {
        _qrData = p.qrData;
        _secondsRemaining = p.secondsRemaining;
      });
      }
    });
  }

  @override
  void dispose() {
    _qrTimer?.dispose();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isExpiring = _secondsRemaining <= 10;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan to Earn',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white, // Keep QR background white for scanners
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isExpiring
                      ? AppColors.error.withValues(alpha: 0.5)
                      : AppColors.gold.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.08),
                    blurRadius: 30,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: _qrData.isEmpty
                  ? const SizedBox(
                      width: 240,
                      height: 240,
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.gold, strokeWidth: 2),
                      ),
                    )
                  : QrImageView(
                      data: _qrData,
                      version: QrVersions.auto,
                      size: 240,
                    ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    value: _secondsRemaining / 60.0,
                    strokeWidth: 2.5,
                    backgroundColor: Colors.white12,
                    color: isExpiring ? AppColors.error : AppColors.gold,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Refreshes in ${_secondsRemaining}s',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isExpiring ? AppColors.error : Colors.white70,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Show this QR code to staff to earn points',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
