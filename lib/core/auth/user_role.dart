/// User Role System
///
/// PURPOSE:
/// Define user roles for RBAC (Role-Based Access Control).
/// Controls access to features based on user's role.
///
/// ROLES:
/// - admin: Full access to all features, manage company
/// - manager: Manage jobs, assign workers, approve timesheets
/// - worker: Clock in/out, view own timesheet, view assigned jobs
///
/// SECURITY:
/// Roles are stored in Firebase Auth custom claims (server-side).
/// Client reads role but server enforces via Firestore rules.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// User roles in the system
enum UserRole {
  /// Full system access - company owner/admin
  admin,

  /// Manage jobs and workers - supervisor/foreman
  manager,

  /// Basic worker - clock in/out, view own data
  worker;

  /// Convert from string (from Firebase custom claims)
  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'manager':
        return UserRole.manager;
      case 'worker':
        return UserRole.worker;
      default:
        return UserRole.worker; // Default to worker for safety
    }
  }

  /// Convert to string for storage
  @override
  String toString() {
    return name;
  }

  /// Check if role has admin privileges
  bool get isAdmin => this == UserRole.admin;

  /// Check if role has manager privileges (admin or manager)
  bool get isManager => this == UserRole.admin || this == UserRole.manager;

  /// Check if role is basic worker
  bool get isWorker => this == UserRole.worker;

  /// Display name for UI
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.manager:
        return 'Manager';
      case UserRole.worker:
        return 'Worker';
    }
  }
}

/// User profile with role information
class UserProfile {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final UserRole role;
  final String companyId;
  final DateTime createdAt;
  final DateTime? lastLoginAt;

  UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    required this.role,
    required this.companyId,
    required this.createdAt,
    this.lastLoginAt,
  });

  /// Create from Firebase user and custom claims
  factory UserProfile.fromFirebaseUser(User user, Map<String, dynamic> claims) {
    return UserProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      role: UserRole.fromString(claims['role'] as String? ?? 'worker'),
      companyId: claims['companyId'] as String? ?? '',
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      lastLoginAt: user.metadata.lastSignInTime,
    );
  }

  /// Check if user has admin access
  bool get isAdmin => role.isAdmin;

  /// Check if user has manager access
  bool get isManager => role.isManager;

  /// Check if user is a basic worker
  bool get isWorker => role.isWorker;
}

/// Provider for current user's profile with role
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  try {
    // Get custom claims from ID token
    final idTokenResult = await user.getIdTokenResult();
    final claims = idTokenResult.claims ?? {};

    return UserProfile.fromFirebaseUser(user, claims);
  } catch (e) {
    // If claims fetch fails, return basic profile with worker role
    return UserProfile(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      photoUrl: user.photoURL,
      role: UserRole.worker,
      companyId: '',
      createdAt: user.metadata.creationTime ?? DateTime.now(),
      lastLoginAt: user.metadata.lastSignInTime,
    );
  }
});

/// Provider for current user's role
final userRoleProvider = Provider<AsyncValue<UserRole>>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.whenData((profile) => profile?.role ?? UserRole.worker);
});

/// Helper to check if current user has admin access
final isAdminProvider = Provider<bool>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.value?.isAdmin ?? false;
});

/// Helper to check if current user has manager access
final isManagerProvider = Provider<bool>((ref) {
  final profileAsync = ref.watch(userProfileProvider);
  return profileAsync.value?.isManager ?? false;
});
