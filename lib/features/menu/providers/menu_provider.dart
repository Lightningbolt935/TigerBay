import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tigerbay_app/data/models/menu_item_model.dart';
import 'package:tigerbay_app/data/models/menu_category_node.dart';
import 'package:tigerbay_app/features/home/providers/home_provider.dart';

// ── Legacy Compatibility Providers ────────────────────────────────────────────

final selectedMenuCategoryProvider =
    StateProvider<MenuCategory>((ref) => MenuCategory.all);

final menuSearchQueryProvider = StateProvider<String>((ref) => '');

final dishesStreamProvider = StreamProvider<List<MenuItemModel>>((ref) {
  return ref.read(menuRepositoryProvider).watchDishes();
});

final groupedDishesProvider =
    Provider<Map<String, List<MenuItemModel>>>((ref) {
  final dishesAsync = ref.watch(dishesStreamProvider);
  final selectedCategory = ref.watch(selectedMenuCategoryProvider);
  final searchQuery = ref.watch(menuSearchQueryProvider).toLowerCase();

  final items = dishesAsync.asData?.value ?? [];

  final filtered = items.where((item) {
    final categoryMatch = selectedCategory == MenuCategory.all ||
        item.menuCategory == selectedCategory;
    final searchMatch = searchQuery.isEmpty ||
        item.name.toLowerCase().contains(searchQuery) ||
        item.description.toLowerCase().contains(searchQuery) ||
        item.category.toLowerCase().contains(searchQuery);
    return categoryMatch && searchMatch;
  }).toList();

  final Map<String, List<MenuItemModel>> grouped = {};
  for (final item in filtered) {
    grouped.putIfAbsent(item.category, () => []).add(item);
  }
  return grouped;
});

// ═══════════════════════════════════════════════════════════════════════════════
// HIERARCHICAL & DYNAMIC MENU STATE MANAGEMENT (SUPABASE DRIVEN)
// ═══════════════════════════════════════════════════════════════════════════════

/// Root Menu Tab: 'food', 'drinks', 'shisha'
final selectedMenuTypeProvider = StateProvider<String>((ref) => 'food');

/// Watch active categories for the currently selected menu type in realtime from Supabase.
/// Strictly filtered by is_active == true and selected branch.
final hierarchicalCategoriesProvider =
    StreamProvider<List<MenuCategoryNode>>((ref) {
  final menuType = ref.watch(selectedMenuTypeProvider);
  final selectedBranch = ref.watch(selectedBranchProvider);
  return ref.read(menuRepositoryProvider).watchCategories(
    menuType: menuType,
    branchId: selectedBranch?.id,
  );
});

/// Category navigation breadcrumb stack (e.g. [Food, Starters])
class CategoryNavigationNotifier
    extends StateNotifier<List<MenuCategoryNode>> {
  CategoryNavigationNotifier() : super([]);

  void pushCategory(MenuCategoryNode node) {
    state = [...state, node];
  }

  void popCategory() {
    if (state.isNotEmpty) {
      state = state.sublist(0, state.length - 1);
    }
  }

  void popToCategory(MenuCategoryNode node) {
    final index = state.indexWhere((n) => n.id == node.id);
    if (index >= 0) {
      state = state.sublist(0, index + 1);
    }
  }

  void selectCategory(MenuCategoryNode? node) {
    if (node == null) {
      state = [];
    } else {
      state = [node];
    }
  }

  void resetStack() {
    state = [];
  }
}

final categoryNavigationStackProvider = StateNotifierProvider<
    CategoryNavigationNotifier, List<MenuCategoryNode>>((ref) {
  return CategoryNavigationNotifier();
});

/// Currently active category node (null means 'ALL' categories of selectedMenuType)
final currentCategoryNodeProvider = Provider<MenuCategoryNode?>((ref) {
  final stack = ref.watch(categoryNavigationStackProvider);
  return stack.isNotEmpty ? stack.last : null;
});

/// The categories / subcategories to display at the current hierarchical depth
final currentLevelCategoriesProvider =
    Provider<AsyncValue<List<MenuCategoryNode>>>((ref) {
  final rootCategoriesAsync = ref.watch(hierarchicalCategoriesProvider);
  final currentNode = ref.watch(currentCategoryNodeProvider);

  return rootCategoriesAsync.whenData((roots) {
    if (currentNode == null) {
      return roots;
    }
    // Return children of current node if any
    return currentNode.subcategories;
  });
});

/// Filtered dishes for the current category selection, search, and active Supabase categories.
/// If an admin hides a category (is_active == false), its dishes are vanished as well.
final dishesForCurrentHierarchyProvider =
    Provider<AsyncValue<List<MenuItemModel>>>((ref) {
  final selectedBranch = ref.watch(selectedBranchProvider);
  final dishesAsync = ref.watch(menuForBranchProvider(selectedBranch?.id));
  final currentNode = ref.watch(currentCategoryNodeProvider);
  final menuType = ref.watch(selectedMenuTypeProvider).toLowerCase();
  final searchQuery = ref.watch(menuSearchQueryProvider).trim().toLowerCase();
  final categoriesAsync = ref.watch(hierarchicalCategoriesProvider);

  return dishesAsync.whenData((allDishes) {
    final activeCategories = categoriesAsync.asData?.value ?? [];
    final activeCategoryIds = activeCategories.map((c) => c.id).toSet();
    final activeCategoryNames =
        activeCategories.map((c) => c.name.toLowerCase()).toSet();

    // Check if a dish belongs to an active category mentioned in Supabase
    bool belongsToActiveCategory(MenuItemModel dish) {
      if (dish.categoryId != null &&
          activeCategoryIds.contains(dish.categoryId)) {
        return true;
      }
      final dishCat = dish.category.toLowerCase();
      final dishSub = dish.subcategory?.toLowerCase();

      if (activeCategoryNames.contains(dishCat)) return true;
      if (dishSub != null && activeCategoryNames.contains(dishSub)) return true;

      for (final activeName in activeCategoryNames) {
        if (dishCat.contains(activeName) || activeName.contains(dishCat)) {
          return true;
        }
        if (dishSub != null &&
            (dishSub.contains(activeName) || activeName.contains(dishSub))) {
          return true;
        }
      }

      // If no categories in Supabase yet, match by menuType keywords
      if (activeCategories.isEmpty) {
        if (menuType == 'food' &&
            (dishCat.contains('food') ||
                dishCat.contains('starter') ||
                dishCat.contains('dessert') ||
                dishCat.contains('main'))) {
          return true;
        }
        if (menuType == 'drinks' &&
            (dishCat.contains('drink') ||
                dishCat.contains('wine') ||
                dishCat.contains('beer') ||
                dishCat.contains('spirit') ||
                dishCat.contains('cocktail'))) {
          return true;
        }
        if (menuType == 'shisha' && dishCat.contains('shisha')) {
          return true;
        }
      }

      return false;
    }

    // 1. Search Query active
    if (searchQuery.isNotEmpty) {
      return allDishes.where((dish) {
        if (!dish.isAvailable) return false;
        final matchesSearch = dish.name.toLowerCase().contains(searchQuery) ||
            dish.description.toLowerCase().contains(searchQuery) ||
            dish.category.toLowerCase().contains(searchQuery) ||
            (dish.subcategory != null &&
                dish.subcategory!.toLowerCase().contains(searchQuery));
        return matchesSearch && belongsToActiveCategory(dish);
      }).toList();
    }

    // 2. Specific Category Node selected
    if (currentNode != null) {
      final targetId = currentNode.id;
      final targetName = currentNode.name.toLowerCase();

      return allDishes.where((dish) {
        if (!dish.isAvailable) return false;
        if (dish.categoryId != null && dish.categoryId == targetId) return true;
        if (dish.subcategory != null &&
            dish.subcategory!.toLowerCase() == targetName) {
          return true;
        }
        final dishCat = dish.category.toLowerCase();
        return dishCat == targetName ||
            dishCat.contains(targetName) ||
            targetName.contains(dishCat);
      }).toList();
    }

    // 3. Root Level: Show all dishes belonging to active categories for current menuType
    return allDishes
        .where((dish) => dish.isAvailable && belongsToActiveCategory(dish))
        .toList();
  });
});
