/// Estimate Repository - Data Layer
///
/// PURPOSE:
/// Repository pattern implementation for estimate operations.
/// Centralizes all estimate API calls with:
/// - Type-safe Firestore operations
/// - Company isolation (multi-tenant)
/// - Result-based error handling
/// - Pagination support
///
/// RESPONSIBILITIES:
/// - Create estimates
/// - Fetch estimates with filters
/// - Update estimate status
/// - Convert estimate to invoice
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers/firestore_provider.dart';
import 'package:sierra_painting/core/utils/result.dart';
import 'package:sierra_painting/features/estimates/domain/estimate.dart';

/// Create estimate request
class CreateEstimateRequest {
  final String companyId;
  final String customerId;
  final String? jobId;
  final List<EstimateItem> items;
  final String? notes;
  final DateTime validUntil;

  CreateEstimateRequest({
    required this.companyId,
    required this.customerId,
    this.jobId,
    required this.items,
    this.notes,
    required this.validUntil,
  });

  double get totalAmount {
    return items.fold(0.0, (total, item) => total + item.total);
  }
}

/// Estimate Repository
class EstimateRepository {
  final FirebaseFirestore _firestore;

  /// Default pagination limit
  static const int defaultLimit = 50;

  /// Maximum pagination limit
  static const int maxLimit = 100;

  EstimateRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  /// Create a new estimate
  ///
  /// SECURITY: Requires companyId to be set (enforced by Firestore rules)
  /// Only users with appropriate roles can create estimates.
  Future<Result<Estimate, String>> createEstimate(
    CreateEstimateRequest request,
  ) async {
    try {
      final now = DateTime.now();
      final estimate = Estimate(
        companyId: request.companyId,
        customerId: request.customerId,
        jobId: request.jobId,
        status: EstimateStatus.draft,
        amount: request.totalAmount,
        items: request.items,
        notes: request.notes,
        validUntil: request.validUntil,
        createdAt: now,
        updatedAt: now,
      );

      final docRef = await _firestore
          .collection('estimates')
          .add(estimate.toFirestore());

      final createdEstimate = estimate.copyWith(id: docRef.id);
      return Result.success(createdEstimate);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Get estimates for a company
  ///
  /// PERFORMANCE: Always uses pagination with default limit of 50.
  /// Filters by companyId for multi-tenant isolation.
  Future<Result<List<Estimate>, String>> getEstimates({
    required String companyId,
    EstimateStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
    DocumentSnapshot? startAfterDoc,
  }) async {
    try {
      final effectiveLimit = limit != null
          ? (limit > maxLimit ? maxLimit : limit)
          : defaultLimit;

      Query query = _firestore
          .collection('estimates')
          .where('companyId', isEqualTo: companyId);

      if (status != null) {
        query = query.where(
          'status',
          isEqualTo: Estimate.statusToString(status),
        );
      }

      if (startDate != null) {
        query = query.where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'createdAt',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      query = query
          .orderBy('createdAt', descending: true)
          .limit(effectiveLimit);

      if (startAfterDoc != null) {
        query = query.startAfterDocument(startAfterDoc);
      }

      final snapshot = await query.get();
      final estimates = snapshot.docs
          .map((doc) => Estimate.fromFirestore(doc))
          .toList();

      return Result.success(estimates);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Get a single estimate by ID
  Future<Result<Estimate, String>> getEstimate(String estimateId) async {
    try {
      final doc = await _firestore
          .collection('estimates')
          .doc(estimateId)
          .get();

      if (!doc.exists) {
        return Result.failure('Estimate not found');
      }

      final estimate = Estimate.fromFirestore(doc);
      return Result.success(estimate);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Mark estimate as sent
  Future<Result<Estimate, String>> markAsSent(String estimateId) async {
    return await updateStatus(
      estimateId: estimateId,
      status: EstimateStatus.sent,
    );
  }

  /// Mark estimate as accepted
  Future<Result<Estimate, String>> markAsAccepted({
    required String estimateId,
    required DateTime acceptedAt,
  }) async {
    try {
      await _firestore.collection('estimates').doc(estimateId).update({
        'status': 'accepted',
        'acceptedAt': Timestamp.fromDate(acceptedAt),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Fetch updated estimate
      return await getEstimate(estimateId);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Update estimate status
  Future<Result<Estimate, String>> updateStatus({
    required String estimateId,
    required EstimateStatus status,
  }) async {
    try {
      await _firestore.collection('estimates').doc(estimateId).update({
        'status': Estimate.statusToString(status),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Fetch updated estimate
      return await getEstimate(estimateId);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Map Firestore errors to user-friendly messages
  String _mapError(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to perform this action.';
        case 'not-found':
          return 'Estimate not found.';
        case 'unavailable':
          return 'Service temporarily unavailable. Please try again.';
        default:
          return 'An error occurred: ${error.message}';
      }
    }
    return 'An unexpected error occurred: $error';
  }
}

/// Provider for EstimateRepository
final estimateRepositoryProvider = Provider<EstimateRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return EstimateRepository(firestore: firestore);
});
