/// Location Service Interface
///
/// PURPOSE:
/// Abstract interface for GPS and location handling.
/// Supports multi-signal verification and offline scenarios.
///
/// FEATURES:
/// - Current location with accuracy
/// - Permission handling with primer flow
/// - Battery-efficient location tracking
/// - Multi-signal verification (GPS + Wi-Fi + network)
/// - Privacy mode support
/// - Offline location caching
///
/// PRODUCTION REQUIREMENTS (per coach notes):
/// - 2 of 3 signal verification (GPS + Wi-Fi + geohash)
/// - Accuracy threshold enforcement
/// - Battery-aware tracking modes
/// - Permission primer before system dialog
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Location accuracy level
enum LocationAccuracy {
  /// Best accuracy (high battery usage)
  best,

  /// Balanced accuracy (moderate battery usage)
  balanced,

  /// Low accuracy (low battery usage)
  low;

  /// Get accuracy in meters
  double get thresholdMeters {
    switch (this) {
      case LocationAccuracy.best:
        return 10.0;
      case LocationAccuracy.balanced:
        return 50.0;
      case LocationAccuracy.low:
        return 100.0;
    }
  }
}

/// Location permission status
enum LocationPermissionStatus {
  /// Permission granted
  granted,

  /// Permission denied by user
  denied,

  /// Permission permanently denied (requires settings)
  deniedForever,

  /// Permission not yet requested
  notDetermined;

  bool get isGranted => this == LocationPermissionStatus.granted;
  bool get isDenied =>
      this == LocationPermissionStatus.denied ||
      this == LocationPermissionStatus.deniedForever;
  bool get needsSettingsRedirect =>
      this == LocationPermissionStatus.deniedForever;
}

/// Location result with multi-signal data
class LocationResult {
  final double latitude;
  final double longitude;
  final double accuracy; // GPS accuracy in meters
  final DateTime timestamp;

  // Multi-signal verification data
  final bool hasGPS;
  final bool hasWiFi;
  final bool hasNetwork;
  final String? geohash; // For geofence caching

  // Metadata
  final double? altitude;
  final double? speed;
  final double? heading;

  LocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
    this.hasGPS = true,
    this.hasWiFi = false,
    this.hasNetwork = false,
    this.geohash,
    this.altitude,
    this.speed,
    this.heading,
  });

  /// Check if location meets minimum signal requirements
  /// (2 of 3: GPS + Wi-Fi + network)
  bool get meetsSignalRequirements {
    int signals = 0;
    if (hasGPS) signals++;
    if (hasWiFi) signals++;
    if (hasNetwork) signals++;
    return signals >= 2;
  }

  /// Check if accuracy is acceptable
  bool isAcceptable(LocationAccuracy threshold) {
    return accuracy <= threshold.thresholdMeters;
  }

  /// Check if location is recent (within 30 seconds)
  bool get isRecent {
    final age = DateTime.now().difference(timestamp);
    return age.inSeconds <= 30;
  }

  /// Create a copy with updated fields
  LocationResult copyWith({
    double? latitude,
    double? longitude,
    double? accuracy,
    DateTime? timestamp,
    bool? hasGPS,
    bool? hasWiFi,
    bool? hasNetwork,
    String? geohash,
    double? altitude,
    double? speed,
    double? heading,
  }) {
    return LocationResult(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      timestamp: timestamp ?? this.timestamp,
      hasGPS: hasGPS ?? this.hasGPS,
      hasWiFi: hasWiFi ?? this.hasWiFi,
      hasNetwork: hasNetwork ?? this.hasNetwork,
      geohash: geohash ?? this.geohash,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
    );
  }
}

/// Abstract location service interface
abstract class LocationService {
  /// Check current permission status
  Future<LocationPermissionStatus> checkPermission();

  /// Request location permission
  /// Returns true if granted
  Future<bool> requestPermission();

  /// Check if location services are enabled on device
  Future<bool> isLocationServiceEnabled();

  /// Open device location settings
  Future<void> openLocationSettings();

  /// Open app settings (for "denied forever" case)
  /// IMPLEMENTATION TODO: Use app_settings package or platform-specific code
  Future<bool> openAppSettings();

  /// Get stabilization tip for poor accuracy
  /// Returns user-friendly message based on accuracy level
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

  /// Get current location with specified accuracy
  /// Throws LocationException if unable to get location
  Future<LocationResult> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.balanced,
    Duration timeout = const Duration(seconds: 10),
  });

  /// Get cached location (last known position)
  /// Returns null if no cached location available
  Future<LocationResult?> getCachedLocation();

  /// Start continuous location tracking
  /// Returns stream of location updates
  Stream<LocationResult> watchLocation({
    LocationAccuracy accuracy = LocationAccuracy.balanced,
    Duration updateInterval = const Duration(minutes: 5),
  });

  /// Stop location tracking (cleanup stream)
  Future<void> stopTracking();

  /// Calculate distance between two points in meters
  /// Uses Haversine formula
  double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  });

  /// Generate geohash for location
  /// Used for offline geofence caching
  String generateGeohash({
    required double latitude,
    required double longitude,
    int precision = 7, // ~150m precision
  });
}

/// Location service exceptions
class LocationException implements Exception {
  final String message;
  final LocationExceptionType type;

  LocationException(this.message, this.type);

  @override
  String toString() => 'LocationException: $message';
}

/// Exception types
enum LocationExceptionType {
  /// Permission denied by user
  permissionDenied,

  /// Location services disabled on device
  serviceDisabled,

  /// Timeout waiting for location
  timeout,

  /// Location accuracy too low
  insufficientAccuracy,

  /// Multi-signal requirement not met
  insufficientSignals,

  /// Unknown error
  unknown,
}

/// Provider for location service
/// Implementation will be provided by concrete class
final locationServiceProvider = Provider<LocationService>((ref) {
  throw UnimplementedError(
    'LocationService provider must be overridden with concrete implementation',
  );
});
