/// Estimate List Item Widget
///
/// PURPOSE:
/// Displays estimate information in a list format.
/// Shows key details: amount, customer, status, valid until date.
///
/// FEATURES:
/// - Status badge with color coding
/// - Formatted currency display
/// - Valid until date with expired indicator
/// - Tap to view details
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sierra_painting/design/design.dart';
import 'package:sierra_painting/features/estimates/domain/estimate.dart';

class EstimateListItem extends StatelessWidget {
  final Estimate estimate;
  final VoidCallback? onTap;

  const EstimateListItem({super.key, required this.estimate, this.onTap});

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
    final statusColor = _getStatusColor(context, estimate.status);

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

            // Estimate details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Estimate number and status
                  Row(
                    children: [
                      Text(
                        'Estimate #${estimate.id?.substring(0, 8) ?? 'NEW'}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: DesignTokens.spaceSM),
                      AppBadge(
                        label: _getStatusLabel(estimate.status),
                        backgroundColor: statusColor,
                        foregroundColor: Colors.white,
                      ),
                    ],
                  ),
                  const SizedBox(height: DesignTokens.spaceXS),

                  // Customer ID (TODO: Replace with customer name lookup)
                  Text(
                    'Customer: ${estimate.customerId}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spaceXS),

                  // Valid until date
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: estimate.isExpired ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Valid until: ${_formatDate(estimate.validUntil)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: estimate.isExpired
                              ? Colors.red
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                          fontWeight: estimate.isExpired
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
                  _formatCurrency(estimate.amount, estimate.currency),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceXS),
                Text(
                  '${estimate.items.length} item${estimate.items.length != 1 ? 's' : ''}',
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
