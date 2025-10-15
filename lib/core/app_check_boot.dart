import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Call from your main() initialization after Firebase.initializeApp().
Future<void> activateAppCheck() async {
  final enforce =
      (dotenv.env['APP_CHECK_ENFORCE'] ?? 'false').toLowerCase() == 'true';
  final debugToken = dotenv.env['APP_CHECK_DEBUG_TOKEN'];
  final webKey = dotenv.env['RECAPTCHA_V3_KEY'];

  if (!enforce) {
    // Keep optional opt-out for tests or local dev.
    await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(false);
    return;
  }

  if (kIsWeb) {
    if (webKey == null || webKey.isEmpty) {
      throw StateError(
        'APP_CHECK_ENFORCE=true but RECAPTCHA_V3_KEY is missing.',
      );
    }
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaV3Provider(webKey),
    );
    return;
  }

  // Mobile/Desktop: use debug provider in non-release by default.
  final useDebug = kDebugMode || (debugToken != null && debugToken.isNotEmpty);
  if (useDebug) {
    if (debugToken != null && debugToken.isNotEmpty) {
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      // Debug tokens are set via native layer/env; no explicit set in SDK.
    }
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidDebugProvider(),
      providerApple: const AppleDebugProvider(),
    );
  } else {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidPlayIntegrityProvider(),
      providerApple: const AppleAppAttestProvider(),
    );
  }
}
