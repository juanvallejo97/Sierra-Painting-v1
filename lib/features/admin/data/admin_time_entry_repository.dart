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
  /// TEMPORARY: Showing ALL statuses for testing (not just pending)
  /// ENV flag: ADMIN_USE_STATUS_FILTER=true to fall back to old indexed query
  Future<List<TimeEntry>> getPendingEntries({
    required String companyId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    print('[AdminRepo] getPendingEntries START - companyId=$companyId');

    const useFallbackIndexedQuery =
        bool.fromEnvironment('ADMIN_USE_STATUS_FILTER', defaultValue: false);

    var base = _firestore
        .collection('time_entries')
        .where('companyId', isEqualTo: companyId);

    if (startDate != null) {
      base = base.where('clockInAt', isGreaterThanOrEqualTo: startDate);
    }

    if (endDate != null) {
      base = base.where('clockInAt', isLessThanOrEqualTo: endDate);
    }

    final q = useFallbackIndexedQuery
        ? base
            .where('status', isEqualTo: 'pending')
            .orderBy('clockInAt', descending: true)
            .limit(100)
        : base.orderBy('clockInAt', descending: true).limit(100);

    print(
      '[AdminRepo] Executing query (fallback=${useFallbackIndexedQuery ? "status-filtered" : "all-entries"})...',
    );

    try {
      // Hard timeout that *always* fires & logs:
      final snap = await Future.any([
        q.get(),
        Future.delayed(
          const Duration(seconds: 20),
          () => throw TimeoutException('time_entries query timeout (20s)'),
        ),
      ]);

      print('[AdminRepo] ✅ SUCCESS - docs=${(snap as QuerySnapshot).size}');
      return snap.docs.map((doc) => TimeEntry.fromFirestore(doc)).toList();
    } catch (e) {
      print('[AdminRepo] ❌ ERROR: $e');
      rethrow;
    }
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
    final entries =
        await getPendingEntries(
          companyId: companyId,
          startDate: startDate,
          endDate: endDate,
        ).timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw TimeoutException(
            'Stats query timed out - index may still be building',
          ),
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
  /// TEMPORARY: Showing ALL statuses for testing (not just pending)
  Stream<List<TimeEntry>> watchPendingEntries({
    required String companyId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    var query = _firestore
        .collection('time_entries')
        .where('companyId', isEqualTo: companyId);
    // TEMPORARY: Removed .where('status', isEqualTo: 'pending') for testing

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
