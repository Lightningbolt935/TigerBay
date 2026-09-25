import 'package:flutter/foundation.dart'; // 💡 FIXED: Adds core infrastructure for debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/booking_model.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../auth/providers/auth_provider.dart';

final bookingRepositoryProvider =
    Provider<BookingRepository>((ref) => BookingRepository());

// ── User bookings (real-time stream) ──────────────────────────────────────────

final userBookingsStreamProvider = StreamProvider<List<BookingModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return const Stream.empty();
  return ref.read(bookingRepositoryProvider).watchUserBookings(user.id);
});

// ── Available slots ───────────────────────────────────────────────────────────

class SlotQuery {
  final String branchId;
  final DateTime date;
  SlotQuery({required this.branchId, required this.date});

  @override
  bool operator ==(Object other) =>
      other is SlotQuery &&
      other.branchId == branchId &&
      other.date.day == date.day &&
      other.date.month == date.month &&
      other.date.year == date.year;

  @override
  int get hashCode => Object.hash(branchId, date.day, date.month, date.year);
}

final availableSlotsProvider =
    FutureProvider.family<List<String>, SlotQuery>((ref, query) async {
  return ref.read(bookingRepositoryProvider).getAvailableSlots(
        branchId: query.branchId,
        date: query.date,
      );
});

// ── New booking state ─────────────────────────────────────────────────────────

class NewBookingState {
  final String? branchId;
  final DateTime? selectedDate;
  final String? selectedSlot;
  final int partySize;
  final bool isLoading;
  final String? error;

  const NewBookingState({
    this.branchId,
    this.selectedDate,
    this.selectedSlot,
    this.partySize = 2,
    this.isLoading = false,
    this.error,
  });

  NewBookingState copyWith({
    String? branchId,
    DateTime? selectedDate,
    String? selectedSlot,
    int? partySize,
    bool? isLoading,
    String? error,
    bool clearError = false,
    bool clearSlot = false,
  }) {
    return NewBookingState(
      branchId: branchId ?? this.branchId,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedSlot: clearSlot ? null : (selectedSlot ?? this.selectedSlot),
      partySize: partySize ?? this.partySize,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  bool get canProceed =>
      branchId != null && selectedDate != null && selectedSlot != null;
}

class BookingNotifier extends StateNotifier<NewBookingState> {
  final BookingRepository _repo;
  final String _userId;

  BookingNotifier(this._repo, this._userId) : super(const NewBookingState());

  void setBranch(String branchId) =>
      state = state.copyWith(branchId: branchId, clearSlot: true);

  void setDate(DateTime date) =>
      state = state.copyWith(selectedDate: date, clearSlot: true);

  void setSlot(String slot) => state = state.copyWith(selectedSlot: slot);

  void setPartySize(int size) => state = state.copyWith(partySize: size);

  /// Returns { clientSecret, bookingId, depositAmount } on success
  Future<Map<String, dynamic>?> createBooking() async {
    if (!state.canProceed) return null;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repo.createBookingWithDeposit(
        userId: _userId,
        branchId: state.branchId!,
        bookingDate: state.selectedDate!,
        timeSlot: state.selectedSlot!,
        partySize: state.partySize,
      );

      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      debugPrint('❌ Intercepted Booking Repository Exception: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  Future<bool> cancelBooking(int bookingId) async {
    try {
      await _repo.cancelBooking(bookingId);
      return true;
    } catch (_) {
      return false;
    }
  }
}

final bookingNotifierProvider =
    StateNotifierProvider<BookingNotifier, NewBookingState>((ref) {
  final user = ref.watch(currentUserProvider);
  final repo = ref.read(bookingRepositoryProvider);
  return BookingNotifier(repo, user?.id ?? '');
});
