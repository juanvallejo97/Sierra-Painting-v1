/// Company Settings Domain Model
///
/// PURPOSE:
/// Centralized company configuration and preferences.
/// Includes timezone for proper timesheet grouping and pay period calculations.
///
/// TIMEZONE HANDLING:
/// - Uses IANA timezone strings (e.g., "America/New_York", "America/Los_Angeles")
/// - Client computes timesheet week/day ranges in company timezone
/// - Server stores all timestamps in UTC (no timezone conversions server-side)
/// - Critical for avoiding pay period boundary bugs with DST transitions
///
/// USAGE:
/// - Fetch once on app start and cache
/// - Use timezone for all date range calculations in timesheets
/// - Update via admin settings screen
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class CompanySettings {
  final String companyId;
  final String timezone; // IANA timezone (e.g., "America/New_York")
  final String? defaultHourlyRate; // Default billing rate for time entries
  final bool requireGeofence; // Enforce geofence for all clock operations
  final int maxShiftHours; // Maximum shift duration before auto clock-out
  final bool autoApproveTime; // Automatically approve time entries
  final DateTime createdAt;
  final DateTime updatedAt;

  CompanySettings({
    required this.companyId,
    this.timezone = 'America/New_York', // Default to US Eastern
    this.defaultHourlyRate,
    this.requireGeofence = true,
    this.maxShiftHours = 12,
    this.autoApproveTime = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from Firestore document
  factory CompanySettings.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CompanySettings(
      companyId: doc.id,
      timezone: data['timezone'] as String? ?? 'America/New_York',
      defaultHourlyRate: data['defaultHourlyRate'] as String?,
      requireGeofence: data['requireGeofence'] as bool? ?? true,
      maxShiftHours: data['maxShiftHours'] as int? ?? 12,
      autoApproveTime: data['autoApproveTime'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'timezone': timezone,
      if (defaultHourlyRate != null) 'defaultHourlyRate': defaultHourlyRate,
      'requireGeofence': requireGeofence,
      'maxShiftHours': maxShiftHours,
      'autoApproveTime': autoApproveTime,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  CompanySettings copyWith({
    String? companyId,
    String? timezone,
    String? defaultHourlyRate,
    bool? requireGeofence,
    int? maxShiftHours,
    bool? autoApproveTime,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanySettings(
      companyId: companyId ?? this.companyId,
      timezone: timezone ?? this.timezone,
      defaultHourlyRate: defaultHourlyRate ?? this.defaultHourlyRate,
      requireGeofence: requireGeofence ?? this.requireGeofence,
      maxShiftHours: maxShiftHours ?? this.maxShiftHours,
      autoApproveTime: autoApproveTime ?? this.autoApproveTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Validate IANA timezone string (basic check)
  /// For production, use timezone package to validate against known timezones
  static bool isValidTimezone(String tz) {
    // Basic validation: must contain "/" and be reasonable length
    return tz.contains('/') && tz.length >= 5 && tz.length <= 50;
  }
}
