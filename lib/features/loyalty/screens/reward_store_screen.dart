import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/data/models/reward_item_model.dart';
import 'package:tigerbay_app/features/auth/providers/auth_provider.dart';
import 'package:tigerbay_app/features/auth/providers/profile_state_provider.dart';
import 'package:tigerbay_app/features/home/providers/home_provider.dart';
import 'package:tigerbay_app/features/loyalty/providers/reward_provider.dart';
import 'package:tigerbay_app/shared/widgets/tigerbay_brand_header.dart';

// -- Supabase Storage image URL resolver -------------------------------------
//
// Accepts either a complete HTTP/HTTPS URL (already public) or a bare filename
// stored in the `rewards` table image_url column (e.g. "mocktail.jpg").
// Bare filenames are resolved against the public "Rewards" storage bucket.

String getRewardImageUrl(String imageUrl) {
  if (imageUrl.trim().isEmpty) return '';
  if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
    return imageUrl;
  }
  return Supabase.instance.client.storage
      .from('Rewards')
      .getPublicUrl(imageUrl);
}

/// Reward Store Screen
class RewardStoreScreen extends ConsumerWidget {
  const RewardStoreScreen({super.key});

  /// Handles the complete redemption lifecycle with confirmation, loading indicator,
  /// and guaranteed presentation of the Redemption QR Pass modal.
  Future<void> _handleRedeemRequest(
    BuildContext context,
    WidgetRef ref,
    RewardItem reward,
  ) async {
    // ── 1. Confirm Dialog ──────────────────────────────────────────────────
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.stars_rounded, color: AppColors.gold, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Confirm Redemption',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Redeem "${reward.title}" for ${reward.stripsCost} Strips?',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'A scannable QR voucher will be generated immediately for staff at the venue to verify.',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textHint,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'CANCEL',
              style: GoogleFonts.poppins(
                color: AppColors.textHint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: const Color(0xFF1C1C1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              elevation: 0,
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'CONFIRM & REDEEM',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // ── 2. Loading Indicator ───────────────────────────────────────────────
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 3),
      ),
    );

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('Not authenticated.');
      final repo = ref.read(supabaseRepositoryProvider);

      final redemptionCode = await repo.redeemReward(
        userId: user.id,
        rewardId: reward.id,
        stripsCost: reward.stripsCost,
        rewardTitle: reward.title,
      );

      // Close loading dialog safely
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      final finalCode = (redemptionCode != null && redemptionCode.isNotEmpty)
          ? redemptionCode
          : 'TB-REDEEM-${reward.id}-${DateTime.now().millisecondsSinceEpoch}';

      // ── 3. Guaranteed Presentation of the Redemption QR Dialog ───────────
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => RedemptionQrDialog(
            redemptionCode: finalCode,
            rewardTitle: reward.title,
            stripsCost: reward.stripsCost,
          ),
        );
      }

      // Refresh Strips balance and ledger in background
      ref.invalidate(stripsLedgerProvider);
      try {
        await ref.read(profileStateProvider.notifier).refreshProfile();
      } catch (_) {}
    } catch (e) {
      // Close loading dialog if still open
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Redemption failed: $e',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBranch = ref.watch(selectedBranchProvider);
    final int? branchId = selectedBranch?.id;
    final rewardsAsync = ref.watch(rewardsForBranchProvider(branchId));
    final stripsBalance = ref.watch(stripsBalanceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Column(
        children: [
          const TigerBayBrandHeader(),

          // ── Balance Bar ───────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            color: const Color(0xFF141418),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'REWARD STORE',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Redeem Strips for complimentary perks',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$stripsBalance',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.champagneGold,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'STRIPS',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Rewards List ─────────────────────────────────────────────
          Expanded(
            child: rewardsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                    color: AppColors.gold, strokeWidth: 2),
              ),
              error: (err, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    Text('Could not load rewards',
                        style: GoogleFonts.poppins(
                            fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(rewardsForBranchProvider(branchId)),
                      child: Text('Retry',
                          style: GoogleFonts.poppins(
                              fontSize: 13, color: AppColors.gold)),
                    ),
                  ],
                ),
              ),
              data: (rewards) {
                if (rewards.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.card_giftcard_outlined,
                            size: 48,
                            color:
                                const Color(0xFFD4AF37).withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text('No rewards available yet',
                            style: GoogleFonts.poppins(
                                fontSize: 14, color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: rewards.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, index) => _RewardCard(
                    key: ValueKey('reward_${rewards[index].id}'),
                    reward: rewards[index],
                    userBalance: stripsBalance,
                    onRedeem: () =>
                        _handleRedeemRequest(context, ref, rewards[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// -- Reward Image Widget ------------------------------------------------------

class _RewardImageWidget extends StatelessWidget {
  final String imageUrl;
  final double height;

  const _RewardImageWidget({required this.imageUrl, this.height = 150});

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = getRewardImageUrl(imageUrl);

    return Container(
      height: height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: resolvedUrl.isEmpty
          ? const _RewardPlaceholder()
          : Image.network(
              resolvedUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: const Color(0xFF1C1C1E),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          const Color(0xFFD4AF37).withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => const _RewardPlaceholder(),
            ),
    );
  }
}

class _RewardPlaceholder extends StatelessWidget {
  const _RewardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1C1C1E),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.card_giftcard_rounded,
              color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
              size: 34,
            ),
            const SizedBox(height: 6),
            Text(
              'TIGERBAY REWARD',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -- Reward Card --------------------------------------------------------------

class _RewardCard extends StatelessWidget {
  final RewardItem reward;
  final int userBalance;
  final VoidCallback onRedeem;

  const _RewardCard({
    super.key,
    required this.reward,
    required this.userBalance,
    required this.onRedeem,
  });

  bool get canAfford => userBalance >= reward.stripsCost;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reward image from Supabase Storage
          _RewardImageWidget(imageUrl: reward.imageUrl, height: 150),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + Strips badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        reward.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded,
                              color: Color(0xFFD4AF37), size: 13),
                          const SizedBox(width: 3),
                          Text(
                            '${reward.stripsCost} Strips',
                            style: const TextStyle(
                              color: Color(0xFFD4AF37),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Auto Expiry & Category Tag
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: reward.isExpired
                            ? Colors.red.withValues(alpha: 0.15)
                            : Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: reward.isExpired
                              ? Colors.redAccent
                              : Colors.amber.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            reward.isExpired
                                ? Icons.timer_off_outlined
                                : Icons.hourglass_top_rounded,
                            size: 11,
                            color: reward.isExpired
                                ? Colors.redAccent
                                : Colors.amber,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            reward.expiryBadgeText,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                              color: reward.isExpired
                                  ? Colors.redAccent
                                  : Colors.amber,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Description
                if (reward.description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    reward.description,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 12),

                // Redeem Button
                SizedBox(
                  width: double.infinity,
                  height: 42,
                  child: ElevatedButton(
                    onPressed: (canAfford && !reward.isExpired) ? onRedeem : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: reward.isExpired
                          ? AppColors.surfaceLight
                          : (canAfford ? AppColors.gold : AppColors.surfaceLight),
                      foregroundColor: reward.isExpired
                          ? Colors.redAccent
                          : (canAfford
                              ? const Color(0xFF1C1C1E)
                              : AppColors.textHint),
                      disabledBackgroundColor: AppColors.surfaceLight,
                      disabledForegroundColor: reward.isExpired
                          ? Colors.redAccent.withValues(alpha: 0.7)
                          : AppColors.textHint,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22)),
                      elevation: 0,
                    ),
                    child: Text(
                      reward.isExpired
                          ? 'REWARD EXPIRED'
                          : (canAfford ? 'REDEEM' : 'NOT ENOUGH STRIPS'),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Redemption QR Dialog — Guaranteed Presentation with Countdown Timer
// ═══════════════════════════════════════════════════════════════════════════════

class RedemptionQrDialog extends StatefulWidget {
  final String redemptionCode;
  final String rewardTitle;
  final int stripsCost;

  const RedemptionQrDialog({
    super.key,
    required this.redemptionCode,
    required this.rewardTitle,
    required this.stripsCost,
  });

  @override
  State<RedemptionQrDialog> createState() => _RedemptionQrDialogState();
}

class _RedemptionQrDialogState extends State<RedemptionQrDialog> {
  static const int _totalSeconds = 15 * 60; // 15-minute countdown window
  int _secondsRemaining = _totalSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        setState(() => _secondsRemaining = 0);
        timer.cancel();
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final m = _secondsRemaining ~/ 60;
    final s = _secondsRemaining % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _copyCode() {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: widget.redemptionCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Redemption code copied to clipboard',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1E1E22),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _secondsRemaining / _totalSeconds;
    final isExpiring = _secondsRemaining <= 2 * 60;

    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Success Checkmark Badge ──────────────────────────────
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.gold, size: 38),
              ),
              const SizedBox(height: 12),

              // ── Header Title ─────────────────────────────────────────
              Text(
                'REWARD REDEEMED!',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),

              Text(
                widget.rewardTitle,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // ── Real QR Code Container ───────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: widget.redemptionCode,
                  version: QrVersions.auto,
                  size: 190,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 14),

              // ── Copyable Code Badge ──────────────────────────────────
              InkWell(
                onTap: _copyCode,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          widget.redemptionCode,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.champagneGold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.copy_rounded,
                          size: 13, color: AppColors.textHint),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── Instructions ─────────────────────────────────────────
              Text(
                'Show this QR code to staff at the venue to claim',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),

              // ── Live Countdown Timer ─────────────────────────────────
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: isExpiring ? AppColors.error : AppColors.gold,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _secondsRemaining > 0
                            ? 'Expires in $_formattedTime'
                            : 'QR Code Expired',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isExpiring ? AppColors.error : AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isExpiring ? AppColors.error : AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── DONE Button ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: const Color(0xFF1C1C1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(23),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'DONE',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
