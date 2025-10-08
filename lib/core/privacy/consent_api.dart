import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:sierra_painting/core/privacy/consent_store.dart';

class PrivacyConsent {
  PrivacyConsent(this._store);
  final ConsentStore _store;

  Future<void> applyFromDisk() async {
    final a = await _store.getAnalytics();
    if (a != null) {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(a);
    }

    final c = await _store.getCrash();
    if (c != null) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(c);
    }
  }

  Future<void> setAnalytics(bool enabled) async {
    await _store.setAnalytics(enabled);
    await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(enabled);
  }

  Future<void> setCrash(bool enabled) async {
    await _store.setCrash(enabled);
    await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled);
  }
}
