import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/strips_ledger_entry.dart';
import '../../../data/repositories/loyalty_repository.dart';
import '../../auth/providers/auth_provider.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Loyalty Providers (Strips System)
/// ═══════════════════════════════════════════════════════════════════════════

final loyaltyRepositoryProvider =
    Provider<LoyaltyRepository>((ref) => LoyaltyRepository());

// ── Strips balance stream (realtime from profiles table) ──────────────────

final stripsBalanceStreamProvider = StreamProvider<int>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.read(loyaltyRepositoryProvider).watchStripsBalance(user.id);
});

// ── Strips transaction history ────────────────────────────────────────────

final stripsTransactionsProvider =
    FutureProvider<List<StripsLedgerEntry>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref
      .read(loyaltyRepositoryProvider)
      .getStripsLedger(user.id);
});

// ── QR secret (used by QrTimer) ───────────────────────────────────────────

final qrSecretProvider = FutureProvider<String>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return '';
  return ref.read(loyaltyRepositoryProvider).generateQrSecret(user.id);
});

// ── Loyalty notifier (for actions: redeem, link card) ─────────────────────

class LoyaltyNotifier extends StateNotifier<AsyncValue<void>> {
  final LoyaltyRepository _repo;
  final String _userId;

  LoyaltyNotifier(this._repo, this._userId)
      : super(const AsyncValue.data(null));

  Future<bool> linkPhysicalCard(String cardNumber) async {
    state = const AsyncValue.loading();
    try {
      await _repo.linkPhysicalCard(
          userId: _userId, cardNumber: cardNumber);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> redeemStrips({
    required int amount,
    required String description,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repo.redeemStrips(
        userId: _userId,
        amount: amount,
        description: description,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final loyaltyNotifierProvider =
    StateNotifierProvider<LoyaltyNotifier, AsyncValue<void>>((ref) {
  final user = ref.watch(currentUserProvider);
  final repo = ref.read(loyaltyRepositoryProvider);
  return LoyaltyNotifier(repo, user?.id ?? '');
});
