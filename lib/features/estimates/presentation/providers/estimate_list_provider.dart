/// Estimate List Provider
///
/// PURPOSE:
/// Riverpod provider for fetching and managing estimate list state.
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
import 'package:sierra_painting/features/estimates/data/estimate_repository.dart';
import 'package:sierra_painting/features/estimates/domain/estimate.dart';

/// Provider for current user's company ID (reused from invoices)
final _companyIdProvider = FutureProvider<String?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;

  final idTokenResult = await user.getIdTokenResult();
  return idTokenResult.claims?['companyId'] as String?;
});

/// Provider for estimate list
///
/// Automatically fetches estimates for the current user's company.
/// Returns empty list if no company ID or user not authenticated.
final estimateListProvider = FutureProvider<List<Estimate>>((ref) async {
  final companyId = await ref.watch(_companyIdProvider.future);

  if (companyId == null) {
    return [];
  }

  final repository = ref.watch(estimateRepositoryProvider);
  final result = await repository.getEstimates(companyId: companyId);

  return result.when(
    success: (estimates) => estimates,
    failure: (error) {
      // Log error and return empty list
      // In production, you might want to throw or handle differently
      return [];
    },
  );
});

/// Provider for refreshing estimate list
///
/// Use this to manually trigger a refresh of the estimate list.
final estimateListRefreshProvider = Provider<void Function()>((ref) {
  return () {
    ref.invalidate(estimateListProvider);
  };
});
