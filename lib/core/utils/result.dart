/// Result type for type-safe error handling
///
/// PURPOSE:
/// Provides a Rust-inspired `Result<T, E>` type for explicit error handling
/// without throwing exceptions. Encourages explicit error handling at call sites.
///
/// USAGE:
/// ```dart
/// Result<User, String> fetchUser(String id) {
///   try {
///     final user = await userService.get(id);
///     return Result.success(user);
///   } catch (e) {
///     return Result.failure('Failed to fetch user: $e');
///   }
/// }
///
/// // At call site
/// final result = await fetchUser('123');
/// result.when(
///   success: (user) => print('Got user: ${user.name}'),
///   failure: (error) => print('Error: $error'),
/// );
/// ```
///
/// BENEFITS:
/// - Forces explicit error handling
/// - Type-safe success and failure paths
/// - No hidden exceptions
/// - Composable with map/flatMap
library;

sealed class Result<T, E> {
  const Result();

  /// Create a successful result
  factory Result.success(T value) = Success<T, E>;

  /// Create a failure result
  factory Result.failure(E error) = Failure<T, E>;

  /// Check if this is a success
  bool get isSuccess => this is Success<T, E>;

  /// Check if this is a failure
  bool get isFailure => this is Failure<T, E>;

  /// Get the success value or null
  T? get valueOrNull => this is Success<T, E> ? (this as Success<T, E>).value : null;

  /// Get the error or null
  E? get errorOrNull => this is Failure<T, E> ? (this as Failure<T, E>).error : null;

  /// Get the value or throw
  T get value {
    if (this is Success<T, E>) {
      return (this as Success<T, E>).value;
    }
    throw StateError('Tried to get value from a Failure result');
  }

  /// Get the value or return a default
  T getOrElse(T defaultValue) {
    if (this is Success<T, E>) {
      return (this as Success<T, E>).value;
    }
    return defaultValue;
  }

  /// Pattern matching
  R when<R>({required R Function(T value) success, required R Function(E error) failure}) {
    if (this is Success<T, E>) {
      return success((this as Success<T, E>).value);
    } else {
      return failure((this as Failure<T, E>).error);
    }
  }

  /// Map the success value
  Result<R, E> map<R>(R Function(T value) transform) {
    if (this is Success<T, E>) {
      return Result.success(transform((this as Success<T, E>).value));
    } else {
      return Result.failure((this as Failure<T, E>).error);
    }
  }

  /// Map the error
  Result<T, R> mapError<R>(R Function(E error) transform) {
    if (this is Success<T, E>) {
      return Result.success((this as Success<T, E>).value);
    } else {
      return Result.failure(transform((this as Failure<T, E>).error));
    }
  }

  /// Flat map (for chaining operations that return Result)
  Result<R, E> flatMap<R>(Result<R, E> Function(T value) transform) {
    if (this is Success<T, E>) {
      return transform((this as Success<T, E>).value);
    } else {
      return Result.failure((this as Failure<T, E>).error);
    }
  }
}

/// Successful result
final class Success<T, E> extends Result<T, E> {
  @override
  final T value;
  const Success(this.value);

  @override
  String toString() => 'Success($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Success<T, E> && runtimeType == other.runtimeType && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Failed result
final class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);

  @override
  String toString() => 'Failure($error)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Failure<T, E> && runtimeType == other.runtimeType && error == other.error;

  @override
  int get hashCode => error.hashCode;
}

/// Convenience extension for `Future<Result<T, E>>`
extension ResultFuture<T, E> on Future<Result<T, E>> {
  /// Unwrap the future result
  Future<T> unwrap() async {
    final result = await this;
    return result.value;
  }

  /// Get value or default from future result
  Future<T> getOrElse(T defaultValue) async {
    final result = await this;
    return result.getOrElse(defaultValue);
  }
}
