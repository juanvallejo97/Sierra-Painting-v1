@Timeout(Duration(seconds: 25))
library smoke_login_test;

import 'package:flutter_test/flutter_test.dart';
import 'test_harness.dart';
import 'firebase_test_setup.dart'; // <-- provides setupFirebaseForTesting()

void main() {
  // Ensure bootstrap is done once before any widget pumping.
  setUpAll(() async {
    await setupFirebaseForTesting();
  });

  testWidgets('Login screen renders', (tester) async {
    await pumpLogin(tester, authenticated: false);
    expect(find.text('Log In'), findsOneWidget);
  });
}
