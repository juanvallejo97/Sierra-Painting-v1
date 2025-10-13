/// Assignment Picker Dialog
///
/// PURPOSE:
/// Reusable widget for assigning workers to job sites.
/// Used in job create/edit flows and standalone assignment management.
///
/// FEATURES:
/// - List all workers in company
/// - Filter by role, availability
/// - Bulk select/deselect
/// - Show current assignments
/// - Set assignment start/end dates
/// - Set worker role on job (lead, painter, helper)
///
/// VALIDATION:
/// - At least one worker must be selected
/// - Cannot assign inactive workers
/// - Warn if worker already assigned to another job on same dates
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Worker selection model
class WorkerSelection {
  final String userId;
  final String name;
  final String? role;
  final bool isAssigned;
  final bool isSelected;

  WorkerSelection({
    required this.userId,
    required this.name,
    this.role,
    this.isAssigned = false,
    this.isSelected = false,
  });

  WorkerSelection copyWith({
    String? userId,
    String? name,
    String? role,
    bool? isAssigned,
    bool? isSelected,
  }) {
    return WorkerSelection(
      userId: userId ?? this.userId,
      name: name ?? this.name,
      role: role ?? this.role,
      isAssigned: isAssigned ?? this.isAssigned,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Assignment Picker Dialog - Skeleton
class AssignmentPickerDialog extends ConsumerStatefulWidget {
  final String jobId;
  final String jobName;
  final List<String> currentlyAssignedWorkerIds;
  final DateTime? jobStartDate;
  final DateTime? jobEndDate;

  const AssignmentPickerDialog({
    super.key,
    required this.jobId,
    required this.jobName,
    this.currentlyAssignedWorkerIds = const [],
    this.jobStartDate,
    this.jobEndDate,
  });

  @override
  ConsumerState<AssignmentPickerDialog> createState() =>
      _AssignmentPickerDialogState();

  /// Show dialog and return list of selected worker IDs
  static Future<List<String>?> show(
    BuildContext context, {
    required String jobId,
    required String jobName,
    List<String> currentlyAssignedWorkerIds = const [],
    DateTime? jobStartDate,
    DateTime? jobEndDate,
  }) {
    return showDialog<List<String>>(
      context: context,
      builder: (context) => AssignmentPickerDialog(
        jobId: jobId,
        jobName: jobName,
        currentlyAssignedWorkerIds: currentlyAssignedWorkerIds,
        jobStartDate: jobStartDate,
        jobEndDate: jobEndDate,
      ),
    );
  }
}

class _AssignmentPickerDialogState
    extends ConsumerState<AssignmentPickerDialog> {
  // State
  List<WorkerSelection> _workers = [];
  String _searchQuery = '';
  bool _showOnlyAvailable = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorkers();
  }

  Future<void> _loadWorkers() async {
    setState(() {
      _isLoading = true;
    });

    // TODO: Load workers from repository
    // 1. Get all workers in company
    // 2. Check current assignments for conflicts
    // 3. Build WorkerSelection list

    await Future.delayed(const Duration(milliseconds: 500)); // Simulate API

    // Mock data for skeleton
    setState(() {
      _workers = [
        WorkerSelection(
          userId: '1',
          name: 'John Doe',
          role: 'painter',
          isAssigned: widget.currentlyAssignedWorkerIds.contains('1'),
          isSelected: widget.currentlyAssignedWorkerIds.contains('1'),
        ),
        WorkerSelection(
          userId: '2',
          name: 'Jane Smith',
          role: 'lead',
          isAssigned: widget.currentlyAssignedWorkerIds.contains('2'),
          isSelected: widget.currentlyAssignedWorkerIds.contains('2'),
        ),
      ];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _workers.where((w) => w.isSelected).length;

    return Dialog(
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            AppBar(
              title: Text('Assign Workers to ${widget.jobName}'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),

            // Search and Filters
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search workers...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilterChip(
                        label: const Text('Available Only'),
                        selected: _showOnlyAvailable,
                        onSelected: (selected) {
                          setState(() {
                            _showOnlyAvailable = selected;
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$selectedCount worker(s) selected',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      TextButton(
                        onPressed: _handleSelectAll,
                        child: const Text('Select All'),
                      ),
                      TextButton(
                        onPressed: _handleClearAll,
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Worker List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _buildWorkerList(),
            ),

            // Actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: selectedCount > 0 ? _handleSave : null,
                      child: const Text('Save Assignments'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerList() {
    final filteredWorkers = _workers.where((worker) {
      // Apply search filter
      if (_searchQuery.isNotEmpty &&
          !worker.name.toLowerCase().contains(_searchQuery)) {
        return false;
      }

      // Apply availability filter
      // TODO: Check if worker has conflicting assignments
      if (_showOnlyAvailable) {
        // For now, show all
        return true;
      }

      return true;
    }).toList();

    if (filteredWorkers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No workers found',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: filteredWorkers.length,
      itemBuilder: (context, index) {
        final worker = filteredWorkers[index];
        return _buildWorkerTile(worker);
      },
    );
  }

  Widget _buildWorkerTile(WorkerSelection worker) {
    return CheckboxListTile(
      value: worker.isSelected,
      onChanged: (selected) {
        setState(() {
          final index = _workers.indexWhere((w) => w.userId == worker.userId);
          if (index != -1) {
            _workers[index] = worker.copyWith(isSelected: selected ?? false);
          }
        });
      },
      title: Text(worker.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (worker.role != null) Text('Role: ${_formatRole(worker.role!)}'),
          if (worker.isAssigned)
            const Text(
              'Currently assigned to this job',
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
        ],
      ),
      secondary: CircleAvatar(child: Text(worker.name[0].toUpperCase())),
    );
  }

  String _formatRole(String role) {
    switch (role) {
      case 'lead':
        return 'Lead Painter';
      case 'painter':
        return 'Painter';
      case 'helper':
        return 'Helper';
      default:
        return role;
    }
  }

  void _handleSelectAll() {
    setState(() {
      _workers = _workers.map((w) => w.copyWith(isSelected: true)).toList();
    });
  }

  void _handleClearAll() {
    setState(() {
      _workers = _workers.map((w) => w.copyWith(isSelected: false)).toList();
    });
  }

  void _handleSave() {
    final selectedWorkerIds = _workers
        .where((w) => w.isSelected)
        .map((w) => w.userId)
        .toList();

    // TODO: Create/update assignments in repository
    // 1. For newly selected workers: create assignments
    // 2. For deselected workers: update assignments (set active=false)
    // 3. Update assignment dates if job dates changed

    Navigator.of(context).pop(selectedWorkerIds);
  }
}
