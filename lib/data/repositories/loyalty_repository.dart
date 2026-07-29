import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/strips_ledger_entry.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// TigerBay International — Loyalty Repository (Strips-Based)
/// ═══════════════════════════════════════════════════════════════════════════
/// Data access layer for the Strips ledger and loyalty-related operations.
/// Queries the `strips_ledger` table and `profiles.strips_balance`.
class LoyaltyRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch the user's Strips transaction history, ordered newest-first.
  Future<List<StripsLedgerEntry>> getStripsLedger(String userId,
      {int limit = 50}) async {
    final data = await _supabase
        .from('strips_ledger')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (data as List)
        .map((e) => StripsLedgerEntry.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Redeem Strips for a reward. Decrements the user's balance and records
  /// a ledger entry.
  Future<void> redeemStrips({
    required String userId,
    required int amount,
    required String description,
  }) async {
    // Fetch current balance
    final profileData = await _supabase
        .from('profiles')
        .select('strips_balance')
        .eq('id', userId)
        .single();

    final currentBalance =
        (profileData['strips_balance'] as int?) ?? 0;

    if (currentBalance < amount) {
      throw Exception('Insufficient Strips balance. '
          'Current: $currentBalance, Required: $amount');
    }

    // Update balance
    await _supabase.from('profiles').update({
      'strips_balance': currentBalance - amount,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);

    // Insert ledger entry
    await _supabase.from('strips_ledger').insert({
      'user_id': userId,
      'amount': amount,
      'transaction_type': 'redeem',
      'description': description,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Watch the user's Strips balance in realtime via profile stream.
  Stream<int> watchStripsBalance(String userId) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) {
      if (rows.isEmpty) return 0;
      return (rows.first['strips_balance'] as int?) ?? 0;
    });
  }

  /// Generate a signed QR token payload (validated server-side).
  Future<String> generateQrSecret(String userId) async {
    final data = await _supabase
        .from('qr_secrets')
        .select('secret')
        .eq('user_id', userId)
        .single();
    return data['secret'] as String;
  }

  /// Link a physical card number to the digital account.
  Future<void> linkPhysicalCard({
    required String userId,
    required String cardNumber,
  }) async {
    final card = await _supabase
        .from('physical_card')
        .select()
        .eq('card_number', cardNumber)
        .maybeSingle();

    if (card == null) throw Exception('Card not found');
    if (card['is_linked'] == true) throw Exception('Card already linked');

    await _supabase.rpc('link_physical_card', params: {
      'p_user_id': userId,
      'p_card_number': cardNumber,
    });
  }
}
