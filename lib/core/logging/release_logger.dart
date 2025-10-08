import 'package:flutter/foundation.dart';

void logInfo(String msg) {
  if (kReleaseMode) return; // silence in release
  // ignore: avoid_print
  print(msg);
}
