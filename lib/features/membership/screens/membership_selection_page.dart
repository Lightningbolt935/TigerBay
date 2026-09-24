import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/constants/app_routes.dart';
import 'package:tigerbay_app/core/services/stripe_service.dart';
import 'package:tigerbay_app/data/models/membership_tier_model.dart';
import 'package:tigerbay_app/features/auth/providers/profile_state_provider.dart';
import 'package:tigerbay_app/features/profile/providers/membership_provider.dart';

/// Post-registration paywall gate. Shown immediately after a new user
/// completes sign-up, before they reach venue selection or the main
/// dashboard. Renders N swipeable premium tier cards dynamically from
/// the `membership_tiers` Supabase table and activates the chosen tier
/// on the user's profile.
class MembershipSelectionPage extends ConsumerStatefulWidget {
  const MembershipSelectionPage({super.key});

  @override
  ConsumerState<MembershipSelectionPage> createState() =>
      _MembershipSelectionPageState();
}

class _MembershipSelectionPageState
    extends ConsumerState<MembershipSelectionPage> {
  final PageController _pageController = PageController(viewportFraction: 0.88);
  int _currentPage = 0;
  bool _isProcessing = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _activateMembership(MembershipTier tier) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final supabase = ref.read(supabaseClientProvider);
      final userId = supabase.auth.currentUser?.id;

      // ── Step 1: Collect payment via Stripe ──────────────────────────────
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
            content: const Text('Payment cancelled. No charge was made.'),
            backgroundColor: AppColors.textSecondary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      // Payment failed — surface the error and allow retry.
      if (!paymentResult.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                paymentResult.error ?? 'Payment failed. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        return;
      }

      // ── Step 2: Payment confirmed — activate membership in Supabase ──────
      // Activate via the provider layer so profileStateProvider is
      // refreshed and GoRouter's ref.listen fires automatically,
      // redirecting the user to /home without any manual navigation call.
      final success = await ref
          .read(profileStateProvider.notifier)
          .activateMembership(tierId: tier.id, status: 'active');

      if (!mounted) return;

      if (success) {
        // ── Step 3: Record Stripe payment ID for audit trail ────────────────
        if (paymentResult.paymentIntentId != null &&
            paymentResult.paymentIntentId!.isNotEmpty) {
          try {
            if (userId != null) {
              await supabase.from('profiles').update({
                'paypal_order_id': paymentResult.paymentIntentId,
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', userId);
            }
          } catch (e) {
            debugPrint('[MembershipSelection] payment intent record failed: $e');
          }
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tier.name} membership activated!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
        // Auto return home after brief delay
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          context.go(AppRoutes.home);
        }
      } else {
        final error = ref.read(profileStateProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                error ?? 'Could not activate membership. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not activate membership: $error'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final tiersAsync = ref.watch(membershipTiersProvider);

    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      body: SafeArea(
        child: tiersAsync.when(
          // ── Loading state ──────────────────────────────────────────────
          loading: () => const Center(
            child: CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 2,
            ),
          ),

          // ── Error state ────────────────────────────────────────────────
          error: (err, __) => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  const Text(
                    'Could not load membership tiers',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$err',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => ref.invalidate(membershipTiersProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),

          // ── Data state — dynamic tier cards ────────────────────────────
          data: (tiers) {
            if (tiers.isEmpty) {
              return const Center(
                child: Text(
                  'No membership tiers available',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
              );
            }

            // Clamp page index to valid range
            final safeIndex = _currentPage.clamp(0, tiers.length - 1);
            final selectedTier = tiers[safeIndex];

            return Column(
              children: [
                const SizedBox(height: 24),
                const Text(
                  'Choose Your Membership',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Unlock exclusive rewards across every TigerBay venue',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Swipeable tier cards (N cards from DB) ──────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: tiers.length,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemBuilder: (context, index) {
                      return _TierCard(tier: tiers[index]);
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // ── Page indicator dots (dynamic count) ─────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(tiers.length, (index) {
                    final isActive = index == safeIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color:
                            isActive ? AppColors.gold : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 24),

                // ── Activate button ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isProcessing
                          ? null
                          : () => _activateMembership(selectedTier),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        disabledBackgroundColor:
                            AppColors.gold.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: _isProcessing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Activate ${selectedTier.name}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Individual tier card widget (DB-driven) ───────────────────────────────────

class _TierCard extends StatelessWidget {
  final MembershipTier tier;
  const _TierCard({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Tier name ──────────────────────────────────────────────────
          Text(
            tier.name,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
              letterSpacing: 1,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 4),

          // ── Price & Strips Rate ────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                tier.formattedPrice,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tier.stripsRateDescription,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                    color: AppColors.gold,
                    fontFamily: 'Poppins',
                  ),
                  maxLines: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 20),

          // ── Benefits loop (from DB text array) ─────────────────────────
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tier.benefits.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
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
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                          fontFamily: 'Poppins',
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
