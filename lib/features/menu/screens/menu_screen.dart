import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
/// BeautifulMenuCard widgets with discount support and multi-image detail modal.
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
                        color: isSelected ? AppColors.gold : AppColors.surface,
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
                    final dish = filtered[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: BeautifulMenuCard(
                        item: dish,
                        onTap: () => _showDishDetailModal(context, dish),
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

  void _showDishDetailModal(BuildContext context, MenuItemModel item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DishDetailModalSheet(item: item),
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

/// ── High-Resolution Dish Detail Modal with Swipeable Gallery ──────────────
class _DishDetailModalSheet extends StatefulWidget {
  final MenuItemModel item;

  const _DishDetailModalSheet({required this.item});

  @override
  State<_DishDetailModalSheet> createState() => _DishDetailModalSheetState();
}

class _DishDetailModalSheetState extends State<_DishDetailModalSheet> {
  int _activeImageIndex = 0;
  final PageController _modalPageController = PageController();

  @override
  void dispose() {
    _modalPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.item.images.isNotEmpty
        ? widget.item.images
        : (widget.item.imageUrl != null && widget.item.imageUrl!.isNotEmpty
            ? [widget.item.imageUrl!]
            : <String>[]);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Enlarged Multi-Image Gallery
            if (images.isNotEmpty)
              SizedBox(
                height: 240,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    PageView.builder(
                      controller: _modalPageController,
                      itemCount: images.length,
                      onPageChanged: (i) =>
                          setState(() => _activeImageIndex = i),
                      itemBuilder: (context, idx) {
                        return CachedNetworkImage(
                          imageUrl: images[idx],
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppColors.surfaceLight,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.gold,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: AppColors.surfaceLight,
                            child: const Icon(
                              Icons.restaurant_outlined,
                              color: AppColors.textHint,
                              size: 48,
                            ),
                          ),
                        );
                      },
                    ),
                    if (images.length > 1) ...[
                      Positioned(
                        bottom: 10,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            images.length,
                            (idx) => AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: _activeImageIndex == idx ? 16 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _activeImageIndex == idx
                                    ? AppColors.gold
                                    : Colors.white60,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_activeImageIndex + 1}/${images.length}',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.item.name,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (widget.item.hasDiscount)
                        Text(
                          widget.item.discountedPriceFormatted,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold,
                          ),
                        )
                      else
                        Text(
                          widget.item.formattedPrice,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                    ],
                  ),
                  if (widget.item.hasDiscount) ...[
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          widget.item.formattedPrice,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textHint,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.brandRed,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${widget.item.discountPercentage}% OFF',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    widget.item.description,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
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
}
