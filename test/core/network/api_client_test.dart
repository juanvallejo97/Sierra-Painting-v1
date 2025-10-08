/// Unit tests for ApiClient
///
/// PURPOSE:
/// Verify ApiClient behavior:
/// - Timeout handling
/// - Retry logic with exponential backoff
/// - Error mapping
/// - RequestId propagation
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/core/network/api_client.dart';

void main() {
  group('ApiClient', () {
    test('Configuration defaults are set correctly', () {
      expect(ApiConfig.defaultTimeout.inSeconds, 30);
      expect(ApiConfig.maxRetries, 3);
      expect(ApiConfig.initialRetryDelay.inSeconds, 1);
      expect(ApiConfig.maxRetryDelay.inSeconds, 10);
    });

    test('ApiError contains required fields', () {
      final error = ApiError(
        type: ApiErrorType.timeout,
        message: 'Request timed out',
        requestId: 'req_123',
        functionName: 'clockIn',
      );

      expect(error.type, ApiErrorType.timeout);
      expect(error.message, 'Request timed out');
      expect(error.requestId, 'req_123');
      expect(error.functionName, 'clockIn');
    });

    test('ApiError toString includes requestId', () {
      final error = ApiError(type: ApiErrorType.network, message: 'Network error', requestId: 'req_456');

      expect(error.toString(), contains('req_456'));
      expect(error.toString(), contains('Network error'));
    });

    // TODO: Add integration tests with Firebase emulator
    // TODO: Test retry logic with mock responses
    // TODO: Test timeout behavior
    // TODO: Verify requestId generation and propagation
  });
}
