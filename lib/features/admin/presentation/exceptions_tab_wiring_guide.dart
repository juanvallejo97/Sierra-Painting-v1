/// Admin Exceptions Tab - Wiring Guide
///
/// PURPOSE:
/// Shows how to wire the Exceptions tab with bulk approve functionality.
/// This is a GUIDE/SKELETON - implement in actual admin dashboard.
///
/// FEATURES:
/// - Badge counts for each exception type
/// - Filtered queries using exceptionTags array
/// - Bulk selection + approve
/// - Success toast + refresh
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Exception type filter
enum ExceptionFilter {
  all,
  geofenceOut, // geofence_out
  exceeds12h, // exceeds_12h
  autoClockout, // auto_clockout
  overlap, // overlap
  disputed, // disputed
}

/// Provider for exception counts (badges)
final exceptionCountsProvider =
    StreamProvider.family<Map<ExceptionFilter, int>, String>((ref, companyId) {
      final firestore = FirebaseFirestore.instance;

      // Query for each exception type
      // NOTE: Requires composite index: (companyId, exceptionTags array, clockInAt DESC)
      final geofenceOutQuery = firestore
          .collection('timeEntries')
          .where('companyId', isEqualTo: companyId)
          .where('exceptionTags', arrayContains: 'geofence_out')
          .where('approved', isEqualTo: false); // Only unapproved

      // TODO: Add queries for other exception types and combine snapshots
      // For production, use combineLatest or similar to merge all counts

      // Combine snapshots into counts map
      return geofenceOutQuery.snapshots().map((snapshot) {
        return {
          ExceptionFilter.geofenceOut: snapshot.size,
          ExceptionFilter.exceeds12h: 0, // TODO: Query
          ExceptionFilter.autoClockout: 0, // TODO: Query
          ExceptionFilter.overlap: 0,
          ExceptionFilter.disputed: 0,
          ExceptionFilter.all: snapshot.size, // TODO: Sum all
        };
      });
    });

/// Provider for filtered exception entries
final filteredExceptionsProvider =
    StreamProvider.family<List<QueryDocumentSnapshot>, ExceptionFilter>((
      ref,
      filter,
    ) {
      final firestore = FirebaseFirestore.instance;
      // TODO: Get companyId from auth provider
      final companyId = 'company-id';

      Query query = firestore
          .collection('timeEntries')
          .where('companyId', isEqualTo: companyId)
          .where('approved', isEqualTo: false);

      // Filter by exception type
      switch (filter) {
        case ExceptionFilter.geofenceOut:
          query = query.where('exceptionTags', arrayContains: 'geofence_out');
          break;
        case ExceptionFilter.exceeds12h:
          query = query.where('exceptionTags', arrayContains: 'exceeds_12h');
          break;
        case ExceptionFilter.autoClockout:
          query = query.where('exceptionTags', arrayContains: 'auto_clockout');
          break;
        case ExceptionFilter.overlap:
          query = query.where('exceptionTags', arrayContains: 'overlap');
          break;
        case ExceptionFilter.disputed:
          query = query.where('exceptionTags', arrayContains: 'disputed');
          break;
        case ExceptionFilter.all:
          // No additional filter - all unapproved
          break;
      }

      query = query.orderBy('clockInAt', descending: true).limit(50);

      return query.snapshots().map((snapshot) => snapshot.docs);
    });

/// Exceptions Tab Widget (Skeleton)
class ExceptionsTab extends ConsumerStatefulWidget {
  const ExceptionsTab({super.key});

  @override
  ConsumerState<ExceptionsTab> createState() => _ExceptionsTabState();
}

class _ExceptionsTabState extends ConsumerState<ExceptionsTab> {
  ExceptionFilter _currentFilter = ExceptionFilter.all;
  final Set<String> _selectedEntryIds = {};

  @override
  Widget build(BuildContext context) {
    // TODO: Get companyId from auth provider
    final companyId = 'company-id';

    final countsAsync = ref.watch(exceptionCountsProvider(companyId));
    final entriesAsync = ref.watch(filteredExceptionsProvider(_currentFilter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exceptions'),
        actions: [
          if (_selectedEntryIds.isNotEmpty)
            TextButton.icon(
              onPressed: () => _bulkApprove(context),
              icon: const Icon(Icons.check, color: Colors.white),
              label: Text(
                'Approve (${_selectedEntryIds.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips with badge counts
          countsAsync.when(
            data: (counts) => _buildFilterChips(counts),
            loading: () => const LinearProgressIndicator(),
            error: (error, stack) => Text('Error: $error'),
          ),

          // Exception entries list
          Expanded(
            child: entriesAsync.when(
              data: (entries) => _buildEntriesList(entries),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Error: $error')),
            ),
          ),
        ],
      ),
    );
  }

  /// Build filter chips with badge counts
  Widget _buildFilterChips(Map<ExceptionFilter, int> counts) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: ExceptionFilter.values.map((filter) {
          final count = counts[filter] ?? 0;
          final isSelected = filter == _currentFilter;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_filterLabel(filter)),
                  if (count > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: isSelected ? Colors.blue : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _currentFilter = filter;
                    _selectedEntryIds.clear();
                  });
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Build entries list with checkboxes
  Widget _buildEntriesList(List<QueryDocumentSnapshot> entries) {
    if (entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green),
            SizedBox(height: 16),
            Text('No exceptions to review', style: TextStyle(fontSize: 18)),
            Text(
              'All time entries are approved!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final doc = entries[index];
        final data = doc.data() as Map<String, dynamic>;
        final isSelected = _selectedEntryIds.contains(doc.id);

        return CheckboxListTile(
          value: isSelected,
          onChanged: (checked) {
            setState(() {
              if (checked == true) {
                _selectedEntryIds.add(doc.id);
              } else {
                _selectedEntryIds.remove(doc.id);
              }
            });
          },
          title: Text('${data['userId']} - ${data['jobId']}'),
          subtitle: Text(_formatExceptionTags(data['exceptionTags'] as List?)),
          secondary: Icon(
            _getExceptionIcon(data['exceptionTags'] as List?),
            color: Colors.orange,
          ),
        );
      },
    );
  }

  /// Call bulkApproveTimeEntries function
  Future<void> _bulkApprove(BuildContext context) async {
    if (_selectedEntryIds.isEmpty) return;

    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-east4');
      final callable = functions.httpsCallable('bulkApproveTimeEntries');

      // Show loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Approving entries...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Call function
      final result = await callable.call<Map<String, dynamic>>({
        'entryIds': _selectedEntryIds.toList(),
      });

      final data = result.data;
      final approved = data['approved'] as int;
      final failed = data['failed'] as int;

      // Clear selection
      setState(() {
        _selectedEntryIds.clear();
      });

      // Show success
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✓ Approved $approved entries${failed > 0 ? ' ($failed failed)' : ''}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving entries: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _filterLabel(ExceptionFilter filter) {
    switch (filter) {
      case ExceptionFilter.all:
        return 'All';
      case ExceptionFilter.geofenceOut:
        return 'Geofence';
      case ExceptionFilter.exceeds12h:
        return '12h+';
      case ExceptionFilter.autoClockout:
        return 'Auto';
      case ExceptionFilter.overlap:
        return 'Overlap';
      case ExceptionFilter.disputed:
        return 'Disputed';
    }
  }

  String _formatExceptionTags(List? tags) {
    if (tags == null || tags.isEmpty) return 'No tags';
    return tags.join(', ');
  }

  IconData _getExceptionIcon(List? tags) {
    if (tags == null || tags.isEmpty) return Icons.warning;
    if (tags.contains('geofence_out')) return Icons.location_off;
    if (tags.contains('exceeds_12h')) return Icons.access_time;
    if (tags.contains('auto_clockout')) return Icons.timer_off;
    return Icons.warning;
  }
}
