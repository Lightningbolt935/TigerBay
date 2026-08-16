import 'package:flutter/material.dart';
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
/// TigerBay International — Loyalty / Strips Wallet Screen (Apple Dark Luxury)
/// ═══════════════════════════════════════════════════════════════════════════
class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Live profile stream from Supabase (profiles table) ─────────────────
    final profileStream = ref.watch(userProfileStreamProvider);

    // ── Resolve tier name from membership_tiers table ──────────────────────
    final tiersAsync = ref.watch(membershipTiersProvider);

    // ── Live transaction ledger ────────────────────────────────────────────
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
          ),

          // ── Live Animated Digital Membership Card ────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: profileStream.when(
                data: (profile) {
                  final String tierName = tiersAsync.whenData((tiers) {
                    final tierId = profile?.membershipTierId;
                    if (tierId == null) return '';
                    try {
                      return tiers.firstWhere((t) => t.id == tierId).name;
                    } catch (_) {
                      return '';
                    }
                  }).valueOrNull ?? '';

                  return LiveLoyaltyCard(
                    tierName: tierName,
                    balance: profile?.stripsBalance ?? 0,
                    userName: profile?.fullName ?? 'TigerBay Member',
                    onTap: () => context.push(AppRoutes.qrDisplay),
                  );
                },
                loading: () => _CardSkeleton(),
                error: (err, _) {
                  final fallback = ref.read(userProfileProvider);
                  final String tierName = tiersAsync.whenData((tiers) {
                    final tierId = fallback?.membershipTierId;
                    if (tierId == null) return '';
                    try {
                      return tiers.firstWhere((t) => t.id == tierId).name;
                    } catch (_) {
                      return '';
                    }
                  }).valueOrNull ?? '';
                  return LiveLoyaltyCard(
                    tierName: tierName,
                    balance: fallback?.stripsBalance ?? 0,
                    userName: fallback?.fullName ?? 'TigerBay Member',
                    onTap: () => context.push(AppRoutes.qrDisplay),
                  );
                },
              ),
            ),
          ),

          // ── Apple-Style Quick Action Matrix ──────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.45,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                children: [
                  _ActionCard(
                    title: 'Live QR Pass',
                    subtitle: 'Scan at lounge to earn & spend',
                    icon: Icons.qr_code_scanner_rounded,
                    iconColor: AppColors.gold,
                    onTap: () => context.push(AppRoutes.qrDisplay),
                  ),
                  _ActionCard(
                    title: 'Redeem Perks',
                    subtitle: 'Spend Strips on gifts & perks',
                    icon: Icons.card_giftcard_rounded,
                    iconColor: AppColors.brandRed,
                    onTap: () => context.push(AppRoutes.rewardStore),
                  ),
                  _ActionCard(
                    title: 'Physical Card',
                    subtitle: 'Link membership card badge',
                    icon: Icons.credit_card_rounded,
                    iconColor: const Color(0xFFE5A93C),
                    onTap: () => context.push(AppRoutes.linkPhysicalCard),
                  ),
                  _ActionCard(
                    title: 'Ledger Audit',
                    subtitle: 'View points history & logs',
                    icon: Icons.receipt_long_rounded,
                    iconColor: const Color(0xFF38BDF8),
                    onTap: () => context.push(AppRoutes.transactionHistory),
                  ),
                ],
              ),
            ),
          ),

          // ── Transaction Ledger Activity Header ───────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'RECENT LEDGER ACTIVITY',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.gold,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Live Ledger Rows (Apple Pay Inset Grouped Style) ──────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: txAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      padding: const EdgeInsets.symmetric(
                          vertical: 36, horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.glassBorder,
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
                                size: 30,
                                color: AppColors.textHint,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No transactions yet',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Visit TigerBay lounges to start earning Strips!',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Show up to 4 most recent entries
                final preview = entries.take(4).toList();
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
                  padding: EdgeInsets.symmetric(vertical: 32),
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
                      'Could not load transactions.',
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
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
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

// ── Action Navigation Node Card (Apple Squircle Style) ────────────────────────
class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppleTouchFeedback(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.glassBorder,
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 14,
              spreadRadius: -2,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: AppColors.textSecondary,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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

    return AppleTouchFeedback(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.glassBorder,
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
      ),
    );
  }
}
