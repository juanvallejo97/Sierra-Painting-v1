/// Assignment Domain Model
///
/// PURPOSE:
/// Type-safe domain entity for worker-to-job assignments.
/// Enforces access control for geofence-based timeclock.
///
/// FEATURES:
/// - Worker-to-job assignment tracking
/// - Active/inactive status
/// - Company isolation
/// - Start/end date tracking
///
/// SECURITY:
/// - Only admin/manager can create/update/delete assignments
/// - Workers can read their own assignments
/// - Used by Cloud Functions to validate clock in/out permissions
///
/// USAGE:
/// - Create assignment to grant worker access to job site
/// - Set active=false to revoke access without deletion
/// - Query by userId to get worker's current assignments
/// - Query by jobId to get all workers on a job
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class Assignment {
  final String? id;
  final String companyId;
  final String userId; // Worker ID
  final String jobId;
  final bool active; // Active assignments allow clock in/out
  final DateTime? startDate; // When assignment begins
  final DateTime? endDate; // When assignment ends (null = ongoing)
  final String? role; // Optional: 'lead', 'painter', 'helper', etc.
  final String? notes; // Optional notes about the assignment
  final DateTime createdAt;
  final DateTime updatedAt;

  Assignment({
    this.id,
    required this.companyId,
    required this.userId,
    required this.jobId,
    this.active = true,
    this.startDate,
    this.endDate,
    this.role,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory Assignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Assignment(
      id: doc.id,
      companyId: data['companyId'] as String,
      userId: data['userId'] as String,
      jobId: data['jobId'] as String,
      active: data['active'] as bool? ?? true,
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : null,
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      role: data['role'] as String?,
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'userId': userId,
      'jobId': jobId,
      'active': active,
      if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      if (role != null) 'role': role,
      if (notes != null) 'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated fields
  Assignment copyWith({
    String? id,
    String? companyId,
    String? userId,
    String? jobId,
    bool? active,
    DateTime? startDate,
    DateTime? endDate,
    String? role,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Assignment(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      userId: userId ?? this.userId,
      jobId: jobId ?? this.jobId,
      active: active ?? this.active,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      role: role ?? this.role,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if assignment is currently valid
  bool get isValid {
    if (!active) return false;

    final now = DateTime.now();

    // Check start date
    if (startDate != null && now.isBefore(startDate!)) {
      return false;
    }

    // Check end date
    if (endDate != null && now.isAfter(endDate!)) {
      return false;
    }

    return true;
  }

  /// Check if assignment is expired
  bool get isExpired {
    if (endDate == null) return false;
    return DateTime.now().isAfter(endDate!);
  }

  /// Check if assignment is scheduled for future
  bool get isFuture {
    if (startDate == null) return false;
    return DateTime.now().isBefore(startDate!);
  }
}
