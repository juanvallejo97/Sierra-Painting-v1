/// PHASE 2: SKELETON CODE - Feature Flags System
///
/// PURPOSE:
/// - Remote feature flag management via Firebase Remote Config
/// - Respect system-level preferences (Reduce Motion, Battery Saver)
/// - Enable gradual rollout of new features
/// - Instant kill-switch capability
///
/// ARCHITECTURE:
/// FeatureFlags (static)
///   -> RemoteConfigService (singleton)
///   -> SystemPreferencesService (singleton)
///   -> FlagOverrideService (debug only)

library feature_flags;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

// ============================================================================
// DATA STRUCTURES
// ============================================================================

/// Enum of all available feature flags
enum FeatureFlag {
  SHIMMER_LOADERS,
  LOTTIE_ANIMATIONS,
  HAPTIC_FEEDBACK,
  OFFLINE_QUEUE_V2,
  AUDIT_TRAIL,
  SMART_FORMS,
  KPI_DRILL_DOWN,
  CONFLICT_DETECTION,
}

/// Flag configuration with metadata
class FlagConfig {
  final FeatureFlag flag;
  final bool defaultValue;
  final String remoteConfigKey;
  final bool respectReduceMotion; // If true, disabled when Reduce Motion is on
  final bool respectBatterySaver; // If true, disabled in battery saver mode
  final String description;

  // CONSTRUCTOR: Initialize flag configuration
  const FlagConfig({
    required this.flag,
    required this.defaultValue,
    required this.remoteConfigKey,
    this.respectReduceMotion = false,
    this.respectBatterySaver = false,
    required this.description,
  });
}

// ============================================================================
// MAIN FEATURE FLAGS CLASS
// ============================================================================

class FeatureFlags {
  // PRIVATE: Prevent instantiation (static-only class)
  FeatureFlags._();

  // STATE: Map of all flag configurations
  static final Map<FeatureFlag, FlagConfig> _flagConfigs = {};

  // STATE: Current flag values (after remote + system prefs applied)
  static final Map<FeatureFlag, bool> _currentValues = {};

  // STATE: Initialization status
  static bool _initialized = false;

  // ============================================================================
  // PUBLIC API
  // ============================================================================

  /// ASYNC: Initialize feature flags system
  /// 1. Load flag configurations
  /// 2. Fetch from Remote Config
  /// 3. Apply system preferences
  /// 4. Set up listeners for system changes
  static Future<void> initialize() async {
    if (_initialized) return;

    // TODO(Phase 3): Load all flag configurations with default values
    _loadFlagConfigs();

    try {
      // TODO(Phase 3): Fetch flag values from Firebase Remote Config
      await _syncWithRemoteConfig();
    } catch (e) {
      // TODO(Phase 3): Log error to Crashlytics
      debugPrint('Failed to sync remote config: $e');
    }

    // TODO(Phase 3): Apply system preferences (Reduce Motion, Battery Saver)
    _applySystemPreferences();

    // TODO(Phase 3): Set up listeners for preference changes
    _setupListeners();

    _initialized = true;
  }

  /// SYNC: Check if a feature is enabled
  /// Returns: true if enabled, false otherwise
  static bool isEnabled(FeatureFlag flag) {
    // Return default if not initialized
    if (!_initialized) {
      return _flagConfigs[flag]?.defaultValue ?? false;
    }

    // TODO(Phase 3): Check if flag is overridden in debug mode
    // TODO(Phase 3): Return current value after remote config + system prefs applied
    return _currentValues[flag] ?? _flagConfigs[flag]?.defaultValue ?? false;
  }

  /// SYNC: Get all enabled flags (for debugging)
  static Map<FeatureFlag, bool> getAll() {
    // TODO(Phase 3): Include override status in debug mode
    return Map.unmodifiable(_currentValues);
  }

  /// ASYNC: Force refresh from Remote Config
  static Future<void> refresh() async {
    // TODO(Phase 3): Fetch latest values from Remote Config
    await _syncWithRemoteConfig();

    // TODO(Phase 3): Re-apply system preferences
    _applySystemPreferences();
  }

  /// DEBUG ONLY: Override a flag value locally
  static void override(FeatureFlag flag, bool value) {
    assert(kDebugMode, 'Overrides only allowed in debug mode');

    // TODO(Phase 3): Store override in SharedPreferences for persistence
    _currentValues[flag] = value;
  }

  // ============================================================================
  // PRIVATE METHODS
  // ============================================================================

  /// Load all flag configurations with defaults
  static void _loadFlagConfigs() {
    // TODO(Phase 3): Load all flag configurations
    _flagConfigs[FeatureFlag.SHIMMER_LOADERS] = const FlagConfig(
      flag: FeatureFlag.SHIMMER_LOADERS,
      defaultValue: false,
      remoteConfigKey: 'shimmer_loaders_enabled',
      respectReduceMotion: true,
      respectBatterySaver: true,
      description: 'Enable shimmer loading animations',
    );

    _flagConfigs[FeatureFlag.LOTTIE_ANIMATIONS] = const FlagConfig(
      flag: FeatureFlag.LOTTIE_ANIMATIONS,
      defaultValue: false,
      remoteConfigKey: 'lottie_animations_enabled',
      respectReduceMotion: true,
      respectBatterySaver: false,
      description: 'Enable Lottie animations',
    );

    _flagConfigs[FeatureFlag.HAPTIC_FEEDBACK] = const FlagConfig(
      flag: FeatureFlag.HAPTIC_FEEDBACK,
      defaultValue: false,
      remoteConfigKey: 'haptic_feedback_enabled',
      respectReduceMotion: false,
      respectBatterySaver: true,
      description: 'Enable haptic feedback',
    );

    _flagConfigs[FeatureFlag.OFFLINE_QUEUE_V2] = const FlagConfig(
      flag: FeatureFlag.OFFLINE_QUEUE_V2,
      defaultValue: false,
      remoteConfigKey: 'offline_queue_v2_enabled',
      respectReduceMotion: false,
      respectBatterySaver: false,
      description: 'Enable enhanced offline queue',
    );

    _flagConfigs[FeatureFlag.AUDIT_TRAIL] = const FlagConfig(
      flag: FeatureFlag.AUDIT_TRAIL,
      defaultValue: false,
      remoteConfigKey: 'audit_trail_enabled',
      respectReduceMotion: false,
      respectBatterySaver: false,
      description: 'Enable audit trail logging',
    );

    _flagConfigs[FeatureFlag.SMART_FORMS] = const FlagConfig(
      flag: FeatureFlag.SMART_FORMS,
      defaultValue: false,
      remoteConfigKey: 'smart_forms_enabled',
      respectReduceMotion: false,
      respectBatterySaver: false,
      description: 'Enable smart forms with autosave',
    );

    _flagConfigs[FeatureFlag.KPI_DRILL_DOWN] = const FlagConfig(
      flag: FeatureFlag.KPI_DRILL_DOWN,
      defaultValue: false,
      remoteConfigKey: 'kpi_drill_down_enabled',
      respectReduceMotion: false,
      respectBatterySaver: false,
      description: 'Enable KPI drill-down navigation',
    );

    _flagConfigs[FeatureFlag.CONFLICT_DETECTION] = const FlagConfig(
      flag: FeatureFlag.CONFLICT_DETECTION,
      defaultValue: false,
      remoteConfigKey: 'conflict_detection_enabled',
      respectReduceMotion: false,
      respectBatterySaver: false,
      description: 'Enable time entry conflict detection',
    );

    // TODO(Phase 3): Add remaining flags as they're developed
  }

  /// Fetch flag values from Firebase Remote Config
  static Future<void> _syncWithRemoteConfig() async {
    try {
      // TODO(Phase 3): Configure Remote Config settings (fetch timeout, minimum fetch interval)
      final remoteConfig = FirebaseRemoteConfig.instance;

      // TODO(Phase 3): Set Remote Config settings
      // await remoteConfig.setConfigSettings(RemoteConfigSettings(
      //   fetchTimeout: Duration(seconds: 10),
      //   minimumFetchInterval: Duration(hours: 1),
      // ));

      // TODO(Phase 3): Fetch and activate remote values
      await remoteConfig.fetchAndActivate();

      // TODO(Phase 3): Update current values from remote config
      for (final config in _flagConfigs.values) {
        try {
          final remoteValue = remoteConfig.getBool(config.remoteConfigKey);
          _currentValues[config.flag] = remoteValue;
        } catch (e) {
          // Use default if remote value not available
          _currentValues[config.flag] = config.defaultValue;
          debugPrint('Using default for ${config.flag}: $e');
        }
      }
    } catch (e) {
      // TODO(Phase 3): Log to Crashlytics
      debugPrint('Failed to sync with remote config: $e');
      // Use defaults for all flags
      for (final config in _flagConfigs.values) {
        _currentValues[config.flag] = config.defaultValue;
      }
    }
  }

  /// Apply system preferences (Reduce Motion, Battery Saver)
  static void _applySystemPreferences() {
    // TODO(Phase 3): Get system preferences from SystemPreferencesService
    // For now, assume not in reduce motion or battery saver mode
    const reduceMotion = false;
    const batterySaver = false;

    // TODO(Phase 3): Disable flags that respect these preferences
    for (final config in _flagConfigs.values) {
      if (config.respectReduceMotion && reduceMotion) {
        _currentValues[config.flag] = false;
      }
      if (config.respectBatterySaver && batterySaver) {
        _currentValues[config.flag] = false;
      }
    }
  }

  /// Set up listeners for system preference changes
  static void _setupListeners() {
    // TODO(Phase 3): Listen to SystemPreferencesService changes
    // SystemPreferencesService.instance.onPreferencesChanged.listen((_) {
    //   _applySystemPreferences();
    // });
  }
}

// ============================================================================
// SUPPORTING SERVICES
// ============================================================================

/// Service for monitoring system preferences
class SystemPreferencesService {
  // SINGLETON: Private constructor
  SystemPreferencesService._();
  static final instance = SystemPreferencesService._();

  final _preferencesController = StreamController<void>.broadcast();

  /// GETTER: Whether Reduce Motion is enabled
  /// TODO(Phase 3): Access MediaQuery.disableAnimations from build context
  bool get reduceMotion {
    // Default to false, actual value needs BuildContext
    return false;
  }

  /// GETTER: Whether Battery Saver mode is active
  /// TODO(Phase 3): Implement battery state checking with battery_plus plugin
  bool get batterySaver {
    // Default to false
    return false;
  }

  /// STREAM: Emits when preferences change
  /// TODO(Phase 3): Combine MediaQuery changes + battery state streams
  Stream<void> get onPreferencesChanged => _preferencesController.stream;

  /// Update reduce motion preference (called from app root)
  /// TODO(Phase 3): Hook this up to WidgetsBindingObserver
  void updateReduceMotion(bool value) {
    _preferencesController.add(null);
  }

  /// Update battery saver preference
  /// TODO(Phase 3): Hook this up to battery state listener
  void updateBatterySaver(bool value) {
    _preferencesController.add(null);
  }

  /// Dispose the service
  void dispose() {
    _preferencesController.close();
  }
}
