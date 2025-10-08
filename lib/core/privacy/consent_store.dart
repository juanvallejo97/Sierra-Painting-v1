import 'package:shared_preferences/shared_preferences.dart';

class ConsentStore {
  static const _kAnalytics = 'consent.analytics';
  static const _kCrash = 'consent.crash';

  Future<bool?> getAnalytics() async =>
      (await SharedPreferences.getInstance()).getBool(_kAnalytics);

  Future<bool?> getCrash() async =>
      (await SharedPreferences.getInstance()).getBool(_kCrash);

  Future<void> setAnalytics(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kAnalytics, v);

  Future<void> setCrash(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kCrash, v);
}
