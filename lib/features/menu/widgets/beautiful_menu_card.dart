import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/data/models/menu_item_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Beautiful Menu Card Widget
/// ═══════════════════════════════════════════════════════════════════════════
/// Standalone card component for menu items. Supports multi-image carousels
/// with page indicators when multiple images are detected, shows a discount
/// ribbon when discount_percentage > 0, with discounted price in gold and
/// original price struck through. Follows the full dark luxury design system.
class BeautifulMenuCard extends StatefulWidget {
  final MenuItemModel item;
  final VoidCallback? onTap;

  const BeautifulMenuCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  State<BeautifulMenuCard> createState() => _BeautifulMenuCardState();
}

class _BeautifulMenuCardState extends State<BeautifulMenuCard> {
  int _currentImageIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
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
            // ── Image / Multi-Image Carousel Section ───────────────────
            _buildImageSection(),

            // ── Content Section ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Item Name
                  Text(
                    widget.item.name,
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
                    widget.item.description,
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
    final images = widget.item.images.isNotEmpty
        ? widget.item.images
        : (widget.item.imageUrl != null && widget.item.imageUrl!.isNotEmpty
            ? [widget.item.imageUrl!]
            : <String>[]);

    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Stack(
        children: [
          // ── Image or Carousel ───────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: images.isEmpty
                ? _buildPlaceholderImage()
                : images.length == 1
                    ? _buildSingleNetworkImage(images.first)
                    : PageView.builder(
                        controller: _pageController,
                        itemCount: images.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return _buildSingleNetworkImage(images[index]);
                        },
                      ),
          ),

          // ── Carousel Dots & Badge (only when 2+ images exist) ───────
          if (images.length > 1) ...[
            // Bottom Indicator Dots
            Positioned(
              bottom: 8,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2.5),
                    width: _currentImageIndex == index ? 14 : 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _currentImageIndex == index
                          ? AppColors.gold
                          : Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),

            // Top-right Image Counter Badge
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.photo_library_outlined,
                      size: 11,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${_currentImageIndex + 1}/${images.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Discount Ribbon (top-left, only if discounted) ──────────
          if (widget.item.hasDiscount)
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
                  '${widget.item.discountPercentage}% OFF',
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

  Widget _buildSingleNetworkImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
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
      errorWidget: (_, __, ___) => _buildPlaceholderImage(),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 140,
      color: AppColors.surfaceLight,
      child: const Center(
        child: Icon(
          Icons.restaurant_outlined,
          color: AppColors.textHint,
          size: 40,
        ),
      ),
    );
  }

  Widget _buildPriceRow() {
    if (widget.item.hasDiscount) {
      // ── Discounted: gold new price + struck-through original ────────
      return Row(
        children: [
          Text(
            widget.item.discountedPriceFormatted,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.item.formattedPrice,
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
      widget.item.formattedPrice,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}
