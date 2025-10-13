/// Job Context Service
///
/// PURPOSE:
/// Resolves which job(s) a worker should see for clock-in based on:
/// - Assignment windows (startDate/endDate in company timezone)
/// - Current location (distance to job sites)
/// - Active clock-in status
///
/// DECISION RULES:
/// 1. Only show jobs where worker has active assignment TODAY (company TZ)
/// 2. Sort by distance (nearest first)
/// 3. If only one job assigned today → auto-select
/// 4. If multiple jobs → show picker with distance to each
/// 5. If no jobs today → show "No assignments. Contact your manager."
///
/// IMPLEMENTATION NOTES (for implementation crew):
/// - Use company timezone from CompanySettings for "today" calculation
/// - Query assignments with: active=true, userId=currentUser, startDate≤today≤endDate
/// - Join with jobs collection to get lat/lng/radius
/// - Calculate distance using LocationService.calculateDistance()
/// - Cache results for 5 minutes to reduce Firestore reads
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/features/jobs/domain/job.dart';

/// Job with computed context for clock-in decision
class JobWithContext {
  final Job job;
  final DateTime assignmentStart;
  final DateTime assignmentEnd;
  final double? distanceMeters; // null if location not available
  final bool isWithinGeofence; // false if location not available

  JobWithContext({
    required this.job,
    required this.assignmentStart,
    required this.assignmentEnd,
    this.distanceMeters,
    this.isWithinGeofence = false,
  });

  /// Human-readable distance
  String get distanceDescription {
    if (distanceMeters == null) return 'Distance unknown';
    if (distanceMeters! < 50) return 'At job site';
    if (distanceMeters! < 500) return '${distanceMeters!.round()}m away';
    return '${(distanceMeters! / 1000).toStringAsFixed(1)}km away';
  }

  /// Sort priority (within geofence first, then by distance)
  int compareTo(JobWithContext other) {
    // Jobs within geofence come first
    if (isWithinGeofence && !other.isWithinGeofence) return -1;
    if (!isWithinGeofence && other.isWithinGeofence) return 1;

    // Then sort by distance
    if (distanceMeters == null && other.distanceMeters == null) return 0;
    if (distanceMeters == null) return 1;
    if (other.distanceMeters == null) return -1;
    return distanceMeters!.compareTo(other.distanceMeters!);
  }
}

/// Job selection result for clock-in flow
sealed class JobSelectionResult {}

/// Single job auto-selected (go directly to clock-in)
class SingleJobSelected extends JobSelectionResult {
  final JobWithContext job;
  SingleJobSelected(this.job);
}

/// Multiple jobs available (show picker)
class MultipleJobsAvailable extends JobSelectionResult {
  final List<JobWithContext> jobs;
  MultipleJobsAvailable(this.jobs);
}

/// No jobs assigned today (show message)
class NoJobsAssigned extends JobSelectionResult {
  final String message;
  NoJobsAssigned([
    this.message = 'No assignments for today. Contact your manager.',
  ]);
}

/// User already clocked in (show current job)
class AlreadyClockedIn extends JobSelectionResult {
  final JobWithContext currentJob;
  final DateTime clockedInAt;
  AlreadyClockedIn(this.currentJob, this.clockedInAt);
}

/// Job context service interface
abstract class JobContextService {
  /// Get jobs available for clock-in TODAY
  ///
  /// DECISION TREE:
  /// 1. Check if user has active time entry → AlreadyClockedIn
  /// 2. Query assignments for today (company TZ, active=true, window check)
  /// 3. If no assignments → NoJobsAssigned
  /// 4. Get user location (optional, for distance calculation)
  /// 5. Calculate distance to each job site
  /// 6. Sort by distance (within geofence first)
  /// 7. If exactly one job → SingleJobSelected
  /// 8. If multiple jobs → MultipleJobsAvailable
  ///
  /// IMPLEMENTATION TODO:
  /// ```dart
  /// // 1. Check active time entry
  /// final activeEntry = await _getActiveTimeEntry(userId);
  /// if (activeEntry != null) {
  ///   final job = await _getJob(activeEntry.jobId);
  ///   return AlreadyClockedIn(JobWithContext(...), activeEntry.clockInAt);
  /// }
  ///
  /// // 2. Get company settings for timezone
  /// final settings = await _getCompanySettings(companyId);
  /// final tz = getLocation(settings.timezone);
  /// final today = TZDateTime.now(tz);
  /// final todayStart = TZDateTime(tz, today.year, today.month, today.day);
  /// final todayEnd = todayStart.add(Duration(days: 1));
  ///
  /// // 3. Query assignments
  /// final assignments = await db
  ///   .collection('assignments')
  ///   .where('companyId', '==', companyId)
  ///   .where('userId', '==', userId)
  ///   .where('active', '==', true)
  ///   .where('startDate', '<=', todayEnd.toUtc())
  ///   .where('endDate', '>=', todayStart.toUtc())
  ///   .get();
  ///
  /// if (assignments.isEmpty) return NoJobsAssigned();
  ///
  /// // 4. Get location (optional)
  /// LocationResult? location;
  /// try {
  ///   location = await _locationService.getCurrentLocation();
  /// } catch (e) {
  ///   // Continue without location
  /// }
  ///
  /// // 5. Build JobWithContext list
  /// final jobsWithContext = <JobWithContext>[];
  /// for (final assignment in assignments) {
  ///   final job = await _getJob(assignment.jobId);
  ///   double? distance;
  ///   bool withinGeofence = false;
  ///
  ///   if (location != null && job.lat != null && job.lng != null) {
  ///     distance = _locationService.calculateDistance(
  ///       lat1: location.latitude,
  ///       lon1: location.longitude,
  ///       lat2: job.lat!,
  ///       lon2: job.lng!,
  ///     );
  ///     final radius = job.radiusM ?? 100;
  ///     final effectiveRadius = radius + location.accuracy;
  ///     withinGeofence = distance <= effectiveRadius;
  ///   }
  ///
  ///   jobsWithContext.add(JobWithContext(
  ///     job: job,
  ///     assignmentStart: assignment.startDate,
  ///     assignmentEnd: assignment.endDate,
  ///     distanceMeters: distance,
  ///     isWithinGeofence: withinGeofence,
  ///   ));
  /// }
  ///
  /// // 6. Sort by distance
  /// jobsWithContext.sort((a, b) => a.compareTo(b));
  ///
  /// // 7. Return result
  /// if (jobsWithContext.length == 1) {
  ///   return SingleJobSelected(jobsWithContext.first);
  /// }
  /// return MultipleJobsAvailable(jobsWithContext);
  /// ```
  Future<JobSelectionResult> getJobsForClockIn({
    required String userId,
    required String companyId,
  });

  /// Get current active job (if clocked in)
  ///
  /// Returns null if not clocked in.
  ///
  /// IMPLEMENTATION TODO:
  /// ```dart
  /// final query = await db
  ///   .collection('timeEntries')
  ///   .where('companyId', '==', companyId)
  ///   .where('userId', '==', userId)
  ///   .where('clockOutAt', '==', null)
  ///   .limit(1)
  ///   .get();
  ///
  /// if (query.isEmpty) return null;
  ///
  /// final entry = TimeEntry.fromFirestore(query.first);
  /// final job = await _getJob(entry.jobId);
  /// return JobWithContext(
  ///   job: job,
  ///   assignmentStart: entry.clockInAt,
  ///   assignmentEnd: entry.clockInAt,
  /// );
  /// ```
  Future<JobWithContext?> getCurrentJob({
    required String userId,
    required String companyId,
  });

  /// Refresh job context (force cache invalidation)
  Future<void> refresh();
}

/// Provider for job context service
/// Implementation will be provided by concrete class
final jobContextServiceProvider = Provider<JobContextService>((ref) {
  throw UnimplementedError(
    'JobContextService provider must be overridden with concrete implementation',
  );
});

/// Provider for current job selection
/// Watches for changes and updates UI reactively
final jobSelectionProvider = FutureProvider.family<JobSelectionResult, String>((
  ref,
  userId,
) async {
  final service = ref.watch(jobContextServiceProvider);
  // TODO: Get companyId from auth provider
  final companyId = 'TODO';
  return await service.getJobsForClockIn(userId: userId, companyId: companyId);
});
