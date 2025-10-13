/// Token Refresh Service
///
/// PURPOSE:
/// Automatically refreshes Firebase Auth tokens when user roles change.
/// Prevents privilege escalation from cached tokens with stale role claims.
///
/// SECURITY:
/// - Tokens contain custom claims (role, companyId) that last up to 1 hour
/// - If admin changes a user's role, old token still valid until expiry
/// - This service forces immediate token refresh when role changes
/// - Prevents users from accessing resources with outdated permissions
///
/// ARCHITECTURE:
/// 1. Backend sets `forceTokenRefresh: true` in user doc when role changes
/// 2. Client listens to user doc via Firestore
/// 3. When flag detected, call `getIdToken(true)` to force refresh
/// 4. Clear flag after successful refresh
///
/// USAGE:
/// Initialize in app startup (main.dart):
/// ```dart
/// final tokenRefreshService = ref.read(tokenRefreshServiceProvider);
/// tokenRefreshService.startListening();
/// ```
library;

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for automatic token refresh on role changes
class TokenRefreshService {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  TokenRefreshService({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  }) : _auth = auth,
       _firestore = firestore;

  /// Start listening for token refresh flags
  ///
  /// Call this when user logs in.
  /// Automatically stops when user logs out.
  void startListening() {
    // Cancel existing subscription
    stopListening();

    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[TokenRefreshService] No user logged in, skipping listener');
      return;
    }

    debugPrint('[TokenRefreshService] Starting listener for user: ${user.uid}');

    // Listen to user document
    _userDocSubscription = _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen(
          _handleUserDocChange,
          onError: (error) {
            debugPrint(
              '[TokenRefreshService] Error listening to user doc: $error',
            );
          },
        );
  }

  /// Stop listening for token refresh flags
  ///
  /// Call this when user logs out.
  void stopListening() {
    _userDocSubscription?.cancel();
    _userDocSubscription = null;
    debugPrint('[TokenRefreshService] Stopped listener');
  }

  /// Handle user document changes
  Future<void> _handleUserDocChange(DocumentSnapshot snapshot) async {
    if (!snapshot.exists) {
      debugPrint('[TokenRefreshService] User doc does not exist');
      return;
    }

    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) {
      return;
    }

    // Check if token refresh is required
    final forceRefresh = data['forceTokenRefresh'] as bool?;
    final reason = data['tokenRefreshReason'] as String?;

    if (forceRefresh == true) {
      debugPrint('[TokenRefreshService] Token refresh required: $reason');
      await _refreshToken(snapshot.reference);
    }
  }

  /// Force token refresh and clear flag
  Future<void> _refreshToken(DocumentReference userRef) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('[TokenRefreshService] No user logged in during refresh');
        return;
      }

      // Force token refresh (bypass cache)
      debugPrint('[TokenRefreshService] Refreshing token...');
      final idTokenResult = await user.getIdToken(true);

      if (idTokenResult != null) {
        debugPrint('[TokenRefreshService] Token refreshed successfully');
        debugPrint('[TokenRefreshService] New role: $idTokenResult');

        // Clear the flag (optimistic update, don't await)
        await _clearRefreshFlag(userRef);
      }
    } catch (error) {
      debugPrint('[TokenRefreshService] Error refreshing token: $error');
      // Don't rethrow - retry on next doc change
    }
  }

  /// Clear forceTokenRefresh flag from user document
  Future<void> _clearRefreshFlag(DocumentReference userRef) async {
    try {
      await userRef.update({
        'forceTokenRefresh': FieldValue.delete(),
        'tokenRefreshReason': FieldValue.delete(),
      });
      debugPrint('[TokenRefreshService] Cleared refresh flag');
    } catch (error) {
      debugPrint('[TokenRefreshService] Error clearing refresh flag: $error');
      // Non-critical error, will retry on next doc change
    }
  }

  /// Dispose resources
  void dispose() {
    stopListening();
  }
}
