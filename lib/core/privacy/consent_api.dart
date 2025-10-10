import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sierra_painting/core/env/build_flags.dart';
import 'package:sierra_painting/core/privacy/consent_store.dart';

class PrivacyConsent {
  PrivacyConsent(this._store);
  final ConsentStore _store;

  Future<void> applyFromDisk() async {
    final a = await _store.getAnalytics();
    if (a != null && !isUnderTest) {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(a);
    }

    final c = await _store.getCrash();
    if (c != null && !isUnderTest) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(c);
    }
  }

  Future<void> setAnalytics(bool enabled) async {
    await _store.setAnalytics(enabled);
    if (!isUnderTest) {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
    }
  }

  Future<void> setCrash(bool enabled) async {
    await _store.setCrash(enabled);
    if (!isUnderTest) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        enabled,
      );
    }
  }
}
