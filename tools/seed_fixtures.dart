import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sierra_painting/firebase_options.dart';

Future<void> main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  final b = FirebaseFirestore.instance.batch();
  final uid = 'demo-user';
  b.set(FirebaseFirestore.instance.collection('users').doc(uid), {
    'displayName': 'Demo User',
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });
  b.set(FirebaseFirestore.instance.collection('timeclockEntries').doc(), {
    'userId': uid,
    'jobId': 'demo-job',
    'clockIn': FieldValue.serverTimestamp(),
    'notes': 'Seed entry',
    'createdAt': FieldValue.serverTimestamp(),
  });
  await b.commit();
  print('Seeded fixtures into emulator.');
}
