import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'branch_provider.dart';

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
      previewText: json['preview_text'] as String? ?? '',
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

// ── Reactive newsfeed stream — global when activeBranchId is null,
//    localized to that branch otherwise ────────────────────────────────────────

final newsFeedStreamProvider =
    StreamProvider.autoDispose<List<NewsFeedItem>>((ref) {
  final client = ref.watch(supabaseClientProvider);
  final branchId = ref.watch(activeBranchIdProvider);

  if (branchId == null) {
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

  return client
      .from('newsfeed')
      .stream(primaryKey: ['id'])
      .eq('branch_id', branchId)
      .order('created_at')
      .map((rows) =>
          rows.map((row) => NewsFeedItem.fromJson(row)).toList().reversed.toList());
});

// ── Convenience label for section header text ─────────────────────────────────

final newsFeedSectionLabelProvider = Provider<String>((ref) {
  final branchId = ref.watch(activeBranchIdProvider);
  return branchId == null ? 'CORPORATE ANNOUNCEMENTS' : 'VENUE UPDATES';
});

final newsFeedEmptyMessageProvider = Provider<String>((ref) {
  final branchId = ref.watch(activeBranchIdProvider);
  return branchId == null
      ? 'No corporate announcements right now.'
      : 'No updates for this venue yet.';
});
