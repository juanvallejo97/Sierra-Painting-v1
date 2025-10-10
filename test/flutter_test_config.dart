import 'package:flutter/foundation.dart'; // Ensures a single place to init binding & guard FlutterError handlers
import 'dart:async';

typedef _Err = void Function(FlutterErrorDetails);

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final _Err original = FlutterError.onError ?? FlutterError.dumpErrorToConsole;

  // Use the default console dumper but keep original for restore.
  FlutterError.onError = FlutterError.dumpErrorToConsole;

  // Make test teardown robust even if extra async prints/errors happen.
  await runZonedGuarded(
    () async {
      await testMain();
    },
    (e, s) {
      // Don’t crash the harness on stray async errors in teardown.
      // They will still be printed by the default handler.
    },
  );

  // Restore original.
  FlutterError.onError = original;
}
