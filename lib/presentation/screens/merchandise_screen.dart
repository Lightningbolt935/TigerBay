import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/data/models/merchandise_item.dart';
import 'package:tigerbay_app/features/auth/providers/profile_state_provider.dart';
import 'package:tigerbay_app/logic/providers/merchandise_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TigerBay International — Merchandise Marketplace Screen
// ═══════════════════════════════════════════════════════════════════════════
// Premium dark-luxury merchandise grid. Members browse TigerBay branded
// items and redeem them with Strips Tokens or cash. The REDEEM action
// is reactively locked when the member's strips balance is insufficient,
// preventing invalid redemption attempts without a round-trip to the server.
// ═══════════════════════════════════════════════════════════════════════════

/// Root screen for the Merchandise Marketplace feature.
class MerchandiseScreen extends ConsumerWidget {
  const MerchandiseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(merchandiseProvider);
    final stripsBalance = ref.watch(stripsBalanceProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Sliver App Bar ─────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 110,
            backgroundColor: const Color(0xFF0D0D0D),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0.5),
              child: Container(
                height: 0.5,
                color: AppColors.gold.withValues(alpha: 0.25),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TIGERBAY MERCHANDISE',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Redeem with Strips or cash',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w400,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A1300), Color(0xFF0D0D0D)],
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 52, right: 20),
                    child: _BalanceBadge(balance: stripsBalance),
                  ),
                ),
              ),
            ),
          ),

          // ── Section Header ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'EXCLUSIVE COLLECTION',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${items.length} items',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Merchandise Grid ────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.68,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _MerchandiseCard(
                  item: items[index],
                  userBalance: stripsBalance,
                ),
                childCount: items.length,
              ),
            ),
          ),

          // ── Footer note ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24, left: 20, right: 20),
              child: Text(
                'Collect Strips at every visit to unlock exclusive merchandise.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: AppColors.textHint,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Balance Badge — pinned to the app bar flex background
// ─────────────────────────────────────────────────────────────────────────────

class _BalanceBadge extends StatelessWidget {
  final int balance;
  const _BalanceBadge({required this.balance});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.gold, width: 1),
        borderRadius: BorderRadius.circular(20),
        color: AppColors.gold.withValues(alpha: 0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.toll_rounded, size: 14, color: AppColors.gold),
          const SizedBox(width: 5),
          Text(
            '$balance',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'STRIPS',
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Merchandise Card — individual grid tile
// ─────────────────────────────────────────────────────────────────────────────

class _MerchandiseCard extends StatelessWidget {
  final MerchandiseItem item;
  final int userBalance;

  const _MerchandiseCard({
    required this.item,
    required this.userBalance,
  });

  bool get _canAfford => userBalance >= item.requiredStrips;
  bool get _isLocked => !_canAfford || !item.isAvailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image Section ─────────────────────────────────────────────
          _ProductImageBlock(imageUrl: item.imageUrl, isLocked: _isLocked),

          // ── Body Section ──────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    item.name,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Description
                  Expanded(
                    child: Text(
                      item.description,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Bottom Action Row ───────────────────────────────
                  _ActionRow(item: item, isLocked: _isLocked),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Product Image Block — top section of the card
// ─────────────────────────────────────────────────────────────────────────────

class _ProductImageBlock extends StatelessWidget {
  final String imageUrl;
  final bool isLocked;

  const _ProductImageBlock({required this.imageUrl, required this.isLocked});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Asset image with dark fallback
          Image.asset(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: const Color(0xFF111111),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_bag_outlined,
                    size: 36,
                    color: AppColors.gold.withValues(alpha: 0.35),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'TIGERBAY',
                    style: GoogleFonts.poppins(
                      fontSize: 8,
                      letterSpacing: 2,
                      color: AppColors.textHint,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Locked overlay
          if (isLocked)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: const Center(
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 28,
                  color: AppColors.textHint,
                ),
              ),
            ),

          // Subtle gold shimmer gradient at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 40,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xFF1A1A1A), Colors.transparent],
                ),
              ),
            ),
          ),

          // Availability badge
          if (!isLocked)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'IN STOCK',
                  style: GoogleFonts.poppins(
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1A00),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Row — strips cost badge + redeem button
// ─────────────────────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final MerchandiseItem item;
  final bool isLocked;

  const _ActionRow({required this.item, required this.isLocked});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Strips cost badge
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.toll_rounded,
                    size: 11,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${item.requiredStrips} S',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                ],
              ),
              Text(
                '\$${item.price.toStringAsFixed(2)}',
                style: GoogleFonts.poppins(
                  fontSize: 9,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 6),

        // Redeem / Locked button
        _RedeemButton(item: item, isLocked: isLocked),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Redeem Button — active or locked state
// ─────────────────────────────────────────────────────────────────────────────

class _RedeemButton extends StatelessWidget {
  final MerchandiseItem item;
  final bool isLocked;

  const _RedeemButton({required this.item, required this.isLocked});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLocked ? null : () => _handleRedeem(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isLocked
              ? AppColors.surfaceLight.withValues(alpha: 0.55)
              : AppColors.gold,
          borderRadius: BorderRadius.circular(10),
          border: isLocked
              ? Border.all(
                  color: AppColors.border.withValues(alpha: 0.4),
                  width: 0.8,
                )
              : null,
          boxShadow: isLocked
              ? null
              : [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLocked ? Icons.lock_outline_rounded : Icons.redeem_rounded,
              size: 10,
              color: isLocked ? AppColors.textHint : const Color(0xFF1A1200),
            ),
            const SizedBox(width: 4),
            Text(
              isLocked ? 'Locked' : 'Redeem',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: isLocked
                    ? AppColors.textHint.withValues(alpha: 0.7)
                    : const Color(0xFF1A1200),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleRedeem(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RedeemSheet(item: item),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Redeem Confirmation Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _RedeemSheet extends StatelessWidget {
  final MerchandiseItem item;
  const _RedeemSheet({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              color: AppColors.gold,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'CONFIRM REDEMPTION',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.name,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.gold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Cost breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _CostColumn(
                  label: 'STRIPS COST',
                  value: '${item.requiredStrips} S',
                  valueColor: AppColors.gold,
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: AppColors.border,
                ),
                _CostColumn(
                  label: 'CASH VALUE',
                  value: '\$${item.price.toStringAsFixed(2)}',
                  valueColor: AppColors.textPrimary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Confirm CTA
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Request submitted — our team will contact you shortly.',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: const Color(0xFF1A1200),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: Text(
                'CONFIRM REDEEM',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: const Color(0xFF1A1200),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Cancel
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cost Column — used inside the confirmation sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CostColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _CostColumn({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.textHint,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
