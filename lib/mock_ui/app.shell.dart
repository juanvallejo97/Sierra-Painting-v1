import 'package:flutter/material.dart';
import 'theme.dart';
import 'demo_state.dart';
import 'router.dart';

class PlaygroundApp extends StatefulWidget {
  const PlaygroundApp({super.key});
  @override State<PlaygroundApp> createState() => _PlaygroundAppState();
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
              seed: controller.seedColor,
              radius: controller.radius,
              density: controller.density,
            ),
            darkTheme: buildTheme(
              brightness: Brightness.dark,
              seed: controller.seedColor,
              radius: controller.radius,
              density: controller.density,
            ),
            themeMode: controller.darkMode ? ThemeMode.dark : ThemeMode.light,
            onGenerateRoute: buildRouter(),
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              final dir = controller.rtl ? TextDirection.rtl : TextDirection.ltr;
              return Directionality(
                textDirection: dir,
                child: MediaQuery(
                  data: mq.copyWith(textScaler: TextScaler.linear(controller.textScale)),
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
