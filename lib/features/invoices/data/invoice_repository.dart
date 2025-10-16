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
  final String customerName;
  final String? jobId;
  final List<InvoiceItem> items;
  final double taxRate; // Tax rate as percentage (e.g., 8.5 for 8.5%)
  final String? notes;
  final DateTime dueDate;

  CreateInvoiceRequest({
    required this.companyId,
    this.estimateId,
    required this.customerId,
    required this.customerName,
    this.jobId,
    required this.items,
    this.taxRate = 0.0,
    this.notes,
    required this.dueDate,
  });

  double get subtotal {
    return items.fold(0.0, (total, item) => total + item.total);
  }

  double get tax {
    return subtotal * (taxRate / 100.0);
  }

  double get totalAmount {
    return subtotal + tax;
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

  /// Generate invoice number (INV-YYYYMM-####)
  Future<String> _generateInvoiceNumber(String companyId) async {
    final now = DateTime.now();
    final prefix = 'INV-${now.year}${now.month.toString().padLeft(2, '0')}';

    // Query for invoices in current month to get next number
    final snapshot = await _firestore
        .collection('invoices')
        .where('companyId', isEqualTo: companyId)
        .where('number', isGreaterThanOrEqualTo: prefix)
        .where('number', isLessThan: '$prefix-9999')
        .orderBy('number', descending: true)
        .limit(1)
        .get();

    int nextNum = 1;
    if (snapshot.docs.isNotEmpty) {
      final lastNumber = snapshot.docs.first.data()['number'] as String?;
      if (lastNumber != null) {
        final parts = lastNumber.split('-');
        if (parts.length == 3) {
          nextNum = (int.tryParse(parts[2]) ?? 0) + 1;
        }
      }
    }

    return '$prefix-${nextNum.toString().padLeft(4, '0')}';
  }

  /// Create a new invoice
  ///
  /// SECURITY: Requires companyId to be set (enforced by Firestore rules)
  /// Only users with appropriate roles can create invoices.
  Future<Result<Invoice, String>> createInvoice(
    CreateInvoiceRequest request,
  ) async {
    try {
      final now = DateTime.now();
      final invoiceNumber = await _generateInvoiceNumber(request.companyId);

      final invoice = Invoice(
        companyId: request.companyId,
        estimateId: request.estimateId,
        customerId: request.customerId,
        customerName: request.customerName,
        jobId: request.jobId,
        status: InvoiceStatus.draft,
        number: invoiceNumber,
        amount: request.totalAmount,
        subtotal: request.subtotal,
        tax: request.tax,
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

  /// Mark invoice as sent to customer
  Future<Result<Invoice, String>> markAsSent({
    required String invoiceId,
  }) async {
    try {
      // Use transaction to maintain status history
      await _firestore.runTransaction((tx) async {
        final docRef = _firestore.collection('invoices').doc(invoiceId);
        final doc = await tx.get(docRef);

        if (!doc.exists) {
          throw Exception('Invoice not found');
        }

        final data = doc.data()!;
        final currentStatus = data['status'] as String;
        final statusHistory =
            data['statusHistory'] as List<dynamic>? ?? <dynamic>[];

        // Add current status to history with timestamp
        final updatedHistory = List<Map<String, dynamic>>.from(
          statusHistory.map((e) => Map<String, dynamic>.from(e as Map)),
        );
        updatedHistory.add({
          'status': 'sent',
          'changedAt': FieldValue.serverTimestamp(),
          'previousStatus': currentStatus,
        });

        tx.update(docRef, {
          'status': 'sent',
          'statusHistory': updatedHistory,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Fetch updated invoice
      return await getInvoice(invoiceId);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Mark invoice as paid (cash)
  Future<Result<Invoice, String>> markAsPaidCash({
    required String invoiceId,
    required DateTime paidAt,
  }) async {
    try {
      // Use transaction to maintain status history
      await _firestore.runTransaction((tx) async {
        final docRef = _firestore.collection('invoices').doc(invoiceId);
        final doc = await tx.get(docRef);

        if (!doc.exists) {
          throw Exception('Invoice not found');
        }

        final data = doc.data()!;
        final currentStatus = data['status'] as String;
        final statusHistory =
            data['statusHistory'] as List<dynamic>? ?? <dynamic>[];

        // Add current status to history with timestamp
        final updatedHistory = List<Map<String, dynamic>>.from(
          statusHistory.map((e) => Map<String, dynamic>.from(e as Map)),
        );
        updatedHistory.add({
          'status': 'paid_cash',
          'changedAt': FieldValue.serverTimestamp(),
          'previousStatus': currentStatus,
        });

        tx.update(docRef, {
          'status': 'paid_cash',
          'paidAt': Timestamp.fromDate(paidAt),
          'statusHistory': updatedHistory,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Fetch updated invoice
      return await getInvoice(invoiceId);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Mark invoice as paid (legacy method - kept for backwards compatibility)
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

  /// Revert invoice to previous status (for undo within 15s window)
  ///
  /// UNDO MECHANISM:
  /// - Maintains status history in statusHistory array
  /// - Allows reverting to previous status within 15s
  /// - Idempotent: prevents duplicate reverts
  /// - Audit trail: preserves all transitions
  Future<Result<Invoice, String>> revertStatus({
    required String invoiceId,
  }) async {
    try {
      // Use transaction to ensure atomic read-modify-write
      await _firestore.runTransaction<void>((tx) async {
        final docRef = _firestore.collection('invoices').doc(invoiceId);
        final doc = await tx.get(docRef);

        if (!doc.exists) {
          throw Exception('Invoice not found');
        }

        final data = doc.data()!;
        final statusHistory =
            data['statusHistory'] as List<dynamic>? ?? <dynamic>[];

        // Need at least 2 entries (current + previous)
        if (statusHistory.length < 2) {
          throw Exception('No previous status to revert to');
        }

        // Get the last two status entries
        final currentEntry = statusHistory.last as Map<String, dynamic>;
        final previousEntry =
            statusHistory[statusHistory.length - 2] as Map<String, dynamic>;

        // Check 15s window (using client time for UX, server time for audit)
        final changedAt = (currentEntry['changedAt'] as Timestamp).toDate();
        final now = DateTime.now();
        final elapsed = now.difference(changedAt);

        if (elapsed.inSeconds > 15) {
          throw Exception('Undo window expired (>15s)');
        }

        // Remove current entry and revert to previous status
        final newHistory = List<Map<String, dynamic>>.from(
          statusHistory.take(statusHistory.length - 1).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
        );

        final previousStatus = previousEntry['status'] as String;

        // Update with previous status
        tx.update(docRef, {
          'status': previousStatus,
          'statusHistory': newHistory,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      // Fetch updated invoice after transaction
      return await getInvoice(invoiceId);
    } catch (e) {
      if (e.toString().contains('Undo window expired')) {
        return Result.failure('Cannot undo: more than 15 seconds have passed');
      }
      if (e.toString().contains('No previous status')) {
        return Result.failure('Cannot undo: no previous status available');
      }
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
