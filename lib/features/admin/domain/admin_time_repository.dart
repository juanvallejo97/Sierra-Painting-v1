/// Admin Time Repository Contract
///
/// PURPOSE:
/// Admin operations for reviewing, editing, approving time entries.
/// Supports exception-first workflow with bulk actions.
///
/// EXCEPTION QUERIES:
/// - Outside Geofence: geoOkIn=false OR geoOkOut=false
/// - >12h: durationHours > 12
/// - Auto Clock-Out: exceptionTags contains "auto_clockout"
/// - Overlapping: exceptionTags contains "overlap"
/// - Disputed: disputeNote != null
/// - All Pending: approved=false, invoiceId=null
///
/// FIRESTORE QUERIES (implementation crew):
/// ```dart
/// // Outside geofence
/// db.collection('timeEntries')
///   .where('companyId', '==', companyId)
///   .where('exceptionTags', 'array-contains', 'geofence_out')
///   .where('approved', '==', false)
///   .orderBy('clockInAt', descending: true)
///
/// // >12h shifts
/// db.collection('timeEntries')
///   .where('companyId', '==', companyId)
///   .where('exceptionTags', 'array-contains', 'exceeds_12h')
///   .where('approved', '==', false)
///   .orderBy('clockInAt', descending: true)
///
/// // Auto clock-out
/// db.collection('timeEntries')
///   .where('companyId', '==', companyId)
///   .where('exceptionTags', 'array-contains', 'auto_clockout')
///   .where('approved', '==', false)
///   .orderBy('clockInAt', descending: true)
///
/// // Overlapping
/// db.collection('timeEntries')
///   .where('companyId', '==', companyId)
///   .where('exceptionTags', 'array-contains', 'overlap')
///   .where('approved', '==', false)
///   .orderBy('clockInAt', descending: true)
///
/// // Disputed
/// db.collection('timeEntries')
///   .where('companyId', '==', companyId)
///   .where('disputeNote', '!=', null)
///   .where('approved', '==', false)
///   .orderBy('disputeNote')
///   .orderBy('clockInAt', descending: true)
///
/// // All pending (no exceptions)
/// db.collection('timeEntries')
///   .where('companyId', '==', companyId)
///   .where('approved', '==', false)
///   .where('invoiceId', '==', null)
///   .orderBy('clockInAt', descending: true)
/// ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/features/timeclock/domain/time_entry.dart';

/// Exception filter type
enum ExceptionFilter {
  outsideGeofence,
  exceeds12h,
  autoClockOut,
  overlapping,
  disputed,
  allPending,
}

/// Date range for filtering
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});

  /// Today (midnight to midnight in company timezone)
  factory DateRange.today({required String timezone}) {
    // TODO: Use timezone package
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return DateRange(start: start, end: end);
  }

  /// This week (Monday to Sunday)
  factory DateRange.thisWeek({required String timezone}) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
    final end = start.add(const Duration(days: 7));
    return DateRange(start: start, end: end);
  }

  /// Last 30 days
  factory DateRange.last30Days() {
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 30));
    return DateRange(start: start, end: end);
  }
}

/// Edit time entry request
class EditTimeEntryRequest {
  final String timeEntryId;
  final DateTime? clockInAt;
  final DateTime? clockOutAt;
  final String? notes;
  final String editReason; // Required for audit

  EditTimeEntryRequest({
    required this.timeEntryId,
    this.clockInAt,
    this.clockOutAt,
    this.notes,
    required this.editReason,
  });

  /// Convert to request for callable function
  Map<String, dynamic> toJson() {
    return {
      'timeEntryId': timeEntryId,
      if (clockInAt != null) 'clockInAt': clockInAt!.toIso8601String(),
      if (clockOutAt != null) 'clockOutAt': clockOutAt!.toIso8601String(),
      if (notes != null) 'notes': notes,
      'editReason': editReason,
    };
  }
}

/// Create invoice from time request
class CreateInvoiceFromTimeRequest {
  final List<String> timeEntryIds;
  final String customerId;
  final double hourlyRate;
  final String? notes;

  CreateInvoiceFromTimeRequest({
    required this.timeEntryIds,
    required this.customerId,
    required this.hourlyRate,
    this.notes,
  });

  /// Convert to request for callable function
  Map<String, dynamic> toJson() {
    return {
      'timeEntryIds': timeEntryIds,
      'customerId': customerId,
      'hourlyRate': hourlyRate,
      if (notes != null) 'notes': notes,
    };
  }
}

/// Result wrapper
sealed class Result<T, E> {
  const Result();
}

class Success<T, E> extends Result<T, E> {
  final T value;
  const Success(this.value);
}

class Failure<T, E> extends Result<T, E> {
  final E error;
  const Failure(this.error);
}

/// Admin time repository interface
abstract class AdminTimeRepository {
  /// Get time entries with exception filter
  ///
  /// Returns stream for real-time updates in UI.
  ///
  /// IMPLEMENTATION TODO:
  /// ```dart
  /// Stream<List<TimeEntry>> exceptions({
  ///   required String companyId,
  ///   ExceptionFilter filter = ExceptionFilter.allPending,
  ///   DateRange? dateRange,
  /// }) {
  ///   Query<Map<String, dynamic>> query = _firestore
  ///     .collection('timeEntries')
  ///     .where('companyId', '==', companyId)
  ///     .where('approved', '==', false);
  ///
  ///   // Add filter-specific conditions
  ///   switch (filter) {
  ///     case ExceptionFilter.outsideGeofence:
  ///       query = query.where('exceptionTags', 'array-contains', 'geofence_out');
  ///       break;
  ///     case ExceptionFilter.exceeds12h:
  ///       query = query.where('exceptionTags', 'array-contains', 'exceeds_12h');
  ///       break;
  ///     // ... other filters
  ///   }
  ///
  ///   // Add date range if provided
  ///   if (dateRange != null) {
  ///     query = query
  ///       .where('clockInAt', '>=', Timestamp.fromDate(dateRange.start))
  ///       .where('clockInAt', '<', Timestamp.fromDate(dateRange.end));
  ///   }
  ///
  ///   return query
  ///     .orderBy('clockInAt', descending: true)
  ///     .snapshots()
  ///     .map((snapshot) => snapshot.docs
  ///       .map((doc) => TimeEntry.fromFirestore(doc))
  ///       .toList());
  /// }
  /// ```
  Stream<List<TimeEntry>> exceptions({
    required String companyId,
    ExceptionFilter filter = ExceptionFilter.allPending,
    DateRange? dateRange,
  });

  /// Get count of entries in each exception category
  ///
  /// Used for tab badges showing count.
  ///
  /// IMPLEMENTATION TODO:
  /// ```dart
  /// Future<Map<ExceptionFilter, int>> getExceptionCounts({
  ///   required String companyId,
  ///   DateRange? dateRange,
  /// }) async {
  ///   final counts = <ExceptionFilter, int>{};
  ///
  ///   for (final filter in ExceptionFilter.values) {
  ///     final snapshot = await _buildQuery(companyId, filter, dateRange)
  ///       .count()
  ///       .get();
  ///     counts[filter] = snapshot.count;
  ///   }
  ///
  ///   return counts;
  /// }
  /// ```
  Future<Map<ExceptionFilter, int>> getExceptionCounts({
    required String companyId,
    DateRange? dateRange,
  });

  /// Approve time entries in bulk
  ///
  /// Sets approved=true for all specified entries.
  /// Uses batch write for atomicity.
  ///
  /// IMPLEMENTATION TODO:
  /// ```dart
  /// Future<Result<void, String>> approve(List<String> entryIds) async {
  ///   if (entryIds.isEmpty) {
  ///     return const Failure('No entries selected');
  ///   }
  ///
  ///   if (entryIds.length > 500) {
  ///     return const Failure('Max 500 entries per batch');
  ///   }
  ///
  ///   final batch = _firestore.batch();
  ///
  ///   for (final id in entryIds) {
  ///     final ref = _firestore.collection('timeEntries').doc(id);
  ///     batch.update(ref, {
  ///       'approved': true,
  ///       'approvedAt': FieldValue.serverTimestamp(),
  ///       'approvedBy': _currentUserId,
  ///       'updatedAt': FieldValue.serverTimestamp(),
  ///     });
  ///   }
  ///
  ///   try {
  ///     await batch.commit();
  ///     return const Success(null);
  ///   } catch (e) {
  ///     return Failure('Batch update failed: $e');
  ///   }
  /// }
  /// ```
  Future<Result<void, String>> approve(List<String> entryIds);

  /// Reject time entries in bulk
  ///
  /// Sets approved=false, adds rejection note.
  ///
  /// IMPLEMENTATION TODO: Similar to approve(), but sets approved=false
  /// and adds rejectionNote field.
  Future<Result<void, String>> reject(
    List<String> entryIds, {
    required String reason,
  });

  /// Edit single time entry
  ///
  /// Calls editTimeEntry callable function.
  /// Function handles overlap detection, audit trail, and validation.
  ///
  /// IMPLEMENTATION TODO:
  /// ```dart
  /// Future<Result<void, String>> editTimeEntry(EditTimeEntryRequest request) async {
  ///   try {
  ///     final callable = FirebaseFunctions.instance.httpsCallable('editTimeEntry');
  ///     await callable.call(request.toJson());
  ///     return const Success(null);
  ///   } on FirebaseFunctionsException catch (e) {
  ///     return Failure(e.message ?? 'Edit failed');
  ///   } catch (e) {
  ///     return Failure('Unexpected error: $e');
  ///   }
  /// }
  /// ```
  Future<Result<void, String>> editTimeEntry(EditTimeEntryRequest request);

  /// Create invoice from selected time entries
  ///
  /// Calls createInvoiceFromTime callable function.
  /// Function validates entries, aggregates hours, and locks entries atomically.
  ///
  /// Returns invoice ID on success.
  ///
  /// IMPLEMENTATION TODO:
  /// ```dart
  /// Future<Result<String, String>> createInvoiceFromTime(
  ///   CreateInvoiceFromTimeRequest request,
  /// ) async {
  ///   try {
  ///     final callable = FirebaseFunctions.instance
  ///       .httpsCallable('createInvoiceFromTime');
  ///     final result = await callable.call(request.toJson());
  ///     final invoiceId = result.data['invoiceId'] as String;
  ///     return Success(invoiceId);
  ///   } on FirebaseFunctionsException catch (e) {
  ///     return Failure(e.message ?? 'Invoice creation failed');
  ///   } catch (e) {
  ///     return Failure('Unexpected error: $e');
  ///   }
  /// }
  /// ```
  Future<Result<String, String>> createInvoiceFromTime(
    CreateInvoiceFromTimeRequest request,
  );

  /// Get invoicing candidates
  ///
  /// Returns entries that are:
  /// - approved=true
  /// - invoiceId==null
  /// - clockOutAt!=null (closed)
  ///
  /// IMPLEMENTATION TODO:
  /// ```dart
  /// Stream<List<TimeEntry>> getInvoicingCandidates({
  ///   required String companyId,
  ///   String? jobId,
  ///   String? customerId,
  /// }) {
  ///   Query<Map<String, dynamic>> query = _firestore
  ///     .collection('timeEntries')
  ///     .where('companyId', '==', companyId)
  ///     .where('approved', '==', true)
  ///     .where('invoiceId', '==', null)
  ///     .where('clockOutAt', '!=', null);
  ///
  ///   if (jobId != null) {
  ///     query = query.where('jobId', '==', jobId);
  ///   }
  ///
  ///   // Note: customerId filter would require denormalization
  ///   // or client-side filtering after job lookup
  ///
  ///   return query
  ///     .orderBy('clockOutAt')
  ///     .orderBy('clockInAt', descending: true)
  ///     .snapshots()
  ///     .map((snapshot) => snapshot.docs
  ///       .map((doc) => TimeEntry.fromFirestore(doc))
  ///       .toList());
  /// }
  /// ```
  Stream<List<TimeEntry>> getInvoicingCandidates({
    required String companyId,
    String? jobId,
    String? customerId,
  });
}

/// Provider for admin time repository
/// Implementation will be provided by concrete class
final adminTimeRepositoryProvider = Provider<AdminTimeRepository>((ref) {
  throw UnimplementedError(
    'AdminTimeRepository provider must be overridden with concrete implementation',
  );
});

/// Provider for exception counts (reactive)
final exceptionCountsProvider =
    StreamProvider.family<
      Map<ExceptionFilter, int>,
      String // companyId
    >((ref, companyId) async* {
      final repository = ref.watch(adminTimeRepositoryProvider);

      // Poll counts every 30 seconds
      while (true) {
        try {
          final counts = await repository.getExceptionCounts(
            companyId: companyId,
          );
          yield counts;
        } catch (e) {
          // Yield previous value or empty map on error
          yield {};
        }
        await Future.delayed(const Duration(seconds: 30));
      }
    });

/// Provider for exception entries by filter
final exceptionEntriesProvider =
    StreamProvider.family<
      List<TimeEntry>,
      ({String companyId, ExceptionFilter filter})
    >((ref, params) {
      final repository = ref.watch(adminTimeRepositoryProvider);
      return repository.exceptions(
        companyId: params.companyId,
        filter: params.filter,
      );
    });
