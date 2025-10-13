/// Invoice Form Provider
///
/// PURPOSE:
/// Manages invoice creation form state and submission.
/// Handles validation, company ID extraction, and repository interaction.
///
/// FEATURES:
/// - Form state management with Riverpod
/// - Loading/error states
/// - Company isolation via auth claims
/// - Invoice creation with validation
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/features/invoices/data/invoice_repository.dart';
import 'package:sierra_painting/features/invoices/domain/invoice.dart';

/// Form state for invoice creation
class InvoiceFormState {
  final bool isLoading;
  final String? error;
  final Invoice? createdInvoice;

  InvoiceFormState({this.isLoading = false, this.error, this.createdInvoice});

  InvoiceFormState copyWith({
    bool? isLoading,
    String? error,
    Invoice? createdInvoice,
  }) {
    return InvoiceFormState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      createdInvoice: createdInvoice ?? this.createdInvoice,
    );
  }
}

/// Invoice form notifier
class InvoiceFormNotifier extends Notifier<InvoiceFormState> {
  late final InvoiceRepository _repository;
  late final FirebaseAuth _auth;

  @override
  InvoiceFormState build() {
    _repository = ref.watch(invoiceRepositoryProvider);
    _auth = FirebaseAuth.instance;
    return InvoiceFormState();
  }

  /// Get current user's company ID from auth claims
  Future<String?> _getCompanyId() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final idTokenResult = await user.getIdTokenResult();
    return idTokenResult.claims?['companyId'] as String?;
  }

  /// Create invoice
  Future<void> createInvoice({
    required String customerId,
    String? jobId,
    required List<InvoiceItem> items,
    String? notes,
    required DateTime dueDate,
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
      final request = CreateInvoiceRequest(
        companyId: companyId,
        customerId: customerId,
        jobId: jobId?.isNotEmpty == true ? jobId : null,
        items: items,
        notes: notes?.isNotEmpty == true ? notes : null,
        dueDate: dueDate,
      );

      // Call repository
      final result = await _repository.createInvoice(request);

      result.when(
        success: (invoice) {
          state = state.copyWith(isLoading: false, createdInvoice: invoice);
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
    state = InvoiceFormState();
  }
}

/// Provider for invoice form
final invoiceFormProvider =
    NotifierProvider<InvoiceFormNotifier, InvoiceFormState>(
      InvoiceFormNotifier.new,
    );
