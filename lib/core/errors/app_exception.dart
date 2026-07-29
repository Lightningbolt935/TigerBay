/// Base class for all app-level exceptions
class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AppException($code): $message';
}

class NetworkException extends AppException {
  const NetworkException({super.message = 'No internet connection.'})
      : super(code: 'NETWORK_ERROR');
}

class AuthException extends AppException {
  const AuthException({required super.message, String? code})
      : super(code: code ?? 'AUTH_ERROR');
}

class DeviceMismatchException extends AppException {
  const DeviceMismatchException()
      : super(
          message:
              'This account is linked to a different device. Please contact support.',
          code: 'DEVICE_MISMATCH',
        );
}

class InsufficientPointsException extends AppException {
  const InsufficientPointsException()
      : super(
          message: 'Insufficient points balance.',
          code: 'INSUFFICIENT_POINTS',
        );
}

class PaymentException extends AppException {
  const PaymentException({required super.message})
      : super(code: 'PAYMENT_ERROR');
}

class CardNotFoundException extends AppException {
  const CardNotFoundException()
      : super(
          message: 'Physical card not found. Please check the card number.',
          code: 'CARD_NOT_FOUND',
        );
}

class CardAlreadyLinkedException extends AppException {
  const CardAlreadyLinkedException()
      : super(
          message: 'This card is already linked to an account.',
          code: 'CARD_ALREADY_LINKED',
        );
}

class BookingNotFoundException extends AppException {
  const BookingNotFoundException()
      : super(message: 'Booking not found.', code: 'BOOKING_NOT_FOUND');
}

class SlotUnavailableException extends AppException {
  const SlotUnavailableException()
      : super(
          message:
              'This time slot is no longer available. Please choose another.',
          code: 'SLOT_UNAVAILABLE',
        );
}
