import 'package:flutter_test/flutter_test.dart';
import 'test_harness.dart';

void main() {
  testWidgets('Login screen renders', (tester) async {
    await pumpLogin(tester, authenticated: false);
    expect(find.text('Log In'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 10)));
}
