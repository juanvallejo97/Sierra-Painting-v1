import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:sierra_painting/mock_ui/app.shell.dart' as mock;

class PlaygroundApp extends StatelessWidget {
  const PlaygroundApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Playground',
      home: Scaffold(
        appBar: AppBar(title: const Text('Playground')),
        body: const Center(child: Text('Playground App')),
      ),
    );
  }
}

void main() {
  // Gate mock UI behind kReleaseMode check
  // This prevents accidental execution in release builds
  if (kReleaseMode) {
    throw StateError(
      'Mock UI is not available in release mode. '
      'Use the main app entry point (lib/main.dart) instead.',
    );
  }

  // Run the full-featured mock UI playground
  runApp(const mock.PlaygroundApp());
}
