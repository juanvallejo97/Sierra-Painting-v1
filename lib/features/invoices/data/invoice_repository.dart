/// Invoice Repository - Data Layer
///
/// PURPOSE:
/// Repository pattern implementation for invoice operations.
/// Centralizes all invoice API calls with:
/// - Type-safe Firestore operations
/// - Company isolation (multi-tenant)
/// - Result-based error handling
/// - Pagination support
///
/// RESPONSIBILITIES:
/// - Create invoices
/// - Fetch invoices with filters
/// - Update invoice status
/// - Mark as paid
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers/firestore_provider.dart';
import 'package:sierra_painting/core/utils/result.dart';
import 'package:sierra_painting/features/invoices/domain/invoice.dart';

/// Create invoice request
class CreateInvoiceRequest {
  final String companyId;
  final String? estimateId;
  final String customerId;
  final String? jobId;
  final List<InvoiceItem> items;
  final String? notes;
  final DateTime dueDate;

  CreateInvoiceRequest({
    required this.companyId,
    this.estimateId,
    required this.customerId,
    this.jobId,
    required this.items,
    this.notes,
    required this.dueDate,
  });

  double get totalAmount {
    return items.fold(0.0, (total, item) => total + item.total);
  }
}

/// Invoice Repository
class InvoiceRepository {
  final FirebaseFirestore _firestore;

  /// Default pagination limit
  static const int defaultLimit = 50;

  /// Maximum pagination limit
  static const int maxLimit = 100;

  InvoiceRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  /// Create a new invoice
  ///
  /// SECURITY: Requires companyId to be set (enforced by Firestore rules)
  /// Only users with appropriate roles can create invoices.
  Future<Result<Invoice, String>> createInvoice(
    CreateInvoiceRequest request,
  ) async {
    try {
      final now = DateTime.now();
      final invoice = Invoice(
        companyId: request.companyId,
        estimateId: request.estimateId,
        customerId: request.customerId,
        jobId: request.jobId,
        status: InvoiceStatus.pending,
        amount: request.totalAmount,
        items: request.items,
        notes: request.notes,
        dueDate: request.dueDate,
        createdAt: now,
        updatedAt: now,
      );

      final docRef = await _firestore
          .collection('invoices')
          .add(invoice.toFirestore());

      final createdInvoice = invoice.copyWith(id: docRef.id);
      return Result.success(createdInvoice);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Get invoices for a company
  ///
  /// PERFORMANCE: Always uses pagination with default limit of 50.
  /// Filters by companyId for multi-tenant isolation.
  Future<Result<List<Invoice>, String>> getInvoices({
    required String companyId,
    InvoiceStatus? status,
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
          .collection('invoices')
          .where('companyId', isEqualTo: companyId);

      if (status != null) {
        query = query.where(
          'status',
          isEqualTo: Invoice.statusToString(status),
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
      final invoices = snapshot.docs
          .map((doc) => Invoice.fromFirestore(doc))
          .toList();

      return Result.success(invoices);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Get a single invoice by ID
  Future<Result<Invoice, String>> getInvoice(String invoiceId) async {
    try {
      final doc = await _firestore.collection('invoices').doc(invoiceId).get();

      if (!doc.exists) {
        return Result.failure('Invoice not found');
      }

      final invoice = Invoice.fromFirestore(doc);
      return Result.success(invoice);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Mark invoice as paid
  Future<Result<Invoice, String>> markAsPaid({
    required String invoiceId,
    required DateTime paidAt,
  }) async {
    try {
      await _firestore.collection('invoices').doc(invoiceId).update({
        'status': 'paid',
        'paidAt': Timestamp.fromDate(paidAt),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Fetch updated invoice
      return await getInvoice(invoiceId);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Update invoice status
  Future<Result<Invoice, String>> updateStatus({
    required String invoiceId,
    required InvoiceStatus status,
  }) async {
    try {
      await _firestore.collection('invoices').doc(invoiceId).update({
        'status': Invoice.statusToString(status),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Fetch updated invoice
      return await getInvoice(invoiceId);
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
          return 'Invoice not found.';
        case 'unavailable':
          return 'Service temporarily unavailable. Please try again.';
        default:
          return 'An error occurred: ${error.message}';
      }
    }
    return 'An unexpected error occurred: $error';
  }
}

/// Provider for InvoiceRepository
final invoiceRepositoryProvider = Provider<InvoiceRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return InvoiceRepository(firestore: firestore);
});
