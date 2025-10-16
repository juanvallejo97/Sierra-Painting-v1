/// Application Flavor Configuration
///
/// PURPOSE:
/// - Separate staging and production environments
/// - Different Firebase projects per flavor
/// - Environment-specific configuration
/// - Feature flag targeting by environment
///
/// USAGE:
/// - Flavor is set at app launch via --dart-define
/// - Access via AppFlavor.current
/// - Use for environment-specific logic

enum Flavor {
  staging,
  production,
}

class AppFlavor {
  static Flavor _currentFlavor = Flavor.staging; // Default to staging

  /// Get current flavor
  static Flavor get current => _currentFlavor;

  /// Check if running in staging
  static bool get isStaging => _currentFlavor == Flavor.staging;

  /// Check if running in production
  static bool get isProduction => _currentFlavor == Flavor.production;

  /// Initialize flavor from environment or dart-define
  static void initialize() {
    const flavorString = String.fromEnvironment(
      'FLAVOR',
      defaultValue: 'staging',
    );

    switch (flavorString.toLowerCase()) {
      case 'production':
      case 'prod':
        _currentFlavor = Flavor.production;
        break;
      case 'staging':
      case 'stage':
      case 'stg':
      default:
        _currentFlavor = Flavor.staging;
        break;
    }

    print('🔧 AppFlavor initialized: $_currentFlavor');
  }

  /// Get Firebase project ID for current flavor
  static String get firebaseProjectId {
    switch (_currentFlavor) {
      case Flavor.production:
        return 'sierra-painting';
      case Flavor.staging:
        return 'sierra-painting-staging';
    }
  }

  /// Get environment name for display
  static String get displayName {
    switch (_currentFlavor) {
      case Flavor.production:
        return 'Production';
      case Flavor.staging:
        return 'Staging';
    }
  }

  /// Get environment display color
  static int get displayColor {
    switch (_currentFlavor) {
      case Flavor.production:
        return 0xFFE53935; // Red for production (be careful!)
      case Flavor.staging:
        return 0xFFFFA726; // Orange for staging
    }
  }

  /// Get API endpoint base URL (if using custom backend)
  static String get apiBaseUrl {
    switch (_currentFlavor) {
      case Flavor.production:
        return 'https://api.sierra-painting.com';
      case Flavor.staging:
        return 'https://api-staging.sierra-painting.com';
    }
  }

  /// Should enable verbose logging
  static bool get enableVerboseLogging {
    return _currentFlavor == Flavor.staging;
  }

  /// Should enable debug features
  static bool get enableDebugFeatures {
    return _currentFlavor == Flavor.staging;
  }

  /// Remote Config fetch timeout
  static Duration get remoteConfigTimeout {
    switch (_currentFlavor) {
      case Flavor.production:
        return const Duration(seconds: 10);
      case Flavor.staging:
        return const Duration(seconds: 5); // Faster for testing
    }
  }

  /// Remote Config minimum fetch interval
  static Duration get remoteConfigMinFetchInterval {
    switch (_currentFlavor) {
      case Flavor.production:
        return const Duration(hours: 1);
      case Flavor.staging:
        return const Duration(minutes: 5); // More frequent for testing
    }
  }
}
