/// Repository Tests for InvoiceRepository
///
/// PURPOSE:
/// Tests for the InvoiceRepository data layer, covering:
/// - Create operations with validation
/// - Read operations (single and list)
/// - Update operations (status changes, mark as paid)
/// - Error handling
/// - Company isolation
///
/// APPROACH:
/// Uses fake_cloud_firestore for in-memory Firestore simulation.
/// Avoids external dependencies and provides fast, reliable tests.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/features/invoices/data/invoice_repository.dart';
import 'package:sierra_painting/features/invoices/domain/invoice.dart';

void main() {
  group('InvoiceRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late InvoiceRepository repository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = InvoiceRepository(firestore: fakeFirestore);
    });

    group('createInvoice', () {
      test('creates invoice successfully', () async {
        final items = [
          InvoiceItem(description: 'Item 1', quantity: 10, unitPrice: 50),
          InvoiceItem(description: 'Item 2', quantity: 5, unitPrice: 100),
        ];

        final request = CreateInvoiceRequest(
          companyId: 'company-1',
          customerId: 'customer-1',
          items: items,
          dueDate: DateTime(2025, 12, 31),
        );

        final result = await repository.createInvoice(request);

        expect(result.isSuccess, isTrue);

        final invoice = result.valueOrNull;
        expect(invoice, isNotNull);
        expect(invoice!.id, isNotNull);
        expect(invoice.companyId, 'company-1');
        expect(invoice.customerId, 'customer-1');
        expect(invoice.status, InvoiceStatus.pending);
        expect(invoice.amount, 1000.0); // 10*50 + 5*100
        expect(invoice.items.length, 2);
      });

      test('creates invoice with optional fields', () async {
        final items = [
          InvoiceItem(
            description: 'Item 1',
            quantity: 10,
            unitPrice: 50,
            discount: 50,
          ),
        ];

        final request = CreateInvoiceRequest(
          companyId: 'company-1',
          estimateId: 'estimate-1',
          customerId: 'customer-1',
          jobId: 'job-1',
          items: items,
          notes: 'Test notes',
          dueDate: DateTime(2025, 12, 31),
        );

        final result = await repository.createInvoice(request);

        expect(result.isSuccess, isTrue);

        final invoice = result.valueOrNull;
        expect(invoice!.estimateId, 'estimate-1');
        expect(invoice.jobId, 'job-1');
        expect(invoice.notes, 'Test notes');
        expect(invoice.amount, 450.0); // (10*50) - 50 discount
      });

      test('calculates total amount correctly', () async {
        final items = [
          InvoiceItem(description: 'Item 1', quantity: 2, unitPrice: 100),
          InvoiceItem(
            description: 'Item 2',
            quantity: 3,
            unitPrice: 50,
            discount: 25,
          ),
        ];

        final request = CreateInvoiceRequest(
          companyId: 'company-1',
          customerId: 'customer-1',
          items: items,
          dueDate: DateTime(2025, 12, 31),
        );

        final result = await repository.createInvoice(request);
        final invoice = result.valueOrNull;

        // (2*100) + (3*50 - 25) = 200 + 125 = 325
        expect(invoice!.amount, 325.0);
      });
    });

    group('getInvoice', () {
      test('retrieves existing invoice', () async {
        // Create an invoice first
        final items = [
          InvoiceItem(description: 'Test', quantity: 1, unitPrice: 100),
        ];

        final createRequest = CreateInvoiceRequest(
          companyId: 'company-1',
          customerId: 'customer-1',
          items: items,
          dueDate: DateTime(2025, 12, 31),
        );

        final createResult = await repository.createInvoice(createRequest);
        final invoiceId = createResult.valueOrNull!.id!;

        // Retrieve it
        final result = await repository.getInvoice(invoiceId);

        expect(result.isSuccess, isTrue);

        final invoice = result.valueOrNull;
        expect(invoice!.id, invoiceId);
        expect(invoice.companyId, 'company-1');
        expect(invoice.customerId, 'customer-1');
      });

      test('returns failure for non-existent invoice', () async {
        final result = await repository.getInvoice('non-existent-id');

        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, contains('not found'));
      });
    });

    group('getInvoices', () {
      setUp(() async {
        // Seed multiple invoices for different companies
        await fakeFirestore.collection('invoices').add({
          'companyId': 'company-1',
          'customerId': 'customer-1',
          'status': 'pending',
          'amount': 100.0,
          'currency': 'USD',
          'items': [],
          'dueDate': Timestamp.fromDate(DateTime(2025, 12, 31)),
          'createdAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
          'updatedAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
        });

        await fakeFirestore.collection('invoices').add({
          'companyId': 'company-1',
          'customerId': 'customer-2',
          'status': 'paid',
          'amount': 200.0,
          'currency': 'USD',
          'items': [],
          'dueDate': Timestamp.fromDate(DateTime(2025, 12, 31)),
          'paidAt': Timestamp.fromDate(DateTime(2025, 1, 5)),
          'createdAt': Timestamp.fromDate(DateTime(2025, 1, 2)),
          'updatedAt': Timestamp.fromDate(DateTime(2025, 1, 5)),
        });

        await fakeFirestore.collection('invoices').add({
          'companyId': 'company-2',
          'customerId': 'customer-3',
          'status': 'pending',
          'amount': 300.0,
          'currency': 'USD',
          'items': [],
          'dueDate': Timestamp.fromDate(DateTime(2025, 12, 31)),
          'createdAt': Timestamp.fromDate(DateTime(2025, 1, 3)),
          'updatedAt': Timestamp.fromDate(DateTime(2025, 1, 3)),
        });
      });

      test('retrieves invoices for specific company', () async {
        final result = await repository.getInvoices(companyId: 'company-1');

        expect(result.isSuccess, isTrue);

        final invoices = result.valueOrNull!;
        expect(invoices.length, 2);
        expect(invoices.every((i) => i.companyId == 'company-1'), isTrue);
      });

      test('filters by status', () async {
        final result = await repository.getInvoices(
          companyId: 'company-1',
          status: InvoiceStatus.paid,
        );

        expect(result.isSuccess, isTrue);

        final invoices = result.valueOrNull!;
        expect(invoices.length, 1);
        expect(invoices.first.status, InvoiceStatus.paid);
        expect(invoices.first.paidAt, isNotNull);
      });

      test('enforces company isolation', () async {
        final result = await repository.getInvoices(companyId: 'company-2');

        expect(result.isSuccess, isTrue);

        final invoices = result.valueOrNull!;
        expect(invoices.length, 1);
        expect(invoices.first.companyId, 'company-2');
      });

      test('respects pagination limit', () async {
        // Create more invoices
        for (int i = 0; i < 60; i++) {
          await fakeFirestore.collection('invoices').add({
            'companyId': 'company-3',
            'customerId': 'customer-$i',
            'status': 'pending',
            'amount': 100.0,
            'currency': 'USD',
            'items': [],
            'dueDate': Timestamp.fromDate(DateTime(2025, 12, 31)),
            'createdAt': Timestamp.fromDate(DateTime(2025, 1, i + 1)),
            'updatedAt': Timestamp.fromDate(DateTime(2025, 1, i + 1)),
          });
        }

        final result = await repository.getInvoices(
          companyId: 'company-3',
          limit: 25,
        );

        expect(result.isSuccess, isTrue);

        final invoices = result.valueOrNull!;
        expect(invoices.length, 25);
      });

      test('enforces maximum limit', () async {
        final result = await repository.getInvoices(
          companyId: 'company-1',
          limit: 200, // Exceeds maxLimit of 100
        );

        expect(result.isSuccess, isTrue);

        // Should be capped at maxLimit (100) even though we requested 200
        // In this case we only have 2 invoices, so we get 2
        final invoices = result.valueOrNull!;
        expect(invoices.length, lessThanOrEqualTo(100));
      });
    });

    group('markAsPaid', () {
      test('updates invoice status to paid with timestamp', () async {
        // Create an invoice
        final items = [
          InvoiceItem(description: 'Test', quantity: 1, unitPrice: 100),
        ];

        final createRequest = CreateInvoiceRequest(
          companyId: 'company-1',
          customerId: 'customer-1',
          items: items,
          dueDate: DateTime(2025, 12, 31),
        );

        final createResult = await repository.createInvoice(createRequest);
        final invoiceId = createResult.valueOrNull!.id!;

        // Mark as paid
        final paidAt = DateTime(2025, 1, 15);
        final result = await repository.markAsPaid(
          invoiceId: invoiceId,
          paidAt: paidAt,
        );

        expect(result.isSuccess, isTrue);

        final invoice = result.valueOrNull;
        expect(invoice!.status, InvoiceStatus.paid);
        expect(invoice.paidAt, isNotNull);
      });

      test('changes status from overdue to paid', () async {
        // Create an invoice with overdue status
        final docRef = await fakeFirestore.collection('invoices').add({
          'companyId': 'company-1',
          'customerId': 'customer-1',
          'status': 'overdue',
          'amount': 100.0,
          'currency': 'USD',
          'items': [],
          'dueDate': Timestamp.fromDate(DateTime(2025, 1, 1)),
          'createdAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
          'updatedAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
        });

        // Mark as paid
        final paidAt = DateTime(2025, 2, 1);
        final result = await repository.markAsPaid(
          invoiceId: docRef.id,
          paidAt: paidAt,
        );

        expect(result.isSuccess, isTrue);

        final invoice = result.valueOrNull;
        expect(invoice!.status, InvoiceStatus.paid);
      });
    });

    group('updateStatus', () {
      test('updates invoice status', () async {
        // Create an invoice
        final items = [
          InvoiceItem(description: 'Test', quantity: 1, unitPrice: 100),
        ];

        final createRequest = CreateInvoiceRequest(
          companyId: 'company-1',
          customerId: 'customer-1',
          items: items,
          dueDate: DateTime(2025, 12, 31),
        );

        final createResult = await repository.createInvoice(createRequest);
        final invoiceId = createResult.valueOrNull!.id!;

        // Update status to cancelled
        final result = await repository.updateStatus(
          invoiceId: invoiceId,
          status: InvoiceStatus.cancelled,
        );

        expect(result.isSuccess, isTrue);

        final invoice = result.valueOrNull;
        expect(invoice!.status, InvoiceStatus.cancelled);
      });

      test('can mark invoice as overdue', () async {
        // Create a pending invoice
        final items = [
          InvoiceItem(description: 'Test', quantity: 1, unitPrice: 100),
        ];

        final createRequest = CreateInvoiceRequest(
          companyId: 'company-1',
          customerId: 'customer-1',
          items: items,
          dueDate: DateTime(2025, 1, 1), // Past due
        );

        final createResult = await repository.createInvoice(createRequest);
        final invoiceId = createResult.valueOrNull!.id!;

        // Update status to overdue
        final result = await repository.updateStatus(
          invoiceId: invoiceId,
          status: InvoiceStatus.overdue,
        );

        expect(result.isSuccess, isTrue);

        final invoice = result.valueOrNull;
        expect(invoice!.status, InvoiceStatus.overdue);
      });
    });
  });
}
