/// A generic functional Result type representing either a [Success] or a [Failure].
abstract class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => isSuccess ? (this as Success<T>).data : null;
  String? get errorOrNull => isFailure ? (this as Failure<T>).message : null;

  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(String message, dynamic error) onFailure,
  }) {
    if (this is Success<T>) {
      return onSuccess((this as Success<T>).data);
    } else {
      final failure = this as Failure<T>;
      return onFailure(failure.message, failure.error);
    }
  }
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final String message;
  final dynamic error;
  const Failure(this.message, [this.error]);
}
