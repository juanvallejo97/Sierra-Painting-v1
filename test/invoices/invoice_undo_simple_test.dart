/// Simplified invoice undo tests that don't rely on FakeFirebaseFirestore
///
/// PURPOSE:
/// Test the invoice undo logic at the domain level
/// Note: Full integration tests with real Firebase would test the complete flow

import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/features/invoices/domain/invoice.dart';

void main() {
  group('Invoice Undo Domain Tests', () {
    test('Invoice model supports status transitions', () {
      final invoice = Invoice(
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
        subtotal: 100.0,
        tax: 8.5,
        amount: 108.5,
        dueDate: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Test initial status
      expect(invoice.status, InvoiceStatus.draft);

      // Test status transition to sent
      final sentInvoice = invoice.copyWith(status: InvoiceStatus.sent);
      expect(sentInvoice.status, InvoiceStatus.sent);

      // Test status transition to paid
      final paidInvoice = sentInvoice.copyWith(status: InvoiceStatus.paidCash);
      expect(paidInvoice.status, InvoiceStatus.paidCash);

      // Test revert to sent
      final revertedToSent = paidInvoice.copyWith(status: InvoiceStatus.sent);
      expect(revertedToSent.status, InvoiceStatus.sent);

      // Test revert to draft
      final revertedToDraft = revertedToSent.copyWith(status: InvoiceStatus.draft);
      expect(revertedToDraft.status, InvoiceStatus.draft);
    });

    test('Invoice totals remain unchanged during status transitions', () {
      final invoice = Invoice(
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
        subtotal: 850.0, // 500 + 350
        tax: 72.25, // 850 * 0.085
        amount: 922.25, // 850 + 72.25
        dueDate: DateTime.now().add(const Duration(days: 30)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final originalSubtotal = invoice.subtotal;
      final originalTax = invoice.tax;
      final originalAmount = invoice.amount;

      // Transition through statuses
      final sent = invoice.copyWith(status: InvoiceStatus.sent);
      final paid = sent.copyWith(status: InvoiceStatus.paidCash);
      final revertedToSent = paid.copyWith(status: InvoiceStatus.sent);
      final revertedToDraft = revertedToSent.copyWith(status: InvoiceStatus.draft);

      // Verify totals never changed
      expect(sent.subtotal, originalSubtotal);
      expect(sent.tax, originalTax);
      expect(sent.amount, originalAmount);

      expect(paid.subtotal, originalSubtotal);
      expect(paid.tax, originalTax);
      expect(paid.amount, originalAmount);

      expect(revertedToSent.subtotal, originalSubtotal);
      expect(revertedToSent.tax, originalTax);
      expect(revertedToSent.amount, originalAmount);

      expect(revertedToDraft.subtotal, originalSubtotal);
      expect(revertedToDraft.tax, originalTax);
      expect(revertedToDraft.amount, originalAmount);
    });

    test('InvoiceItem calculates total correctly', () {
      // Simple item
      final item1 = InvoiceItem(
        description: 'Paint',
        quantity: 5.0,
        unitPrice: 20.0,
      );
      expect(item1.total, 100.0);

      // Item with discount
      final item2 = InvoiceItem(
        description: 'Labor',
        quantity: 4.0,
        unitPrice: 50.0,
        discount: 25.0,
      );
      expect(item2.total, 175.0); // (4 * 50) - 25
    });

    test('Status serialization round-trips correctly', () {
      // Test all status values
      for (final status in InvoiceStatus.values) {
        final statusString = Invoice.statusToString(status);
        final parsedStatus = Invoice.statusFromString(statusString);
        expect(parsedStatus, status, reason: 'Failed for status: $status');
      }
    });
  });
}
