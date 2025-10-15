/// Worker Schedule Screen
///
/// PURPOSE:
/// Shows worker's assigned shifts and schedule.
///
/// FEATURES:
/// - List of upcoming assignments
/// - Filter by date (today, this week, all)
/// - Shows job details for each assignment
/// - Pull-to-refresh
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sierra_painting/core/widgets/worker_scaffold.dart';
import 'package:sierra_painting/features/jobs/domain/assignment.dart';

/// Provider for worker's assignments
final workerAssignmentsProvider = StreamProvider<List<Assignment>>((ref) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    return Stream.value([]);
  }

  // Get company ID from claims
  return user.getIdTokenResult().asStream().asyncExpand((idTokenResult) {
    final companyId = idTokenResult.claims?['companyId'] as String?;
    if (companyId == null) {
      return Stream.value([]);
    }

    // Stream assignments for this worker
    return FirebaseFirestore.instance
        .collection('assignments')
        .where('companyId', isEqualTo: companyId)
        .where('userId', isEqualTo: user.uid)
        .where('active', isEqualTo: true)
        .orderBy('startDate', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Assignment.fromFirestore(doc))
              .toList();
        });
  });
});

class WorkerScheduleScreen extends ConsumerStatefulWidget {
  const WorkerScheduleScreen({super.key});

  @override
  ConsumerState<WorkerScheduleScreen> createState() =>
      _WorkerScheduleScreenState();
}

class _WorkerScheduleScreenState extends ConsumerState<WorkerScheduleScreen> {
  String _filter = 'all'; // 'today', 'week', 'all'

  @override
  Widget build(BuildContext context) {
    final assignmentsAsync = ref.watch(workerAssignmentsProvider);

    return WorkerScaffold(
      title: 'My Schedule',
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.filter_list),
          onSelected: (value) {
            setState(() {
              _filter = value;
            });
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'today', child: Text('Today')),
            const PopupMenuItem(value: 'week', child: Text('This Week')),
            const PopupMenuItem(value: 'all', child: Text('All Upcoming')),
          ],
        ),
      ],
      body: assignmentsAsync.when(
        data: (assignments) {
          // Apply filter
          final filteredAssignments = _filterAssignments(assignments);

          if (filteredAssignments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No shifts scheduled',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your schedule will appear here when assignments are made',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(workerAssignmentsProvider);
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredAssignments.length,
              itemBuilder: (context, index) {
                return _buildAssignmentCard(filteredAssignments[index]);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Error loading schedule'),
              const SizedBox(height: 8),
              Text(error.toString()),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(workerAssignmentsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Assignment> _filterAssignments(List<Assignment> assignments) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endOfWeek = today.add(const Duration(days: 7));

    switch (_filter) {
      case 'today':
        return assignments.where((a) {
          if (a.startDate == null) return false;
          final assignDate = DateTime(
            a.startDate!.year,
            a.startDate!.month,
            a.startDate!.day,
          );
          return assignDate == today;
        }).toList();
      case 'week':
        return assignments.where((a) {
          if (a.startDate == null) return false;
          return a.startDate!.isBefore(endOfWeek) &&
              a.startDate!.isAfter(today.subtract(const Duration(days: 1)));
        }).toList();
      case 'all':
      default:
        return assignments;
    }
  }

  Widget _buildAssignmentCard(Assignment assignment) {
    final isToday =
        assignment.startDate != null &&
        DateTime.now().day == assignment.startDate!.day &&
        DateTime.now().month == assignment.startDate!.month;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isToday ? Colors.blue.shade50 : null,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: isToday
              ? Colors.blue
              : Theme.of(context).colorScheme.primary,
          child: Icon(
            isToday ? Icons.today : Icons.calendar_month,
            color: Colors.white,
          ),
        ),
        title: Text(
          'Job ID: ${assignment.jobId}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            if (assignment.startDate != null)
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16),
                  const SizedBox(width: 4),
                  Text(DateFormat('MMM d, yyyy').format(assignment.startDate!)),
                ],
              ),
            if (assignment.startDate != null) const SizedBox(height: 4),
            if (assignment.role != null)
              Row(
                children: [
                  const Icon(Icons.work, size: 16),
                  const SizedBox(width: 4),
                  Text(assignment.role!),
                ],
              ),
            if (assignment.notes != null && assignment.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                assignment.notes!,
                style: const TextStyle(fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: isToday
            ? const Chip(
                label: Text('TODAY'),
                backgroundColor: Colors.blue,
                labelStyle: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
    );
  }
}
