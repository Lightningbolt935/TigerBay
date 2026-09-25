import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tigerbay_app/core/constants/app_routes.dart';
import 'package:tigerbay_app/data/models/booking_model.dart';
import 'package:tigerbay_app/features/bookings/providers/booking_provider.dart';
import 'package:tigerbay_app/features/bookings/screens/booking_detail_screen.dart';
import 'package:tigerbay_app/features/bookings/screens/my_bookings_screen.dart';
import 'package:tigerbay_app/features/home/providers/home_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookingModel & Status Tests', () {
    test('BookingStatus parsing and display names', () {
      expect(BookingStatus.fromString('upcoming'), equals(BookingStatus.upcoming));
      expect(BookingStatus.fromString('UPCOMING'), equals(BookingStatus.upcoming));
      expect(BookingStatus.fromString('past'), equals(BookingStatus.past));
      expect(BookingStatus.fromString('cancelled'), equals(BookingStatus.cancelled));
      expect(BookingStatus.fromString('unknown_value'), equals(BookingStatus.upcoming));

      expect(BookingStatus.upcoming.displayName, equals('Upcoming'));
      expect(BookingStatus.past.displayName, equals('Past'));
      expect(BookingStatus.cancelled.displayName, equals('Cancelled'));
    });

    test('BookingModel fromJson and toJson serialization', () {
      final json = {
        'id': 101,
        'user_id': 'user_abc',
        'branch_id': 2,
        'branch_name': 'Kingsbury Lounge',
        'booking_date': '2026-10-15',
        'booking_time': '20:00',
        'guest_count': 4,
        'status': 'upcoming',
        'strips_awarded': true,
        'special_requests': 'Booth seating near terrace',
        'created_at': '2026-09-25T12:00:00.000Z',
      };

      final model = BookingModel.fromJson(json);
      expect(model.id, equals(101));
      expect(model.userId, equals('user_abc'));
      expect(model.branchId, equals(2));
      expect(model.branchName, equals('Kingsbury Lounge'));
      expect(model.bookingDate.year, equals(2026));
      expect(model.bookingDate.month, equals(10));
      expect(model.bookingDate.day, equals(15));
      expect(model.bookingTime, equals('20:00'));
      expect(model.guestCount, equals(4));
      expect(model.status, equals(BookingStatus.upcoming));
      expect(model.stripsAwarded, isTrue);
      expect(model.specialRequests, equals('Booth seating near terrace'));

      final outputJson = model.toJson();
      expect(outputJson['id'], equals(101));
      expect(outputJson['status'], equals('upcoming'));
    });
  });

  group('Booking Routes & Path Tests', () {
    test('Reservation routes are correctly configured', () {
      expect(AppRoutes.myBookings, equals('/my-bookings'));
      expect(AppRoutes.booking, equals('/my-bookings/new'));
      expect(AppRoutes.bookingConfirm, equals('/my-bookings/confirm'));
      expect(AppRoutes.bookingDetail, equals('/my-bookings/detail'));
    });
  });

  group('MyBookingsScreen Widget Tests', () {
    testWidgets('MyBookingsScreen displays luxury header, tabs, and FAB',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userBookingsStreamProvider.overrideWith((ref) => Stream.value([])),
            branchesProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: MyBookingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Screen Header
      expect(find.text('Reservations'), findsOneWidget);

      // Verify Tab Labels
      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);

      // Verify Reserve a Table FAB
      expect(find.text('Reserve a Table'), findsOneWidget);

      // Verify Empty State for Upcoming Tab
      expect(find.text('No Upcoming Reservations'), findsOneWidget);
    });

    testWidgets('MyBookingsScreen renders booking cards when bookings exist',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sampleBooking = BookingModel(
        id: 77,
        userId: 'u_1',
        branchId: 1,
        branchName: 'Kingsbury Lounge',
        bookingDate: DateTime(2026, 11, 20),
        bookingTime: '19:30',
        guestCount: 3,
        status: BookingStatus.upcoming,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userBookingsStreamProvider
                .overrideWith((ref) => Stream.value([sampleBooking])),
            branchesProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: MyBookingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kingsbury Lounge'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.text('19:30'), findsOneWidget);
    });
  });

  group('BookingDetailScreen Widget Tests', () {
    testWidgets('BookingDetailScreen renders reservation details correctly',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sampleBooking = BookingModel(
        id: 88,
        userId: 'u_1',
        branchId: 1,
        branchName: 'Hanger Lane Lounge',
        bookingDate: DateTime(2026, 12, 5),
        bookingTime: '21:00',
        guestCount: 6,
        status: BookingStatus.upcoming,
        specialRequests: 'Birthday celebration table',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userBookingsStreamProvider
                .overrideWith((ref) => Stream.value([sampleBooking])),
          ],
          child: MaterialApp(
            home: BookingDetailScreen(
              bookingId: '88',
              initialBooking: sampleBooking,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Reservation Details'), findsOneWidget);
      expect(find.text('Hanger Lane Lounge'), findsOneWidget);
      expect(find.text('REF: #TB-00088'), findsOneWidget);
      expect(find.text('6 Guests'), findsOneWidget);
      expect(find.text('21:00'), findsOneWidget);
      expect(find.text('Birthday celebration table'), findsOneWidget);
      expect(find.text('Modify Reservation'), findsOneWidget);
      expect(find.text('Cancel Reservation'), findsOneWidget);
    });
  });
}
