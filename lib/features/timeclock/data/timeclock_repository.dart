/// Timeclock Repository - Data Layer
///
/// PURPOSE:
/// Repository pattern implementation for time clock operations.
/// Centralizes all time clock API calls with:
/// - Type-safe API calls via ApiClient
/// - Offline queue integration
/// - Result-based error handling
/// - RequestId propagation
///
/// RESPONSIBILITIES:
/// - Clock in/out operations
/// - Time entry queries
/// - Offline queue management
/// - Error mapping to domain

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:sierra_painting/core/network/api_client.dart';
import 'package:sierra_painting/core/providers/firestore_provider.dart';
import 'package:sierra_painting/core/services/queue_service.dart';
import 'package:sierra_painting/core/models/queue_item.dart';
import 'package:sierra_painting/core/utils/result.dart';
import 'package:sierra_painting/features/timeclock/domain/time_entry.dart';

/// Clock in request
class ClockInRequest {
  final String jobId;
  final DateTime at;
  final String clientId;
  final GeoPoint? geo;

  ClockInRequest({
    required this.jobId,
    required this.at,
    required this.clientId,
    this.geo,
  });

  Map<String, dynamic> toJson() {
    return {
      'jobId': jobId,
      'at': Timestamp.fromDate(at),
      'clientId': clientId,
      if (geo != null) 'geo': {'lat': geo!.latitude, 'lng': geo!.longitude},
    };
  }
}

/// Clock in response
class ClockInResponse {
  final bool success;
  final String entryId;

  ClockInResponse({required this.success, required this.entryId});

  factory ClockInResponse.fromJson(Map<String, dynamic> json) {
    return ClockInResponse(
      success: json['success'] as bool,
      entryId: json['entryId'] as String,
    );
  }
}

/// Timeclock Repository
class TimeclockRepository {
  final ApiClient _apiClient;
  final FirebaseFirestore _firestore;
  final QueueService? _queueService;
  final Uuid _uuid = const Uuid();

  TimeclockRepository({
    required ApiClient apiClient,
    required FirebaseFirestore firestore,
    QueueService? queueService,
  }) : _apiClient = apiClient,
       _firestore = firestore,
       _queueService = queueService;

  /// Clock in to a job
  ///
  /// Handles both online and offline scenarios:
  /// - Online: Calls Cloud Function directly
  /// - Offline: Queues operation for later sync
  Future<Result<ClockInResponse, String>> clockIn({
    required String jobId,
    GeoPoint? geo,
    bool? isOnline,
  }) async {
    final clientId = _uuid.v4();
    final request = ClockInRequest(
      jobId: jobId,
      at: DateTime.now(),
      clientId: clientId,
      geo: geo,
    );

    // Check if online
    final online = isOnline ?? true; // TODO: Add network connectivity check

    if (!online && _queueService != null) {
      // Queue for offline sync
      try {
        await _queueService!.addToQueue(
          QueueItem(
            id: clientId,
            operation: 'clockIn',
            data: request.toJson(),
            timestamp: DateTime.now(),
            processed: false,
            retryCount: 0,
          ),
        );

        return Result.success(
          ClockInResponse(
            success: true,
            entryId: clientId, // Temporary ID
          ),
        );
      } on QueueFullException catch (e) {
        return Result.failure(e.message);
      } catch (e) {
        return Result.failure('Failed to queue operation: $e');
      }
    }

    // Online: Call Cloud Function
    final result = await _apiClient.call<Map<String, dynamic>>(
      functionName: 'clockIn',
      data: request.toJson(),
    );

    return result.when(
      success: (data) {
        try {
          final response = ClockInResponse.fromJson(data);
          return Result.success(response);
        } catch (e) {
          return Result.failure('Failed to parse response: $e');
        }
      },
      failure: (error) => Result.failure(_mapApiError(error)),
    );
  }

  /// Get time entries for a user
  Future<Result<List<TimeEntry>, String>> getTimeEntries({
    required String userId,
    String? jobId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      Query query = _firestore
          .collectionGroup('timeEntries')
          .where('userId', isEqualTo: userId);

      if (jobId != null) {
        query = query.where('jobId', isEqualTo: jobId);
      }

      if (startDate != null) {
        query = query.where(
          'clockIn',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
        );
      }

      if (endDate != null) {
        query = query.where(
          'clockIn',
          isLessThanOrEqualTo: Timestamp.fromDate(endDate),
        );
      }

      query = query.orderBy('clockIn', descending: true);

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      final entries = snapshot.docs
          .map((doc) => TimeEntry.fromFirestore(doc))
          .toList();

      return Result.success(entries);
    } catch (e) {
      return Result.failure('Failed to fetch time entries: $e');
    }
  }

  /// Get today's time entries for a user
  Future<Result<List<TimeEntry>, String>> getTodayEntries({
    required String userId,
  }) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return getTimeEntries(
      userId: userId,
      startDate: startOfDay,
      endDate: endOfDay,
    );
  }

  /// Get active (open) time entries for a user
  Future<Result<List<TimeEntry>, String>> getActiveEntries({
    required String userId,
    String? jobId,
  }) async {
    try {
      Query query = _firestore
          .collectionGroup('timeEntries')
          .where('userId', isEqualTo: userId)
          .where('clockOut', isEqualTo: null);

      if (jobId != null) {
        query = query.where('jobId', isEqualTo: jobId);
      }

      final snapshot = await query.get();
      final entries = snapshot.docs
          .map((doc) => TimeEntry.fromFirestore(doc))
          .toList();

      return Result.success(entries);
    } catch (e) {
      return Result.failure('Failed to fetch active entries: $e');
    }
  }

  /// Map ApiError to user-friendly message
  String _mapApiError(ApiError error) {
    switch (error.type) {
      case ApiErrorType.timeout:
        return 'Request timed out. Please try again.';
      case ApiErrorType.network:
        return 'Network error. Please check your connection.';
      case ApiErrorType.unauthenticated:
        return 'You must be logged in to perform this action.';
      case ApiErrorType.permissionDenied:
        return 'You don\'t have permission to perform this action.';
      case ApiErrorType.notFound:
        return 'Resource not found.';
      case ApiErrorType.invalidArgument:
        return 'Invalid input: ${error.message}';
      case ApiErrorType.resourceExhausted:
        return 'Too many requests. Please try again later.';
      case ApiErrorType.failedPrecondition:
        return error
            .message; // Use specific message (e.g., "Already clocked in")
      case ApiErrorType.internal:
        return 'Server error. Please try again.';
      case ApiErrorType.unknown:
        return 'An unexpected error occurred: ${error.message}';
    }
  }
}

/// Provider for TimeclockRepository
final timeclockRepositoryProvider = Provider<TimeclockRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final firestore = ref.watch(firestoreProvider);
  final queueService = ref.watch(queueServiceProvider);

  return TimeclockRepository(
    apiClient: apiClient,
    firestore: firestore,
    queueService: queueService,
  );
});
