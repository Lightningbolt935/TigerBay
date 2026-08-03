import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tigerbay_app/data/models/branch_model.dart';
import 'package:tigerbay_app/data/models/menu_item_model.dart';
import 'package:tigerbay_app/data/models/reward_item_model.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// ── Fetch all active branches ─────────────────────────────────────────────────

final branchListProvider = FutureProvider<List<Branch>>((ref) async {
  final client = ref.watch(supabaseClientProvider);

  final response = await client
      .from('branches')
      .select()
      .eq('is_active', true)
      .order('title');

  return (response as List)
      .map((row) => Branch.fromJson(row as Map<String, dynamic>))
      .toList();
});

// ── Active session branch (int id, nullable) ──────────────────────────────────

final activeBranchIdProvider = StateProvider<int?>((ref) => null);

final activeBranchProvider = Provider<Branch?>((ref) {
  final branchId = ref.watch(activeBranchIdProvider);
  final branchListAsync = ref.watch(branchListProvider);

  return branchListAsync.maybeWhen(
    data: (branches) {
      if (branchId == null) return null;
      try {
        return branches.firstWhere((b) => b.id == branchId);
      } catch (_) {
        return null;
      }
    },
    orElse: () => null,
  );
});

// ── Venue selection state notifier ────────────────────────────────────────────

class VenueSelectionState {
  final bool isSubmitting;
  final int? tappedBranchId;
  final String? error;

  const VenueSelectionState({
    this.isSubmitting = false,
    this.tappedBranchId,
    this.error,
  });

  VenueSelectionState copyWith({
    bool? isSubmitting,
    int? tappedBranchId,
    String? error,
    bool clearError = false,
    bool clearTapped = false,
  }) {
    return VenueSelectionState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      tappedBranchId: clearTapped ? null : (tappedBranchId ?? this.tappedBranchId),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class VenueSelectionNotifier extends StateNotifier<VenueSelectionState> {
  final SupabaseClient _client;
  final Ref _ref;

  VenueSelectionNotifier(this._client, this._ref)
      : super(const VenueSelectionState());

  Future<bool> selectBranch(Branch branch) async {
    if (state.isSubmitting) return false;

    state = state.copyWith(
      isSubmitting: true,
      tappedBranchId: branch.id,
      clearError: true,
    );

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No authenticated user found.');
      }

      await _client
          .from('profiles')
          .update({'last_selected_branch_id': branch.id})
          .eq('id', userId);

      await _client.from('user_login_sessions').insert({
        'user_id': userId,
        'selected_branch_id': branch.id,
      });

      _ref.read(activeBranchIdProvider.notifier).state = branch.id;

      state = state.copyWith(isSubmitting: false, clearTapped: true);
      return true;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        clearTapped: true,
        error: error.toString(),
      );
      return false;
    }
  }
}

final venueSelectionNotifierProvider =
    StateNotifierProvider<VenueSelectionNotifier, VenueSelectionState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return VenueSelectionNotifier(client, ref);
});

// ── Check whether the user needs to see the venue selection gate ─────────────

final needsVenueSelectionProvider = FutureProvider<bool>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return false;

  final response = await client
      .from('profiles')
      .select('last_selected_branch_id')
      .eq('id', userId)
      .single();

  return response['last_selected_branch_id'] == null;
});

// ── User profile raw map (for last_selected_branch_id lookup) ─────────────

final userProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final client = ref.watch(supabaseClientProvider);
  final userId = client.auth.currentUser?.id;
  if (userId == null) return null;

  final response = await client
      .from('profiles')
      .select('last_selected_branch_id')
      .eq('id', userId)
      .maybeSingle();

  return response;
});

// ── One-Time Init Session Branch Controller ───────────────────────────────
//
// Reads the user's profile `last_selected_branch_id` exactly once on app
// launch. After initialization, local `changeBranch` calls update state
// without re-triggering the profile fetch.

class SelectedBranchNotifier extends Notifier<Branch?> {
  bool _isInitialized = false;

  @override
  Branch? build() {
    if (_isInitialized) return state;

    try {
      final branchesAsync = ref.watch(branchListProvider);
      final profileAsync = ref.watch(userProfileProvider);

      final branchList = branchesAsync.valueOrNull;
      final profile = profileAsync.valueOrNull;

      if (branchList != null && profile != null) {
        _isInitialized = true;

        final rawBranchId = profile['last_selected_branch_id'];
        int? homeSiteId;

        if (rawBranchId != null) {
          if (rawBranchId is int) {
            homeSiteId = rawBranchId;
          } else if (rawBranchId is String) {
            homeSiteId = int.tryParse(rawBranchId);
          }
        }

        if (homeSiteId != null) {
          for (final branch in branchList) {
            if (branch.id == homeSiteId) return branch;
          }
        }
        return branchList.isNotEmpty ? branchList.first : null;
      }
    } catch (e, stack) {
      debugPrint('🚨 CRITICAL INIT ERROR: $e');
      debugPrint('$stack');
    }
    return null;
  }

  void changeBranch(Branch newBranch) {
    _isInitialized = true;
    state = newBranch;
  }
}

final selectedBranchProvider =
    NotifierProvider<SelectedBranchNotifier, Branch?>(
  SelectedBranchNotifier.new,
);

// ── Branch-filtered menu dishes ───────────────────────────────────────────────
//
// Accepts a nullable int branchId (from selectedBranch?.id).
// When non-null: returns dishes for that branch OR global dishes (branch_id IS NULL).
// When null: returns all available dishes unfiltered.

final menuForBranchProvider =
    FutureProvider.family<List<MenuItemModel>, int?>((ref, branchId) async {
  final client = ref.watch(supabaseClientProvider);

  final List<dynamic> response;
  if (branchId != null) {
    response = await client
        .from('dishes')
        .select('*')
        .eq('is_available', true)
        .or('branch_id.eq.$branchId,branch_id.is.null');
  } else {
    response = await client
        .from('dishes')
        .select('*')
        .eq('is_available', true);
  }

  return response
      .map((row) => MenuItemModel.fromJson(row as Map<String, dynamic>))
      .toList();
});

// ── Branch-filtered rewards ───────────────────────────────────────────────────
//
// Same pattern: branch-specific OR global rewards (branch_id IS NULL).

final rewardsForBranchProvider =
    FutureProvider.family<List<RewardItem>, int?>((ref, branchId) async {
  final client = ref.watch(supabaseClientProvider);

  final List<dynamic> response;
  if (branchId != null) {
    response = await client
        .from('rewards')
        .select('*')
        .eq('is_active', true)
        .or('branch_id.eq.$branchId,branch_id.is.null');
  } else {
    response = await client
        .from('rewards')
        .select('*')
        .eq('is_active', true);
  }

  return response
      .map((row) => RewardItem.fromMap(row as Map<String, dynamic>))
      .toList();
});
