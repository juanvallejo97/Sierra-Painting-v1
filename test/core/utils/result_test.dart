/// Unit tests for Result type
///
/// PURPOSE:
/// Verify Result type behavior for type-safe error handling

import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/core/utils/result.dart';

void main() {
  group('Result', () {
    test('Success result', () {
      final result = Result<int, String>.success(42);

      expect(result.isSuccess, true);
      expect(result.isFailure, false);
      expect(result.valueOrNull, 42);
      expect(result.errorOrNull, null);
      expect(result.value, 42);
    });

    test('Failure result', () {
      final result = Result<int, String>.failure('error');

      expect(result.isSuccess, false);
      expect(result.isFailure, true);
      expect(result.valueOrNull, null);
      expect(result.errorOrNull, 'error');
    });

    test('when() pattern matching', () {
      final success = Result<int, String>.success(42);
      final failure = Result<int, String>.failure('error');

      final successResult = success.when(
        success: (value) => 'Got $value',
        failure: (error) => 'Error: $error',
      );

      final failureResult = failure.when(
        success: (value) => 'Got $value',
        failure: (error) => 'Error: $error',
      );

      expect(successResult, 'Got 42');
      expect(failureResult, 'Error: error');
    });

    test('map() transforms success value', () {
      final result = Result<int, String>.success(42);
      final mapped = result.map((value) => value * 2);

      expect(mapped.isSuccess, true);
      expect(mapped.value, 84);
    });

    test('map() preserves failure', () {
      final result = Result<int, String>.failure('error');
      final mapped = result.map((value) => value * 2);

      expect(mapped.isFailure, true);
      expect(mapped.errorOrNull, 'error');
    });

    test('getOrElse() returns value for success', () {
      final result = Result<int, String>.success(42);
      expect(result.getOrElse(0), 42);
    });

    test('getOrElse() returns default for failure', () {
      final result = Result<int, String>.failure('error');
      expect(result.getOrElse(0), 0);
    });

    test('flatMap() chains operations', () {
      final result = Result<int, String>.success(42);
      final chained = result.flatMap((value) {
        if (value > 40) {
          return Result.success('Large');
        } else {
          return Result.failure('Too small');
        }
      });

      expect(chained.isSuccess, true);
      expect(chained.value, 'Large');
    });
  });
}
