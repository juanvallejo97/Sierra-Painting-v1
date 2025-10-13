import 'dart:async';

import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:permission_handler/permission_handler.dart';

/// Simple static helper for location access (J5 - Cross-Platform Parity)
///
/// Provides a simplified API for clock in/out flows with:
/// - One-time permission handling
/// - 6-second timeout with fallback to last known position
/// - Graceful error messages for GPS off or denied permissions
class LocationHelper {
  /// Ensure location permission is granted
  ///
  /// Returns true if permission is granted or successfully requested.
  /// Returns false if permanently denied or unavailable.
  ///
  /// Workflow:
  /// 1. Check if already granted → return true
  /// 2. Request permission if not determined
  /// 3. Return result
  static Future<bool> ensurePermission() async {
    try {
      // Check current status
      final status = await Permission.location.status;

      if (status.isGranted) {
        return true;
      }

      if (status.isPermanentlyDenied) {
        return false;
      }

      // Request permission
      final result = await Permission.location.request();
      return result.isGranted;
    } catch (e) {
      // Permission check failed - return false
      return false;
    }
  }

  /// Get current location with timeout and fallback
  ///
  /// Returns ({lat, lng}) record with coordinates.
  /// Throws [LocationException] with user-friendly message on failure.
  ///
  /// Fallback strategy:
  /// 1. Try high accuracy with timeout (default: 6s)
  /// 2. If timeout → try last known position
  /// 3. If no cached → try medium accuracy (3s timeout)
  /// 4. If all fail → throw LocationException
  static Future<({double lat, double lng})> getCurrent({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    // Check if location services are enabled
    final serviceEnabled =
        await geolocator.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationException(
        'Location services are disabled. Please enable GPS in your device settings.',
      );
    }

    // Check permission
    final permission = await geolocator.Geolocator.checkPermission();
    if (permission == geolocator.LocationPermission.denied) {
      final requested = await geolocator.Geolocator.requestPermission();
      if (requested == geolocator.LocationPermission.denied ||
          requested == geolocator.LocationPermission.deniedForever) {
        throw LocationException(
          'Location permission denied. Please allow location access to clock in/out.',
        );
      }
    }

    if (permission == geolocator.LocationPermission.deniedForever) {
      throw LocationException(
        'Location permission permanently denied. Please enable in Settings → App Permissions.',
      );
    }

    try {
      // Try high accuracy with timeout
      final position = await geolocator.Geolocator.getCurrentPosition(
        locationSettings: geolocator.LocationSettings(
          accuracy: geolocator.LocationAccuracy.best,
          timeLimit: timeout,
        ),
      );

      return (lat: position.latitude, lng: position.longitude);
    } on TimeoutException catch (_) {
      // Timeout - try last known position
      final lastKnown = await geolocator.Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        return (lat: lastKnown.latitude, lng: lastKnown.longitude);
      }

      // No cached position - try medium accuracy with shorter timeout
      try {
        final position = await geolocator.Geolocator.getCurrentPosition(
          locationSettings: geolocator.LocationSettings(
            accuracy: geolocator.LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 3),
          ),
        );

        return (lat: position.latitude, lng: position.longitude);
      } catch (_) {
        throw LocationException(
          'Location timeout. Please ensure you have a clear view of the sky and try again.',
        );
      }
    } catch (e) {
      throw LocationException('Unable to get location: ${e.toString()}');
    }
  }
}

/// Exception thrown when location operations fail
class LocationException implements Exception {
  final String message;

  LocationException(this.message);

  @override
  String toString() => message;
}
