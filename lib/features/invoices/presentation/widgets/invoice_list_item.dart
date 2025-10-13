/// Invoice List Item Widget
///
/// PURPOSE:
/// Displays invoice information in a list format.
/// Shows key details: amount, customer, status, due date.
///
/// FEATURES:
/// - Status badge with color coding
/// - Formatted currency display
/// - Due date with overdue indicator
/// - Tap to view details
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sierra_painting/design/design.dart';
import 'package:sierra_painting/features/invoices/domain/invoice.dart';

class InvoiceListItem extends StatelessWidget {
  final Invoice invoice;
  final VoidCallback? onTap;

  const InvoiceListItem({super.key, required this.invoice, this.onTap});

  Color _getStatusColor(BuildContext context, InvoiceStatus status) {
    final theme = Theme.of(context);
    switch (status) {
      case InvoiceStatus.paid:
        return Colors.green;
      case InvoiceStatus.overdue:
        return Colors.red;
      case InvoiceStatus.cancelled:
        return Colors.grey;
      case InvoiceStatus.pending:
        return theme.colorScheme.primary;
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

  String _formatCurrency(double amount, String currency) {
    final formatter = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    return formatter.format(amount);
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(context, invoice.status);

    return AppCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 4,
              height: 60,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: DesignTokens.spaceMD),

            // Invoice details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Invoice number and status
                  Row(
                    children: [
                      Text(
                        'Invoice #${invoice.id?.substring(0, 8) ?? 'NEW'}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spaceSM),
                      AppBadge(
                        label: _getStatusLabel(invoice.status),
                        backgroundColor: statusColor,
                        foregroundColor: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.spaceXS),

                  // Customer ID (TODO: Replace with customer name lookup)
                  Text(
                    'Customer: ${invoice.customerId}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceXS),

                  // Due date
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: invoice.isOverdue ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Due: ${_formatDate(invoice.dueDate)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: invoice.isOverdue
                              ? Colors.red
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                          fontWeight: invoice.isOverdue
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Amount
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatCurrency(invoice.amount, invoice.currency),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceXS),
                Text(
                  '${invoice.items.length} item${invoice.items.length != 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
