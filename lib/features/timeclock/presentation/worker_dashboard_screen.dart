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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers.dart';
import 'package:sierra_painting/core/services/idempotency.dart';
import 'package:sierra_painting/core/services/location_service_provider.dart';
import 'package:sierra_painting/features/timeclock/data/timeclock_api_impl.dart';
import 'package:sierra_painting/features/timeclock/domain/time_entry.dart';
import 'package:sierra_painting/features/timeclock/domain/timeclock_api.dart';
import 'package:sierra_painting/features/timeclock/presentation/providers/timeclock_providers.dart';
import 'package:sierra_painting/features/jobs/domain/job.dart';

/// Worker Dashboard Screen - Skeleton
class WorkerDashboardScreen extends ConsumerWidget {
  const WorkerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Get current user from auth provider
    // TODO: Get active time entry from repository
    // TODO: Get today's jobs from repository
    // TODO: Get GPS location status

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Timesheet'),
        actions: [
          // GPS status indicator
          IconButton(
            icon: const Icon(Icons.location_on),
            onPressed: () {
              // TODO: Show GPS accuracy and location settings
            },
            tooltip: 'GPS Status',
          ),
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final auth = ref.read(firebaseAuthProvider);
              await auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // TODO: Refresh time entries and jobs
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Active Clock-In Status Card
            _buildStatusCard(context),
            const SizedBox(height: 16),

            // Primary Action Button (Clock In/Out)
            _buildPrimaryActionButton(context),
            const SizedBox(height: 24),

            // Today's Summary
            _buildTodaySummary(context),
            const SizedBox(height: 24),

            // Recent Time Entries
            _buildRecentEntries(context),
          ],
        ),
      ),
    );
  }

  /// Build status card showing current clock-in state
  Widget _buildStatusCard(BuildContext context) {
    // TODO: Replace with actual active time entry data
    final hasActiveEntry = false;
    final currentJob = null;

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
            if (hasActiveEntry) ...[
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Clock In Time:',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text('8:30 AM',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          )),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Elapsed Time:',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Text('2h 30m',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          )),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build primary clock in/out button
  Widget _buildPrimaryActionButton(BuildContext context) {
    // TODO: Replace with actual active time entry state
    final hasActiveEntry = false;
    final isLoading = false;

    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: isLoading
            ? null
            : () async {
                if (hasActiveEntry) {
                  await _handleClockOut(context);
                } else {
                  await _handleClockIn(context);
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: hasActiveEntry ? Colors.orange : Colors.green,
          foregroundColor: Colors.white,
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
                hasActiveEntry ? 'Clock Out' : 'Clock In',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }

  /// Build today's summary section
  Widget _buildTodaySummary(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Summary',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                icon: Icons.access_time,
                label: 'Total Hours',
                value: '0.0',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                context,
                icon: Icons.location_on,
                label: 'Job Sites',
                value: '0',
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
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  /// Build recent entries list
  Widget _buildRecentEntries(BuildContext context) {
    // TODO: Replace with actual time entries from repository
    final entries = <TimeEntry>[];

    return Column(
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey,
                    ),
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

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '${hour}:${time.minute.toString().padLeft(2, '0')} $period';
  }

  /// Handle clock in action
  Future<void> _handleClockIn(BuildContext context) async {
    print('🔵 Clock In clicked!');
    final ref = ProviderScope.containerOf(context);

    try {
      print('🔵 Getting location...');
      // 1. Get location
      final locService = ref.read(locationServiceImplProvider);
      final loc = await locService.getCurrentLocation();
      print('🔵 Location: ${loc.latitude}, ${loc.longitude}');

      // 2. Get active job (direct Firestore query)
      print('🔵 Step 2: Getting user from provider...');
      final user = ref.read(currentUserProvider);
      print('🔵 User: ${user?.uid}');
      if (user == null) {
        throw Exception('Not signed in');
      }

      print('🔵 Getting ID token...');
      final idToken = await user.getIdTokenResult();
      print('🔵 Token claims: ${idToken.claims}');
      final companyId = idToken.claims?['companyId'] as String?;
      print('🔵 Company ID: $companyId');
      if (companyId == null) {
        throw Exception('No company ID in token');
      }

      final db = ref.read(firestoreProvider);
      final assignmentsQuery = await db
          .collection('assignments')
          .where('userId', isEqualTo: user.uid)
          .where('companyId', isEqualTo: companyId)
          .where('active', isEqualTo: true)
          .limit(1)
          .get();

      print('🔵 Assignments found: ${assignmentsQuery.docs.length}');
      if (assignmentsQuery.docs.isEmpty) {
        throw Exception('No active job assigned. Contact your manager.');
      }

      final assignment = assignmentsQuery.docs.first.data();
      final jobId = assignment['jobId'] as String;
      print('🔵 Job ID: $jobId');

      // 3. Get device ID and generate event ID
      final deviceId = 'web-${DateTime.now().millisecondsSinceEpoch}';
      final clientEventId = Idempotency.newEventId();

      // 4. Call API
      final api = ref.read(timeclockApiProvider);
      final response = await api.clockIn(ClockInRequest(
        jobId: jobId,
        latitude: loc.latitude,
        longitude: loc.longitude,
        accuracy: loc.accuracy,
        deviceId: deviceId,
        clientEventId: clientEventId,
      ));

      // 5. Refresh providers
      ref.invalidate(activeEntryProvider);

      // 6. Show success
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Clocked in (ID: ${response.id})'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stack) {
      print('🔴 Clock In ERROR: $e');
      print('🔴 Stack: $stack');
      if (context.mounted) {
        final errorMessage = _mapErrorToUserMessage(e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Handle clock out action
  Future<void> _handleClockOut(BuildContext context) async {
    final ref = ProviderScope.containerOf(context);

    try {
      // 1. Get location
      final locService = ref.read(locationServiceImplProvider);
      final loc = await locService.getCurrentLocation();

      // 2. Get active time entry
      final activeEntry = await ref.read(activeEntryProvider.future);
      if (activeEntry == null) {
        throw Exception('No active clock-in found');
      }

      // 3. Get device ID and generate event ID
      final deviceId = 'web-${DateTime.now().millisecondsSinceEpoch}';
      final clientEventId = Idempotency.newEventId();

      // 4. Call API
      final api = ref.read(timeclockApiProvider);
      final response = await api.clockOut(ClockOutRequest(
        timeEntryId: activeEntry.id!,
        latitude: loc.latitude,
        longitude: loc.longitude,
        accuracy: loc.accuracy,
        deviceId: deviceId,
        clientEventId: clientEventId,
      ));

      // 5. Refresh providers
      ref.invalidate(activeEntryProvider);

      // 6. Show success with optional warning
      if (context.mounted) {
        final hasWarning = response.warning != null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasWarning
                  ? '⚠ Clocked out: ${response.warning}'
                  : '✓ Clocked out successfully',
            ),
            backgroundColor: hasWarning ? Colors.orange : Colors.green,
            duration: Duration(seconds: hasWarning ? 5 : 2),
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
  Future<void> _showDisputeDialog(BuildContext context, String errorDetails) async {
    // TODO: Implement dispute dialog
    // Pre-fill with error details (distance, accuracy, job location)
    // Allow worker to add explanation
    // Submit as dispute note on time entry
    showDialog(
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
