/// Feature Flags Service
///
/// PURPOSE:
/// Centralized feature flag management for canary rollouts and A/B testing.
/// Uses Firebase Remote Config with local overrides for development.
///
/// CANARY ROLLOUT PATTERN:
/// 1. Deploy functions + rules to prod
/// 2. Set feature flag to enabled for specific roles/uids
/// 3. Monitor SLOs for 24-48h
/// 4. If clean, enable for all users
/// 5. If issues, disable flag (instant rollback, no redeployment)
///
/// FLAGS:
/// - timeclockEnabled: Timeclock screens visible (MVP canary gate)
/// - adminReviewEnabled: Admin Review exceptions screen
/// - invoiceFromTimeEnabled: Create invoice from time button
/// - testingAllowlist: List of UIDs for early access
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';

/// Feature flag configuration
class FeatureFlags {
  final bool timeclockEnabled;
  final bool adminReviewEnabled;
  final bool invoiceFromTimeEnabled;
  final List<String> testingAllowlist;

  FeatureFlags({
    required this.timeclockEnabled,
    required this.adminReviewEnabled,
    required this.invoiceFromTimeEnabled,
    required this.testingAllowlist,
  });

  /// Default values (conservative - all disabled)
  factory FeatureFlags.defaults() {
    return FeatureFlags(
      timeclockEnabled: false,
      adminReviewEnabled: false,
      invoiceFromTimeEnabled: false,
      testingAllowlist: [],
    );
  }

  /// Create from Remote Config
  factory FeatureFlags.fromRemoteConfig(FirebaseRemoteConfig config) {
    return FeatureFlags(
      timeclockEnabled: config.getBool('timeclock_enabled'),
      adminReviewEnabled: config.getBool('admin_review_enabled'),
      invoiceFromTimeEnabled: config.getBool('invoice_from_time_enabled'),
      testingAllowlist: config
          .getString('testing_allowlist')
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
    );
  }

  /// Check if user has access to a feature
  bool hasAccess({
    required String featureName,
    required String? userId,
    required String? userRole,
  }) {
    // Admins always have access (for testing/support)
    if (userRole == 'admin') return true;

    // Check if user is in testing allowlist
    if (userId != null && testingAllowlist.contains(userId)) return true;

    // Check feature-specific flags
    switch (featureName) {
      case 'timeclock':
        return timeclockEnabled;
      case 'adminReview':
        return adminReviewEnabled;
      case 'invoiceFromTime':
        return invoiceFromTimeEnabled;
      default:
        return false;
    }
  }
}

/// Feature flags service
class FeatureFlagsService {
  final FirebaseRemoteConfig _remoteConfig;
  FeatureFlags _flags;

  FeatureFlagsService(this._remoteConfig) : _flags = FeatureFlags.defaults();

  /// Initialize Remote Config and fetch flags
  Future<void> initialize() async {
    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(
          minutes: 15,
        ), // Faster updates during canary
      ),
    );

    // Set defaults
    await _remoteConfig.setDefaults({
      'timeclock_enabled': false,
      'admin_review_enabled': false,
      'invoice_from_time_enabled': false,
      'testing_allowlist': '', // Comma-separated UIDs
    });

    // Fetch and activate
    try {
      await _remoteConfig.fetchAndActivate();
      _flags = FeatureFlags.fromRemoteConfig(_remoteConfig);
    } catch (e) {
      // Fallback to defaults on error
      _flags = FeatureFlags.defaults();
    }
  }

  /// Refresh flags (call periodically or on app resume)
  Future<void> refresh() async {
    try {
      await _remoteConfig.fetchAndActivate();
      _flags = FeatureFlags.fromRemoteConfig(_remoteConfig);
    } catch (e) {
      // Keep existing flags on error
    }
  }

  /// Get current flags
  FeatureFlags get flags => _flags;

  /// Check if user has access to feature
  bool hasAccess({
    required String featureName,
    required String? userId,
    required String? userRole,
  }) {
    return _flags.hasAccess(
      featureName: featureName,
      userId: userId,
      userRole: userRole,
    );
  }
}

/// Provider for feature flags service
final featureFlagsServiceProvider = Provider<FeatureFlagsService>((ref) {
  final remoteConfig = FirebaseRemoteConfig.instance;
  return FeatureFlagsService(remoteConfig);
});

/// Provider for current feature flags
final featureFlagsProvider = FutureProvider<FeatureFlags>((ref) async {
  final service = ref.watch(featureFlagsServiceProvider);
  await service.initialize();
  return service.flags;
});
