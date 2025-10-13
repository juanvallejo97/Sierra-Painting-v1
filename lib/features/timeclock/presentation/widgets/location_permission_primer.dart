/// Location Permission Primer
///
/// PURPOSE:
/// Educate user before showing system permission dialog.
/// Improves grant rate by explaining why permission is needed.
///
/// PATTERN:
/// 1. Show this dialog first (app-controlled, friendly)
/// 2. User taps "Enable Location"
/// 3. Then show system permission dialog
/// 4. Higher acceptance rate than cold system prompt
///
/// UX:
/// - Friendly illustration
/// - Clear benefit statement ("Verify you're at the job site")
/// - Two buttons: "Enable Location" (primary) and "Not Now" (secondary)
library;

import 'package:flutter/material.dart';

/// Location Permission Primer Dialog
///
/// USAGE:
/// ```dart
/// final shouldRequest = await showDialog<bool>(
///   context: context,
///   builder: (context) => const LocationPermissionPrimer(),
/// );
///
/// if (shouldRequest == true) {
///   await locationService.requestPermission();
/// }
/// ```
class LocationPermissionPrimer extends StatelessWidget {
  const LocationPermissionPrimer({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon/illustration
          Icon(
            Icons.location_on_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),

          // Title
          Text(
            'Enable Location',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Benefit statement
          Text(
            'We use your location to verify you\'re at the job site when clocking in. '
            'This helps ensure accurate time tracking and prevents errors.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Privacy note
          Text(
            'Your location is only checked during clock in/out and is never shared.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        // Secondary action
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not Now'),
        ),

        // Primary action
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Enable Location'),
        ),
      ],
    );
  }
}

/// Permission Denied Forever Dialog
///
/// Shown when user has permanently denied permission.
/// Directs user to app settings.
class PermissionDeniedForeverDialog extends StatelessWidget {
  const PermissionDeniedForeverDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Location Permission Needed'),
      content: const Text(
        'Location permission is required to clock in. '
        'Please enable location access in your device settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Open Settings'),
        ),
      ],
    );
  }
}

/// GPS Accuracy Warning Dialog
///
/// Shown when GPS accuracy is poor (>50m).
/// Helps user improve signal before attempting clock-in.
class GPSAccuracyWarningDialog extends StatelessWidget {
  final double accuracy;
  final String tip;

  const GPSAccuracyWarningDialog({
    super.key,
    required this.accuracy,
    required this.tip,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.signal_wifi_statusbar_null, color: Colors.orange),
          SizedBox(width: 8),
          Text('Weak GPS Signal'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current accuracy: ${accuracy.round()}m'),
          const SizedBox(height: 12),
          Text(
            tip,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Better GPS accuracy helps ensure your clock-in is accepted.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Try Again'),
        ),
      ],
    );
  }
}
