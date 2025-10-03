import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/app/app.dart';
import 'package:sierra_painting/firebase_options.dart';
import 'package:sierra_painting/core/services/feature_flag_service.dart';
import 'package:sierra_painting/core/services/offline_service.dart';

/// Sierra Painting Flutter Application
///
/// PURPOSE:
/// Entry point for the Sierra Painting mobile application.
/// Initializes Firebase, offline storage, and feature flags before app launch.
///
/// ARCHITECTURE:
/// - Uses Riverpod for state management and dependency injection
/// - Implements offline-first architecture with queue synchronization
/// - Follows Material Design 3 guidelines
///
/// INITIALIZATION ORDER:
/// 1. Firebase (auth, firestore, functions)
/// 2. Offline storage (Hive)
/// 3. Feature flags
/// 4. App widget tree
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

  runApp(
    const ProviderScope(
      child: SierraPaintingApp(),
    ),
  );
}
