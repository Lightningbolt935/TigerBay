import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reactive home-screen feed component.
///
/// Behaviour:
///   - If [activeBranchId] is null  -> loads GLOBAL corporate
///     announcements only (rows where `branch_id IS NULL`).
///   - If [activeBranchId] is set   -> loads that branch's LOCAL feed
///     (rows where `branch_id = activeBranchId`).
///
/// Pass the user's current session branch id (an `int`, or null) in from
/// whatever app-state/provider holds it — this widget itself stays
/// stateless with respect to session management and simply reacts to
/// the value it's given.
class NewsFeedComponent extends StatefulWidget {
  /// The currently active branch for this session. Pass `null` to force
  /// the global corporate announcements feed.
  final int? activeBranchId;

  const NewsFeedComponent({super.key, this.activeBranchId});

  @override
  State<NewsFeedComponent> createState() => _NewsFeedComponentState();
}

class _NewsFeedComponentState extends State<NewsFeedComponent> {
  late Stream<List<NewsFeedItem>> _feedStream;

  static const Color _gold = Color(0xFFC9A84C);

  @override
  void initState() {
    super.initState();
    _feedStream = _buildStream(widget.activeBranchId);
  }

  @override
  void didUpdateWidget(covariant NewsFeedComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-subscribe whenever the active branch changes (e.g. the user
    // switches venues mid-session) so the feed swaps from global to
    // local, or vice versa, without requiring a full widget rebuild tree.
    if (oldWidget.activeBranchId != widget.activeBranchId) {
      setState(() {
        _feedStream = _buildStream(widget.activeBranchId);
      });
    }
  }

  Stream<List<NewsFeedItem>> _buildStream(int? branchId) {
    final client = Supabase.instance.client;

    if (branchId == null) {
      // ── Global corporate announcements feed ──────────────────────────
      return client
          .from('newsfeed')
          .stream(primaryKey: ['id'])
          .order('created_at')
          .map((rows) => rows
              .where((row) => row['branch_id'] == null)
              .map((row) => NewsFeedItem.fromJson(row))
              .toList()
              .reversed
              .toList());
    }

    // ── Localized branch feed ────────────────────────────────────────────
    return client
        .from('newsfeed')
        .stream(primaryKey: ['id'])
        .eq('branch_id', branchId)
        .order('created_at')
        .map((rows) =>
            rows.map((row) => NewsFeedItem.fromJson(row)).toList().reversed.toList());
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NewsFeedItem>>(
      stream: _feedStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: CircularProgressIndicator(color: _gold, strokeWidth: 2),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load updates: ${snapshot.error}',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: Color(0xFFFF3B30),
              ),
            ),
          );
        }

        final items = snapshot.data ?? [];

        if (items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                widget.activeBranchId == null
                    ? 'No corporate announcements right now.'
                    : 'No updates for this venue yet.',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Color(0xFF6C6C70),
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Text(
                widget.activeBranchId == null
                    ? 'CORPORATE ANNOUNCEMENTS'
                    : 'VENUE UPDATES',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Color(0xFF6C6C70),
                ),
              ),
            ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) => _NewsFeedCard(item: items[index]),
            ),
          ],
        );
      },
    );
  }
}

// ── Feed item model ───────────────────────────────────────────────────────────

class NewsFeedItem {
  final String id;
  final int? branchId;
  /// Sanitized image URL. Null when the DB value is empty or absent.
  /// Relative paths are expanded to full Supabase Storage public URLs.
  final String? imageUrl;
  final String title;
  final String previewText;
  final DateTime createdAt;

  const NewsFeedItem({
    required this.id,
    required this.branchId,
    this.imageUrl,
    required this.title,
    required this.previewText,
    required this.createdAt,
  });

  factory NewsFeedItem.fromJson(Map<String, dynamic> json) {
    // Resolves a raw DB value into a usable URL:
    //  • null / empty  → null
    //  • already full URL → returned as-is
    //  • relative path → expanded to Supabase Storage public URL
    String? formatImageUrl(dynamic raw) {
      if (raw == null) return null;
      final clean = raw.toString().trim();
      if (clean.isEmpty) return null;
      if (clean.startsWith('http://') || clean.startsWith('https://')) {
        return clean;
      }
      const supabaseUrl = 'https://xxnqlktcbwqhoyezlokv.supabase.co';
      const bucket = 'news';
      return '$supabaseUrl/storage/v1/object/public/$bucket/$clean';
    }

    return NewsFeedItem(
      id: json['id'].toString(),
      branchId: json['branch_id'] as int?,
      imageUrl: formatImageUrl(json['image_url'] ?? json['banner_url']),
      title: json['title'] as String? ?? '',
      previewText: (json['preview_text'] ?? json['subtitle'] ?? json['content'] ?? '') as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  String get timeAgoLabel {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays}d ago';
  }
}

// ── Feed card widget ───────────────────────────────────────────────────────────

class _NewsFeedCard extends StatelessWidget {
  final NewsFeedItem item;
  const _NewsFeedCard({required this.item});

  static const Color _black = Color(0xFF0A0A0A);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Large premium image header ────────────────────────────────
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _buildNewsImage(item.imageUrl),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.timeAgoLabel,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Color(0xFFAEAEB2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _black,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item.previewText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: Color(0xFF6C6C70),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Image helpers ────────────────────────────────────────────────────────


  /// Uses [CachedNetworkImage] for valid URLs, falls back to a branded
  /// placeholder when [imageUrl] is null, empty, or fails to load.
  Widget _buildNewsImage(String? imageUrl) {
    final bool isValid = imageUrl != null && imageUrl.trim().isNotEmpty;

    if (!isValid) return _buildFallbackBanner();

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      placeholder: (context, url) => Container(
        color: Colors.grey[900],
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFC9A84C),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        debugPrint('NewsFeedCard: failed to load image: $url → $error');
        return _buildFallbackBanner();
      },
    );
  }

  Widget _buildFallbackBanner() {
    return Container(
      color: Colors.grey[900],
      child: const Center(
        child: Icon(
          Icons.newspaper,
          color: Color(0xFFC9A84C),
          size: 40,
        ),
      ),
    );
  }
}
