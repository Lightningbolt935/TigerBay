import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/data/models/menu_item_model.dart';
import 'package:tigerbay_app/features/home/providers/home_provider.dart';
import 'package:tigerbay_app/features/menu/providers/menu_provider.dart';
import 'package:tigerbay_app/features/menu/widgets/beautiful_menu_card.dart';
import 'package:tigerbay_app/shared/widgets/tigerbay_brand_header.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Menu Screen (Dark Luxury)
/// ═══════════════════════════════════════════════════════════════════════════
/// Displays the restaurant menu with category pills, search, and
/// BeautifulMenuCard widgets with discount support.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Branch-filtered dishes — re-fetches automatically on branch switch
    final selectedBranch = ref.watch(selectedBranchProvider);
    final int? branchId = selectedBranch?.id;
    final dishesAsync = ref.watch(menuForBranchProvider(branchId));
    final selectedCategory = ref.watch(selectedMenuCategoryProvider);
    final searchQuery = ref.watch(menuSearchQueryProvider);

    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      body: Column(
        children: [
          const TigerBayBrandHeader(),

          // ── Search Bar ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                onChanged: (val) =>
                    ref.read(menuSearchQueryProvider.notifier).state = val,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search menu...',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 14,
                    color: AppColors.textHint,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textHint, size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Category Pills ──────────────────────────────────────────
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: MenuCategory.values.map((cat) {
                final isSelected = selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => ref
                        .read(selectedMenuCategoryProvider.notifier)
                        .state = cat,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.gold
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cat.displayName,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // ── Menu Items ──────────────────────────────────────────────
          Expanded(
            child: dishesAsync.when(
              loading: () => _buildLoadingShimmer(),
              error: (err, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.textSecondary),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load menu',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(menuForBranchProvider(branchId)),
                      child: Text(
                        'Retry',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              data: (allItems) {
                // Apply category + search filter
                final filtered = allItems.where((item) {
                  final catMatch = selectedCategory == MenuCategory.all ||
                      item.menuCategory == selectedCategory;
                  final searchMatch = searchQuery.isEmpty ||
                      item.name
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase()) ||
                      item.description
                          .toLowerCase()
                          .contains(searchQuery.toLowerCase());
                  return catMatch && searchMatch;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.restaurant_menu_outlined,
                            size: 48, color: AppColors.border),
                        const SizedBox(height: 12),
                        Text(
                          'No items found',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (_, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: BeautifulMenuCard(
                        item: filtered[index],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: AppColors.surface,
      highlightColor: AppColors.surfaceLight,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 4,
        itemBuilder: (_, __) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 220,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }
}
