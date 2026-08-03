import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tigerbay_app/core/constants/app_colors.dart';
import 'package:tigerbay_app/data/models/notification_item.dart';
import 'package:tigerbay_app/features/notifications/providers/user_notifications_provider.dart';
import 'package:tigerbay_app/shared/widgets/tigerbay_brand_header.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Notifications Screen
/// ═══════════════════════════════════════════════════════════════════════════
/// Real-time list of the logged-in user's notifications, scoped via RLS.
/// New rows from INSERT/UPDATE events on `user_notifications` appear
/// instantly via the Supabase Realtime stream — no pull-to-refresh needed.
///
/// Icon, badge color and card accent adapt per notification [type]:
///   • birthday  → 🎂  pink
///   • broadcast → 📣  blue
///   • system    → 🔧  orange
///   • promo     → 🏷️  gold
///   • (others)  → 🔔  textSecondary

// ── Date Formatting Helpers ─────────────────────────────────────────────────

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime dt) {
  final day = dt.day.toString().padLeft(2, '0');
  final month = _months[dt.month - 1];
  return '$day $month ${dt.year}';
}

String _formatTimestamp(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  return _formatDate(dt);
}

// ── Type → Icon / Color resolution ─────────────────────────────────────────

/// Returns the icon and accent color for a given notification type.
/// Matches the spec: birthday=pink, system=orange, broadcast=blue, promo=gold.
({IconData icon, Color color}) _resolveTypeStyle(String type) {
  switch (type) {
    case 'birthday':
      return (icon: Icons.cake_outlined, color: const Color(0xFFEC407A));
    case 'system':
      return (icon: Icons.build_circle_outlined, color: const Color(0xFFFF9500));
    case 'promo':
      return (icon: Icons.local_offer_rounded, color: AppColors.gold);
    case 'loyalty':
      return (icon: Icons.stars_rounded, color: AppColors.gold);
    case 'booking':
      return (icon: Icons.calendar_today_rounded, color: const Color(0xFF5C6BC0));
    case 'broadcast':
    default:
      return (icon: Icons.campaign_outlined, color: const Color(0xFF42A5F5));
  }
}

// ═══════════════════════════════════════════════════════════════════════════

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: AppColors.brandBlack,
      body: Column(
        children: [
          // ── Brand Header with "Mark all read" action ──────────────────
          TigerBayBrandHeader(
            showBackButton: true,
            actions: [
              if (unreadCount > 0)
                GestureDetector(
                  onTap: () =>
                      ref.read(notificationsProvider.notifier).markAllAsRead(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      'Mark all read',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // ── Section title + unread badge ──────────────────────────────
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  'NOTIFICATIONS',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(width: 8),
                if (unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.brandRed,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                const Spacer(),
                // Realtime indicator dot
                _RealtimeIndicator(),
              ],
            ),
          ),

          // ── Notification List ─────────────────────────────────────────
          Expanded(
            child: notificationsAsync.when(
              // ── Loading: Shimmer skeleton tiles ──────────────────────
              loading: () => ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, __) => const _ShimmerNotificationTile(),
              ),

              // ── Error: Message + Retry ────────────────────────────────
              error: (err, __) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.wifi_off_rounded,
                          size: 32,
                          color: AppColors.error,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Could not load notifications',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Please check your connection and try again.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () => ref
                            .read(notificationsProvider.notifier)
                            .refresh(),
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(
                          'Retry',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.gold,
                          side: const BorderSide(color: AppColors.gold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Data ─────────────────────────────────────────────────
              data: (notifications) {
                // ── Empty: "All caught up" state ──────────────────────
                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 40,
                            color: AppColors.gold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          "You're all caught up!",
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'No notifications yet.\nWe\'ll let you know when something arrives.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: AppColors.textHint,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    return _NotificationTile(
                      notification: notification,
                      onTap: () {
                        // Optimistic mark-as-read (instant UI feedback)
                        if (!notification.isRead) {
                          ref
                              .read(notificationsProvider.notifier)
                              .markAsRead(notification.id);
                        }
                        // Show full notification detail in bottom sheet
                        if (context.mounted) {
                          _showNotificationDetail(context, notification);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Detail Bottom Sheet ─────────────────────────────────────────────────

  void _showNotificationDetail(
    BuildContext context,
    NotificationItem notification,
  ) {
    final style = _resolveTypeStyle(notification.type);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Type chip + icon
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(style.icon, color: style.color, size: 22),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: style.color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    notification.type.toUpperCase(),
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: style.color,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              notification.title,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),

            // Timestamp
            Text(
              _formatTimestamp(notification.createdAt),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.textHint,
              ),
            ),
            const SizedBox(height: 16),

            // Body
            Text(
              notification.body,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Realtime Indicator ──────────────────────────────────────────────────────

/// Animated green dot shown at the top of the list to indicate the
/// realtime subscription is active.
class _RealtimeIndicator extends StatefulWidget {
  @override
  State<_RealtimeIndicator> createState() => _RealtimeIndicatorState();
}

class _RealtimeIndicatorState extends State<_RealtimeIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _pulse,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF34C759),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: GoogleFonts.poppins(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF34C759),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Notification Tile ───────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = _resolveTypeStyle(notification.type);
    final accentColor = notification.isRead ? AppColors.textSecondary : style.color;
    final iconBg = notification.isRead
        ? AppColors.surfaceLight
        : style.color.withValues(alpha: 0.12);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: notification.isRead
              ? null
              : Border.all(
                  color: style.color.withValues(alpha: 0.30),
                  width: 1,
                ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Type icon / Avatar image ────────────────────────────────
            _buildNotificationIcon(
              notification.imageUrl,
              notification.type,
              accentColor,
              iconBg,
            ),

            const SizedBox(width: 12),

            // ── Title, Body Preview & Timestamp ───────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: notification.isRead
                          ? FontWeight.w400
                          : FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    notification.body,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        _formatTimestamp(notification.createdAt),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: AppColors.textHint,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Type label pill (only on unread)
                      if (!notification.isRead)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: style.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            notification.type,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: style.color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Unread indicator dot ───────────────────────────────────
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, left: 8),
                decoration: BoxDecoration(
                  color: style.color,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Icon helpers ────────────────────────────────────────────────────────

  /// Shows a [CachedNetworkImage] when [imageUrl] is a valid, non-empty URL;
  /// otherwise falls back to the type-appropriate icon inside a styled box.
  Widget _buildNotificationIcon(
    String? imageUrl,
    String type,
    Color accentColor,
    Color iconBg,
  ) {
    final bool hasValidUrl = imageUrl != null && imageUrl.trim().isNotEmpty;

    if (!hasValidUrl) {
      return _buildTypeFallbackIcon(type, accentColor, iconBg);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: 42,
        height: 42,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) =>
            _buildTypeFallbackIcon(type, accentColor, iconBg),
      ),
    );
  }

  Widget _buildTypeFallbackIcon(
    String type,
    Color accentColor,
    Color iconBg,
  ) {
    final style = _resolveTypeStyle(type);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: iconBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        style.icon,
        color: accentColor,
        size: 20,
      ),
    );
  }
}

// ── Shimmer Skeleton Tile ──────────────────────────────────────────────────

class _ShimmerNotificationTile extends StatefulWidget {
  const _ShimmerNotificationTile();

  @override
  State<_ShimmerNotificationTile> createState() =>
      _ShimmerNotificationTileState();
}

class _ShimmerNotificationTileState extends State<_ShimmerNotificationTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.08, end: 0.20).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final shimmerColor = Colors.white.withValues(alpha: _animation.value);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon placeholder
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Body
                    Container(
                      height: 11,
                      width: 180,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Timestamp
                    Container(
                      height: 10,
                      width: 60,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
