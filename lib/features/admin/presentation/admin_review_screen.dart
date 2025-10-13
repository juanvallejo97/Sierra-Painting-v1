/// Admin Review Screen - Exception-First View
///
/// PURPOSE:
/// Admin/Manager interface to review and approve time entries that need attention.
/// Exception-first design surfaces problematic entries before routine approvals.
///
/// FEATURES:
/// - Tabbed view: Outside Geofence, >12h, Overlapping, Disputed, All Pending
/// - Each row shows: worker, job, in/out times, geo badges, actions
/// - Bulk selection and approval
/// - Edit/reject individual entries
/// - Filter and search
/// - Summary stats at top
///
/// WORKFLOW:
/// 1. Admin opens review screen
/// 2. Default tab: "Outside Geofence" (highest priority)
/// 3. Admin reviews entries, edits if needed
/// 4. Bulk approve or reject
/// 5. Status updates, entries move to approved/rejected buckets
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers.dart';
import 'package:sierra_painting/features/admin/presentation/providers/admin_review_providers.dart';
import 'package:sierra_painting/features/timeclock/domain/time_entry.dart';

/// Exception category for filtering
enum ExceptionCategory {
  outsideGeofence('Outside Geofence', Icons.location_off, Colors.red),
  exceedsMaxHours('>12 Hours', Icons.access_time, Colors.orange),
  autoClockOut('Auto Clock-Out', Icons.alarm, Colors.orange),
  overlapping('Overlapping', Icons.warning, Colors.amber),
  disputed('Disputed', Icons.flag, Colors.purple),
  allPending('All Pending', Icons.pending, Colors.blue);

  final String label;
  final IconData icon;
  final Color color;

  const ExceptionCategory(this.label, this.icon, this.color);
}

/// Admin Review Screen - Skeleton
class AdminReviewScreen extends ConsumerStatefulWidget {
  const AdminReviewScreen({super.key});

  @override
  ConsumerState<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends ConsumerState<AdminReviewScreen> {
  ExceptionCategory _selectedCategory = ExceptionCategory.outsideGeofence;
  final Set<String> _selectedEntries = {};
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Entry Review'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'Filters',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(pendingEntriesProvider);
              ref.invalidate(exceptionCountsProvider);
              ref.invalidate(outsideGeofenceEntriesProvider);
              ref.invalidate(exceedsMaxHoursEntriesProvider);
              ref.invalidate(disputedEntriesProvider);
              ref.invalidate(flaggedEntriesProvider);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Stats Card
          _buildSummaryStats(),

          // Category Tabs
          _buildCategoryTabs(),

          // Search Bar
          _buildSearchBar(),

          // Bulk Actions Bar (when items selected)
          if (_selectedEntries.isNotEmpty) _buildBulkActionsBar(),

          // Entry List
          Expanded(child: _buildEntryList()),
        ],
      ),
    );
  }

  Widget _buildSummaryStats() {
    final countsAsync = ref.watch(exceptionCountsProvider);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: countsAsync.when(
          data: (counts) => Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                label: 'Outside Fence',
                count: counts['outsideGeofence'] ?? 0,
                color: Colors.red,
              ),
              _buildStatItem(
                label: '>12 Hours',
                count: counts['exceedsMaxHours'] ?? 0,
                color: Colors.orange,
              ),
              _buildStatItem(
                label: 'Disputed',
                count: counts['disputed'] ?? 0,
                color: Colors.purple,
              ),
              _buildStatItem(
                label: 'Total Pending',
                count: counts['totalPending'] ?? 0,
                color: Colors.blue,
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => _buildErrorWidget(
            title: 'Can\'t load admin data',
            subtitle: error is TimeoutException
                ? 'Query timed out. Try refreshing your admin token.'
                : error.toString(),
            isTimeout: error is TimeoutException,
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required int count,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildCategoryTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: ExceptionCategory.values.map((category) {
          final isSelected = category == _selectedCategory;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(category.icon, size: 16),
                  const SizedBox(width: 4),
                  Text(category.label),
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                  _selectedEntries.clear();
                });
              },
              selectedColor: category.color.withValues(alpha: 0.2),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search by worker name or job...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                    ref.read(searchQueryProvider.notifier).clear();
                  },
                )
              : null,
        ),
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
          ref.read(searchQueryProvider.notifier).update(value);
        },
      ),
    );
  }

  Widget _buildBulkActionsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Text(
            '${_selectedEntries.length} selected',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Spacer(),
          TextButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Approve'),
            onPressed: _handleBulkApprove,
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            icon: const Icon(Icons.close),
            label: const Text('Reject'),
            onPressed: _handleBulkReject,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedEntries.clear();
              });
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryList() {
    // Select the appropriate provider based on category
    final AsyncValue<List<TimeEntry>> entriesAsync =
        switch (_selectedCategory) {
          ExceptionCategory.outsideGeofence => ref.watch(
            outsideGeofenceEntriesProvider,
          ),
          ExceptionCategory.exceedsMaxHours => ref.watch(
            exceedsMaxHoursEntriesProvider,
          ),
          ExceptionCategory.disputed => ref.watch(disputedEntriesProvider),
          ExceptionCategory.autoClockOut => ref.watch(
            flaggedEntriesProvider,
          ), // Reuse flagged for auto-clock-out
          ExceptionCategory.overlapping => ref.watch(
            flaggedEntriesProvider,
          ), // Reuse flagged for overlapping
          ExceptionCategory.allPending => ref.watch(pendingEntriesProvider),
        };

    return entriesAsync.when(
      data: (entries) {
        // Apply search filter
        final filteredEntries = ref.watch(filteredEntriesProvider(entries));

        if (filteredEntries.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _selectedCategory.icon,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${_selectedCategory.label.toLowerCase()} entries',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 8),
                Text(
                  'All caught up!',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredEntries.length,
          itemBuilder: (context, index) {
            return _buildEntryCard(filteredEntries[index]);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorWidget(
        title: 'Error loading entries',
        subtitle: error is TimeoutException
            ? 'Query timed out. Try refreshing your admin token.'
            : error.toString(),
        isTimeout: error is TimeoutException,
      ),
    );
  }

  /// Build error widget with optional "Refresh Claims" action
  Widget _buildErrorWidget({
    required String title,
    required String subtitle,
    required bool isTimeout,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isTimeout ? Icons.access_time : Icons.error_outline,
              size: 48,
              color: isTimeout ? Colors.orange.shade300 : Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (isTimeout)
              ElevatedButton.icon(
                onPressed: () async {
                  // Force refresh ID token and invalidate claims provider
                  await FirebaseAuth.instance.currentUser?.getIdToken(true);
                  ref.invalidate(userClaimsProvider);
                  // Also refresh data providers
                  ref.invalidate(pendingEntriesProvider);
                  ref.invalidate(exceptionCountsProvider);
                  ref.invalidate(outsideGeofenceEntriesProvider);
                  ref.invalidate(exceedsMaxHoursEntriesProvider);
                  ref.invalidate(disputedEntriesProvider);
                  ref.invalidate(flaggedEntriesProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh Claims & Retry'),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  // Just refresh data providers
                  ref.invalidate(pendingEntriesProvider);
                  ref.invalidate(exceptionCountsProvider);
                  ref.invalidate(outsideGeofenceEntriesProvider);
                  ref.invalidate(exceedsMaxHoursEntriesProvider);
                  ref.invalidate(disputedEntriesProvider);
                  ref.invalidate(flaggedEntriesProvider);
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(TimeEntry entry) {
    final isSelected = _selectedEntries.contains(entry.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _handleEntryTap(entry),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Selection Checkbox
              Checkbox(
                value: isSelected,
                onChanged: (selected) {
                  setState(() {
                    if (selected == true) {
                      _selectedEntries.add(entry.id!);
                    } else {
                      _selectedEntries.remove(entry.id);
                    }
                  });
                },
              ),

              // Worker Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Worker: ${entry.workerId}', // TODO: Resolve to name
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Job: ${entry.jobId}'), // TODO: Resolve to job name
                    const SizedBox(height: 4),
                    _buildTimeInfo(entry),
                    const SizedBox(height: 4),
                    _buildExceptionBadges(entry),
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _handleEdit(entry),
                    tooltip: 'Edit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, size: 20),
                    onPressed: () => _handleApprove(entry),
                    color: Colors.green,
                    tooltip: 'Approve',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => _handleReject(entry),
                    color: Colors.red,
                    tooltip: 'Reject',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeInfo(TimeEntry entry) {
    final duration = entry.durationHours ?? 0;
    return Row(
      children: [
        const Icon(Icons.access_time, size: 14),
        const SizedBox(width: 4),
        Text(
          '${_formatTime(entry.clockIn)} - ${entry.clockOut != null ? _formatTime(entry.clockOut!) : 'In Progress'}',
          style: const TextStyle(fontSize: 12),
        ),
        const SizedBox(width: 8),
        Text(
          '${duration.toStringAsFixed(1)}h',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildExceptionBadges(TimeEntry entry) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        if (!entry.clockInGeofenceValid) _buildBadge('Geo In', Colors.red),
        if (entry.clockOutGeofenceValid == false)
          _buildBadge('Geo Out', Colors.red),
        if (entry.exceedsTwelveHours) _buildBadge('>12h', Colors.orange),
        if (entry.isFlagged) _buildBadge('Flagged', Colors.purple),
      ],
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:${time.minute.toString().padLeft(2, '0')} $period';
  }

  void _handleEntryTap(TimeEntry entry) {
    // TODO: Show entry detail dialog
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('View detail for ${entry.id}')));
  }

  void _handleEdit(TimeEntry entry) {
    // TODO: Show edit dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit entry - Not implemented')),
    );
  }

  Future<void> _handleApprove(TimeEntry entry) async {
    try {
      await approveEntry(ref, entry.id!);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('✓ Approved entry ${entry.id}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleReject(TimeEntry entry) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _RejectReasonDialog(),
    );

    if (reason == null) return; // User cancelled

    try {
      await rejectEntry(ref, entry.id!, reason: reason);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('✓ Rejected entry ${entry.id}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleBulkApprove() async {
    try {
      await bulkApproveEntries(ref, _selectedEntries.toList());
      if (mounted) {
        setState(() {
          _selectedEntries.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Approved ${_selectedEntries.length} entries'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to approve: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleBulkReject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => const _RejectReasonDialog(isBulk: true),
    );

    if (reason == null) return; // User cancelled

    try {
      await bulkRejectEntries(ref, _selectedEntries.toList(), reason: reason);
      if (mounted) {
        setState(() {
          _selectedEntries.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Rejected ${_selectedEntries.length} entries'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to reject: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filters'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Start Date'),
              subtitle: Text(_startDate?.toString() ?? 'Not set'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 90)),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _startDate = date;
                  });
                  if (mounted && context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            ),
            ListTile(
              title: const Text('End Date'),
              subtitle: Text(_endDate?.toString() ?? 'Not set'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? DateTime.now(),
                  firstDate:
                      _startDate ??
                      DateTime.now().subtract(const Duration(days: 90)),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    _endDate = date;
                  });
                  if (mounted && context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

/// Dialog for entering rejection reason
class _RejectReasonDialog extends StatefulWidget {
  final bool isBulk;

  const _RejectReasonDialog({this.isBulk = false});

  @override
  State<_RejectReasonDialog> createState() => _RejectReasonDialogState();
}

class _RejectReasonDialogState extends State<_RejectReasonDialog> {
  final _controller = TextEditingController();
  String? _selectedReason;

  final List<String> _commonReasons = [
    'GPS inaccuracy',
    'Outside geofence',
    'Excessive hours',
    'Duplicate entry',
    'Other',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isBulk ? 'Reject Entries' : 'Reject Entry'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select or enter rejection reason:'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _selectedReason,
            decoration: const InputDecoration(
              labelText: 'Reason',
              border: OutlineInputBorder(),
            ),
            items: _commonReasons.map((reason) {
              return DropdownMenuItem(value: reason, child: Text(reason));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedReason = value;
                if (value != 'Other') {
                  _controller.text = value ?? '';
                } else {
                  _controller.clear();
                }
              });
            },
          ),
          if (_selectedReason == 'Other') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Custom reason',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final reason = _selectedReason == 'Other'
                ? _controller.text.trim()
                : _selectedReason;
            if (reason != null && reason.isNotEmpty) {
              Navigator.of(context).pop(reason);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
