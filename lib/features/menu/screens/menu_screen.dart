import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/data/models/menu_item_model.dart';
import 'package:tigerbay_app/data/models/menu_category_node.dart';
import 'package:tigerbay_app/features/home/providers/branch_provider.dart';
import 'package:tigerbay_app/features/menu/providers/menu_provider.dart';
import 'package:tigerbay_app/features/menu/widgets/beautiful_menu_card.dart';
import 'package:tigerbay_app/shared/widgets/tigerbay_brand_header.dart';
import 'package:tigerbay_app/shared/widgets/apple_touch_feedback.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Ultra-Luxury Editorial Menu Screen
/// ═══════════════════════════════════════════════════════════════════════════
/// Inspired by elite Mayfair London lounges and Michelin dining apps (Nobu, Dishoom):
/// - Brushed champagne gold segmented capsule (FOOD / DRINKS / SHISHA).
/// - Dynamic category rail driven 100% by Supabase `menu_categories`.
/// - Instant vanishing of hidden categories (is_active == false).
/// - Seamless browsing with luxury editorial dish cards.
class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBranch = ref.watch(selectedBranchProvider);
    final searchQuery = ref.watch(menuSearchQueryProvider);
    final selectedMenuType = ref.watch(selectedMenuTypeProvider);
    final currentNode = ref.watch(currentCategoryNodeProvider);
    final categoriesAsync = ref.watch(hierarchicalCategoriesProvider);
    final dishesAsync = ref.watch(dishesForCurrentHierarchyProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Column(
        children: [
          const TigerBayBrandHeader(),

          // ── 1. Search Bar & Venue Branch Selector Row ─────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF141418),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (val) =>
                          ref.read(menuSearchQueryProvider.notifier).state = val,
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        color: Colors.white,
                      ),
                      cursorColor: AppColors.champagneGold,
                      decoration: InputDecoration(
                        hintText: 'Search dishes, cocktails, shisha...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: AppColors.textHint,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.champagneGold,
                          size: 20,
                        ),
                        suffixIcon: searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 16, color: Colors.white70),
                                onPressed: () => ref
                                    .read(menuSearchQueryProvider.notifier)
                                    .state = '',
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Venue Branch Selector Capsule
                ref.watch(branchListProvider).when(
                  data: (branchList) => _MenuBranchSelector(
                    branches: branchList,
                    selected: selectedBranch,
                    onSelected: (b) {
                      if (b == null) {
                        ref
                            .read(selectedBranchProvider.notifier)
                            .selectAllVenues();
                      } else {
                        ref
                            .read(selectedBranchProvider.notifier)
                            .changeBranch(b);
                      }
                    },
                  ),
                  loading: () => Container(
                    height: 48,
                    width: 105,
                    decoration: BoxDecoration(
                      color: const Color(0xFF141418),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── 2. Segmented Menu Capsule (FOOD / DRINKS / SHISHA) ─────────────
          if (searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF17171C),
                      Color(0xFF0F0F12),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.08),
                      blurRadius: 10,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildLuxurySegmentTab(
                      ref: ref,
                      label: 'FOOD',
                      icon: Icons.restaurant_rounded,
                      type: 'food',
                      isSelected: selectedMenuType == 'food',
                    ),
                    _buildLuxurySegmentTab(
                      ref: ref,
                      label: 'DRINKS',
                      icon: Icons.local_bar_rounded,
                      type: 'drinks',
                      isSelected: selectedMenuType == 'drinks',
                    ),
                    _buildLuxurySegmentTab(
                      ref: ref,
                      label: 'SHISHA',
                      icon: Icons.cloud_rounded,
                      type: 'shisha',
                      isSelected: selectedMenuType == 'shisha',
                    ),
                  ],
                ),
              ),
            ),

          // ── 3. Dynamic Category Filter Rail (Supabase Controlled) ──────────
          if (searchQuery.isEmpty) ...[
            const SizedBox(height: 10),
            _buildSupabaseCategoryRail(ref, categoriesAsync, currentNode),
          ],

          const SizedBox(height: 8),

          // ── 4. Main Dishes List View ──────────────────────────────────────
          Expanded(
            child: dishesAsync.when(
              loading: () => _buildLoadingShimmer(),
              error: (err, _) => _buildErrorView(ref),
              data: (dishes) {
                if (dishes.isEmpty) {
                  return _buildEmptyDishesView(ref, currentNode);
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                  physics: const BouncingScrollPhysics(),
                  itemCount: dishes.length,
                  itemBuilder: (context, index) {
                    final dish = dishes[index];
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

  // ── Segmented Tab Capsule Helper ───────────────────────────────────────────
  Widget _buildLuxurySegmentTab({
    required WidgetRef ref,
    required String label,
    required IconData icon,
    required String type,
    required bool isSelected,
  }) {
    return Expanded(
      child: AppleTouchFeedback(
        onTap: () {
          ref.read(selectedMenuTypeProvider.notifier).state = type;
          ref
              .read(categoryNavigationStackProvider.notifier)
              .selectCategory(null);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(
                    colors: [
                      Color(0xFFE5C378),
                      Color(0xFFC79E38),
                      Color(0xFFA17C18),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? Colors.black : const Color(0xFF8E8B85),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.black : const Color(0xFFC2BEB6),
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Supabase-Controlled Category Rail ──────────────────────────────────────
  Widget _buildSupabaseCategoryRail(
    WidgetRef ref,
    AsyncValue<List<MenuCategoryNode>> categoriesAsync,
    MenuCategoryNode? currentNode,
  ) {
    return categoriesAsync.when(
      loading: () => SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          children: List.generate(
            4,
            (i) => Container(
              margin: const EdgeInsets.only(right: 8),
              width: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF141418),
                borderRadius: BorderRadius.circular(19),
              ),
            ),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();

        return SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: categories.length + 1, // +1 for "ALL"
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                // "ALL" Category Chip
                final isSelected = currentNode == null;
                return _CategoryPillChip(
                  label: 'ALL',
                  isSelected: isSelected,
                  onTap: () => ref
                      .read(categoryNavigationStackProvider.notifier)
                      .selectCategory(null),
                );
              }

              final cat = categories[index - 1];
              final isSelected = currentNode?.id == cat.id;

              return _CategoryPillChip(
                label: cat.name.toUpperCase(),
                isSelected: isSelected,
                onTap: () => ref
                    .read(categoryNavigationStackProvider.notifier)
                    .selectCategory(cat),
              );
            },
          ),
        );
      },
    );
  }

  // ── Luxury Empty Dishes State ──────────────────────────────────────────────
  Widget _buildEmptyDishesView(WidgetRef ref, MenuCategoryNode? currentNode) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF141418),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Icon(
                Icons.restaurant_menu_rounded,
                size: 32,
                color: AppColors.champagneGold,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              currentNode != null ? currentNode.name : 'No Items Available',
              style: GoogleFonts.playfairDisplay(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Selections in this section are currently being refreshed by our culinary team.',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (currentNode != null) ...[
              const SizedBox(height: 20),
              AppleTouchFeedback(
                onTap: () => ref
                    .read(categoryNavigationStackProvider.notifier)
                    .selectCategory(null),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_rounded,
                          size: 14, color: AppColors.champagneGold),
                      const SizedBox(width: 8),
                      Text(
                        'View All Categories',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.champagneGold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
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
      baseColor: const Color(0xFF141418),
      highlightColor: const Color(0xFF22222A),
      child: ListView.builder(
        padding: const EdgeInsets.all(18),
        itemCount: 4,
        itemBuilder: (_, __) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 165,
            decoration: BoxDecoration(
              color: const Color(0xFF141418),
              borderRadius: BorderRadius.circular(20),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorView(WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 44, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(
            'Could not load menu data',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () {
              ref.invalidate(hierarchicalCategoriesProvider);
              ref.invalidate(dishesForCurrentHierarchyProvider);
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.champagneGold,
              side: const BorderSide(color: AppColors.gold, width: 0.8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Retry',
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Luxury Category Pill Chip ────────────────────────────────────────────────
class _CategoryPillChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryPillChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppleTouchFeedback(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [
                    Color(0xFFE5C378),
                    Color(0xFFC79E38),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : const Color(0xFF141418),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: isSelected
                ? AppColors.gold
                : AppColors.gold.withValues(alpha: 0.22),
            width: 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.black : Colors.white,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

/// ── High-Resolution Dish Detail Modal with Variants & Add-ons ──────────────
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
        color: Color(0xFF141418),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Enlarged Multi-Image Gallery
            if (images.isNotEmpty)
              SizedBox(
                height: 250,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    PageView.builder(
                      controller: _modalPageController,
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _activeImageIndex = i),
                      itemBuilder: (context, idx) {
                        return CachedNetworkImage(
                          imageUrl: images[idx],
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: const Color(0xFF1E1E26),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.gold,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: const Color(0xFF1E1E26),
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
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      if (widget.item.hasDiscount)
                        Text(
                          widget.item.discountedPriceFormatted,
                          style: GoogleFonts.poppins(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: AppColors.champagneGold,
                          ),
                        )
                      else
                        Text(
                          widget.item.formattedPrice,
                          style: GoogleFonts.poppins(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: AppColors.champagneGold,
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

                  // Variants Section (e.g. 175ml, 250ml, Bottle)
                  if (widget.item.variants.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Options / Sizes',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.item.variants.map((v) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E26),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                v.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                v.formattedPrice,
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.champagneGold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Addons Section
                  if (widget.item.addons.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Available Extras & Add-ons',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.item.addons.map((a) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E26),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                a.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '+${a.formattedPrice}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.champagneGold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],


                  const SizedBox(height: 24),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'DONE',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
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

/// ── Menu Branch Selector Capsule ──────────────────────────────────────────
class _MenuBranchSelector extends StatelessWidget {
  final List<Branch> branches;
  final Branch? selected;
  final ValueChanged<Branch?> onSelected;

  const _MenuBranchSelector({
    required this.branches,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AppleTouchFeedback(
      onTap: () => _showPicker(context),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF141418),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.35),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_on_rounded,
              color: AppColors.champagneGold,
              size: 15,
            ),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 82),
              child: Text(
                selected?.title ?? 'All Sites',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.champagneGold,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF141418),
      barrierColor: Colors.black.withValues(alpha: 0.8),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Filter Menu by Venue',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 14),

              // All Sites option
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected == null
                        ? AppColors.gold
                        : const Color(0xFF1E1E26),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.store_rounded,
                    size: 18,
                    color: selected == null ? Colors.black : Colors.white,
                  ),
                ),
                title: Text(
                  'All TigerBay Venues',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight:
                        selected == null ? FontWeight.w700 : FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetCtx).pop();
                  onSelected(null);
                },
              ),
              const Divider(color: Color(0xFF262630), height: 1),

              ...branches.map((b) {
                final isSelected = selected?.id == b.id;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.gold
                          : const Color(0xFF1E1E26),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.location_on_rounded,
                      size: 18,
                      color: isSelected ? Colors.black : AppColors.gold,
                    ),
                  ),
                  title: Text(
                    b.title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Text(
                    b.city ?? 'London',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded,
                          color: AppColors.gold, size: 20)
                      : null,
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    onSelected(b);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
