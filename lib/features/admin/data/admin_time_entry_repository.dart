/// Admin Time Entry Repository
///
/// Repository for admin operations on time entries: querying by exception type,
/// bulk approval/rejection, and statistics.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers.dart';
import 'package:sierra_painting/features/timeclock/domain/time_entry.dart';

/// Repository for admin time entry operations
class AdminTimeEntryRepository {
  final FirebaseFirestore _firestore;

  AdminTimeEntryRepository(this._firestore);

  /// Get pending time entries (awaiting approval)
  Future<List<TimeEntry>> getPendingEntries({
    required String companyId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _firestore
        .collection('time_entries')
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'pending');

    if (startDate != null) {
      query = query.where('clockInAt', isGreaterThanOrEqualTo: startDate);
    }

    if (endDate != null) {
      query = query.where('clockInAt', isLessThanOrEqualTo: endDate);
    }

    final snapshot = await query
        .orderBy('clockInAt', descending: true)
        .get()
        .timeout(
          const Duration(seconds: 8),
          onTimeout: () => throw TimeoutException('Firestore query timed out'),
        );
    return snapshot.docs.map((doc) => TimeEntry.fromFirestore(doc)).toList();
  }

  /// Get entries outside geofence (clock-in or clock-out)
  Future<List<TimeEntry>> getOutsideGeofenceEntries({
    required String companyId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final entries = await getPendingEntries(
      companyId: companyId,
      startDate: startDate,
      endDate: endDate,
    );

    return entries
        .where(
          (entry) =>
              !entry.clockInGeofenceValid ||
              (entry.clockOutGeofenceValid == false),
        )
        .toList();
  }

  /// Get entries exceeding 12 hours
  Future<List<TimeEntry>> getExceedsMaxHoursEntries({
    required String companyId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final entries = await getPendingEntries(
      companyId: companyId,
      startDate: startDate,
      endDate: endDate,
    );

    return entries.where((entry) => entry.exceedsTwelveHours).toList();
  }

  /// Get disputed entries
  Future<List<TimeEntry>> getDisputedEntries({
    required String companyId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final entries = await getPendingEntries(
      companyId: companyId,
      startDate: startDate,
      endDate: endDate,
    );

    return entries
        .where((entry) => entry.status == TimeEntryStatus.disputed)
        .toList();
  }

  /// Get flagged entries
  Future<List<TimeEntry>> getFlaggedEntries({
    required String companyId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final entries = await getPendingEntries(
      companyId: companyId,
      startDate: startDate,
      endDate: endDate,
    );

    return entries
        .where((entry) => entry.status == TimeEntryStatus.flagged)
        .toList();
  }

  /// Approve a single time entry
  Future<void> approveEntry({
    required String entryId,
    required String approvedBy,
  }) async {
    await _firestore.collection('time_entries').doc(entryId).update({
      'status': 'approved',
      'approvedBy': approvedBy,
      'approvedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Reject a single time entry
  Future<void> rejectEntry({
    required String entryId,
    required String rejectedBy,
    String? reason,
  }) async {
    await _firestore.collection('time_entries').doc(entryId).update({
      'status': 'rejected',
      'rejectedBy': rejectedBy,
      'rejectedAt': FieldValue.serverTimestamp(),
      if (reason != null) 'rejectionReason': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Bulk approve time entries
  Future<void> bulkApproveEntries({
    required List<String> entryIds,
    required String approvedBy,
  }) async {
    final batch = _firestore.batch();

    for (final entryId in entryIds) {
      final ref = _firestore.collection('time_entries').doc(entryId);
      batch.update(ref, {
        'status': 'approved',
        'approvedBy': approvedBy,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Bulk reject time entries
  Future<void> bulkRejectEntries({
    required List<String> entryIds,
    required String rejectedBy,
    String? reason,
  }) async {
    final batch = _firestore.batch();

    for (final entryId in entryIds) {
      final ref = _firestore.collection('time_entries').doc(entryId);
      batch.update(ref, {
        'status': 'rejected',
        'rejectedBy': rejectedBy,
        'rejectedAt': FieldValue.serverTimestamp(),
        if (reason != null) 'rejectionReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Get exception counts for statistics
  Future<Map<String, int>> getExceptionCounts({
    required String companyId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final entries = await getPendingEntries(
      companyId: companyId,
      startDate: startDate,
      endDate: endDate,
    ).timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw TimeoutException('Stats query timed out'),
    );

    return {
      'outsideGeofence': entries
          .where(
            (e) =>
                !e.clockInGeofenceValid || (e.clockOutGeofenceValid == false),
          )
          .length,
      'exceedsMaxHours': entries.where((e) => e.exceedsTwelveHours).length,
      'disputed': entries
          .where((e) => e.status == TimeEntryStatus.disputed)
          .length,
      'flagged': entries
          .where((e) => e.status == TimeEntryStatus.flagged)
          .length,
      'totalPending': entries.length,
    };
  }

  /// Stream of pending entries for real-time updates
  Stream<List<TimeEntry>> watchPendingEntries({
    required String companyId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    var query = _firestore
        .collection('time_entries')
        .where('companyId', isEqualTo: companyId)
        .where('status', isEqualTo: 'pending');

    if (startDate != null) {
      query = query.where('clockInAt', isGreaterThanOrEqualTo: startDate);
    }

    if (endDate != null) {
      query = query.where('clockInAt', isLessThanOrEqualTo: endDate);
    }

    return query
        .orderBy('clockInAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => TimeEntry.fromFirestore(doc)).toList(),
        );
  }
}

/// Provider for AdminTimeEntryRepository
final adminTimeEntryRepositoryProvider = Provider<AdminTimeEntryRepository>((
  ref,
) {
  final firestore = ref.watch(firestoreProvider);
  return AdminTimeEntryRepository(firestore);
});
