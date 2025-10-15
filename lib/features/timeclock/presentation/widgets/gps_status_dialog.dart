/// GPS Status Dialog
///
/// PURPOSE:
/// Shows GPS/location status information to the user.
library;

import 'package:flutter/material.dart';

/// Show GPS status dialog
Future<void> showGPSStatusDialog(
  BuildContext context, {
  required bool isEnabled,
  required String? errorMessage,
}) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          Icon(
            isEnabled ? Icons.gps_fixed : Icons.gps_off,
            color: isEnabled ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(isEnabled ? 'GPS Active' : 'GPS Disabled'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isEnabled) ...[
            const Text('GPS is working correctly.'),
            const SizedBox(height: 8),
            const Text('You can clock in when you arrive at the job site.'),
          ] else ...[
            const Text('GPS is currently disabled or not available.'),
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            const Text(
              'Please enable location services to use the time clock.',
            ),
          ],
        ],
      ),
      actions: [
        if (!isEnabled)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Go to Settings'),
          ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
