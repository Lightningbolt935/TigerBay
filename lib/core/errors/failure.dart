/// Failure types used with a Result pattern across the app.
/// Each repository method can return Either<Failure, T>.
sealed class Failure {
  final String message;
  const Failure(this.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure() : super('No internet connection. Please try again.');
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}

class DeviceMismatchFailure extends Failure {
  const DeviceMismatchFailure()
      : super('Account is bound to a different device.');
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

class PaymentFailure extends Failure {
  const PaymentFailure(super.message);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

class PermissionFailure extends Failure {
  const PermissionFailure(super.message);
}

/// Simple Result type — avoids requiring `dartz` package
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Err<T> extends Result<T> {
  final Failure failure;
  const Err(this.failure);
}

extension ResultX<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isError => this is Err<T>;
  T get data => (this as Success<T>).data;
  Failure get failure => (this as Err<T>).failure;

  R fold<R>(
    R Function(Failure failure) onError,
    R Function(T data) onSuccess,
  ) {
    return switch (this) {
      Err<T> e => onError(e.failure),
      Success<T> s => onSuccess(s.data),
    };
  }
}
