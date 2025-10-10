import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as fb_storage;

Future<void> useFirebaseEmulators({String host = 'localhost'}) async {
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
    sslEnabled: false,
  );

  FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  await fb_storage.FirebaseStorage.instance.useStorageEmulator(host, 9199);
}
