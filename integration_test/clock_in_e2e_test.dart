/// Clock In/Out End-to-End Integration Test
///
/// Tests the full clock in/out flow using TimeclockService with us-east4 region.
/// Validates canonical schema usage and geofence validation.
///
/// Run with: flutter test integration_test/clock_in_e2e_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Import services under test
import 'package:sierra_painting/core/services/timeclock_service.dart';
import 'package:sierra_painting/core/models/time_entry.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Test constants (must match setup_test_data.cjs)
  const String testWorkerEmail = 'worker@test.com';
  const String testWorkerPassword = 'testpass123';
  const String testJobId = 'job_painted_ladies';
  const String testCompanyId = 'company_dsierrapainting';

  // SF Painted Ladies coordinates (from setup script)
  const double jobLat = 37.7793;
  const double jobLng = -122.4193;
  // const double jobRadiusM = 150.0;  // Unused for now

  late FirebaseAuth auth;
  late FirebaseFirestore firestore;
  late TimeclockService timeclockService;

  setUpAll(() async {
    await Firebase.initializeApp();
    auth = FirebaseAuth.instance;
    firestore = FirebaseFirestore.instance;
    timeclockService = TimeclockService.usEast4(); // us-east4 region
  });

  tearDown(() async {
    // Clean up test entries after each test
    final userId = auth.currentUser?.uid;
    if (userId != null) {
      final entries = await firestore
          .collection('time_entries')
          .where('userId', isEqualTo: userId)
          .get();

      for (final doc in entries.docs) {
        await doc.reference.delete();
      }
    }

    // Sign out
    await auth.signOut();
  });

  group('Clock In E2E Tests', () {
    test('should successfully clock in when inside geofence', () async {
      // 1. Authenticate as test worker
      final userCredential = await auth.signInWithEmailAndPassword(
        email: testWorkerEmail,
        password: testWorkerPassword,
      );

      expect(userCredential.user, isNotNull);
      final userId = userCredential.user!.uid;

      // 2. Verify custom claims (companyId, role)
      final idTokenResult = await userCredential.user!.getIdTokenResult();
      expect(idTokenResult.claims?['companyId'], equals(testCompanyId));
      expect(idTokenResult.claims?['role'], equals('worker'));

      // 3. Clock in at job site (inside geofence)
      final clientEventId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      final result = await timeclockService.clockIn(
        jobId: testJobId,
        lat: jobLat + 0.0001, // ~11m north (well within 150m radius)
        lng: jobLng,
        accuracy: 10.0,
        clientEventId: clientEventId,
        notes: 'E2E test clock in',
      );

      expect(result['ok'], isTrue);
      expect(result['id'], isNotNull);

      // 4. Verify time entry was created with canonical schema
      final entryId = result['id'] as String;
      final entryDoc = await firestore.doc('time_entries/$entryId').get();

      expect(entryDoc.exists, isTrue);

      final entry = TimeEntry.fromMap(entryDoc.data()!, entryDoc.id);

      // Verify canonical field names
      expect(entry.entryId, equals(entryId));
      expect(entry.companyId, equals(testCompanyId));
      expect(entry.userId, equals(userId));
      expect(entry.jobId, equals(testJobId));
      expect(entry.clockInGeofenceValid, isTrue);
      expect(entry.clockInLocation, isNotNull);
      expect(entry.clockOutAt, isNull); // Should be null (still active)

      // Verify location accuracy
      expect(entry.clockInLocation!.lat, closeTo(jobLat + 0.0001, 0.0001));
      expect(entry.clockInLocation!.lng, closeTo(jobLng, 0.0001));
    });

    test('should reject clock in when outside geofence', () async {
      // 1. Authenticate as test worker
      await auth.signInWithEmailAndPassword(
        email: testWorkerEmail,
        password: testWorkerPassword,
      );

      // 2. Attempt to clock in far from job site (outside geofence)
      final clientEventId = 'test_${DateTime.now().millisecondsSinceEpoch}';

      expect(
        () => timeclockService.clockIn(
          jobId: testJobId,
          lat: jobLat + 0.01, // ~1.1km north (outside 150m radius)
          lng: jobLng,
          accuracy: 10.0,
          clientEventId: clientEventId,
        ),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('OUTSIDE_GEOFENCE') ||
                e.toString().contains('Outside geofence'),
          ),
        ),
      );
    });

    test('should prevent double clock in (idempotency)', () async {
      // 1. Authenticate as test worker
      await auth.signInWithEmailAndPassword(
        email: testWorkerEmail,
        password: testWorkerPassword,
      );

      // 2. Clock in first time
      final clientEventId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      final result1 = await timeclockService.clockIn(
        jobId: testJobId,
        lat: jobLat,
        lng: jobLng,
        accuracy: 10.0,
        clientEventId: clientEventId,
      );

      expect(result1['ok'], isTrue);
      final entryId1 = result1['id'] as String;

      // 3. Attempt to clock in again with same clientEventId (idempotent)
      final result2 = await timeclockService.clockIn(
        jobId: testJobId,
        lat: jobLat,
        lng: jobLng,
        accuracy: 10.0,
        clientEventId: clientEventId, // Same clientEventId
      );

      expect(result2['ok'], isTrue);
      expect(result2['id'], equals(entryId1)); // Should return same entry ID

      // 4. Attempt to clock in again with different clientEventId (should fail - already clocked in)
      expect(
        () => timeclockService.clockIn(
          jobId: testJobId,
          lat: jobLat,
          lng: jobLng,
          accuracy: 10.0,
          clientEventId: 'different_${DateTime.now().millisecondsSinceEpoch}',
        ),
        throwsA(
          predicate(
            (e) =>
                e.toString().contains('ALREADY_CLOCKED_IN') ||
                e.toString().contains('Already clocked in'),
          ),
        ),
      );
    });
  });

  group('Clock Out E2E Tests', () {
    late String activeEntryId;

    setUp(() async {
      // Clock in before each clock out test
      await auth.signInWithEmailAndPassword(
        email: testWorkerEmail,
        password: testWorkerPassword,
      );

      final clientEventId = 'setup_${DateTime.now().millisecondsSinceEpoch}';
      final result = await timeclockService.clockIn(
        jobId: testJobId,
        lat: jobLat,
        lng: jobLng,
        accuracy: 10.0,
        clientEventId: clientEventId,
      );

      activeEntryId = result['id'] as String;
    });

    test('should successfully clock out when inside geofence', () async {
      // Clock out at job site (inside geofence)
      final clientEventId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      final result = await timeclockService.clockOut(
        timeEntryId: activeEntryId,
        lat: jobLat,
        lng: jobLng,
        accuracy: 10.0,
        clientEventId: clientEventId,
      );

      expect(result['ok'], isTrue);
      expect(result['warning'], isNull); // No warning when inside geofence

      // Verify time entry was updated with clockOut fields
      final entryDoc = await firestore.doc('time_entries/$activeEntryId').get();
      final entry = TimeEntry.fromMap(entryDoc.data()!, entryDoc.id);

      expect(entry.clockOutAt, isNotNull);
      expect(entry.clockOutGeofenceValid, isTrue);
      expect(entry.clockOutLocation, isNotNull);
    });

    test('should clock out with warning when outside geofence', () async {
      // Clock out far from job site (outside geofence)
      final clientEventId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      final result = await timeclockService.clockOut(
        timeEntryId: activeEntryId,
        lat: jobLat + 0.01, // ~1.1km north (outside 150m radius)
        lng: jobLng,
        accuracy: 10.0,
        clientEventId: clientEventId,
      );

      expect(result['ok'], isTrue);
      expect(result['warning'], isNotNull); // Should have warning

      // Verify time entry was flagged for review
      final entryDoc = await firestore.doc('time_entries/$activeEntryId').get();
      final data = entryDoc.data()!;
      final entry = TimeEntry.fromMap(data, entryDoc.id);

      expect(entry.clockOutAt, isNotNull);
      expect(entry.clockOutGeofenceValid, isFalse);
      expect(
        data['exceptionTags'],
        contains('geofence_out'),
      ); // Flagged for admin review
    });

    test('should be idempotent for duplicate clock out requests', () async {
      // Clock out first time
      final clientEventId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      final result1 = await timeclockService.clockOut(
        timeEntryId: activeEntryId,
        lat: jobLat,
        lng: jobLng,
        accuracy: 10.0,
        clientEventId: clientEventId,
      );

      expect(result1['ok'], isTrue);

      // Clock out again with same clientEventId (idempotent)
      final result2 = await timeclockService.clockOut(
        timeEntryId: activeEntryId,
        lat: jobLat,
        lng: jobLng,
        accuracy: 10.0,
        clientEventId: clientEventId,
      );

      expect(result2['ok'], isTrue); // Should succeed (idempotent)
    });
  });

  group('Firestore Rules Integration', () {
    test('time entry core fields should be immutable', () async {
      // 1. Clock in
      await auth.signInWithEmailAndPassword(
        email: testWorkerEmail,
        password: testWorkerPassword,
      );

      final clientEventId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      final result = await timeclockService.clockIn(
        jobId: testJobId,
        lat: jobLat,
        lng: jobLng,
        accuracy: 10.0,
        clientEventId: clientEventId,
      );

      final entryId = result['id'] as String;

      // 2. Attempt to modify immutable field (should fail)
      final entryRef = firestore.doc('time_entries/$entryId');

      expect(
        () => entryRef.update({
          'companyId': 'different_company', // Immutable field
        }),
        throwsA(isA<FirebaseException>()),
      );

      expect(
        () => entryRef.update({
          'userId': 'different_user', // Immutable field
        }),
        throwsA(isA<FirebaseException>()),
      );

      expect(
        () => entryRef.update({
          'jobId': 'different_job', // Immutable field
        }),
        throwsA(isA<FirebaseException>()),
      );

      expect(
        () => entryRef.update({
          'clockInGeofenceValid': false, // Immutable field (prevents fraud)
        }),
        throwsA(isA<FirebaseException>()),
      );
    });
  });
}
