import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/data/models/menu_item_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Beautiful Menu Card Widget
/// ═══════════════════════════════════════════════════════════════════════════
/// Standalone card component for menu items. Shows a discount ribbon when
/// discount_percentage > 0, with discounted price in gold and original price
/// struck through. Follows the full dark luxury design system.
class BeautifulMenuCard extends StatelessWidget {
  final MenuItemModel item;
  final VoidCallback? onTap;

  const BeautifulMenuCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image Section with Optional Discount Ribbon ────────────
            _buildImageSection(),

            // ── Content Section ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item Name
                  Text(
                    item.name,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Description
                  Text(
                    item.description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),

                  // Price Row
                  _buildPriceRow(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Stack(
        children: [
          // ── Image ───────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.imageUrl!,
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 140,
                      color: AppColors.surfaceLight,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.gold,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 140,
                      color: AppColors.surfaceLight,
                      child: const Icon(
                        Icons.restaurant_outlined,
                        color: AppColors.textHint,
                        size: 40,
                      ),
                    ),
                  )
                : Container(
                    height: 140,
                    color: AppColors.surfaceLight,
                    child: const Center(
                      child: Icon(
                        Icons.restaurant_outlined,
                        color: AppColors.textHint,
                        size: 40,
                      ),
                    ),
                  ),
          ),

          // ── Discount Ribbon (top-left, only if discounted) ──────────
          if (item.hasDiscount)
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.brandRed,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomRight: Radius.circular(10),
                  ),
                ),
                child: Text(
                  '${item.discountPercentage}% OFF',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPriceRow() {
    if (item.hasDiscount) {
      // ── Discounted: gold new price + struck-through original ────────
      return Row(
        children: [
          Text(
            item.discountedPriceFormatted,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.formattedPrice,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: AppColors.textHint,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.textHint,
            ),
          ),
        ],
      );
    }

    // ── Standard price (no discount) ──────────────────────────────────
    return Text(
      item.formattedPrice,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}
