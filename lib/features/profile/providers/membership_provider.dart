import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tigerbay_app/data/models/membership_tier_model.dart';
import 'package:tigerbay_app/features/auth/providers/profile_state_provider.dart';

// ═══════════════════════════════════════════════════════════════════════════
// TigerBay International — Membership Tier & Activation Providers
// ═══════════════════════════════════════════════════════════════════════════

/// Database-driven tier list from `public.membership_tiers`, ordered by
/// tier_level ascending.
final membershipTiersProvider =
    FutureProvider<List<MembershipTier>>((ref) async {
  final repo = ref.watch(supabaseRepositoryProvider);
  return repo.fetchMembershipTiers();
});

/// Currently selected page index in the PageView swiper.
final selectedTierIndexProvider = StateProvider<int>((ref) => 0);

/// The currently selected MembershipTier (derived from index + tier list).
final selectedTierProvider = Provider<MembershipTier?>((ref) {
  final tiersAsync = ref.watch(membershipTiersProvider);
  final index = ref.watch(selectedTierIndexProvider);

  return tiersAsync.whenData((tiers) {
    if (tiers.isEmpty) return null;
    return tiers[index.clamp(0, tiers.length - 1)];
  }).valueOrNull;
});

/// Selected payment method for the paywall screen.
final selectedPaymentMethodProvider =
    StateProvider<PaymentMethod>((ref) => PaymentMethod.cashAtVenue);

/// Payment method options for membership activation.
enum PaymentMethod {
  cashAtVenue('Cash at Venue'),
  posCard('Card POS Machine'),
  bankTransfer('Bank Transfer'),
  paypal('PayPal'),
  stripe('Card (Stripe)'); // 🔜 Activated when Stripe Edge Function is deployed

  final String displayName;
  const PaymentMethod(this.displayName);
}

// ── Membership Activation State ───────────────────────────────────────────

class MembershipActivationState {
  final bool isProcessing;
  final bool isSuccess;
  final String? error;

  const MembershipActivationState({
    this.isProcessing = false,
    this.isSuccess = false,
    this.error,
  });

  MembershipActivationState copyWith({
    bool? isProcessing,
    bool? isSuccess,
    String? error,
    bool clearError = false,
  }) {
    return MembershipActivationState(
      isProcessing: isProcessing ?? this.isProcessing,
      isSuccess: isSuccess ?? this.isSuccess,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MembershipActivationNotifier
    extends StateNotifier<MembershipActivationState> {
  final SupabaseClient _client;
  final Ref _ref;

  MembershipActivationNotifier(this._client, this._ref)
      : super(const MembershipActivationState());

  /// Activate a membership tier for the current user. Updates
  /// `membership_status` to 'active' and sets `membership_tier_id`.
  Future<bool> activateMembership(MembershipTier tier) async {
    if (state.isProcessing) return false;

    state = state.copyWith(isProcessing: true, clearError: true);

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No authenticated user found.');
      }

      // ⚠️ CRITICAL FIX: Append .select() to verify rows were actually modified!
      final response = await _client.from('profiles').update({
        'membership_tier_id': tier.id,
        'membership_status': 'active',
        'membership_expires_at':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId).select();

      if (response.isEmpty) {
        throw Exception('Update failed: 0 rows modified. Check Supabase RLS policies.');
      }

      // Force the profileStateProvider to fetch the updated profile row
      await _ref.read(profileStateProvider.notifier).refreshProfile();

      state = state.copyWith(isProcessing: false, isSuccess: true);
      return true;
    } catch (error) {
      debugPrint('[MembershipActivation] ERROR: $error');
      state = state.copyWith(
        isProcessing: false,
        isSuccess: false,
        error: error.toString(),
      );
      return false;
    }
  }

  void reset() {
    state = const MembershipActivationState();
  }
}

final membershipActivationNotifierProvider = StateNotifierProvider<
    MembershipActivationNotifier, MembershipActivationState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MembershipActivationNotifier(client, ref);
});
