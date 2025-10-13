/// Location Service Implementation
///
/// Concrete implementation of LocationService using geolocator package.
library;

import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:sierra_painting/core/services/location_service.dart';
import 'dart:async';

/// Concrete implementation of LocationService
class LocationServiceImpl implements LocationService {
  /// Get stabilization tip for poor accuracy
  @override
  String getStabilizationTip(double accuracy) {
    if (accuracy < 50) return '';
    if (accuracy < 100) {
      return 'Move to an open area for better GPS signal.';
    }
    if (accuracy < 200) {
      return 'Step outside or near a window. GPS signal is weak indoors.';
    }
    return 'GPS signal very weak. Go outside and wait 10-30 seconds.';
  }

  /// Get current location with timeout
  @override
  Future<LocationResult> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.balanced,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final settings = geolocator.LocationSettings(
        accuracy: _mapAccuracyToGeolocator(accuracy),
        timeLimit: timeout,
      );
      final position = await geolocator.Geolocator.getCurrentPosition(
        locationSettings: settings,
      );

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
        hasGPS: true,
        hasWiFi: false, // Geolocator doesn't expose this
        hasNetwork: false, // Geolocator doesn't expose this
        altitude: position.altitude,
        speed: position.speed,
        heading: position.heading,
      );
    } on TimeoutException {
      throw LocationException(
        'Location timeout after ${timeout.inSeconds}s',
        LocationExceptionType.timeout,
      );
    } on geolocator.LocationServiceDisabledException {
      throw LocationException(
        'Location services disabled on device',
        LocationExceptionType.serviceDisabled,
      );
    } on geolocator.PermissionDeniedException {
      throw LocationException(
        'Location permission denied',
        LocationExceptionType.permissionDenied,
      );
    } catch (e) {
      throw LocationException(
        'Failed to get location: $e',
        LocationExceptionType.unknown,
      );
    }
  }

  /// Check current permission status
  @override
  Future<LocationPermissionStatus> checkPermission() async {
    final permission = await geolocator.Geolocator.checkPermission();
    return _mapPermission(permission);
  }

  /// Request location permission
  @override
  Future<bool> requestPermission() async {
    final permission = await geolocator.Geolocator.requestPermission();
    return _mapPermission(permission) == LocationPermissionStatus.granted;
  }

  /// Check if location services are enabled
  @override
  Future<bool> isLocationServiceEnabled() async {
    return await geolocator.Geolocator.isLocationServiceEnabled();
  }

  /// Open device location settings
  @override
  Future<void> openLocationSettings() async {
    await geolocator.Geolocator.openLocationSettings();
  }

  /// Open app settings
  @override
  Future<bool> openAppSettings() async {
    return await geolocator.Geolocator.openAppSettings();
  }

  /// Get cached location (last known position)
  @override
  Future<LocationResult?> getCachedLocation() async {
    try {
      final position = await geolocator.Geolocator.getLastKnownPosition();
      if (position == null) return null;

      return LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
        hasGPS: true,
        altitude: position.altitude,
        speed: position.speed,
        heading: position.heading,
      );
    } catch (e) {
      return null;
    }
  }

  /// Watch location updates
  @override
  Stream<LocationResult> watchLocation({
    LocationAccuracy accuracy = LocationAccuracy.balanced,
    Duration updateInterval = const Duration(minutes: 5),
  }) {
    final settings = geolocator.LocationSettings(
      accuracy: _mapAccuracyToGeolocator(accuracy),
      distanceFilter: 10, // meters
      timeLimit: const Duration(minutes: 10),
    );

    return geolocator.Geolocator.getPositionStream(locationSettings: settings).map(
      (position) => LocationResult(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
        hasGPS: true,
        altitude: position.altitude,
        speed: position.speed,
        heading: position.heading,
      ),
    );
  }

  /// Stop tracking (no-op for geolocator)
  @override
  Future<void> stopTracking() async {
    // Geolocator streams are cancelled when disposed
  }

  /// Calculate distance between two points (Haversine formula)
  @override
  double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    return geolocator.Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Generate geohash
  @override
  String generateGeohash({
    required double latitude,
    required double longitude,
    int precision = 7,
  }) {
    // Simple geohash implementation
    // For production, use geohash package
    const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

    double minLat = -90.0;
    double maxLat = 90.0;
    double minLon = -180.0;
    double maxLon = 180.0;

    final hash = StringBuffer();
    int idx = 0;
    int bit = 0;

    while (hash.length < precision) {
      if (bit % 2 == 0) {
        // Longitude
        final mid = (minLon + maxLon) / 2;
        if (longitude > mid) {
          idx = (idx << 1) + 1;
          minLon = mid;
        } else {
          idx = idx << 1;
          maxLon = mid;
        }
      } else {
        // Latitude
        final mid = (minLat + maxLat) / 2;
        if (latitude > mid) {
          idx = (idx << 1) + 1;
          minLat = mid;
        } else {
          idx = idx << 1;
          maxLat = mid;
        }
      }

      bit++;

      if (bit == 5) {
        hash.write(base32[idx]);
        bit = 0;
        idx = 0;
      }
    }

    return hash.toString();
  }

  /// Map geolocator permission to our enum
  LocationPermissionStatus _mapPermission(geolocator.LocationPermission permission) {
    return switch (permission) {
      geolocator.LocationPermission.always ||
      geolocator.LocationPermission.whileInUse =>
        LocationPermissionStatus.granted,
      geolocator.LocationPermission.denied => LocationPermissionStatus.denied,
      geolocator.LocationPermission.deniedForever =>
        LocationPermissionStatus.deniedForever,
      geolocator.LocationPermission.unableToDetermine =>
        LocationPermissionStatus.notDetermined,
    };
  }

  /// Map our accuracy enum to geolocator
  geolocator.LocationAccuracy _mapAccuracyToGeolocator(
      LocationAccuracy accuracy) {
    return switch (accuracy) {
      LocationAccuracy.best => geolocator.LocationAccuracy.best,
      LocationAccuracy.balanced => geolocator.LocationAccuracy.high,
      LocationAccuracy.low => geolocator.LocationAccuracy.low,
    };
  }
}
