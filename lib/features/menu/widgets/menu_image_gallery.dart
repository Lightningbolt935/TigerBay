import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Luxury Menu Image Gallery
/// ═══════════════════════════════════════════════════════════════════════════
/// Full-screen luxury image gallery for viewing multiple dish photos.
/// Features:
///  • Free horizontal swipe & slide gestures between photos (PageView)
///  • Pinch-to-zoom & double-tap to zoom with InteractiveViewer
///  • Left & Right navigation chevrons for direct tap-sliding
///  • Bottom interactive thumbnail strip with active gold highlight
///  • Slide indicator and photo counter (e.g. "Photo 2 of 3")
///  • Floating bottom card with dish name, category, and price
class MenuImageGallery extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String? dishName;
  final String? category;
  final String? price;
  final String? description;

  const MenuImageGallery({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.dishName,
    this.category,
    this.price,
    this.description,
  });

  @override
  State<MenuImageGallery> createState() => _MenuImageGalleryState();
}

class _MenuImageGalleryState extends State<MenuImageGallery> {
  late final PageController _pageController;
  late final ScrollController _thumbnailController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(
        0, widget.imageUrls.isEmpty ? 0 : widget.imageUrls.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailController = ScrollController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _scrollThumbnailToVisible(index);
  }

  void _scrollThumbnailToVisible(int index) {
    if (!_thumbnailController.hasClients) return;
    const itemWidth = 64.0;
    final targetOffset = (index * itemWidth) - 100.0;
    _thumbnailController.animateTo(
      targetOffset.clamp(0.0, _thumbnailController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _goToPage(int index) {
    if (index < 0 || index >= widget.imageUrls.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final hasMultiple = widget.imageUrls.length > 1;

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Main PageView with Non-Blocking Zoomable Image ────────────────
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.imageUrls.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              return _ZoomableGalleryImage(
                imageUrl: widget.imageUrls[index],
              );
            },
          ),

          // ── Top Navigation Bar ────────────────────────────────────────────
          Positioned(
            top: topPadding + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close button
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                          width: 0.8,
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),

                // Photo Counter & Slide Hint
                if (hasMultiple)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.swipe_rounded,
                              size: 14,
                              color: AppColors.gold,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_currentIndex + 1} of ${widget.imageUrls.length} • Slide',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Left Navigation Chevron (tap to slide prev) ───────────────────
          if (hasMultiple && _currentIndex > 0)
            Positioned(
              left: 12,
              top: 0,
              bottom: 120,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () => _goToPage(_currentIndex - 1),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Right Navigation Chevron (tap to slide next) ──────────────────
          if (hasMultiple && _currentIndex < widget.imageUrls.length - 1)
            Positioned(
              right: 12,
              top: 0,
              bottom: 120,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(Icons.arrow_forward_ios_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () => _goToPage(_currentIndex + 1),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // ── Bottom Floating Card with Info & Thumbnails ───────────────────
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomPadding + 14,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.76),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dish Title & Price Row
                      if (widget.dishName != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.category != null &&
                                      widget.category!.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold
                                            .withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        widget.category!.toUpperCase(),
                                        style: GoogleFonts.poppins(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                          color: AppColors.gold,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    widget.dishName!,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (widget.price != null &&
                                widget.price!.isNotEmpty)
                              Text(
                                widget.price!,
                                style: GoogleFonts.poppins(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold,
                                ),
                              ),
                          ],
                        ),
                        if (widget.description != null &&
                            widget.description!.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.description!,
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],

                      // Thumbnail Strip (Tap to jump directly to any photo)
                      if (hasMultiple) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Text(
                              'SLIDE PHOTOS',
                              style: GoogleFonts.poppins(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.champagneGold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'Tap any photo to view',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 54,
                          child: ListView.separated(
                            controller: _thumbnailController,
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.imageUrls.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, thumbIdx) {
                              final isSelected = thumbIdx == _currentIndex;
                              return GestureDetector(
                                onTap: () => _goToPage(thumbIdx),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.gold
                                          : Colors.white
                                              .withValues(alpha: 0.25),
                                      width: isSelected ? 2.4 : 0.8,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: AppColors.gold
                                                  .withValues(alpha: 0.45),
                                              blurRadius: 10,
                                              spreadRadius: 1,
                                            )
                                          ]
                                        : null,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: widget.imageUrls[thumbIdx],
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: AppColors.surfaceLight,
                                      ),
                                      errorWidget: (_, __, ___) => Container(
                                        color: AppColors.surfaceLight,
                                        child: const Icon(
                                          Icons.image_outlined,
                                          size: 16,
                                          color: AppColors.textHint,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Zoomable Gallery Image that only enables pan when zoomed in,
/// so normal horizontal swipes are smoothly captured by the parent PageView!
class _ZoomableGalleryImage extends StatefulWidget {
  final String imageUrl;

  const _ZoomableGalleryImage({required this.imageUrl});

  @override
  State<_ZoomableGalleryImage> createState() => _ZoomableGalleryImageState();
}

class _ZoomableGalleryImageState extends State<_ZoomableGalleryImage> {
  late final TransformationController _transformController;
  bool _isZoomed = false;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _transformController.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    final scale = _transformController.value.getMaxScaleOnAxis();
    final isZoomed = scale > 1.05;
    if (isZoomed != _isZoomed) {
      setState(() => _isZoomed = isZoomed);
    }
  }

  void _handleDoubleTap() {
    if (_isZoomed) {
      _transformController.value = Matrix4.identity();
      setState(() => _isZoomed = false);
    } else {
      _transformController.value = Matrix4.diagonal3Values(2.5, 2.5, 1.0);
      setState(() => _isZoomed = true);
    }
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  Widget _buildImageContent() {
    return Center(
      child: CachedNetworkImage(
        imageUrl: widget.imageUrl,
        fit: BoxFit.contain,
        placeholder: (_, __) => const Center(
          child: CircularProgressIndicator(
            color: AppColors.gold,
            strokeWidth: 2,
          ),
        ),
        errorWidget: (_, __, ___) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.broken_image_rounded,
                color: AppColors.textHint,
                size: 48,
              ),
              const SizedBox(height: 8),
              Text(
                'Image unavailable',
                style: GoogleFonts.poppins(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isZoomed) {
      // Normal state: Pure CachedNetworkImage wrapped in GestureDetector for double tap!
      // NO InteractiveViewer in the tree at all!
      // This guarantees 100% unimpeded horizontal swiping in the parent PageView!
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTap: _handleDoubleTap,
        child: _buildImageContent(),
      );
    }

    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _transformController,
        minScale: 1.0,
        maxScale: 4.0,
        panEnabled: true,
        scaleEnabled: true,
        child: _buildImageContent(),
      ),
    );
  }
}

/// Helper function to open the luxury image gallery
void showMenuImageGallery(
  BuildContext context,
  List<String> imageUrls, {
  int initialIndex = 0,
  String? dishName,
  String? category,
  String? price,
  String? description,
}) {
  if (imageUrls.isEmpty) return;
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      pageBuilder: (context, animation, secondaryAnimation) => MenuImageGallery(
        imageUrls: imageUrls,
        initialIndex: initialIndex,
        dishName: dishName,
        category: category,
        price: price,
        description: description,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}