/// Time Entry Repository - Data Layer
///
/// PURPOSE:
/// Repository pattern for time entry CRUD operations.
/// Handles Firestore integration with idempotency and audit trail.
///
/// FEATURES:
/// - Create/read/update time entries
/// - Idempotency deduplication via clientEventId
/// - Company-scoped queries
/// - Audit trail for all edits
/// - Worker-only create, admin-only edit enforcement
/// - Exception-first queries for admin review
///
/// SECURITY (per coach notes):
/// - Workers can only create their own entries
/// - Admin edits via this repository (logged in audit trail)
/// - Approved entries are locked (enforced by Firestore rules)
/// - All edits tracked with before/after values
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers/firestore_provider.dart';
import 'package:sierra_painting/core/utils/result.dart';
import 'package:sierra_painting/features/timeclock/domain/time_entry.dart';

/// Create time entry request (clock-in)
class CreateTimeEntryRequest {
  final String clientEventId; // For idempotency
  final String companyId;
  final String workerId;
  final String jobId;
  final DateTime clockIn;
  final TimeEntryGeoPoint? clockInLocation;
  final bool clockInGeofenceValid;
  final String? notes;
  final String source; // 'mobile', 'web'

  CreateTimeEntryRequest({
    required this.clientEventId,
    required this.companyId,
    required this.workerId,
    required this.jobId,
    required this.clockIn,
    this.clockInLocation,
    this.clockInGeofenceValid = true,
    this.notes,
    this.source = 'mobile',
  });
}

/// Clock-out request
class ClockOutRequest {
  final String timeEntryId;
  final DateTime clockOut;
  final TimeEntryGeoPoint? clockOutLocation;
  final bool clockOutGeofenceValid;
  final String? notes;

  ClockOutRequest({
    required this.timeEntryId,
    required this.clockOut,
    this.clockOutLocation,
    this.clockOutGeofenceValid = true,
    this.notes,
  });
}

/// Admin edit request
class AdminEditRequest {
  final String timeEntryId;
  final String adminUserId;
  final String reason;
  final DateTime? clockIn;
  final DateTime? clockOut;
  final String? notes;

  AdminEditRequest({
    required this.timeEntryId,
    required this.adminUserId,
    required this.reason,
    this.clockIn,
    this.clockOut,
    this.notes,
  });
}

/// Approval request
class ApprovalRequest {
  final String timeEntryId;
  final String adminUserId;
  final TimeEntryStatus newStatus; // approved or flagged

  ApprovalRequest({
    required this.timeEntryId,
    required this.adminUserId,
    required this.newStatus,
  });
}

/// Time entry query filters
class TimeEntryFilters {
  final String? workerId;
  final String? jobId;
  final TimeEntryStatus? status;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool? hasGeofenceViolation;
  final bool? exceedsTwelveHours;
  final bool? isPending;

  TimeEntryFilters({
    this.workerId,
    this.jobId,
    this.status,
    this.startDate,
    this.endDate,
    this.hasGeofenceViolation,
    this.exceedsTwelveHours,
    this.isPending,
  });
}

/// Time entry repository
class TimeEntryRepository {
  final FirebaseFirestore _firestore;

  TimeEntryRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  /// Create a new time entry (clock-in)
  ///
  /// Performs idempotency check using clientEventId.
  /// If entry with same clientEventId exists, returns existing entry.
  Future<Result<TimeEntry, String>> createTimeEntry(
    CreateTimeEntryRequest request,
  ) async {
    try {
      // Check for existing entry with same clientEventId (idempotency)
      final existingQuery = await _firestore
          .collection('time_entries')
          .where('clientEventId', isEqualTo: request.clientEventId)
          .limit(1)
          .get();

      if (existingQuery.docs.isNotEmpty) {
        // Return existing entry (idempotent)
        final existing = TimeEntry.fromFirestore(existingQuery.docs.first);
        return Result.success(existing);
      }

      // Create new entry
      final now = DateTime.now();
      final timeEntry = TimeEntry(
        clientEventId: request.clientEventId,
        companyId: request.companyId,
        workerId: request.workerId,
        jobId: request.jobId,
        status: TimeEntryStatus.active,
        clockIn: request.clockIn,
        clockInLocation: request.clockInLocation,
        clockInGeofenceValid: request.clockInGeofenceValid,
        notes: request.notes,
        source: request.source,
        createdAt: now,
        updatedAt: now,
      );

      final docRef = await _firestore
          .collection('time_entries')
          .add(timeEntry.toFirestore());

      final createdEntry = timeEntry.copyWith(id: docRef.id);
      return Result.success(createdEntry);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Clock out from time entry
  Future<Result<TimeEntry, String>> clockOut(ClockOutRequest request) async {
    try {
      final docRef = _firestore
          .collection('time_entries')
          .doc(request.timeEntryId);
      final doc = await docRef.get();

      if (!doc.exists) {
        return Result.failure('Time entry not found');
      }

      final entry = TimeEntry.fromFirestore(doc);

      // Check if already clocked out
      if (entry.clockOut != null) {
        return Result.failure('Already clocked out');
      }

      // Check if entry is locked (approved)
      if (entry.isApproved) {
        return Result.failure('Cannot modify approved time entry');
      }

      // Update with clock-out info
      final updates = {
        'clockOut': Timestamp.fromDate(request.clockOut),
        if (request.clockOutLocation != null)
          'clockOutLocation': request.clockOutLocation!.toMap(),
        'clockOutGeofenceValid': request.clockOutGeofenceValid,
        if (request.notes != null) 'notes': request.notes,
        'status': TimeEntryStatus.pending.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await docRef.update(updates);

      // Fetch updated entry
      return await getTimeEntry(request.timeEntryId);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Admin edit time entry (with audit log)
  Future<Result<TimeEntry, String>> adminEdit(AdminEditRequest request) async {
    try {
      final docRef = _firestore
          .collection('time_entries')
          .doc(request.timeEntryId);
      final doc = await docRef.get();

      if (!doc.exists) {
        return Result.failure('Time entry not found');
      }

      final entry = TimeEntry.fromFirestore(doc);

      // Build audit record
      final changes = <String, dynamic>{};
      if (request.clockIn != null) {
        changes['clockIn'] = {
          'before': entry.clockIn.toIso8601String(),
          'after': request.clockIn!.toIso8601String(),
        };
      }
      if (request.clockOut != null) {
        changes['clockOut'] = {
          'before': entry.clockOut?.toIso8601String(),
          'after': request.clockOut!.toIso8601String(),
        };
      }
      if (request.notes != null) {
        changes['notes'] = {'before': entry.notes, 'after': request.notes};
      }

      final auditRecord = AuditRecord(
        editedBy: request.adminUserId,
        editedAt: DateTime.now(),
        reason: request.reason,
        changes: changes,
      );

      // Prepare updates
      final updates = <String, dynamic>{
        'auditLog': FieldValue.arrayUnion([auditRecord.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (request.clockIn != null) {
        updates['clockIn'] = Timestamp.fromDate(request.clockIn!);
      }
      if (request.clockOut != null) {
        updates['clockOut'] = Timestamp.fromDate(request.clockOut!);
      }
      if (request.notes != null) {
        updates['notes'] = request.notes;
      }

      await docRef.update(updates);

      // Fetch updated entry
      return await getTimeEntry(request.timeEntryId);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Approve or flag time entry
  Future<Result<TimeEntry, String>> updateApprovalStatus(
    ApprovalRequest request,
  ) async {
    try {
      final docRef = _firestore
          .collection('time_entries')
          .doc(request.timeEntryId);

      final updates = <String, dynamic>{
        'status': request.newStatus.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (request.newStatus == TimeEntryStatus.approved) {
        updates['approvedBy'] = request.adminUserId;
        updates['approvedAt'] = FieldValue.serverTimestamp();
      }

      await docRef.update(updates);

      return await getTimeEntry(request.timeEntryId);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Get single time entry
  Future<Result<TimeEntry, String>> getTimeEntry(String timeEntryId) async {
    try {
      final doc = await _firestore
          .collection('time_entries')
          .doc(timeEntryId)
          .get();

      if (!doc.exists) {
        return Result.failure('Time entry not found');
      }

      return Result.success(TimeEntry.fromFirestore(doc));
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Get time entries with filters
  Future<Result<List<TimeEntry>, String>> getTimeEntries({
    required String companyId,
    TimeEntryFilters? filters,
    int limit = 100,
  }) async {
    try {
      Query query = _firestore
          .collection('time_entries')
          .where('companyId', isEqualTo: companyId)
          .orderBy('clockIn', descending: true)
          .limit(limit);

      // Apply filters
      if (filters != null) {
        if (filters.workerId != null) {
          query = query.where('workerId', isEqualTo: filters.workerId);
        }
        if (filters.jobId != null) {
          query = query.where('jobId', isEqualTo: filters.jobId);
        }
        if (filters.status != null) {
          query = query.where(
            'status',
            isEqualTo: filters.status!.toFirestore(),
          );
        }
        if (filters.startDate != null) {
          query = query.where(
            'clockIn',
            isGreaterThanOrEqualTo: Timestamp.fromDate(filters.startDate!),
          );
        }
        if (filters.endDate != null) {
          query = query.where(
            'clockIn',
            isLessThanOrEqualTo: Timestamp.fromDate(filters.endDate!),
          );
        }
      }

      final snapshot = await query.get();
      var entries = snapshot.docs
          .map((doc) => TimeEntry.fromFirestore(doc))
          .toList();

      // Client-side filters (not supported by Firestore query)
      if (filters != null) {
        if (filters.hasGeofenceViolation == true) {
          entries = entries.where((e) => e.hasGeofenceViolation).toList();
        }
        if (filters.exceedsTwelveHours == true) {
          entries = entries.where((e) => e.exceedsTwelveHours).toList();
        }
        if (filters.isPending == true) {
          entries = entries
              .where((e) => e.status == TimeEntryStatus.pending)
              .toList();
        }
      }

      return Result.success(entries);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Get exception entries for admin review (exception-first view)
  ///
  /// Returns entries that need attention:
  /// - Geofence violations
  /// - Exceeds 12 hours
  /// - Flagged or disputed
  /// - Pending approval
  Future<Result<List<TimeEntry>, String>> getExceptionEntries({
    required String companyId,
    int limit = 50,
  }) async {
    try {
      // Get pending and flagged entries
      final snapshot = await _firestore
          .collection('time_entries')
          .where('companyId', isEqualTo: companyId)
          .where('status', whereIn: ['pending', 'flagged', 'disputed'])
          .orderBy('clockIn', descending: true)
          .limit(limit)
          .get();

      final entries = snapshot.docs
          .map((doc) => TimeEntry.fromFirestore(doc))
          .toList();

      // Filter for exceptions
      final exceptions = entries.where((entry) {
        return entry.hasGeofenceViolation ||
            entry.exceedsTwelveHours ||
            entry.isFlagged;
      }).toList();

      return Result.success(exceptions);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Get active clock-in for worker
  Future<Result<TimeEntry?, String>> getActiveClockin({
    required String workerId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('time_entries')
          .where('workerId', isEqualTo: workerId)
          .where('status', isEqualTo: 'active')
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return Result.success(null);
      }

      final entry = TimeEntry.fromFirestore(snapshot.docs.first);
      return Result.success(entry);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Stream time entries for real-time updates
  Stream<List<TimeEntry>> watchTimeEntries({
    required String companyId,
    TimeEntryFilters? filters,
    int limit = 100,
  }) {
    Query query = _firestore
        .collection('time_entries')
        .where('companyId', isEqualTo: companyId)
        .orderBy('clockIn', descending: true)
        .limit(limit);

    // Apply filters
    if (filters?.workerId != null) {
      query = query.where('workerId', isEqualTo: filters!.workerId);
    }
    if (filters?.jobId != null) {
      query = query.where('jobId', isEqualTo: filters!.jobId);
    }
    if (filters?.status != null) {
      query = query.where('status', isEqualTo: filters!.status!.toFirestore());
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TimeEntry.fromFirestore(doc)).toList();
    });
  }

  /// Map Firestore errors to user-friendly messages
  String _mapError(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to perform this action.';
        case 'not-found':
          return 'Time entry not found.';
        case 'unavailable':
          return 'Service temporarily unavailable. Please try again.';
        default:
          return 'An error occurred: ${error.message}';
      }
    }
    return 'An unexpected error occurred: $error';
  }
}

/// Provider for TimeEntryRepository
final timeEntryRepositoryProvider = Provider<TimeEntryRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return TimeEntryRepository(firestore: firestore);
});
