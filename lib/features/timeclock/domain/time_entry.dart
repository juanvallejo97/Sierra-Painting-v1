/// Time Entry Domain Model with Idempotency
///
/// PURPOSE:
/// Type-safe domain entity for worker time tracking.
/// Includes idempotency for offline/retry scenarios.
///
/// FEATURES:
/// - Clock in/out with timestamps
/// - Geolocation capture with accuracy
/// - Idempotency token (clientEventId) for deduplication
/// - Approval workflow with audit trail
/// - Geofence validation
/// - 12-hour auto-clock-out support
///
/// SECURITY (per coach notes):
/// - Workers can only create their own entries
/// - Admin edits via Cloud Function with audit log
/// - Approved entries are locked from client-side edits
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

/// Time entry status
enum TimeEntryStatus {
  active, // Currently clocked in
  pending, // Clocked out, awaiting approval
  approved, // Approved by admin
  flagged, // Flagged for review
  disputed; // Worker disputed the entry

  static TimeEntryStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return TimeEntryStatus.active;
      case 'pending':
        return TimeEntryStatus.pending;
      case 'approved':
        return TimeEntryStatus.approved;
      case 'flagged':
        return TimeEntryStatus.flagged;
      case 'disputed':
        return TimeEntryStatus.disputed;
      default:
        return TimeEntryStatus.pending;
    }
  }

  String toFirestore() => name;
}

/// Custom GeoPoint with accuracy
class TimeEntryGeoPoint {
  final double latitude;
  final double longitude;
  final double? accuracy; // Accuracy in meters
  final DateTime timestamp;

  TimeEntryGeoPoint({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    required this.timestamp,
  });

  factory TimeEntryGeoPoint.fromMap(Map<String, dynamic> map) {
    return TimeEntryGeoPoint(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: map['accuracy'] != null
          ? (map['accuracy'] as num).toDouble()
          : null,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  /// Convert to Firestore GeoPoint
  GeoPoint toGeoPoint() => GeoPoint(latitude, longitude);
}

/// Audit record for edits
class AuditRecord {
  final String editedBy; // User ID who made the edit
  final DateTime editedAt;
  final String reason;
  final Map<String, dynamic> changes; // Before/after values

  AuditRecord({
    required this.editedBy,
    required this.editedAt,
    required this.reason,
    required this.changes,
  });

  factory AuditRecord.fromMap(Map<String, dynamic> map) {
    return AuditRecord(
      editedBy: map['editedBy'] as String,
      editedAt: (map['editedAt'] as Timestamp).toDate(),
      reason: map['reason'] as String,
      changes: Map<String, dynamic>.from(map['changes'] as Map),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'editedBy': editedBy,
      'editedAt': Timestamp.fromDate(editedAt),
      'reason': reason,
      'changes': changes,
    };
  }
}

class TimeEntry {
  final String? id;

  // Idempotency & Identity
  final String clientEventId; // For offline deduplication
  final String companyId; // Renamed from orgId for consistency
  final String workerId; // Renamed from userId for clarity
  final String jobId;

  // Status & Workflow
  final TimeEntryStatus status;

  // Time tracking
  final DateTime clockIn;
  final DateTime? clockOut;

  // Geolocation with accuracy
  final TimeEntryGeoPoint? clockInLocation;
  final TimeEntryGeoPoint? clockOutLocation;
  final bool clockInGeofenceValid;
  final bool? clockOutGeofenceValid;

  // Legacy support
  final GeoPoint? geo; // Legacy field, use clockInLocation instead
  final bool gpsMissing;

  // Break tracking
  final List<String> breakIds; // References to BreakEntry documents

  // Metadata
  final String? notes;
  final String? disputeReason;
  final List<AuditRecord> auditLog;
  final String source; // 'mobile', 'web', 'admin'
  final DateTime createdAt;
  final DateTime updatedAt;

  // Offline support
  final String origin; // 'online' | 'offline'
  final bool needsReview; // Flag for admin review
  final String? deviceId; // Device identifier
  final DateTime? submittedAt; // When synced to server
  final GeoPoint? approxLocation; // Approximate location if GPS unavailable

  // Approval
  final String? approvedBy;
  final DateTime? approvedAt;

  TimeEntry({
    this.id,
    String? clientEventId,
    String? companyId, // Support both names
    String? orgId, // Legacy
    String? workerId, // Support both names
    String? userId, // Legacy
    required this.jobId,
    this.status = TimeEntryStatus.active,
    required this.clockIn,
    this.clockOut,
    this.clockInLocation,
    this.clockOutLocation,
    this.clockInGeofenceValid = true,
    this.clockOutGeofenceValid,
    this.geo,
    this.gpsMissing = false,
    this.breakIds = const [],
    this.notes,
    this.disputeReason,
    this.auditLog = const [],
    this.source = 'mobile',
    required this.createdAt,
    required this.updatedAt,
    this.origin = 'online',
    this.needsReview = false,
    this.deviceId,
    this.submittedAt,
    this.approxLocation,
    this.approvedBy,
    this.approvedAt,
  }) : clientEventId = clientEventId ?? const Uuid().v4(),
       companyId = companyId ?? orgId ?? '',
       workerId = workerId ?? userId ?? '';

  /// Calculate duration in hours (excluding breaks)
  /// TODO: Subtract break time from total
  double? get durationHours {
    if (clockOut == null) return null;
    final duration = clockOut!.difference(clockIn);
    return duration.inMinutes / 60.0;
  }

  /// Check if entry is currently active (clocked in)
  bool get isActive => status == TimeEntryStatus.active && clockOut == null;

  /// Check if entry is approved and locked
  bool get isApproved => status == TimeEntryStatus.approved;

  /// Check if entry is flagged for review
  bool get isFlagged =>
      status == TimeEntryStatus.flagged || status == TimeEntryStatus.disputed;

  /// Check if geofence was invalid at clock-in or clock-out
  bool get hasGeofenceViolation =>
      !clockInGeofenceValid || (clockOutGeofenceValid == false);

  /// Check if entry exceeds 12 hours (auto clock-out threshold)
  bool get exceedsTwelveHours {
    final duration = (clockOut ?? DateTime.now()).difference(clockIn);
    return duration.inHours >= 12;
  }

  /// Create from Firestore document
  factory TimeEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Support both clockIn/clockInAt naming (Cloud Function uses clockInAt)
    final clockInTimestamp =
        data['clockInAt'] as Timestamp? ?? data['clockIn'] as Timestamp?;
    final clockOutTimestamp =
        data['clockOutAt'] as Timestamp? ?? data['clockOut'] as Timestamp?;

    // Support both clockInLocation and clockInLoc (Cloud Function uses clockInLoc)
    TimeEntryGeoPoint? parseLocation(String locKey, String geoKey) {
      if (data[locKey] != null) {
        return TimeEntryGeoPoint.fromMap(data[locKey] as Map<String, dynamic>);
      } else if (data[geoKey] != null) {
        final geoPoint = data[geoKey] as GeoPoint;
        return TimeEntryGeoPoint(
          latitude: geoPoint.latitude,
          longitude: geoPoint.longitude,
          timestamp: clockInTimestamp?.toDate() ?? DateTime.now(),
        );
      }
      return null;
    }

    return TimeEntry(
      id: doc.id,
      clientEventId: data['clientEventId'] as String? ?? const Uuid().v4(),
      orgId: data['orgId'] as String?,
      companyId: data['companyId'] as String?,
      userId: data['userId'] as String?,
      workerId: data['workerId'] as String?,
      jobId: data['jobId'] as String,
      status: data['status'] != null
          ? TimeEntryStatus.fromString(data['status'] as String)
          : TimeEntryStatus.active,
      clockIn: clockInTimestamp?.toDate() ?? DateTime.now(),
      clockOut: clockOutTimestamp?.toDate(),
      clockInLocation: parseLocation('clockInLocation', 'clockInLoc'),
      clockOutLocation: parseLocation('clockOutLocation', 'clockOutLoc'),
      clockInGeofenceValid:
          data['clockInGeofenceValid'] as bool? ??
          data['geoOk'] as bool? ??
          true,
      clockOutGeofenceValid: data['clockOutGeofenceValid'] as bool?,
      geo: data['geo'] as GeoPoint?,
      gpsMissing: data['gpsMissing'] as bool? ?? false,
      breakIds:
          (data['breakIds'] as List?)?.map((e) => e as String).toList() ?? [],
      notes: data['notes'] as String?,
      disputeReason: data['disputeReason'] as String?,
      auditLog:
          (data['auditLog'] as List?)
              ?.map((e) => AuditRecord.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      source: data['source'] as String? ?? 'function',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      origin: data['origin'] as String? ?? 'online',
      needsReview: data['needsReview'] as bool? ?? false,
      deviceId: data['deviceId'] as String?,
      submittedAt: data['submittedAt'] != null
          ? (data['submittedAt'] as Timestamp).toDate()
          : null,
      approxLocation: data['approxLocation'] as GeoPoint?,
      approvedBy: data['approvedBy'] as String?,
      approvedAt: data['approvedAt'] != null
          ? (data['approvedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'clientEventId': clientEventId,
      'companyId': companyId,
      'orgId': companyId, // Legacy support
      'workerId': workerId,
      'userId': workerId, // Legacy support
      'jobId': jobId,
      'status': status.toFirestore(),
      'clockIn': Timestamp.fromDate(clockIn),
      if (clockOut != null) 'clockOut': Timestamp.fromDate(clockOut!),
      if (clockInLocation != null) 'clockInLocation': clockInLocation!.toMap(),
      if (clockOutLocation != null)
        'clockOutLocation': clockOutLocation!.toMap(),
      'clockInGeofenceValid': clockInGeofenceValid,
      if (clockOutGeofenceValid != null)
        'clockOutGeofenceValid': clockOutGeofenceValid,
      if (geo != null) 'geo': geo,
      'gpsMissing': gpsMissing,
      'breakIds': breakIds,
      if (notes != null) 'notes': notes,
      if (disputeReason != null) 'disputeReason': disputeReason,
      'auditLog': auditLog.map((e) => e.toMap()).toList(),
      'source': source,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'origin': origin,
      'needsReview': needsReview,
      if (deviceId != null) 'deviceId': deviceId,
      if (submittedAt != null) 'submittedAt': Timestamp.fromDate(submittedAt!),
      if (approxLocation != null) 'approxLocation': approxLocation,
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
    };
  }

  TimeEntry copyWith({
    String? id,
    String? clientEventId,
    String? companyId,
    String? workerId,
    String? jobId,
    TimeEntryStatus? status,
    DateTime? clockIn,
    DateTime? clockOut,
    TimeEntryGeoPoint? clockInLocation,
    TimeEntryGeoPoint? clockOutLocation,
    bool? clockInGeofenceValid,
    bool? clockOutGeofenceValid,
    GeoPoint? geo,
    bool? gpsMissing,
    List<String>? breakIds,
    String? notes,
    String? disputeReason,
    List<AuditRecord>? auditLog,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? origin,
    bool? needsReview,
    String? deviceId,
    DateTime? submittedAt,
    GeoPoint? approxLocation,
    String? approvedBy,
    DateTime? approvedAt,
  }) {
    return TimeEntry(
      id: id ?? this.id,
      clientEventId: clientEventId ?? this.clientEventId,
      companyId: companyId ?? this.companyId,
      workerId: workerId ?? this.workerId,
      jobId: jobId ?? this.jobId,
      status: status ?? this.status,
      clockIn: clockIn ?? this.clockIn,
      clockOut: clockOut ?? this.clockOut,
      clockInLocation: clockInLocation ?? this.clockInLocation,
      clockOutLocation: clockOutLocation ?? this.clockOutLocation,
      clockInGeofenceValid: clockInGeofenceValid ?? this.clockInGeofenceValid,
      clockOutGeofenceValid:
          clockOutGeofenceValid ?? this.clockOutGeofenceValid,
      geo: geo ?? this.geo,
      gpsMissing: gpsMissing ?? this.gpsMissing,
      breakIds: breakIds ?? this.breakIds,
      notes: notes ?? this.notes,
      disputeReason: disputeReason ?? this.disputeReason,
      auditLog: auditLog ?? this.auditLog,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      origin: origin ?? this.origin,
      needsReview: needsReview ?? this.needsReview,
      deviceId: deviceId ?? this.deviceId,
      submittedAt: submittedAt ?? this.submittedAt,
      approxLocation: approxLocation ?? this.approxLocation,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }
}
