/// Estimate Detail Screen
///
/// PURPOSE:
/// Full-page detail view for a single estimate/quote.
/// Displays all estimate information, line items, and provides actions.
///
/// FEATURES:
/// - Estimate header with status badge
/// - Customer and job information
/// - Itemized line items with calculations
/// - Total breakdown
/// - Action buttons (mark as sent, accepted, etc.)
/// - Loading/error states
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sierra_painting/design/design.dart';
import 'package:sierra_painting/features/estimates/data/estimate_repository.dart';
import 'package:sierra_painting/features/estimates/domain/estimate.dart';

/// Provider for single estimate detail
final estimateDetailProvider = FutureProvider.family<Estimate?, String>((
  ref,
  estimateId,
) async {
  final repository = ref.watch(estimateRepositoryProvider);
  final result = await repository.getEstimate(estimateId);

  return result.when(success: (estimate) => estimate, failure: (error) => null);
});

class EstimateDetailScreen extends ConsumerWidget {
  final String estimateId;

  const EstimateDetailScreen({super.key, required this.estimateId});

  Color _getStatusColor(BuildContext context, EstimateStatus status) {
    switch (status) {
      case EstimateStatus.accepted:
        return Colors.green;
      case EstimateStatus.rejected:
        return Colors.red;
      case EstimateStatus.expired:
        return Colors.grey;
      case EstimateStatus.sent:
        return Colors.blue;
      case EstimateStatus.draft:
        return Colors.orange;
    }
  }

  String _getStatusLabel(EstimateStatus status) {
    switch (status) {
      case EstimateStatus.accepted:
        return 'Accepted';
      case EstimateStatus.rejected:
        return 'Rejected';
      case EstimateStatus.expired:
        return 'Expired';
      case EstimateStatus.sent:
        return 'Sent';
      case EstimateStatus.draft:
        return 'Draft';
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  Future<void> _markAsSent(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Sent'),
        content: const Text(
          'Are you sure you want to mark this estimate as sent?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mark as Sent'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repository = ref.read(estimateRepositoryProvider);
      final result = await repository.markAsSent(estimateId);

      if (context.mounted) {
        result.when(
          success: (estimate) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Estimate marked as sent'),
                backgroundColor: Colors.green,
              ),
            );
            ref.invalidate(estimateDetailProvider);
          },
          failure: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to mark as sent: $error'),
                backgroundColor: Colors.red,
              ),
            );
          },
        );
      }
    }
  }

  Future<void> _markAsAccepted(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Accepted'),
        content: const Text(
          'Are you sure you want to mark this estimate as accepted?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mark as Accepted'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repository = ref.read(estimateRepositoryProvider);
      final result = await repository.markAsAccepted(
        estimateId: estimateId,
        acceptedAt: DateTime.now(),
      );

      if (context.mounted) {
        result.when(
          success: (estimate) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Estimate marked as accepted'),
                backgroundColor: Colors.green,
              ),
            );
            ref.invalidate(estimateDetailProvider);
          },
          failure: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to mark as accepted: $error'),
                backgroundColor: Colors.red,
              ),
            );
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimateAsync = ref.watch(estimateDetailProvider(estimateId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estimate Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(estimateDetailProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: estimateAsync.when(
        data: (estimate) {
          if (estimate == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceXL),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: DesignTokens.spaceMD),
                    Text(
                      'Estimate not found',
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            );
          }

          final statusColor = _getStatusColor(context, estimate.status);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(DesignTokens.spaceLG),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(DesignTokens.spaceLG),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Estimate number and status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Estimate #${estimate.id?.substring(0, 8) ?? 'NEW'}',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            AppBadge(
                              label: _getStatusLabel(estimate.status),
                              backgroundColor: statusColor,
                              foregroundColor: Colors.white,
                            ),
                          ],
                        ),
                        const SizedBox(height: DesignTokens.spaceLG),

                        // Customer ID
                        _InfoRow(
                          icon: Icons.person,
                          label: 'Customer',
                          value: estimate.customerId,
                        ),
                        const SizedBox(height: DesignTokens.spaceSM),

                        // Job ID
                        if (estimate.jobId != null)
                          _InfoRow(
                            icon: Icons.work,
                            label: 'Job',
                            value: estimate.jobId!,
                          ),
                        if (estimate.jobId != null)
                          const SizedBox(height: DesignTokens.spaceSM),

                        // Valid Until date
                        _InfoRow(
                          icon: Icons.calendar_today,
                          label: 'Valid Until',
                          value: _formatDate(estimate.validUntil),
                          valueColor: estimate.isExpired ? Colors.red : null,
                        ),
                        const SizedBox(height: DesignTokens.spaceSM),

                        // Created date
                        _InfoRow(
                          icon: Icons.schedule,
                          label: 'Created',
                          value: _formatDate(estimate.createdAt),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceLG),

                // Line Items Section
                Text(
                  'Line Items',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceMD),

                ...estimate.items.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: DesignTokens.spaceSM,
                    ),
                    child: AppCard(
                      child: Padding(
                        padding: const EdgeInsets.all(DesignTokens.spaceMD),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Item number and description
                            Text(
                              'Item ${index + 1}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: DesignTokens.spaceXS),
                            Text(
                              item.description,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: DesignTokens.spaceSM),

                            // Quantity, unit price, discount, total
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Qty: ${item.quantity}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    Text(
                                      'Unit: ${_formatCurrency(item.unitPrice)}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    if (item.discount != null)
                                      Text(
                                        'Discount: ${_formatCurrency(item.discount!)}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: Colors.green),
                                      ),
                                  ],
                                ),
                                Text(
                                  _formatCurrency(item.total),
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: DesignTokens.spaceLG),

                // Total Card
                AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(DesignTokens.spaceLG),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Amount',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _formatCurrency(estimate.amount),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Notes
                if (estimate.notes != null) ...[
                  const SizedBox(height: DesignTokens.spaceLG),
                  Text(
                    'Notes',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceMD),
                  AppCard(
                    child: Padding(
                      padding: const EdgeInsets.all(DesignTokens.spaceMD),
                      child: Text(
                        estimate.notes!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: DesignTokens.spaceXL),

                // Actions
                if (estimate.status == EstimateStatus.draft)
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Mark as Sent',
                      icon: Icons.send,
                      onPressed: () => _markAsSent(context, ref),
                    ),
                  ),
                if (estimate.status == EstimateStatus.sent)
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Mark as Accepted',
                      icon: Icons.check_circle,
                      onPressed: () => _markAsAccepted(context, ref),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.spaceXL),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: theme.colorScheme.error.withValues(alpha: 0.5),
                ),
                const SizedBox(height: DesignTokens.spaceMD),
                Text(
                  'Failed to load estimate',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: DesignTokens.spaceSM),
                Text(
                  error.toString(),
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Info row widget for displaying labeled information
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
        const SizedBox(width: DesignTokens.spaceSM),
        Text(
          '$label:',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(width: DesignTokens.spaceSM),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
