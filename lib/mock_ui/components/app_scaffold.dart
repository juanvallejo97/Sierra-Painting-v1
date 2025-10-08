import 'package:flutter/material.dart';
import 'package:sierra_painting/mock_ui/components/debug_drawer.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom; // NEW
  const AppScaffold({super.key, required this.title, required this.body, this.actions, this.bottom});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...?actions,
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Debug',
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ],
        bottom: bottom,
      ),
      endDrawer: const DebugDrawer(),
      body: body,
    );
  }
}
