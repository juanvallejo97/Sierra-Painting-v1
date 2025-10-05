/// API Client with timeout, retry, and requestId propagation
///
/// PURPOSE:
/// Centralized HTTP client for Cloud Functions callable with:
/// - Automatic timeout handling
/// - Exponential backoff retry logic
/// - RequestId propagation for distributed tracing
/// - Error mapping from Firebase exceptions
///
/// USAGE:
/// ```dart
/// final apiClient = ref.read(apiClientProvider);
/// final result = await apiClient.call<Map<String, dynamic>>(
///   functionName: 'clockIn',
///   data: { 'jobId': '123', 'at': DateTime.now().toIso8601String() },
/// );
/// 
/// // Or with explicit deserialization:
/// final result = await apiClient.call<ClockInResponse>(
///   functionName: 'clockIn',
///   data: { 'jobId': '123', 'at': DateTime.now().toIso8601String() },
///   fromJson: ClockInResponse.fromJson,
/// );
/// ```
library api_client;

import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/utils/result.dart' as core;

/// Configuration for API calls
class ApiConfig {
  /// Default timeout for API calls
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// Maximum number of retry attempts
  static const int maxRetries = 3;

  /// Initial retry delay (doubles with each retry)
  static const Duration initialRetryDelay = Duration(seconds: 1);

  /// Maximum retry delay
  static const Duration maxRetryDelay = Duration(seconds: 10);
}

/// Error types for API calls
enum ApiErrorType {
  timeout,
  network,
  unauthenticated,
  permissionDenied,
  notFound,
  invalidArgument,
  resourceExhausted,
  failedPrecondition,
  internal,
  unknown,
}

/// API error with context
class ApiError {
  final ApiErrorType type;
  final String message;
  final String? requestId;
  final String? functionName;
  final dynamic originalError;

  ApiError({
    required this.type,
    required this.message,
    this.requestId,
    this.functionName,
    this.originalError,
  });

  @override
  String toString() =>
      'ApiError($type): $message ${requestId != null ? "(requestId: $requestId)" : ""}';
}

/// API Client for Cloud Functions
class ApiClient {
  final cf.FirebaseFunctions _functions;
  final Uuid _uuid = const Uuid();

  ApiClient({cf.FirebaseFunctions? functions})
      : _functions = functions ?? cf.FirebaseFunctions.instance;

  /// Call a Cloud Function with timeout, retry, and requestId
  Future<core.Result<T, ApiError>> call<T>({
    required String functionName,
    Map<String, dynamic>? data,
    Duration? timeout,
    int? maxRetries,
    Map<String, String>? headers,
    T Function(Map<String, dynamic> json)? fromJson,
  }) async {
    final requestId = _uuid.v4();
    final effectiveTimeout = timeout ?? ApiConfig.defaultTimeout;
    final effectiveMaxRetries = maxRetries ?? ApiConfig.maxRetries;

    // Prepare headers with requestId
    final effectiveHeaders = {'X-Request-Id': requestId, ...?headers};

    // Add requestId to data for backend correlation
    final dataWithRequestId = {...?data, '_requestId': requestId};

    for (var attempt = 0; attempt <= effectiveMaxRetries; attempt++) {
      try {
        // Call function with timeout
        final result = await _callFunction<T>(
          functionName: functionName,
          data: dataWithRequestId,
          timeout: effectiveTimeout,
          headers: effectiveHeaders,
          fromJson: fromJson,
        );

        return core.Result.success(result);
      } on TimeoutException catch (e) {
        if (attempt < effectiveMaxRetries) {
          await _delay(attempt);
          continue;
        }
        return core.Result.failure(
          ApiError(
            type: ApiErrorType.timeout,
            message: 'Request timed out after ${effectiveTimeout.inSeconds}s',
            requestId: requestId,
            functionName: functionName,
            originalError: e,
          ),
        );
      } on cf.FirebaseFunctionsException catch (e) {
        // Do not retry client errors (4xx)
        if (!_shouldRetry(e)) {
          return core.Result.failure(
              _mapFirebaseError(e, requestId, functionName));
        }

        if (attempt < effectiveMaxRetries) {
          await _delay(attempt);
          continue;
        }

        return core.Result.failure(
            _mapFirebaseError(e, requestId, functionName));
      } catch (e) {
        if (attempt < effectiveMaxRetries) {
          await _delay(attempt);
          continue;
        }

        return core.Result.failure(
          ApiError(
            type: ApiErrorType.unknown,
            message: 'Unknown error: $e',
            requestId: requestId,
            functionName: functionName,
            originalError: e,
          ),
        );
      }
    }

    // Should never reach here
    return core.Result.failure(
      ApiError(
        type: ApiErrorType.unknown,
        message: 'Unexpected error',
        requestId: requestId,
        functionName: functionName,
      ),
    );
  }

  /// Call function with timeout
  Future<T> _callFunction<T>({
    required String functionName,
    required Map<String, dynamic> data,
    required Duration timeout,
    required Map<String, String> headers,
    T Function(Map<String, dynamic> json)? fromJson,
  }) async {
    // Note: Firebase Callable Functions don't support custom headers in the call itself.
    // Headers like X-Request-Id are passed via the data payload instead.
    // The headers parameter is kept for future extensibility.
    final cf.HttpsCallable callable = _functions.httpsCallable(functionName);

    final result = await callable.call(data).timeout(timeout);

    // Use fromJson if provided, otherwise cast to T
    if (fromJson != null && result.data is Map<String, dynamic>) {
      return fromJson(result.data as Map<String, dynamic>);
    }
    return result.data as T;
  }

  /// Calculate delay for exponential backoff with jitter
  Future<void> _delay(int attempt) async {
    final baseDelay = ApiConfig.initialRetryDelay.inMilliseconds;
    final exponentialDelay = baseDelay * (1 << attempt); // 2^attempt
    final jitter = (exponentialDelay * 0.1).toInt(); // 10% jitter
    final delayMs = (exponentialDelay + jitter).clamp(
      0,
      ApiConfig.maxRetryDelay.inMilliseconds,
    );

    await Future.delayed(Duration(milliseconds: delayMs));
  }

  /// Check if error should be retried
  bool _shouldRetry(cf.FirebaseFunctionsException e) {
    // Retry on server errors (5xx) and rate limiting
    switch (e.code) {
      case 'deadline-exceeded':
      case 'unavailable':
      case 'resource-exhausted':
      case 'internal':
      case 'unknown':
        return true;
      default:
        return false;
    }
  }

  /// Map Firebase error to ApiError
  ApiError _mapFirebaseError(
    cf.FirebaseFunctionsException e,
    String requestId,
    String functionName,
  ) {
    final type = _errorTypeFromCode(e.code);
    return ApiError(
      type: type,
      message: e.message ?? 'Unknown error',
      requestId: requestId,
      functionName: functionName,
      originalError: e,
    );
  }

  /// Map Firebase error code to ApiErrorType
  ApiErrorType _errorTypeFromCode(String code) {
    switch (code) {
      case 'deadline-exceeded':
        return ApiErrorType.timeout;
      case 'unavailable':
        return ApiErrorType.network;
      case 'unauthenticated':
        return ApiErrorType.unauthenticated;
      case 'permission-denied':
        return ApiErrorType.permissionDenied;
      case 'not-found':
        return ApiErrorType.notFound;
      case 'invalid-argument':
        return ApiErrorType.invalidArgument;
      case 'resource-exhausted':
        return ApiErrorType.resourceExhausted;
      case 'failed-precondition':
        return ApiErrorType.failedPrecondition;
      case 'internal':
        return ApiErrorType.internal;
      default:
        return ApiErrorType.unknown;
    }
  }
}

/// Provider for ApiClient
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});
