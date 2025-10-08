import 'dart:ui';
import 'package:flutter/material.dart';

class DesktopWebScaffold extends StatelessWidget {
  final Widget child;
  const DesktopWebScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: const _ScrollBehavior(),
      child: FocusTraversalGroup(child: child),
    );
  }
}

class _ScrollBehavior extends MaterialScrollBehavior {
  const _ScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
  };
}
