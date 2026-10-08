import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/data/models/menu_category_node.dart';
import 'package:tigerbay_app/shared/widgets/apple_touch_feedback.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — MenuBreadcrumbBar (Luxury Edition)
/// ═══════════════════════════════════════════════════════════════════════════
/// Interactive luxury breadcrumb trail showing current position in menu hierarchy.
class MenuBreadcrumbBar extends StatelessWidget {
  final String menuType;
  final List<MenuCategoryNode> stack;
  final VoidCallback onBack;
  final VoidCallback onRootTap;
  final ValueChanged<MenuCategoryNode> onCategoryTap;

  const MenuBreadcrumbBar({
    super.key,
    required this.menuType,
    required this.stack,
    required this.onBack,
    required this.onRootTap,
    required this.onCategoryTap,
  });

  @override
  Widget build(BuildContext context) {
    if (stack.isEmpty) return const SizedBox.shrink();

    final String rootName = _getRootName(menuType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF141418),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          // Back button
          AppleTouchFeedback(
            onTap: onBack,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E26),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.4),
                  width: 0.8,
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.champagneGold,
                size: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Breadcrumb Trail
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: stack.length > 2,
              child: Row(
                children: [
                  // Root Crumb
                  GestureDetector(
                    onTap: onRootTap,
                    child: Text(
                      rootName.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),

                  // Dynamic Crumbs
                  for (int i = 0; i < stack.length; i++) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: AppColors.gold.withValues(alpha: 0.6),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onCategoryTap(stack[i]),
                      child: Text(
                        stack[i].name,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: (i == stack.length - 1)
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: (i == stack.length - 1)
                              ? AppColors.champagneGold
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRootName(String type) {
    switch (type.toLowerCase()) {
      case 'food':
        return 'Food';
      case 'drinks':
        return 'Drinks';
      case 'shisha':
        return 'Shisha';
      default:
        return 'Menu';
    }
  }
}
