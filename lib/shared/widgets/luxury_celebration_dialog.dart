import 'dart:math' as math;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import 'apple_touch_feedback.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Luxury Celebration Dialog (Tier-1 Benchmark)
/// ═══════════════════════════════════════════════════════════════════════════
/// Displays an Apple / Soho House style celebratory modal with physics-driven
/// golden confetti particle bursts, tactile haptics, and glowing VIP badges.
class LuxuryCelebrationDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final String? badgeText;
  final String primaryButtonText;
  final VoidCallback onPrimaryPressed;
  final IconData icon;
  final List<String> benefits;

  const LuxuryCelebrationDialog({
    super.key,
    required this.title,
    required this.subtitle,
    this.badgeText,
    required this.primaryButtonText,
    required this.onPrimaryPressed,
    this.icon = Icons.stars_rounded,
    this.benefits = const [],
  });

  /// Static helper to trigger the celebration modal from anywhere
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String subtitle,
    String? badgeText,
    required String primaryButtonText,
    required VoidCallback onPrimaryPressed,
    IconData icon = Icons.stars_rounded,
    List<String> benefits = const [],
  }) {
    HapticFeedback.mediumImpact();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (_) => LuxuryCelebrationDialog(
        title: title,
        subtitle: subtitle,
        badgeText: badgeText,
        primaryButtonText: primaryButtonText,
        onPrimaryPressed: onPrimaryPressed,
        icon: icon,
        benefits: benefits,
      ),
    );
  }

  @override
  State<LuxuryCelebrationDialog> createState() =>
      _LuxuryCelebrationDialogState();
}

class _LuxuryCelebrationDialogState extends State<LuxuryCelebrationDialog>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  final List<_ConfettiParticle> _particles = [];

  @override
  void initState() {
    super.initState();

    // Secondary heavy haptic bump
    Future.delayed(const Duration(milliseconds: 150), () {
      HapticFeedback.heavyImpact();
    });

    // ── Generate Golden Confetti Particles ──────────────────────────────────
    final rand = math.Random();
    for (int i = 0; i < 48; i++) {
      _particles.add(
        _ConfettiParticle(
          x: rand.nextDouble(),
          y: rand.nextDouble() * 0.3,
          speed: 0.4 + rand.nextDouble() * 0.8,
          size: 4 + rand.nextDouble() * 7,
          rotation: rand.nextDouble() * 2 * math.pi,
          rotationSpeed: (rand.nextDouble() - 0.5) * 8,
          color: i % 3 == 0
              ? const Color(0xFFE5C07B) // Champagne Gold
              : (i % 3 == 1
                  ? const Color(0xFFD4AF37) // Pure Gold
                  : const Color(0xFFFFFFFF)), // Sparkle White
          isStar: i % 4 == 0,
        ),
      );
    }

    // ── Confetti Loop ───────────────────────────────────────────────────────
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..forward();

    // ── Scale & Bounce In ───────────────────────────────────────────────────
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeIn,
    );

    _scaleController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── Falling Gold Particles ──────────────────────────────────────────
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _confettiController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ConfettiPainter(
                    particles: _particles,
                    progress: _confettiController.value,
                  ),
                );
              },
            ),
          ),
        ),

        // ── Main Dialog Content ─────────────────────────────────────────────
        Center(
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E1E24), Color(0xFF121215)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.22),
                      blurRadius: 36,
                      spreadRadius: -4,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 30,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Glowing Golden Icon Badge ─────────────────────────
                      Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE5C07B), Color(0xFFC9A84C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.45),
                              blurRadius: 22,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            widget.icon,
                            size: 42,
                            color: const Color(0xFF141418),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Optional Badge Pill ───────────────────────────────
                      if (widget.badgeText != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            widget.badgeText!.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: AppColors.champagneGold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── Celebration Title ─────────────────────────────────
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Subtitle ──────────────────────────────────────────
                      Text(
                        widget.subtitle,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),

                      // ── Unlocked Benefits List ────────────────────────────
                      if (widget.benefits.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF141418),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: widget.benefits.map((b) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    const Icon(
                                      CupertinoIcons.checkmark_seal_fill,
                                      size: 15,
                                      color: AppColors.gold,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        b,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12.5,
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // ── Primary Action Button ─────────────────────────────
                      AppleTouchFeedback(
                        onTap: widget.onPrimaryPressed,
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE5C07B), Color(0xFFC9A84C)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            widget.primaryButtonText,
                            style: GoogleFonts.poppins(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF141418),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Confetti Particle Model & Painter ────────────────────────────────────────

class _ConfettiParticle {
  double x;
  double y;
  double speed;
  double size;
  double rotation;
  double rotationSpeed;
  Color color;
  bool isStar;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
    required this.color,
    required this.isStar,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final currentY = (p.y + progress * p.speed) % 1.1 * size.height;
      final currentX = p.x * size.width + math.sin(progress * 6 + p.x * 10) * 18;
      final currentRot = p.rotation + progress * p.rotationSpeed;

      final paint = Paint()
        ..color = p.color.withValues(alpha: (1.0 - (currentY / size.height) * 0.8).clamp(0.0, 1.0))
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(currentRot);

      if (p.isStar) {
        // Draw 4-point star sparkle
        final path = Path();
        final s = p.size;
        path.moveTo(0, -s);
        path.quadraticBezierTo(0, 0, s, 0);
        path.quadraticBezierTo(0, 0, 0, s);
        path.quadraticBezierTo(0, 0, -s, 0);
        path.quadraticBezierTo(0, 0, 0, -s);
        path.close();
        canvas.drawPath(path, paint);
      } else {
        // Draw confetti rectangle
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: p.size,
          height: p.size * 0.55,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(1.5)), paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
