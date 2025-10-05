/// Core Providers Barrel File
///
/// PURPOSE:
/// Centralized export for all core Riverpod providers.
/// Makes it easier to import commonly used providers throughout the app.
///
/// EXPORTS:
/// - Auth providers (Firebase Auth state)
/// - Firestore providers (database collections)
/// - Haptic providers (tactile feedback service)
/// - Service providers (feature flags, offline, queue)
///
/// USAGE:
/// ```dart
/// import 'package:sierra_painting/core/providers.dart';
///
/// final user = ref.watch(currentUserProvider);
/// final haptics = ref.watch(hapticServiceProvider);
/// ```
library core_providers;

// Auth providers
export 'package:sierra_painting/core/providers/auth_provider.dart';

// Firestore providers
export 'package:sierra_painting/core/providers/firestore_provider.dart';

// Haptic service providers (from haptic_service.dart)
export 'package:sierra_painting/core/services/haptic_service.dart'
    show hapticEnabledProvider, hapticServiceProvider, HapticService;

// Feature flag service providers
export 'package:sierra_painting/core/services/feature_flag_service.dart'
    show
        featureFlagServiceProvider,
        clockInEnabledProvider,
        clockOutEnabledProvider,
        jobsTodayEnabledProvider,
        createQuoteEnabledProvider,
        markPaidEnabledProvider,
        stripeCheckoutEnabledProvider,
        offlineModeEnabledProvider,
        gpsTrackingEnabledProvider;

// Queue service provider
export 'package:sierra_painting/core/services/queue_service.dart'
    show queueServiceProvider, queueBoxProvider, QueueService;
