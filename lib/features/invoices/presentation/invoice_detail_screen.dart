/// Invoice Detail Screen
///
/// PURPOSE:
/// Full-page detail view for a single invoice.
/// Displays all invoice information, line items, and provides actions.
///
/// FEATURES:
/// - Invoice header with status badge
/// - Customer and job information
/// - Itemized line items with calculations
/// - Total breakdown
/// - Action buttons (mark as paid, cancel, etc.)
/// - Loading/error states
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sierra_painting/design/design.dart';
import 'package:sierra_painting/features/invoices/data/invoice_repository.dart';
import 'package:sierra_painting/features/invoices/domain/invoice.dart';

/// Provider for single invoice detail
final invoiceDetailProvider = FutureProvider.family<Invoice?, String>((
  ref,
  invoiceId,
) async {
  final repository = ref.watch(invoiceRepositoryProvider);
  final result = await repository.getInvoice(invoiceId);

  return result.when(success: (invoice) => invoice, failure: (error) => null);
});

class InvoiceDetailScreen extends ConsumerWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  Color _getStatusColor(BuildContext context, InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return Colors.green;
      case InvoiceStatus.overdue:
        return Colors.red;
      case InvoiceStatus.cancelled:
        return Colors.grey;
      case InvoiceStatus.pending:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _getStatusLabel(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.overdue:
        return 'Overdue';
      case InvoiceStatus.cancelled:
        return 'Cancelled';
      case InvoiceStatus.pending:
        return 'Pending';
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(symbol: '\$', decimalDigits: 2).format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  Future<void> _markAsPaid(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Paid'),
        content: const Text(
          'Are you sure you want to mark this invoice as paid?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Mark as Paid'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repository = ref.read(invoiceRepositoryProvider);
      final result = await repository.markAsPaid(
        invoiceId: invoiceId,
        paidAt: DateTime.now(),
      );

      if (context.mounted) {
        result.when(
          success: (invoice) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Invoice marked as paid'),
                backgroundColor: Colors.green,
              ),
            );
            ref.invalidate(invoiceDetailProvider);
          },
          failure: (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to mark as paid: $error'),
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
    final invoiceAsync = ref.watch(invoiceDetailProvider(invoiceId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(invoiceDetailProvider),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: invoiceAsync.when(
        data: (invoice) {
          if (invoice == null) {
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
                      'Invoice not found',
                      style: theme.textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            );
          }

          final statusColor = _getStatusColor(context, invoice.status);

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
                        // Invoice number and status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Invoice #${invoice.id?.substring(0, 8) ?? 'NEW'}',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            AppBadge(
                              label: _getStatusLabel(invoice.status),
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
                          value: invoice.customerId,
                        ),
                        const SizedBox(height: DesignTokens.spaceSM),

                        // Job ID
                        if (invoice.jobId != null)
                          _InfoRow(
                            icon: Icons.work,
                            label: 'Job',
                            value: invoice.jobId!,
                          ),
                        if (invoice.jobId != null)
                          const SizedBox(height: DesignTokens.spaceSM),

                        // Due date
                        _InfoRow(
                          icon: Icons.calendar_today,
                          label: 'Due Date',
                          value: _formatDate(invoice.dueDate),
                          valueColor: invoice.isOverdue ? Colors.red : null,
                        ),
                        const SizedBox(height: DesignTokens.spaceSM),

                        // Created date
                        _InfoRow(
                          icon: Icons.schedule,
                          label: 'Created',
                          value: _formatDate(invoice.createdAt),
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

                ...invoice.items.asMap().entries.map((entry) {
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
                          _formatCurrency(invoice.amount),
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
                if (invoice.notes != null) ...[
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
                        invoice.notes!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: DesignTokens.spaceXL),

                // Actions
                if (invoice.status == InvoiceStatus.pending ||
                    invoice.status == InvoiceStatus.overdue)
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Mark as Paid',
                      icon: Icons.check_circle,
                      onPressed: () => _markAsPaid(context, ref),
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
                  'Failed to load invoice',
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
