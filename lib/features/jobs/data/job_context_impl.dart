/// Job Context Service Implementation
///
/// Concrete implementation of JobContextService for resolving worker assignments.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/domain/company_settings.dart';
import 'package:sierra_painting/core/providers.dart';
import 'package:sierra_painting/core/services/location_service.dart';
import 'package:sierra_painting/features/jobs/domain/assignment.dart';
import 'package:sierra_painting/features/jobs/domain/job.dart';
import 'package:sierra_painting/features/jobs/domain/job_context.dart';
import 'package:sierra_painting/features/timeclock/domain/time_entry.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

/// Concrete implementation of JobContextService
class JobContextServiceImpl implements JobContextService {
  final FirebaseFirestore _firestore;
  final LocationService _locationService;

  // Cache for company settings (5 minutes)
  final Map<String, _CachedCompanySettings> _companyCache = {};
  static const _companyCacheDuration = Duration(minutes: 5);

  // Cache for job selection (5 minutes)
  final Map<String, _CachedJobSelection> _jobSelectionCache = {};
  static const _jobSelectionCacheDuration = Duration(minutes: 5);

  JobContextServiceImpl(this._firestore, this._locationService) {
    // Initialize timezone database
    tz.initializeTimeZones();
  }

  @override
  Future<JobSelectionResult> getJobsForClockIn({
    required String userId,
    required String companyId,
  }) async {
    // Check cache first
    final cacheKey = '$companyId:$userId';
    final cached = _jobSelectionCache[cacheKey];
    if (cached != null && !cached.isExpired) {
      return cached.result;
    }

    // 1. Check if user has active time entry → AlreadyClockedIn
    final activeEntry = await _getActiveTimeEntry(userId, companyId);
    if (activeEntry != null) {
      final job = await _getJob(activeEntry.jobId);
      final result = AlreadyClockedIn(
        JobWithContext(
          job: job,
          assignmentStart: activeEntry.clockIn,
          assignmentEnd: activeEntry.clockIn,
        ),
        activeEntry.clockIn,
      );
      _jobSelectionCache[cacheKey] = _CachedJobSelection(
        result,
        DateTime.now(),
      );
      return result;
    }

    // 2. Get company settings for timezone
    final settings = await _getCompanySettings(companyId);
    final location = tz.getLocation(settings.timezone);
    final now = tz.TZDateTime.now(location);
    final todayStart = tz.TZDateTime(location, now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    // 3. Query assignments for today
    final assignmentsSnapshot = await _firestore
        .collection('assignments')
        .where('companyId', isEqualTo: companyId)
        .where('userId', isEqualTo: userId)
        .where('active', isEqualTo: true)
        .get();

    // Filter assignments that are valid for today
    final validAssignments = assignmentsSnapshot.docs
        .map((doc) => Assignment.fromFirestore(doc))
        .where((assignment) {
          // Check if today falls within assignment window
          final startDate =
              assignment.startDate?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final endDate =
              assignment.endDate?.toUtc() ??
              DateTime.now().add(const Duration(days: 365));

          return startDate.isBefore(todayEnd.toUtc()) &&
              endDate.isAfter(todayStart.toUtc());
        })
        .toList();

    if (validAssignments.isEmpty) {
      final result = NoJobsAssigned();
      _jobSelectionCache[cacheKey] = _CachedJobSelection(
        result,
        DateTime.now(),
      );
      return result;
    }

    // 4. Get user location (optional, for distance calculation)
    LocationResult? userLocation;
    try {
      userLocation = await _locationService.getCurrentLocation(
        timeout: const Duration(seconds: 5),
      );
    } catch (e) {
      // Continue without location - distance will be null
    }

    // 5. Build JobWithContext list
    final jobsWithContext = <JobWithContext>[];
    for (final assignment in validAssignments) {
      final job = await _getJob(assignment.jobId);
      double? distance;
      bool withinGeofence = false;

      if (userLocation != null) {
        distance = _locationService.calculateDistance(
          lat1: userLocation.latitude,
          lon1: userLocation.longitude,
          lat2: job.location.latitude,
          lon2: job.location.longitude,
        );

        // Effective radius includes user location accuracy
        final effectiveRadius =
            job.location.geofenceRadius + userLocation.accuracy;
        withinGeofence = distance <= effectiveRadius;
      }

      jobsWithContext.add(
        JobWithContext(
          job: job,
          assignmentStart: assignment.startDate ?? DateTime.now(),
          assignmentEnd: assignment.endDate ?? DateTime.now(),
          distanceMeters: distance,
          isWithinGeofence: withinGeofence,
        ),
      );
    }

    // 6. Sort by distance (within geofence first)
    jobsWithContext.sort((a, b) => a.compareTo(b));

    // 7. Return result
    final JobSelectionResult result;
    if (jobsWithContext.length == 1) {
      result = SingleJobSelected(jobsWithContext.first);
    } else {
      result = MultipleJobsAvailable(jobsWithContext);
    }

    _jobSelectionCache[cacheKey] = _CachedJobSelection(result, DateTime.now());
    return result;
  }

  @override
  Future<JobWithContext?> getCurrentJob({
    required String userId,
    required String companyId,
  }) async {
    final activeEntry = await _getActiveTimeEntry(userId, companyId);
    if (activeEntry == null) return null;

    final job = await _getJob(activeEntry.jobId);
    return JobWithContext(
      job: job,
      assignmentStart: activeEntry.clockIn,
      assignmentEnd: activeEntry.clockIn,
    );
  }

  @override
  Future<void> refresh() async {
    _jobSelectionCache.clear();
    _companyCache.clear();
  }

  /// Get active time entry for user (if any)
  Future<TimeEntry?> _getActiveTimeEntry(
    String userId,
    String companyId,
  ) async {
    final query = await _firestore
        .collection('timeEntries')
        .where('companyId', isEqualTo: companyId)
        .where('workerId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return TimeEntry.fromFirestore(query.docs.first);
  }

  /// Get job by ID
  Future<Job> _getJob(String jobId) async {
    final doc = await _firestore.collection('jobs').doc(jobId).get();
    if (!doc.exists) {
      throw Exception('Job not found: $jobId');
    }
    return Job.fromFirestore(doc);
  }

  /// Get company settings with caching
  Future<CompanySettings> _getCompanySettings(String companyId) async {
    final cached = _companyCache[companyId];
    if (cached != null && !cached.isExpired) {
      return cached.settings;
    }

    final doc = await _firestore.collection('companies').doc(companyId).get();
    if (!doc.exists) {
      throw Exception('Company not found: $companyId');
    }

    final settings = CompanySettings.fromFirestore(doc);
    _companyCache[companyId] = _CachedCompanySettings(settings, DateTime.now());
    return settings;
  }
}

/// Cached company settings
class _CachedCompanySettings {
  final CompanySettings settings;
  final DateTime cachedAt;

  _CachedCompanySettings(this.settings, this.cachedAt);

  bool get isExpired =>
      DateTime.now().difference(cachedAt) >
      JobContextServiceImpl._companyCacheDuration;
}

/// Cached job selection result
class _CachedJobSelection {
  final JobSelectionResult result;
  final DateTime cachedAt;

  _CachedJobSelection(this.result, this.cachedAt);

  bool get isExpired =>
      DateTime.now().difference(cachedAt) >
      JobContextServiceImpl._jobSelectionCacheDuration;
}

/// Provider override for JobContextService
final jobContextServiceImplProvider = Provider<JobContextService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final locationService = ref.watch(locationServiceProvider);
  return JobContextServiceImpl(firestore, locationService);
});
