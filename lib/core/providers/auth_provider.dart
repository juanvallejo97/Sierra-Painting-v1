/// Authentication Providers
///
/// PURPOSE:
/// Riverpod providers for Firebase Authentication integration.
/// Provides reactive access to auth state throughout the application.
///
/// PROVIDERS:
/// - firebaseAuthProvider: Firebase Auth instance
/// - authStateProvider: Stream of auth state changes (User? or null)
/// - currentUserProvider: Current authenticated user snapshot
///
/// USAGE:
/// ```dart
/// final user = ref.watch(currentUserProvider);
/// if (user != null) {
///   // User is logged in
/// }
/// ```
///
/// ARCHITECTURE:
/// All auth state is managed through Riverpod for reactive updates.
/// Components watch these providers to rebuild on auth changes.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for Firebase Auth instance
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Stream provider for auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Provider for current user
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});
