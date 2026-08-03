import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/data/models/reward_item_model.dart';
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

          // Balance Bar
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

          // Rewards List
          Expanded(
            child: rewardsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
              ),
              error: (err, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    Text('Could not load rewards',
                        style: GoogleFonts.poppins(fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(rewardsForBranchProvider(branchId)),
                      child: Text('Retry',
                          style: GoogleFonts.poppins(fontSize: 13, color: AppColors.gold)),
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
                            color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
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
                    reward: rewards[index],
                    userBalance: stripsBalance,
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

class _RewardCard extends ConsumerWidget {
  final RewardItem reward;
  final int userBalance;

  const _RewardCard({required this.reward, required this.userBalance});

  bool get canAfford => userBalance >= reward.stripsCost;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final redeemState = ref.watch(redeemNotifierProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

                // Redeem Button (full width)
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: canAfford && !redeemState.isProcessing
                        ? () => _handleRedeem(context, ref)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          canAfford ? AppColors.gold : AppColors.surfaceLight,
                      foregroundColor:
                          canAfford ? const Color(0xFF1C1C1E) : AppColors.textHint,
                      disabledBackgroundColor: AppColors.surfaceLight,
                      disabledForegroundColor: AppColors.textHint,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22)),
                      elevation: 0,
                    ),
                    child: redeemState.isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Color(0xFF1C1C1E), strokeWidth: 2))
                        : Text(
                            canAfford ? 'REDEEM' : 'NOT ENOUGH STRIPS',
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showSuccessDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.gold.withValues(alpha: 0.15),
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: AppColors.gold, size: 40),
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
                    color: AppColors.gold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                height: 80,
                decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_2_rounded,
                        size: 36, color: AppColors.textHint),
                    const SizedBox(height: 4),
                    Text('Show to staff at venue',
                        style: GoogleFonts.poppins(
                            fontSize: 11, color: AppColors.textHint)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
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
                        borderRadius: BorderRadius.circular(24)),
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
