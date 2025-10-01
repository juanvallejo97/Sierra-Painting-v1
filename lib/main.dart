import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'core/config/firebase_options.dart';
import 'core/config/theme_config.dart';
import 'core/services/feature_flag_service.dart';
import 'core/services/offline_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Initialize offline storage
  await OfflineService.initialize();
  
  // Initialize feature flags
  await FeatureFlagService.initialize();
  
  runApp(const SierraPaintingApp());
}

class SierraPaintingApp extends StatelessWidget {
  const SierraPaintingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FeatureFlagService>(
          create: (_) => FeatureFlagService(),
        ),
        Provider<OfflineService>(
          create: (_) => OfflineService(),
        ),
      ],
      child: MaterialApp(
        title: 'Sierra Painting',
        theme: ThemeConfig.lightTheme,
        darkTheme: ThemeConfig.darkTheme,
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
        
        // Accessibility
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(1.0, 1.3),
            ),
            child: child!,
          );
        },
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sierra Painting'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.format_paint,
              size: 100,
              color: Theme.of(context).colorScheme.primary,
              semanticLabel: 'Painting app icon',
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to Sierra Painting',
              style: Theme.of(context).textTheme.headlineMedium,
              semanticsLabel: 'Welcome to Sierra Painting',
            ),
            const SizedBox(height: 16),
            Text(
              'Small Business Management',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}
