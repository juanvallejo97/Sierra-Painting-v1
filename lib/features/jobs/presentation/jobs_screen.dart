/// Jobs List Screen
///
/// PURPOSE:
/// Shows list of all jobs for admins to manage and coordinate crews.
///
/// FEATURES:
/// - List of jobs with status, location, and worker info
/// - Search by job name or address
/// - Filter by status
/// - Tap to view details
/// - Empty state for no jobs
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/widgets/admin_scaffold.dart';
import 'package:sierra_painting/features/jobs/domain/job.dart';
import 'package:sierra_painting/features/jobs/presentation/providers/jobs_providers.dart';

class JobsScreen extends ConsumerStatefulWidget {
  const JobsScreen({super.key});

  @override
  ConsumerState<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends ConsumerState<JobsScreen> {
  String _searchQuery = '';
  JobStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(jobsListProvider);

    return AdminScaffold(
      title: 'Jobs',
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          tooltip: 'Filter',
          onPressed: _showFilterDialog,
        ),
      ],
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search jobs by name or address...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Clear search',
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Jobs List
          Expanded(
            child: jobsAsync.when(
              data: (jobs) {
                // Apply search and filters
                var filteredJobs = jobs;

                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  filteredJobs = jobs.where((job) {
                    return job.name.toLowerCase().contains(query) ||
                        job.location.address.toLowerCase().contains(query);
                  }).toList();
                }

                if (_statusFilter != null) {
                  filteredJobs = filteredJobs
                      .where((job) => job.status == _statusFilter)
                      .toList();
                }

                if (filteredJobs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.work_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          jobs.isEmpty ? 'No jobs yet' : 'No matching jobs',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          jobs.isEmpty
                              ? 'Create your first job to get started'
                              : 'Try adjusting your search or filters',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredJobs.length,
                  itemBuilder: (context, index) {
                    return _buildJobCard(filteredJobs[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Error loading jobs',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: const TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(jobsListProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to job create screen
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Create Job (coming soon)')),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Job'),
      ),
    );
  }

  Widget _buildJobCard(Job job) {
    Color statusColor;
    IconData statusIcon;

    switch (job.status) {
      case JobStatus.active:
        statusColor = Colors.green;
        statusIcon = Icons.play_circle;
        break;
      case JobStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case JobStatus.paused:
        statusColor = Colors.blue;
        statusIcon = Icons.pause_circle;
        break;
      case JobStatus.completed:
        statusColor = Colors.grey;
        statusIcon = Icons.check_circle;
        break;
      case JobStatus.cancelled:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(statusIcon, color: statusColor, size: 32),
        title: Text(
          job.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    job.location.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.people, size: 14),
                const SizedBox(width: 4),
                Text('${job.assignedWorkerIds.length} workers'),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    job.status.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pushNamed(context, '/jobs/${job.id}');
        },
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Jobs'),
        content: RadioGroup<JobStatus?>(
          groupValue: _statusFilter,
          onChanged: (value) {
            setState(() {
              _statusFilter = value;
            });
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Status:'),
              const SizedBox(height: 8),
              ...JobStatus.values.map((status) {
                return RadioListTile<JobStatus?>(
                  title: Text(status.displayName),
                  value: status,
                );
              }),
              const RadioListTile<JobStatus?>(title: Text('All'), value: null),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
