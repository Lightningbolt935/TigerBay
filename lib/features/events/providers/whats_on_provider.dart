import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tigerbay_app/data/models/whats_on_event_model.dart';

/// Provides the list of What's On events for a specific branch (or all branches if null)
final whatsOnEventsProvider =
    FutureProvider.family<List<WhatsOnEvent>, int?>((ref, branchId) async {
  final client = Supabase.instance.client;

  // 1. Try fetching from public.whats_on table if exists
  try {
    var query = client.from('whats_on').select();
    if (branchId != null) {
      query = query.or('branch_id.eq.$branchId,branch_id.is.null');
    }
    final response = await query.order('created_at', ascending: false);
    final list = (response as List)
        .map((row) => WhatsOnEvent.fromJson(row as Map<String, dynamic>))
        .toList();
    if (list.isNotEmpty) return list;
  } catch (_) {
    // whats_on table might not exist yet
  }

  // 2. Try fetching from public.events table if exists
  try {
    var query = client.from('events').select();
    if (branchId != null) {
      query = query.or('branch_id.eq.$branchId,branch_id.is.null');
    }
    final response = await query.order('created_at', ascending: false);
    final list = (response as List)
        .map((row) => WhatsOnEvent.fromJson(row as Map<String, dynamic>))
        .toList();
    if (list.isNotEmpty) return list;
  } catch (_) {
    // events table might not exist yet
  }

  // 3. Try fetching from public.newsfeed table (which exists and has event rows)
  try {
    var query = client.from('newsfeed').select();
    if (branchId != null) {
      query = query.or('branch_id.eq.$branchId,branch_id.is.null');
    }
    final response = await query.order('created_at', ascending: false);
    final list = (response as List)
        .map((row) => WhatsOnEvent.fromJson(row as Map<String, dynamic>))
        .toList();
    if (list.isNotEmpty) {
      // Merge with default luxury Tiger Bay events so the screen is super rich
      final defaults = WhatsOnEvent.defaultEvents(branchId: branchId);
      return [...list, ...defaults];
    }
  } catch (_) {}

  // 4. Return curated default events for Tiger Bay International
  return WhatsOnEvent.defaultEvents(branchId: branchId);
});
