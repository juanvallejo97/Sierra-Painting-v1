import 'package:flutter/material.dart';
// Local fallback implementation of PlaygroundApp to avoid a missing import.
// If you intend to use a shared app_shell.dart, create that file instead
// and restore the original import.
class PlaygroundApp extends StatelessWidget {
  const PlaygroundApp({Key? key}) : super(key: key);

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

void main() => runApp(const PlaygroundApp());
