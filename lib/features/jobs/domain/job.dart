/// Job Domain Model with Geolocation
///
/// PURPOSE:
/// Type-safe domain entity for painting jobs.
/// Includes geolocation for time tracking and crew assignment.
///
/// FEATURES:
/// - Job details (name, customer, dates)
/// - Geolocation with adaptive geofence
/// - Worker assignments
/// - Status tracking
/// - Cost estimation
///
/// GEOFENCE STRATEGY (per coach notes):
/// - Urban: 75-100m radius
/// - Suburban: 150m radius
/// - Rural: 250m radius
/// - Per-job override supported
library;

import 'package:cloud_firestore/cloud_firestore.dart';

/// Job status enum
enum JobStatus {
  pending, // Not yet started
  active, // Currently in progress
  paused, // Temporarily paused
  completed, // Finished
  cancelled; // Cancelled

  static JobStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return JobStatus.active;
      case 'paused':
        return JobStatus.paused;
      case 'completed':
        return JobStatus.completed;
      case 'cancelled':
        return JobStatus.cancelled;
      case 'pending':
      default:
        return JobStatus.pending;
    }
  }

  String toFirestore() => name;

  String get displayName {
    switch (this) {
      case JobStatus.pending:
        return 'Pending';
      case JobStatus.active:
        return 'Active';
      case JobStatus.paused:
        return 'Paused';
      case JobStatus.completed:
        return 'Completed';
      case JobStatus.cancelled:
        return 'Cancelled';
    }
  }
}

/// Environment type for adaptive geofence
enum JobEnvironment {
  urban,
  suburban,
  rural;

  static JobEnvironment fromString(String env) {
    switch (env.toLowerCase()) {
      case 'urban':
        return JobEnvironment.urban;
      case 'suburban':
        return JobEnvironment.suburban;
      case 'rural':
        return JobEnvironment.rural;
      default:
        return JobEnvironment.suburban;
    }
  }

  String toFirestore() => name;

  /// Default geofence radius in meters
  double get defaultRadius {
    switch (this) {
      case JobEnvironment.urban:
        return 100.0;
      case JobEnvironment.suburban:
        return 150.0;
      case JobEnvironment.rural:
        return 250.0;
    }
  }
}

/// Geolocation data for job site
class JobLocation {
  final double latitude;
  final double longitude;
  final String address;
  final JobEnvironment environment;
  final double? customRadius; // Optional override

  JobLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    this.environment = JobEnvironment.suburban,
    this.customRadius,
  });

  /// Effective geofence radius (custom or default)
  double get geofenceRadius => customRadius ?? environment.defaultRadius;

  /// Create from Firestore map
  factory JobLocation.fromMap(Map<String, dynamic> map) {
    return JobLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      address: map['address'] as String,
      environment: JobEnvironment.fromString(
        map['environment'] as String? ?? 'suburban',
      ),
      customRadius: map['customRadius'] != null
          ? (map['customRadius'] as num).toDouble()
          : null,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'environment': environment.toFirestore(),
      if (customRadius != null) 'customRadius': customRadius,
    };
  }

  /// Calculate distance to a point in meters (Haversine formula)
  /// TODO: Implement actual distance calculation
  double distanceTo(double lat, double lng) {
    // IMPLEMENTATION NEEDED: Use geolocator package or implement Haversine
    // For now, return approximate value
    final latDiff = (latitude - lat).abs();
    final lngDiff = (longitude - lng).abs();
    return (latDiff + lngDiff) * 111000; // Rough approximation
  }
}

/// Job domain model
class Job {
  final String? id;
  final String companyId;
  final String name;
  final String? customerId;
  final String? estimateId;
  final JobLocation location;
  final JobStatus status;
  final List<String> assignedWorkerIds;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? notes;
  final double? estimatedCost;
  final double? actualCost;
  final DateTime createdAt;
  final DateTime updatedAt;

  Job({
    this.id,
    required this.companyId,
    required this.name,
    this.customerId,
    this.estimateId,
    required this.location,
    this.status = JobStatus.pending,
    this.assignedWorkerIds = const [],
    this.startDate,
    this.endDate,
    this.notes,
    this.estimatedCost,
    this.actualCost,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory Job.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Job(
      id: doc.id,
      companyId: data['companyId'] as String,
      name: data['name'] as String,
      customerId: data['customerId'] as String?,
      estimateId: data['estimateId'] as String?,
      location: JobLocation.fromMap(data['location'] as Map<String, dynamic>),
      status: JobStatus.fromString(data['status'] as String? ?? 'pending'),
      assignedWorkerIds:
          (data['assignedWorkerIds'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      startDate: data['startDate'] != null
          ? (data['startDate'] as Timestamp).toDate()
          : null,
      endDate: data['endDate'] != null
          ? (data['endDate'] as Timestamp).toDate()
          : null,
      notes: data['notes'] as String?,
      estimatedCost: data['estimatedCost'] != null
          ? (data['estimatedCost'] as num).toDouble()
          : null,
      actualCost: data['actualCost'] != null
          ? (data['actualCost'] as num).toDouble()
          : null,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'name': name,
      if (customerId != null) 'customerId': customerId,
      if (estimateId != null) 'estimateId': estimateId,
      'location': location.toMap(),
      // Top-level fields for Cloud Functions (geofence validation)
      'lat': location.latitude,
      'lng': location.longitude,
      'radiusM': location.geofenceRadius,
      'address': location.address,
      'status': status.toFirestore(),
      'assignedWorkerIds': assignedWorkerIds,
      if (startDate != null) 'startDate': Timestamp.fromDate(startDate!),
      if (endDate != null) 'endDate': Timestamp.fromDate(endDate!),
      if (notes != null) 'notes': notes,
      if (estimatedCost != null) 'estimatedCost': estimatedCost,
      if (actualCost != null) 'actualCost': actualCost,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Create a copy with updated fields
  Job copyWith({
    String? id,
    String? companyId,
    String? name,
    String? customerId,
    String? estimateId,
    JobLocation? location,
    JobStatus? status,
    List<String>? assignedWorkerIds,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    double? estimatedCost,
    double? actualCost,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Job(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      name: name ?? this.name,
      customerId: customerId ?? this.customerId,
      estimateId: estimateId ?? this.estimateId,
      location: location ?? this.location,
      status: status ?? this.status,
      assignedWorkerIds: assignedWorkerIds ?? this.assignedWorkerIds,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      notes: notes ?? this.notes,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      actualCost: actualCost ?? this.actualCost,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Check if worker is assigned to this job
  bool isWorkerAssigned(String workerId) {
    return assignedWorkerIds.contains(workerId);
  }

  /// Check if job is active
  bool get isActive => status == JobStatus.active;

  /// Check if job is completed
  bool get isCompleted => status == JobStatus.completed;

  /// Check if location is within geofence
  /// TODO: Implement with actual geolocation service
  bool isWithinGeofence(double lat, double lng) {
    final distance = location.distanceTo(lat, lng);
    return distance <= location.geofenceRadius;
  }
}
