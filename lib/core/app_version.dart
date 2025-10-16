// Application version information
//
// This file contains the app version string extracted from pubspec.yaml.
// It's used for cache debugging and version verification across deployments.
//
// Version format: MAJOR.MINOR.PATCH+BUILD
// Example: 0.0.13+13
//
// IMPORTANT: This should be kept in sync with pubspec.yaml version field.
// Consider using code generation (e.g., build_runner) for automatic sync.

const String kAppVersion = '0.0.14';
const String kAppBuildNumber = '14';
const String kAppVersionFull = '$kAppVersion+$kAppBuildNumber';
