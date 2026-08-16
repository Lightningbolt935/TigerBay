import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/apple_touch_feedback.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — LiveLoyaltyCard (Apple Wallet Luxury Edition)
/// ═══════════════════════════════════════════════════════════════════════════
class LiveLoyaltyCard extends StatefulWidget {
  final String tierName;
  final int balance;
  final String userName;
  final VoidCallback? onTap;

  const LiveLoyaltyCard({
    super.key,
    required this.tierName,
    required this.balance,
    required this.userName,
    this.onTap,
  });

  @override
  State<LiveLoyaltyCard> createState() => _LiveLoyaltyCardState();
}

class _LiveLoyaltyCardState extends State<LiveLoyaltyCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.8, end: 2.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppleTouchFeedback(
      pressedScale: 0.97,
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        height: 215,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE2231A).withValues(alpha: 0.22),
              blurRadius: 28,
              spreadRadius: -4,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: -6,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // ── Base Gradient: Obsidian Luxury Crimson ───────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF141214),
                      Color(0xFF4A0A0A),
                      Color(0xFF9E100A),
                      Color(0xFFE2231A),
                    ],
                    stops: [0.0, 0.4, 0.8, 1.0],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  ),
                ),
              ),

              // ── Subtle Specular Grid Sheen ───────────────────────────
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.6, -0.6),
                      radius: 1.2,
                      colors: [
                        Colors.white.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // ── Brand Paw Watermark ───────────────────────────────────
              Positioned(
                right: -25,
                bottom: -25,
                child: Icon(
                  Icons.pets,
                  size: 210,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),

              // ── Diagonal Gloss Stripe Sweep ───────────────────────────
              AnimatedBuilder(
                animation: _shimmerAnimation,
                builder: (context, child) {
                  return FractionalTranslation(
                    translation: Offset(_shimmerAnimation.value, 0),
                    child: Transform.rotate(
                      angle: -math.pi / 5,
                      child: Container(
                        width: 90,
                        height: 440,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.0),
                              Colors.white.withValues(alpha: 0.15),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // ── Top Hairline Border Highlight ────────────────────────
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                ),
              ),

              // ── Dynamic Card Content ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(22.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Tier Badge + Apple contactless symbol
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTierBadge(widget.tierName),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 0.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.contactless_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Middle: Available Balance
                    Text(
                      'AVAILABLE BALANCE',
                      style: GoogleFonts.poppins(
                        color: Colors.white60,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${widget.balance}',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'STRIPS',
                          style: GoogleFonts.poppins(
                            color: AppColors.champagneGold,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Bottom: Live Member Name
                    Text(
                      widget.userName.toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.8,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierBadge(String tierName) {
    final String displayTier =
        tierName.trim().isEmpty ? 'STANDARD' : tierName.trim().toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.champagneGold.withValues(alpha: 0.6),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.stars_rounded,
              color: AppColors.champagneGold, size: 14),
          const SizedBox(width: 5),
          Text(
            displayTier,
            style: GoogleFonts.poppins(
              color: AppColors.champagneGold,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
