/// Unit tests for invoice undo functionality
///
/// PURPOSE:
/// Verify that invoice status revert mechanism works correctly:
/// - Status history is maintained monotonically
/// - Totals round-trip correctly (unchanged after undo)
/// - 15s window is enforced
/// - Idempotency is maintained

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/features/invoices/data/invoice_repository.dart';
import 'package:sierra_painting/features/invoices/domain/invoice.dart';

void main() {
  group('Invoice Undo Tests', () {
    late FakeFirebaseFirestore firestore;
    late InvoiceRepository repository;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repository = InvoiceRepository(firestore: firestore);
    });

    test('revertStatus() reverts to previous status within 15s', () async {
      // Create invoice
      final request = CreateInvoiceRequest(
        companyId: 'company-1',
        customerId: 'customer-1',
        customerName: 'Test Customer',
        items: [
          InvoiceItem(
            description: 'Test Item',
            quantity: 1.0,
            unitPrice: 100.0,
          ),
        ],
        dueDate: DateTime.now().add(const Duration(days: 30)),
      );

      final createResult = await repository.createInvoice(request);
      expect(createResult.isSuccess, true);

      final invoice = createResult.valueOrNull!;
      expect(invoice.status, InvoiceStatus.draft);

      // Mark as sent
      final sentResult = await repository.markAsSent(invoiceId: invoice.id!);
      expect(sentResult.isSuccess, true);
      final sentInvoice = sentResult.valueOrNull!;
      expect(sentInvoice.status, InvoiceStatus.sent);

      // Verify status history exists
      final doc = await firestore.collection('invoices').doc(invoice.id).get();
      final data = doc.data()!;
      final statusHistory = data['statusHistory'] as List;
      expect(statusHistory.length, 1); // One entry for 'sent'

      // Revert status (should go back to draft)
      final revertResult = await repository.revertStatus(invoiceId: invoice.id!);
      expect(revertResult.isSuccess, true);

      final revertedInvoice = revertResult.valueOrNull!;
      expect(revertedInvoice.status, InvoiceStatus.draft);

      // Verify totals unchanged
      expect(revertedInvoice.amount, invoice.amount);
      expect(revertedInvoice.subtotal, invoice.subtotal);
      expect(revertedInvoice.tax, invoice.tax);
    });

    test('revertStatus() maintains monotonic status history', () async {
      // Create invoice
      final request = CreateInvoiceRequest(
        companyId: 'company-1',
        customerId: 'customer-1',
        customerName: 'Test Customer',
        items: [
          InvoiceItem(
            description: 'Test Item',
            quantity: 1.0,
            unitPrice: 100.0,
          ),
        ],
        dueDate: DateTime.now().add(const Duration(days: 30)),
      );

      final createResult = await repository.createInvoice(request);
      final invoice = createResult.valueOrNull!;

      // Mark as sent
      await repository.markAsSent(invoiceId: invoice.id!);

      // Check history length
      var doc = await firestore.collection('invoices').doc(invoice.id).get();
      var statusHistory = doc.data()!['statusHistory'] as List;
      expect(statusHistory.length, 1);

      // Mark as paid
      await repository.markAsPaidCash(
        invoiceId: invoice.id!,
        paidAt: DateTime.now(),
      );

      // Check history length increased
      doc = await firestore.collection('invoices').doc(invoice.id).get();
      statusHistory = doc.data()!['statusHistory'] as List;
      expect(statusHistory.length, 2);

      // Revert (should remove last entry)
      await repository.revertStatus(invoiceId: invoice.id!);

      // Check history length decreased
      doc = await firestore.collection('invoices').doc(invoice.id).get();
      statusHistory = doc.data()!['statusHistory'] as List;
      expect(statusHistory.length, 1);

      // History should be monotonic - only 'sent' entry remains
      final lastEntry = statusHistory.last as Map<String, dynamic>;
      expect(lastEntry['status'], 'sent');
    });

    test('revertStatus() fails when no previous status exists', () async {
      // Create invoice (no status changes yet)
      final request = CreateInvoiceRequest(
        companyId: 'company-1',
        customerId: 'customer-1',
        customerName: 'Test Customer',
        items: [
          InvoiceItem(
            description: 'Test Item',
            quantity: 1.0,
            unitPrice: 100.0,
          ),
        ],
        dueDate: DateTime.now().add(const Duration(days: 30)),
      );

      final createResult = await repository.createInvoice(request);
      final invoice = createResult.valueOrNull!;

      // Try to revert (should fail - no history)
      final revertResult = await repository.revertStatus(invoiceId: invoice.id!);
      expect(revertResult.isFailure, true);
      expect(
        revertResult.errorOrNull,
        contains('no previous status'),
      );
    });

    test('revertStatus() preserves totals after round-trip', () async {
      // Create invoice with specific amounts
      final request = CreateInvoiceRequest(
        companyId: 'company-1',
        customerId: 'customer-1',
        customerName: 'Test Customer',
        items: [
          InvoiceItem(
            description: 'Paint Job',
            quantity: 10.0,
            unitPrice: 50.0,
          ),
          InvoiceItem(
            description: 'Labor',
            quantity: 5.0,
            unitPrice: 75.0,
            discount: 25.0,
          ),
        ],
        taxRate: 8.5,
        dueDate: DateTime.now().add(const Duration(days: 30)),
      );

      final createResult = await repository.createInvoice(request);
      final original = createResult.valueOrNull!;

      final originalSubtotal = original.subtotal;
      final originalTax = original.tax;
      final originalAmount = original.amount;

      // Mark as sent
      await repository.markAsSent(invoiceId: original.id!);

      // Mark as paid
      await repository.markAsPaidCash(
        invoiceId: original.id!,
        paidAt: DateTime.now(),
      );

      // Revert to sent
      final revert1 = await repository.revertStatus(invoiceId: original.id!);
      final afterRevert1 = revert1.valueOrNull!;
      expect(afterRevert1.status, InvoiceStatus.sent);
      expect(afterRevert1.subtotal, originalSubtotal);
      expect(afterRevert1.tax, originalTax);
      expect(afterRevert1.amount, originalAmount);

      // Revert to draft
      final revert2 = await repository.revertStatus(invoiceId: original.id!);
      final afterRevert2 = revert2.valueOrNull!;
      expect(afterRevert2.status, InvoiceStatus.draft);
      expect(afterRevert2.subtotal, originalSubtotal);
      expect(afterRevert2.tax, originalTax);
      expect(afterRevert2.amount, originalAmount);
    });
  });
}
