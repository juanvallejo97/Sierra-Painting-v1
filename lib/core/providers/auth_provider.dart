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
import '../services/token_refresh_service.dart';
import 'firestore_provider.dart';

/// Provider for Firebase Auth instance
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

/// Provider for Token Refresh Service
final tokenRefreshServiceProvider = Provider<TokenRefreshService>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final firestore = ref.watch(firestoreProvider);
  final service = TokenRefreshService(auth: auth, firestore: firestore);

  // Auto-dispose when provider is removed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Stream provider for auth state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

/// Provider for current user
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

/// Provider for user role from custom claims
final userRoleProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  // Get ID token which contains custom claims
  final idTokenResult = await user.getIdTokenResult();
  return idTokenResult.claims?['role'] as String?;
});

/// Provider for user company ID from custom claims
final userCompanyProvider = FutureProvider<String?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final idTokenResult = await user.getIdTokenResult();
  return idTokenResult.claims?['companyId'] as String?;
});

/// Provider that manages token refresh listener lifecycle
///
/// Automatically starts listening when user logs in,
/// stops listening when user logs out.
final tokenRefreshListenerProvider = Provider<void>((ref) {
  final user = ref.watch(currentUserProvider);
  final service = ref.watch(tokenRefreshServiceProvider);

  if (user != null) {
    // User logged in - start listening
    service.startListening();
  } else {
    // User logged out - stop listening
    service.stopListening();
  }
});
