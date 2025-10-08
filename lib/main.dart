// lib/main.dart
import 'dart:async';
import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/firebase_options.dart';
import 'package:sierra_painting/infra/perf/performance_monitor.dart';
import 'package:sierra_painting/router.dart';

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
      if (!kIsWeb && !kFlutterTestMode) {
        FlutterError.onError = (FlutterErrorDetails details) {
          FlutterError.presentError(details);
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        };
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }
      runApp(const ProviderScope(child: SierraPaintingApp()));

      // Stop after first frame (app "visually ready")
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await bootTrace.stop();
      });
    },
    (error, stack) async {
      if (!kIsWeb && !kFlutterTestMode) {
        await FirebaseCrashlytics.instance.recordError(
          error,
          stack,
          fatal: true,
        );
      } else {
        // ignore: avoid_print
        debugPrint('Top-level error (web/test): $error\n$stack');
      }
    },
  );
}

Future<void> _initializeApp() async {
  debugPrint('Initializing app...'); // Debug print
  // Load env only when not running tests; ignore missing file quietly.
  if (!kFlutterTestMode) {
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

  // Firebase core
  debugPrint('Initializing Firebase...'); // Debug print
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Skip App Check & Performance during tests
  if (!kFlutterTestMode) {
    await _activateAppCheck();
  }
  if (!kIsWeb && kReleaseMode && !kFlutterTestMode) {
    await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
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

  // For Web:
  // 1) To use reCAPTCHA v3, set RECAPTCHA_V3_SITE_KEY in public.env.
  // 2) For local/dev, you can enable debug by setting
  //    window.FIREBASE_APPCHECK_DEBUG_TOKEN = true in index.html
  //    (you already saw the token printed in your console).
  final v3Key = dotenv.env['RECAPTCHA_V3_SITE_KEY'];

  try {
    if (kIsWeb && v3Key != null && v3Key.isNotEmpty) {
      // Newer API (firebase_app_check >= 0.3): ReCaptchaV3Provider
      try {
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider(v3Key),
          androidProvider: AndroidProvider.debug, // or playIntegrity in prod
          appleProvider:
              AppleProvider.debug, // or appAttest/deviceCheck in prod
        );
      } catch (_) {
        // Back-compat API (older plugin versions use webRecaptchaSiteKey)
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider(v3Key),
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        );
      }
      // ignore: avoid_print
      debugPrint(
        'App Check: activation succeeded on web (v3 site key detected).',
      );
    } else {
      // Mobile or no site key on web — still activate (debug providers ok for dev)
      await FirebaseAppCheck.instance.activate(
        androidProvider: kReleaseMode
            ? AndroidProvider.playIntegrity
            : AndroidProvider.debug,
        appleProvider: kReleaseMode
            ? AppleProvider.appAttest
            : AppleProvider.debug,
      );
      // ignore: avoid_print
      debugPrint('App Check: activation succeeded (mobile or debug).');
    }
  } catch (e) {
    // ignore: avoid_print
    debugPrint('App Check: activation failed — $e');
  }
}

class SierraPaintingApp extends StatelessWidget {
  const SierraPaintingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sierra Painting',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // keep your text theme or customize as needed
        textTheme: ThemeData.light().textTheme,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        textTheme: ThemeData.dark().textTheme,
        useMaterial3: true,
      ),
      // 👇 Key fix: give the app a starting route and a route generator.
      initialRoute: '/', // Updated to align with router configuration
      onGenerateRoute: onGenerateRoute,
    );
  }
}

// Confirm Crashlytics & AppCheck gating for web/tests vs. real devices.
