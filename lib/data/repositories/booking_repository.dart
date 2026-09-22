import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking_model.dart';

class BookingRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<BookingModel>> getUserBookings(String userId) async {
    final data = await _supabase
        .from('bookings')
        .select()
        .eq('user_id', userId)
        .order('booking_date', ascending: false);

    return (data as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  Future<BookingModel?> getBooking(String bookingId) async {
    final data = await _supabase
        .from('bookings')
        .select()
        .eq('id', bookingId)
        .single();

    return BookingModel.fromJson(data);
  }

  Future<List<String>> getAvailableSlots({
    required String branchId,
    required DateTime date,
  }) async {
    final data = await _supabase.rpc('get_available_slots', params: {
      'p_branch_id': branchId,
      'p_date': date.toIso8601String().substring(0, 10),
    });

    return (data as List).map((e) => e as String).toList();
  }

  /// Create booking and initiate Stripe deposit payment intent
  Future<Map<String, dynamic>> createBookingWithDeposit({
    required String userId,
    required String branchId,
    required DateTime bookingDate,
    required String timeSlot,
    required int partySize,
    String? specialRequests,
  }) async {
    // Call Edge Function which creates booking + Stripe PaymentIntent atomically
    final response = await _supabase.functions.invoke(
      'create-booking',
      body: {
        'user_id': userId,
        'branch_id': branchId,
        'booking_date': bookingDate.toIso8601String(),
        'time_slot': timeSlot,
        'party_size': partySize,
        'special_requests': specialRequests,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to create booking: ${response.data}');
    }

    return response.data as Map<String, dynamic>;
    // Returns: { bookingId, clientSecret, depositAmount }
  }

  Future<BookingModel> confirmBookingPayment({
    required String bookingId,
    required String stripePaymentIntentId,
  }) async {
    final data = await _supabase
        .from('bookings')
        .update({
          'stripe_payment_intent_id': stripePaymentIntentId,
          'status': 'upcoming',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', bookingId)
        .select()
        .single();

    return BookingModel.fromJson(data);
  }


  Future<BookingModel> modifyBooking({
    required String bookingId,
    required DateTime newDate,
    required String newTimeSlot,
    required int newPartySize,
  }) async {
    final data = await _supabase
        .from('bookings')
        .update({
          'booking_date': newDate.toIso8601String(),
          'time_slot': newTimeSlot,
          'party_size': newPartySize,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', bookingId)
        .select()
        .single();

    return BookingModel.fromJson(data);
  }

  /// Cancel booking and trigger Stripe refund via Edge Function
  Future<void> cancelBooking(int bookingId) async {
    await _supabase.functions.invoke(
      'cancel-booking',
      body: {'booking_id': bookingId},
    );
  }

  /// Fetch the Stripe connected-account ID for a specific branch.
  /// Returns `null` if the branch has no connected account configured.
  Future<String?> fetchBranchStripeAccountId(String branchId) async {
    final data = await _supabase
        .from('branches')
        .select('stripe_account_id')
        .eq('id', branchId)
        .maybeSingle();
    return data?['stripe_account_id'] as String?;
  }

  Stream<List<BookingModel>> watchUserBookings(String userId) {
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) =>
            rows.map((e) => BookingModel.fromJson(e)).toList());
  }
}
