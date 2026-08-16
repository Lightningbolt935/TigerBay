import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/constants/app_routes.dart';
import 'apple_touch_feedback.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Main Shell (Apple Floating Frosted Glass Dock)
/// ═══════════════════════════════════════════════════════════════════════════
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const List<_NavItem> _items = [
    _NavItem(
      label: 'Feed',
      icon: Icons.rss_feed_rounded,
      activeIcon: Icons.rss_feed_rounded,
      route: AppRoutes.home,
    ),
    _NavItem(
      label: 'Menu',
      icon: Icons.restaurant_menu_outlined,
      activeIcon: Icons.restaurant_menu_rounded,
      route: AppRoutes.menu,
    ),
    _NavItem(
      label: 'Wallet',
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
      route: AppRoutes.loyalty,
    ),
    _NavItem(
      label: 'Rewards',
      icon: Icons.card_giftcard_outlined,
      activeIcon: Icons.card_giftcard_rounded,
      route: AppRoutes.rewardStore,
    ),
    _NavItem(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      route: AppRoutes.profile,
    ),
  ];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _items.length; i++) {
      if (location.startsWith(_items[i].route)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _currentIndex(context);

    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      extendBody: true,
      body: child,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 32,
                spreadRadius: -4,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(34),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.glassBackground,
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: AppColors.glassBorder,
                    width: 0.8,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_items.length, (i) {
                    final item = _items[i];
                    final isSelected = i == currentIndex;

                    return Expanded(
                      child: AppleTouchFeedback(
                        pressedScale: 0.92,
                        onTap: () {
                          if (!isSelected) {
                            HapticFeedback.selectionClick();
                            context.go(item.route);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.gold.withValues(alpha: 0.16)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            border: isSelected
                                ? Border.all(
                                    color: AppColors.gold.withValues(alpha: 0.35),
                                    width: 0.8,
                                  )
                                : null,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedScale(
                                duration: const Duration(milliseconds: 200),
                                scale: isSelected ? 1.08 : 1.0,
                                curve: Curves.easeOutBack,
                                child: Icon(
                                  isSelected ? item.activeIcon : item.icon,
                                  size: 22,
                                  color: isSelected
                                      ? AppColors.gold
                                      : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.label,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? AppColors.gold
                                      : AppColors.textHint,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final String route;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.route,
  });
}
