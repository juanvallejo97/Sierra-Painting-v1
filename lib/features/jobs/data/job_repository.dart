/// Job Repository - Data Layer
///
/// PURPOSE:
/// Repository pattern for job CRUD operations.
/// Handles Firestore integration with company isolation and geolocation.
///
/// FEATURES:
/// - Create/read/update/delete jobs
/// - Company-scoped queries
/// - Worker assignment management
/// - Geolocation and geofence setup
/// - Status tracking
/// - Search by name or customer
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers/firestore_provider.dart';
import 'package:sierra_painting/core/utils/result.dart';
import 'package:sierra_painting/features/jobs/domain/job.dart';

/// Create job request
class CreateJobRequest {
  final String companyId;
  final String name;
  final String? customerId;
  final String? estimateId;
  final JobLocation location;
  final List<String> assignedWorkerIds;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final double? estimatedCost;

  CreateJobRequest({
    required this.companyId,
    required this.name,
    this.customerId,
    this.estimateId,
    required this.location,
    this.assignedWorkerIds = const [],
    this.startDate,
    this.endDate,
    this.notes,
    this.estimatedCost,
  });
}

/// Update job request
class UpdateJobRequest {
  final String jobId;
  final String? name;
  final String? customerId;
  final JobLocation? location;
  final JobStatus? status;
  final List<String>? assignedWorkerIds;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final double? estimatedCost;
  final double? actualCost;

  UpdateJobRequest({
    required this.jobId,
    this.name,
    this.customerId,
    this.location,
    this.status,
    this.assignedWorkerIds,
    this.startDate,
    this.endDate,
    this.notes,
    this.estimatedCost,
    this.actualCost,
  });
}

/// Job query filters
class JobFilters {
  final JobStatus? status;
  final String? workerId; // Filter jobs assigned to worker
  final String? customerId;
  final DateTime? startDateAfter;
  final DateTime? endDateBefore;

  JobFilters({
    this.status,
    this.workerId,
    this.customerId,
    this.startDateAfter,
    this.endDateBefore,
  });
}

/// Job Repository
class JobRepository {
  final FirebaseFirestore _firestore;

  JobRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  /// Create a new job
  Future<Result<Job, String>> createJob(CreateJobRequest request) async {
    try {
      final now = DateTime.now();
      final job = Job(
        companyId: request.companyId,
        name: request.name,
        customerId: request.customerId,
        estimateId: request.estimateId,
        location: request.location,
        status: JobStatus.pending,
        assignedWorkerIds: request.assignedWorkerIds,
        startDate: request.startDate,
        endDate: request.endDate,
        notes: request.notes,
        estimatedCost: request.estimatedCost,
        createdAt: now,
        updatedAt: now,
      );

      final docRef = await _firestore.collection('jobs').add(job.toFirestore());

      final createdJob = job.copyWith(id: docRef.id);
      return Result.success(createdJob);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Get jobs for a company with filters
  Future<Result<List<Job>, String>> getJobs({
    required String companyId,
    JobFilters? filters,
    String? searchQuery,
    int limit = 50,
  }) async {
    try {
      Query query = _firestore
          .collection('jobs')
          .where('companyId', isEqualTo: companyId)
          .orderBy('createdAt', descending: true)
          .limit(limit);

      // Apply Firestore filters
      if (filters?.status != null) {
        query = query.where(
          'status',
          isEqualTo: filters!.status!.toFirestore(),
        );
      }
      if (filters?.customerId != null) {
        query = query.where('customerId', isEqualTo: filters!.customerId);
      }
      if (filters?.startDateAfter != null) {
        query = query.where(
          'startDate',
          isGreaterThanOrEqualTo: Timestamp.fromDate(filters!.startDateAfter!),
        );
      }

      final snapshot = await query.get();
      var jobs = snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();

      // Client-side filters
      if (filters?.workerId != null) {
        jobs = jobs
            .where((job) => job.isWorkerAssigned(filters!.workerId!))
            .toList();
      }

      // Client-side search
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final lowerQuery = searchQuery.toLowerCase();
        jobs = jobs.where((job) {
          return job.name.toLowerCase().contains(lowerQuery) ||
              job.location.address.toLowerCase().contains(lowerQuery);
        }).toList();
      }

      return Result.success(jobs);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Get a single job by ID
  Future<Result<Job, String>> getJob(String jobId) async {
    try {
      final doc = await _firestore.collection('jobs').doc(jobId).get();

      if (!doc.exists) {
        return Result.failure('Job not found');
      }

      final job = Job.fromFirestore(doc);
      return Result.success(job);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Update job
  Future<Result<Job, String>> updateJob(UpdateJobRequest request) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (request.name != null) updates['name'] = request.name;
      if (request.customerId != null) {
        updates['customerId'] = request.customerId;
      }
      if (request.location != null) {
        updates['location'] = request.location!.toMap();
      }
      if (request.status != null) {
        updates['status'] = request.status!.toFirestore();
      }
      if (request.assignedWorkerIds != null) {
        updates['assignedWorkerIds'] = request.assignedWorkerIds;
      }
      if (request.startDate != null) {
        updates['startDate'] = Timestamp.fromDate(request.startDate!);
      }
      if (request.endDate != null) {
        updates['endDate'] = Timestamp.fromDate(request.endDate!);
      }
      if (request.notes != null) updates['notes'] = request.notes;
      if (request.estimatedCost != null) {
        updates['estimatedCost'] = request.estimatedCost;
      }
      if (request.actualCost != null) {
        updates['actualCost'] = request.actualCost;
      }

      await _firestore.collection('jobs').doc(request.jobId).update(updates);

      // Fetch updated job
      return await getJob(request.jobId);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Assign workers to job
  Future<Result<Job, String>> assignWorkers({
    required String jobId,
    required List<String> workerIds,
  }) async {
    try {
      await _firestore.collection('jobs').doc(jobId).update({
        'assignedWorkerIds': workerIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return await getJob(jobId);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Add worker to job
  Future<Result<Job, String>> addWorker({
    required String jobId,
    required String workerId,
  }) async {
    try {
      await _firestore.collection('jobs').doc(jobId).update({
        'assignedWorkerIds': FieldValue.arrayUnion([workerId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return await getJob(jobId);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Remove worker from job
  Future<Result<Job, String>> removeWorker({
    required String jobId,
    required String workerId,
  }) async {
    try {
      await _firestore.collection('jobs').doc(jobId).update({
        'assignedWorkerIds': FieldValue.arrayRemove([workerId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return await getJob(jobId);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Update job status
  Future<Result<Job, String>> updateStatus({
    required String jobId,
    required JobStatus status,
  }) async {
    try {
      await _firestore.collection('jobs').doc(jobId).update({
        'status': status.toFirestore(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return await getJob(jobId);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Delete job
  Future<Result<void, String>> deleteJob(String jobId) async {
    try {
      await _firestore.collection('jobs').doc(jobId).delete();
      return Result.success(null);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Get active jobs for worker (for dashboard)
  Future<Result<List<Job>, String>> getActiveJobsForWorker({
    required String companyId,
    required String workerId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('jobs')
          .where('companyId', isEqualTo: companyId)
          .where('status', isEqualTo: 'active')
          .where('assignedWorkerIds', arrayContains: workerId)
          .orderBy('startDate')
          .limit(20)
          .get();

      final jobs = snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();
      return Result.success(jobs);
    } catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Stream jobs for real-time updates
  Stream<List<Job>> watchJobs({
    required String companyId,
    JobFilters? filters,
    int limit = 50,
  }) {
    Query query = _firestore
        .collection('jobs')
        .where('companyId', isEqualTo: companyId)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (filters?.status != null) {
      query = query.where('status', isEqualTo: filters!.status!.toFirestore());
    }

    return query.snapshots().map((snapshot) {
      var jobs = snapshot.docs.map((doc) => Job.fromFirestore(doc)).toList();

      // Client-side filter for worker assignment
      if (filters?.workerId != null) {
        jobs = jobs
            .where((job) => job.isWorkerAssigned(filters!.workerId!))
            .toList();
      }

      return jobs;
    });
  }

  /// Map Firestore errors to user-friendly messages
  String _mapError(dynamic error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return 'You don\'t have permission to perform this action.';
        case 'not-found':
          return 'Job not found.';
        case 'unavailable':
          return 'Service temporarily unavailable. Please try again.';
        default:
          return 'An error occurred: ${error.message}';
      }
    }
    return 'An unexpected error occurred: $error';
  }
}

/// Provider for JobRepository
final jobRepositoryProvider = Provider<JobRepository>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return JobRepository(firestore: firestore);
});
