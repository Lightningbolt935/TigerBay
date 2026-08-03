import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../auth/providers/profile_state_provider.dart';
import '../../profile/providers/membership_provider.dart';
import '../providers/loyalty_provider.dart';
import 'live_loyalty_card.dart';

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ── Live profile stream from Supabase (profiles table) ─────────────────
    // Emits a new UserProfile every time strips_balance, membership_tier_id,
    // full_name, or any other column changes in real time.
    final profileStream = ref.watch(userProfileStreamProvider);

    // ── Resolve tier name from membership_tiers table ──────────────────────
    final tiersAsync = ref.watch(membershipTiersProvider);

    // ── Live transaction ledger ────────────────────────────────────────────
    final txAsync = ref.watch(stripsTransactionsProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // ── Premium App Bar ──────────────────────────────────────────────
          const SliverAppBar(
            expandedHeight: 60.0,
            floating: false,
            pinned: true,
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Text(
              'TIGERBAY LOYALTY',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: Colors.black87,
              ),
            ),
          ),

          // ── Live Animated Digital Membership Card ────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: profileStream.when(
                data: (profile) {
                  // Resolve the tier name from the membership_tiers lookup.
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
                  );
                },
                loading: () => _CardSkeleton(),
                error: (err, _) {
                  // On stream error, fall back to a card sourced from the
                  // cached profile snapshot so the UI never goes blank.
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
                  );
                },
              ),
            ),
          ),

          // ── Quick Action Command Operations Matrix ───────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 1.55,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _ActionCard(
                    title: 'Live QR Gateway',
                    subtitle: 'Scan at lounge to earn/burn',
                    icon: Icons.qr_code_scanner_rounded,
                    color: Colors.white,
                    iconColor: AppColors.brandRed,
                    onTap: () => context.push(AppRoutes.qrDisplay),
                  ),
                  _ActionCard(
                    title: 'Redeem Perks',
                    subtitle: 'Spend context balances',
                    icon: Icons.card_giftcard_rounded,
                    color: Colors.white,
                    iconColor: Colors.amber.shade700,
                    onTap: () => context.push(AppRoutes.redeem),
                  ),
                  _ActionCard(
                    title: 'Physical Card',
                    subtitle: 'Link membership plastics',
                    icon: Icons.credit_card_rounded,
                    color: Colors.white,
                    iconColor: Colors.blue.shade700,
                    onTap: () => context.push(AppRoutes.linkPhysicalCard),
                  ),
                  _ActionCard(
                    title: 'Statement Logs',
                    subtitle: 'Audit transaction delta',
                    icon: Icons.receipt_long_rounded,
                    color: Colors.white,
                    iconColor: Colors.teal.shade700,
                    onTap: () => context.push(AppRoutes.transactionHistory),
                  ),
                ],
              ),
            ),
          ),

          // ── Transaction Ledger Activity Header ───────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'RECENT LEDGER ACTIVITY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Colors.black54,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push(AppRoutes.transactionHistory),
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandRed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Live Ledger Rows from strips_ledger table ────────────────────
          // stripsTransactionsProvider streams the most recent 50 entries.
          // We show the latest 3 here as a preview.
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: txAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No transactions yet.\nStart earning Strips at TigerBay!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade400,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  );
                }

                // Show at most the 3 most recent entries as a preview.
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
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.brandRed,
                      ),
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
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

// ── Card Loading Skeleton ────────────────────────────────────────────────────
/// Shown while the profile stream is initialising. Matches the card dimensions
/// exactly so there is no layout shift when data arrives.
class _CardSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A1A), Color(0xFF3A0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: Colors.white38,
          ),
        ),
      ),
    );
  }
}





// ── Action Navigation Node Card ──────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                  fontSize: 10, color: Colors.grey.shade500, height: 1.2),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Transaction Statement Audit Component Item ───────────────────────────────

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

  // Precise brand colors per spec
  static const Color _creditGreen = Color(0xFF2E7D32);
  static const Color _debitRed    = Color(0xFFD31212);

  @override
  Widget build(BuildContext context) {
    final Color statusColor = isPositive ? _creditGreen : _debitRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          // Dynamic Circle Badge (+ or -)
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive ? Icons.add_rounded : Icons.remove_rounded,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  date,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          // Dynamic prefix: +100 Strips or -5 Strips
          Text(
            points,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}
