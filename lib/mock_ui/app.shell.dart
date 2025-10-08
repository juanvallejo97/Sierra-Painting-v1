import 'package:flutter/material.dart';
import 'package:sierra_painting/mock_ui/demo_state.dart';
import 'package:sierra_painting/mock_ui/router.dart';
import 'package:sierra_painting/mock_ui/theme.dart';

class PlaygroundApp extends StatefulWidget {
  const PlaygroundApp({super.key});
  @override
  State<PlaygroundApp> createState() => _PlaygroundAppState();
}

class _PlaygroundAppState extends State<PlaygroundApp> {
  final controller = DemoController();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return DemoScope(
          controller: controller,
          child: MaterialApp(
            title: 'Sierra Playground',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(
              brightness: Brightness.light,
              seed: Colors.blue, // fallback
              radius: 8.0, // fallback
              density: 1.0, // fallback
            ),
            darkTheme: buildTheme(
              brightness: Brightness.dark,
              seed: Colors.blue, // fallback
              radius: 8.0, // fallback
              density: 1.0, // fallback
            ),
            themeMode: controller.darkMode ? ThemeMode.dark : ThemeMode.light,
            onGenerateRoute: buildRouter(),
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              final dir = controller.rtl
                  ? TextDirection.rtl
                  : TextDirection.ltr;
              return Directionality(
                textDirection: dir,
                child: MediaQuery(
                  data: mq.copyWith(
                    textScaler: TextScaler.linear(controller.textScale),
                  ),
                  child: child ?? const SizedBox.shrink(),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
