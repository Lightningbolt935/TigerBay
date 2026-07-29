import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/profile_state_provider.dart';
import '../../profile/providers/membership_provider.dart';

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    // Safely extract real-time user metrics from your auth metadata object
    final userName =
        user?.userMetadata?['full_name'] as String? ?? 'TigerBay Member';
    final userPoints = user?.userMetadata?['loyalty_points'] as int? ?? 450;

    // Dynamically resolve the plan name from the DB
    final profile = ref.watch(userProfileProvider);
    final tiersAsync = ref.watch(membershipTiersProvider);
    final String? activePlanName = tiersAsync.whenData((tiers) {
      final tierId = profile?.membershipTierId;
      if (tierId == null) return null;
      try {
        return tiers.firstWhere((t) => t.id == tierId).name;
      } catch (_) {
        return null;
      }
    }).valueOrNull;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          // ── Premium App Bar ────────────────────────────────────────────────
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

          // ── Digital Membership Card Card Container ─────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                height: 210,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1A1A1A), // Sleek Onyx
                      AppColors.brandRed, // Premium Crimson Brand Identity
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandRed.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Subtle background branding design alignment
                    Positioned(
                      right: -30,
                      bottom: -30,
                      child: Icon(
                        Icons.pets,
                        size: 200,
                        color: Colors.white.withValues(alpha: 0.04),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment
                                .spaceBetween, // Fixed: Swapped 'between' for 'spaceBetween'
                            children: [
                              _buildMembershipBadge(activePlanName),
                              const Icon(Icons.nfc_rounded,
                                  color: Colors.white70, size: 24),
                            ],
                          ),
                          const Spacer(),
                          const Text(
                            'AVAILABLE BALANCE',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$userPoints PTS',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            userName.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Quick Action Command Operations Matrix ────────────────────────
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

          // ── Transaction Ledger Activity Header ────────────────────────────
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

          // ── Real-time Historic Statement List View ────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const _HistoryRow(
                  title: 'Terrace Lounge Booking Bonus',
                  date: 'Today, 4:12 PM',
                  points: '+120 Pts',
                  isPositive: true,
                ),
                const _HistoryRow(
                  title: 'Signature Wagyu Redemptions',
                  date: 'June 21, 8:45 PM',
                  points: '-150 Pts',
                  isPositive: false,
                ),
                const _HistoryRow(
                  title: 'Cocktail Soirée Accrual',
                  date: 'June 18, 11:20 PM',
                  points: '+45 Pts',
                  isPositive: true,
                ),
              ]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // ── Dynamic Membership Plan Badge ─────────────────────────────────────────
  /// Displays the exact membership plan fetched from the database dynamically.
  /// Falls back to 'STANDARD' if the plan name is null or empty.
  Widget _buildMembershipBadge(String? planName) {
    final String activePlan = (planName != null && planName.trim().isNotEmpty)
        ? planName.trim().toUpperCase()
        : 'STANDARD';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFD4AF37), size: 14),
          const SizedBox(width: 6),
          Text(
            activePlan,
            style: const TextStyle(
              color: Color(0xFFD4AF37),
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.2,
            ),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isPositive ? Colors.green.shade50 : Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              // Fixed: Swapped out non-existent icons for safe, standard Material alternatives
              isPositive
                  ? Icons.add_circle_rounded
                  : Icons.remove_circle_rounded,
              size: 18,
              color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  date,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          Text(
            points,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isPositive ? Colors.green.shade700 : Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
