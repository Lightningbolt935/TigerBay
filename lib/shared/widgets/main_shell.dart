import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/constants/app_routes.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Main Shell (Dark Luxury Bottom Nav)
/// ═══════════════════════════════════════════════════════════════════════════
class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  static const List<_NavItem> _items = [
    _NavItem(
        label: 'FEED',
        icon: Icons.rss_feed_rounded,
        route: AppRoutes.home),
    _NavItem(
        label: 'MENU',
        icon: Icons.restaurant_menu_rounded,
        route: AppRoutes.menu),
    _NavItem(
        label: 'WALLET',
        icon: Icons.account_balance_wallet_outlined,
        route: AppRoutes.loyalty),
    _NavItem(
        label: 'REWARDS',
        icon: Icons.card_giftcard_rounded,
        route: AppRoutes.rewardStore),
    _NavItem(
        label: 'PROFILE',
        icon: Icons.person_outline_rounded,
        route: AppRoutes.profile),
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
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.brandBlack,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 0.5),
          ),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 60,
            child: Row(
              children: List.generate(_items.length, (i) {
                final item = _items[i];
                final isSelected = i == currentIndex;
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.go(item.route),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: isSelected
                              ? const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 4)
                              : EdgeInsets.zero,
                          decoration: isSelected
                              ? BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                )
                              : null,
                          child: Icon(
                            item.icon,
                            size: 22,
                            color: isSelected
                                ? AppColors.gold
                                : AppColors.textHint,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: GoogleFonts.poppins(
                            fontSize: 9,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                            color: isSelected
                                ? AppColors.gold
                                : AppColors.textHint,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
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
  final String route;
  const _NavItem(
      {required this.label, required this.icon, required this.route});
}
