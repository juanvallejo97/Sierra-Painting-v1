/// Connectivity Banner Widget (P - UX Polish)
///
/// Displays a persistent banner when device is offline.
/// Automatically shows/hides based on connectivity status.
///
/// FEATURES:
/// - Watches connectivity via SyncService
/// - Shows pending sync count when offline
/// - Dismissible but re-appears on next offline event
/// - Accessible colors and contrast
///
/// USAGE:
/// ```dart
/// Scaffold(
///   body: Column(
///     children: [
///       ConnectivityBanner(), // <-- Add at top of screen
///       Expanded(child: YourContent()),
///     ],
///   ),
/// )
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/offline/sync_service.dart';

/// Connectivity banner that shows when device is offline
class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final pendingCount = ref.watch(syncServicePendingCountProvider).value ?? 0;

    // Hide banner when online and no pending syncs
    if (isOnline && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    // Show banner when offline or has pending syncs
    return Material(
      color: isOnline ? Colors.orange.shade700 : Colors.red.shade700,
      elevation: 4,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                isOnline ? Icons.sync : Icons.wifi_off,
                color: Colors.white,
                size: 20,
                semanticLabel: isOnline ? 'Syncing' : 'Offline',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isOnline
                      ? 'Syncing $pendingCount pending operation${pendingCount == 1 ? '' : 's'}...'
                      : 'No internet connection${pendingCount > 0 ? ' • $pendingCount pending' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (pendingCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$pendingCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Error message mapping utility (P - UX Polish)
///
/// Centralizes error message transformation for consistent UX.
/// Maps technical errors to user-friendly messages.
class ErrorMessageMapper {
  /// Map location errors to user-friendly messages
  static String mapLocationError(String error) {
    final lowerError = error.toLowerCase();

    // Permission errors
    if (lowerError.contains('permission') && lowerError.contains('denied')) {
      if (lowerError.contains('permanently') ||
          lowerError.contains('forever')) {
        return 'Location permission permanently denied. Please enable in Settings → App Permissions.';
      }
      return 'Location permission denied. Please allow location access to clock in/out.';
    }

    // Service disabled
    if (lowerError.contains('location services') &&
        lowerError.contains('disabled')) {
      return 'Location services are disabled. Please enable GPS in your device settings.';
    }

    // Timeout errors
    if (lowerError.contains('timeout')) {
      return 'Location timeout. Please ensure you have a clear view of the sky and try again.';
    }

    // Accuracy errors
    if (lowerError.contains('accuracy')) {
      return 'GPS signal weak. Move to an open area for better accuracy.';
    }

    // Geofence errors
    if (lowerError.contains('outside geofence')) {
      final match = RegExp(r'(\d+\.?\d*)m from').firstMatch(error);
      if (match != null) {
        return 'You are ${match.group(1)}m from the job site. Move closer to clock in.';
      }
      return 'You are outside the job site area. Move closer to clock in.';
    }

    // Default: return original error
    return error;
  }

  /// Map clock in/out API errors to user-friendly messages
  static String mapClockError(String error) {
    final lowerError = error.toLowerCase();

    // Assignment errors
    if (lowerError.contains('not assigned')) {
      return 'You are not assigned to this job. Contact your manager.';
    }

    if (lowerError.contains('already clocked in')) {
      return 'You are already clocked in to a job. Clock out first.';
    }

    if (lowerError.contains('assignment not active')) {
      final match = RegExp(r'Starts:(.*)').firstMatch(error);
      if (match != null) {
        return 'This job assignment has not started yet. ${match.group(1)?.trim()}';
      }
      return 'This job assignment is not active yet.';
    }

    if (lowerError.contains('assignment expired')) {
      return 'This job assignment has ended. Contact your manager.';
    }

    // Authentication errors
    if (lowerError.contains('sign in required') ||
        lowerError.contains('unauthenticated')) {
      return 'Please sign in to use the timeclock.';
    }

    // Network errors
    if (lowerError.contains('network') || lowerError.contains('offline')) {
      return 'No internet connection. Your clock action has been saved and will sync when online.';
    }

    // Server errors
    if (lowerError.contains('internal server error') ||
        lowerError.contains('500')) {
      return 'Server error. Please try again in a moment.';
    }

    // Rate limiting
    if (lowerError.contains('too many requests') ||
        lowerError.contains('429')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }

    // Default: sanitize technical jargon
    if (lowerError.contains('exception') ||
        lowerError.contains('error') ||
        lowerError.contains('failed')) {
      return 'Unable to complete. Please try again or contact support.';
    }

    return error;
  }

  /// Map generic errors to user-friendly messages
  static String mapGenericError(String error) {
    final lowerError = error.toLowerCase();

    // Network errors
    if (lowerError.contains('socket') ||
        lowerError.contains('connection') ||
        lowerError.contains('network')) {
      return 'Connection error. Please check your internet and try again.';
    }

    // Timeout
    if (lowerError.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    // Parsing/data errors
    if (lowerError.contains('parse') ||
        lowerError.contains('format') ||
        lowerError.contains('invalid data')) {
      return 'Data error. Please try again or contact support.';
    }

    return 'An error occurred. Please try again.';
  }

  /// Main entry point - tries all mappers in sequence
  static String mapError(String error, {String? context}) {
    // Try context-specific mappers first
    if (context == 'location') {
      return mapLocationError(error);
    } else if (context == 'clock') {
      return mapClockError(error);
    }

    // Try all mappers
    final locationMapped = mapLocationError(error);
    if (locationMapped != error) return locationMapped;

    final clockMapped = mapClockError(error);
    if (clockMapped != error) return clockMapped;

    return mapGenericError(error);
  }
}
