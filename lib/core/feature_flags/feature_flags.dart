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
import 'package:battery_plus/battery_plus.dart';
import 'package:sierra_painting/core/env/app_flavor.dart';

// ============================================================================
// DATA STRUCTURES
// ============================================================================

/// Enum of all available feature flags
enum FeatureFlag {
  globalPanic,      // CRITICAL: Kills ALL features instantly (emergency)
  shimmerLoaders,
  lottieAnimations,
  hapticFeedback,
  offlineQueueV2,
  auditTrail,
  smartForms,
  kpiDrillDown,
  conflictDetection,
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
  /// 3. Initialize system preferences monitoring
  /// 4. Apply system preferences
  /// 5. Set up listeners for system changes
  static Future<void> initialize() async {
    if (_initialized) return;

    // Load all flag configurations with default values
    _loadFlagConfigs();

    try {
      // Fetch flag values from Firebase Remote Config
      await _syncWithRemoteConfig();
    } catch (e) {
      // TODO(Phase 3): Log error to Crashlytics
      debugPrint('FeatureFlags: Failed to sync remote config: $e');
    }

    // Initialize system preferences monitoring (battery, reduce motion)
    try {
      await SystemPreferencesService.instance.initialize();
    } catch (e) {
      debugPrint('FeatureFlags: Failed to initialize system preferences: $e');
    }

    // Apply system preferences (Reduce Motion, Battery Saver)
    _applySystemPreferences();

    // Set up listeners for preference changes
    _setupListeners();

    _initialized = true;
    debugPrint('FeatureFlags: Initialization complete');
  }

  /// SYNC: Check if a feature is enabled
  /// Returns: true if enabled, false otherwise
  static bool isEnabled(FeatureFlag flag) {
    // Return default if not initialized
    if (!_initialized) {
      return _flagConfigs[flag]?.defaultValue ?? false;
    }

    // CRITICAL: Check global panic flag first (kills all features)
    if (flag != FeatureFlag.globalPanic) {
      final panicMode = _currentValues[FeatureFlag.globalPanic] ?? false;
      if (panicMode) {
        debugPrint('FeatureFlags: PANIC MODE ACTIVE - all features disabled');
        return false;
      }
    }

    // TODO(Phase 3): Check if flag is overridden in debug mode
    // Return current value after remote config + system prefs applied
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
    // CRITICAL: Global panic flag (default OFF)
    _flagConfigs[FeatureFlag.globalPanic] = const FlagConfig(
      flag: FeatureFlag.globalPanic,
      defaultValue: false,
      remoteConfigKey: 'global_panic',
      respectReduceMotion: false,
      respectBatterySaver: false,
      description: 'EMERGENCY: Disable all features instantly',
    );

    // TODO(Phase 3): Load all flag configurations
    _flagConfigs[FeatureFlag.shimmerLoaders] = const FlagConfig(
      flag: FeatureFlag.shimmerLoaders,
      defaultValue: false,
      remoteConfigKey: 'shimmer_loaders_enabled',
      respectReduceMotion: true,
      respectBatterySaver: true,
      description: 'Enable shimmer loading animations',
    );

    _flagConfigs[FeatureFlag.lottieAnimations] = const FlagConfig(
      flag: FeatureFlag.lottieAnimations,
      defaultValue: false,
      remoteConfigKey: 'lottie_animations_enabled',
      respectReduceMotion: true,
      respectBatterySaver: false,
      description: 'Enable Lottie animations',
    );

    _flagConfigs[FeatureFlag.hapticFeedback] = const FlagConfig(
      flag: FeatureFlag.hapticFeedback,
      defaultValue: false,
      remoteConfigKey: 'haptic_feedback_enabled',
      respectReduceMotion: false,
      respectBatterySaver: true,
      description: 'Enable haptic feedback',
    );

    _flagConfigs[FeatureFlag.offlineQueueV2] = const FlagConfig(
      flag: FeatureFlag.offlineQueueV2,
      defaultValue: false,
      remoteConfigKey: 'offline_queue_v2_enabled',
      respectReduceMotion: false,
      respectBatterySaver: false,
      description: 'Enable enhanced offline queue',
    );

    _flagConfigs[FeatureFlag.auditTrail] = const FlagConfig(
      flag: FeatureFlag.auditTrail,
      defaultValue: false,
      remoteConfigKey: 'audit_trail_enabled',
      respectReduceMotion: false,
      respectBatterySaver: false,
      description: 'Enable audit trail logging',
    );

    _flagConfigs[FeatureFlag.smartForms] = const FlagConfig(
      flag: FeatureFlag.smartForms,
      defaultValue: false,
      remoteConfigKey: 'smart_forms_enabled',
      respectReduceMotion: false,
      respectBatterySaver: false,
      description: 'Enable smart forms with autosave',
    );

    _flagConfigs[FeatureFlag.kpiDrillDown] = const FlagConfig(
      flag: FeatureFlag.kpiDrillDown,
      defaultValue: false,
      remoteConfigKey: 'kpi_drill_down_enabled',
      respectReduceMotion: false,
      respectBatterySaver: false,
      description: 'Enable KPI drill-down navigation',
    );

    _flagConfigs[FeatureFlag.conflictDetection] = const FlagConfig(
      flag: FeatureFlag.conflictDetection,
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
      final remoteConfig = FirebaseRemoteConfig.instance;

      // Configure Remote Config settings (flavor-specific)
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: AppFlavor.remoteConfigTimeout,
        minimumFetchInterval: AppFlavor.remoteConfigMinFetchInterval,
      ));

      // Set default values for all flags
      final defaults = <String, dynamic>{};
      for (final config in _flagConfigs.values) {
        defaults[config.remoteConfigKey] = config.defaultValue;
      }
      await remoteConfig.setDefaults(defaults);

      // Fetch and activate remote values
      final activated = await remoteConfig.fetchAndActivate();
      debugPrint('FeatureFlags: Remote Config ${activated ? "updated" : "unchanged"}');

      // Update current values from remote config
      for (final config in _flagConfigs.values) {
        try {
          final remoteValue = remoteConfig.getBool(config.remoteConfigKey);
          _currentValues[config.flag] = remoteValue;
          debugPrint('FeatureFlags: ${config.flag.name} = $remoteValue (remote)');
        } catch (e) {
          // Use default if remote value not available
          _currentValues[config.flag] = config.defaultValue;
          debugPrint('FeatureFlags: ${config.flag.name} = ${config.defaultValue} (default)');
        }
      }
    } catch (e) {
      debugPrint('FeatureFlags: Failed to sync Remote Config - $e');
      // Use defaults for all flags
      for (final config in _flagConfigs.values) {
        _currentValues[config.flag] = config.defaultValue;
      }
    }
  }

  /// Apply system preferences (Reduce Motion, Battery Saver)
  static void _applySystemPreferences() {
    // Get system preferences
    final reduceMotion = SystemPreferencesService.instance.reduceMotion;
    final batterySaver = SystemPreferencesService.instance.batterySaver;

    debugPrint('FeatureFlags: System prefs - reduceMotion: $reduceMotion, batterySaver: $batterySaver');

    // Disable flags that respect these preferences
    for (final config in _flagConfigs.values) {
      final currentValue = _currentValues[config.flag] ?? config.defaultValue;

      // Only disable if flag was enabled
      if (currentValue) {
        if (config.respectReduceMotion && reduceMotion) {
          _currentValues[config.flag] = false;
          debugPrint('FeatureFlags: Disabled ${config.flag.name} (reduce motion)');
        }
        if (config.respectBatterySaver && batterySaver) {
          _currentValues[config.flag] = false;
          debugPrint('FeatureFlags: Disabled ${config.flag.name} (battery saver)');
        }
      }
    }
  }

  /// Set up listeners for system preference changes
  static void _setupListeners() {
    // Listen to system preferences changes
    SystemPreferencesService.instance.onPreferencesChanged.listen((_) {
      debugPrint('FeatureFlags: System preferences changed, re-applying...');
      _applySystemPreferences();
    });
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
  final _battery = Battery();

  // STATE: Current preference values
  bool _reduceMotion = false;
  bool _batterySaver = false;
  bool _initialized = false;

  StreamSubscription<BatteryState>? _batterySubscription;

  /// Initialize the service and start listening
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Check initial battery state
      final batteryState = await _battery.batteryState;
      _batterySaver = batteryState == BatteryState.charging ? false : await _isLowBattery();

      // Listen to battery state changes
      _batterySubscription = _battery.onBatteryStateChanged.listen((state) async {
        final wasInSaverMode = _batterySaver;

        // Battery saver is active if:
        // 1. Battery level is low (<20%) and not charging
        // 2. Or explicitly in power save mode (platform-specific)
        _batterySaver = state == BatteryState.charging ? false : await _isLowBattery();

        // Notify listeners if state changed
        if (wasInSaverMode != _batterySaver) {
          debugPrint('SystemPreferences: Battery saver mode: $_batterySaver');
          _preferencesController.add(null);
        }
      });

      debugPrint('SystemPreferences: Initialized (batterySaver: $_batterySaver)');
      _initialized = true;
    } catch (e) {
      debugPrint('SystemPreferences: Failed to initialize battery monitoring - $e');
      _batterySaver = false;
    }
  }

  /// Check if battery is low
  Future<bool> _isLowBattery() async {
    try {
      final level = await _battery.batteryLevel;
      return level < 20; // Consider <20% as low battery
    } catch (e) {
      debugPrint('SystemPreferences: Failed to get battery level - $e');
      return false;
    }
  }

  /// GETTER: Whether Reduce Motion is enabled
  /// This value must be updated from the app root using updateReduceMotion()
  /// Call from WidgetsBindingObserver.didChangeAccessibilityFeatures()
  bool get reduceMotion => _reduceMotion;

  /// GETTER: Whether Battery Saver mode is active
  /// Automatically detected via battery_plus plugin
  bool get batterySaver => _batterySaver;

  /// STREAM: Emits when preferences change
  Stream<void> get onPreferencesChanged => _preferencesController.stream;

  /// Update reduce motion preference (called from app root)
  /// USAGE: Call this from your app's WidgetsBindingObserver:
  ///
  /// ```dart
  /// @override
  /// void didChangeAccessibilityFeatures() {
  ///   final reduceMotion = WidgetsBinding.instance.window.accessibilityFeatures.disableAnimations;
  ///   SystemPreferencesService.instance.updateReduceMotion(reduceMotion);
  /// }
  /// ```
  void updateReduceMotion(bool value) {
    if (_reduceMotion != value) {
      _reduceMotion = value;
      debugPrint('SystemPreferences: Reduce motion: $_reduceMotion');
      _preferencesController.add(null);
    }
  }

  /// Dispose the service
  void dispose() {
    _batterySubscription?.cancel();
    _preferencesController.close();
  }
}
