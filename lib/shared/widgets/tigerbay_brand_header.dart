import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/constants/app_routes.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Brand Header Widget
/// ═══════════════════════════════════════════════════════════════════════════
/// Reusable branded header showing the TigerBay logo, brand name in brandRed,
/// and "INTERNATIONAL" subtitle in gold. Used in every screen's AppBar.
class TigerBayBrandHeader extends StatelessWidget {
  final bool showBackButton;
  final List<Widget>? actions;

  const TigerBayBrandHeader({
    super.key,
    this.showBackButton = false,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.brandBlack,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      child: Row(
        children: [
          if (showBackButton)
            GestureDetector(
              onTap: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                } else {
                  context.go(AppRoutes.home);
                }
              },
              child: const Padding(
                padding: EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.arrow_back_ios_rounded,
                  color: AppColors.textPrimary,
                  size: 20,
                ),
              ),
            ),

          // Logo image
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: AppColors.brandBlack,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/tigerbay_logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: AppColors.brandRed,
                  size: 20,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Brand text stack
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TigerBay',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brandRed,
                  letterSpacing: 2,
                  height: 1.2,
                ),
              ),
              Text(
                'INTERNATIONAL',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                  letterSpacing: 4,
                  height: 1.2,
                ),
              ),
            ],
          ),

          const Spacer(),

          if (actions != null) ...actions!,
        ],
      ),
    );
  }
}

/// Convenience wrapper that returns a PreferredSizeWidget for use in
/// Scaffold's appBar parameter.
class TigerBayAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;
  final List<Widget>? actions;

  const TigerBayAppBar({
    super.key,
    this.showBackButton = false,
    this.actions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return TigerBayBrandHeader(
      showBackButton: showBackButton,
      actions: actions,
    );
  }
}
