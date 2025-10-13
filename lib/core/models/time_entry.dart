/// TimeEntry Model (Canonical v2.0)
///
/// Simplified model matching canonical schema in docs/schemas/time_entry.md
/// Includes legacy fallbacks for migration period (until 2025-10-26)
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'location.dart';

class TimeEntry {
  final String entryId;
  final String companyId;
  final String userId;
  final String jobId;
  final DateTime clockInAt;
  final bool clockInGeofenceValid;
  final GeoPointLike? clockInLocation;
  final DateTime? clockOutAt;
  final bool? clockOutGeofenceValid;
  final GeoPointLike? clockOutLocation;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  TimeEntry({
    required this.entryId,
    required this.companyId,
    required this.userId,
    required this.jobId,
    required this.clockInAt,
    required this.clockInGeofenceValid,
    this.clockInLocation,
    this.clockOutAt,
    this.clockOutGeofenceValid,
    this.clockOutLocation,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  /// Create from Firestore with legacy fallbacks
  factory TimeEntry.fromMap(Map<String, dynamic> m, String id) {
    // LEGACY FALLBACKS (remove after 2025-10-26)
    final clockInTs = (m['clockInAt'] ?? m['clockIn']) as Timestamp?;
    final clockOutTs = (m['clockOutAt'] ?? m['clockOut']) as Timestamp?;
    final userId = (m['userId'] ?? m['workerId']) as String?;

    // Parse location (support GeoPoint or nested {lat,lng})
    GeoPointLike? parseLocation(dynamic loc) {
      if (loc == null) return null;
      if (loc is GeoPoint) {
        return GeoPointLike(lat: loc.latitude, lng: loc.longitude);
      }
      if (loc is Map<String, dynamic>) {
        return GeoPointLike.fromMap(loc);
      }
      return null;
    }

    return TimeEntry(
      entryId: id,
      companyId: m['companyId'] as String,
      userId: userId ?? '',
      jobId: m['jobId'] as String,
      clockInAt: (clockInTs ?? Timestamp.now()).toDate(),
      clockInGeofenceValid:
          (m['clockInGeofenceValid'] ?? m['geoOkIn'] ?? false) as bool,
      clockInLocation: parseLocation(m['clockInLocation'] ?? m['clockInLoc']),
      clockOutAt: clockOutTs?.toDate(),
      clockOutGeofenceValid:
          (m['clockOutGeofenceValid'] ?? m['geoOkOut']) as bool?,
      clockOutLocation: parseLocation(
        m['clockOutLocation'] ?? m['clockOutLoc'],
      ),
      notes: m['notes'] as String?,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory TimeEntry.fromFirestore(DocumentSnapshot doc) {
    return TimeEntry.fromMap(doc.data() as Map<String, dynamic>, doc.id);
  }

  /// Convert to Firestore (canonical fields only)
  Map<String, dynamic> toFirestore() {
    return {
      'entryId': entryId,
      'companyId': companyId,
      'userId': userId,
      'jobId': jobId,
      'clockInAt': Timestamp.fromDate(clockInAt),
      'clockInGeofenceValid': clockInGeofenceValid,
      if (clockInLocation != null) 'clockInLocation': clockInLocation!.toMap(),
      if (clockOutAt != null) 'clockOutAt': Timestamp.fromDate(clockOutAt!),
      if (clockOutGeofenceValid != null)
        'clockOutGeofenceValid': clockOutGeofenceValid,
      if (clockOutLocation != null)
        'clockOutLocation': clockOutLocation!.toMap(),
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'createdAt': Timestamp.fromDate(createdAt!),
      if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
    };
  }

  /// Check if entry is currently active (no clock out)
  bool get isActive => clockOutAt == null;

  /// Calculate duration in hours
  double? get durationHours {
    if (clockOutAt == null) return null;
    final duration = clockOutAt!.difference(clockInAt);
    return duration.inMinutes / 60.0;
  }

  /// Check if either geofence check failed
  bool get hasGeofenceViolation =>
      !clockInGeofenceValid || (clockOutGeofenceValid == false);

  TimeEntry copyWith({
    String? entryId,
    String? companyId,
    String? userId,
    String? jobId,
    DateTime? clockInAt,
    bool? clockInGeofenceValid,
    GeoPointLike? clockInLocation,
    DateTime? clockOutAt,
    bool? clockOutGeofenceValid,
    GeoPointLike? clockOutLocation,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimeEntry(
      entryId: entryId ?? this.entryId,
      companyId: companyId ?? this.companyId,
      userId: userId ?? this.userId,
      jobId: jobId ?? this.jobId,
      clockInAt: clockInAt ?? this.clockInAt,
      clockInGeofenceValid: clockInGeofenceValid ?? this.clockInGeofenceValid,
      clockInLocation: clockInLocation ?? this.clockInLocation,
      clockOutAt: clockOutAt ?? this.clockOutAt,
      clockOutGeofenceValid:
          clockOutGeofenceValid ?? this.clockOutGeofenceValid,
      clockOutLocation: clockOutLocation ?? this.clockOutLocation,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'TimeEntry(id: $entryId, user: $userId, job: $jobId, '
      'in: $clockInAt, out: $clockOutAt)';
}
