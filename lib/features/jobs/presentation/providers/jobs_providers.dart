/// Jobs List Provider
///
/// PURPOSE:
/// Provides list of jobs for the current company.
library;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/features/jobs/data/job_repository.dart';
import 'package:sierra_painting/features/jobs/domain/job.dart';

/// Jobs list provider
final jobsListProvider = FutureProvider<List<Job>>((ref) async {
  final repository = ref.watch(jobRepositoryProvider);

  // Get current user's company ID
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('User not authenticated');
  }

  final idTokenResult = await user.getIdTokenResult();
  final companyId = idTokenResult.claims?['companyId'] as String?;

  if (companyId == null) {
    throw Exception('No company assigned to user');
  }

  // Fetch jobs
  final result = await repository.getJobs(companyId: companyId);

  return result.when(
    success: (jobs) => jobs,
    failure: (error) => throw Exception(error),
  );
});

/// Provider for active jobs only
final activeJobsProvider = FutureProvider<List<Job>>((ref) async {
  final allJobs = await ref.watch(jobsListProvider.future);
  return allJobs.where((job) => job.status == JobStatus.active).toList();
});
