/// Timeclock Providers
///
/// Comprehensive Riverpod providers for Worker Dashboard and timeclock features.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/auth/company_claims.dart';
import 'package:sierra_painting/core/domain/company_settings.dart';
import 'package:sierra_painting/core/providers.dart';
import 'package:sierra_painting/features/timeclock/domain/time_entry.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// Provider for company settings
final companySettingsProvider = FutureProvider<CompanySettings?>((ref) async {
  final userProfile = await ref.watch(userProfileProvider.future);
  if (userProfile == null || userProfile.companyId.isEmpty) return null;

  final db = ref.watch(firestoreProvider);
  final doc = await db.collection('companies').doc(userProfile.companyId).get();

  if (!doc.exists) return null;
  return CompanySettings.fromFirestore(doc);
});

/// Provider for active time entry (currently clocked in)
final activeTimeEntryProvider = StreamProvider<TimeEntry?>((ref) {
  final userProfile = ref.watch(userProfileProvider).value;
  if (userProfile == null || userProfile.companyId.isEmpty) {
    return Stream.value(null);
  }

  final db = ref.watch(firestoreProvider);
  return db
      .collection('time_entries')
      .where('companyId', isEqualTo: userProfile.companyId)
      .where('userId', isEqualTo: userProfile.uid)
      .where('status', isEqualTo: 'active')
      .limit(1)
      .snapshots()
      .map((snapshot) {
        if (snapshot.docs.isEmpty) return null;
        return TimeEntry.fromFirestore(snapshot.docs.first);
      });
});

/// Provider for this week's time entries (in company timezone)
final timeEntriesThisWeekProvider = FutureProvider<List<TimeEntry>>((
  ref,
) async {
  final userProfile = await ref.watch(userProfileProvider.future);
  if (userProfile == null || userProfile.companyId.isEmpty) return [];

  final settings = await ref.watch(companySettingsProvider.future);
  if (settings == null) return [];

  // Initialize timezone database if not already initialized
  try {
    tz.initializeTimeZones();
  } catch (_) {
    // Already initialized
  }

  // Calculate week range in company timezone
  final location = tz.getLocation(settings.timezone);
  final now = tz.TZDateTime.now(location);
  final weekday = now.weekday; // Monday = 1, Sunday = 7
  final daysToMonday = weekday - 1;
  final weekStart = tz.TZDateTime(
    location,
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: daysToMonday));
  final weekEnd = weekStart.add(const Duration(days: 7));

  final db = ref.watch(firestoreProvider);
  final snapshot = await db
      .collection('time_entries')
      .where('companyId', isEqualTo: userProfile.companyId)
      .where('userId', isEqualTo: userProfile.uid)
      .where('clockInAt', isGreaterThanOrEqualTo: weekStart.toUtc())
      .where('clockInAt', isLessThan: weekEnd.toUtc())
      .orderBy('clockInAt', descending: true)
      .get()
      .timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Week entries query timed out'),
      );

  return snapshot.docs.map((doc) => TimeEntry.fromFirestore(doc)).toList();
});

/// Provider for recent time entries (last 10)
final recentTimeEntriesProvider = StreamProvider<List<TimeEntry>>((ref) {
  final userProfile = ref.watch(userProfileProvider).value;
  if (userProfile == null || userProfile.companyId.isEmpty) {
    return Stream.value([]);
  }

  final db = ref.watch(firestoreProvider);
  return db
      .collection('time_entries')
      .where('companyId', isEqualTo: userProfile.companyId)
      .where('userId', isEqualTo: userProfile.uid)
      .orderBy('clockInAt', descending: true)
      .limit(100) // Limit to prevent memory leaks
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => TimeEntry.fromFirestore(doc)).toList(),
      );
});

/// Provider for this week's total hours
final thisWeekTotalHoursProvider = FutureProvider<double>((ref) async {
  final entries = await ref.watch(timeEntriesThisWeekProvider.future);
  return entries.fold<double>(
    0.0,
    (sum, entry) => sum + (entry.durationHours ?? 0.0),
  );
});

/// Provider for this week's unique job sites count
final thisWeekJobSitesProvider = FutureProvider<int>((ref) async {
  final entries = await ref.watch(timeEntriesThisWeekProvider.future);
  final uniqueJobIds = entries.map((e) => e.jobId).toSet();
  return uniqueJobIds.length;
});

/// Provider for elapsed time since clock-in (updates every minute)
/// Returns null if not clocked in
final elapsedTimeProvider = StreamProvider<Duration?>((ref) async* {
  while (true) {
    final activeEntry = ref.watch(activeTimeEntryProvider).value;
    if (activeEntry == null) {
      yield null;
    } else {
      yield DateTime.now().difference(activeEntry.clockIn);
    }
    await Future.delayed(const Duration(minutes: 1));
  }
});

// === MINIMAL PROVIDERS FOR VALIDATION ===

/// Provider for active job (auto-select from assignments)
final activeJobProvider = FutureProvider((ref) async {
  debugPrint('🟢 activeJobProvider: Starting');

  final user = ref.watch(currentUserProvider);
  if (user == null) {
    debugPrint('🟢 activeJobProvider: No user, returning null');
    return null;
  }
  debugPrint('🟢 activeJobProvider: User UID = ${user.uid}');

  final db = ref.watch(firestoreProvider);

  // Fetch company ID from Firebase Auth custom claims
  final company = await ref.watch(companyIdProvider.future);
  if (company == null || company.isEmpty) {
    debugPrint('🔴 activeJobProvider: No company claim found');
    return null;
  }
  debugPrint('🟢 activeJobProvider: Company ID from claims = $company');

  // Query active assignment for this user
  debugPrint('🟢 activeJobProvider: Querying assignments...');
  final assignmentsQuery = await db
      .collection('assignments')
      .where('userId', isEqualTo: user.uid)
      .where('companyId', isEqualTo: company)
      .where('active', isEqualTo: true)
      .limit(1)
      .get()
      .timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Assignment query timed out'),
      );

  debugPrint(
    '🟢 activeJobProvider: Found ${assignmentsQuery.docs.length} assignments',
  );

  if (assignmentsQuery.docs.isEmpty) return null;

  final assignment = assignmentsQuery.docs.first.data();
  final jobId = assignment['jobId'] as String;
  debugPrint('🟢 activeJobProvider: Job ID from assignment = $jobId');

  // Get the job
  debugPrint('🟢 activeJobProvider: Fetching job document...');
  final jobDoc = await db
      .collection('jobs')
      .doc(jobId)
      .get()
      .timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Job document fetch timed out'),
      );
  debugPrint('🟢 activeJobProvider: Job doc exists = ${jobDoc.exists}');

  if (!jobDoc.exists) return null;

  final jobData = jobDoc.data();
  if (jobData == null) return null;

  // Ensure document ID is included in returned map
  debugPrint('🟢 activeJobProvider: Returning job data with ID = ${jobDoc.id}');
  return {'id': jobDoc.id, ...jobData};
});

/// Simple provider for active time entry
final activeEntryProvider = FutureProvider<TimeEntry?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final db = ref.watch(firestoreProvider);

  // Fetch company ID from Firebase Auth custom claims
  final company = await ref.watch(companyIdProvider.future);
  if (company == null || company.isEmpty) {
    return null; // No company claim, cannot query
  }

  // Query active time entry (no clockOutAt)
  final entriesQuery = await db
      .collection('time_entries')
      .where('userId', isEqualTo: user.uid)
      .where('companyId', isEqualTo: company)
      .where('clockOutAt', isEqualTo: null)
      .limit(1)
      .get()
      .timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Time entry query timed out'),
      );

  if (entriesQuery.docs.isEmpty) return null;

  return TimeEntry.fromFirestore(entriesQuery.docs.first);
});
