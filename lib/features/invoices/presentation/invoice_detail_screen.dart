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
      case InvoiceStatus.draft:
        return Colors.grey;
      case InvoiceStatus.sent:
        return Colors.blue;
      case InvoiceStatus.paid:
      case InvoiceStatus.paidCash:
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
      case InvoiceStatus.draft:
        return 'Draft';
      case InvoiceStatus.sent:
        return 'Sent';
      case InvoiceStatus.paid:
        return 'Paid';
      case InvoiceStatus.paidCash:
        return 'Paid (Cash)';
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

  Future<void> _markAsSent(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Sent'),
        content: const Text(
          'Are you sure you want to mark this invoice as sent to the customer?',
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
      final repository = ref.read(invoiceRepositoryProvider);
      final result = await repository.markAsSent(invoiceId: invoiceId);

      if (context.mounted) {
        result.when(
          success: (invoice) {
            // Show success with Undo button (15s window)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Invoice marked as sent'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 15),
                action: SnackBarAction(
                  label: 'Undo',
                  textColor: Colors.white,
                  onPressed: () async {
                    final undoResult =
                        await repository.revertStatus(invoiceId: invoiceId);
                    if (context.mounted) {
                      undoResult.when(
                        success: (invoice) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Status reverted'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          ref.invalidate(invoiceDetailProvider);
                        },
                        failure: (error) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
              ),
            );
            ref.invalidate(invoiceDetailProvider);
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

  Future<void> _markAsPaidCash(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Paid (Cash)'),
        content: const Text(
          'Are you sure you want to mark this invoice as paid with cash?',
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
      final result = await repository.markAsPaidCash(
        invoiceId: invoiceId,
        paidAt: DateTime.now(),
      );

      if (context.mounted) {
        result.when(
          success: (invoice) {
            // Show success with Undo button (15s window)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Invoice marked as paid (cash)'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 15),
                action: SnackBarAction(
                  label: 'Undo',
                  textColor: Colors.white,
                  onPressed: () async {
                    final undoResult =
                        await repository.revertStatus(invoiceId: invoiceId);
                    if (context.mounted) {
                      undoResult.when(
                        success: (invoice) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Payment status reverted'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          ref.invalidate(invoiceDetailProvider);
                        },
                        failure: (error) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(error),
                              backgroundColor: Colors.orange,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                      );
                    }
                  },
                ),
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
                              invoice.number ??
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

                        // Customer Name
                        _InfoRow(
                          icon: Icons.person,
                          label: 'Customer',
                          value: invoice.customerName,
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
                    child: Column(
                      children: [
                        // Subtotal
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Subtotal',
                              style: theme.textTheme.titleMedium,
                            ),
                            Text(
                              _formatCurrency(invoice.subtotal),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DesignTokens.spaceSM),
                        // Tax
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Tax', style: theme.textTheme.titleMedium),
                            Text(
                              _formatCurrency(invoice.tax),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: DesignTokens.spaceLG),
                        // Total
                        Row(
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
                if (invoice.status == InvoiceStatus.draft)
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Mark as Sent',
                      icon: Icons.send,
                      onPressed: () => _markAsSent(context, ref),
                    ),
                  ),
                if (invoice.status == InvoiceStatus.sent ||
                    invoice.status == InvoiceStatus.pending ||
                    invoice.status == InvoiceStatus.overdue)
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      label: 'Mark as Paid (Cash)',
                      icon: Icons.attach_money,
                      onPressed: () => _markAsPaidCash(context, ref),
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
