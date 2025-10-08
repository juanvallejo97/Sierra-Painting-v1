import 'package:flutter/material.dart';

class DemoController extends ChangeNotifier {
  bool darkMode = false;
  bool rtl = false;
  bool simulateLoading = false;
  bool simulateError = false;
  double textScale = 1.0;

  void setDark(bool v) {
    darkMode = v;
    notifyListeners();
  }

  void setRtl(bool v) {
    rtl = v;
    notifyListeners();
  }

  void setLoading(bool v) {
    simulateLoading = v;
    notifyListeners();
  }

  void setError(bool v) {
    simulateError = v;
    notifyListeners();
  }

  void setScale(double v) {
    textScale = v;
    notifyListeners();
  }
}

class DemoScope extends InheritedNotifier<DemoController> {
  const DemoScope({super.key, required DemoController controller, required super.child}) : super(notifier: controller);

  static DemoController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<DemoScope>();
    assert(scope != null, 'DemoScope not found');
    return scope!.notifier!;
  }
}
