import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/app/app.dart';
import 'package:sierra_painting/firebase_options.dart';
import 'package:sierra_painting/core/services/feature_flag_service.dart';
import 'package:sierra_painting/core/services/offline_service.dart';

/// Sierra Painting Flutter Application
///
/// PURPOSE:
/// Entry point for the Sierra Painting mobile application.
/// Initializes Firebase, offline storage, and feature flags before app launch.
///
/// ARCHITECTURE:
/// - Uses Riverpod for state management and dependency injection
/// - Implements offline-first architecture with queue synchronization
/// - Follows Material Design 3 guidelines
///
/// INITIALIZATION ORDER:
/// 1. Firebase (auth, firestore, functions, performance, crashlytics)
/// 2. Firebase App Check (security)
/// 3. Offline storage (Hive)
/// 4. Feature flags
/// 5. App widget tree
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase App Check
  // Use dart-define flag to enable/disable: --dart-define=ENABLE_APP_CHECK=true
  const enableAppCheck = String.fromEnvironment('ENABLE_APP_CHECK', defaultValue: 'false');
  final shouldEnableAppCheck = enableAppCheck == 'true' || kReleaseMode;
  
  if (shouldEnableAppCheck) {
    await FirebaseAppCheck.instance.activate(
      // Android: Play Integrity API for production
      androidProvider: kDebugMode 
        ? AndroidProvider.debug 
        : AndroidProvider.playIntegrity,
      // iOS: App Attest for iOS 14+ (falls back to DeviceCheck for older versions)
      appleProvider: kDebugMode 
        ? AppleProvider.debug 
        : AppleProvider.appAttest,
      // Web: ReCaptcha v3 (placeholder - replace with actual site key)
      webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
    );
  }

  // Initialize Firebase Performance Monitoring
  final performance = FirebasePerformance.instance;
  
  // Enable performance monitoring in release mode only
  if (kReleaseMode) {
    await performance.setPerformanceCollectionEnabled(true);
  }

  // Initialize Firebase Crashlytics
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  
  // Pass all uncaught asynchronous errors to Crashlytics
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Initialize offline storage
  await OfflineService.initialize();

  // Initialize feature flags
  await FeatureFlagService.initialize();

  // Track app startup
  final trace = performance.newTrace('app_startup');
  await trace.start();

  runApp(
    const ProviderScope(
      child: SierraPaintingApp(),
    ),
  );

  // Stop startup trace after first frame
  WidgetsBinding.instance.addPostFrameCallback((_) {
    trace.stop();
  });
}
