/// Worker Schedule Screen
///
/// PURPOSE:
/// Display weekly schedule for workers with today/week/all filters
/// Shows assigned shifts with job details and time ranges
///
/// FEATURES:
/// - Calendar week view with date picker
/// - Filter: Today / This Week / All Upcoming
/// - Real-time updates via Firestore streams
/// - Pull-to-refresh
/// - "TODAY" badge for current shifts
/// - Empty states with friendly messaging
/// - Tap shift to see job details
///
/// HAIKU TODO:
/// - Implement Firestore query for worker shifts
/// - Build calendar week selector widget
/// - Add filter chip row
/// - Create shift card widget
/// - Wire up navigation to job details
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers/auth_provider.dart';
import 'package:sierra_painting/design/tokens.dart';

/// JobAssignment domain model for worker shifts
class JobAssignment {
  final String id;
  final String jobId;
  final String jobName;
  final String workerId;
  final DateTime shiftStart;
  final DateTime shiftEnd;
  final String? notes;
  final String status; // scheduled, in_progress, completed, cancelled

  JobAssignment({
    required this.id,
    required this.jobId,
    required this.jobName,
    required this.workerId,
    required this.shiftStart,
    required this.shiftEnd,
    this.notes,
    required this.status,
  });

  /// Parse from Firestore document
  factory JobAssignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JobAssignment(
      id: doc.id,
      jobId: data['jobId'] as String,
      jobName: data['jobName'] as String? ?? 'Untitled Job',
      workerId: data['workerId'] as String,
      shiftStart: (data['shiftStart'] as Timestamp).toDate(),
      shiftEnd: (data['shiftEnd'] as Timestamp).toDate(),
      notes: data['notes'] as String?,
      status: data['status'] as String? ?? 'scheduled',
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() {
    return {
      'jobId': jobId,
      'jobName': jobName,
      'workerId': workerId,
      'shiftStart': Timestamp.fromDate(shiftStart),
      'shiftEnd': Timestamp.fromDate(shiftEnd),
      'notes': notes,
      'status': status,
    };
  }

  /// Calculate shift duration in hours
  double get durationHours {
    return shiftEnd.difference(shiftStart).inMinutes / 60.0;
  }
}

/// Provider for fetching worker's assigned shifts from Firestore
final workerAssignmentsProvider = StreamProvider<List<JobAssignment>>((ref) {
  final workerId = ref.watch(currentUserProvider)?.uid;
  final companyId = ref.watch(userCompanyProvider);

  if (workerId == null || companyId == null) {
    return Stream.value([]);
  }

  // Query all upcoming assignments for this worker
  return FirebaseFirestore.instance
      .collection('companies/$companyId/job_assignments')
      .where('workerId', isEqualTo: workerId)
      .where('shiftStart', isGreaterThanOrEqualTo: DateTime.now())
      .orderBy('shiftStart')
      .snapshots()
      .map((snapshot) =>
          snapshot.docs.map((doc) => JobAssignment.fromFirestore(doc)).toList());
});

class WorkerScheduleScreen extends ConsumerWidget {
  const WorkerScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/branding/dsierra_logo.jpg',
              height: 32,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
            const SizedBox(width: 12),
            const Text("My Schedule"),
          ],
        ),
        actions: [
          // HAIKU TODO: Add calendar icon button to pick date
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              // TODO: Show date picker
            },
            tooltip: 'Pick Date',
          ),
        ],
      ),
      body: const WorkerScheduleBody(),
    );
  }
}

class WorkerScheduleBody extends ConsumerStatefulWidget {
  const WorkerScheduleBody({super.key});

  @override
  ConsumerState<WorkerScheduleBody> createState() => _WorkerScheduleBodyState();
}

class _WorkerScheduleBodyState extends ConsumerState<WorkerScheduleBody> {
  String _filter = 'today'; // today, week, all
  DateTime _selectedWeek = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final assignmentsAsync = ref.watch(workerAssignmentsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(workerAssignmentsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilterChips(),
            const SizedBox(height: DesignTokens.spaceLG),
            if (_filter == 'week') ...[
              _buildWeekSelector(),
              const SizedBox(height: DesignTokens.spaceLG),
            ],
            assignmentsAsync.when(
              data: (assignments) => _buildAssignmentsList(assignments),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => _buildErrorState(error),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        _buildFilterChip('Today', 'today'),
        const SizedBox(width: 8),
        _buildFilterChip('This Week', 'week'),
        const SizedBox(width: 8),
        _buildFilterChip('All Upcoming', 'all'),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _filter = value;
        });
      },
      selectedColor: DesignTokens.dsierraRed.withValues(alpha: 0.2),
      checkmarkColor: DesignTokens.dsierraRed,
    );
  }

  Widget _buildWeekSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () {
                setState(() {
                  _selectedWeek = _selectedWeek.subtract(const Duration(days: 7));
                });
              },
            ),
            Text(
              'Week of ${_selectedWeek.month}/${_selectedWeek.day}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () {
                setState(() {
                  _selectedWeek = _selectedWeek.add(const Duration(days: 7));
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentsList(List<JobAssignment> assignments) {
    // Apply filter based on selected filter
    final now = DateTime.now();
    final filteredAssignments = assignments.where((assignment) {
      switch (_filter) {
        case 'today':
          // Same calendar day
          return assignment.shiftStart.year == now.year &&
              assignment.shiftStart.month == now.month &&
              assignment.shiftStart.day == now.day;
        case 'week':
          // Same week as selected week
          final weekStart =
              _selectedWeek.subtract(Duration(days: _selectedWeek.weekday - 1));
          final weekEnd = weekStart.add(const Duration(days: 6));
          return assignment.shiftStart.isAfter(weekStart) &&
              assignment.shiftStart.isBefore(weekEnd);
        case 'all':
        default:
          // All upcoming (already filtered in provider)
          return true;
      }
    }).toList();

    if (filteredAssignments.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredAssignments.length,
      itemBuilder: (context, index) {
        return _buildShiftCard(filteredAssignments[index]);
      },
    );
  }

  Widget _buildShiftCard(JobAssignment assignment) {
    // Check if shift is today
    final now = DateTime.now();
    final isToday = assignment.shiftStart.year == now.year &&
        assignment.shiftStart.month == now.month &&
        assignment.shiftStart.day == now.day;

    // Format shift time as "8:00 AM - 5:00 PM (9h)"
    final startTime = _formatTime(assignment.shiftStart);
    final endTime = _formatTime(assignment.shiftEnd);
    final duration = assignment.durationHours.toStringAsFixed(1);

    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceMD),
      child: InkWell(
        onTap: () {
          // Navigate to job details
          // TODO: Implement navigation when job detail route exists
          // Navigator.pushNamed(context, '/job-details', arguments: assignment.jobId);
        },
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spaceMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      assignment.jobName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: DesignTokens.dsierraRed,
                        borderRadius: BorderRadius.circular(DesignTokens.radiusSM),
                      ),
                      child: const Text(
                        'TODAY',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    '$startTime - $endTime ($duration h)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Format DateTime to 12-hour format (e.g., "8:00 AM")
  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildEmptyState() {
    String message = 'No shifts scheduled';
    if (_filter == 'today') {
      message = 'No shifts scheduled for today';
    } else if (_filter == 'week') {
      message = 'No shifts scheduled this week';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXL),
        child: Column(
          children: [
            const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
            const SizedBox(height: DesignTokens.spaceMD),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceXL),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 64, color: DesignTokens.errorRed),
            const SizedBox(height: DesignTokens.spaceMD),
            Text('Failed to load schedule', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
