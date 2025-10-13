/// Invoice List Content Widget
///
/// PURPOSE:
/// Displays invoice list with loading/error/empty states.
/// Embedded in dashboard, handles all list logic internally.
///
/// FEATURES:
/// - Loading state with skeleton
/// - Error state with retry
/// - Empty state with action
/// - List with pull-to-refresh
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/design/design.dart';
import 'package:sierra_painting/features/invoices/presentation/providers/invoice_list_provider.dart';
import 'package:sierra_painting/features/invoices/presentation/widgets/invoice_list_item.dart';

class InvoiceListContent extends ConsumerWidget {
  final VoidCallback? onCreateInvoice;

  const InvoiceListContent({super.key, this.onCreateInvoice});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceListAsync = ref.watch(invoiceListProvider);

    return invoiceListAsync.when(
      data: (invoices) {
        if (invoices.isEmpty) {
          return AppEmpty(
            icon: Icons.receipt_long,
            title: 'No Invoices Yet',
            description: 'Create your first invoice to start getting paid!',
            actionLabel: onCreateInvoice != null ? 'Create Invoice' : null,
            onAction: onCreateInvoice,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(invoiceListProvider);
            // Wait for the refresh to complete
            await ref.read(invoiceListProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.all(DesignTokens.spaceMD),
            itemCount: invoices.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: DesignTokens.spaceSM),
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              return InvoiceListItem(
                invoice: invoice,
                onTap: () {
                  if (invoice.id != null) {
                    Navigator.of(context).pushNamed('/invoices/${invoice.id}');
                  }
                },
              );
            },
          ),
        );
      },
      loading: () => _buildLoading(),
      error: (error, stack) => _buildError(context, ref, error),
    );
  }

  Widget _buildLoading() {
    return ListView.separated(
      padding: const EdgeInsets.all(DesignTokens.spaceMD),
      itemCount: 5, // Show 5 skeleton items
      separatorBuilder: (context, index) =>
          const SizedBox(height: DesignTokens.spaceSM),
      itemBuilder: (context, index) =>
          const AppSkeleton(width: double.infinity, height: 100),
    );
  }

  Widget _buildError(BuildContext context, WidgetRef ref, Object error) {
    final theme = Theme.of(context);

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
              'Failed to load invoices',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceSM),
            Text(
              error.toString(),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spaceLG),
            AppButton(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () {
                ref.invalidate(invoiceListProvider);
              },
            ),
          ],
        ),
      ),
    );
  }
}
