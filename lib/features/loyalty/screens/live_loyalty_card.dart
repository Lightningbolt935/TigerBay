import 'dart:math' as math;
import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — LiveLoyaltyCard Widget
/// ═══════════════════════════════════════════════════════════════════════════
/// A fully dynamic, animated loyalty card that accepts live data from
/// Supabase via Riverpod providers. Features a continuous diagonal gloss
/// sheen sweep using an AnimationController that repeats indefinitely.
///
/// All three displayed fields (tierName, balance, userName) are injected
/// as constructor parameters — zero hardcoded data inside this widget.
class LiveLoyaltyCard extends StatefulWidget {
  /// The membership tier name, e.g. "Silver", "Gold", "Platinum".
  final String tierName;

  /// The live Strips balance from public.profiles.strips_balance.
  final int balance;

  /// The member's full name from public.profiles.full_name.
  final String userName;

  const LiveLoyaltyCard({
    super.key,
    required this.tierName,
    required this.balance,
    required this.userName,
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
    // Continuous live sweep — gloss stripe travels left-to-right every 3 s.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: false);

    _shimmerAnimation = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 210,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC40C0C).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // ── 1. Base Dark-to-Red Luxury Gradient ──────────────────────
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF141212), // Sleek Onyx
                    Color(0xFF7A0000), // Deep Crimson
                    Color(0xFFC40C0C), // Premium Brand Red
                  ],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ),
              ),
            ),

            // ── 2. Paw Print Watermark / Brand Logo ───────────────────────
            Positioned(
              right: -30,
              bottom: -30,
              child: Icon(
                Icons.pets,
                size: 200,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),

            // ── 3. Animated Diagonal Gloss Sheen Stripe ───────────────────
            // FractionalTranslation moves the stripe from far-left to
            // far-right as _shimmerAnimation sweeps from -1.5 to 2.5.
            AnimatedBuilder(
              animation: _shimmerAnimation,
              builder: (context, child) {
                return FractionalTranslation(
                  translation: Offset(_shimmerAnimation.value, 0),
                  child: Transform.rotate(
                    angle: -math.pi / 5,
                    child: Container(
                      width: 80,
                      height: 400,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.0),
                            Colors.white.withValues(alpha: 0.18),
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

            // ── 4. Dynamic Data Overlay ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Dynamic Tier Badge + NFC Icon
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTierBadge(widget.tierName),
                      const Icon(
                        Icons.nfc_rounded,
                        color: Colors.white70,
                        size: 24,
                      ),
                    ],
                  ),

                  const Spacer(),

                  // Middle: Realtime Balance Points
                  const Text(
                    'AVAILABLE BALANCE',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.balance} PTS',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const Spacer(),

                  // Bottom: Live Member Name
                  Text(
                    widget.userName.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dynamic Tier Badge ──────────────────────────────────────────────────
  /// Renders the golden membership tier pill with a star icon.
  /// Falls back to 'STANDARD' if tierName is empty.
  Widget _buildTierBadge(String tierName) {
    final String displayTier =
        tierName.trim().isEmpty ? 'STANDARD' : tierName.trim().toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFD4AF37), size: 14),
          const SizedBox(width: 6),
          Text(
            displayTier,
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
