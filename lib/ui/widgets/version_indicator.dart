import 'package:flutter/material.dart';
import 'package:sierra_painting/core/app_version.dart';

/// Version indicator widget
///
/// Displays the current app version (e.g., "v0.0.13") in a subtle way.
/// Useful for:
/// - Cache debugging (verify which build is loaded)
/// - Staging/production verification
/// - Windows development (aggressive caching issues)
///
/// Usage:
/// ```dart
/// Scaffold(
///   body: Stack(
///     children: [
///       // Your main content
///       Positioned(
///         bottom: 8,
///         right: 8,
///         child: VersionIndicator(),
///       ),
///     ],
///   ),
/// )
/// ```
class VersionIndicator extends StatelessWidget {
  const VersionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          'v$kAppVersion',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
