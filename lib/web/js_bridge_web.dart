// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

// Web-only JS bridge using js_util.
import 'dart:js_util' as js_util;

void _callConsole(String method, String message) {
  try {
    final console = js_util.getProperty<Object>(js_util.globalThis, 'console');
    js_util.callMethod<Object?>(console, method, [message]);
  } catch (_) {}
}

void consoleLog(String message) => _callConsole('log', message);
void consoleWarn(String message) => _callConsole('warn', message);
void consoleError(String message) => _callConsole('error', message);

void setGlobalFlag(String name, Object? value) {
  try {
    js_util.setProperty(js_util.globalThis, name, value);
  } catch (_) {}
}
