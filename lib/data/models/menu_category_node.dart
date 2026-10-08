
/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — MenuCategoryNode Model
/// ═══════════════════════════════════════════════════════════════════════════
/// Represents a node in the hierarchical menu structure:
/// Menu (Food/Drinks/Shisha) -> Section -> Subsection -> Items.
/// Data is driven dynamically by Supabase `public.menu_categories`, with
/// luxury fallback presets derived directly from Tiger Bay's official menus.
class MenuCategoryNode {
  final String id;
  final String menuType; // 'food', 'drinks', 'shisha'
  final String? parentId;
  final String name;
  final String? description;
  final String? imageUrl;
  final int displayOrder;
  final bool isActive;
  final int? branchId;
  final List<MenuCategoryNode> subcategories;

  const MenuCategoryNode({
    required this.id,
    required this.menuType,
    this.parentId,
    required this.name,
    this.description,
    this.imageUrl,
    this.displayOrder = 0,
    this.isActive = true,
    this.branchId,
    this.subcategories = const [],
  });

  bool get hasChildren => subcategories.isNotEmpty;

  MenuCategoryNode copyWith({
    String? id,
    String? menuType,
    String? parentId,
    String? name,
    String? description,
    String? imageUrl,
    int? displayOrder,
    bool? isActive,
    int? branchId,
    List<MenuCategoryNode>? subcategories,
  }) {
    return MenuCategoryNode(
      id: id ?? this.id,
      menuType: menuType ?? this.menuType,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
      branchId: branchId ?? this.branchId,
      subcategories: subcategories ?? this.subcategories,
    );
  }

  factory MenuCategoryNode.fromJson(Map<String, dynamic> json) {
    return MenuCategoryNode(
      id: json['id']?.toString() ?? '',
      menuType: (json['menu_type'] as String?)?.toLowerCase() ?? 'food',
      parentId: json['parent_id']?.toString(),
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      imageUrl: json['image_url']?.toString(),
      displayOrder: json['display_order'] is int
          ? json['display_order']
          : int.tryParse(json['display_order']?.toString() ?? '0') ?? 0,
      isActive: json['is_active'] == true,
      branchId: json['branch_id'] is int
          ? json['branch_id']
          : int.tryParse(json['branch_id']?.toString() ?? ''),
      subcategories: const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'menu_type': menuType,
        'parent_id': parentId,
        'name': name,
        'description': description,
        'image_url': imageUrl,
        'display_order': displayOrder,
        'is_active': isActive,
        'branch_id': branchId,
      };

  /// Builds a nested category tree from flat Supabase records.
  /// Hidden/inactive categories and their children are completely vanished.
  static List<MenuCategoryNode> buildTree(List<MenuCategoryNode> flatList) {
    final activeNodes = flatList.where((n) => n.isActive).toList();
    final activeIds = activeNodes.map((n) => n.id).toSet();
    final Map<String, List<MenuCategoryNode>> childrenMap = {};
    final List<MenuCategoryNode> roots = [];

    for (final node in activeNodes) {
      if (node.parentId == null || node.parentId!.isEmpty) {
        roots.add(node);
      } else if (activeIds.contains(node.parentId)) {
        childrenMap.putIfAbsent(node.parentId!, () => []).add(node);
      }
      // If parent is inactive or missing, this child is also hidden
    }

    roots.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    MenuCategoryNode attachChildren(MenuCategoryNode parent) {
      final children = childrenMap[parent.id] ?? [];
      children.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      final resolvedChildren = children.map(attachChildren).toList();
      return parent.copyWith(subcategories: resolvedChildren);
    }

    return roots.map(attachChildren).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SOURCE OF TRUTH: Tiger Bay Official Menu Defaults
  // ═══════════════════════════════════════════════════════════════════════════

  static List<MenuCategoryNode> defaultTreeFor(String menuType) {
    switch (menuType.toLowerCase()) {
      case 'food':
        return defaultFoodHierarchy;
      case 'drinks':
        return defaultDrinksHierarchy;
      case 'shisha':
        return defaultShishaHierarchy;
      default:
        return defaultFoodHierarchy;
    }
  }

  /// Official Food Menu hierarchy from TB-FOOD-MENU.pdf & tiger-bay-late-night-menu.pdf
  static const List<MenuCategoryNode> defaultFoodHierarchy = [
    MenuCategoryNode(
      id: 'food_indian',
      menuType: 'food',
      name: 'Indian Food',
      description: 'Authentic Indian curries, tandoori grills & Indo-Chinese',
      displayOrder: 1,
      subcategories: [
        MenuCategoryNode(
          id: 'food_pre_starters',
          menuType: 'food',
          parentId: 'food_indian',
          name: 'Pre-Starters',
          description: 'Poppadums, spiced peanuts, crisps & Carlton mix',
          displayOrder: 1,
        ),
        MenuCategoryNode(
          id: 'food_veg_starters',
          menuType: 'food',
          parentId: 'food_indian',
          name: 'Vegetarian Starters',
          description: 'Paneer tikka, samosas, mogo & crispy bhajiya',
          displayOrder: 2,
        ),
        MenuCategoryNode(
          id: 'food_nonveg_starters',
          menuType: 'food',
          parentId: 'food_indian',
          name: 'Non-Vegetarian Starters',
          description: 'Tandoori drumsticks, chicken tikka, mutton rolls & seekh kebabs',
          displayOrder: 3,
        ),
        MenuCategoryNode(
          id: 'food_indo_chinese',
          menuType: 'food',
          parentId: 'food_indian',
          name: 'Indo-Chinese',
          description: 'Chilli paneer, salt & pepper bhindi, veg manchurian',
          displayOrder: 4,
        ),
        MenuCategoryNode(
          id: 'food_veg_mains',
          menuType: 'food',
          parentId: 'food_indian',
          name: 'Vegetarian Main Course',
          description: 'Dal makhani, paneer tikka masala, tarka daal, cashew curry',
          displayOrder: 5,
        ),
        MenuCategoryNode(
          id: 'food_nonveg_mains',
          menuType: 'food',
          parentId: 'food_indian',
          name: 'Non-Vegetarian Mains',
          description: 'Butter chicken, lamb karahi, kashmiri rogan josh, desi curry',
          displayOrder: 6,
        ),
        MenuCategoryNode(
          id: 'food_seafood',
          menuType: 'food',
          parentId: 'food_indian',
          name: 'Sea Food',
          description: 'Goan fish curry, king prawn karahi',
          displayOrder: 7,
        ),
        MenuCategoryNode(
          id: 'food_biryani',
          menuType: 'food',
          parentId: 'food_indian',
          name: 'Hyderabadi Biryani',
          description: 'Slow-cooked aromatic basmati rice with chicken, lamb or veg',
          displayOrder: 8,
        ),
        MenuCategoryNode(
          id: 'food_rice_noodles',
          menuType: 'food',
          parentId: 'food_indian',
          name: 'Oriental Rice & Noodles',
          description: 'Fried rice, vegetable & chicken chow mein',
          displayOrder: 9,
        ),
        MenuCategoryNode(
          id: 'food_wraps',
          menuType: 'food',
          parentId: 'food_indian',
          name: 'Wraps',
          description: 'Chicken tikka, seekh kebab, paneer tikka served with fries',
          displayOrder: 10,
        ),
        MenuCategoryNode(
          id: 'food_rice_breads',
          menuType: 'food',
          parentId: 'food_indian',
          name: 'Rice & Breads',
          description: 'Naans, rotis, parathas & pilau rice',
          displayOrder: 11,
        ),
        MenuCategoryNode(
          id: 'food_salads_extras',
          menuType: 'food',
          parentId: 'food_indian',
          name: 'Salads & Extras',
          description: 'Raita, french fries, masala chips, fresh salads',
          displayOrder: 12,
        ),
        MenuCategoryNode(
          id: 'food_desserts',
          menuType: 'food',
          parentId: 'food_indian',
          name: 'Desserts',
          description: 'Ras malai, kulfi, waffles, brownies & cheesecakes',
          displayOrder: 13,
        ),
      ],
    ),
    MenuCategoryNode(
      id: 'food_late_night',
      menuType: 'food',
      name: 'Late Night',
      description: 'Served until 01:30 everyday',
      displayOrder: 2,
      subcategories: [
        MenuCategoryNode(
          id: 'food_late_night_bites',
          menuType: 'food',
          parentId: 'food_late_night',
          name: 'Late Night Starters & Bites',
          description: 'Crispy calamari, prawn tempura, chicken goujons, mutton rolls, kiev @ the bay',
          displayOrder: 1,
        ),
      ],
    ),
  ];

  /// Official Drinks Menu hierarchy from drink.pdf
  static const List<MenuCategoryNode> defaultDrinksHierarchy = [
    MenuCategoryNode(
      id: 'drinks_cocktails',
      menuType: 'drinks',
      name: 'Cocktails',
      description: 'Signature mixology, martinis and classic cocktails',
      displayOrder: 1,
    ),
    MenuCategoryNode(
      id: 'drinks_mocktails',
      menuType: 'drinks',
      name: 'Mocktails',
      description: 'Refreshing alcohol-free botanical mocktails & fruit blends',
      displayOrder: 2,
    ),
    MenuCategoryNode(
      id: 'drinks_wine',
      menuType: 'drinks',
      name: 'Wine',
      description: 'Selected fine wines available by 175ml, 250ml or bottle',
      displayOrder: 3,
      subcategories: [
        MenuCategoryNode(
          id: 'drinks_wine_white',
          menuType: 'drinks',
          parentId: 'drinks_wine',
          name: 'White Wine',
          description: 'Crisp and refreshing whites (175ml, 250ml, Bottle)',
          displayOrder: 1,
        ),
        MenuCategoryNode(
          id: 'drinks_wine_red',
          menuType: 'drinks',
          parentId: 'drinks_wine',
          name: 'Red Wine',
          description: 'Smooth and full-bodied reds (175ml, 250ml, Bottle)',
          displayOrder: 2,
        ),
        MenuCategoryNode(
          id: 'drinks_wine_rose',
          menuType: 'drinks',
          parentId: 'drinks_wine',
          name: 'Rosé Wine',
          description: 'Delicate and vibrant rosé (175ml, 250ml, Bottle)',
          displayOrder: 3,
        ),
      ],
    ),
    MenuCategoryNode(
      id: 'drinks_champagne',
      menuType: 'drinks',
      name: 'Champagne',
      description: 'Prestige champagnes & prosecco by the bottle',
      displayOrder: 4,
    ),
    MenuCategoryNode(
      id: 'drinks_spirits',
      menuType: 'drinks',
      name: 'Spirits',
      description: 'Premium bottles and single/double measures',
      displayOrder: 5,
      subcategories: [
        MenuCategoryNode(
          id: 'drinks_spirits_vodka',
          menuType: 'drinks',
          parentId: 'drinks_spirits',
          name: 'Vodka',
          description: 'Cîroc, Grey Goose, Belvedere and house vodkas',
          displayOrder: 1,
        ),
        MenuCategoryNode(
          id: 'drinks_spirits_cognac',
          menuType: 'drinks',
          parentId: 'drinks_spirits',
          name: 'Cognac',
          description: 'Hennessy, Courvoisier, Rémy Martin',
          displayOrder: 2,
        ),
        MenuCategoryNode(
          id: 'drinks_spirits_rum',
          menuType: 'drinks',
          parentId: 'drinks_spirits',
          name: 'Rum',
          description: 'Bacardi, Captain Morgan, Kraken spiced rum',
          displayOrder: 3,
        ),
        MenuCategoryNode(
          id: 'drinks_spirits_tequila',
          menuType: 'drinks',
          parentId: 'drinks_spirits',
          name: 'Tequila',
          description: 'Don Julio 1942, Patron Silver, Casamigos',
          displayOrder: 4,
        ),
        MenuCategoryNode(
          id: 'drinks_spirits_gin',
          menuType: 'drinks',
          parentId: 'drinks_spirits',
          name: 'Gin',
          description: 'Hendrick’s, Bombay Sapphire, Tanqueray 10',
          displayOrder: 5,
        ),
        MenuCategoryNode(
          id: 'drinks_spirits_whisky',
          menuType: 'drinks',
          parentId: 'drinks_spirits',
          name: 'Whisky',
          description: 'Johnnie Walker Blue/Black, Chivas, Macallan',
          displayOrder: 6,
        ),
      ],
    ),
    MenuCategoryNode(
      id: 'drinks_beer_cider',
      menuType: 'drinks',
      name: 'Beer & Cider',
      description: 'Cold draughts, craft bottles and apple ciders',
      displayOrder: 6,
    ),
    MenuCategoryNode(
      id: 'drinks_soft_juices',
      menuType: 'drinks',
      name: 'Soft Drinks & Juices',
      description: 'Fresh fruit juices, sodas, tonics & still/sparkling water',
      displayOrder: 7,
    ),
  ];

  /// Official Shisha Menu hierarchy from desert-shisha_menu.pdf
  static const List<MenuCategoryNode> defaultShishaHierarchy = [
    MenuCategoryNode(
      id: 'shisha_flavours',
      menuType: 'shisha',
      name: 'Flavours',
      description: 'Savacco, Starbuzz, Al Fakher and house signatures (£35 - £38)',
      displayOrder: 1,
    ),
    MenuCategoryNode(
      id: 'shisha_fruit_head',
      menuType: 'shisha',
      name: 'Fruit Head',
      description: 'Upgrade to fresh carved pineapple or grapefruit head (+£10)',
      displayOrder: 2,
    ),
    MenuCategoryNode(
      id: 'shisha_vip',
      menuType: 'shisha',
      name: 'VIP',
      description: 'Exclusive lounge master blends, ice pipes & luxury heads',
      displayOrder: 3,
    ),
  ];
}
