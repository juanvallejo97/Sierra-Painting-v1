import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/features/invoices/domain/invoice.dart';

void main() {
  group('InvoiceItem', () {
    test('creates instance with required fields', () {
      final item = InvoiceItem(
        description: 'Interior painting',
        quantity: 10.0,
        unitPrice: 50.0,
      );

      expect(item.description, 'Interior painting');
      expect(item.quantity, 10.0);
      expect(item.unitPrice, 50.0);
      expect(item.discount, isNull);
    });

    test('creates instance with discount', () {
      final item = InvoiceItem(
        description: 'Exterior painting',
        quantity: 5.0,
        unitPrice: 100.0,
        discount: 50.0,
      );

      expect(item.discount, 50.0);
    });

    group('total', () {
      test('calculates total without discount', () {
        final item = InvoiceItem(
          description: 'Test',
          quantity: 10.0,
          unitPrice: 50.0,
        );

        expect(item.total, 500.0);
      });

      test('calculates total with discount', () {
        final item = InvoiceItem(
          description: 'Test',
          quantity: 10.0,
          unitPrice: 50.0,
          discount: 50.0,
        );

        expect(item.total, 450.0); // 500 - 50
      });

      test('handles fractional quantities and prices', () {
        final item = InvoiceItem(
          description: 'Test',
          quantity: 2.5,
          unitPrice: 33.50,
        );

        expect(item.total, closeTo(83.75, 0.01));
      });
    });

    group('toMap', () {
      test('serializes without discount', () {
        final item = InvoiceItem(
          description: 'Test',
          quantity: 10.0,
          unitPrice: 50.0,
        );

        final map = item.toMap();

        expect(map['description'], 'Test');
        expect(map['quantity'], 10.0);
        expect(map['unitPrice'], 50.0);
        expect(map.containsKey('discount'), isFalse);
      });

      test('serializes with discount', () {
        final item = InvoiceItem(
          description: 'Test',
          quantity: 10.0,
          unitPrice: 50.0,
          discount: 50.0,
        );

        final map = item.toMap();

        expect(map['discount'], 50.0);
      });
    });

    group('fromMap', () {
      test('deserializes without discount', () {
        final map = {'description': 'Test', 'quantity': 10, 'unitPrice': 50};

        final item = InvoiceItem.fromMap(map);

        expect(item.description, 'Test');
        expect(item.quantity, 10.0);
        expect(item.unitPrice, 50.0);
        expect(item.discount, isNull);
      });

      test('deserializes with discount', () {
        final map = {
          'description': 'Test',
          'quantity': 10,
          'unitPrice': 50,
          'discount': 50,
        };

        final item = InvoiceItem.fromMap(map);

        expect(item.discount, 50.0);
      });

      test('handles double values', () {
        final map = {
          'description': 'Test',
          'quantity': 10.5,
          'unitPrice': 50.25,
          'discount': 25.50,
        };

        final item = InvoiceItem.fromMap(map);

        expect(item.quantity, 10.5);
        expect(item.unitPrice, 50.25);
        expect(item.discount, 25.50);
      });
    });
  });

  group('Invoice', () {
    final now = DateTime(2025, 1, 15);
    final dueDate = DateTime(2025, 2, 15);
    final items = [
      InvoiceItem(description: 'Item 1', quantity: 10, unitPrice: 50),
      InvoiceItem(description: 'Item 2', quantity: 5, unitPrice: 100),
    ];

    test('creates instance with required fields', () {
      final invoice = Invoice(
        companyId: 'company-1',
        customerId: 'customer-1',
        customerName: 'Test Customer',
        amount: 1000.0,
        subtotal: 900.0,
        tax: 100.0,
        items: items,
        dueDate: dueDate,
        createdAt: now,
        updatedAt: now,
      );

      expect(invoice.companyId, 'company-1');
      expect(invoice.customerId, 'customer-1');
      expect(invoice.amount, 1000.0);
      expect(invoice.items, items);
      expect(invoice.dueDate, dueDate);
      expect(invoice.status, InvoiceStatus.draft); // default for new invoices
      expect(invoice.currency, 'USD'); // default
      expect(invoice.id, isNull);
      expect(invoice.estimateId, isNull);
      expect(invoice.jobId, isNull);
      expect(invoice.notes, isNull);
      expect(invoice.paidAt, isNull);
    });

    test('creates instance with all fields', () {
      final paidAt = DateTime(2025, 1, 20);
      final invoice = Invoice(
        id: 'invoice-1',
        companyId: 'company-1',
        estimateId: 'estimate-1',
        customerId: 'customer-1',
        customerName: 'Test Customer',
        jobId: 'job-1',
        status: InvoiceStatus.paid,
        amount: 1000.0,
        subtotal: 900.0,
        tax: 100.0,
        currency: 'EUR',
        items: items,
        notes: 'Test notes',
        dueDate: dueDate,
        paidAt: paidAt,
        createdAt: now,
        updatedAt: paidAt,
      );

      expect(invoice.id, 'invoice-1');
      expect(invoice.estimateId, 'estimate-1');
      expect(invoice.jobId, 'job-1');
      expect(invoice.status, InvoiceStatus.paid);
      expect(invoice.currency, 'EUR');
      expect(invoice.notes, 'Test notes');
      expect(invoice.paidAt, paidAt);
    });

    group('isOverdue', () {
      test('returns false when status is paid', () {
        final pastDue = DateTime.now().subtract(const Duration(days: 30));
        final invoice = Invoice(
          companyId: 'company-1',
          customerId: 'customer-1',
          customerName: 'Test Customer',
          status: InvoiceStatus.paid,
          amount: 1000.0,
          subtotal: 900.0,
          tax: 100.0,
          items: items,
          dueDate: pastDue,
          createdAt: now,
          updatedAt: now,
        );

        expect(invoice.isOverdue, isFalse);
      });

      test('returns false when status is cancelled', () {
        final pastDue = DateTime.now().subtract(const Duration(days: 30));
        final invoice = Invoice(
          companyId: 'company-1',
          customerId: 'customer-1',
          customerName: 'Test Customer',
          status: InvoiceStatus.cancelled,
          amount: 1000.0,
          subtotal: 900.0,
          tax: 100.0,
          items: items,
          dueDate: pastDue,
          createdAt: now,
          updatedAt: now,
        );

        expect(invoice.isOverdue, isFalse);
      });

      test('returns true when past due date and pending', () {
        final pastDue = DateTime.now().subtract(const Duration(days: 1));
        final invoice = Invoice(
          companyId: 'company-1',
          customerId: 'customer-1',
          customerName: 'Test Customer',
          status: InvoiceStatus.pending,
          amount: 1000.0,
          subtotal: 900.0,
          tax: 100.0,
          items: items,
          dueDate: pastDue,
          createdAt: now,
          updatedAt: now,
        );

        expect(invoice.isOverdue, isTrue);
      });

      test('returns false when not yet due', () {
        final futureDue = DateTime.now().add(const Duration(days: 30));
        final invoice = Invoice(
          companyId: 'company-1',
          customerId: 'customer-1',
          customerName: 'Test Customer',
          status: InvoiceStatus.pending,
          amount: 1000.0,
          subtotal: 900.0,
          tax: 100.0,
          items: items,
          dueDate: futureDue,
          createdAt: now,
          updatedAt: now,
        );

        expect(invoice.isOverdue, isFalse);
      });
    });

    group('toFirestore', () {
      test('serializes all fields correctly', () {
        final paidAt = DateTime(2025, 1, 20);
        final invoice = Invoice(
          id: 'invoice-1',
          companyId: 'company-1',
          estimateId: 'estimate-1',
          customerId: 'customer-1',
          customerName: 'Test Customer',
          jobId: 'job-1',
          status: InvoiceStatus.paid,
          amount: 1000.0,
          subtotal: 900.0,
          tax: 100.0,
          currency: 'EUR',
          items: items,
          notes: 'Test notes',
          dueDate: dueDate,
          paidAt: paidAt,
          createdAt: now,
          updatedAt: paidAt,
        );

        final map = invoice.toFirestore();

        expect(map['companyId'], 'company-1');
        expect(map['estimateId'], 'estimate-1');
        expect(map['customerId'], 'customer-1');
        expect(map['jobId'], 'job-1');
        expect(map['status'], 'paid');
        expect(map['amount'], 1000.0);
        expect(map['currency'], 'EUR');
        expect(map['notes'], 'Test notes');
        expect(map['items'], isA<List>());
        expect((map['items'] as List).length, 2);
      });

      test('excludes null optional fields', () {
        final invoice = Invoice(
          companyId: 'company-1',
          customerId: 'customer-1',
          customerName: 'Test Customer',
          amount: 1000.0,
          subtotal: 900.0,
          tax: 100.0,
          items: items,
          dueDate: dueDate,
          createdAt: now,
          updatedAt: now,
        );

        final map = invoice.toFirestore();

        expect(map.containsKey('estimateId'), isFalse);
        expect(map.containsKey('jobId'), isFalse);
        expect(map.containsKey('notes'), isFalse);
        expect(map.containsKey('paidAt'), isFalse);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final invoice = Invoice(
          companyId: 'company-1',
          customerId: 'customer-1',
          customerName: 'Test Customer',
          amount: 1000.0,
          subtotal: 900.0,
          tax: 100.0,
          items: items,
          dueDate: dueDate,
          createdAt: now,
          updatedAt: now,
        );

        final paidAt = DateTime(2025, 1, 20);
        final updated = invoice.copyWith(
          status: InvoiceStatus.paid,
          paidAt: paidAt,
        );

        expect(updated.companyId, invoice.companyId);
        expect(updated.status, InvoiceStatus.paid);
        expect(updated.paidAt, paidAt);
      });

      test('preserves original values when no updates', () {
        final invoice = Invoice(
          id: 'invoice-1',
          companyId: 'company-1',
          customerId: 'customer-1',
          customerName: 'Test Customer',
          status: InvoiceStatus.paid,
          amount: 1000.0,
          subtotal: 900.0,
          tax: 100.0,
          currency: 'EUR',
          items: items,
          notes: 'Test',
          dueDate: dueDate,
          createdAt: now,
          updatedAt: now,
        );

        final copy = invoice.copyWith();

        expect(copy.id, invoice.id);
        expect(copy.companyId, invoice.companyId);
        expect(copy.customerId, invoice.customerId);
        expect(copy.status, invoice.status);
        expect(copy.amount, invoice.amount);
        expect(copy.currency, invoice.currency);
        expect(copy.items, invoice.items);
        expect(copy.notes, invoice.notes);
      });
    });

    group('status conversion', () {
      test('statusFromString converts all statuses', () {
        expect(Invoice.statusFromString('pending'), InvoiceStatus.pending);
        expect(Invoice.statusFromString('paid'), InvoiceStatus.paid);
        expect(Invoice.statusFromString('overdue'), InvoiceStatus.overdue);
        expect(Invoice.statusFromString('cancelled'), InvoiceStatus.cancelled);
      });

      test('statusFromString defaults to pending for unknown', () {
        expect(Invoice.statusFromString('unknown'), InvoiceStatus.pending);
        expect(Invoice.statusFromString(''), InvoiceStatus.pending);
      });

      test('statusToString converts all statuses', () {
        expect(Invoice.statusToString(InvoiceStatus.pending), 'pending');
        expect(Invoice.statusToString(InvoiceStatus.paid), 'paid');
        expect(Invoice.statusToString(InvoiceStatus.overdue), 'overdue');
        expect(Invoice.statusToString(InvoiceStatus.cancelled), 'cancelled');
      });
    });
  });
}
