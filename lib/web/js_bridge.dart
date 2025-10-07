// Conditional export: web uses real JS bridge; other platforms are no-ops.
export 'js_bridge_stub.dart' if (dart.library.html) 'js_bridge_web.dart';
