/// Location Service Provider
///
/// Provides concrete implementation of LocationService using geolocator package.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/services/location_service.dart';
import 'package:sierra_painting/core/services/location_service_impl.dart';

/// Provider override for LocationService with concrete implementation
final locationServiceImplProvider = Provider<LocationService>((ref) {
  return LocationServiceImpl();
});
