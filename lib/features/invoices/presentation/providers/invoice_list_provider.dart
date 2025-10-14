/// Invoice List Provider
///
/// PURPOSE:
/// Riverpod provider for fetching and managing invoice list state.
/// Handles loading, error, and data states with company isolation.
///
/// FEATURES:
/// - Automatic company ID extraction from auth claims
/// - Loading/error/data states
/// - Refresh capability
/// - Company-scoped data isolation
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers.dart';
import 'package:sierra_painting/features/invoices/data/invoice_repository.dart';
import 'package:sierra_painting/features/invoices/domain/invoice.dart';

/// Provider for invoice list
///
/// Automatically fetches invoices for the current user's company.
/// Returns empty list if no company ID or user not authenticated.
final invoiceListProvider = FutureProvider.autoDispose<List<Invoice>>((
  ref,
) async {
  final repository = ref.watch(invoiceRepositoryProvider);
  final companyId = ref.watch(currentCompanyIdProvider);

  if (companyId == null || companyId.isEmpty) {
    return [];
  }

  final result = await repository.getInvoices(companyId: companyId, limit: 100);

  return result.when(
    success: (invoices) => invoices,
    failure: (error) => throw Exception(error),
  );
});
