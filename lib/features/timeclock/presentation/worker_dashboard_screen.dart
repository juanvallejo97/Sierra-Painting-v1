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
import 'package:sierra_painting/core/services/location_service.dart';
import 'package:sierra_painting/core/services/location_service_provider.dart';
import 'package:sierra_painting/features/timeclock/data/timeclock_api_impl.dart';
import 'package:sierra_painting/features/timeclock/domain/time_entry.dart';
import 'package:sierra_painting/features/timeclock/domain/timeclock_api.dart';
import 'package:sierra_painting/features/timeclock/presentation/providers/timeclock_providers.dart';
import 'package:sierra_painting/features/timeclock/presentation/widgets/location_permission_primer.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Export OperationQueuedException for UI handling
export 'package:sierra_painting/features/timeclock/data/timeclock_api_impl.dart'
    show OperationQueuedException;

/// Worker Dashboard Screen
class WorkerDashboardScreen extends ConsumerStatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  ConsumerState<WorkerDashboardScreen> createState() =>
      _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends ConsumerState<WorkerDashboardScreen> {
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final activeEntryAsync = ref.watch(activeTimeEntryProvider);
    final activeJobAsync = ref.watch(activeJobProvider);
    final recentEntriesAsync = ref.watch(recentTimeEntriesProvider);
    final totalHoursAsync = ref.watch(thisWeekTotalHoursProvider);
    final jobSitesAsync = ref.watch(thisWeekJobSitesProvider);

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
          // Sign out menu
          PopupMenuButton<int>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 1, child: Text('Sign Out')),
            ],
            onSelected: (v) async {
              if (v != 1) return;
              final auth = ref.read(firebaseAuthProvider);
              await auth.signOut();
              if (mounted && context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(activeJobProvider);
          ref.invalidate(activeTimeEntryProvider);
          ref.invalidate(recentTimeEntriesProvider);
          ref.invalidate(thisWeekTotalHoursProvider);
          ref.invalidate(thisWeekJobSitesProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Active Job Assignment Card (prevents "no spinner forever")
            activeJobAsync.when(
              loading: () => const _JobAssignmentSkeleton(),
              error: (error, stack) => _buildJobAssignmentError(context, error),
              data: (job) => _buildJobAssignmentCard(context, job),
            ),
            const SizedBox(height: 16),

            // Active Clock-In Status Card
            activeEntryAsync.when(
              loading: () => const _StatusCardSkeleton(),
              error: (error, stack) => _buildErrorCard(context, error),
              data: (activeEntry) => _buildStatusCard(context, activeEntry),
            ),
            const SizedBox(height: 16),

            // Primary Action Button (Clock In/Out)
            _buildPrimaryActionButton(context, activeEntryAsync.value),
            const SizedBox(height: 24),

            // Today's Summary
            _buildTodaySummary(
              context,
              totalHoursAsync.value ?? 0.0,
              jobSitesAsync.value ?? 0,
            ),
            const SizedBox(height: 24),

            // Recent Time Entries
            recentEntriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) =>
                  Center(child: Text('Error loading entries: $error')),
              data: (entries) => _buildRecentEntries(context, entries),
            ),
          ],
        ),
      ),
    );
  }

  /// Build status card showing current clock-in state
  Widget _buildStatusCard(BuildContext context, TimeEntry? activeEntry) {
    final hasActiveEntry = activeEntry != null;

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
                          'Job: ${activeEntry.jobId}',
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
                    _formatTime(activeEntry.clockIn),
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
                  _ElapsedTimeWidget(clockIn: activeEntry.clockIn),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, Object error) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Unable to load status: $error',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build job assignment card (shows active job or empty state)
  Widget _buildJobAssignmentCard(BuildContext context, Map<String, dynamic>? job) {
    if (job == null) {
      // Empty state: No active assignment
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.assignment_late, color: Colors.orange.shade700, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No Active Assignment',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                        Text(
                          'Contact your manager to get assigned to a job.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    ref.invalidate(activeJobProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange.shade700,
                    side: BorderSide(color: Colors.orange.shade700),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Active job assigned
    final jobName = job['name'] as String? ?? 'Unknown Job';
    final jobAddress = job['address'] as String? ?? 'No address';

    return Card(
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.assignment_turned_in, color: Colors.green.shade700, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assigned to Job',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    jobName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    jobAddress,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build job assignment error card with refresh
  Widget _buildJobAssignmentError(BuildContext context, Object error) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unable to Load Assignment',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                      Text(
                        error.toString().contains('TimeoutException')
                            ? 'Request timed out. Check your connection.'
                            : 'An error occurred. Please try again.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  ref.invalidate(activeJobProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build primary clock in/out button
  Widget _buildPrimaryActionButton(
    BuildContext context,
    TimeEntry? activeEntry,
  ) {
    final hasActiveEntry = activeEntry != null;

    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: _isProcessing
            ? null
            : () async {
                if (hasActiveEntry) {
                  await _handleClockOut(context, activeEntry);
                } else {
                  await _handleClockIn(context);
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: hasActiveEntry ? Colors.orange : Colors.green,
          foregroundColor: Colors.white,
        ),
        child: _isProcessing
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                hasActiveEntry ? 'Clock Out' : 'Clock In',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  /// Build today's summary section
  Widget _buildTodaySummary(
    BuildContext context,
    double totalHours,
    int jobSites,
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
              child: _buildSummaryCard(
                context,
                icon: Icons.access_time,
                label: 'Total Hours',
                value: totalHours.toStringAsFixed(1),
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                context,
                icon: Icons.location_on,
                label: 'Job Sites',
                value: jobSites.toString(),
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
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  /// Build recent entries list
  Widget _buildRecentEntries(BuildContext context, List<TimeEntry> entries) {
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

  String _formatTime(DateTime time) {
    final hour = time.hour > 12
        ? time.hour - 12
        : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  /// Handle clock in action with complete permission flow
  Future<void> _handleClockIn(BuildContext context) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      debugPrint('🔵 Clock In started');
      final locService = ref.read(locationServiceImplProvider);

      // Step 1: Check if location services are enabled
      debugPrint('🔵 Step 1: Checking location services...');
      final isEnabled = await locService.isLocationServiceEnabled();
      if (!isEnabled) {
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location services are disabled. Please enable GPS in device settings.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Step 2: Check permission status
      debugPrint('🔵 Step 2: Checking location permission...');
      final permissionStatus = await locService.checkPermission();
      debugPrint('🔵 Step 2: Permission status = $permissionStatus');

      // Handle permission states
      if (permissionStatus == LocationPermissionStatus.deniedForever) {
        // Permanently denied - guide to settings
        if (mounted && context.mounted) {
          final shouldOpenSettings = await showDialog<bool>(
            context: context,
            builder: (context) => const PermissionDeniedForeverDialog(),
          );
          if (shouldOpenSettings == true) {
            await locService.openAppSettings();
          }
        }
        return;
      }

      if (permissionStatus == LocationPermissionStatus.notDetermined ||
          permissionStatus == LocationPermissionStatus.denied) {
        // Show primer before requesting permission
        if (mounted && context.mounted) {
          final shouldRequest = await showDialog<bool>(
            context: context,
            builder: (context) => const LocationPermissionPrimer(),
          );

          if (shouldRequest != true) {
            // User declined to grant permission
            return;
          }

          // Request permission
          final granted = await locService.requestPermission();
          if (!granted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission is required to clock in.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
            return;
          }
        }
      }

      // Step 3: Get location with fallback chain
      debugPrint('🔵 Step 3: Getting location...');
      final loc = await locService.getCurrentLocation();
      debugPrint(
        '🔵 Step 3: Location obtained - lat: ${loc.latitude}, lng: ${loc.longitude}, accuracy: ${loc.accuracy}m',
      );

      // Step 4: Check GPS accuracy and show warning if poor
      if (loc.accuracy > 50 && mounted && context.mounted) {
        final tip = locService.getStabilizationTip(loc.accuracy);
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (context) =>
              GPSAccuracyWarningDialog(accuracy: loc.accuracy, tip: tip),
        );

        if (shouldContinue != true) {
          return; // User chose to cancel and improve GPS
        }
      }

      // Step 5: Get active job (provider will fetch assignment)
      debugPrint('🔵 Step 5: Getting active job...');
      final job = await ref.read(activeJobProvider.future);
      debugPrint('🔵 Step 5: Job data: $job');

      if (job == null) {
        throw Exception('No active job assigned. Contact your manager.');
      }

      final jobId = job['id'] as String;
      debugPrint('🔵 Step 5: Job ID = $jobId');

      // Step 6: Generate device ID and event ID
      debugPrint('🔵 Step 6: Generating IDs...');
      final deviceId = 'web-${DateTime.now().millisecondsSinceEpoch}';
      final clientEventId = Idempotency.newEventId();
      debugPrint('🔵 Step 6: deviceId=$deviceId, clientEventId=$clientEventId');

      // Step 7: Call API (Firebase SDK sends auth token automatically)
      debugPrint('🔵 Step 7: Calling clockIn API...');
      final api = ref.read(timeclockApiProvider);
      final response = await api.clockIn(
        ClockInRequest(
          jobId: jobId,
          latitude: loc.latitude,
          longitude: loc.longitude,
          accuracy: loc.accuracy,
          deviceId: deviceId,
          clientEventId: clientEventId,
        ),
      );
      debugPrint('🔵 Step 7: API response received - ID: ${response.id}');

      // Step 8: Refresh providers and wait for Firestore to propagate
      ref.invalidate(activeTimeEntryProvider);
      ref.invalidate(recentTimeEntriesProvider);
      ref.invalidate(thisWeekTotalHoursProvider);
      ref.invalidate(thisWeekJobSitesProvider);

      // Step 9: Wait for real-time listener to detect the new entry (max 3 seconds)
      debugPrint('🔵 Step 9: Waiting for Firestore snapshot to update...');
      var attempts = 0;
      while (attempts < 15) {
        // 15 attempts * 200ms = 3 seconds max
        await Future.delayed(const Duration(milliseconds: 200));
        final activeEntry = ref.read(activeTimeEntryProvider).value;
        if (activeEntry != null && activeEntry.id == response.id) {
          debugPrint('✅ Step 9: Firestore snapshot updated, entry detected');
          break;
        }
        attempts++;
        debugPrint('⏳ Step 9: Waiting... attempt $attempts/15');
      }

      // Step 10: Show success
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Clocked in successfully (ID: ${response.id})'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } on OperationQueuedException catch (e) {
      // Operation queued for offline sync
      debugPrint('⏳ Clock In queued: ${e.message}');
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏳ ${e.message}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on LocationException catch (e) {
      debugPrint('❌ Location Error: ${e.type} - ${e.message}');
      if (mounted && context.mounted) {
        String errorMessage;
        switch (e.type) {
          case LocationExceptionType.serviceDisabled:
            errorMessage =
                'Location services are disabled. Please enable GPS in device settings.';
            break;
          case LocationExceptionType.permissionDenied:
            errorMessage =
                'Location permission denied. Please grant permission to clock in.';
            break;
          case LocationExceptionType.timeout:
            errorMessage =
                'Location timeout. Please ensure you have a clear view of the sky.';
            break;
          default:
            errorMessage = 'Unable to get location: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted && context.mounted) {
        final errorMessage = _mapErrorToUserMessage(e.message ?? e.code);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stack) {
      // Debug logging for troubleshooting
      debugPrint('❌ Clock In Error: ${e.runtimeType}');
      debugPrint('❌ Clock In Message: $e');
      debugPrint('❌ Clock In Stack: $stack');

      if (mounted && context.mounted) {
        final errorMessage = _mapErrorToUserMessage(e.toString());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Handle clock out action
  Future<void> _handleClockOut(
    BuildContext context,
    TimeEntry activeEntry,
  ) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // 1. Get location (permission already granted from clock in)
      final locService = ref.read(locationServiceImplProvider);
      final loc = await locService.getCurrentLocation();
      debugPrint(
        '🔵 Clock Out: Location obtained - lat: ${loc.latitude}, lng: ${loc.longitude}, accuracy: ${loc.accuracy}m',
      );

      // 2. Generate device ID and event ID
      final deviceId = 'web-${DateTime.now().millisecondsSinceEpoch}';
      final clientEventId = Idempotency.newEventId();

      // 3. Call API
      final api = ref.read(timeclockApiProvider);
      final response = await api.clockOut(
        ClockOutRequest(
          timeEntryId: activeEntry.id!,
          latitude: loc.latitude,
          longitude: loc.longitude,
          accuracy: loc.accuracy,
          deviceId: deviceId,
          clientEventId: clientEventId,
        ),
      );

      // 4. Refresh providers
      ref.invalidate(activeTimeEntryProvider);
      ref.invalidate(recentTimeEntriesProvider);
      ref.invalidate(thisWeekTotalHoursProvider);
      ref.invalidate(thisWeekJobSitesProvider);

      // 5. Show success with optional warning
      if (mounted && context.mounted) {
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
    } on OperationQueuedException catch (e) {
      // Operation queued for offline sync
      debugPrint('⏳ Clock Out queued: ${e.message}');
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⏳ ${e.message}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on LocationException catch (e) {
      debugPrint('❌ Clock Out Location Error: ${e.type} - ${e.message}');
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Unable to get location: ${e.message}. Please try again.',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted && context.mounted) {
        final errorMessage = _mapErrorToUserMessage(e.message ?? e.code);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mapErrorToUserMessage(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Map exception to user-friendly message
  String _mapErrorToUserMessage(String error) {
    if (error.contains('GPS accuracy too low')) {
      return 'GPS signal weak. Move to open area and try again.';
    }
    if (error.contains('Outside geofence') ||
        error.contains('outside the job site')) {
      // Extract distance info from error message
      final match = RegExp(r'(\d+\.?\d*)m').firstMatch(error);
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
      return 'This job assignment is not active yet. Contact your manager.';
    }
    if (error.contains('Assignment expired')) {
      return 'This job assignment has ended. Contact your manager.';
    }
    if (error.contains('Sign in required') ||
        error.contains('UNAUTHENTICATED')) {
      return 'Please sign in to use the timeclock.';
    }
    if (error.contains('No active job assigned')) {
      return 'No active job assigned. Contact your manager.';
    }
    return 'Unable to complete. Please try again or contact support.';
  }
}

/// Skeleton loading state for status card
class _StatusCardSkeleton extends StatelessWidget {
  const _StatusCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 150,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 100,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loading state for job assignment card
class _JobAssignmentSkeleton extends StatelessWidget {
  const _JobAssignmentSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 120,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 180,
                    height: 16,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 200,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget that updates elapsed time every minute
class _ElapsedTimeWidget extends StatefulWidget {
  final DateTime clockIn;

  const _ElapsedTimeWidget({required this.clockIn});

  @override
  State<_ElapsedTimeWidget> createState() => _ElapsedTimeWidgetState();
}

class _ElapsedTimeWidgetState extends State<_ElapsedTimeWidget> {
  String _elapsed = '';

  @override
  void initState() {
    super.initState();
    _updateElapsed();
    // Update every minute
    Future.doWhile(() async {
      await Future.delayed(const Duration(minutes: 1));
      if (mounted) {
        _updateElapsed();
        return true;
      }
      return false;
    });
  }

  void _updateElapsed() {
    if (!mounted) return;
    final duration = DateTime.now().difference(widget.clockIn);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    setState(() {
      _elapsed = '${hours}h ${minutes}m';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _elapsed,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Colors.green,
      ),
    );
  }
}
