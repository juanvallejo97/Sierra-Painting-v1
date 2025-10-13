/// Worker Dashboard Screen — Production Skeleton
///
/// PURPOSE:
/// Primary interface for field workers. "It just works" demo on staging.
///
/// FEATURES:
/// - Large primary CTA (Clock In/Out) at top — 64px height, 44px min touch target
/// - Permission primer before system dialog
/// - This week's hours (company timezone calculation)
/// - Next/active job card with address + distance
/// - Pending sync chip for offline operations
/// - Clear error handling with structured messages
/// - Accessibility: semantic labels, high contrast, WCAG AA
///
/// DECISION TREE (Clock-In):
/// ```
/// START
///  ├─ Check permission status
///  │   ├─ Not granted → Show LocationPermissionPrimer → Request
///  │   └─ Granted → Continue
///  ├─ Get current location (10s timeout)
///  │   ├─ Success
///  │   │   ├─ Accuracy > 50m → Show stabilization tip + retry option
///  │   │   └─ Accuracy ≤ 50m → Continue
///  │   └─ Fail → Show error with "Open Settings" action
///  ├─ Get jobs for today (JobContext)
///  │   ├─ No jobs → Show "No assignments. Contact manager."
///  │   ├─ One job → Auto-select
///  │   └─ Multiple jobs → Show picker with distance to each
///  ├─ Check geofence
///  │   ├─ Within radius + accuracy buffer → Call clockIn() → Success toast
///  │   └─ Outside geofence → Show distance + "Explain Issue" shortcut
///  └─ If offline → Queue event with idempotency token → Show "Pending sync" chip
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/features/timeclock/domain/time_entry.dart';
import 'package:sierra_painting/features/jobs/domain/job.dart';
import 'package:sierra_painting/features/jobs/domain/job_context.dart';
// import 'package:sierra_painting/core/services/location_service.dart' hide LocationException;  // TODO: Uncomment when implementing
import 'package:sierra_painting/core/services/location_helper.dart';
import 'package:sierra_painting/core/ui/connectivity_banner.dart';
import 'package:sierra_painting/features/timeclock/presentation/widgets/location_permission_primer.dart';
import 'package:sierra_painting/features/timeclock/presentation/widgets/pending_sync_chip.dart';

/// Worker Dashboard Screen — Staging Production Skeleton
class WorkerDashboardScreenV2 extends ConsumerStatefulWidget {
  const WorkerDashboardScreenV2({super.key});

  @override
  ConsumerState<WorkerDashboardScreenV2> createState() =>
      _WorkerDashboardScreenV2State();
}

class _WorkerDashboardScreenV2State
    extends ConsumerState<WorkerDashboardScreenV2> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // TODO: Wire to providers
    // final user = ref.watch(currentUserProvider);
    // final activeEntry = ref.watch(activeTimeEntryProvider);
    // final jobSelection = ref.watch(jobSelectionProvider(user.uid));
    // final syncStatus = ref.watch(syncStatusProvider);

    final hasActiveEntry = false; // activeEntry != null
    // ignore: dead_code
    final hasPendingSync = false; // syncStatus.hasPending

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Timesheet'),
        actions: [
          // Pending sync indicator
          if (hasPendingSync)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: PendingSyncChip(),
            ),
          // GPS status indicator
          Semantics(
            label: 'GPS Status',
            button: true,
            child: IconButton(
              icon: const Icon(Icons.location_on),
              onPressed: _showGPSStatus,
              tooltip: 'GPS Status',
              iconSize: 24, // Ensure visibility
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // P: Connectivity banner (shows when offline or syncing)
          const ConnectivityBanner(),

          // Main content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Active Clock-In Status Card
                  _buildStatusCard(context, hasActiveEntry: hasActiveEntry),
                  const SizedBox(height: 16),

                  // PRIMARY CTA — 64px height for easy tapping
                  _buildPrimaryActionButton(
                    context,
                    hasActiveEntry: hasActiveEntry,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 24),

                  // This Week's Summary (company TZ)
                  _buildWeeklySummary(context),
                  const SizedBox(height: 24),

                  // Next/Active Job Card
                  _buildJobCard(context, hasActiveEntry: hasActiveEntry),
                  const SizedBox(height: 24),

                  // Recent Time Entries
                  _buildRecentEntries(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build status card showing current clock-in state
  Widget _buildStatusCard(
    BuildContext context, {
    required bool hasActiveEntry,
  }) {
    // TODO: Get actual data from providers
    final currentJob = null; // Job?
    final clockInTime = null; // DateTime?
    final elapsedDuration = null; // Duration?

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          label: hasActiveEntry
              ? 'Currently clocked in and working'
              : 'Not clocked in',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasActiveEntry ? Icons.work : Icons.home,
                    color: hasActiveEntry ? Colors.green : Colors.grey,
                    size: 32,
                    semanticLabel: hasActiveEntry ? 'Working' : 'Not working',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasActiveEntry
                              ? 'Currently Working'
                              : 'Not Clocked In',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        if (hasActiveEntry && currentJob != null)
                          Text(
                            'Job: ${(currentJob as Job).name}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (hasActiveEntry && clockInTime != null) ...[
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Clock In Time:'),
                    Text(
                      _formatTime(clockInTime),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Elapsed Time:'),
                    Text(
                      elapsedDuration != null
                          ? _formatDuration(elapsedDuration)
                          : '0h 0m',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build primary clock in/out button
  /// ACCESSIBILITY: 64px height, high contrast, semantic label
  Widget _buildPrimaryActionButton(
    BuildContext context, {
    required bool hasActiveEntry,
    required bool isLoading,
  }) {
    return Semantics(
      button: true,
      label: hasActiveEntry ? 'Clock Out' : 'Clock In',
      enabled: !isLoading,
      child: SizedBox(
        width: double.infinity,
        height: 64, // Large touch target
        child: ElevatedButton(
          onPressed: isLoading
              ? null
              : () async {
                  if (hasActiveEntry) {
                    await _handleClockOut();
                  } else {
                    await _handleClockIn();
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: hasActiveEntry ? Colors.orange : Colors.green,
            foregroundColor: Colors.white,
            // High contrast for accessibility
            elevation: 4,
          ),
          child: isLoading
              ? const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                )
              : Text(
                  hasActiveEntry ? 'Clock Out' : 'Clock In',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  /// Build this week's summary
  /// TODO: Calculate week range using company timezone from CompanySettings
  Widget _buildWeeklySummary(BuildContext context) {
    // TODO: Get data from providers
    // final settings = ref.watch(companySettingsProvider);
    // final tz = getLocation(settings.timezone); // America/New_York
    // final now = TZDateTime.now(tz);
    // final weekStart = now.subtract(Duration(days: now.weekday - 1));
    // final weekEnd = weekStart.add(Duration(days: 7));
    // final entries = ref.watch(timeEntriesThisWeekProvider(weekStart, weekEnd));
    // final totalHours = entries.fold<double>(0, (sum, e) => sum + (e.durationHours ?? 0));

    final totalHoursThisWeek = 0.0;
    final jobSitesThisWeek = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This Week', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                icon: Icons.access_time,
                label: 'Total Hours',
                value: totalHoursThisWeek.toStringAsFixed(1),
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                context,
                icon: Icons.location_on,
                label: 'Job Sites',
                value: '$jobSitesThisWeek',
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          label: '$label: $value',
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  /// Build next/active job card with address + distance
  Widget _buildJobCard(BuildContext context, {required bool hasActiveEntry}) {
    // TODO: Get from JobContextService
    // final jobSelection = ref.watch(jobSelectionProvider(currentUserId));
    // switch (jobSelection) {
    //   case SingleJobSelected(job: final job):
    //     return _renderJobCard(job);
    //   case MultipleJobsAvailable(jobs: final jobs):
    //     return _renderNextJob(jobs.first); // Show nearest
    //   case NoJobsAssigned(message: final msg):
    //     return _renderNoJobs(msg);
    //   case AlreadyClockedIn(currentJob: final job):
    //     return _renderActiveJob(job);
    // }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasActiveEntry ? 'Active Job' : 'Next Job',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            // TODO: Replace with actual job data
            Row(
              children: [
                Icon(
                  hasActiveEntry ? Icons.work : Icons.location_on,
                  color: hasActiveEntry ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Maple Ave Interior',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        '1234 Maple Ave, Albany, NY',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      // Distance indicator
                      if (!hasActiveEntry)
                        const Text(
                          '150m away', // job.distanceDescription
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build recent entries list
  Widget _buildRecentEntries(BuildContext context) {
    // TODO: Get from provider
    // final entries = ref.watch(recentTimeEntriesProvider(currentUserId));

    final entries = <TimeEntry>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Entries', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No time entries yet',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
            ),
          )
        else
          ...entries.map((entry) => _buildTimeEntryCard(context, entry)),
      ],
    );
  }

  Widget _buildTimeEntryCard(BuildContext context, TimeEntry entry) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          entry.clockOut != null ? Icons.check_circle : Icons.pending,
          color: entry.clockOut != null ? Colors.green : Colors.orange,
        ),
        title: Text('Job: ${entry.jobId}'),
        subtitle: Text(
          '${_formatTime(entry.clockIn)} - ${entry.clockOut != null ? _formatTime(entry.clockOut!) : 'In Progress'}',
        ),
        trailing: entry.durationHours != null
            ? Text(
                '${entry.durationHours!.toStringAsFixed(1)}h',
                style: const TextStyle(fontWeight: FontWeight.bold),
              )
            : null,
      ),
    );
  }

  /// DECISION TREE: Handle clock in action
  ///
  /// FULL FLOW:
  /// 1. Check permission status
  /// 2. Request if needed (with primer)
  /// 3. Get location with accuracy check
  /// 4. Get jobs for today
  /// 5. Select job (or show picker)
  /// 6. Check geofence
  /// 7. Call API or queue offline
  Future<void> _handleClockIn() async {
    setState(() => _isLoading = true);

    try {
      // STEP 1: Ensure location permission (J6)
      final hasPermission = await LocationHelper.ensurePermission();

      if (!hasPermission) {
        // Show primer dialog explaining why we need location
        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          builder: (context) => const LocationPermissionPrimer(),
        );

        if (shouldOpenSettings == true) {
          // User wants to open settings - guide them there
          _showMessage(
            'Please enable location permission in Settings → App Permissions',
            isError: true,
          );
        } else {
          _showMessage('Location permission needed to clock in', isError: true);
        }
        return;
      }

      // STEP 2: Get current location with 6s timeout and fallbacks (J6)
      try {
        final location = await LocationHelper.getCurrent(
          timeout: const Duration(seconds: 6),
        );
        // TODO: Use location for geofence check
        // ignore: unused_local_variable
        final lat = location.lat;
        // ignore: unused_local_variable
        final lng = location.lng;
      } on LocationException catch (e) {
        // User-friendly error from LocationHelper
        _showMessage(e.message, isError: true);
        return;
      }

      // STEP 3: Get jobs for today
      // final jobContextService = ref.read(jobContextServiceProvider);
      // final userId = ref.read(currentUserProvider).uid;
      // final companyId = ref.read(currentUserProvider).companyId;
      // final jobSelection = await jobContextService.getJobsForClockIn(
      //   userId: userId,
      //   companyId: companyId,
      // );
      //
      // switch (jobSelection) {
      //   case NoJobsAssigned(message: final msg):
      //     _showMessage(msg, isError: true);
      //     return;
      //   case AlreadyClockedIn():
      //     _showMessage('Already clocked in. Clock out first.', isError: true);
      //     return;
      //   case SingleJobSelected(job: final job):
      //     selectedJob = job;
      //   case MultipleJobsAvailable(jobs: final jobs):
      //     final selected = await _showJobPicker(jobs);
      //     if (selected == null) return;
      //     selectedJob = selected;
      // }

      // STEP 4: Check geofence
      // final job = selectedJob.job;
      // final distance = locationService.calculateDistance(
      //   lat1: location.latitude,
      //   lon1: location.longitude,
      //   lat2: job.lat!,
      //   lon2: job.lng!,
      // );
      // final effectiveRadius = (job.radiusM ?? 100) + location.accuracy;
      //
      // if (distance > effectiveRadius) {
      //   // Outside geofence — show error with "Explain Issue"
      //   _showGeofenceError(distance, job.name, selectedJob);
      //   return;
      // }

      // STEP 5: Call API (or queue if offline)
      // final timeclockApi = ref.read(timeclockApiProvider);
      // final clientEventId = Uuid().v4();
      //
      // ClockAttemptResult result;
      // try {
      //   result = await timeclockApi.clockIn(ClockInRequest(
      //     jobId: job.id!,
      //     latitude: location.latitude,
      //     longitude: location.longitude,
      //     accuracy: location.accuracy,
      //     clientEventId: clientEventId,
      //   ));
      // } catch (e) {
      //   // Offline: queue event
      //   if (e is NetworkException) {
      //     await ref.read(timeclockQueueProvider).queueClockIn(
      //       jobId: job.id!,
      //       location: location,
      //       clientEventId: clientEventId,
      //     );
      //     _showMessage('Queued for sync when online', isWarning: true);
      //     return;
      //   }
      //   rethrow;
      // }
      //
      // if (result.success) {
      //   _showMessage('✓ Clocked in successfully');
      //   await _refreshData();
      // } else {
      //   _showMessage(result.userMessage ?? 'Clock in failed', isError: true);
      // }

      // PLACEHOLDER: Show success for demo
      if (mounted) {
        _showMessage('✓ Clocked in successfully');
      }
    } catch (e) {
      if (mounted) {
        _showMessage(_mapErrorToUserMessage(e.toString()), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Handle clock out action
  Future<void> _handleClockOut() async {
    setState(() => _isLoading = true);

    try {
      // STEP 1: Get location (optional, for distance recording) (J6)
      try {
        final location = await LocationHelper.getCurrent(
          timeout: const Duration(seconds: 6),
        );
        // TODO: Use location for geofence validation
        // ignore: unused_local_variable
        final lat = location.lat;
        // ignore: unused_local_variable
        final lng = location.lng;
      } on LocationException catch (_) {
        // Location is optional for clock-out, continue without it
        // Warning will be shown if outside geofence
      }

      // STEP 2: Get active time entry
      // TODO: Get from provider
      // final activeEntry = ref.read(activeTimeEntryProvider);
      // if (activeEntry == null) {
      //   _showMessage('No active clock-in found', isError: true);
      //   return;
      // }

      // STEP 3: Call clockOut API
      // TODO: Implement API call
      // final timeclockApi = ref.read(timeclockApiProvider);
      // final result = await timeclockApi.clockOut(ClockOutRequest(
      //   entryId: activeEntry.id,
      //   latitude: lat,
      //   longitude: lng,
      //   clientEventId: Uuid().v4(),
      // ));
      //
      // if (result.success) {
      //   _showMessage('✓ Clocked out successfully');
      //   await _refreshData();
      // } else {
      //   _showMessage(result.userMessage ?? 'Clock out failed', isError: true);
      // }

      // PLACEHOLDER
      if (mounted) {
        _showMessage('✓ Clocked out successfully');
      }
    } catch (e) {
      if (mounted) {
        _showMessage(_mapErrorToUserMessage(e.toString()), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Show geofence error with "Explain Issue" shortcut
  // ignore: unused_element
  void _showGeofenceError(double distance, String jobName, JobWithContext job) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are ${distance.round()}m from $jobName.'),
            const Text('Move closer to clock in.'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                _showDisputeDialog(distance, jobName);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
              ),
              child: const Text('Explain Issue →'),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  /// Show dispute dialog (pre-filled with geofence data)
  Future<void> _showDisputeDialog(double distance, String jobName) async {
    // TODO: Implement dispute dialog
    // Pre-fill with: distance, accuracy, job location, timestamp
    // Allow worker to add explanation
    // Submit as dispute note via callable function
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Explain Issue'),
        content: Text(
          'Distance: ${distance.round()}m from $jobName\n\n'
          'Dispute functionality coming in Month 2. '
          'Contact your manager about the geofence issue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show GPS status dialog
  void _showGPSStatus() {
    // TODO: Get actual GPS status
    // final locationService = ref.read(locationServiceProvider);
    // final isEnabled = await locationService.isLocationServiceEnabled();
    // final cachedLocation = await locationService.getCachedLocation();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GPS Status'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GPS: Enabled'),
            Text('Accuracy: Good'),
            Text('Last update: Just now'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Refresh data
  Future<void> _refreshData() async {
    // TODO: Invalidate providers
    // ref.invalidate(activeTimeEntryProvider);
    // ref.invalidate(jobSelectionProvider);
    // ref.invalidate(recentTimeEntriesProvider);
    await Future.delayed(const Duration(milliseconds: 500)); // Placeholder
  }

  /// Show message to user
  void _showMessage(
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.red
            : isWarning
            ? Colors.orange
            : Colors.green,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  /// Map exception to user-friendly message (P - using centralized error mapper)
  String _mapErrorToUserMessage(String error) {
    return ErrorMessageMapper.mapError(error, context: 'clock');
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }
}
