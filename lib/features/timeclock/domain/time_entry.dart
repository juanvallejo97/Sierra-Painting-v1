/// Domain model for time entry
///
/// PURPOSE:
/// Type-safe domain entity for time clock entries.
/// Separates domain logic from data layer representation.

import 'package:cloud_firestore/cloud_firestore.dart';

class TimeEntry {
  final String? id;
  final String orgId;
  final String userId;
  final String jobId;
  final DateTime clockIn;
  final DateTime? clockOut;
  final GeoPoint? geo;
  final bool gpsMissing;
  final String clientId;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;

  TimeEntry({
    this.id,
    required this.orgId,
    required this.userId,
    required this.jobId,
    required this.clockIn,
    this.clockOut,
    this.geo,
    this.gpsMissing = false,
    required this.clientId,
    this.source = 'mobile',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Calculate duration in hours
  double? get durationHours {
    if (clockOut == null) return null;
    return clockOut!.difference(clockIn).inSeconds / 3600.0;
  }

  /// Check if entry is currently active (not clocked out)
  bool get isActive => clockOut == null;

  /// Create from Firestore document
  factory TimeEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TimeEntry(
      id: doc.id,
      orgId: data['orgId'] as String,
      userId: data['userId'] as String,
      jobId: data['jobId'] as String,
      clockIn: (data['clockIn'] as Timestamp).toDate(),
      clockOut: data['clockOut'] != null
          ? (data['clockOut'] as Timestamp).toDate()
          : null,
      geo: data['geo'] as GeoPoint?,
      gpsMissing: data['gpsMissing'] as bool? ?? false,
      clientId: data['clientId'] as String,
      source: data['source'] as String? ?? 'mobile',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'orgId': orgId,
      'userId': userId,
      'jobId': jobId,
      'clockIn': Timestamp.fromDate(clockIn),
      'clockOut': clockOut != null ? Timestamp.fromDate(clockOut!) : null,
      'geo': geo,
      'gpsMissing': gpsMissing,
      'clientId': clientId,
      'source': source,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  TimeEntry copyWith({
    String? id,
    String? orgId,
    String? userId,
    String? jobId,
    DateTime? clockIn,
    DateTime? clockOut,
    GeoPoint? geo,
    bool? gpsMissing,
    String? clientId,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TimeEntry(
      id: id ?? this.id,
      orgId: orgId ?? this.orgId,
      userId: userId ?? this.userId,
      jobId: jobId ?? this.jobId,
      clockIn: clockIn ?? this.clockIn,
      clockOut: clockOut ?? this.clockOut,
      geo: geo ?? this.geo,
      gpsMissing: gpsMissing ?? this.gpsMissing,
      clientId: clientId ?? this.clientId,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
