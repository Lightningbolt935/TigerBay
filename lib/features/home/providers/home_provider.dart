import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tigerbay_app/data/models/app_config_model.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/data/repositories/menu_repository.dart';
import 'package:tigerbay_app/features/home/screens/news_feed_component.dart';

// Re-export selectedBranchProvider so existing consumer imports keep working.
export 'package:tigerbay_app/features/home/providers/branch_provider.dart'
    show selectedBranchProvider;

final menuRepositoryProvider = Provider<MenuRepository>((ref) => MenuRepository());

// ── Branches (public.branches) ────────────────────────────────────────────────

final branchesProvider = FutureProvider<List<Branch>>((ref) async {
  return ref.read(menuRepositoryProvider).getBranches();
});

// ── Newsfeed ──────────────────────────────────────────────────────────────────

final newsfeedProvider = FutureProvider.family<List<NewsFeedItem>, int>(
  (ref, branchId) async {
    return ref.read(menuRepositoryProvider).getNewsfeed(branchId: branchId);
  },
);

// ── App Config Realtime Stream (public.app_configs, id = 1) ──────────────────
//
// Supabase Realtime is enabled on app_configs. This stream re-emits
// the banner_title and banner_subtitle whenever a DB edit is saved.

final appConfigStreamProvider = StreamProvider<AppConfigModel?>((ref) {
  return Supabase.instance.client
      .from('app_configs')
      .stream(primaryKey: ['id'])
      .eq('id', 1)
      .map((rows) => rows.isEmpty ? null : AppConfigModel.fromJson(rows.first));
});
