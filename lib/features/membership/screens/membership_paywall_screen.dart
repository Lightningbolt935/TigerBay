import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/constants/app_routes.dart';
import 'package:tigerbay_app/core/services/stripe_service.dart';
import 'package:tigerbay_app/data/models/membership_tier_model.dart';
import 'package:tigerbay_app/features/auth/providers/auth_provider.dart';
import 'package:tigerbay_app/features/auth/providers/profile_state_provider.dart';
import 'package:tigerbay_app/features/profile/providers/membership_provider.dart';
import 'package:tigerbay_app/shared/widgets/apple_touch_feedback.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Membership Paywall Screen
/// ═══════════════════════════════════════════════════════════════════════════
/// Hard gate for inactive users. Displays 5 premium tier cards with pricing,
/// Strips earning rate, benefits list, and payment method selection. User
/// cannot navigate elsewhere until membership is activated.
class MembershipPaywallScreen extends ConsumerStatefulWidget {
  const MembershipPaywallScreen({super.key});

  @override
  ConsumerState<MembershipPaywallScreen> createState() =>
      _MembershipPaywallScreenState();
}

class _MembershipPaywallScreenState
    extends ConsumerState<MembershipPaywallScreen> {
  final PageController _pageController =
      PageController(viewportFraction: 0.85);
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    HapticFeedback.lightImpact();
    final profile = ref.read(profileStateProvider).profile;
    if (profile?.isMembershipActive == true) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.home);
      }
    } else {
      await ref.read(authProvider.notifier).signOut();
      if (mounted) context.go(AppRoutes.login);
    }
  }

  Future<void> _activateMembership(MembershipTier tier) async {
    final activator = ref.read(membershipActivationNotifierProvider.notifier);
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;

    // ── Step 1: Collect payment via Stripe ────────────────────────────────
    final paymentResult = await StripeService.presentMembershipPayment(
      context: context,
      tierName: tier.name,
      amountGbp: tier.price,
      tierId: tier.id.toString(),
      userId: userId,
    );

    if (!mounted) return;

    // User cancelled — soft message, no activation.
    if (paymentResult.cancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment cancelled. No charge was made.',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: AppColors.textSecondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Payment failed — surface the error and allow retry.
    if (!paymentResult.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            paymentResult.error ?? 'Payment failed. Please try again.',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // ── Step 2: Payment confirmed — activate membership in Supabase ────────
    final success = await activator.activateMembership(tier);

    if (!mounted) return;

    if (success) {
      // ── Step 3: Record Stripe payment ID for audit trail ──────────────────
      if (paymentResult.paymentIntentId != null &&
          paymentResult.paymentIntentId!.isNotEmpty) {
        try {
          final supabase = ref.read(supabaseClientProvider);
          if (userId != null) {
            await supabase.from('profiles').update({
              'paypal_order_id': paymentResult.paymentIntentId,
              'updated_at': DateTime.now().toIso8601String(),
            }).eq('id', userId);
          }
        } catch (e) {
          debugPrint('[MembershipPaywall] stripe payment intent record failed: $e');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tier.name} membership activated!',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
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
      // Auto return home after brief delay
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) {
        context.go(AppRoutes.home);
      }
    } else {
      final error = ref.read(membershipActivationNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error ?? 'Could not activate membership. Please try again.',
            style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiersAsync = ref.watch(membershipTiersProvider);
    final activationState = ref.watch(membershipActivationNotifierProvider);
    final profile = ref.watch(profileStateProvider).profile;
    final isActive = profile?.membershipStatus == 'active';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.brandBlack,
        body: SafeArea(
          child: tiersAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 2,
            ),
          ),
          error: (err, __) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'Could not load membership tiers',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$err',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () =>
                        ref.invalidate(membershipTiersProvider),
                    child: Text(
                      'Retry',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          data: (tiers) {
            if (tiers.isEmpty) {
              return Center(
                child: Text(
                  'No membership tiers available',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }

            final safeIndex = _currentPage.clamp(0, tiers.length - 1);
            final selectedTier = tiers[safeIndex];

            MembershipTier? currentTier;
            if (isActive) {
              for (final t in tiers) {
                if (t.id == profile?.membershipTierId) {
                  currentTier = t;
                  break;
                }
              }
            }

            final bool isCurrentSelected =
                selectedTier.id == currentTier?.id;
            // Downgrade guard: user cannot switch to a lower tier level.
            final bool isDowngrade = isActive &&
                currentTier != null &&
                !isCurrentSelected &&
                selectedTier.tierLevel < currentTier.tierLevel;

            final String ctaLabel = isCurrentSelected
                ? 'RENEW ${selectedTier.name.toUpperCase()}'
                : isDowngrade
                    ? 'CANNOT DOWNGRADE PLAN'
                    : isActive
                        ? 'UPGRADE TO ${selectedTier.name.toUpperCase()}'
                        : 'ACTIVATE ${selectedTier.name.toUpperCase()}';

            return Column(
              children: [
                const SizedBox(height: 16),

                // ── Brand Header ─────────────────────────────────────────
                _buildBrandHeader(),

                if (isActive && currentTier != null) ...[
                  const SizedBox(height: 16),
                  _buildCurrentPlanBanner(currentTier, profile),
                ],

                const SizedBox(height: 24),

                // ── Title ────────────────────────────────────────────────
                Text(
                  isActive ? 'MANAGE YOUR MEMBERSHIP' : 'CHOOSE YOUR MEMBERSHIP',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isActive
                      ? 'Renew your current plan or upgrade to a higher tier'
                      : 'Unlock exclusive rewards across every TigerBay venue',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Swipeable Tier Cards ─────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: tiers.length,
                    onPageChanged: (i) {
                      HapticFeedback.selectionClick();
                      setState(() => _currentPage = i);
                    },
                    itemBuilder: (_, index) {
                      final isSelected = index == safeIndex;
                      return _TierCard(
                        tier: tiers[index],
                        isSelected: isSelected,
                        isCurrentTier: tiers[index].id == currentTier?.id,
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // ── Page Dots ────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(tiers.length, (index) {
                    final isActive = index == safeIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.gold
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 24),

                // ── CTA Button ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: activationState.isProcessing || isDowngrade
                          ? null
                          : () => _activateMembership(selectedTier),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDowngrade ? AppColors.surfaceLight : AppColors.gold,
                        disabledBackgroundColor: isDowngrade
                            ? AppColors.surfaceLight
                            : AppColors.gold.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: activationState.isProcessing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (isDowngrade) ...[
                                  const Icon(Icons.lock_outline_rounded,
                                      size: 16, color: AppColors.textHint),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  ctaLabel,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isDowngrade
                                        ? AppColors.textHint
                                        : Colors.white,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    ),
  );
}

  Widget _buildBrandHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // ── Visible Luxury Back Button ────────────────────────────────────
          AppleTouchFeedback(
            onTap: _handleBack,
            child: Container(
              key: const ValueKey('paywall_back_button'),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AppColors.brandBlack,
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandRed.withValues(alpha: 0.2),
                  blurRadius: 16,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/tigerbay_logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.local_fire_department_rounded,
                color: AppColors.brandRed,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TigerBay',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandRed,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'INTERNATIONAL',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
          const Spacer(),
          AppleTouchFeedback(
            onTap: () async {
              await ref.read(authProvider.notifier).signOut();
              if (mounted) context.go(AppRoutes.login);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.square_arrow_right,
                    color: AppColors.brandRed,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Sign Out',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPlanBanner(MembershipTier tier, dynamic profile) {
    final expiresAt = profile?.membershipExpiresAt;
    final expiryText = expiresAt != null
        ? 'Renews ${DateTime.parse(expiresAt.toString()).toLocal().day} '
            '${_monthName(DateTime.parse(expiresAt.toString()).toLocal().month)}'
            ' ${DateTime.parse(expiresAt.toString()).toLocal().year}'
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: AppColors.goldGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium, color: Colors.black, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CURRENT PLAN — ${tier.name.toUpperCase()}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (expiryText != null)
                    Text(
                      expiryText,
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: Colors.black.withValues(alpha: 0.7),
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

  static String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}

// ── Tier Card Widget ──────────────────────────────────────────────────────

class _TierCard extends StatelessWidget {
  final MembershipTier tier;
  final bool isSelected;
  final bool isCurrentTier;

  const _TierCard({
    required this.tier,
    required this.isSelected,
    this.isCurrentTier = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.gold : AppColors.border,
          width: isSelected ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tier Name ────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  tier.name,
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
              ),
              if (isCurrentTier)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gold, width: 1),
                  ),
                  child: Text(
                    'CURRENT PLAN',
                    style: GoogleFonts.poppins(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // ── Price ────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                tier.formattedPrice,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/month',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // ── Strips Rate ──────────────────────────────────────────────
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.gold),
            ),
            child: Text(
              tier.stripsRateDescription,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.gold,
                letterSpacing: 0.8,
              ),
            ),
          ),

          const SizedBox(height: 16),
          Divider(color: AppColors.border.withValues(alpha: 0.5), height: 1),
          const SizedBox(height: 16),

          // ── Benefits List ────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: tier.benefits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, index) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tier.benefits[index],
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
