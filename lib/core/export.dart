/// PHASE 2: Core Systems - Barrel Export
///
/// PURPOSE:
/// - Single import point for all core systems
/// - Simplifies imports across the app
/// - Ensures consistent access to core functionality

library core_export;

// Feature Flags
export 'feature_flags/feature_flags.dart';

// Telemetry & Monitoring
export 'telemetry/ux_telemetry.dart';

// Offline Queue
export 'offline/offline_queue_v2.dart';
