/// Timeclock Geofence Integration Tests
///
/// PURPOSE:
/// End-to-end tests for geofence-enforced time tracking.
/// Tests the full flow: client → Cloud Function → timeEntry creation.
///
/// ACCEPTANCE CRITERIA:
/// - Clock-in inside geofence completes ≤2s
/// - Clock-in outside geofence returns clear error with distance info
/// - Idempotency: duplicate clientEventId returns same entry
/// - Worker must be assigned to job
/// - Cannot clock in twice simultaneously
///
/// SETUP:
/// - Runs against Firebase emulators (firestore, functions, auth)
/// - Creates test job with geofence at specific coordinates
/// - Creates test worker and assignment
/// - Tests various distance scenarios
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore firestore;
  late FirebaseAuth auth;
  late FirebaseFunctions functions;
  late String testUserId;
  late String testCompanyId;
  late String testJobId;

  // Test job location: San Francisco City Hall
  const double jobLat = 37.7793;
  const double jobLng = -122.4193;
  const double jobRadius = 100.0; // meters

  setUpAll(() async {
    await Firebase.initializeApp();

    // Connect to emulators
    firestore = FirebaseFirestore.instance;
    auth = FirebaseAuth.instance;
    functions = FirebaseFunctions.instance;

    // Check if running against emulators
    const useEmulator = bool.fromEnvironment(
      'USE_EMULATORS',
      defaultValue: false,
    );
    if (useEmulator) {
      firestore.useFirestoreEmulator('localhost', 8080);
      await auth.useAuthEmulator('localhost', 9099);
      functions.useFunctionsEmulator('localhost', 5001);
    }

    // Create test user
    final userCredential = await auth.createUserWithEmailAndPassword(
      email: 'worker@test.com',
      password: 'password123',
    );
    testUserId = userCredential.user!.uid;
    testCompanyId = 'test-company-${DateTime.now().millisecondsSinceEpoch}';

    // Set custom claims (would normally be done by setUserRole function)
    // For emulator testing, we'll create the user document directly
    await firestore.collection('users').doc(testUserId).set({
      'email': 'worker@test.com',
      'companyId': testCompanyId,
      'role': 'staff',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });

  tearDownAll(() async {
    // Clean up test user
    await auth.currentUser?.delete();
    await auth.signOut();
  });

  group('Timeclock Geofence Integration Tests', () {
    setUp(() async {
      // Create test job with geofence
      final jobRef = await firestore.collection('jobs').add({
        'companyId': testCompanyId,
        'name': 'Test Job Site',
        'address': 'San Francisco City Hall',
        'lat': jobLat,
        'lng': jobLng,
        'radiusM': jobRadius,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      testJobId = jobRef.id;

      // Create assignment for test user
      await firestore.collection('assignments').add({
        'companyId': testCompanyId,
        'userId': testUserId,
        'jobId': testJobId,
        'active': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    tearDown(() async {
      // Clean up test data
      final timeEntries = await firestore
          .collection('timeEntries')
          .where('companyId', isEqualTo: testCompanyId)
          .get();
      for (final doc in timeEntries.docs) {
        await doc.reference.delete();
      }

      final assignments = await firestore
          .collection('assignments')
          .where('companyId', isEqualTo: testCompanyId)
          .get();
      for (final doc in assignments.docs) {
        await doc.reference.delete();
      }

      if (testJobId.isNotEmpty) {
        await firestore.collection('jobs').doc(testJobId).delete();
      }
    });

    test('Clock in inside geofence succeeds within 2 seconds', () async {
      final clientEventId = const Uuid().v4();
      final stopwatch = Stopwatch()..start();

      // Location inside geofence (50m away)
      final lat = jobLat + 0.00045; // ~50 meters north
      final lng = jobLng;

      final callable = functions.httpsCallable('clockIn');
      final result = await callable.call({
        'jobId': testJobId,
        'lat': lat,
        'lng': lng,
        'accuracy': 10.0,
        'clientEventId': clientEventId,
      });

      stopwatch.stop();

      expect(result.data['ok'], isTrue);
      expect(result.data['id'], isNotNull);
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));

      // Verify time entry was created
      final timeEntryId = result.data['id'] as String;
      final timeEntry = await firestore
          .collection('timeEntries')
          .doc(timeEntryId)
          .get();

      expect(timeEntry.exists, isTrue);
      expect(timeEntry.data()?['userId'], equals(testUserId));
      expect(timeEntry.data()?['jobId'], equals(testJobId));
      expect(timeEntry.data()?['companyId'], equals(testCompanyId));
      expect(timeEntry.data()?['clockOutAt'], isNull);
      expect(timeEntry.data()?['geoOk'], isTrue);
    });

    test('Clock in outside geofence fails with clear error', () async {
      final clientEventId = const Uuid().v4();

      // Location outside geofence (200m away, beyond 100m radius)
      final lat = jobLat + 0.0018; // ~200 meters north
      final lng = jobLng;

      final callable = functions.httpsCallable('clockIn');

      try {
        await callable.call({
          'jobId': testJobId,
          'lat': lat,
          'lng': lng,
          'accuracy': 10.0,
          'clientEventId': clientEventId,
        });
        fail('Expected exception for outside geofence');
      } catch (e) {
        expect(e.toString(), contains('geofence'));
        expect(e.toString(), contains('m from job site'));
      }
    });

    test('Idempotency: same clientEventId returns same entry', () async {
      final clientEventId = const Uuid().v4();

      // Location inside geofence
      final lat = jobLat + 0.00045; // ~50 meters north
      final lng = jobLng;

      // First call
      final callable = functions.httpsCallable('clockIn');
      final result1 = await callable.call({
        'jobId': testJobId,
        'lat': lat,
        'lng': lng,
        'accuracy': 10.0,
        'clientEventId': clientEventId,
      });

      final entryId1 = result1.data['id'] as String;

      // Second call with same clientEventId
      final result2 = await callable.call({
        'jobId': testJobId,
        'lat': lat,
        'lng': lng,
        'accuracy': 10.0,
        'clientEventId': clientEventId,
      });

      final entryId2 = result2.data['id'] as String;

      // Should return same entry ID
      expect(entryId1, equals(entryId2));

      // Verify only one entry was created
      final entries = await firestore
          .collection('timeEntries')
          .where('clientEventId', isEqualTo: clientEventId)
          .get();

      expect(entries.docs.length, equals(1));
    });

    test('Cannot clock in without assignment', () async {
      // Create a job without assigning the user
      final unassignedJobRef = await firestore.collection('jobs').add({
        'companyId': testCompanyId,
        'name': 'Unassigned Job',
        'address': 'Test Address',
        'lat': jobLat,
        'lng': jobLng,
        'radiusM': jobRadius,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final clientEventId = const Uuid().v4();
      final callable = functions.httpsCallable('clockIn');

      try {
        await callable.call({
          'jobId': unassignedJobRef.id,
          'lat': jobLat,
          'lng': jobLng,
          'accuracy': 10.0,
          'clientEventId': clientEventId,
        });
        fail('Expected exception for unassigned job');
      } catch (e) {
        expect(e.toString(), contains('Not assigned'));
      } finally {
        await unassignedJobRef.delete();
      }
    });

    test('Cannot clock in twice simultaneously', () async {
      // First clock in
      final clientEventId1 = const Uuid().v4();
      final lat = jobLat + 0.00045;
      final lng = jobLng;

      final callable = functions.httpsCallable('clockIn');
      await callable.call({
        'jobId': testJobId,
        'lat': lat,
        'lng': lng,
        'accuracy': 10.0,
        'clientEventId': clientEventId1,
      });

      // Try to clock in again with different clientEventId
      final clientEventId2 = const Uuid().v4();

      try {
        await callable.call({
          'jobId': testJobId,
          'lat': lat,
          'lng': lng,
          'accuracy': 10.0,
          'clientEventId': clientEventId2,
        });
        fail('Expected exception for duplicate clock in');
      } catch (e) {
        expect(e.toString(), contains('Already clocked in'));
      }
    });

    test('Clock out succeeds inside geofence', () async {
      // First clock in
      final clientEventId = const Uuid().v4();
      final lat = jobLat + 0.00045;
      final lng = jobLng;

      final clockInCallable = functions.httpsCallable('clockIn');
      final clockInResult = await clockInCallable.call({
        'jobId': testJobId,
        'lat': lat,
        'lng': lng,
        'accuracy': 10.0,
        'clientEventId': clientEventId,
      });

      final timeEntryId = clockInResult.data['id'] as String;

      // Clock out
      final clockOutCallable = functions.httpsCallable('clockOut');
      final clockOutResult = await clockOutCallable.call({
        'timeEntryId': timeEntryId,
        'lat': lat,
        'lng': lng,
        'accuracy': 10.0,
      });

      expect(clockOutResult.data['ok'], isTrue);

      // Verify time entry was updated
      final timeEntry = await firestore
          .collection('timeEntries')
          .doc(timeEntryId)
          .get();

      expect(timeEntry.data()?['clockOutAt'], isNotNull);
    });

    test('Clock out fails outside geofence', () async {
      // First clock in
      final clientEventId = const Uuid().v4();
      final lat = jobLat + 0.00045;
      final lng = jobLng;

      final clockInCallable = functions.httpsCallable('clockIn');
      final clockInResult = await clockInCallable.call({
        'jobId': testJobId,
        'lat': lat,
        'lng': lng,
        'accuracy': 10.0,
        'clientEventId': clientEventId,
      });

      final timeEntryId = clockInResult.data['id'] as String;

      // Try to clock out from far away
      final clockOutCallable = functions.httpsCallable('clockOut');

      try {
        await clockOutCallable.call({
          'timeEntryId': timeEntryId,
          'lat': jobLat + 0.0018, // 200m away
          'lng': jobLng,
          'accuracy': 10.0,
        });
        fail('Expected exception for clock out outside geofence');
      } catch (e) {
        expect(e.toString(), contains('geofence'));
      }
    });
  });
}
