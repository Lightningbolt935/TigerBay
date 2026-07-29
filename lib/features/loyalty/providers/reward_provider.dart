import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/reward_item_model.dart';
import '../../../data/models/strips_ledger_entry.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/profile_state_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TigerBay International — Reward & Strips Providers
// ═══════════════════════════════════════════════════════════════════════════

/// Fetch all active rewards for the Reward Store.
final rewardsProvider = FutureProvider<List<RewardItem>>((ref) async {
  final repo = ref.watch(supabaseRepositoryProvider);
  return repo.fetchRewards();
});

/// Fetch the user's Strips transaction history.
final stripsLedgerProvider =
    FutureProvider<List<StripsLedgerEntry>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final repo = ref.watch(supabaseRepositoryProvider);
  return repo.fetchStripsLedger(user.id);
});

// ── Reward Redemption State ───────────────────────────────────────────────

class RedeemState {
  final bool isProcessing;
  final bool isSuccess;
  final String? error;
  final RewardItem? redeemedItem;

  const RedeemState({
    this.isProcessing = false,
    this.isSuccess = false,
    this.error,
    this.redeemedItem,
  });

  RedeemState copyWith({
    bool? isProcessing,
    bool? isSuccess,
    String? error,
    RewardItem? redeemedItem,
    bool clearError = false,
    bool clearRedeemed = false,
  }) {
    return RedeemState(
      isProcessing: isProcessing ?? this.isProcessing,
      isSuccess: isSuccess ?? this.isSuccess,
      error: clearError ? null : (error ?? this.error),
      redeemedItem:
          clearRedeemed ? null : (redeemedItem ?? this.redeemedItem),
    );
  }
}

class RedeemNotifier extends StateNotifier<RedeemState> {
  final Ref _ref;

  RedeemNotifier(this._ref) : super(const RedeemState());

  /// Attempt to redeem a reward. Checks balance, deducts Strips, inserts
  /// ledger entry, and refreshes the profile state.
  Future<bool> redeem(RewardItem reward) async {
    if (state.isProcessing) return false;
    state = state.copyWith(
      isProcessing: true,
      clearError: true,
      isSuccess: false,
      clearRedeemed: true,
    );

    try {
      final user = _ref.read(currentUserProvider);
      if (user == null) throw Exception('Not authenticated.');

      final repo = _ref.read(supabaseRepositoryProvider);
      await repo.redeemReward(
        userId: user.id,
        rewardId: reward.id,
        stripsCost: reward.stripsCost,
        rewardTitle: reward.title,
      );

      // Refresh profile to get updated strips_balance
      await _ref.read(profileStateProvider.notifier).refreshProfile();
      // Refresh ledger
      _ref.invalidate(stripsLedgerProvider);

      state = state.copyWith(
        isProcessing: false,
        isSuccess: true,
        redeemedItem: reward,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        isSuccess: false,
        error: e.toString(),
      );
      return false;
    }
  }

  void reset() => state = const RedeemState();
}

final redeemNotifierProvider =
    StateNotifierProvider<RedeemNotifier, RedeemState>((ref) {
  return RedeemNotifier(ref);
});
