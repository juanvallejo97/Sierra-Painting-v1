/// Device Info Service
///
/// PURPOSE:
/// Provides stable device identifier for debugging and support.
/// Used to correlate clock events across sessions and network retries.
///
/// IMPLEMENTATION:
/// - Tries to get platform-specific stable ID (Android: androidId, iOS: identifierForVendor)
/// - Falls back to generated UUID persisted in SharedPreferences
/// - Format: "$platform-$model-$id"
///
/// DEPENDENCIES:
/// - device_info_plus: ^10.0.0
/// - shared_preferences: ^2.2.0
library;

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service to get stable device identifier
class DeviceInfoService {
  final DeviceInfoPlugin _deviceInfo;
  final SharedPreferences _prefs;

  DeviceInfoService({
    required DeviceInfoPlugin deviceInfo,
    required SharedPreferences prefs,
  }) : _deviceInfo = deviceInfo,
       _prefs = prefs;

  /// Get stable device ID
  ///
  /// Format: "android-SM-G998U-abc123" or "ios-iPhone15,2-xyz789"
  ///
  /// Tries platform-specific ID first, falls back to persisted UUID
  Future<String> getDeviceId() async {
    // Check cache first
    final cached = _prefs.getString('device_id');
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    String deviceId;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        final id = androidInfo.id; // Android ID (stable unless factory reset)
        final model = androidInfo.model;
        deviceId = 'android-$model-$id';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        final id = iosInfo.identifierForVendor ?? _generateFallbackId();
        final model = iosInfo.model;
        deviceId = 'ios-$model-$id';
      } else {
        // Web or other platforms
        deviceId = 'web-${_generateFallbackId()}';
      }
    } catch (e) {
      // Fallback if platform detection fails
      deviceId = 'unknown-${_generateFallbackId()}';
    }

    // Persist for future use
    await _prefs.setString('device_id', deviceId);

    return deviceId;
  }

  /// Generate fallback UUID
  String _generateFallbackId() {
    final fallback = _prefs.getString('device_fallback_uuid');
    if (fallback != null && fallback.isNotEmpty) {
      return fallback;
    }

    final uuid = const Uuid().v4();
    _prefs.setString('device_fallback_uuid', uuid);
    return uuid;
  }
}

/// Provider for DeviceInfoService
final deviceInfoServiceProvider = Provider<DeviceInfoService>((ref) {
  throw UnimplementedError(
    'deviceInfoServiceProvider must be overridden with concrete implementation',
  );
});
