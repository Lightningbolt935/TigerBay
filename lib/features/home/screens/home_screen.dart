import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/core/constants/app_routes.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/features/home/screens/news_feed_component.dart';
import 'package:tigerbay_app/features/home/providers/home_provider.dart';
import 'package:tigerbay_app/features/notifications/providers/user_notifications_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesProvider);
    final selectedBranch = ref.watch(selectedBranchProvider);

    // ── Realtime app_configs stream ─────────────────────────────────────────
    // Re-renders the hero banner whenever banner_title / banner_subtitle is
    // edited directly inside Supabase dashboard (id = 1 row).
    final appConfig = ref.watch(appConfigStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── App Bar ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              'assets/images/tigerbay_logo.png',
                              width: 30,
                              height: 30,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.pets,
                                size: 24,
                                color: AppColors.brandRed,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'TigerBay',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 20,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 2,
                                color: AppColors.brandRed,),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Branch selector chip — luxury dark glassmorphic pill
                    branches.when(
                      data: (list) => _HomeBranchChip(
                        branches: list,
                        selected: selectedBranch ??
                            (list.isNotEmpty ? list.first : null),
                        onChanged: (b) =>
                            ref.read(selectedBranchProvider.notifier).changeBranch(b),
                      ),
                      loading: () => const SizedBox(
                        width: 130,
                        height: 32,
                        child: _ShimmerBox(radius: 20),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 4),
                    // ── Notification Bell with unread badge ─────────
                    IconButton(
                      icon: Badge(
                        isLabelVisible:
                            ref.watch(unreadNotificationCountProvider) > 0,
                        label: Text(
                          '${ref.watch(unreadNotificationCountProvider)}',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        backgroundColor: AppColors.brandRed,
                        child: const Icon(
                          Icons.notifications_outlined,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      onPressed: () =>
                          context.push(AppRoutes.notifications),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // ── Hero Banner (Realtime app_configs) ────────────────────────
            // Rebuilds whenever banner_title or banner_subtitle changes in DB.
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: appConfig.when(
                  loading: () => _HeroBanner(
                    title: null,
                    subtitle: null,
                    onReserve: () => context.go('${AppRoutes.myBookings}/new'),
                  ),
                  error: (_, __) => _HeroBanner(
                    title: null,
                    subtitle: null,
                    onReserve: () => context.go('${AppRoutes.myBookings}/new'),
                  ),
                  data: (config) => _HeroBanner(
                    title: config?.bannerTitle,
                    subtitle: config?.bannerSubtitle,
                    isPromoActive: config?.isPromoActive ?? false,
                    onReserve: () => context.go('${AppRoutes.myBookings}/new'),
                  ),
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),

            // ── Latest Updates header ────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'LATEST UPDATES',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white54,),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        // Sleek, presentation-safe fallback since the feed route doesn't exist yet
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'You are completely up to date! ✨',
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            backgroundColor: AppColors.brandRed,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                      child: const Text(
                        'See all',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.gold,),
                      ),
                    )
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // ── Newsfeed ─────────────────────────────────────────────────
            _NewsfeedList(branchId: selectedBranch?.id),

            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

// ── Hero Banner (driven by app_configs Realtime stream) ───────────────────────

class _HeroBanner extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final bool isPromoActive;
  final VoidCallback onReserve;

  const _HeroBanner({
    required this.onReserve,
    this.title,
    this.subtitle,
    this.isPromoActive = false,
  });

  @override
  Widget build(BuildContext context) {
    // Fallback strings when no DB config row exists yet
    final displayTitle = title ?? 'Exclusive Member\nSunset Soirée';
    final displaySubtitle = subtitle ?? 'THE TERRACE LOUNGE';

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            CachedNetworkImage(
              imageUrl:
                  'https://images.unsplash.com/photo-1600585154340-be6161a56a0c?w=800',
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: Colors.white12),
              errorWidget: (_, __, ___) =>
                  Container(color: Colors.white24),
            ),
            // Gradient overlay
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            // Content — reacts to banner_title / banner_subtitle from DB
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Promo badge — only shown when is_promo_active = true
                  if (isPromoActive)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'PROMO ACTIVE',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C1C1E),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  // banner_subtitle maps to the small label above the title
                  Text(
                    displaySubtitle.toUpperCase(),
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                      letterSpacing: 1.5,),
                  ),
                  const SizedBox(height: 4),
                  // banner_title is the main heading
                  Text(
                    displayTitle,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1E),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: onReserve,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Reserve Spot',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1C1C1E),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Newsfeed List ─────────────────────────────────────────────────────────────

class _NewsfeedList extends ConsumerWidget {
  final int? branchId;
  const _NewsfeedList({required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (branchId == null) {
      return const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Waiting for branch selection...'),
          ),
        ),
      );
    }

    final feed = ref.watch(newsfeedProvider(branchId!));
    return feed.when(
      data: (items) => items.isEmpty
          ? const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Center(
                  child: Text(
                    'STREAM ONLINE: NO NEWS FOUND FOR THIS BRANCH ID',
                    style: TextStyle(fontFamily: 'Poppins', color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          : SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: _NewsfeedCard(item: items[i]),
                ),
                childCount: items.length,
              ),
            ),
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: CircularProgressIndicator(
                color: AppColors.gold, strokeWidth: 2),
          ),
        ),
      ),
      error: (err, __) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'Feed Stream Error: $err',
              style: const TextStyle(fontFamily: 'Poppins', color: Colors.red, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _NewsfeedCard extends StatelessWidget {
  final NewsFeedItem item;

  const _NewsfeedCard({required this.item});

  String get _category => item.previewText.toUpperCase();
  String get _title => item.title;
  String get _timeAgo => item.timeAgoLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1C1C1E)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
            ),
            child: _buildNewsImage(item.imageUrl),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _category,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                        color: Colors.white54,),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _title,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.3,),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _timeAgo,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 11,
                      color: Colors.white38,),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  // ── Image helpers ──────────────────────────────────────────────────────────

  Widget _buildNewsImage(String? imageUrl) {
    final bool isValid = imageUrl != null && imageUrl.trim().isNotEmpty;

    if (!isValid) return _buildFallbackBanner();

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: 88,
      height: 88,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        width: 88,
        height: 88,
        color: const Color(0xFF2C2C2E),
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFC9A84C),
            ),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        debugPrint('NewsfeedCard: failed to load image: $url -> $error');
        return _buildFallbackBanner();
      },
    );
  }

  Widget _buildFallbackBanner() {
    return Container(
      width: 88,
      height: 88,
      color: const Color(0xFF2C2C2E),
      child: const Icon(
        Icons.newspaper,
        color: Color(0xFFC9A84C),
        size: 28,
      ),
    );
  }
}


// ── Branch chip + luxury picker (Home screen) ────────────────────────────────

class _HomeBranchChip extends StatelessWidget {
  final List<Branch> branches;
  final Branch? selected;
  final ValueChanged<Branch> onChanged;

  const _HomeBranchChip({
    required this.branches,
    required this.selected,
    required this.onChanged,
  });

  static const Color _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showPicker(context),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_rounded,
                color: _gold,
                size: 14,
              ),
              const SizedBox(width: 5),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  selected?.title ?? 'Select Branch',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withValues(alpha: 0.6),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121212),
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            const Row(
              children: [
                Icon(Icons.location_on_rounded, color: _gold, size: 20),
                SizedBox(width: 8),
                Text(
                  'Select Branch',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Branch cards
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: branches.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, index) {
                  final b = branches[index];
                  final bool isSelected = selected?.id == b.id;

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        onChanged(b);
                        Navigator.pop(ctx);
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _gold.withValues(alpha: 0.12)
                              : const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? _gold
                                : Colors.white.withValues(alpha: 0.08),
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.title,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFFE4E4E7),
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (b.city != null &&
                                      b.city!.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      b.city!,
                                      style: TextStyle(
                                        color: isSelected
                                            ? _gold
                                            : const Color(0xFFA1A1AA),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (isSelected)
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  color: _gold,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  color: Colors.black,
                                  size: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer placeholder ───────────────────────────────────────────────────────

class _ShimmerBox extends StatelessWidget {
  final double radius;
  const _ShimmerBox({required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}