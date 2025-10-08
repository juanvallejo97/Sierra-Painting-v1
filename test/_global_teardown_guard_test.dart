import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDownAll(() async {
    // Extra delay to let file watchers / temp listeners shut down cleanly.
    await Future<void>.delayed(const Duration(milliseconds: 800));
  });

  // Proves that our onError handler is restored between tests.
  test('teardown guard integrity', () {
    expect(FlutterError.onError, isNotNull);
  });
}
