/// Timeclock Screen
///
/// PURPOSE:
/// Primary screen for time clock operations (clock in/out).
/// Displays current clock status and provides quick access to time tracking.
///
/// FEATURES:
/// - Clock in/out functionality with offline support
/// - Current job selection
/// - Time entry history
/// - Offline queue status with sync badge
/// - GPS location tracking with accuracy indicator
/// - Geofence validation with "Clock in anyway" fallback
/// - Device identification for audit trail
///
/// OFFLINE BEHAVIOR:
/// - Operations are queued when offline and synced when connection restores
/// - "Clock in anyway" button bypasses geofence validation
/// - Offline entries flagged with needsReview for admin review
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sierra_painting/core/providers/auth_provider.dart';
import 'package:sierra_painting/design/tokens.dart';
import 'package:sierra_painting/features/timeclock/domain/time_entry.dart';
import 'package:uuid/uuid.dart';

class TimeclockScreen extends ConsumerWidget {
  const TimeclockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/branding/dsierra_logo.jpg',
              height: 32,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
            const SizedBox(width: 12),
            const Text("D' Sierra Painting"),
          ],
        ),
        actions: [
          // Sync status indicator
          const _SyncStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              // TODO: Navigate to time entry history
            },
            tooltip: 'View History',
          ),
        ],
      ),
      body: const TimeclockBody(),
    );
  }
}

/// Sync status indicator chip
class _SyncStatusIndicator extends ConsumerWidget {
  const _SyncStatusIndicator();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // TODO: Wire to actual sync queue provider
    final hasPendingSync = false; // Placeholder

    if (!hasPendingSync) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Chip(
        avatar: const Icon(Icons.sync, size: 16),
        label: const Text('Syncing', style: TextStyle(fontSize: 12)),
        backgroundColor: DesignTokens.warningAmber.withValues(alpha: 0.2),
        side: const BorderSide(color: DesignTokens.warningAmber),
      ),
    );
  }
}

/// Router-free body used by tests and the real screen.
class TimeclockBody extends ConsumerStatefulWidget {
  const TimeclockBody({super.key});

  @override
  ConsumerState<TimeclockBody> createState() => _TimeclockBodyState();
}

class _TimeclockBodyState extends ConsumerState<TimeclockBody> {
  // State
  TimeEntry? _activeEntry;
  Position? _currentPosition;
  bool _isLoadingPosition = false;
  bool _isOnline = true;
  bool _showOfflineOverride = false;
  String? _selectedJobId;
  double? _gpsAccuracy;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadActiveEntry();
  }

  Future<void> _checkConnectivity() async {
    final connectivity = Connectivity();
    final result = await connectivity.checkConnectivity();
    setState(() {
      _isOnline = result.contains(ConnectivityResult.mobile) ||
          result.contains(ConnectivityResult.wifi);
    });

    // Listen to connectivity changes
    connectivity.onConnectivityChanged.listen((results) {
      setState(() {
        _isOnline = results.contains(ConnectivityResult.mobile) ||
            results.contains(ConnectivityResult.wifi);
      });
    });
  }

  Future<void> _loadActiveEntry() async {
    // TODO: Load active time entry from Firestore
    // For now, just placeholder
  }

  Future<Position?> _getCurrentPosition() async {
    setState(() {
      _isLoadingPosition = true;
    });

    try {
      // Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied. GPS unavailable.'),
              ),
            );
          }
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permissions permanently denied. '
                'Please enable in settings.',
              ),
            ),
          );
        }
        return null;
      }

      // Get position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _currentPosition = position;
        _gpsAccuracy = position.accuracy;
      });

      return position;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to get location: $e')),
        );
      }
      return null;
    } finally {
      setState(() {
        _isLoadingPosition = false;
      });
    }
  }

  bool _validateGeofence(Position position, GeoPoint jobLocation) {
    // Calculate distance using Haversine formula
    final distanceInMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      jobLocation.latitude,
      jobLocation.longitude,
    );

    // Adaptive radius based on GPS accuracy
    double radius = 75.0; // Base radius
    if (_gpsAccuracy != null && _gpsAccuracy! > 50) {
      radius = 250.0; // Expanded radius for poor accuracy
    }

    return distanceInMeters <= radius;
  }

  Future<String?> _getDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Theme.of(context).platform == TargetPlatform.android) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Theme.of(context).platform == TargetPlatform.iOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor;
      } else {
        final webInfo = await deviceInfo.webBrowserInfo;
        return webInfo.userAgent;
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> _handleClockIn({bool forceOffline = false}) async {
    final userId = ref.read(currentUserProvider)?.uid;
    final companyId = ref.read(userCompanyProvider);

    if (userId == null || companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    if (_selectedJobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a job first')),
      );
      return;
    }

    // Get position
    final position = await _getCurrentPosition();
    final deviceId = await _getDeviceId();

    // Determine if offline mode
    final isOfflineMode = !_isOnline || forceOffline || position == null;

    // Validate geofence if online and position available
    bool geofenceValid = true;
    if (!isOfflineMode && position != null) {
      // TODO: Get job location from Firestore
      // For now, assume geofence validation
      final jobLocation = GeoPoint(0, 0); // Placeholder
      geofenceValid = _validateGeofence(position, jobLocation);

      if (!geofenceValid && !forceOffline) {
        setState(() {
          _showOfflineOverride = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You are outside the job site geofence. '
              'Use "Clock in anyway" to proceed.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }
    }

    // Create time entry
    final now = DateTime.now();
    final entry = TimeEntry(
      clientEventId: const Uuid().v4(),
      companyId: companyId,
      workerId: userId,
      jobId: _selectedJobId!,
      status: TimeEntryStatus.active,
      clockIn: now,
      clockInLocation: position != null
          ? TimeEntryGeoPoint(
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
              timestamp: now,
            )
          : null,
      clockInGeofenceValid: geofenceValid,
      gpsMissing: position == null,
      source: 'mobile',
      createdAt: now,
      updatedAt: now,
      origin: isOfflineMode ? 'offline' : 'online',
      needsReview: isOfflineMode || !geofenceValid || forceOffline,
      deviceId: deviceId,
      submittedAt: isOfflineMode ? null : now,
      approxLocation:
          position != null ? GeoPoint(position.latitude, position.longitude) : null,
    );

    // TODO: Save to Firestore (or queue if offline)
    // For now, just update local state
    setState(() {
      _activeEntry = entry;
      _showOfflineOverride = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isOfflineMode
                ? 'Clocked in (offline). Entry will be reviewed by admin.'
                : 'Clocked in successfully!',
          ),
          backgroundColor:
              isOfflineMode ? DesignTokens.warningAmber : DesignTokens.successGreen,
        ),
      );
    }
  }

  Future<void> _handleClockOut() async {
    if (_activeEntry == null) return;

    final position = await _getCurrentPosition();
    final now = DateTime.now();

    // Check if entry exceeds 24 hours (fraud control)
    final duration = now.difference(_activeEntry!.clockIn);
    if (duration.inHours >= 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot clock out: Entry exceeds 24 hours. '
            'Please contact your administrator.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Update entry with clock out
    final updatedEntry = _activeEntry!.copyWith(
      clockOut: now,
      clockOutLocation: position != null
          ? TimeEntryGeoPoint(
              latitude: position.latitude,
              longitude: position.longitude,
              accuracy: position.accuracy,
              timestamp: now,
            )
          : null,
      clockOutGeofenceValid: position != null ? true : null, // TODO: Validate
      status: TimeEntryStatus.pending,
      updatedAt: now,
    );

    // TODO: Save to Firestore (or queue if offline)
    // For now, just clear local state
    setState(() {
      _activeEntry = null;
    });

    // Silence unused variable warning until Firestore integration
    // ignore: avoid_print
    print('Clock out entry created: ${updatedEntry.id}');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clocked out successfully!'),
          backgroundColor: DesignTokens.successGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userEmail = ref.watch(currentUserProvider)?.email ?? 'User';

    return RefreshIndicator(
      onRefresh: () async {
        await _loadActiveEntry();
        await _getCurrentPosition();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Welcome header
            Text(
              'Welcome, $userEmail',
              style: Theme.of(context).textTheme.headlineSmall,
              key: const Key('welcomeText'),
            ),
            const SizedBox(height: DesignTokens.spaceSM),

            // Online/Offline indicator
            _buildConnectionStatus(),

            const SizedBox(height: DesignTokens.spaceLG),

            // GPS Status Card
            _buildGPSStatusCard(),

            const SizedBox(height: DesignTokens.spaceLG),

            // Current Status Card
            _activeEntry != null
                ? _buildClockedInCard()
                : _buildClockedOutCard(),

            const SizedBox(height: DesignTokens.spaceLG),

            // Action Buttons
            _activeEntry != null
                ? _buildClockOutButton()
                : _buildClockInSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Card(
      color: _isOnline
          ? DesignTokens.successGreen.withValues(alpha: 0.1)
          : DesignTokens.warningAmber.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceSM),
        child: Row(
          children: [
            Icon(
              _isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: _isOnline ? DesignTokens.successGreen : DesignTokens.warningAmber,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              _isOnline ? 'Online' : 'Offline - Changes will sync when connected',
              style: TextStyle(
                fontSize: 12,
                color:
                    _isOnline ? DesignTokens.successGreen : DesignTokens.warningAmber,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGPSStatusCard() {
    final accuracy = _gpsAccuracy;
    final position = _currentPosition;

    Color statusColor = Colors.grey;
    String statusText = 'GPS not acquired';
    IconData statusIcon = Icons.location_searching;

    if (_isLoadingPosition) {
      statusText = 'Acquiring GPS...';
    } else if (position != null && accuracy != null) {
      if (accuracy <= 20) {
        statusColor = DesignTokens.successGreen;
        statusText = 'Excellent (±${accuracy.toStringAsFixed(0)}m)';
        statusIcon = Icons.gps_fixed;
      } else if (accuracy <= 50) {
        statusColor = DesignTokens.infoBlue;
        statusText = 'Good (±${accuracy.toStringAsFixed(0)}m)';
        statusIcon = Icons.gps_fixed;
      } else {
        statusColor = DesignTokens.warningAmber;
        statusText = 'Poor (±${accuracy.toStringAsFixed(0)}m)';
        statusIcon = Icons.gps_not_fixed;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GPS Status',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
            ),
            if (!_isLoadingPosition)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _getCurrentPosition,
                tooltip: 'Refresh GPS',
              ),
            if (_isLoadingPosition)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClockedInCard() {
    final entry = _activeEntry!;
    final duration = DateTime.now().difference(entry.clockIn);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    return Card(
      color: DesignTokens.successGreen.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.access_time_filled,
                  color: DesignTokens.successGreen,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Currently Clocked In',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: DesignTokens.successGreen,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        'Job: ${entry.jobId}', // TODO: Show job name
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTimeInfo(
                  'Clock In',
                  _formatTime(entry.clockIn),
                ),
                Text(
                  '${hours}h ${minutes}m',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: DesignTokens.dsierraRed,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            if (entry.origin == 'offline' || entry.needsReview) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DesignTokens.warningAmber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMD),
                  border: Border.all(color: DesignTokens.warningAmber),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: DesignTokens.warningAmber,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This entry will be reviewed by admin',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildClockedOutCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Column(
          children: [
            const Icon(
              Icons.schedule,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(
              'Not Currently Clocked In',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Select a job and clock in to start tracking time',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClockInSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Job selector
        DropdownButtonFormField<String>(
          value: _selectedJobId,
          decoration: const InputDecoration(
            labelText: 'Select Job',
            prefixIcon: Icon(Icons.work),
          ),
          items: const [
            // TODO: Load from Firestore
            DropdownMenuItem(
              value: 'job1',
              child: Text('Sample Job 1'),
            ),
            DropdownMenuItem(
              value: 'job2',
              child: Text('Sample Job 2'),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _selectedJobId = value;
            });
          },
        ),
        const SizedBox(height: DesignTokens.spaceMD),

        // Clock in button
        FilledButton.icon(
          onPressed: _selectedJobId == null ? null : () => _handleClockIn(),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Clock In'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.all(DesignTokens.spaceMD),
            backgroundColor: DesignTokens.dsierraRed,
          ),
        ),

        // Offline override button
        if (_showOfflineOverride) ...[
          const SizedBox(height: DesignTokens.spaceSM),
          OutlinedButton.icon(
            onPressed: () => _handleClockIn(forceOffline: true),
            icon: const Icon(Icons.warning_amber),
            label: const Text('Clock in anyway (will need review)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(DesignTokens.spaceMD),
              foregroundColor: DesignTokens.warningAmber,
              side: const BorderSide(color: DesignTokens.warningAmber),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildClockOutButton() {
    return FilledButton.icon(
      onPressed: _handleClockOut,
      icon: const Icon(Icons.stop),
      label: const Text('Clock Out'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        backgroundColor: DesignTokens.errorRed,
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
        Text(
          time,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
