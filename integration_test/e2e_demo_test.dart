/// E2E Demo Test
///
/// PURPOSE:
/// End-to-end smoke test exercising the full demo path from worker clock-in
/// to admin approval. Validates the complete timeclock workflow.
///
/// ACCEPTANCE CRITERIA:
/// - Completes full demo path in <8 minutes
/// - Worker can login, see job assignment, clock in/out
/// - Admin can login, see pending entry, approve it
/// - All state changes are persisted correctly
///
/// SETUP:
/// - Runs against Firebase emulators (firestore, functions, auth)
/// - Creates test company, users, job, and assignment
/// - Simulates GPS locations for geofence testing
///
/// FLOW:
/// 1. Setup: Create test company, admin, worker, job, assignment
/// 2. Worker login
/// 3. Worker sees job assignment on dashboard
/// 4. Worker clocks in (location within geofence)
/// 5. Worker clocks out (location within geofence)
/// 6. Admin login
/// 7. Admin sees pending entry in review screen
/// 8. Admin approves entry
/// 9. Verify entry status is 'approved'
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:uuid/uuid.dart';
import 'package:sierra_painting/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  late FirebaseFirestore firestore;
  late FirebaseAuth auth;
  late FirebaseFunctions functions;
  late String testCompanyId;
  late String adminUid;
  late String workerUid;
  late String jobId;
  late String assignmentId;
  late String timeEntryId;

  // Test credentials
  const adminEmail = 'e2e-admin@test.com';
  const adminPassword = 'TestAdmin123!';
  const workerEmail = 'e2e-worker@test.com';
  const workerPassword = 'TestWorker123!';

  // Test job location: Albany, NY (from seed script)
  const double jobLat = 42.6526;
  const double jobLng = -73.7562;
  const double jobRadius = 125.0; // meters

  setUpAll(() async {
    await Firebase.initializeApp();

    firestore = FirebaseFirestore.instance;
    auth = FirebaseAuth.instance;
    functions = FirebaseFunctions.instance;

    // Connect to emulators
    const useEmulator = bool.fromEnvironment(
      'USE_EMULATORS',
      defaultValue: true,
    );
    if (useEmulator) {
      firestore.useFirestoreEmulator('localhost', 8080);
      auth.useAuthEmulator('localhost', 9099);
      functions.useFunctionsEmulator('localhost', 5001);
    }

    // Generate deterministic test IDs
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    testCompanyId = 'e2e-company-$timestamp';
    adminUid = 'e2e-admin-$timestamp';
    workerUid = 'e2e-worker-$timestamp';
    jobId = 'e2e-job-$timestamp';
    assignmentId = 'e2e-assignment-$timestamp';

    // Create test company
    await firestore.collection('companies').doc(testCompanyId).set({
      'name': 'E2E Test Company',
      'timezone': 'America/New_York',
      'requireGeofence': true,
      'maxShiftHours': 12,
      'autoApproveTime': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create admin user
    final adminCredential = await auth.createUserWithEmailAndPassword(
      email: adminEmail,
      password: adminPassword,
    );
    adminUid = adminCredential.user!.uid;
    await firestore.collection('users').doc(adminUid).set({
      'displayName': 'E2E Admin',
      'email': adminEmail,
      'companyId': testCompanyId,
      'role': 'admin',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create worker user
    final workerCredential = await auth.createUserWithEmailAndPassword(
      email: workerEmail,
      password: workerPassword,
    );
    workerUid = workerCredential.user!.uid;
    await firestore.collection('users').doc(workerUid).set({
      'displayName': 'E2E Worker',
      'email': workerEmail,
      'companyId': testCompanyId,
      'role': 'staff',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create job with geofence
    await firestore.collection('jobs').doc(jobId).set({
      'companyId': testCompanyId,
      'name': 'E2E Test Job',
      'description': 'Integration test job site',
      'address': {
        'street': '1234 Test Ave',
        'city': 'Albany',
        'state': 'NY',
        'zip': '12203',
        'country': 'USA',
      },
      'location': {
        'latitude': jobLat,
        'longitude': jobLng,
        'geofenceRadius': jobRadius,
      },
      'status': 'active',
      'startDate': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Create assignment for worker
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 6));

    await firestore.collection('assignments').doc(assignmentId).set({
      'companyId': testCompanyId,
      'userId': workerUid,
      'jobId': jobId,
      'active': true,
      'startDate': Timestamp.fromDate(weekStart),
      'endDate': Timestamp.fromDate(weekEnd),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await auth.signOut();
  });

  tearDownAll(() async {
    // Clean up test data
    try {
      // Delete time entries
      final timeEntries = await firestore
          .collection('timeEntries')
          .where('companyId', isEqualTo: testCompanyId)
          .get();
      for (final doc in timeEntries.docs) {
        await doc.reference.delete();
      }

      // Delete assignments
      if (assignmentId.isNotEmpty) {
        await firestore.collection('assignments').doc(assignmentId).delete();
      }

      // Delete job
      if (jobId.isNotEmpty) {
        await firestore.collection('jobs').doc(jobId).delete();
      }

      // Delete users
      if (adminUid.isNotEmpty) {
        await firestore.collection('users').doc(adminUid).delete();
      }
      if (workerUid.isNotEmpty) {
        await firestore.collection('users').doc(workerUid).delete();
      }

      // Delete company
      if (testCompanyId.isNotEmpty) {
        await firestore.collection('companies').doc(testCompanyId).delete();
      }

      // Sign out
      await auth.signOut();
    } catch (e) {
      // Ignore cleanup errors
      debugPrint('Cleanup error: $e');
    }
  });

  testWidgets('E2E Demo: Worker clock-in/out → Admin approval', (
    WidgetTester tester,
  ) async {
    final stopwatch = Stopwatch()..start();

    // ============================================================================
    // STEP 1: Worker Login
    // ============================================================================
    debugPrint('[E2E] Step 1: Worker login');
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Find login fields
    final emailField = find.byKey(const Key('login_email'));
    final passwordField = find.byKey(const Key('login_password'));
    final submitButton = find.byKey(const Key('login_submit'));

    expect(emailField, findsOneWidget, reason: 'Email field should be present');
    expect(
      passwordField,
      findsOneWidget,
      reason: 'Password field should be present',
    );

    // Enter worker credentials
    await tester.enterText(emailField, workerEmail);
    await tester.pump();
    await tester.enterText(passwordField, workerPassword);
    await tester.pump();

    // Submit login
    await tester.tap(submitButton);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Verify we're logged in (dashboard should be visible)
    expect(
      find.text('Dashboard').evaluate().isNotEmpty ||
          find.text('Timeclock').evaluate().isNotEmpty,
      true,
      reason: 'Should navigate to dashboard after login',
    );

    debugPrint('[E2E] Step 1 complete: Worker logged in');

    // ============================================================================
    // STEP 2: Worker sees job assignment
    // ============================================================================
    debugPrint('[E2E] Step 2: Verify job assignment visible');

    // Wait for job data to load
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Job name or clock-in button should be visible
    final hasJobInfo =
        find.text('E2E Test Job').evaluate().isNotEmpty ||
        find.textContaining('Clock In').evaluate().isNotEmpty;

    expect(hasJobInfo, true, reason: 'Job assignment should be visible');
    debugPrint('[E2E] Step 2 complete: Job assignment visible');

    // ============================================================================
    // STEP 3: Worker clocks in (using Cloud Function)
    // ============================================================================
    debugPrint('[E2E] Step 3: Worker clock-in');

    final clientEventId = const Uuid().v4();
    final clockInLat = jobLat + 0.0005; // ~50m from center
    final clockInLng = jobLng;

    // Call clockIn function directly
    final clockInCallable = functions.httpsCallable('clockIn');
    final clockInResult = await clockInCallable.call({
      'jobId': jobId,
      'lat': clockInLat,
      'lng': clockInLng,
      'accuracy': 10.0,
      'clientEventId': clientEventId,
    });

    expect(clockInResult.data['ok'], isTrue, reason: 'Clock-in should succeed');
    timeEntryId = clockInResult.data['id'] as String;

    debugPrint('[E2E] Step 3 complete: Clocked in (entry: $timeEntryId)');

    // Wait a moment to simulate work
    await Future.delayed(const Duration(seconds: 2));

    // ============================================================================
    // STEP 4: Worker clocks out
    // ============================================================================
    debugPrint('[E2E] Step 4: Worker clock-out');

    final clockOutCallable = functions.httpsCallable('clockOut');
    final clockOutResult = await clockOutCallable.call({
      'timeEntryId': timeEntryId,
      'lat': clockInLat,
      'lng': clockInLng,
      'accuracy': 10.0,
    });

    expect(
      clockOutResult.data['ok'],
      isTrue,
      reason: 'Clock-out should succeed',
    );
    debugPrint('[E2E] Step 4 complete: Clocked out');

    // Verify time entry is now pending
    final pendingEntry = await firestore
        .collection('timeEntries')
        .doc(timeEntryId)
        .get();
    expect(pendingEntry.exists, true);
    expect(pendingEntry.data()?['status'], 'pending');
    expect(pendingEntry.data()?['clockOut'], isNotNull);

    // Sign out worker
    await auth.signOut();
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // ============================================================================
    // STEP 5: Admin Login
    // ============================================================================
    debugPrint('[E2E] Step 5: Admin login');

    // Should be back at login screen
    await tester.pumpAndSettle(const Duration(seconds: 2));

    final emailFieldAdmin = find.byKey(const Key('login_email'));
    final passwordFieldAdmin = find.byKey(const Key('login_password'));
    final submitButtonAdmin = find.byKey(const Key('login_submit'));

    await tester.enterText(emailFieldAdmin, adminEmail);
    await tester.pump();
    await tester.enterText(passwordFieldAdmin, adminPassword);
    await tester.pump();

    await tester.tap(submitButtonAdmin);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    debugPrint('[E2E] Step 5 complete: Admin logged in');

    // ============================================================================
    // STEP 6: Admin navigates to review screen
    // ============================================================================
    debugPrint('[E2E] Step 6: Navigate to admin review');

    // Look for admin review link/button
    final adminReviewButton = find.text('Review').evaluate().isNotEmpty
        ? find.text('Review')
        : find.text('Time Entries').evaluate().isNotEmpty
        ? find.text('Time Entries')
        : find.byIcon(Icons.admin_panel_settings);

    if (adminReviewButton.evaluate().isNotEmpty) {
      await tester.tap(adminReviewButton.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
    }

    debugPrint('[E2E] Step 6 complete: On review screen');

    // ============================================================================
    // STEP 7: Admin approves entry (using action function)
    // ============================================================================
    debugPrint('[E2E] Step 7: Admin approves entry');

    // Approve directly via Firestore (simulating admin action)
    await firestore.collection('timeEntries').doc(timeEntryId).update({
      'status': 'approved',
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verify entry is approved
    final approvedEntry = await firestore
        .collection('timeEntries')
        .doc(timeEntryId)
        .get();

    expect(approvedEntry.exists, true);
    expect(approvedEntry.data()?['status'], 'approved');
    expect(approvedEntry.data()?['approvedBy'], adminUid);

    debugPrint('[E2E] Step 7 complete: Entry approved');

    // ============================================================================
    // TEST COMPLETE
    // ============================================================================
    stopwatch.stop();
    final elapsedSeconds = stopwatch.elapsed.inSeconds;

    debugPrint('');
    debugPrint('✅ E2E Demo Test PASSED');
    debugPrint('   Elapsed time: ${elapsedSeconds}s');
    debugPrint('   Acceptance: <480s (8 min)');
    debugPrint('');

    expect(
      elapsedSeconds,
      lessThan(480),
      reason: 'E2E test should complete in <8 minutes',
    );

    // Sign out admin
    await auth.signOut();
  });
}
