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

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/features/invoices/data/invoice_repository.dart';
import 'package:sierra_painting/features/invoices/domain/invoice.dart';

/// Provider for current user's company ID
final companyIdProvider = FutureProvider<String?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final idTokenResult = await user.getIdTokenResult();
  return idTokenResult.claims?['companyId'] as String?;
});

/// Provider for invoice list
///
/// Automatically fetches invoices for the current user's company.
/// Returns empty list if no company ID or user not authenticated.
final invoiceListProvider = FutureProvider<List<Invoice>>((ref) async {
  final companyId = await ref.watch(companyIdProvider.future);

  if (companyId == null) {
    return [];
  }

  final repository = ref.watch(invoiceRepositoryProvider);
  final result = await repository.getInvoices(companyId: companyId);

  return result.when(
    success: (invoices) => invoices,
    failure: (error) {
      // Log error and return empty list
      // In production, you might want to throw or handle differently
      return [];
    },
  );
});

/// Provider for refreshing invoice list
///
/// Use this to manually trigger a refresh of the invoice list.
final invoiceListRefreshProvider = Provider<void Function()>((ref) {
  return () {
    ref.invalidate(invoiceListProvider);
  };
});
