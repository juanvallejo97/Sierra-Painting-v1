import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Service for managing feature flags using Firebase Remote Config
/// Allows toggling features like optional Stripe integration
class FeatureFlagService {
  static final FeatureFlagService _instance = FeatureFlagService._internal();
  factory FeatureFlagService() => _instance;
  FeatureFlagService._internal();

  FirebaseRemoteConfig? _remoteConfig;
  bool _initialized = false;

  // Feature flag keys
  static const String _stripeEnabledKey = 'stripe_enabled';
  static const String _offlineModeKey = 'offline_mode_enabled';

  /// Initialize the feature flag service
  static Future<void> initialize() async {
    try {
      final instance = FeatureFlagService();
      instance._remoteConfig = FirebaseRemoteConfig.instance;

      // Set default values
      await instance._remoteConfig!.setDefaults(<String, dynamic>{
        _stripeEnabledKey: false, // Stripe is OFF by default
        _offlineModeKey: true, // Offline mode is ON by default
      });

      // Set fetch timeout and cache expiration
      await instance._remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(minutes: 1),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      // Fetch and activate
      await instance._remoteConfig!.fetchAndActivate();
      instance._initialized = true;
    } catch (e) {
      // If Remote Config fails, use default values
      // This ensures the app continues to work
      print('Failed to initialize Remote Config: $e');
    }
  }

  /// Check if Stripe payments are enabled
  bool get isStripeEnabled {
    if (!_initialized || _remoteConfig == null) {
      return false; // Default to disabled
    }
    return _remoteConfig!.getBool(_stripeEnabledKey);
  }

  /// Check if offline mode is enabled
  bool get isOfflineModeEnabled {
    if (!_initialized || _remoteConfig == null) {
      return true; // Default to enabled
    }
    return _remoteConfig!.getBool(_offlineModeKey);
  }

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
      print('Failed to refresh Remote Config: $e');
    }
  }
}
