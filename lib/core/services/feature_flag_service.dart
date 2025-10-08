import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service for managing feature flags using Firebase Remote Config
///
/// Design principles:
/// - Flags map to sprint stories (feature_b1_clock_in_enabled)
/// - Default to OFF for new features, ON for released features
/// - Support gradual rollout via Remote Config conditions
/// - Cache for performance, refresh every 1 hour
///
/// See: docs/FEATURE_FLAGS.md for complete documentation
class FeatureFlagService {
  static final FeatureFlagService _instance = FeatureFlagService._internal();
  factory FeatureFlagService() => _instance;
  FeatureFlagService._internal();

  FirebaseRemoteConfig? _remoteConfig;
  bool _initialized = false;

  // Feature flag keys - Sprint-based organization
  // V1 Features (active)
  static const String clockInEnabled = 'feature_b1_clock_in_enabled';
  static const String clockOutEnabled = 'feature_b2_clock_out_enabled';
  static const String jobsTodayEnabled = 'feature_b3_jobs_today_enabled';

  // V2 Features (gated)
  static const String createQuoteEnabled = 'feature_c1_create_quote_enabled';
  static const String markPaidEnabled = 'feature_c3_mark_paid_enabled';

  // V4 Features (optional)
  static const String stripeCheckoutEnabled =
      'feature_c5_stripe_checkout_enabled';

  // Operational flags
  static const String offlineModeEnabled = 'offline_mode_enabled';
  static const String gpsTrackingEnabled = 'gps_tracking_enabled';

  /// Initialize the feature flag service
  static Future<void> initialize() async {
    try {
      final instance = FeatureFlagService();
      instance._remoteConfig = FirebaseRemoteConfig.instance;

      // Set default values matching docs/FEATURE_FLAGS.md
      await instance._remoteConfig!.setDefaults(<String, dynamic>{
        // V1 Features (active)
        clockInEnabled: true,
        clockOutEnabled: true,
        jobsTodayEnabled: true,

        // V2 Features (gated)
        createQuoteEnabled: false,
        markPaidEnabled: false,

        // V4 Features (optional)
        stripeCheckoutEnabled: false,

        // Operational flags
        offlineModeEnabled: true,
        gpsTrackingEnabled: true,
      });

      // Set fetch timeout and cache expiration
      await instance._remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(minutes: 1),
          minimumFetchInterval: const Duration(hours: 1),
        ),
      );

      // Fetch and activate
      await instance._remoteConfig!.fetchAndActivate();
      instance._initialized = true;
    } catch (e) {
      // If Remote Config fails, use default values
      // This ensures the app continues to work
      if (kDebugMode) {
        debugPrint('Failed to initialize Remote Config: $e');
      }
    }
  }

  /// Check if a feature is enabled
  bool isEnabled(String key) {
    if (!_initialized || _remoteConfig == null) {
      // Return safe defaults
      return _getDefaultValue(key);
    }
    return _remoteConfig!.getBool(key);
  }

  /// Get default value for a feature flag
  bool _getDefaultValue(String key) {
    // V1 features default to ON
    if (key == clockInEnabled ||
        key == clockOutEnabled ||
        key == jobsTodayEnabled ||
        key == offlineModeEnabled ||
        key == gpsTrackingEnabled) {
      return true;
    }
    // All other features default to OFF
    return false;
  }

  /// Check if Stripe payments are enabled (legacy)
  bool get isStripeEnabled => isEnabled(stripeCheckoutEnabled);

  /// Check if offline mode is enabled (legacy)
  bool get isOfflineModeEnabled => isEnabled(offlineModeEnabled);

  /// Get a boolean feature flag value
  bool getBoolean(String key, {bool defaultValue = false}) {
    if (!_initialized || _remoteConfig == null) {
      return defaultValue;
    }
    return _remoteConfig!.getBool(key);
  }

  /// Get a string feature flag value
  String getString(String key, {String defaultValue = ''}) {
    if (!_initialized || _remoteConfig == null) {
      return defaultValue;
    }
    return _remoteConfig!.getString(key);
  }

  /// Get an integer feature flag value
  int getInt(String key, {int defaultValue = 0}) {
    if (!_initialized || _remoteConfig == null) {
      return defaultValue;
    }
    return _remoteConfig!.getInt(key);
  }

  /// Get a double feature flag value
  double getDouble(String key, {double defaultValue = 0.0}) {
    if (!_initialized || _remoteConfig == null) {
      return defaultValue;
    }
    return _remoteConfig!.getDouble(key);
  }

  /// Refresh feature flags
  Future<void> refresh() async {
    if (_remoteConfig == null) return;
    try {
      await _remoteConfig!.fetchAndActivate();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to refresh Remote Config: $e');
      }
    }
  }
}

// =============================================================================
// Riverpod Providers for feature flags
// =============================================================================

/// Provider for the feature flag service
final featureFlagServiceProvider = Provider<FeatureFlagService>((ref) {
  return FeatureFlagService();
});

/// Sprint V1 Feature Providers
final clockInEnabledProvider = Provider<bool>((ref) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.isEnabled(FeatureFlagService.clockInEnabled);
});

final clockOutEnabledProvider = Provider<bool>((ref) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.isEnabled(FeatureFlagService.clockOutEnabled);
});

final jobsTodayEnabledProvider = Provider<bool>((ref) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.isEnabled(FeatureFlagService.jobsTodayEnabled);
});

/// Sprint V2 Feature Providers
final createQuoteEnabledProvider = Provider<bool>((ref) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.isEnabled(FeatureFlagService.createQuoteEnabled);
});

final markPaidEnabledProvider = Provider<bool>((ref) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.isEnabled(FeatureFlagService.markPaidEnabled);
});

/// Sprint V4 Feature Providers
final stripeCheckoutEnabledProvider = Provider<bool>((ref) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.isEnabled(FeatureFlagService.stripeCheckoutEnabled);
});

/// Operational Flag Providers
final offlineModeEnabledProvider = Provider<bool>((ref) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.isEnabled(FeatureFlagService.offlineModeEnabled);
});

final gpsTrackingEnabledProvider = Provider<bool>((ref) {
  final service = ref.watch(featureFlagServiceProvider);
  return service.isEnabled(FeatureFlagService.gpsTrackingEnabled);
});
