import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/qr_timer.dart';
import '../../../data/repositories/loyalty_repository.dart';
import '../../../shared/widgets/apple_touch_feedback.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/profile_state_provider.dart';
import '../../profile/providers/membership_provider.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Digital Member QR Pass (Apple Wallet Edition)
/// ═══════════════════════════════════════════════════════════════════════════
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
    final profile = ref.read(userProfileProvider);
    final memberCode = profile?.displayMemberId;
    final secret = await LoyaltyRepository()
        .generateQrSecret(user.id)
        .catchError((_) => 'fallback_${user.id}');

    _qrTimer = QrTimer(
      userId: user.id,
      memberCode: memberCode,
      deviceId: 'device',
      secret: secret,
    );
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

  void _copyMemberId(String memberId) {
    if (memberId.isEmpty) return;
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: memberId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(CupertinoIcons.checkmark_seal_fill,
                color: AppColors.champagneGold, size: 18),
            const SizedBox(width: 10),
            Text(
              'Member ID ($memberId) copied to clipboard',
              style: AppTypography.footnote.copyWith(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E22),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.glassBorder, width: 0.8),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpiring = _secondsRemaining <= 10;
    final user = ref.watch(currentUserProvider);
    final profileStream = ref.watch(userProfileStreamProvider);
    final tiersAsync = ref.watch(membershipTiersProvider);

    final profile =
        profileStream.asData?.value ?? ref.watch(userProfileProvider);
    final userId = user?.id ?? '';
    final memberCode = profile?.displayMemberId ??
        (userId.isNotEmpty
            ? (userId.hashCode.abs() % 900000 + 100000).toString()
            : '100000');
    final formattedMemberId = 'TB-$memberCode';
    final memberName = profile?.fullName ??
        (user?.email?.split('@').first ?? 'TigerBay Member');

    // Resolve tier name
    final String tierName = tiersAsync.whenData((tiers) {
      final tierId = profile?.membershipTierId;
      if (tierId == null) return 'MEMBER';
      try {
        return tiers.firstWhere((t) => t.id == tierId).name.toUpperCase();
      } catch (_) {
        return 'MEMBER';
      }
    }).valueOrNull ?? 'MEMBER';

    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: AppleTouchFeedback(
          onTap: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.chevron_back,
              size: 22, color: AppColors.textPrimary),
        ),
        title: Text(
          'Digital Member Pass',
          style: AppTypography.headline.copyWith(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // ── Member Identity Header Card (Apple Inset Style) ──────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.glassBorder,
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Initials Circle with ambient gold border
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.champagneGold,
                        width: 1.2,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      profile?.initials ?? 'TB',
                      style: AppTypography.sfPro(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.champagneGold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          memberName,
                          style: AppTypography.headline.copyWith(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                tierName,
                                style: AppTypography.caption2.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.champagneGold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${profile?.stripsBalance ?? 0} Strips',
                              style: AppTypography.subheadline.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ── Copyable 6-Digit Member ID Banner ────────────────────────────
            AppleTouchFeedback(
              onTap: () => _copyMemberId(formattedMemberId),
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.glassBorder,
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.person_crop_square,
                      size: 20,
                      color: AppColors.champagneGold,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '6-DIGIT MEMBER ID',
                            style: AppTypography.sectionHeader.copyWith(
                              fontSize: 9.5,
                              color: AppColors.textHint,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedMemberId,
                            style: AppTypography.memberIdStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            CupertinoIcons.doc_on_doc,
                            size: 13,
                            color: AppColors.champagneGold,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Copy',
                            style: AppTypography.caption2.copyWith(
                              color: AppColors.champagneGold,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Optical QR Code Display Card (Apple Pass Layout) ────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isExpiring
                      ? AppColors.error.withValues(alpha: 0.6)
                      : AppColors.glassBorder,
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isExpiring ? AppColors.error : AppColors.gold)
                        .withValues(alpha: 0.10),
                    blurRadius: 36,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // QR Container
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: _qrData.isEmpty
                        ? const SizedBox(
                            width: 220,
                            height: 220,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.gold,
                                strokeWidth: 2,
                              ),
                            ),
                          )
                        : QrImageView(
                            data: _qrData,
                            version: QrVersions.auto,
                            size: 220,
                            backgroundColor: Colors.white,
                          ),
                  ),

                  const SizedBox(height: 18),

                  // 6-Digit Member ID under QR code
                  AppleTouchFeedback(
                    onTap: () => _copyMemberId(formattedMemberId),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.glassBorder,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'MEMBER ID: ',
                            style: AppTypography.caption2.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.champagneGold,
                            ),
                          ),
                          Text(
                            formattedMemberId,
                            style: AppTypography.memberIdStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            CupertinoIcons.doc_on_doc,
                            size: 13,
                            color: AppColors.textHint,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Animated Security Countdown Bar ──────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: AppColors.glassBorder,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      value: _secondsRemaining / 60.0,
                      strokeWidth: 2.2,
                      backgroundColor: Colors.white12,
                      color: isExpiring
                          ? AppColors.error
                          : AppColors.champagneGold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Refreshes in ${_secondsRemaining}s',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color:
                          isExpiring ? AppColors.error : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Instructions for Staff / User ────────────────────────────────
            Text(
              'Present this pass at TigerBay venues to verify status, earn points, and redeem perks.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 36),
          ],
        ),
      ),
    );
  }
}
