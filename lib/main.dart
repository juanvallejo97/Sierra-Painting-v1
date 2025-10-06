// lib/main.dart
import 'dart:async';
import 'dart:ui';
// Used to expose a browser-visible readiness flag when running on web.
// This helps detect early runtime failures that otherwise cause a black screen.
import 'dart:js' as js;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sierra_painting/app/app.dart';
import 'package:sierra_painting/core/services/feature_flag_service.dart';
import 'package:sierra_painting/core/services/offline_service.dart';
import 'package:sierra_painting/firebase_options.dart';

// Re-export app widget for tests that import main.dart
export 'package:sierra_painting/app/app.dart' show SierraPaintingApp;

Future<void> _initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env variables
  await dotenv.load(fileName: ".env");

  // Start Firebase Performance trace early
  final perf = FirebasePerformance.instance;
  final Trace startupTrace = perf.newTrace('app_startup');
  await startupTrace.start();

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Setup Crashlytics
    final crashlyticsEnabled =
        dotenv.env['CRASHLYTICS_ENABLED']?.toLowerCase() == 'true';
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
      kReleaseMode || crashlyticsEnabled,
    );

    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    // Enable Performance Monitoring
    await perf.setPerformanceCollectionEnabled(kReleaseMode);

    // Expose readiness signal earlier so the page can detect successful Firebase
    // initialization even if later steps (e.g., App Check) fail.
    if (kIsWeb) {
      try {
        js.context['flutterReady'] = true;
      } catch (_) {}
    }

    // Enable App Check (Play Integrity / App Attest / reCAPTCHA)
    final appCheckEnabled =
        dotenv.env['ENABLE_APP_CHECK']?.toLowerCase() == 'true';

    if (appCheckEnabled || kReleaseMode) {
      if (kIsWeb) {
        final siteKey = dotenv.env['RECAPTCHA_V3_SITE_KEY'] ?? '';
        if (siteKey.isNotEmpty) {
          await FirebaseAppCheck.instance.activate(
            providerWeb: ReCaptchaV3Provider(siteKey),
          );
        } else {
          // Skip App Check activation on web if no site key is present. In
          // production you should provide a valid RECAPTCHA_V3_SITE_KEY.
          // Skipping avoids runtime failures that block app startup.
          // ignore: avoid_print
          print('Skipping App Check activation on web: RECAPTCHA_V3_SITE_KEY not set');
        }
      } else {
        await FirebaseAppCheck.instance.activate(
          androidProvider: kReleaseMode
              ? AndroidProvider.playIntegrity
              : AndroidProvider.debug,
          appleProvider: kReleaseMode
              ? AppleProvider.appAttest
              : AppleProvider.debug,
        );
      }
    }

    // Initialize Offline Storage + Feature Flags
    await OfflineService.initialize();
    await FeatureFlagService.initialize();

    // On the web, expose a small readiness flag so the page can detect if the
    // Flutter app initialized correctly. This is helpful when debugging blank
    // screens caused by runtime initialization failures.
    if (kIsWeb) {
      try {
        js.context['flutterReady'] = true;
      } catch (_) {}
    }

    // Stop startup trace after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await startupTrace.stop();
    });
  } catch (e, st) {
    try {
      await FirebaseCrashlytics.instance.recordError(e, st, fatal: true);
    } catch (_) {}
    rethrow;
  }
}

void main() {
  runZonedGuarded(
    () async {
      await _initializeApp();
      runApp(const ProviderScope(child: SierraPaintingApp()));
    },
    (error, stack) async {
      try {
        await FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          fatal: true,
        );
      } catch (_) {}
    },
  );
}
