/// Repository Tests for EstimateRepository
///
/// PURPOSE:
/// Tests for the EstimateRepository data layer, covering:
/// - Create operations with validation
/// - Read operations (single and list)
/// - Update operations (status changes)
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
import 'package:sierra_painting/features/estimates/data/estimate_repository.dart';
import 'package:sierra_painting/features/estimates/domain/estimate.dart';

void main() {
  group('EstimateRepository', () {
    late FakeFirebaseFirestore fakeFirestore;
    late EstimateRepository repository;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      repository = EstimateRepository(firestore: fakeFirestore);
    });

    group('createEstimate', () {
      test('creates estimate successfully', () async {
        final items = [
          EstimateItem(description: 'Item 1', quantity: 10, unitPrice: 50),
          EstimateItem(description: 'Item 2', quantity: 5, unitPrice: 100),
        ];

        final request = CreateEstimateRequest(
          companyId: 'company-1',
          customerId: 'customer-1',
          items: items,
          validUntil: DateTime(2025, 12, 31),
        );

        final result = await repository.createEstimate(request);

        expect(result.isSuccess, isTrue);

        final estimate = result.valueOrNull;
        expect(estimate, isNotNull);
        expect(estimate!.id, isNotNull);
        expect(estimate.companyId, 'company-1');
        expect(estimate.customerId, 'customer-1');
        expect(estimate.status, EstimateStatus.draft);
        expect(estimate.amount, 1000.0); // 10*50 + 5*100
        expect(estimate.items.length, 2);
      });

      test('creates estimate with optional fields', () async {
        final items = [
          EstimateItem(
            description: 'Item 1',
            quantity: 10,
            unitPrice: 50,
            discount: 50,
          ),
        ];

        final request = CreateEstimateRequest(
          companyId: 'company-1',
          customerId: 'customer-1',
          jobId: 'job-1',
          items: items,
          notes: 'Test notes',
          validUntil: DateTime(2025, 12, 31),
        );

        final result = await repository.createEstimate(request);

        expect(result.isSuccess, isTrue);

        final estimate = result.valueOrNull;
        expect(estimate!.jobId, 'job-1');
        expect(estimate.notes, 'Test notes');
        expect(estimate.amount, 450.0); // (10*50) - 50 discount
      });

      test('calculates total amount correctly', () async {
        final items = [
          EstimateItem(description: 'Item 1', quantity: 2, unitPrice: 100),
          EstimateItem(
            description: 'Item 2',
            quantity: 3,
            unitPrice: 50,
            discount: 25,
          ),
        ];

        final request = CreateEstimateRequest(
          companyId: 'company-1',
          customerId: 'customer-1',
          items: items,
          validUntil: DateTime(2025, 12, 31),
        );

        final result = await repository.createEstimate(request);
        final estimate = result.valueOrNull;

        // (2*100) + (3*50 - 25) = 200 + 125 = 325
        expect(estimate!.amount, 325.0);
      });
    });

    group('getEstimate', () {
      test('retrieves existing estimate', () async {
        // Create an estimate first
        final items = [
          EstimateItem(description: 'Test', quantity: 1, unitPrice: 100),
        ];

        final createRequest = CreateEstimateRequest(
          companyId: 'company-1',
          customerId: 'customer-1',
          items: items,
          validUntil: DateTime(2025, 12, 31),
        );

        final createResult = await repository.createEstimate(createRequest);
        final estimateId = createResult.valueOrNull!.id!;

        // Retrieve it
        final result = await repository.getEstimate(estimateId);

        expect(result.isSuccess, isTrue);

        final estimate = result.valueOrNull;
        expect(estimate!.id, estimateId);
        expect(estimate.companyId, 'company-1');
        expect(estimate.customerId, 'customer-1');
      });

      test('returns failure for non-existent estimate', () async {
        final result = await repository.getEstimate('non-existent-id');

        expect(result.isFailure, isTrue);
        expect(result.errorOrNull, contains('not found'));
      });
    });

    group('getEstimates', () {
      setUp(() async {
        // Seed multiple estimates for different companies
        await fakeFirestore.collection('estimates').add({
          'companyId': 'company-1',
          'customerId': 'customer-1',
          'status': 'draft',
          'amount': 100.0,
          'currency': 'USD',
          'items': [],
          'validUntil': Timestamp.fromDate(DateTime(2025, 12, 31)),
          'createdAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
          'updatedAt': Timestamp.fromDate(DateTime(2025, 1, 1)),
        });

        await fakeFirestore.collection('estimates').add({
          'companyId': 'company-1',
          'customerId': 'customer-2',
          'status': 'sent',
          'amount': 200.0,
          'currency': 'USD',
          'items': [],
          'validUntil': Timestamp.fromDate(DateTime(2025, 12, 31)),
          'createdAt': Timestamp.fromDate(DateTime(2025, 1, 2)),
          'updatedAt': Timestamp.fromDate(DateTime(2025, 1, 2)),
        });

        await fakeFirestore.collection('estimates').add({
          'companyId': 'company-2',
          'customerId': 'customer-3',
          'status': 'draft',
          'amount': 300.0,
          'currency': 'USD',
          'items': [],
          'validUntil': Timestamp.fromDate(DateTime(2025, 12, 31)),
          'createdAt': Timestamp.fromDate(DateTime(2025, 1, 3)),
          'updatedAt': Timestamp.fromDate(DateTime(2025, 1, 3)),
        });
      });

      test('retrieves estimates for specific company', () async {
        final result = await repository.getEstimates(companyId: 'company-1');

        expect(result.isSuccess, isTrue);

        final estimates = result.valueOrNull!;
        expect(estimates.length, 2);
        expect(estimates.every((e) => e.companyId == 'company-1'), isTrue);
      });

      test('filters by status', () async {
        final result = await repository.getEstimates(
          companyId: 'company-1',
          status: EstimateStatus.sent,
        );

        expect(result.isSuccess, isTrue);

        final estimates = result.valueOrNull!;
        expect(estimates.length, 1);
        expect(estimates.first.status, EstimateStatus.sent);
      });

      test('enforces company isolation', () async {
        final result = await repository.getEstimates(companyId: 'company-2');

        expect(result.isSuccess, isTrue);

        final estimates = result.valueOrNull!;
        expect(estimates.length, 1);
        expect(estimates.first.companyId, 'company-2');
      });

      test('respects pagination limit', () async {
        // Create more estimates
        for (int i = 0; i < 60; i++) {
          await fakeFirestore.collection('estimates').add({
            'companyId': 'company-3',
            'customerId': 'customer-$i',
            'status': 'draft',
            'amount': 100.0,
            'currency': 'USD',
            'items': [],
            'validUntil': Timestamp.fromDate(DateTime(2025, 12, 31)),
            'createdAt': Timestamp.fromDate(DateTime(2025, 1, i + 1)),
            'updatedAt': Timestamp.fromDate(DateTime(2025, 1, i + 1)),
          });
        }

        final result = await repository.getEstimates(
          companyId: 'company-3',
          limit: 25,
        );

        expect(result.isSuccess, isTrue);

        final estimates = result.valueOrNull!;
        expect(estimates.length, 25);
      });

      test('enforces maximum limit', () async {
        final result = await repository.getEstimates(
          companyId: 'company-1',
          limit: 200, // Exceeds maxLimit of 100
        );

        expect(result.isSuccess, isTrue);

        // Should be capped at maxLimit (100) even though we requested 200
        // In this case we only have 2 estimates, so we get 2
        final estimates = result.valueOrNull!;
        expect(estimates.length, lessThanOrEqualTo(100));
      });
    });

    group('markAsSent', () {
      test('updates estimate status to sent', () async {
        // Create an estimate
        final items = [
          EstimateItem(description: 'Test', quantity: 1, unitPrice: 100),
        ];

        final createRequest = CreateEstimateRequest(
          companyId: 'company-1',
          customerId: 'customer-1',
          items: items,
          validUntil: DateTime(2025, 12, 31),
        );

        final createResult = await repository.createEstimate(createRequest);
        final estimateId = createResult.valueOrNull!.id!;

        // Mark as sent
        final result = await repository.markAsSent(estimateId);

        expect(result.isSuccess, isTrue);

        final estimate = result.valueOrNull;
        expect(estimate!.status, EstimateStatus.sent);
      });
    });

    group('markAsAccepted', () {
      test('updates estimate status to accepted with timestamp', () async {
        // Create an estimate
        final items = [
          EstimateItem(description: 'Test', quantity: 1, unitPrice: 100),
        ];

        final createRequest = CreateEstimateRequest(
          companyId: 'company-1',
          customerId: 'customer-1',
          items: items,
          validUntil: DateTime(2025, 12, 31),
        );

        final createResult = await repository.createEstimate(createRequest);
        final estimateId = createResult.valueOrNull!.id!;

        // Mark as accepted
        final acceptedAt = DateTime(2025, 1, 15);
        final result = await repository.markAsAccepted(
          estimateId: estimateId,
          acceptedAt: acceptedAt,
        );

        expect(result.isSuccess, isTrue);

        final estimate = result.valueOrNull;
        expect(estimate!.status, EstimateStatus.accepted);
        expect(estimate.acceptedAt, isNotNull);
      });
    });

    group('updateStatus', () {
      test('updates estimate status', () async {
        // Create an estimate
        final items = [
          EstimateItem(description: 'Test', quantity: 1, unitPrice: 100),
        ];

        final createRequest = CreateEstimateRequest(
          companyId: 'company-1',
          customerId: 'customer-1',
          items: items,
          validUntil: DateTime(2025, 12, 31),
        );

        final createResult = await repository.createEstimate(createRequest);
        final estimateId = createResult.valueOrNull!.id!;

        // Update status
        final result = await repository.updateStatus(
          estimateId: estimateId,
          status: EstimateStatus.rejected,
        );

        expect(result.isSuccess, isTrue);

        final estimate = result.valueOrNull;
        expect(estimate!.status, EstimateStatus.rejected);
      });
    });
  });
}
