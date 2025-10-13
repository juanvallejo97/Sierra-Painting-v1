/// Admin Review Providers
///
/// Providers for admin review screen: exception filtering, statistics, and actions.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/auth/user_role.dart';
import 'package:sierra_painting/features/admin/data/admin_time_entry_repository.dart';
import 'package:sierra_painting/features/timeclock/domain/time_entry.dart';

/// State for date range filter
class DateRangeFilter {
  final DateTime? startDate;
  final DateTime? endDate;

  DateRangeFilter({this.startDate, this.endDate});

  DateRangeFilter copyWith({DateTime? startDate, DateTime? endDate}) {
    return DateRangeFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }
}

/// Simple notifier for date range filter
class DateRangeFilterNotifier extends Notifier<DateRangeFilter> {
  @override
  DateRangeFilter build() => DateRangeFilter();

  void update(DateRangeFilter filter) {
    state = filter;
  }

  void clear() {
    state = DateRangeFilter();
  }
}

/// Provider for date range filter state
final dateRangeFilterProvider =
    NotifierProvider<DateRangeFilterNotifier, DateRangeFilter>(
      DateRangeFilterNotifier.new,
    );

/// Simple notifier for search query
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void update(String query) {
    state = query;
  }

  void clear() {
    state = '';
  }
}

/// Provider for search query
final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

/// Provider for all pending entries (stream)
final pendingEntriesProvider = StreamProvider<List<TimeEntry>>((ref) {
  final userProfile = ref.watch(userProfileProvider).value;
  if (userProfile == null || userProfile.companyId.isEmpty) {
    return Stream.value([]);
  }

  final repository = ref.watch(adminTimeEntryRepositoryProvider);
  final dateRange = ref.watch(dateRangeFilterProvider);

  return repository.watchPendingEntries(
    companyId: userProfile.companyId,
    startDate: dateRange.startDate,
    endDate: dateRange.endDate,
  );
});

/// Provider for entries outside geofence
final outsideGeofenceEntriesProvider = FutureProvider<List<TimeEntry>>((
  ref,
) async {
  final userProfile = await ref.watch(userProfileProvider.future);
  if (userProfile == null || userProfile.companyId.isEmpty) return [];

  final repository = ref.watch(adminTimeEntryRepositoryProvider);
  final dateRange = ref.watch(dateRangeFilterProvider);

  return repository.getOutsideGeofenceEntries(
    companyId: userProfile.companyId,
    startDate: dateRange.startDate,
    endDate: dateRange.endDate,
  );
});

/// Provider for entries exceeding max hours
final exceedsMaxHoursEntriesProvider = FutureProvider<List<TimeEntry>>((
  ref,
) async {
  final userProfile = await ref.watch(userProfileProvider.future);
  if (userProfile == null || userProfile.companyId.isEmpty) return [];

  final repository = ref.watch(adminTimeEntryRepositoryProvider);
  final dateRange = ref.watch(dateRangeFilterProvider);

  return repository.getExceedsMaxHoursEntries(
    companyId: userProfile.companyId,
    startDate: dateRange.startDate,
    endDate: dateRange.endDate,
  );
});

/// Provider for disputed entries
final disputedEntriesProvider = FutureProvider<List<TimeEntry>>((ref) async {
  final userProfile = await ref.watch(userProfileProvider.future);
  if (userProfile == null || userProfile.companyId.isEmpty) return [];

  final repository = ref.watch(adminTimeEntryRepositoryProvider);
  final dateRange = ref.watch(dateRangeFilterProvider);

  return repository.getDisputedEntries(
    companyId: userProfile.companyId,
    startDate: dateRange.startDate,
    endDate: dateRange.endDate,
  );
});

/// Provider for flagged entries
final flaggedEntriesProvider = FutureProvider<List<TimeEntry>>((ref) async {
  final userProfile = await ref.watch(userProfileProvider.future);
  if (userProfile == null || userProfile.companyId.isEmpty) return [];

  final repository = ref.watch(adminTimeEntryRepositoryProvider);
  final dateRange = ref.watch(dateRangeFilterProvider);

  return repository.getFlaggedEntries(
    companyId: userProfile.companyId,
    startDate: dateRange.startDate,
    endDate: dateRange.endDate,
  );
});

/// Provider for exception counts (statistics)
final exceptionCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final userProfile = await ref.watch(userProfileProvider.future);
  if (userProfile == null || userProfile.companyId.isEmpty) {
    return {
      'outsideGeofence': 0,
      'exceedsMaxHours': 0,
      'disputed': 0,
      'flagged': 0,
      'totalPending': 0,
    };
  }

  final repository = ref.watch(adminTimeEntryRepositoryProvider);
  final dateRange = ref.watch(dateRangeFilterProvider);

  return repository.getExceptionCounts(
    companyId: userProfile.companyId,
    startDate: dateRange.startDate,
    endDate: dateRange.endDate,
  );
});

/// Provider for filtered entries based on search query
final filteredEntriesProvider =
    Provider.family<List<TimeEntry>, List<TimeEntry>>((ref, entries) {
      final query = ref.watch(searchQueryProvider).toLowerCase();
      if (query.isEmpty) return entries;

      return entries.where((entry) {
        // TODO: Resolve worker and job names for better search
        return entry.workerId.toLowerCase().contains(query) ||
            entry.jobId.toLowerCase().contains(query);
      }).toList();
    });

/// Action: Approve single entry
Future<void> approveEntry(WidgetRef ref, String entryId) async {
  final userProfile = await ref.read(userProfileProvider.future);
  if (userProfile == null) return;

  final repository = ref.read(adminTimeEntryRepositoryProvider);
  await repository.approveEntry(entryId: entryId, approvedBy: userProfile.uid);

  // Refresh data
  ref.invalidate(pendingEntriesProvider);
  ref.invalidate(exceptionCountsProvider);
}

/// Action: Reject single entry
Future<void> rejectEntry(
  WidgetRef ref,
  String entryId, {
  String? reason,
}) async {
  final userProfile = await ref.read(userProfileProvider.future);
  if (userProfile == null) return;

  final repository = ref.read(adminTimeEntryRepositoryProvider);
  await repository.rejectEntry(
    entryId: entryId,
    rejectedBy: userProfile.uid,
    reason: reason,
  );

  // Refresh data
  ref.invalidate(pendingEntriesProvider);
  ref.invalidate(exceptionCountsProvider);
}

/// Action: Bulk approve entries
Future<void> bulkApproveEntries(WidgetRef ref, List<String> entryIds) async {
  final userProfile = await ref.read(userProfileProvider.future);
  if (userProfile == null) return;

  final repository = ref.read(adminTimeEntryRepositoryProvider);
  await repository.bulkApproveEntries(
    entryIds: entryIds,
    approvedBy: userProfile.uid,
  );

  // Refresh data
  ref.invalidate(pendingEntriesProvider);
  ref.invalidate(exceptionCountsProvider);
}

/// Action: Bulk reject entries
Future<void> bulkRejectEntries(
  WidgetRef ref,
  List<String> entryIds, {
  String? reason,
}) async {
  final userProfile = await ref.read(userProfileProvider.future);
  if (userProfile == null) return;

  final repository = ref.read(adminTimeEntryRepositoryProvider);
  await repository.bulkRejectEntries(
    entryIds: entryIds,
    rejectedBy: userProfile.uid,
    reason: reason,
  );

  // Refresh data
  ref.invalidate(pendingEntriesProvider);
  ref.invalidate(exceptionCountsProvider);
}
