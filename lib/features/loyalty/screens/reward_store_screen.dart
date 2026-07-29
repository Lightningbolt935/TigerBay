import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/data/models/reward_item_model.dart';
import 'package:tigerbay_app/features/auth/providers/profile_state_provider.dart';
import 'package:tigerbay_app/features/loyalty/providers/reward_provider.dart';
import 'package:tigerbay_app/shared/widgets/tigerbay_brand_header.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Reward Store Screen
/// ═══════════════════════════════════════════════════════════════════════════
/// Displays a grid of rewards available for redemption using Strips. Each
/// card shows the strips cost badge and a REDEEM button that checks the
/// user's balance before processing. Successful redemptions show a
/// confirmation dialog with a simulated barcode.
class RewardStoreScreen extends ConsumerWidget {
  const RewardStoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(rewardsProvider);
    final stripsBalance = ref.watch(stripsBalanceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Column(
        children: [
          const TigerBayBrandHeader(),

          // ── Balance Bar ──────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: AppColors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'REWARD STORE',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    letterSpacing: 1.2,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gold, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$stripsBalance',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'STRIPS',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Rewards Grid ─────────────────────────────────────────────
          Expanded(
            child: rewardsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                  color: AppColors.gold,
                  strokeWidth: 2,
                ),
              ),
              error: (err, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load rewards',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(rewardsProvider),
                      child: Text(
                        'Retry',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.gold,
                        ),
                      ),
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
                        const Icon(Icons.card_giftcard_outlined,
                            size: 48, color: AppColors.border),
                        const SizedBox(height: 12),
                        Text(
                          'No rewards available yet',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: rewards.length,
                  itemBuilder: (_, index) {
                    return _RewardCard(
                      reward: rewards[index],
                      userBalance: stripsBalance,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reward Card ───────────────────────────────────────────────────────────

class _RewardCard extends ConsumerWidget {
  final RewardItem reward;
  final int userBalance;

  const _RewardCard({
    required this.reward,
    required this.userBalance,
  });

  bool get canAfford => userBalance >= reward.stripsCost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final redeemState = ref.watch(redeemNotifierProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Reward Icon ──────────────────────────────────────────────
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: AppColors.gold,
              size: 28,
            ),
          ),

          const SizedBox(width: 14),

          // ── Title & Description ──────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  reward.description,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // ── Cost Badge + Redeem Button ────────────────────────
                Row(
                  children: [
                    // Strips Cost Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${reward.stripsCost} STRIPS',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1C1C1E),
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Redeem Button
                    SizedBox(
                      height: 36,
                      child: ElevatedButton(
                        onPressed: canAfford &&
                                !redeemState.isProcessing
                            ? () => _handleRedeem(context, ref)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canAfford
                              ? AppColors.gold
                              : AppColors.surfaceLight,
                          foregroundColor: canAfford
                              ? Colors.white
                              : AppColors.textHint,
                          disabledBackgroundColor: AppColors.surfaceLight,
                          disabledForegroundColor: AppColors.textHint,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                        ),
                        child: redeemState.isProcessing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF1C1C1E),
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'REDEEM',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.8,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleRedeem(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(redeemNotifierProvider.notifier);
    final success = await notifier.redeem(reward);

    if (!context.mounted) return;

    if (success) {
      _showSuccessDialog(context, ref);
    } else {
      final error = ref.read(redeemNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error ?? 'Redemption failed. Please try again.',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showSuccessDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Success Icon ────────────────────────────────────────
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.gold,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'REWARD REDEEMED!',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reward.title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // ── Barcode Placeholder ─────────────────────────────────
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.qr_code_2_rounded,
                      size: 36,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Show to staff at venue',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Close Button ────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    ref.read(redeemNotifierProvider.notifier).reset();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'DONE',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1C1C1E),
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
