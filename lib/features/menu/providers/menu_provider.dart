import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tigerbay_app/data/models/menu_item_model.dart';
import 'package:tigerbay_app/data/models/menu_category_node.dart';
import 'package:tigerbay_app/data/models/package_model.dart';
import 'package:tigerbay_app/data/repositories/menu_repository.dart';
import 'package:tigerbay_app/features/home/providers/home_provider.dart';

// ── Search & Compatibility Providers ─────────────────────────────────────────

final menuSearchQueryProvider = StateProvider<String>((ref) => '');

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository();
});

// ═══════════════════════════════════════════════════════════════════════════════
// DYNAMIC VENUE MENU TYPES & CATEGORIES (SUPABASE DRIVEN)
// ═══════════════════════════════════════════════════════════════════════════════

final availableMenuTypesProvider = StreamProvider<List<String>>((ref) {
  final selectedBranch = ref.watch(selectedBranchProvider);
  return ref.watch(menuRepositoryProvider).watchMenuTypes(
        branchId: selectedBranch?.id,
      );
});

final selectedMenuTypeProvider = StateProvider<String>((ref) => 'food');

final hierarchicalCategoriesProvider =
    StreamProvider<List<MenuCategoryNode>>((ref) {
  final menuType = ref.watch(selectedMenuTypeProvider);
  final selectedBranch = ref.watch(selectedBranchProvider);
  return ref.watch(menuRepositoryProvider).watchCategories(
        menuType: menuType,
        branchId: selectedBranch?.id,
      );
});

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

final currentCategoryNodeProvider = Provider<MenuCategoryNode?>((ref) {
  final stack = ref.watch(categoryNavigationStackProvider);
  return stack.isNotEmpty ? stack.last : null;
});

final celebrationPackagesProvider = StreamProvider<List<PackageModel>>((ref) {
  final selectedBranch = ref.watch(selectedBranchProvider);
  return ref.watch(menuRepositoryProvider).watchPackages(
        branchId: selectedBranch?.id,
      );
});

final dishesForBranchStreamProvider = StreamProvider<List<MenuItemModel>>((ref) {
  final selectedBranch = ref.watch(selectedBranchProvider);
  return ref.watch(menuRepositoryProvider).watchDishes(
        branchId: selectedBranch?.id,
      );
});

final dishesForCurrentHierarchyProvider =
    Provider<AsyncValue<List<MenuItemModel>>>((ref) {
  final dishesAsync = ref.watch(dishesForBranchStreamProvider);
  final currentNode = ref.watch(currentCategoryNodeProvider);
  final menuType = ref.watch(selectedMenuTypeProvider).toLowerCase();
  final searchQuery = ref.watch(menuSearchQueryProvider).trim().toLowerCase();
  final categoriesAsync = ref.watch(hierarchicalCategoriesProvider);

  return dishesAsync.whenData((allDishes) {
    final activeCategories = categoriesAsync.asData?.value ?? [];
    final activeCategoryIds = activeCategories.map((c) => c.id).toSet();
    final activeCategoryNames =
        activeCategories.map((c) => c.name.toLowerCase()).toSet();

    bool belongsToCurrentMenuType(MenuItemModel dish) {
      if (dish.categoryId != null && activeCategoryIds.contains(dish.categoryId)) {
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

      if (menuType == 'food' &&
          (dishCat.contains('food') ||
              dishCat.contains('starter') ||
              dishCat.contains('main') ||
              dishCat.contains('curry') ||
              dishCat.contains('biryani'))) {
        return true;
      }
      if (menuType == 'drinks' &&
          (dishCat.contains('drink') ||
              dishCat.contains('wine') ||
              dishCat.contains('cocktail') ||
              dishCat.contains('beer') ||
              dishCat.contains('spirit') ||
              dishCat.contains('beverage'))) {
        return true;
      }
      if (menuType == 'shisha' && dishCat.contains('shisha')) {
        return true;
      }
      if (menuType == 'dessert' && (dishCat.contains('dessert') || dishCat.contains('sweet'))) {
        return true;
      }

      return false;
    }

    if (searchQuery.isNotEmpty) {
      return allDishes.where((dish) {
        if (!dish.isAvailable) return false;
        final matchesSearch = dish.name.toLowerCase().contains(searchQuery) ||
            dish.description.toLowerCase().contains(searchQuery) ||
            dish.category.toLowerCase().contains(searchQuery) ||
            (dish.subcategory != null &&
                dish.subcategory!.toLowerCase().contains(searchQuery));
        return matchesSearch;
      }).toList();
    }

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

    return allDishes
        .where((dish) => dish.isAvailable && belongsToCurrentMenuType(dish))
        .toList();
  });
});
