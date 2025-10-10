import 'package:flutter_test/flutter_test.dart';
import 'package:sierra_painting/features/estimates/domain/estimate.dart';

void main() {
  group('EstimateItem', () {
    test('creates instance with required fields', () {
      final item = EstimateItem(
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
      final item = EstimateItem(
        description: 'Exterior painting',
        quantity: 5.0,
        unitPrice: 100.0,
        discount: 50.0,
      );

      expect(item.discount, 50.0);
    });

    group('total', () {
      test('calculates total without discount', () {
        final item = EstimateItem(
          description: 'Test',
          quantity: 10.0,
          unitPrice: 50.0,
        );

        expect(item.total, 500.0);
      });

      test('calculates total with discount', () {
        final item = EstimateItem(
          description: 'Test',
          quantity: 10.0,
          unitPrice: 50.0,
          discount: 50.0,
        );

        expect(item.total, 450.0); // 500 - 50
      });

      test('handles fractional quantities and prices', () {
        final item = EstimateItem(
          description: 'Test',
          quantity: 2.5,
          unitPrice: 33.50,
        );

        expect(item.total, closeTo(83.75, 0.01));
      });
    });

    group('toMap', () {
      test('serializes without discount', () {
        final item = EstimateItem(
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
        final item = EstimateItem(
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

        final item = EstimateItem.fromMap(map);

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

        final item = EstimateItem.fromMap(map);

        expect(item.discount, 50.0);
      });

      test('handles double values', () {
        final map = {
          'description': 'Test',
          'quantity': 10.5,
          'unitPrice': 50.25,
          'discount': 25.50,
        };

        final item = EstimateItem.fromMap(map);

        expect(item.quantity, 10.5);
        expect(item.unitPrice, 50.25);
        expect(item.discount, 25.50);
      });
    });
  });

  group('Estimate', () {
    final now = DateTime(2025, 1, 15);
    final validUntil = DateTime(2025, 2, 15);
    final items = [
      EstimateItem(description: 'Item 1', quantity: 10, unitPrice: 50),
      EstimateItem(description: 'Item 2', quantity: 5, unitPrice: 100),
    ];

    test('creates instance with required fields', () {
      final estimate = Estimate(
        companyId: 'company-1',
        customerId: 'customer-1',
        amount: 1000.0,
        items: items,
        validUntil: validUntil,
        createdAt: now,
        updatedAt: now,
      );

      expect(estimate.companyId, 'company-1');
      expect(estimate.customerId, 'customer-1');
      expect(estimate.amount, 1000.0);
      expect(estimate.items, items);
      expect(estimate.validUntil, validUntil);
      expect(estimate.status, EstimateStatus.draft); // default
      expect(estimate.currency, 'USD'); // default
      expect(estimate.id, isNull);
      expect(estimate.jobId, isNull);
      expect(estimate.notes, isNull);
      expect(estimate.acceptedAt, isNull);
    });

    test('creates instance with all fields', () {
      final acceptedAt = DateTime(2025, 1, 20);
      final estimate = Estimate(
        id: 'estimate-1',
        companyId: 'company-1',
        customerId: 'customer-1',
        jobId: 'job-1',
        status: EstimateStatus.accepted,
        amount: 1000.0,
        currency: 'EUR',
        items: items,
        notes: 'Test notes',
        validUntil: validUntil,
        acceptedAt: acceptedAt,
        createdAt: now,
        updatedAt: acceptedAt,
      );

      expect(estimate.id, 'estimate-1');
      expect(estimate.jobId, 'job-1');
      expect(estimate.status, EstimateStatus.accepted);
      expect(estimate.currency, 'EUR');
      expect(estimate.notes, 'Test notes');
      expect(estimate.acceptedAt, acceptedAt);
    });

    group('isExpired', () {
      test('returns false when status is accepted', () {
        final pastValid = DateTime.now().subtract(const Duration(days: 30));
        final estimate = Estimate(
          companyId: 'company-1',
          customerId: 'customer-1',
          status: EstimateStatus.accepted,
          amount: 1000.0,
          items: items,
          validUntil: pastValid,
          createdAt: now,
          updatedAt: now,
        );

        expect(estimate.isExpired, isFalse);
      });

      test('returns false when status is rejected', () {
        final pastValid = DateTime.now().subtract(const Duration(days: 30));
        final estimate = Estimate(
          companyId: 'company-1',
          customerId: 'customer-1',
          status: EstimateStatus.rejected,
          amount: 1000.0,
          items: items,
          validUntil: pastValid,
          createdAt: now,
          updatedAt: now,
        );

        expect(estimate.isExpired, isFalse);
      });

      test('returns true when past valid date and draft', () {
        final pastValid = DateTime.now().subtract(const Duration(days: 1));
        final estimate = Estimate(
          companyId: 'company-1',
          customerId: 'customer-1',
          status: EstimateStatus.draft,
          amount: 1000.0,
          items: items,
          validUntil: pastValid,
          createdAt: now,
          updatedAt: now,
        );

        expect(estimate.isExpired, isTrue);
      });

      test('returns false when still valid', () {
        final futureValid = DateTime.now().add(const Duration(days: 30));
        final estimate = Estimate(
          companyId: 'company-1',
          customerId: 'customer-1',
          status: EstimateStatus.sent,
          amount: 1000.0,
          items: items,
          validUntil: futureValid,
          createdAt: now,
          updatedAt: now,
        );

        expect(estimate.isExpired, isFalse);
      });
    });

    group('toFirestore', () {
      test('serializes all fields correctly', () {
        final acceptedAt = DateTime(2025, 1, 20);
        final estimate = Estimate(
          id: 'estimate-1',
          companyId: 'company-1',
          customerId: 'customer-1',
          jobId: 'job-1',
          status: EstimateStatus.accepted,
          amount: 1000.0,
          currency: 'EUR',
          items: items,
          notes: 'Test notes',
          validUntil: validUntil,
          acceptedAt: acceptedAt,
          createdAt: now,
          updatedAt: acceptedAt,
        );

        final map = estimate.toFirestore();

        expect(map['companyId'], 'company-1');
        expect(map['customerId'], 'customer-1');
        expect(map['jobId'], 'job-1');
        expect(map['status'], 'accepted');
        expect(map['amount'], 1000.0);
        expect(map['currency'], 'EUR');
        expect(map['notes'], 'Test notes');
        expect(map['items'], isA<List>());
        expect((map['items'] as List).length, 2);
      });

      test('excludes null optional fields', () {
        final estimate = Estimate(
          companyId: 'company-1',
          customerId: 'customer-1',
          amount: 1000.0,
          items: items,
          validUntil: validUntil,
          createdAt: now,
          updatedAt: now,
        );

        final map = estimate.toFirestore();

        expect(map.containsKey('jobId'), isFalse);
        expect(map.containsKey('notes'), isFalse);
        expect(map.containsKey('acceptedAt'), isFalse);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final estimate = Estimate(
          companyId: 'company-1',
          customerId: 'customer-1',
          amount: 1000.0,
          items: items,
          validUntil: validUntil,
          createdAt: now,
          updatedAt: now,
        );

        final acceptedAt = DateTime(2025, 1, 20);
        final updated = estimate.copyWith(
          status: EstimateStatus.accepted,
          acceptedAt: acceptedAt,
        );

        expect(updated.companyId, estimate.companyId);
        expect(updated.status, EstimateStatus.accepted);
        expect(updated.acceptedAt, acceptedAt);
      });

      test('preserves original values when no updates', () {
        final estimate = Estimate(
          id: 'estimate-1',
          companyId: 'company-1',
          customerId: 'customer-1',
          status: EstimateStatus.accepted,
          amount: 1000.0,
          currency: 'EUR',
          items: items,
          notes: 'Test',
          validUntil: validUntil,
          createdAt: now,
          updatedAt: now,
        );

        final copy = estimate.copyWith();

        expect(copy.id, estimate.id);
        expect(copy.companyId, estimate.companyId);
        expect(copy.customerId, estimate.customerId);
        expect(copy.status, estimate.status);
        expect(copy.amount, estimate.amount);
        expect(copy.currency, estimate.currency);
        expect(copy.items, estimate.items);
        expect(copy.notes, estimate.notes);
      });
    });

    group('status conversion', () {
      test('statusFromString converts all statuses', () {
        expect(Estimate.statusFromString('draft'), EstimateStatus.draft);
        expect(Estimate.statusFromString('sent'), EstimateStatus.sent);
        expect(Estimate.statusFromString('accepted'), EstimateStatus.accepted);
        expect(Estimate.statusFromString('rejected'), EstimateStatus.rejected);
        expect(Estimate.statusFromString('expired'), EstimateStatus.expired);
      });

      test('statusFromString defaults to draft for unknown', () {
        expect(Estimate.statusFromString('unknown'), EstimateStatus.draft);
        expect(Estimate.statusFromString(''), EstimateStatus.draft);
      });

      test('statusToString converts all statuses', () {
        expect(Estimate.statusToString(EstimateStatus.draft), 'draft');
        expect(Estimate.statusToString(EstimateStatus.sent), 'sent');
        expect(Estimate.statusToString(EstimateStatus.accepted), 'accepted');
        expect(Estimate.statusToString(EstimateStatus.rejected), 'rejected');
        expect(Estimate.statusToString(EstimateStatus.expired), 'expired');
      });
    });
  });
}
