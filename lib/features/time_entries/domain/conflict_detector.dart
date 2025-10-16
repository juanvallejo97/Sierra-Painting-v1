/// PHASE 2: SKELETON CODE - Time Entry Conflict Detector
///
/// PURPOSE:
/// - Detect overlapping time entries (same worker, overlapping times)
/// - Detect DST transition issues (spring forward, fall back)
/// - Detect missing break periods (e.g., 8+ hours without break)
/// - Suggest quick fixes for common issues
/// - Alert on suspicious patterns (e.g., 24h shifts, backdating)

library conflict_detector;

// ============================================================================
// DATA STRUCTURES
// ============================================================================

enum ConflictSeverity {
  critical, // Blocks submission (overlaps, impossible times)
  warning, // Suggests review (long shifts, missing breaks)
  info, // FYI only (DST transitions, unusual patterns)
}

enum ConflictType {
  overlap, // Two entries overlap in time
  dstSpringForward, // Missing time due to DST
  dstFallBack, // Ambiguous time due to DST
  missingBreak, // No break in 8+ hour shift
  excessiveHours, // Shift over 12 hours
  backdated, // Entry created for past date
  futureEntry, // Entry created for future date
  negativeTime, // Clock-out before clock-in
}

// ============================================================================
// CONFLICT CLASSES
// ============================================================================

abstract class TimeConflict {
  final ConflictType type;
  final ConflictSeverity severity;
  final String message;
  final String? technicalDetails;
  final List<QuickFix> quickFixes;

  const TimeConflict({
    required this.type,
    required this.severity,
    required this.message,
    this.technicalDetails,
    this.quickFixes = const [],
  });
}

class OverlapConflict extends TimeConflict {
  final String entryId1;
  final String entryId2;
  final DateTime overlapStart;
  final DateTime overlapEnd;

  const OverlapConflict({
    required this.entryId1,
    required this.entryId2,
    required this.overlapStart,
    required this.overlapEnd,
    required super.message,
    super.technicalDetails,
    super.quickFixes = const [],
  }) : super(
          type: ConflictType.overlap,
          severity: ConflictSeverity.critical,
        );

  Duration get overlapDuration => overlapEnd.difference(overlapStart);
}

class DSTConflict extends TimeConflict {
  final DateTime transitionTime;
  final bool isSpringForward;
  final Duration missingOrAmbiguousDuration;

  const DSTConflict({
    required this.transitionTime,
    required this.isSpringForward,
    required this.missingOrAmbiguousDuration,
    required super.message,
    super.technicalDetails,
    super.quickFixes = const [],
  }) : super(
          type: isSpringForward
              ? ConflictType.dstSpringForward
              : ConflictType.dstFallBack,
          severity: ConflictSeverity.info,
        );
}

class MissingBreakConflict extends TimeConflict {
  final Duration shiftDuration;
  final Duration requiredBreakDuration;

  const MissingBreakConflict({
    required this.shiftDuration,
    required this.requiredBreakDuration,
    required super.message,
    super.technicalDetails,
    super.quickFixes = const [],
  }) : super(
          type: ConflictType.missingBreak,
          severity: ConflictSeverity.warning,
        );
}

class ExcessiveHoursConflict extends TimeConflict {
  final Duration shiftDuration;
  final Duration recommendedMaxDuration;

  const ExcessiveHoursConflict({
    required this.shiftDuration,
    required this.recommendedMaxDuration,
    required super.message,
    super.technicalDetails,
    super.quickFixes = const [],
  }) : super(
          type: ConflictType.excessiveHours,
          severity: ConflictSeverity.warning,
        );
}

class GenericConflict extends TimeConflict {
  const GenericConflict({
    required super.type,
    required super.severity,
    required super.message,
    super.technicalDetails,
    super.quickFixes = const [],
  });
}

// ============================================================================
// QUICK FIX SUGGESTIONS
// ============================================================================

class QuickFix {
  final String id;
  final String label;
  final String description;
  final Map<String, dynamic> params;

  const QuickFix({
    required this.id,
    required this.label,
    required this.description,
    required this.params,
  });
}

// ============================================================================
// TIME ENTRY (Minimal model for conflict detection)
// ============================================================================

class TimeEntry {
  final String id;
  final String userId;
  final DateTime clockInAt;
  final DateTime? clockOutAt;
  final Duration? breakDuration;
  final DateTime createdAt;

  const TimeEntry({
    required this.id,
    required this.userId,
    required this.clockInAt,
    this.clockOutAt,
    this.breakDuration,
    required this.createdAt,
  });

  Duration? get shiftDuration {
    if (clockOutAt == null) return null;
    return clockOutAt!.difference(clockInAt);
  }

  Duration? get workDuration {
    if (shiftDuration == null) return null;
    return shiftDuration! - (breakDuration ?? Duration.zero);
  }
}

// ============================================================================
// MAIN CONFLICT DETECTOR
// ============================================================================

class ConflictDetector {
  ConflictDetector._();

  /// Detect all conflicts for a given time entry
  static List<TimeConflict> detectConflicts({
    required TimeEntry entry,
    required List<TimeEntry> existingEntries,
    Duration? requiredBreakThreshold = const Duration(hours: 8),
    Duration? maxShiftDuration = const Duration(hours: 12),
  }) {
    final conflicts = <TimeConflict>[];

    // TODO(Phase 3): Implement all conflict detection logic

    // Check for overlaps with existing entries
    final overlaps = _detectOverlaps(entry, existingEntries);
    conflicts.addAll(overlaps);

    // Check for negative time
    if (entry.clockOutAt != null && entry.clockOutAt!.isBefore(entry.clockInAt)) {
      conflicts.add(GenericConflict(
        type: ConflictType.negativeTime,
        severity: ConflictSeverity.critical,
        message: 'Clock-out time is before clock-in time',
        technicalDetails: 'clockIn: ${entry.clockInAt}, clockOut: ${entry.clockOutAt}',
        quickFixes: [
          QuickFix(
            id: 'swap_times',
            label: 'Swap clock-in and clock-out',
            description: 'Exchange the clock-in and clock-out times',
            params: {'entryId': entry.id},
          ),
        ],
      ));
    }

    // Check for missing break
    if (requiredBreakThreshold != null) {
      final missingBreak = _detectMissingBreak(entry, requiredBreakThreshold);
      if (missingBreak != null) {
        conflicts.add(missingBreak);
      }
    }

    // Check for excessive hours
    if (maxShiftDuration != null) {
      final excessiveHours = _detectExcessiveHours(entry, maxShiftDuration);
      if (excessiveHours != null) {
        conflicts.add(excessiveHours);
      }
    }

    // Check for DST transitions
    final dstConflicts = _detectDSTIssues(entry);
    conflicts.addAll(dstConflicts);

    // Check for backdating
    final backdating = _detectBackdating(entry);
    if (backdating != null) {
      conflicts.add(backdating);
    }

    // Check for future entries
    final futureEntry = _detectFutureEntry(entry);
    if (futureEntry != null) {
      conflicts.add(futureEntry);
    }

    return conflicts;
  }

  /// Detect overlapping time entries
  static List<OverlapConflict> _detectOverlaps(
    TimeEntry entry,
    List<TimeEntry> existingEntries,
  ) {
    final conflicts = <OverlapConflict>[];

    // TODO(Phase 3): Implement overlap detection
    for (final existing in existingEntries) {
      // Skip if different users
      if (existing.userId != entry.userId) continue;

      // Skip if same entry
      if (existing.id == entry.id) continue;

      // Skip if either entry is still open
      if (entry.clockOutAt == null || existing.clockOutAt == null) continue;

      // Check for overlap
      final entryStart = entry.clockInAt;
      final entryEnd = entry.clockOutAt!;
      final existingStart = existing.clockInAt;
      final existingEnd = existing.clockOutAt!;

      // Overlap exists if: start1 < end2 AND start2 < end1
      if (entryStart.isBefore(existingEnd) && existingStart.isBefore(entryEnd)) {
        final overlapStart = entryStart.isAfter(existingStart) ? entryStart : existingStart;
        final overlapEnd = entryEnd.isBefore(existingEnd) ? entryEnd : existingEnd;

        conflicts.add(OverlapConflict(
          entryId1: entry.id,
          entryId2: existing.id,
          overlapStart: overlapStart,
          overlapEnd: overlapEnd,
          message: 'Time entry overlaps with another entry',
          technicalDetails: 'Overlap: $overlapStart to $overlapEnd',
          quickFixes: [
            QuickFix(
              id: 'adjust_times',
              label: 'Adjust times to remove overlap',
              description: 'Automatically adjust entry times to prevent overlap',
              params: {
                'entryId': entry.id,
                'existingId': existing.id,
              },
            ),
            QuickFix(
              id: 'delete_duplicate',
              label: 'Delete this entry',
              description: 'Remove this entry if it\'s a duplicate',
              params: {'entryId': entry.id},
            ),
          ],
        ));
      }
    }

    return conflicts;
  }

  /// Detect missing break periods
  static MissingBreakConflict? _detectMissingBreak(
    TimeEntry entry,
    Duration threshold,
  ) {
    // TODO(Phase 3): Implement missing break detection
    if (entry.shiftDuration == null) return null;

    final shiftHours = entry.shiftDuration!.inHours;
    final breakMinutes = entry.breakDuration?.inMinutes ?? 0;

    // If shift is over threshold and no break recorded
    if (shiftHours >= threshold.inHours && breakMinutes == 0) {
      // Calculate required break (e.g., 30 min for 8+ hours)
      final requiredBreakDuration = Duration(minutes: 30);

      return MissingBreakConflict(
        shiftDuration: entry.shiftDuration!,
        requiredBreakDuration: requiredBreakDuration,
        message: 'Shift over ${threshold.inHours} hours requires a break',
        technicalDetails: 'Shift: ${shiftHours}h, Break: ${breakMinutes}min',
        quickFixes: [
          QuickFix(
            id: 'add_break',
            label: 'Add ${requiredBreakDuration.inMinutes}-minute break',
            description: 'Add a break period to this shift',
            params: {
              'entryId': entry.id,
              'breakDuration': requiredBreakDuration.inMinutes,
            },
          ),
        ],
      );
    }

    return null;
  }

  /// Detect excessive hours
  static ExcessiveHoursConflict? _detectExcessiveHours(
    TimeEntry entry,
    Duration maxDuration,
  ) {
    // TODO(Phase 3): Implement excessive hours detection
    if (entry.shiftDuration == null) return null;

    if (entry.shiftDuration! > maxDuration) {
      return ExcessiveHoursConflict(
        shiftDuration: entry.shiftDuration!,
        recommendedMaxDuration: maxDuration,
        message: 'Shift exceeds recommended maximum of ${maxDuration.inHours} hours',
        technicalDetails: 'Duration: ${entry.shiftDuration!.inHours}h',
        quickFixes: [
          QuickFix(
            id: 'split_shift',
            label: 'Split into multiple shifts',
            description: 'Divide this into separate entries',
            params: {'entryId': entry.id},
          ),
        ],
      );
    }

    return null;
  }

  /// Detect DST transition issues
  static List<DSTConflict> _detectDSTIssues(TimeEntry entry) {
    final conflicts = <DSTConflict>[];

    // TODO(Phase 3): Implement DST detection
    // Check if shift spans a DST transition
    // Use timezone database to detect spring forward / fall back

    return conflicts;
  }

  /// Detect backdated entries
  static TimeConflict? _detectBackdating(TimeEntry entry) {
    // TODO(Phase 3): Implement backdating detection
    final now = DateTime.now();
    final daysSinceCreation = now.difference(entry.clockInAt).inDays;

    // If entry is more than 7 days old, warn
    if (daysSinceCreation > 7) {
      return GenericConflict(
        type: ConflictType.backdated,
        severity: ConflictSeverity.info,
        message: 'Time entry is $daysSinceCreation days old',
        technicalDetails: 'Created: ${entry.createdAt}, ClockIn: ${entry.clockInAt}',
      );
    }

    return null;
  }

  /// Detect future entries
  static TimeConflict? _detectFutureEntry(TimeEntry entry) {
    // TODO(Phase 3): Implement future entry detection
    final now = DateTime.now();

    if (entry.clockInAt.isAfter(now)) {
      return GenericConflict(
        type: ConflictType.futureEntry,
        severity: ConflictSeverity.warning,
        message: 'Clock-in time is in the future',
        technicalDetails: 'Now: $now, ClockIn: ${entry.clockInAt}',
        quickFixes: [
          QuickFix(
            id: 'set_to_now',
            label: 'Set clock-in to now',
            description: 'Change clock-in time to current time',
            params: {'entryId': entry.id},
          ),
        ],
      );
    }

    return null;
  }
}
