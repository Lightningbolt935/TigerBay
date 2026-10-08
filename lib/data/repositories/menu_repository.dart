import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tigerbay_app/data/models/menu_item_model.dart';
import 'package:tigerbay_app/data/models/menu_category_node.dart';
import 'package:tigerbay_app/data/models/package_model.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/features/home/screens/news_feed_component.dart';

class MenuRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ── 1. Dynamic Menu Categories (public.menu_categories) ─────────────────

  /// Fetch hierarchical categories tree from Supabase.
  /// If admin hides a category (is_active == false), it is completely removed.
  Future<List<MenuCategoryNode>> getCategories({
    String? menuType,
    int? branchId,
  }) async {
    try {
      var query = _supabase.from('menu_categories').select().eq('is_active', true);

      if (menuType != null && menuType.isNotEmpty && menuType.toLowerCase() != 'all') {
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
                      menuType.toLowerCase() == 'all' ||
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

  /// Watch distinct dynamic menu types for the active venue
  Stream<List<String>> watchMenuTypes({int? branchId}) {
    return _supabase
        .from('menu_categories')
        .stream(primaryKey: ['id'])
        .order('display_order', ascending: true)
        .map((rows) {
          final types = <String>{};
          for (final row in rows) {
            final active = row['is_active'] == true;
            final rowBranchId = row['branch_id'] is int
                ? row['branch_id'] as int
                : int.tryParse(row['branch_id']?.toString() ?? '');

            final branchMatch = branchId == null || rowBranchId == null || rowBranchId == branchId;
            final mType = row['menu_type']?.toString().trim().toLowerCase();

            if (active && branchMatch && mType != null && mType.isNotEmpty) {
              types.add(mType);
            }
          }

          if (types.isEmpty) {
            types.addAll(['food', 'drinks']);
          }
          return types.toList();
        })
        .handleError((_) => ['food', 'drinks']);
  }

  // ── 2. Dishes (public.dishes) ─────────────────────────────────────────────

  /// One-shot fetch from public.dishes.
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
  Stream<List<MenuItemModel>> watchDishes({int? branchId}) {
    return _supabase
        .from('dishes')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((e) => MenuItemModel.fromJson(e))
            .where((item) {
              final branchOk = branchId == null ||
                  item.branchId == null ||
                  item.branchId == branchId;
              return item.isAvailable && branchOk;
            })
            .toList());
  }

  // ── 3. Celebration Packages (public.packages) ─────────────────────────────

  Stream<List<PackageModel>> watchPackages({int? branchId}) {
    return _supabase
        .from('packages')
        .stream(primaryKey: ['id'])
        .order('display_order', ascending: true)
        .map((rows) {
          final pkgs = rows
              .map((e) => PackageModel.fromJson(e))
              .where((p) {
                final branchOk = branchId == null || p.branchId == null || p.branchId == branchId;
                return p.isActive && branchOk;
              })
              .toList();

          if (pkgs.isEmpty) {
            return PackageModel.defaultPackages(branchId: branchId);
          }
          return pkgs;
        })
        .handleError((_) => PackageModel.defaultPackages(branchId: branchId));
  }

  // ── 4. Item Variants & Add-ons ────────────────────────────────────────────

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

  // ── 5. Branches, Newsfeed & Enquiries ─────────────────────────────────────

  Future<List<Branch>> getBranches() async {
    final data = await _supabase.from('branches').select().order('name');
    return (data as List).map((e) => Branch.fromJson(e)).toList();
  }

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
