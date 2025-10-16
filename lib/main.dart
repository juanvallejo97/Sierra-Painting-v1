// lib/main.dart
import 'dart:async';
import 'dart:ui';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sierra_painting/core/debug/provider_logger.dart';
import 'package:sierra_painting/core/env/build_flags.dart';
import 'package:sierra_painting/core/providers.dart';
import 'package:sierra_painting/core/offline/sync_service.dart';
import 'package:sierra_painting/core/services/device_info_service.dart';
import 'package:sierra_painting/core/services/location_service.dart';
import 'package:sierra_painting/core/services/location_service_impl.dart';
import 'package:sierra_painting/features/jobs/data/job_context_impl.dart';
import 'package:sierra_painting/features/jobs/domain/job_context.dart';
import 'package:sierra_painting/firebase_options.dart';
import 'package:sierra_painting/infra/perf/performance_monitor.dart';
import 'package:sierra_painting/router.dart';
import 'package:sierra_painting/core/privacy/consent_manager.dart';
import 'package:sierra_painting/core/feature_flags/feature_flags.dart';
import 'package:sierra_painting/core/env/app_flavor.dart';

/// Test-mode flag (set by tests via --dart-define=FLUTTER_TEST=true)
const bool kFlutterTestMode = bool.fromEnvironment(
  'FLUTTER_TEST',
  defaultValue: false,
);

Future<void> main() async {
  // --- A2 Perf: app_boot trace (safe in tests) --------------------------
  final bootTrace = await PerformanceMonitor.instance.start('app_boot');

  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await _initializeApp();

      // Initialize device info and preferences for idempotency support
      final prefs = await SharedPreferences.getInstance();
      final deviceInfo = DeviceInfoPlugin();

      // Only set up Crashlytics error handlers when NOT in test mode
      if (!kIsWeb && !isUnderTest) {
        FlutterError.onError = (FlutterErrorDetails details) {
          FlutterError.presentError(details);
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        };
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }
      runApp(
        ProviderScope(
          observers: kDebugMode ? [ProviderLogger()] : const [],
          overrides: [
            // Override device info service for stable device IDs
            deviceInfoServiceProvider.overrideWithValue(
              DeviceInfoService(deviceInfo: deviceInfo, prefs: prefs),
            ),
            // Override location service with concrete implementation
            locationServiceProvider.overrideWith(
              (ref) => LocationServiceImpl(),
            ),
            // Override job context service with concrete implementation
            jobContextServiceProvider.overrideWith((ref) {
              final firestore = ref.watch(firestoreProvider);
              final locationService = ref.watch(locationServiceProvider);
              return JobContextServiceImpl(firestore, locationService);
            }),
          ],
          child: const SierraPaintingApp(),
        ),
      );

      // Stop after first frame (app "visually ready")
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await bootTrace.stop();
      });
    },
    (error, stack) async {
      if (!kIsWeb && !isUnderTest) {
        await FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          fatal: true,
        );
      } else {
        debugPrint('Top-level error (web/test): $error\n$stack');
      }
    },
  );
}

Future<void> _initializeApp() async {
  debugPrint('Initializing app...'); // Debug print

  // Initialize app flavor FIRST (determines environment)
  AppFlavor.initialize();
  debugPrint('App Flavor: ${AppFlavor.displayName} (${AppFlavor.firebaseProjectId})');

  // Load env only when not running tests; ignore missing file quietly.
  if (!isUnderTest) {
    final envFile = kIsWeb ? 'assets/config/public.env' : '.env';
    try {
      await dotenv.load(fileName: envFile);
      // Diagnostic (keys only, no values)
      final hasEnable = dotenv.env.containsKey('ENABLE_APP_CHECK');
      final hasV3 = dotenv.env.containsKey('RECAPTCHA_V3_SITE_KEY');
      final hasLegacy = dotenv.env.containsKey('RECAPTCHA_SITE_KEY');
      debugPrint(
        '_initializeApp: dotenv loaded ($envFile) — '
        'ENABLE_APP_CHECK=$hasEnable, V3_KEY=$hasV3, LEGACY_KEY=$hasLegacy',
      );
    } catch (e) {
      debugPrint('_initializeApp: dotenv failed to load ($envFile): $e');
    }
  }

  // Firebase core - skip entirely in test mode
  if (!isUnderTest) {
    debugPrint('Initializing Firebase...'); // Debug print
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Enable Firestore debug logging on web in debug builds
    if (kIsWeb && kDebugMode) {
      // FlutterFire prints verbose Firestore logs in debug builds automatically
      debugPrint('[Admin] Firestore debug enabled (web)');
    }

    // App Check & Performance
    await _activateAppCheck();
    if (!kIsWeb && kReleaseMode) {
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
    }

    // Phase 3A: Initialize Consent Manager (GDPR/CCPA compliance)
    debugPrint('Initializing ConsentManager...');
    try {
      await ConsentManager.instance.initialize();
      debugPrint('ConsentManager initialized successfully.');
    } catch (e) {
      debugPrint('ConsentManager initialization failed: $e');
    }

    // Phase 3B: Initialize Feature Flags (Remote Config + System Preferences)
    debugPrint('Initializing FeatureFlags...');
    try {
      await FeatureFlags.initialize();
      debugPrint('FeatureFlags initialized successfully.');
    } catch (e) {
      debugPrint('FeatureFlags initialization failed: $e');
    }
  } else {
    debugPrint('Skipping Firebase initialization in test mode.');
  }

  // K2: Initialize offline sync service (Hive + connectivity monitoring)
  if (!isUnderTest) {
    debugPrint('Initializing SyncService...'); // Debug print
    try {
      await SyncService.initialize();
      debugPrint('SyncService initialized successfully.');
    } catch (e) {
      debugPrint('SyncService initialization failed: $e');
    }
  }

  debugPrint('App initialization complete.'); // Debug print
}

Future<void> _activateAppCheck() async {
  final enableAppCheck =
      (dotenv.env['ENABLE_APP_CHECK'] ?? 'true').toLowerCase() == 'true';

  if (!enableAppCheck) {
    // ignore: avoid_print
    debugPrint('App Check: disabled via env');
    return;
  }

  // TEMPORARY DEBUG MODE:
  // Testing with debug provider to isolate whether issue is:
  // 1) reCAPTCHA integration problem, OR
  // 2) Broader App Check backend issue
  //
  // Debug mode is enabled in index.html via:
  //   self.FIREBASE_APPCHECK_DEBUG_TOKEN = true;
  //
  // Steps to test:
  // 1) Deploy this code
  // 2) Load https://sierra-painting-staging.web.app
  // 3) Open browser console - will see: "Firebase App Check debug token: <TOKEN>"
  // 4) Copy the token
  // 5) Register at: console.firebase.google.com/project/sierra-painting-staging/appcheck
  // 6) Refresh page - debug provider will be used instead of reCAPTCHA
  //
  // If admin dashboard works: Problem is reCAPTCHA integration
  // If admin dashboard still fails: Problem is App Check backend
  final v3Key = dotenv.env['RECAPTCHA_V3_SITE_KEY'];

  try {
    // Enable token auto-refresh BEFORE activation
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

    if (kIsWeb && v3Key != null && v3Key.isNotEmpty) {
      // Web: ReCaptchaV3Provider, but debug mode in index.html will override it
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(v3Key),
        providerAndroid: kReleaseMode
            ? const AndroidPlayIntegrityProvider()
            : const AndroidDebugProvider(),
        providerApple: kReleaseMode
            ? const AppleAppAttestProvider()
            : const AppleDebugProvider(),
      );
      // ignore: avoid_print
      debugPrint(
        'App Check: activation succeeded (debug mode enabled in index.html).',
      );
    } else {
      // Mobile or no site key on web — still activate (debug providers ok for dev)
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kReleaseMode
            ? const AndroidPlayIntegrityProvider()
            : const AndroidDebugProvider(),
        providerApple: kReleaseMode
            ? const AppleAppAttestProvider()
            : const AppleDebugProvider(),
      );
      // ignore: avoid_print
      debugPrint('App Check: activation succeeded (mobile or debug).');
    }
  } catch (e) {
    // ignore: avoid_print
    debugPrint('App Check: activation failed — $e');
  }
}

class SierraPaintingApp extends ConsumerWidget {
  const SierraPaintingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize token refresh listener (automatically starts/stops based on auth state)
    ref.watch(tokenRefreshListenerProvider);

    return MaterialApp(
      title: 'Sierra Painting',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          labelStyle: TextStyle(color: Colors.grey[700]),
          hintStyle: TextStyle(color: Colors.grey[500]),
        ),
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: Colors.black87,
          displayColor: Colors.black87,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey[800],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      // 👇 Key fix: give the app a starting route and a route generator.
      initialRoute: '/', // Updated to align with router configuration
      onGenerateRoute: onGenerateRoute,
    );
  }
}

// Confirm Crashlytics & AppCheck gating for web/tests vs. real devices.
