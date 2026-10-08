import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tigerbay_app/data/models/menu_item_model.dart';
import 'package:tigerbay_app/data/models/menu_category_node.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/features/home/screens/news_feed_component.dart';

class MenuRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── Hierarchical Menu Categories (public.menu_categories) ─────────────────

  /// Fetch hierarchical categories tree from Supabase.
  /// If admin hides a category (is_active == false), it is completely vanished.
  Future<List<MenuCategoryNode>> getCategories({
    String? menuType,
    int? branchId,
  }) async {
    try {
      var query = _supabase.from('menu_categories').select().eq('is_active', true);

      if (menuType != null && menuType.isNotEmpty) {
        query = query.eq('menu_type', menuType.toLowerCase());
      }

      if (branchId != null) {
        query = query.or('branch_id.eq.$branchId,branch_id.is.null');
      }

      final data = await query.order('display_order', ascending: true);
      final flat = (data as List)
          .map((e) => MenuCategoryNode.fromJson(e as Map<String, dynamic>))
          .where((e) => e.isActive)
          .toList();

      return MenuCategoryNode.buildTree(flat);
    } catch (_) {
      return <MenuCategoryNode>[];
    }
  }

  /// Realtime stream for menu categories.
  /// Strictly controlled via Supabase — inactive/hidden categories vanish automatically.
  Stream<List<MenuCategoryNode>> watchCategories({
    String? menuType,
    int? branchId,
  }) {
    return _supabase
        .from('menu_categories')
        .stream(primaryKey: ['id'])
        .order('display_order', ascending: true)
        .map((rows) {
          final flat = rows
              .map((e) => MenuCategoryNode.fromJson(e))
              .where((e) =>
                  e.isActive &&
                  (menuType == null ||
                      e.menuType.toLowerCase() == menuType.toLowerCase()) &&
                  (branchId == null ||
                      e.branchId == null ||
                      e.branchId == branchId))
              .toList();

          return MenuCategoryNode.buildTree(flat);
        })
        .handleError((_) {
          return <MenuCategoryNode>[];
        });
  }

  // ── Dishes (public.dishes) ─────────────────────────────────────────────────

  /// One-shot fetch from public.dishes, ordered by created_at descending.
  Future<List<MenuItemModel>> getDishes({
    MenuCategory? category,
    String? categoryId,
    String? subcategory,
    String? searchQuery,
    int? branchId,
  }) async {
    var query = _supabase.from('dishes').select().eq('is_available', true);

    if (category != null && category != MenuCategory.all) {
      query = query.eq('category', category.value);
    }

    if (categoryId != null && categoryId.isNotEmpty) {
      query = query.eq('category_id', categoryId);
    }

    if (subcategory != null && subcategory.isNotEmpty) {
      query = query.eq('subcategory', subcategory);
    }

    if (branchId != null) {
      query = query.or('branch_id.eq.$branchId,branch_id.is.null');
    }

    final data = await query.order('created_at', ascending: false);
    final items = (data as List).map((e) => MenuItemModel.fromJson(e)).toList();

    if (searchQuery != null && searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      return items
          .where((item) =>
              item.name.toLowerCase().contains(q) ||
              item.description.toLowerCase().contains(q) ||
              item.category.toLowerCase().contains(q) ||
              (item.subcategory != null &&
                  item.subcategory!.toLowerCase().contains(q)))
          .toList();
    }

    return items;
  }

  /// Realtime stream from public.dishes sorted by created_at descending.
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

  // ── Item Variants & Add-ons ─────────────────────────────────────────────────

  Future<List<ItemVariant>> getItemVariants(int dishId) async {
    try {
      final data = await _supabase
          .from('item_variants')
          .select()
          .eq('dish_id', dishId)
          .order('display_order', ascending: true);
      return (data as List).map((e) => ItemVariant.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ItemAddon>> getItemAddons(int dishId) async {
    try {
      final data = await _supabase
          .from('item_addons')
          .select()
          .eq('dish_id', dishId)
          .order('display_order', ascending: true);
      return (data as List).map((e) => ItemAddon.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Branches (public.branches) ─────────────────────────────────────────────

  Future<List<Branch>> getBranches() async {
    final data = await _supabase.from('branches').select().order('name');
    return (data as List).map((e) => Branch.fromJson(e)).toList();
  }

  // ── Newsfeed & What's On (public.newsfeeds) ─────────────────────────────────

  Future<List<NewsFeedItem>> getNewsfeed({
    required int branchId,
    int limit = 20,
  }) async {
    try {
      final data = await _supabase
          .from('newsfeed')
          .select()
          .or('branch_id.eq.$branchId,branch_id.is.null')
          .order('created_at', ascending: false)
          .limit(limit);

      return (data as List).map((e) => NewsFeedItem.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Packages (public.packages) ─────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getPackages({int? branchId}) async {
    try {
      var query = _supabase.from('packages').select().eq('is_active', true);
      if (branchId != null) {
        query = query.or('branch_id.eq.$branchId,branch_id.is.null');
      }
      final data = await query.order('display_order', ascending: true);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  // ── Enquiries (Contact Us -> public.enquiries) ──────────────────────────────

  Future<void> submitEnquiry({
    required String name,
    required String email,
    String? phone,
    String? subject,
    required String message,
    int? branchId,
  }) async {
    await _supabase.from('enquiries').insert({
      'customer_name': name,
      'customer_email': email,
      'customer_phone': phone,
      'subject': subject,
      'message': message,
      'branch_id': branchId,
      'recipient_email': 'bookings@tigerbayshisha.co.uk',
    });
  }
}

