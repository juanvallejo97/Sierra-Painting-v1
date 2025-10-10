import 'package:flutter/material.dart';

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

void main() => runApp(const PlaygroundApp());
