/// Estimates List Screen
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/widgets/admin_scaffold.dart';
import 'package:sierra_painting/features/estimates/domain/estimate.dart';
import 'package:sierra_painting/features/estimates/presentation/providers/estimate_list_provider.dart';

class EstimatesScreen extends ConsumerStatefulWidget {
  const EstimatesScreen({super.key});

  @override
  ConsumerState<EstimatesScreen> createState() => _EstimatesScreenState();
}

class _EstimatesScreenState extends ConsumerState<EstimatesScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final estimatesAsync = ref.watch(estimateListProvider);

    return AdminScaffold(
      title: 'Estimates',
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search estimates by customer...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Estimates List
          Expanded(
            child: estimatesAsync.when(
              data: (estimates) {
                var filteredEstimates = estimates;
                if (_searchQuery.isNotEmpty) {
                  filteredEstimates = estimates
                      .where(
                        (e) => e.customerId.toLowerCase().contains(
                          _searchQuery.toLowerCase(),
                        ),
                      )
                      .toList();
                }

                if (filteredEstimates.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          estimates.isEmpty
                              ? 'No estimates yet'
                              : 'No matching estimates',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          estimates.isEmpty
                              ? 'Create your first estimate'
                              : 'Try adjusting your search',
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
                  itemCount: filteredEstimates.length,
                  itemBuilder: (context, index) =>
                      _buildEstimateCard(filteredEstimates[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading estimates',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(estimateListProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/estimates/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Estimate'),
      ),
    );
  }

  Widget _buildEstimateCard(Estimate estimate) {
    Color statusColor;
    IconData statusIcon;

    switch (estimate.status) {
      case EstimateStatus.accepted:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case EstimateStatus.sent:
        statusColor = Colors.blue;
        statusIcon = Icons.send;
        break;
      case EstimateStatus.draft:
        statusColor = Colors.orange;
        statusIcon = Icons.drafts;
        break;
      case EstimateStatus.rejected:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case EstimateStatus.expired:
        statusColor = Colors.grey;
        statusIcon = Icons.schedule;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(statusIcon, color: statusColor, size: 32),
        title: Text(
          'Customer: ${estimate.customerId}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              '\$${estimate.amount.toStringAsFixed(2)} ${estimate.currency}',
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Valid until: ${_formatDate(estimate.validUntil)}'),
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
                    estimate.status.name.toUpperCase(),
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
        onTap: () => Navigator.pushNamed(context, '/estimates/${estimate.id}'),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
