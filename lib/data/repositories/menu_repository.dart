import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tigerbay_app/data/models/menu_item_model.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/features/home/screens/news_feed_component.dart';

class MenuRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── Dishes (public.dishes) ─────────────────────────────────────────────────

  /// One-shot fetch from public.dishes, ordered by created_at descending.
  Future<List<MenuItemModel>> getDishes({
    MenuCategory? category,
    String? searchQuery,
  }) async {
    var query = _supabase.from('dishes').select().eq('is_available', true);

    if (category != null && category != MenuCategory.all) {
      query = query.eq('category', category.value);
    }

    final data = await query.order('created_at', ascending: false);
    final items = (data as List).map((e) => MenuItemModel.fromJson(e)).toList();

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      return items
          .where((item) =>
              item.name.toLowerCase().contains(q) ||
              item.description.toLowerCase().contains(q) ||
              item.category.toLowerCase().contains(q))
          .toList();
    }

    return items;
  }

  /// Realtime stream from public.dishes sorted by created_at descending.
  /// Used by the menu screen StreamBuilder.
  Stream<List<MenuItemModel>> watchDishes() {
    return _supabase
        .from('dishes')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((e) => MenuItemModel.fromJson(e))
            .where((item) => item.isAvailable)
            .toList());
  }

  // ── Branches (public.branches) ─────────────────────────────────────────────

  /// Fetch all branches. Schema has no is_active column; fetches all rows.
  Future<List<Branch>> getBranches() async {
    final data = await _supabase.from('branches').select().order('name');

    return (data as List).map((e) => Branch.fromJson(e)).toList();
  }

  // ── Newsfeed (public.newsfeed) ────────────────────────────────────────────

  Future<List<NewsFeedItem>> getNewsfeed({
    required int branchId,
    int limit = 20,
  }) async {
    final data = await _supabase
        .from(
            'newsfeed') // Fixed: Swapped plural 'newsfeeds' out for your correct singular table name
        .select()
        .eq('branch_id', branchId)
        .order('created_at',
            ascending:
                false) // Fixed: Updated sorting column to match your exact DB schema tracking layout
        .limit(limit);

    return (data as List).map((e) => NewsFeedItem.fromJson(e)).toList();
  }
}
