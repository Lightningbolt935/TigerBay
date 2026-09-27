import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../shared/widgets/apple_touch_feedback.dart';
import '../../auth/providers/profile_state_provider.dart';
import '../../profile/providers/membership_provider.dart';
import '../providers/loyalty_provider.dart';
import 'live_loyalty_card.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Member Wallet & Digital Pass (Apple Luxury Grade)
/// ═══════════════════════════════════════════════════════════════════════════
class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Live profile stream from Supabase (profiles table) ─────────────────
    final profileStream = ref.watch(userProfileStreamProvider);

    // ── Resolve tier name from membership_tiers table ──────────────────────
    final tiersAsync = ref.watch(membershipTiersProvider);

    // ── Live transaction history ───────────────────────────────────────────
    final txAsync = ref.watch(stripsTransactionsProvider);

    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Apple-Grade App Bar ───────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 70.0,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.brandBlack,
            elevation: 0,
            centerTitle: true,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    color: AppColors.gold,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'TIGERBAY WALLET',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.0,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  CupertinoIcons.question_circle,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                onPressed: () => _showHowStripsWorkDialog(context),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ── Live Animated Digital Membership Card ────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: profileStream.when(
                data: (profile) {
                  final String tierName = tiersAsync.whenData((tiers) {
                    final tierId = profile?.membershipTierId;
                    if (tierId == null) return 'Explorer';
                    try {
                      return tiers.firstWhere((t) => t.id == tierId).name;
                    } catch (_) {
                      return 'Explorer';
                    }
                  }).valueOrNull ?? 'Explorer';

                  return LiveLoyaltyCard(
                    tierName: tierName,
                    balance: profile?.stripsBalance ?? 0,
                    userName: profile?.fullName ?? 'TigerBay Member',
                    memberCode: profile?.displayMemberId,
                    onTap: () => context.push(AppRoutes.qrDisplay),
                  );
                },
                loading: () => _CardSkeleton(),
                error: (err, _) {
                  final fallback = ref.read(userProfileProvider);
                  final String tierName = tiersAsync.whenData((tiers) {
                    final tierId = fallback?.membershipTierId;
                    if (tierId == null) return 'Explorer';
                    try {
                      return tiers.firstWhere((t) => t.id == tierId).name;
                    } catch (_) {
                      return 'Explorer';
                    }
                  }).valueOrNull ?? 'Explorer';
                  return LiveLoyaltyCard(
                    tierName: tierName,
                    balance: fallback?.stripsBalance ?? 0,
                    userName: fallback?.fullName ?? 'TigerBay Member',
                    memberCode: fallback?.displayMemberId,
                    onTap: () => context.push(AppRoutes.qrDisplay),
                  );
                },
              ),
            ),
          ),

          // ── Digital Pass Quick Instruction ────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.qrcode_viewfinder,
                      size: 15,
                      color: AppColors.gold.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Tap card above to show QR pass for till scanning',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Link Physical Card Action ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
              child: AppleTouchFeedback(
                onTap: () => context.push(AppRoutes.linkPhysicalCard),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141418),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF262630),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          CupertinoIcons.creditcard,
                          size: 16,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Have a Physical Lounge Card?',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Link your plastic card to merge points',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: AppColors.textHint,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Recent Activity Section Header ───────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECENT ACTIVITY',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  AppleTouchFeedback(
                    onTap: () => context.push(AppRoutes.transactionHistory),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'View All',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          CupertinoIcons.chevron_right,
                          size: 14,
                          color: AppColors.gold,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Live Recent Activity Rows (Apple Pay Style) ───────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: txAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(
                        vertical: 28,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141418),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF26262F),
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.receipt_long_outlined,
                                size: 26,
                                color: AppColors.textHint,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'No recent activity yet',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Present your digital pass at TigerBay to earn points!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                final preview = entries.take(3).toList();
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final entry = preview[index];
                      return _HistoryRow(
                        title: entry.description.isNotEmpty
                            ? entry.description
                            : entry.transactionType.toUpperCase(),
                        date: entry.formattedDate,
                        points: entry.displayAmount,
                        isPositive: entry.isEarned,
                      );
                    },
                    childCount: preview.length,
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.gold,
                    ),
                  ),
                ),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Could not load activity.',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Padding so content clears the floating dock
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
    );
  }

  // ── Helper Dialogs ────────────────────────────────────────────────────────

  void _showHowStripsWorkDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: const Color(0xFF141418),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: Color(0xFF333342)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.info_circle_fill,
                    color: AppColors.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'About Strips Loyalty',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                '• Strips are TigerBay points earned on dining, shisha, and reservations.\n\n'
                '• Higher VIP tiers earn up to 3x Strips on every pound spent.\n\n'
                '• Spend your Strips in the Reward Store for complimentary drinks, shisha, and VIP table perks.\n\n'
                '• Every 10 lounge visits unlock milestone streak bonus points automatically.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              AppleTouchFeedback(
                onTap: () => Navigator.of(dialogCtx).pop(),
                child: Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22222E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF353546)),
                  ),
                  child: Center(
                    child: Text(
                      'Understood',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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

// ── Card Loading Skeleton ────────────────────────────────────────────────────
class _CardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 215,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.glassBorder,
          width: 0.8,
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.gold,
          ),
        ),
      ),
    );
  }
}

// ── Transaction Statement Item (Apple Pay Style) ───────────────────────────────
class _HistoryRow extends StatelessWidget {
  final String title;
  final String date;
  final String points;
  final bool isPositive;

  const _HistoryRow({
    required this.title,
    required this.date,
    required this.points,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor =
        isPositive ? AppColors.success : AppColors.brandRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF26262F),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive ? Icons.add_rounded : Icons.remove_rounded,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  date,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),
          Text(
            points,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
