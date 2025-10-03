/// Firestore Providers
///
/// PURPOSE:
/// Riverpod providers for Cloud Firestore access with offline persistence.
/// Provides reactive access to Firestore collections throughout the app.
///
/// PROVIDERS:
/// - firestoreProvider: Firestore instance configured with offline persistence
/// - leadsCollectionProvider: Access to leads collection
/// - estimatesCollectionProvider: Access to estimates collection
/// - invoicesCollectionProvider: Access to invoices collection
/// - timeclocksCollectionProvider: Access to timeclocks collection
///
/// CONFIGURATION:
/// - Offline persistence enabled
/// - Unlimited cache size for better offline experience
///
/// USAGE:
/// ```dart
/// final db = ref.watch(firestoreProvider);
/// final invoices = ref.watch(invoicesCollectionProvider);
/// ```
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Provider for Firestore instance with offline persistence
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  final firestore = FirebaseFirestore.instance;

  // Enable offline persistence
  firestore.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  return firestore;
});

/// Collection providers
final leadsCollectionProvider = Provider<CollectionReference>((ref) {
  return ref.watch(firestoreProvider).collection('leads');
});

final estimatesCollectionProvider = Provider<CollectionReference>((ref) {
  return ref.watch(firestoreProvider).collection('estimates');
});

final invoicesCollectionProvider = Provider<CollectionReference>((ref) {
  return ref.watch(firestoreProvider).collection('invoices');
});

final timeclocksCollectionProvider = Provider<CollectionReference>((ref) {
  return ref.watch(firestoreProvider).collection('timeclocks');
});
