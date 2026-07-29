import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/menu_item_model.dart';
import '../../home/providers/home_provider.dart';

final selectedMenuCategoryProvider =
    StateProvider<MenuCategory>((ref) => MenuCategory.all);

final menuSearchQueryProvider = StateProvider<String>((ref) => '');

// ── Realtime dishes stream (public.dishes, Realtime enabled) ──────────────────
//
// watchDishes() uses .stream(primaryKey:['id']) so any DB update to a row
// (price, availability, etc.) is pushed to listeners immediately.

final dishesStreamProvider = StreamProvider<List<MenuItemModel>>((ref) {
  return ref.read(menuRepositoryProvider).watchDishes();
});

// ── Derived: filtered + grouped by category ───────────────────────────────────
//
// Groups dishes by their 'category' field (the only grouping column in schema).

final groupedDishesProvider =
    Provider<Map<String, List<MenuItemModel>>>((ref) {
  final dishesAsync = ref.watch(dishesStreamProvider);
  final selectedCategory = ref.watch(selectedMenuCategoryProvider);
  final searchQuery = ref.watch(menuSearchQueryProvider).toLowerCase();

  final items = dishesAsync.asData?.value ?? [];

  // Apply category filter
  final filtered = items.where((item) {
    final categoryMatch = selectedCategory == MenuCategory.all ||
        item.menuCategory == selectedCategory;
    final searchMatch = searchQuery.isEmpty ||
        item.name.toLowerCase().contains(searchQuery) ||
        item.description.toLowerCase().contains(searchQuery) ||
        item.category.toLowerCase().contains(searchQuery);
    return categoryMatch && searchMatch;
  }).toList();

  // Group by category string for section headers
  final Map<String, List<MenuItemModel>> grouped = {};
  for (final item in filtered) {
    grouped.putIfAbsent(item.category, () => []).add(item);
  }
  return grouped;
});
