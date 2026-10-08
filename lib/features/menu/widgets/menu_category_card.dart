import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/data/models/menu_category_node.dart';
import 'package:tigerbay_app/shared/widgets/apple_touch_feedback.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Editorial Luxury Menu Category Card
/// ═══════════════════════════════════════════════════════════════════════════
/// Replaces basic list tiles with cinematic, Mayfair London lounge cards:
/// - Atmospheric high-res photography with deep obsidian vignette.
/// - Brushed champagne gold typography and subtle border accents.
/// - Clear hierarchy (subsections count, description, and smooth interaction).
class MenuCategoryCard extends StatelessWidget {
  final MenuCategoryNode category;
  final VoidCallback onTap;

  const MenuCategoryCard({
    super.key,
    required this.category,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasChildren = category.hasChildren;
    final childCount = category.subcategories.length;
    final bgImageUrl = _resolveHeroImage(category);

    return AppleTouchFeedback(
      onTap: onTap,
      child: Container(
        height: 148,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.28),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.55),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.06),
              blurRadius: 16,
              spreadRadius: -2,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 1. High-Resolution Atmospheric Visual Background ──────────
            CachedNetworkImage(
              imageUrl: bgImageUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: const Color(0xFF161519),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.gold,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                color: const Color(0xFF161519),
              ),
            ),

            // ── 2. Cinematic Multi-Stop Dark Vignette Overlay ────────────
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.65),
                    const Color(0xFF0C0B0E).withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),

            // ── 3. Subtle Champagne Gold Accent Vertical Pinstripe ────────
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              child: Container(
                width: 3.5,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFE5C378),
                      Color(0xFFC79E38),
                      Color(0xFF7A5C0E),
                    ],
                  ),
                ),
              ),
            ),

            // ── 4. Card Content: Title, Subsections Badge, & Excerpt ─────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row: Category Type Tag + Subsections Count
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getCategoryIcon(category.name, category.menuType),
                              size: 11,
                              color: AppColors.champagneGold,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              category.menuType.toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: AppColors.champagneGold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (hasChildren)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFE5C378),
                                Color(0xFFC79E38),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '$childCount SECTIONS',
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: Colors.black,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // Bottom Content: Large Gold Title + Description + Arrow
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              category.name,
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                                height: 1.15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _resolveSubtitle(category),
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.55),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.champagneGold,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resolveSubtitle(MenuCategoryNode cat) {
    if (cat.description != null && cat.description!.trim().isNotEmpty) {
      return cat.description!;
    }
    final n = cat.name.toLowerCase();
    if (n.contains('indian')) return 'Signature Tandoor, Curries & Biryanis';
    if (n.contains('late night')) return 'Burgers, Wings, Loaded Fries & Late Bites';
    if (n.contains('starter')) return 'Samosas, Chaats & Grilled Appetizers';
    if (n.contains('main')) return 'Rich Curries, Karahi & Tawa Specialties';
    if (n.contains('wine')) return 'Curated Whites, Reds & Crisp Rosés';
    if (n.contains('cocktail')) return 'Bespoke Mixology, Spritz & Classics';
    if (n.contains('mocktail')) return 'Artisan Fresh Fruit Creations';
    if (n.contains('champagne')) return 'Prestige Cuvée & Dom Pérignon Flutes';
    if (n.contains('spirit')) return 'Vodka, Single Malts, Cognac & Rum';
    if (n.contains('shisha') || n.contains('flavour')) {
      return 'Premium German Hookahs & Blonde Leaf Blends';
    }
    if (n.contains('fruit')) return 'Fresh Pineapple, Orange & Grapefruit Heads';
    if (n.contains('vip')) return 'Exotic Savacco, Starbuzz & Elite VIP Blends';
    return 'Explore curated TigerBay selections';
  }

  String _resolveHeroImage(MenuCategoryNode cat) {
    if (cat.imageUrl != null &&
        cat.imageUrl!.isNotEmpty &&
        cat.imageUrl!.startsWith('http')) {
      return cat.imageUrl!;
    }

    final n = cat.name.toLowerCase();
    if (n.contains('indian')) {
      return 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=900&q=80';
    }
    if (n.contains('late night') || n.contains('burger') || n.contains('bites')) {
      return 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=900&q=80';
    }
    if (n.contains('starter') || n.contains('chaat') || n.contains('appetizer')) {
      return 'https://images.unsplash.com/photo-1541544741938-0af808871cc0?w=900&q=80';
    }
    if (n.contains('main') || n.contains('curry') || n.contains('karahi')) {
      return 'https://images.unsplash.com/photo-1544025162-d76694265947?w=900&q=80';
    }
    if (n.contains('dessert') || n.contains('sweet')) {
      return 'https://images.unsplash.com/photo-1551024709-8f23befc6f87?w=900&q=80';
    }
    if (n.contains('biryani') || n.contains('rice')) {
      return 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=900&q=80';
    }
    if (n.contains('cocktail')) {
      return 'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?w=900&q=80';
    }
    if (n.contains('mocktail')) {
      return 'https://images.unsplash.com/photo-1536935338788-846bb9981813?w=900&q=80';
    }
    if (n.contains('champagne')) {
      return 'https://images.unsplash.com/photo-1569919659476-f0852f6834b7?w=900&q=80';
    }
    if (n.contains('wine')) {
      return 'https://images.unsplash.com/photo-1510812431401-41d2bd2722f3?w=900&q=80';
    }
    if (n.contains('spirit') || n.contains('vodka') || n.contains('whisky') || n.contains('cognac')) {
      return 'https://images.unsplash.com/photo-1527281400683-1aae777175f8?w=900&q=80';
    }
    if (n.contains('beer') || n.contains('cider')) {
      return 'https://images.unsplash.com/photo-1608270544781-e2e77b679469?w=900&q=80';
    }
    if (n.contains('fruit')) {
      return 'https://images.unsplash.com/photo-1613478223719-2ab802602423?w=900&q=80';
    }
    if (n.contains('vip')) {
      return 'https://images.unsplash.com/photo-1529156069898-49953e39b3ac?w=900&q=80';
    }
    if (n.contains('shisha') || n.contains('flavour')) {
      return 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=900&q=80';
    }

    if (cat.menuType == 'food') {
      return 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=900&q=80';
    }
    if (cat.menuType == 'drinks') {
      return 'https://images.unsplash.com/photo-1514362545857-3bc16c4c7d1b?w=900&q=80';
    }
    return 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=900&q=80';
  }

  IconData _getCategoryIcon(String name, String menuType) {
    final n = name.toLowerCase();
    if (n.contains('indian')) return Icons.restaurant_menu_rounded;
    if (n.contains('late night')) return Icons.nightlife_rounded;
    if (n.contains('starter')) return Icons.tapas_rounded;
    if (n.contains('main')) return Icons.dinner_dining_rounded;
    if (n.contains('dessert')) return Icons.cake_rounded;
    if (n.contains('biryani') || n.contains('rice')) return Icons.rice_bowl_rounded;
    if (n.contains('cocktail')) return Icons.local_bar_rounded;
    if (n.contains('mocktail')) return Icons.local_drink_rounded;
    if (n.contains('wine')) return Icons.wine_bar_rounded;
    if (n.contains('champagne')) return Icons.liquor_rounded;
    if (n.contains('spirit') || n.contains('vodka') || n.contains('whisky')) {
      return Icons.local_fire_department_rounded;
    }
    if (n.contains('beer')) return Icons.sports_bar_rounded;
    if (n.contains('fruit')) return Icons.eco_rounded;
    if (n.contains('vip')) return Icons.workspace_premium_rounded;
    if (n.contains('shisha')) return Icons.cloud_rounded;

    if (menuType == 'food') return Icons.restaurant_rounded;
    if (menuType == 'drinks') return Icons.local_bar_rounded;
    return Icons.cloud_rounded;
  }
}
