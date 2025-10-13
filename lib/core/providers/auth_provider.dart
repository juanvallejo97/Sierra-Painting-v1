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
import 'package:flutter/foundation.dart';
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

/// Claims provider that guarantees a refresh once if claims are missing.
/// This prevents infinite loading when cached tokens lack role/companyId.
final userClaimsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  // First read (cached)
  var res = await user.getIdTokenResult();
  var claims = (res.claims ?? {})..removeWhere((k, v) => v == null);

  // If role/companyId absent, force refresh once.
  if (!(claims.containsKey('role') && claims.containsKey('companyId'))) {
    debugPrint('🔄 Forcing ID token refresh — missing role/companyId claims');
    res = await user.getIdTokenResult(true);
    claims = (res.claims ?? {})..removeWhere((k, v) => v == null);
  }

  debugPrint('✅ Claims loaded: $claims');
  return Map<String, dynamic>.from(claims);
});

/// Provider for user role from custom claims
final userRoleProvider = Provider<String?>((ref) {
  final claims = ref
      .watch(userClaimsProvider)
      .maybeWhen(data: (c) => c, orElse: () => null);
  return claims?['role'] as String?;
});

/// Provider for user company ID from custom claims
final userCompanyProvider = Provider<String?>((ref) {
  final claims = ref
      .watch(userClaimsProvider)
      .maybeWhen(data: (c) => c, orElse: () => null);
  return claims?['companyId'] as String?;
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
