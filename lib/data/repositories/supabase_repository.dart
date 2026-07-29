import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/membership_tier_model.dart';
import '../models/menu_item_model.dart';
import '../models/reward_item_model.dart';
import '../models/strips_ledger_entry.dart';
import '../models/booking_model.dart';
import '../models/branch_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Central Supabase Repository
/// ═══════════════════════════════════════════════════════════════════════════
/// Single-responsibility data access layer wrapping all Supabase queries.
/// Every method guards against null/type-mismatch errors from dynamic JSON
/// responses using safe casting inside each model's `fromMap` factory.
class SupabaseRepository {
  final SupabaseClient _client;

  SupabaseRepository(this._client);

  // ═══════════════════════════════════════════════════════════════════════════
  // PROFILES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch the full user profile including membership state and Strips balance.
  Future<UserProfile?> fetchUserProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data == null) return null;
      return UserProfile.fromMap(data);
    } catch (e) {
      debugPrint('❌ fetchUserProfile error: $e');
      rethrow;
    }
  }

  /// Realtime stream of the user's profile row. Pushes updates whenever
  /// membership_status, strips_balance, or any other field changes.
  Stream<UserProfile?> watchUserProfile(String userId) {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) =>
            rows.isEmpty ? null : UserProfile.fromMap(rows.first));
  }

  /// Update the membership status and tier on the user's profile.
  Future<void> updateMembershipStatus({
    required String userId,
    required int tierId,
    required String status,
  }) async {
    try {
      await _client.from('profiles').update({
        'membership_tier_id': tierId,
        'membership_status': status,
        'membership_expires_at':
            DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('❌ updateMembershipStatus error: $e');
      rethrow;
    }
  }

  /// Update the user's home site branch.
  Future<void> updateHomeSite({
    required String userId,
    required int branchId,
  }) async {
    try {
      await _client.from('profiles').update({
        'home_site_id': branchId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);
    } catch (e) {
      debugPrint('❌ updateHomeSite error: $e');
      rethrow;
    }
  }

  /// Update basic profile fields (name, email, phone, avatar).
  Future<UserProfile> updateProfile({
    required String userId,
    String? fullName,
    String? email,
    String? phone,
    String? avatarUrl,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (fullName != null) updates['full_name'] = fullName;
      if (email != null) updates['email'] = email;
      if (phone != null) updates['phone'] = phone;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;

      final data = await _client
          .from('profiles')
          .update(updates)
          .eq('id', userId)
          .select()
          .single();

      return UserProfile.fromMap(data);
    } catch (e) {
      debugPrint('❌ updateProfile error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MEMBERSHIP TIERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch all membership tiers ordered by tier_level ascending.
  Future<List<MembershipTier>> fetchMembershipTiers() async {
    try {
      final data = await _client
          .from('membership_tiers')
          .select()
          .order('tier_level', ascending: true);

      return (data as List)
          .map((row) => MembershipTier.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ fetchMembershipTiers error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BRANCHES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch all active branches ordered by name.
  Future<List<Branch>> fetchBranches() async {
    try {
      final data = await _client
          .from('branches')
          .select()
          .eq('is_active', true)
          .order('name');

      return (data as List)
          .map((row) => Branch.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ fetchBranches error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MENU / DISHES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch available menu items, optionally filtered by category.
  Future<List<MenuItemModel>> fetchMenuItems({String? category}) async {
    try {
      var query = _client.from('dishes').select().eq('is_available', true);

      if (category != null && category != 'all') {
        query = query.eq('category', category);
      }

      final data = await query.order('created_at', ascending: false);

      return (data as List)
          .map((row) => MenuItemModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ fetchMenuItems error: $e');
      rethrow;
    }
  }

  /// Realtime stream of menu items.
  Stream<List<MenuItemModel>> watchMenuItems() {
    return _client
        .from('dishes')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((e) => MenuItemModel.fromJson(e))
            .where((item) => item.isAvailable)
            .toList());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REWARDS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch all active rewards from the Reward Store.
  Future<List<RewardItem>> fetchRewards() async {
    try {
      final data = await _client
          .from('rewards')
          .select()
          .eq('is_active', true)
          .order('strips_cost', ascending: true);

      return (data as List)
          .map((row) => RewardItem.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ fetchRewards error: $e');
      rethrow;
    }
  }

  /// Redeem a reward: deducts strips_cost from the user's balance and inserts
  /// a ledger entry. Returns true on success, throws on failure.
  Future<bool> redeemReward({
    required String userId,
    required int rewardId,
    required int stripsCost,
    required String rewardTitle,
  }) async {
    try {
      // Fetch current balance
      final profile = await fetchUserProfile(userId);
      if (profile == null) throw Exception('User profile not found.');
      if (profile.stripsBalance < stripsCost) {
        throw Exception('Insufficient Strips balance.');
      }

      // Deduct balance
      await _client.from('profiles').update({
        'strips_balance': profile.stripsBalance - stripsCost,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      // Insert ledger entry
      await _client.from('strips_ledger').insert({
        'user_id': userId,
        'amount': stripsCost,
        'transaction_type': 'redeem',
        'description': 'Redeemed: $rewardTitle',
        'created_at': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      debugPrint('❌ redeemReward error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STRIPS LEDGER
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch the user's Strips transaction history, most recent first.
  Future<List<StripsLedgerEntry>> fetchStripsLedger(String userId,
      {int limit = 50}) async {
    try {
      final data = await _client
          .from('strips_ledger')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return (data as List)
          .map((row) =>
              StripsLedgerEntry.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ fetchStripsLedger error: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BOOKINGS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fetch all bookings for a user, most recent first.
  Future<List<BookingModel>> fetchUserBookings(String userId) async {
    try {
      final data = await _client
          .from('bookings')
          .select()
          .eq('user_id', userId)
          .order('booking_date', ascending: false);

      return (data as List)
          .map((row) => BookingModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ fetchUserBookings error: $e');
      rethrow;
    }
  }

  /// Realtime stream of user bookings.
  Stream<List<BookingModel>> watchUserBookings(String userId) {
    return _client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) =>
            rows.map((e) => BookingModel.fromJson(e)).toList());
  }

  /// Create a new booking and award Strips.
  Future<BookingModel> createBooking({
    required String userId,
    required int branchId,
    required DateTime bookingDate,
    required String bookingTime,
    required int guestCount,
    String? specialRequests,
  }) async {
    try {
      final data = await _client
          .from('bookings')
          .insert({
            'user_id': userId,
            'branch_id': branchId,
            'booking_date': bookingDate.toIso8601String().substring(0, 10),
            'booking_time': bookingTime,
            'guest_count': guestCount,
            'status': 'upcoming',
            'strips_awarded': false,
            'special_requests': specialRequests,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return BookingModel.fromJson(data);
    } catch (e) {
      debugPrint('❌ createBooking error: $e');
      rethrow;
    }
  }
}
