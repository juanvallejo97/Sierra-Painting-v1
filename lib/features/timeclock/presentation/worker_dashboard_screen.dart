/// Worker Dashboard Screen
///
/// PURPOSE:
/// Primary interface for field workers to clock in/out and view their time.
/// Focus on large touch targets and clear status indicators.
///
/// FEATURES:
/// - Current clock-in status (active job or available)
/// - Large clock in/out button (primary action)
/// - Today's time summary
/// - Recent time entries
/// - GPS status indicator
///
/// GEOFENCE UX:
/// - Show distance to job site before clock in
/// - Clear error messages if outside geofence
/// - Loading state during geolocation and validation
/// - Success feedback on successful clock in/out
library;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sierra_painting/core/widgets/worker_scaffold.dart';
import 'package:sierra_painting/features/timeclock/domain/time_entry.dart';
import 'package:sierra_painting/features/timeclock/domain/timeclock_api.dart';
import 'package:sierra_painting/features/timeclock/data/timeclock_api_impl.dart';
import 'package:sierra_painting/features/timeclock/presentation/providers/timeclock_providers.dart';
import 'package:sierra_painting/features/timeclock/presentation/widgets/gps_status_dialog.dart';
import 'package:uuid/uuid.dart';

/// Worker Dashboard Screen
class WorkerDashboardScreen extends ConsumerWidget {
  const WorkerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch active time entry and today's summary data
    final activeEntry = ref.watch(activeTimeEntryProvider);
    final totalHours = ref.watch(thisWeekTotalHoursProvider);
    final jobSitesCount = ref.watch(thisWeekJobSitesProvider);
    final recentEntries = ref.watch(recentTimeEntriesProvider);
    final currentRoute =
        ModalRoute.of(context)?.settings.name ?? '/worker/home';

    return WorkerScaffold(
      title: 'My Timesheet',
      currentRoute: currentRoute,
      actions: [
        IconButton(
          icon: const Icon(Icons.location_on),
          tooltip: 'GPS Status',
          onPressed: () => showGpsStatusDialog(context),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          // TODO: Refresh time entries and jobs
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Active Clock-In Status Card
            _buildStatusCard(context, activeEntry),
            const SizedBox(height: 16),

            // Primary Action Button (Clock In/Out)
            _buildPrimaryActionButton(context, activeEntry, ref),
            const SizedBox(height: 24),

            // Today's Summary
            _buildTodaySummary(context, totalHours, jobSitesCount),
            const SizedBox(height: 24),

            // Recent Time Entries
            _buildRecentEntries(context, recentEntries),
          ],
        ),
      ),
    );
  }

  /// Build status card showing current clock-in state
  Widget _buildStatusCard(
    BuildContext context,
    AsyncValue<TimeEntry?> activeEntry,
  ) {
    return activeEntry.when(
      data: (entry) => _buildStatusCardContent(context, entry),
      loading: () => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (error, stackTrace) => const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: Text('Error loading status')),
        ),
      ),
    );
  }

  Widget _buildStatusCardContent(BuildContext context, TimeEntry? entry) {
    final hasActiveEntry = entry != null && entry.isActive;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasActiveEntry ? Icons.work : Icons.home,
                  color: hasActiveEntry ? Colors.green : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasActiveEntry ? 'Currently Working' : 'Not Clocked In',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (hasActiveEntry)
                        Text(
                          'Job ID: ${entry.jobId}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (hasActiveEntry) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Clock In Time:',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    _formatTime(entry.clockIn),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Elapsed Time:',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    _formatElapsedTime(entry.clockIn),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
    );
  }

  /// Build primary clock in/out button
  Widget _buildPrimaryActionButton(
    BuildContext context,
    AsyncValue<TimeEntry?> activeEntry,
    WidgetRef ref,
  ) {
    return activeEntry.when(
      data: (entry) {
        final hasActiveEntry = entry != null && entry.isActive;
        return SizedBox(
          width: double.infinity,
          height: 64,
          child: ElevatedButton(
            onPressed: () async {
              if (hasActiveEntry) {
                await _handleClockOut(context, ref);
              } else {
                await _handleClockIn(context, ref);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: hasActiveEntry ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text(
              hasActiveEntry ? 'Clock Out' : 'Clock In',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
      loading: () => SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
          ),
          child: const CircularProgressIndicator(color: Colors.white),
        ),
      ),
      error: (error, stackTrace) => SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton(
          onPressed: () async {
            await _handleClockIn(context, ref);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text(
            'Clock In',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  /// Build today's summary section
  Widget _buildTodaySummary(
    BuildContext context,
    AsyncValue<double> totalHours,
    AsyncValue<int> jobSitesCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'This Week\'s Summary',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: totalHours.when(
                data: (hours) => _buildSummaryCard(
                  context,
                  icon: Icons.access_time,
                  label: 'Total Hours',
                  value: hours.toStringAsFixed(1),
                  color: Colors.blue,
                ),
                loading: () => _buildSummaryCard(
                  context,
                  icon: Icons.access_time,
                  label: 'Total Hours',
                  value: '...',
                  color: Colors.blue,
                ),
                error: (error, stackTrace) => _buildSummaryCard(
                  context,
                  icon: Icons.access_time,
                  label: 'Total Hours',
                  value: '0.0',
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: jobSitesCount.when(
                data: (count) => _buildSummaryCard(
                  context,
                  icon: Icons.location_on,
                  label: 'Job Sites',
                  value: count.toString(),
                  color: Colors.green,
                ),
                loading: () => _buildSummaryCard(
                  context,
                  icon: Icons.location_on,
                  label: 'Job Sites',
                  value: '...',
                  color: Colors.green,
                ),
                error: (error, stackTrace) => _buildSummaryCard(
                  context,
                  icon: Icons.location_on,
                  label: 'Job Sites',
                  value: '0',
                  color: Colors.green,
                ),
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
    );
  }

  /// Build recent entries list
  Widget _buildRecentEntries(
    BuildContext context,
    AsyncValue<List<TimeEntry>> recentEntries,
  ) {
    return recentEntries.when(
      data: (entries) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Entries',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
            ...entries
                .take(10)
                .map((entry) => _buildTimeEntryCard(context, entry)),
        ],
      ),
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Entries',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      ),
      error: (error, stackTrace) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Entries',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Error loading entries',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
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

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  String _formatElapsedTime(DateTime clockIn) {
    final elapsed = DateTime.now().difference(clockIn);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  /// Handle clock in action
  Future<void> _handleClockIn(BuildContext context, WidgetRef ref) async {
    try {
      // Step 1: Check and request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception(
            'Location permission denied. Grant permission to clock in.',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
          'Location permission permanently denied. Enable in settings.',
        );
      }

      // Step 2: Get current location
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Getting your location...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (e) {
        throw Exception(
          'Unable to get location. Make sure location services are enabled.',
        );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Step 3: Check GPS accuracy
      if (position.accuracy > 50) {
        if (!context.mounted) return;
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('GPS Accuracy Warning'),
            content: Text(
              'GPS accuracy is ${position.accuracy.toStringAsFixed(0)}m. '
              'For best results, move to an open area for better signal. '
              'Continue anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );

        if (shouldContinue != true) return;
      }

      // Step 4: Get active job from assignments
      final activeJob = await ref.read(activeJobProvider.future);
      if (activeJob == null) {
        throw Exception('No jobs assigned. Contact your manager.');
      }

      final jobId = activeJob['id'] as String;

      // Step 5: Call API with geofence validation
      final api = ref.read(timeclockApiProvider);
      final clientEventId = const Uuid().v4();
      final deviceId = kIsWeb ? 'web-browser' : 'mobile-device';

      final response = await api.clockIn(
        ClockInRequest(
          jobId: jobId,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          clientEventId: clientEventId,
          deviceId: deviceId,
        ),
      );

      // Step 6: Handle success
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ Clocked in successfully (${response.id})'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );

      // Refresh providers
      ref.invalidate(activeTimeEntryProvider);
      ref.invalidate(recentTimeEntriesProvider);
      ref.invalidate(thisWeekTotalHoursProvider);
      ref.invalidate(thisWeekJobSitesProvider);
    } on OperationQueuedException catch (e) {
      // Queued for offline sync
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📡 ${e.message}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on Exception catch (e) {
      // Parse error and show user-friendly message
      if (context.mounted) {
        final errorMessage = _mapErrorToUserMessage(e.toString());
        final isGeofenceError =
            e.toString().contains('geofence') ||
            e.toString().contains('m from job site');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage),
                if (isGeofenceError) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      _showDisputeDialog(context, errorMessage);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Explain Issue →'),
                  ),
                ],
              ],
            ),
            backgroundColor: isGeofenceError ? Colors.orange : Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Handle clock out action
  Future<void> _handleClockOut(BuildContext context, WidgetRef ref) async {
    try {
      // Step 1: Get active time entry
      final activeEntryAsync = ref.read(activeTimeEntryProvider);
      final activeEntry = activeEntryAsync.value;

      if (activeEntry == null || !activeEntry.isActive) {
        throw Exception('No active clock-in found');
      }

      // Step 2: Get current location
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Getting your location...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 15),
          ),
        );
      } catch (e) {
        throw Exception(
          'Unable to get location. Make sure location services are enabled.',
        );
      }

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Step 3: Call API with geofence validation
      final api = ref.read(timeclockApiProvider);
      final clientEventId = const Uuid().v4();
      final deviceId = kIsWeb ? 'web-browser' : 'mobile-device';

      final response = await api.clockOut(
        ClockOutRequest(
          timeEntryId: activeEntry.id!,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          clientEventId: clientEventId,
          deviceId: deviceId,
        ),
      );

      // Step 4: Handle response with optional warning
      if (!context.mounted) return;

      final hasWarning =
          response.warning != null && response.warning!.isNotEmpty;
      final warningText = response.warning ?? '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasWarning
                    ? '⚠ Clocked out with warning'
                    : '✓ Clocked out successfully',
              ),
              if (hasWarning) ...[
                const SizedBox(height: 4),
                Text(warningText, style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
          backgroundColor: hasWarning ? Colors.orange : Colors.green,
          duration: Duration(seconds: hasWarning ? 5 : 3),
        ),
      );

      // Refresh providers
      ref.invalidate(activeTimeEntryProvider);
      ref.invalidate(recentTimeEntriesProvider);
      ref.invalidate(thisWeekTotalHoursProvider);
      ref.invalidate(thisWeekJobSitesProvider);
    } on OperationQueuedException catch (e) {
      // Queued for offline sync
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📡 ${e.message}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mapErrorToUserMessage(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Map exception to user-friendly message
  String _mapErrorToUserMessage(String error) {
    if (error.contains('GPS accuracy too low')) {
      return 'GPS signal weak. Move to open area and try again.';
    }
    if (error.contains('Outside geofence')) {
      // Extract distance info from error message
      final match = RegExp(r'(\d+\.?\d*)m from job site').firstMatch(error);
      if (match != null) {
        return 'You are ${match.group(1)}m from the job site. Move closer to clock in.';
      }
      return 'You are outside the job site area. Move closer to clock in.';
    }
    if (error.contains('Not assigned')) {
      return 'You are not assigned to this job. Contact your manager.';
    }
    if (error.contains('Already clocked in')) {
      return 'You are already clocked in to a job. Clock out first.';
    }
    if (error.contains('Assignment not active')) {
      // Extract date from error message
      return error.split('Starts:').last.trim();
    }
    if (error.contains('Assignment expired')) {
      return 'This job assignment has ended. Contact your manager.';
    }
    if (error.contains('Sign in required')) {
      return 'Please sign in to use the timeclock.';
    }
    return 'Unable to complete. Please try again or contact support.';
  }

  /// Show dispute dialog for geofence issues
  Future<void> _showDisputeDialog(
    BuildContext context,
    String errorDetails,
  ) async {
    // TODO: Implement dispute dialog
    // Pre-fill with error details (distance, accuracy, job location)
    // Allow worker to add explanation
    // Submit as dispute note on time entry
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Explain Issue'),
        content: const Text(
          'Dispute functionality not yet implemented. '
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
}
