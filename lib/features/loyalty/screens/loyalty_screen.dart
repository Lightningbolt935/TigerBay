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
import 'tier_benefits_sheet.dart';

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

          // ── VIP Tier Progression & Roadmap Tracker ────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: profileStream.when(
                data: (profile) {
                  final balance = profile?.stripsBalance ?? 0;
                  final currentTierId = profile?.membershipTierId ?? 1;
                  return _buildTierProgressCard(
                    context,
                    balance: balance,
                    tierId: currentTierId,
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) {
                  final fallback = ref.read(userProfileProvider);
                  return _buildTierProgressCard(
                    context,
                    balance: fallback?.stripsBalance ?? 0,
                    tierId: fallback?.membershipTierId ?? 1,
                  );
                },
              ),
            ),
          ),

          // ── Luxury 4-Action Quick Dock ────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  // 1. Digital Pass (High-res QR)
                  Expanded(
                    child: _buildActionTile(
                      context,
                      icon: CupertinoIcons.qrcode_viewfinder,
                      label: 'Pass / QR',
                      sublabel: 'Present',
                      accentColor: AppColors.gold,
                      onTap: () => context.push(AppRoutes.qrDisplay),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 2. Reward Store (Redeem Strips for Shisha & Food)
                  Expanded(
                    child: _buildActionTile(
                      context,
                      icon: CupertinoIcons.gift_fill,
                      label: 'Rewards',
                      sublabel: 'Store',
                      accentColor: const Color(0xFFF09A37),
                      onTap: () => context.push(AppRoutes.rewardStore),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 3. Tier Benefits (Interactive Vault — NOT the paywall!)
                  Expanded(
                    child: _buildActionTile(
                      context,
                      icon: CupertinoIcons.sparkles,
                      label: 'Privileges',
                      sublabel: 'VIP Tiers',
                      accentColor: const Color(0xFF88A0BF),
                      onTap: () {
                        final currentTierId =
                            ref.read(userProfileProvider)?.membershipTierId ?? 1;
                        TierBenefitsSheet.show(
                          context,
                          initialTierId: currentTierId,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 4. Physical Card (NFC Link)
                  Expanded(
                    child: _buildActionTile(
                      context,
                      icon: CupertinoIcons.creditcard,
                      label: 'Card NFC',
                      sublabel: 'Physical',
                      accentColor: const Color(0xFF8E8E93),
                      onTap: () => context.push(AppRoutes.linkPhysicalCard),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Strips Balance & Valuation Card ───────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: profileStream.when(
                data: (profile) {
                  final balance = profile?.stripsBalance ?? 0;
                  final tierId = profile?.membershipTierId ?? 1;
                  final multiplier = tierId == 4
                      ? '3 pts / £1'
                      : tierId == 3
                          ? '2 pts / £1'
                          : tierId == 2
                              ? '1 pt / £1'
                              : '0.5 pts / £1';

                  // £0.05 estimated lounge credit per strip
                  final double cashValue = balance * 0.05;

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF181820), Color(0xFF121217)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF2C2C3A),
                        width: 0.9,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AVAILABLE BALANCE',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.2,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      balance.toString(),
                                      style: GoogleFonts.poppins(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.gold,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'STRIPS',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.0,
                                        color: AppColors.champagneGold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '≈ £${cashValue.toStringAsFixed(2)} Dining & Shisha Value',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.gold.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    multiplier,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.gold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                AppleTouchFeedback(
                                  onTap: () => context.push(AppRoutes.rewardStore),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF22222E),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF38384C),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Spend Points',
                                          style: GoogleFonts.poppins(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(
                                          CupertinoIcons.chevron_right,
                                          size: 11,
                                          color: Colors.white70,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),

          // ── Active VIP Privileges & Vouchers Carousel ─────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'ACTIVE PRIVILEGES & PASSES',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '4 READY',
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  AppleTouchFeedback(
                    onTap: () {
                      final currentTierId =
                          ref.read(userProfileProvider)?.membershipTierId ?? 1;
                      TierBenefitsSheet.show(
                        context,
                        initialTierId: currentTierId,
                      );
                    },
                    child: Text(
                      'All Perks',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Horizontal Voucher Cards
          SliverToBoxAdapter(
            child: SizedBox(
              height: 148,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildVoucherCard(
                    context,
                    title: 'Birthday VIP Gift',
                    subtitle: 'Champagne or Shisha bottle',
                    tag: 'ANNUAL REWARD',
                    icon: Icons.cake_rounded,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3B1F20), Color(0xFF1E1012)],
                    ),
                    borderColor: const Color(0xFF6B2B2F),
                    code: 'TB-BDAY-VIP',
                  ),
                  _buildVoucherCard(
                    context,
                    title: 'Dining Privilege',
                    subtitle: '20% - 30% off all dining',
                    tag: 'MEMBERS PERK',
                    icon: CupertinoIcons.tag_fill,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2C2513), Color(0xFF141108)],
                    ),
                    borderColor: const Color(0xFF6E5624),
                    code: 'TB-DINE-20',
                  ),
                  _buildVoucherCard(
                    context,
                    title: 'Shisha Head Upgrade',
                    subtitle: 'Complimentary fruit head',
                    tag: 'LOUNGE PASS',
                    icon: CupertinoIcons.flame_fill,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1D2836), Color(0xFF0F151F)],
                    ),
                    borderColor: const Color(0xFF384F6B),
                    code: 'TB-HOOKAH-UP',
                  ),
                  _buildVoucherCard(
                    context,
                    title: 'Double Strips Pass',
                    subtitle: '2x points on weekend tables',
                    tag: 'BOOST PASS',
                    icon: CupertinoIcons.bolt_fill,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF281C38), Color(0xFF130D1B)],
                    ),
                    borderColor: const Color(0xFF5B3982),
                    code: 'TB-2X-BOOST',
                  ),
                ],
              ),
            ),
          ),

          // ── Ways to Earn Strips Section ───────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                'WAYS TO EARN STRIPS',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF141418),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: const Color(0xFF242430),
                    width: 0.8,
                  ),
                ),
                child: Column(
                  children: [
                    _buildEarnWayRow(
                      icon: CupertinoIcons.cart_fill,
                      title: 'Spend at Lounges',
                      description: 'Scan pass with server to earn up to 3 Strips / £1',
                      badge: 'UP TO 3X',
                    ),
                    const Divider(color: Color(0xFF22222C), height: 16),
                    _buildEarnWayRow(
                      icon: CupertinoIcons.calendar_today,
                      title: 'Table Bookings',
                      description: 'Bonus Strips credited automatically on confirmed visits',
                      badge: '+POINTS',
                    ),
                    const Divider(color: Color(0xFF22222C), height: 16),
                    _buildEarnWayRow(
                      icon: CupertinoIcons.sparkles,
                      title: '10-Visit Streak',
                      description: 'Milestone bonus up to 2,000 Strips every 10 lounge visits',
                      badge: '+2,000',
                    ),
                  ],
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

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _buildTierProgressCard(
    BuildContext context, {
    required int balance,
    required int tierId,
  }) {
    String currentTier = 'Explorer';
    String nextTier = 'Gold VIP';
    int targetPoints = 500;
    int nextTierId = 2;

    if (tierId >= 4) {
      currentTier = 'Black Society';
      nextTier = 'Highest Tier';
      targetPoints = balance;
      nextTierId = 4;
    } else if (tierId == 3) {
      currentTier = 'Platinum';
      nextTier = 'Black Society';
      targetPoints = 3000;
      nextTierId = 4;
    } else if (tierId == 2) {
      currentTier = 'Gold';
      nextTier = 'Platinum';
      targetPoints = 1500;
      nextTierId = 3;
    } else {
      currentTier = 'Explorer';
      nextTier = 'Gold';
      targetPoints = 500;
      nextTierId = 2;
    }

    final double progress = (targetPoints > 0)
        ? (balance / targetPoints).clamp(0.0, 1.0)
        : 1.0;
    final int pointsRemaining = (targetPoints - balance).clamp(0, 99999);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131317),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF252530), width: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      currentTier.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    CupertinoIcons.arrow_right,
                    size: 11,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    nextTier,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              AppleTouchFeedback(
                onTap: () => TierBenefitsSheet.show(
                  context,
                  initialTierId: nextTierId,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Roadmap',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      CupertinoIcons.chevron_right,
                      size: 11,
                      color: AppColors.gold,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Animated Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: const Color(0xFF22222E),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$balance / $targetPoints Strips',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                tierId >= 4
                    ? 'Maximum Status Achieved'
                    : '$pointsRemaining points to $nextTier',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String sublabel,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return AppleTouchFeedback(
      onTap: onTap,
      child: Container(
        height: 82,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF15151A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF262634), width: 0.8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 16),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              sublabel,
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w400,
                color: AppColors.textHint,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoucherCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String tag,
    required IconData icon,
    required LinearGradient gradient,
    required Color borderColor,
    required String code,
  }) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.poppins(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.gold,
                  ),
                ),
              ),
              Icon(icon, color: AppColors.gold, size: 16),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white70,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          AppleTouchFeedback(
            onTap: () => _showVoucherDialog(context, title, subtitle, code),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  'Present Voucher',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarnWayRow({
    required IconData icon,
    required String title,
    required String description,
    required String badge,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.gold, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF22222E),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              badge,
              style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showVoucherDialog(
    BuildContext context,
    String title,
    String subtitle,
    String code,
  ) {
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
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.sparkles,
                  color: AppColors.gold,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E26),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'REDEMPTION PASS CODE',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textHint,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      code,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.0,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Show this code to your waiter when settling your lounge bill.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textHint,
                ),
              ),
              const SizedBox(height: 20),
              AppleTouchFeedback(
                onTap: () => Navigator.of(dialogCtx).pop(),
                child: Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'Done',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F0F12),
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
