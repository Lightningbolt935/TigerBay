import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';

/// Ultra-premium luxury splash screen for TigerBay International.
/// Features atmospheric ambient radial glow, an elastic breathing emblem,
/// and smooth cinematic staggered typography.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _pulseController;

  late Animation<double> _bgGlowAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<Offset> _textSlideAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _progressFadeAnimation;

  @override
  void initState() {
    super.initState();

    // ── Main Entrance Timeline (1200ms) ──────────────────────────────────────
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // ── Ambient Breathing Pulse (repeating 3000ms) ───────────────────────────
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // Ambient radial glow expansion
    _bgGlowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    // Emblem elastic scale-in
    _logoScaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.1, 0.65, curve: Curves.easeOutBack),
      ),
    );

    // Emblem fade-in
    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.05, 0.45, curve: Curves.easeOut),
      ),
    );

    // Typography slide-up
    _textSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.4, 0.8, curve: Curves.easeOut),
      ),
    );

    _progressFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    _entranceController.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    // 2.3 seconds display time for a cinematic luxury feel
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08080A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Ambient Background Lighting ──────────────────────────────────
          AnimatedBuilder(
            animation: Listenable.merge([_bgGlowAnimation, _pulseController]),
            builder: (context, _) {
              final pulse = 0.85 + (_pulseController.value * 0.15);
              final glowAlpha = _bgGlowAnimation.value * pulse;

              return Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0, -0.15),
                      radius: 0.9,
                      colors: [
                        AppColors.brandRed.withValues(alpha: 0.22 * glowAlpha),
                        AppColors.gold.withValues(alpha: 0.08 * glowAlpha),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),

          // ── Center Content ───────────────────────────────────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Animated Emblem with Breathing Halo ────────────────────
                FadeTransition(
                  opacity: _logoFadeAnimation,
                  child: ScaleTransition(
                    scale: _logoScaleAnimation,
                    child: AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final haloSpread = 16.0 + (_pulseController.value * 12.0);
                        final haloAlpha = 0.25 + (_pulseController.value * 0.15);

                        return Container(
                          width: 124,
                          height: 124,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF221A1A), Color(0xFF100E0E)],
                            ),
                            border: Border.all(
                              color: AppColors.gold.withValues(
                                alpha: 0.35 + (_pulseController.value * 0.25),
                              ),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brandRed.withValues(alpha: haloAlpha),
                                blurRadius: haloSpread,
                                spreadRadius: 2,
                                offset: const Offset(0, 6),
                              ),
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: haloAlpha * 0.5),
                                blurRadius: haloSpread * 1.5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(28),
                            child: Image.asset(
                              'assets/images/tigerbay_logo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.pets,
                                size: 52,
                                color: AppColors.brandRed,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Staggered Typography ───────────────────────────────────
                SlideTransition(
                  position: _textSlideAnimation,
                  child: FadeTransition(
                    opacity: _textFadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          'TigerBay',
                          style: GoogleFonts.cinzel(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 4.5,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: AppColors.brandRed.withValues(alpha: 0.6),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'INTERNATIONAL',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 5.5,
                            color: AppColors.champagneGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Luxury Indicator ──────────────────────────────────────
          Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _progressFadeAnimation,
              child: Center(
                child: SizedBox(
                  width: 44,
                  height: 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.champagneGold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
