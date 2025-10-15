/// Employee Domain Model
///
/// PURPOSE:
/// Type-safe domain entity for employees/workers.
/// Tracks employee status from invitation through active employment.
///
/// FIELDS:
/// - id: Firestore document ID
/// - companyId: Company ID for multi-tenant isolation
/// - displayName: Employee's full name
/// - phone: Phone number in E.164 format (e.g., +15551234567)
/// - role: Employee role (worker, admin, manager)
/// - status: Employee status (invited, active, inactive)
/// - uid: Firebase Auth UID (null until onboarding complete)
/// - email: Optional email address
/// - createdAt: When employee record was created
/// - updatedAt: Last update timestamp
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Employee role enum
enum EmployeeRole {
  worker, // Field worker/painter
  admin, // Administrative staff
  manager; // Manager role

  static EmployeeRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return EmployeeRole.admin;
      case 'manager':
        return EmployeeRole.manager;
      case 'worker':
      default:
        return EmployeeRole.worker;
    }
  }

  String toFirestore() => name;

  String get displayName {
    switch (this) {
      case EmployeeRole.worker:
        return 'Worker';
      case EmployeeRole.admin:
        return 'Admin';
      case EmployeeRole.manager:
        return 'Manager';
    }
  }
}

/// Employee status enum
enum EmployeeStatus {
  invited, // Invited but not yet onboarded
  active, // Active employee
  inactive; // Inactive/terminated employee

  static EmployeeStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return EmployeeStatus.active;
      case 'inactive':
        return EmployeeStatus.inactive;
      case 'invited':
      default:
        return EmployeeStatus.invited;
    }
  }

  String toFirestore() => name;

  String get displayName {
    switch (this) {
      case EmployeeStatus.invited:
        return 'Invited';
      case EmployeeStatus.active:
        return 'Active';
      case EmployeeStatus.inactive:
        return 'Inactive';
    }
  }
}

/// Employee domain model
class Employee {
  final String? id;
  final String companyId;
  final String displayName;
  final String phone; // E.164 format (e.g., +15551234567)
  final EmployeeRole role;
  final EmployeeStatus status;
  final String? uid; // Firebase Auth UID (null until onboarded)
  final String? email;
  final DateTime createdAt;
  final DateTime updatedAt;

  Employee({
    this.id,
    required this.companyId,
    required this.displayName,
    required this.phone,
    this.role = EmployeeRole.worker,
    this.status = EmployeeStatus.invited,
    this.uid,
    this.email,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Check if employee is active
  bool get isActive => status == EmployeeStatus.active;

  /// Check if employee is invited but not yet onboarded
  bool get isPendingOnboarding =>
      status == EmployeeStatus.invited && uid == null;

  /// Check if employee has completed onboarding
  bool get hasCompletedOnboarding => uid != null;

  /// Create from Firestore document
  factory Employee.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Employee(
      id: doc.id,
      companyId: data['companyId'] as String,
      displayName: data['displayName'] as String,
      phone: data['phone'] as String,
      role: EmployeeRole.fromString(data['role'] as String? ?? 'worker'),
      status: EmployeeStatus.fromString(data['status'] as String? ?? 'invited'),
      uid: data['uid'] as String?,
      email: data['email'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'displayName': displayName,
      'phone': phone,
      'role': role.toFirestore(),
      'status': status.toFirestore(),
      if (uid != null) 'uid': uid,
      if (email != null) 'email': email,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated fields
  Employee copyWith({
    String? id,
    String? companyId,
    String? displayName,
    String? phone,
    EmployeeRole? role,
    EmployeeStatus? status,
    String? uid,
    String? email,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Employee(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      uid: uid ?? this.uid,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
