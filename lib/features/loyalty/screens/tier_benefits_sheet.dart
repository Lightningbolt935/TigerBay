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

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Interactive VIP Tier Benefits & Privileges Vault
/// ═══════════════════════════════════════════════════════════════════════════
class TierBenefitsSheet extends ConsumerStatefulWidget {
  final int initialTierId;

  const TierBenefitsSheet({
    super.key,
    this.initialTierId = 1,
  });

  static Future<void> show(BuildContext context, {int initialTierId = 1}) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.78),
      builder: (_) => TierBenefitsSheet(initialTierId: initialTierId),
    );
  }

  @override
  ConsumerState<TierBenefitsSheet> createState() => _TierBenefitsSheetState();
}

class _TierBenefitsSheetState extends ConsumerState<TierBenefitsSheet> {
  late int _selectedTierLevel;

  @override
  void initState() {
    super.initState();
    _selectedTierLevel = widget.initialTierId.clamp(1, 4);
  }

  // Tier color styling
  _TierStyle _getTierStyle(int level) {
    switch (level) {
      case 4:
        return const _TierStyle(
          name: 'Black Society',
          badge: 'INVITATION ONLY',
          icon: CupertinoIcons.shield_fill,
          gradient: LinearGradient(
            colors: [Color(0xFF1F1F24), Color(0xFF121215), Color(0xFF070709)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          accentColor: Color(0xFFD4AF37),
          borderColor: Color(0xFF4A4A58),
          multiplier: '3 pts / £1',
          bonus10: '2,000 pts',
          discount: 'Bespoke',
        );
      case 3:
        return const _TierStyle(
          name: 'Platinum',
          badge: 'VIP EXECUTIVE',
          icon: CupertinoIcons.sparkles,
          gradient: LinearGradient(
            colors: [Color(0xFF2C3240), Color(0xFF1E232E), Color(0xFF141720)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          accentColor: Color(0xFF88A0BF),
          borderColor: Color(0xFF3E4A5E),
          multiplier: '2 pts / £1',
          bonus10: '1,000 pts',
          discount: '30% Monthly',
        );
      case 2:
        return const _TierStyle(
          name: 'Gold',
          badge: 'ELITE STATUS',
          icon: CupertinoIcons.star_fill,
          gradient: LinearGradient(
            colors: [Color(0xFF443312), Color(0xFF2B200B), Color(0xFF161005)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          accentColor: Color(0xFFE5A93C),
          borderColor: Color(0xFF785B24),
          multiplier: '1 pt / £1',
          bonus10: '500 pts',
          discount: '25% Every 3 Mo',
        );
      default:
        return const _TierStyle(
          name: 'Explorer',
          badge: 'MEMBER PASS',
          icon: CupertinoIcons.compass_fill,
          gradient: LinearGradient(
            colors: [Color(0xFF381617), Color(0xFF220E0E), Color(0xFF140707)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          accentColor: Color(0xFFE2231A),
          borderColor: Color(0xFF5E2426),
          multiplier: '0.5 pts / £1',
          bonus10: '250 pts',
          discount: '20% Every 6 Mo',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tiersAsync = ref.watch(membershipTiersProvider);
    final userProfile = ref.watch(userProfileProvider);
    final int userCurrentTierLevel = userProfile?.membershipTierId ?? 1;

    final style = _getTierStyle(_selectedTierLevel);

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF101014),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: Color(0xFF2A2A34), width: 1.2),
            ),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        CupertinoIcons.sparkles,
                        color: AppColors.gold,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'VIP MEMBERSHIP TIERS',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Compare privileges, dining perks & rewards',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Tier Tabs Segmented Selector
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF2A2A38), width: 0.8),
                ),
                child: Row(
                  children: [1, 2, 3, 4].map((level) {
                    final tStyle = _getTierStyle(level);
                    final isSelected = _selectedTierLevel == level;
                    final isUserTier = userCurrentTierLevel == level;

                    return Expanded(
                      child: AppleTouchFeedback(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedTierLevel = level);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: isSelected ? tStyle.gradient : null,
                            color: isSelected ? null : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(color: tStyle.borderColor, width: 1)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: tStyle.accentColor.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    tStyle.icon,
                                    size: 13,
                                    color: isSelected
                                        ? tStyle.accentColor
                                        : AppColors.textHint,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tStyle.name.split(' ').first,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              if (isUserTier) ...[
                                const SizedBox(height: 3),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'YOU',
                                    style: GoogleFonts.poppins(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      color: AppColors.gold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),

              // Scrollable Tier Details Body
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    // Tier Banner Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: style.gradient,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: style.borderColor, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: style.accentColor.withValues(alpha: 0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: style.accentColor.withValues(alpha: 0.4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  style.badge,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: style.accentColor,
                                  ),
                                ),
                              ),
                              if (userCurrentTierLevel == _selectedTierLevel)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        size: 12,
                                        color: Color(0xFF0F0F12),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'ACTIVE TIER',
                                        style: GoogleFonts.poppins(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.8,
                                          color: const Color(0xFF0F0F12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'TigerBay ${style.name}',
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          tiersAsync.when(
                            data: (tiers) {
                              try {
                                final tier = tiers.firstWhere(
                                  (t) => t.tierLevel == _selectedTierLevel,
                                );
                                final priceText = tier.price > 0
                                    ? '£${tier.price.toStringAsFixed(2)} / month'
                                    : 'Invitation Only';
                                return Text(
                                  priceText,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: style.accentColor,
                                  ),
                                );
                              } catch (_) {
                                return const SizedBox.shrink();
                              }
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),

                          const SizedBox(height: 20),

                          // Triple Key Metric Grid
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            child: Row(
                              children: [
                                _buildMetric(
                                  'EARNING RATE',
                                  style.multiplier,
                                  style.accentColor,
                                ),
                                _divider(),
                                _buildMetric(
                                  '10-VISIT BONUS',
                                  style.bonus10,
                                  Colors.white,
                                ),
                                _divider(),
                                _buildMetric(
                                  'DINING PERK',
                                  style.discount,
                                  AppColors.gold,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Privileges List Header
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.checkmark_seal_fill,
                          color: AppColors.gold,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TIER PRIVILEGES & INCLUSIONS',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Dynamic Benefits from DB (or Curated Fallback)
                    tiersAsync.when(
                      data: (tiers) {
                        List<String> benefits = [];
                        try {
                          final tier = tiers.firstWhere(
                            (t) => t.tierLevel == _selectedTierLevel,
                          );
                          benefits = tier.benefits;
                        } catch (_) {}

                        if (benefits.isEmpty) {
                          benefits = _getCuratedBenefits(_selectedTierLevel);
                        }

                        return Column(
                          children: benefits.map((b) => _buildBenefitItem(b, style.accentColor)).toList(),
                        );
                      },
                      loading: () => Column(
                        children: _getCuratedBenefits(_selectedTierLevel)
                            .map((b) => _buildBenefitItem(b, style.accentColor))
                            .toList(),
                      ),
                      error: (_, __) => Column(
                        children: _getCuratedBenefits(_selectedTierLevel)
                            .map((b) => _buildBenefitItem(b, style.accentColor))
                            .toList(),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Action Button
                    if (userCurrentTierLevel < _selectedTierLevel) ...[
                      AppleTouchFeedback(
                        onTap: () {
                          Navigator.of(context).pop();
                          // Pre-select the tier in paywall
                          ref.read(selectedTierIndexProvider.notifier).state =
                              (_selectedTierLevel - 1).clamp(0, 3);
                          context.push(AppRoutes.membershipPaywall);
                        },
                        child: Container(
                          width: double.infinity,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE5A93C), Color(0xFFC48618)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  CupertinoIcons.sparkles,
                                  color: Color(0xFF0F0F12),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'UPGRADE TO ${style.name.toUpperCase()}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.2,
                                    color: const Color(0xFF0F0F12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else if (userCurrentTierLevel == _selectedTierLevel) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A22),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF2E2E3C),
                            width: 0.8,
                          ),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_user_rounded,
                                color: AppColors.gold,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'You are currently on this tier',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A22),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF2E2E3C),
                            width: 0.8,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Unlocked with your higher status',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textHint,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: Colors.white.withValues(alpha: 0.1),
    );
  }

  Widget _buildBenefitItem(String text, Color accentColor) {
    IconData icon = CupertinoIcons.check_mark;
    if (text.toLowerCase().contains('birthday')) {
      icon = Icons.cake_outlined;
    } else if (text.toLowerCase().contains('pts') || text.toLowerCase().contains('bonus')) {
      icon = CupertinoIcons.bolt_fill;
    } else if (text.toLowerCase().contains('dining') || text.toLowerCase().contains('%')) {
      icon = CupertinoIcons.tag_fill;
    } else if (text.toLowerCase().contains('event') || text.toLowerCase().contains('early')) {
      icon = CupertinoIcons.calendar;
    } else if (text.toLowerCase().contains('seating') || text.toLowerCase().contains('concierge')) {
      icon = CupertinoIcons.star_circle_fill;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF15151A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF242430),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 13,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getCuratedBenefits(int level) {
    switch (level) {
      case 4:
        return [
          '3 Strips per £1 on all lounge & dining spend',
          '2,000 Bonus Strips every 10 visits',
          '72-Hour Priority Booking window & secret events',
          'Complimentary Luxury Birthday VIP celebration',
          'Bespoke dining rewards & private chef tastings',
          'Preferential booth & VIP lounge seating',
          'Dedicated Personal Concierge booking',
          'Black Edition Titanium digital pass',
        ];
      case 3:
        return [
          '2 Strips per £1 on all lounge & dining spend',
          '1,000 Bonus Strips every 10 visits',
          '48-Hour Early Booking window & VIP events',
          '30% Dining discount rewarded monthly',
          'Premium Birthday VIP gift & experience',
          'Preferential seating subject to availability',
          'Concierge booking support',
          'Gunmetal Platinum digital pass',
        ];
      case 2:
        return [
          '1 Strip per £1 on all lounge & dining spend',
          '500 Bonus Strips every 10 visits',
          '25% Dining discount every 3 months',
          'Priority table reservations & menu previews',
          'Enhanced Birthday gift & celebration',
          '6 Special promotional offers per month',
          'Gold Edition digital pass',
        ];
      default:
        return [
          '0.5 Strips per £1 on all lounge & dining spend',
          '250 Bonus Strips every 10 visits',
          '20% Dining discount every 6 months',
          'Exclusive Birthday lounge gift',
          'Standard event invitations & menu launches',
          'Digital Member Pass (Apple & Android)',
        ];
    }
  }
}

class _TierStyle {
  final String name;
  final String badge;
  final IconData icon;
  final LinearGradient gradient;
  final Color accentColor;
  final Color borderColor;
  final String multiplier;
  final String bonus10;
  final String discount;

  const _TierStyle({
    required this.name,
    required this.badge,
    required this.icon,
    required this.gradient,
    required this.accentColor,
    required this.borderColor,
    required this.multiplier,
    required this.bonus10,
    required this.discount,
  });
}
