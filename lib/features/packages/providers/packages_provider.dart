import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tigerbay_app/data/models/package_model.dart';

/// Provides the list of packages for a specific branch (or all branches if null)
final packagesProvider =
    FutureProvider.family<List<PackageModel>, int?>((ref, branchId) async {
  final client = Supabase.instance.client;

  // 1. Try querying public.packages table
  try {
    var query = client.from('packages').select();
    if (branchId != null) {
      query = query.or('branch_id.eq.$branchId,branch_id.is.null');
    }
    final response = await query.order('price', ascending: true);
    final list = (response as List)
        .map((row) => PackageModel.fromJson(row as Map<String, dynamic>))
        .where((p) => p.isActive)
        .toList();
    if (list.isNotEmpty) return list;
  } catch (_) {
    // packages table might not exist yet
  }

  // 2. Try querying public.venue_packages table
  try {
    var query = client.from('venue_packages').select();
    if (branchId != null) {
      query = query.or('branch_id.eq.$branchId,branch_id.is.null');
    }
    final response = await query.order('price', ascending: true);
    final list = (response as List)
        .map((row) => PackageModel.fromJson(row as Map<String, dynamic>))
        .where((p) => p.isActive)
        .toList();
    if (list.isNotEmpty) return list;
  } catch (_) {}

  // 3. Return curated default packages for Tiger Bay
  return PackageModel.defaultPackages(branchId: branchId);
});
