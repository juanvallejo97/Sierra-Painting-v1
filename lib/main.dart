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

  // Diagnostic: mark that initialization started (helps debug blank-screen cases)
  try {
    js.context.callMethod('console.log', ['_initializeApp: start']);
  } catch (_) {}

  // Choose env file: prefer web-safe asset on web, otherwise .env. Fallback gracefully.
  final String envFile = kIsWeb ? 'assets/config/public.env' : '.env';

  // Load .env variables (don't crash if missing on web)
  try {
    await dotenv.load(fileName: envFile);
    try { js.context.callMethod('console.log', ['_initializeApp: dotenv loaded (' + envFile + ')']); } catch (_) {}
    // Quick diagnostics (no secret values):
    try {
      final hasEnable = dotenv.env.containsKey('ENABLE_APP_CHECK');
      final hasV3 = dotenv.env.containsKey('RECAPTCHA_V3_SITE_KEY');
      final hasLegacy = dotenv.env.containsKey('RECAPTCHA_SITE_KEY');
      js.context.callMethod('console.log', [
        '_initializeApp: env flags -> ENABLE_APP_CHECK=' + hasEnable.toString() + ', V3_KEY=' + hasV3.toString() + ', LEGACY_KEY=' + hasLegacy.toString()
      ]);
    } catch (_) {}
  } catch (e) {
    // Fallback attempts for web: try old path and .env
    if (kIsWeb) {
      try {
        await dotenv.load(fileName: '.env.public');
        try { js.context.callMethod('console.warn', ['_initializeApp: public.env missing; loaded .env.public fallback']); } catch (_) {}
      } catch (_) {
        try {
          await dotenv.load(fileName: '.env');
          try { js.context.callMethod('console.warn', ['_initializeApp: public env missing; loaded .env fallback']); } catch (_) {}
        } catch (e2) {
          // ignore: avoid_print
          print('dotenv load failed: $e2');
          try { js.context.callMethod('console.error', ['_initializeApp: dotenv load failed: ' + e2.toString()]); } catch (_) {}
        }
      }
    } else {
      // ignore: avoid_print
      print('dotenv load failed: $e');
      try { js.context.callMethod('console.error', ['_initializeApp: dotenv load failed: ' + e.toString()]); } catch (_) {}
    }
  }

  // Begin guarded initialization
  try {
    // Initialize Firebase
    try { js.context.callMethod('console.log', ['_initializeApp: calling Firebase.initializeApp']); } catch (_) {}
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    try { js.context.callMethod('console.log', ['_initializeApp: Firebase.initializeApp succeeded']); } catch (_) {}

    // Setup Crashlytics
    final crashlyticsEnabled =
        dotenv.env['CRASHLYTICS_ENABLED']?.toLowerCase() == 'true';
    if (!kIsWeb) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        kReleaseMode || crashlyticsEnabled,
      );

      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    // Expose readiness signal earlier so the page can detect successful Firebase
    // initialization even if later steps (e.g., App Check) fail.
    if (kIsWeb) {
      try { js.context['flutterReady'] = true; } catch (_) {}
    }

    // Start Firebase Performance trace after Firebase has been initialized
    Trace? startupTrace;
    try {
      final perf = FirebasePerformance.instance;
      startupTrace = perf.newTrace('app_startup');
      await startupTrace.start();
      // Enable Performance Monitoring in release only
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(kReleaseMode);
    } catch (e) {
      // ignore: avoid_print
      print('Firebase Performance init failed: $e');
      try { js.context.callMethod('console.error', ['_initializeApp: perf init failed: ' + e.toString()]); } catch (_) {}
    }

    // Enable App Check (Play Integrity / App Attest / reCAPTCHA)
    final appCheckEnabled =
        dotenv.env['ENABLE_APP_CHECK']?.toLowerCase() == 'true';

    if (appCheckEnabled || kReleaseMode) {
      if (kIsWeb) {
        // Load site key only from .env to avoid compile-time embedding
        String runtimeSiteKey = (dotenv.env['RECAPTCHA_V3_SITE_KEY'] ?? dotenv.env['RECAPTCHA_SITE_KEY'] ?? '');

        String sanitizeKey(String? k) {
          k = (k ?? '').trim();
          // Remove common prefixes like `recaptcha:` and surrounding quotes
          k = k.replaceAll(RegExp(r'^recaptcha:\s*', caseSensitive: false), '');
          // Remove surrounding quotes (single or double)
          k = k.replaceAll(RegExp(r'''['"]'''), '');
          // Extract token-looking substring (alphanumeric, - or _)
          final m = RegExp(r'([A-Za-z0-9_-]{20,})').firstMatch(k);
          if (m != null) return m.group(1)!;
          return k;
        }

        runtimeSiteKey = sanitizeKey(runtimeSiteKey);
        try { js.context.callMethod('console.log', ['App Check: runtimeSiteKey empty? ' + (runtimeSiteKey.isEmpty).toString()]); } catch (_) {}

        if (runtimeSiteKey.isNotEmpty) {
          try { js.context.callMethod('console.log', ['App Check: attempting activation on web. runtimeSiteKey present: ${runtimeSiteKey.isNotEmpty}']); } catch (_) {}
          try {
            await FirebaseAppCheck.instance.activate(
              webProvider: ReCaptchaV3Provider(runtimeSiteKey),
            );
            try { js.context.callMethod('console.log', ['App Check: activation succeeded on web']); } catch (_) {}
          } catch (e) {
            // Don't let App Check activation crash the app; log and continue.
            // ignore: avoid_print
            print('App Check activation failed: $e');
            try { js.context.callMethod('console.error', ['App Check activation failed: ' + e.toString()]); } catch (_) {}
          }
        } else {
          // No site key available; skip activation on web to avoid runtime
          // failures during staging/dev.
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
      try { js.context['flutterReady'] = true; } catch (_) {}
    }

    // Stop startup trace after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try { await startupTrace?.stop(); } catch (_) {}
    });
  } catch (e, st) {
    try {
      await FirebaseCrashlytics.instance.recordError(e, st, fatal: true);
    } catch (_) {}
    try { js.context.callMethod('console.error', ['_initializeApp failed: ' + e.toString()]); } catch (_) {}
    // Do not rethrow; allow page overlay/diagnostics to continue.
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
