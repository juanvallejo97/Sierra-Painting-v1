/// Estimate Form Provider
///
/// PURPOSE:
/// Manages estimate creation form state and submission.
/// Handles validation, company ID extraction, and repository interaction.
///
/// FEATURES:
/// - Form state management with Riverpod
/// - Loading/error states
/// - Company isolation via auth claims
/// - Estimate creation with validation
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/features/estimates/data/estimate_repository.dart';
import 'package:sierra_painting/features/estimates/domain/estimate.dart';

/// Form state for estimate creation
class EstimateFormState {
  final bool isLoading;
  final String? error;
  final Estimate? createdEstimate;

  EstimateFormState({this.isLoading = false, this.error, this.createdEstimate});

  EstimateFormState copyWith({
    bool? isLoading,
    String? error,
    Estimate? createdEstimate,
  }) {
    return EstimateFormState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      createdEstimate: createdEstimate ?? this.createdEstimate,
    );
  }
}

/// Estimate form notifier
class EstimateFormNotifier extends Notifier<EstimateFormState> {
  late final EstimateRepository _repository;
  late final FirebaseAuth _auth;

  @override
  EstimateFormState build() {
    _repository = ref.watch(estimateRepositoryProvider);
    _auth = FirebaseAuth.instance;
    return EstimateFormState();
  }

  /// Get current user's company ID from auth claims
  Future<String?> _getCompanyId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final idTokenResult = await user.getIdTokenResult();
    return idTokenResult.claims?['companyId'] as String?;
  }

  /// Create estimate
  Future<void> createEstimate({
    required String customerId,
    String? jobId,
    required List<EstimateItem> items,
    String? notes,
    required DateTime validUntil,
  }) async {
    // Validation
    if (customerId.isEmpty) {
      state = state.copyWith(error: 'Customer ID is required');
      return;
    }

    if (items.isEmpty) {
      state = state.copyWith(error: 'At least one line item is required');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      // Get company ID
      final companyId = await _getCompanyId();
      if (companyId == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'User not authenticated or no company assigned',
        );
        return;
      }

      // Create request
      final request = CreateEstimateRequest(
        companyId: companyId,
        customerId: customerId,
        jobId: jobId?.isNotEmpty == true ? jobId : null,
        items: items,
        notes: notes?.isNotEmpty == true ? notes : null,
        validUntil: validUntil,
      );

      // Call repository
      final result = await _repository.createEstimate(request);

      result.when(
        success: (estimate) {
          state = state.copyWith(isLoading: false, createdEstimate: estimate);
        },
        failure: (error) {
          state = state.copyWith(isLoading: false, error: error);
        },
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Unexpected error: $e');
    }
  }

  /// Reset form state
  void reset() {
    state = EstimateFormState();
  }
}

/// Provider for estimate form
final estimateFormProvider =
    NotifierProvider<EstimateFormNotifier, EstimateFormState>(
      EstimateFormNotifier.new,
    );
