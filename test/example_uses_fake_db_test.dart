import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  testWidgets('widget uses fake db', (tester) async {
    final fake = FakeFirebaseFirestore();
    await fake.collection('demo').add({'ok': true});
    // Inject `fake` into your repository/service/provider here.
    // await tester.pumpWidget(AppShell(testMode: true, db: fake));
    // ...assertions...
  });
}
