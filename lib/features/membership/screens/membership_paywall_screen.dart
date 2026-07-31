import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/services/paypal_service.dart';
import 'package:tigerbay_app/data/models/membership_tier_model.dart';
import 'package:tigerbay_app/features/profile/providers/membership_provider.dart';

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

  Future<void> _activateMembership(MembershipTier tier) async {
    final activator =
        ref.read(membershipActivationNotifierProvider.notifier);
    final paymentMethod = ref.read(selectedPaymentMethodProvider);

    // ── PayPal: launch real WebView checkout ──────────────────────────────
    if (paymentMethod == PaymentMethod.paypal) {
      final paid = await PayPalService.pay(
        context: context,
        amount: tier.price.toStringAsFixed(2),
        currency: 'GBP',
        description: '${tier.name} Membership — TigerBay International',
      );

      if (!mounted) return;

      if (!paid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'PayPal payment was cancelled or failed. Please try again.',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.white),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
      // Payment approved — fall through to activate membership below
    }

    // ── Stripe: coming soon ───────────────────────────────────────────────
    if (paymentMethod == PaymentMethod.stripe) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Card (Stripe) payments coming soon. Please use PayPal or pay at the venue.',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.white),
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // ── Offline methods (Cash / POS / Bank) + post-PayPal activation ──────
    final success = await activator.activateMembership(tier);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tier.name} membership activated via ${paymentMethod.displayName}!',
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
      // GoRouter auto-redirects via Gate 4 as soon as profileState updates!
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
    final selectedPayment = ref.watch(selectedPaymentMethodProvider);

    return Scaffold(
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

            return Column(
              children: [
                const SizedBox(height: 16),

                // ── Brand Header ─────────────────────────────────────────
                _buildBrandHeader(),

                const SizedBox(height: 24),

                // ── Title ────────────────────────────────────────────────
                Text(
                  'CHOOSE YOUR MEMBERSHIP',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Unlock exclusive rewards across every TigerBay venue',
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
                    onPageChanged: (i) => setState(() => _currentPage = i),
                    itemBuilder: (_, index) {
                      final isSelected = index == safeIndex;
                      return _TierCard(
                        tier: tiers[index],
                        isSelected: isSelected,
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

                const SizedBox(height: 20),

                // ── Payment Method Selector ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PAYMENT METHOD',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...PaymentMethod.values.map((method) {
                        final isMethodSelected = selectedPayment == method;
                        final isComingSoon = method == PaymentMethod.stripe;
                        return GestureDetector(
                          onTap: isComingSoon
                              ? null
                              : () => ref
                                  .read(selectedPaymentMethodProvider.notifier)
                                  .state = method,
                          child: Opacity(
                            opacity: isComingSoon ? 0.45 : 1.0,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isMethodSelected
                                      ? AppColors.gold
                                      : AppColors.border,
                                  width: isMethodSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // ── Radio dot ─────────────────────────
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isMethodSelected
                                            ? AppColors.gold
                                            : AppColors.border,
                                        width: 2,
                                      ),
                                    ),
                                    child: isMethodSelected
                                        ? Center(
                                            child: Container(
                                              width: 10,
                                              height: 10,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppColors.gold,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),

                                  // Icon for PayPal / Stripe
                                  if (method == PaymentMethod.paypal)
                                    const _PayPalLogo()
                                  else if (method == PaymentMethod.stripe)
                                    const Icon(Icons.credit_card_rounded,
                                        size: 18,
                                        color: AppColors.textSecondary),

                                  if (method == PaymentMethod.paypal ||
                                      method == PaymentMethod.stripe)
                                    const SizedBox(width: 8),

                                  // Label
                                  Text(
                                    method.displayName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isMethodSelected
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                                  ),

                                  // "Soon" badge
                                  if (isComingSoon) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.border,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'Soon',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── CTA Button ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: activationState.isProcessing
                          ? null
                          : () => _activateMembership(selectedTier),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        disabledBackgroundColor:
                            AppColors.gold.withValues(alpha: 0.4),
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
                          : Text(
                              'ACTIVATE ${selectedTier.name.toUpperCase()}',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
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
    );
  }

  Widget _buildBrandHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
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
        ],
      ),
    );
  }
}

// ── Tier Card Widget ──────────────────────────────────────────────────────

class _TierCard extends StatelessWidget {
  final MembershipTier tier;
  final bool isSelected;

  const _TierCard({required this.tier, required this.isSelected});

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
          Text(
            tier.name,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
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

// ── PayPal Logo Widget ────────────────────────────────────────────────────────
/// Minimal PayPal "P" logo using Flutter built-in widgets — no SVG package needed.
class _PayPalLogo extends StatelessWidget {
  const _PayPalLogo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: Color(0xFF003087),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              'P',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 2),
        Container(
          width: 16,
          height: 16,
          decoration: const BoxDecoration(
            color: Color(0xFF009CDE),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              'P',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
