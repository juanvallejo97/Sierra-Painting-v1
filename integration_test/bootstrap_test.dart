import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sierra_painting/core/firebase_emulators.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Firebase init on emulators', (tester) async {
    await Firebase.initializeApp();
    const useEmus = bool.fromEnvironment('USE_EMULATORS', defaultValue: true);
    if (useEmus) {
      await useFirebaseEmulators(host: 'localhost');
    }
    await FirebaseFirestore.instance.collection('smoke').add({'ok': true});
    final q = await FirebaseFirestore.instance.collection('smoke').get();
    expect(q.docs.isNotEmpty, true);
  });
}
