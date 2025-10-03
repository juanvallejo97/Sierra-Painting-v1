/// Invoices Screen
///
/// PURPOSE:
/// Manage customer invoices and payment tracking.
/// Create invoices from estimates and track payment status.
///
/// FEATURES:
/// - List all invoices
/// - Create new invoices
/// - View invoice details
/// - Generate invoice PDFs
/// - Mark as paid (manual or Stripe)
/// - Track payment status
///
/// PERFORMANCE:
/// - Uses PaginatedListView for efficient list rendering
/// - Automatic pagination at 80% scroll
/// - Memory-efficient with lazy loading
///
/// TODO:
/// - Implement invoice creation form
/// - Add payment recording UI
/// - Add invoice filtering by status
import 'package:flutter/material.dart';
import 'package:sierra_painting/core/widgets/app_navigation.dart';
import 'package:sierra_painting/design/design.dart';
// import 'package:sierra_painting/core/widgets/paginated_list_view.dart'; // Uncomment when implementing list

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      drawer: const AppDrawer(),
      body: const _InvoicesBody(),
      bottomNavigationBar: const AppNavigationBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Create new invoice
        },
        tooltip: 'Create Invoice',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Invoices body - separated for better rebuild isolation
class _InvoicesBody extends StatelessWidget {
  const _InvoicesBody();

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual data from repository
    final hasInvoices = false;

    if (!hasInvoices) {
      return const AppEmpty(
        icon: Icons.receipt_long,
        title: 'No Invoices Yet',
        description: 'Create your first invoice to start getting paid!',
        actionLabel: 'Create Invoice',
        onAction: null, // TODO: Wire to create invoice action
      );
    }

    // Performance-optimized list using PaginatedListView
    // When data is available, replace with:
    // 
    // return PaginatedListView<Invoice>(
    //   itemBuilder: (context, invoice, index) => InvoiceListItem(invoice: invoice),
    //   onLoadMore: () async {
    //     return await ref.read(invoiceRepositoryProvider).fetchInvoices(page: currentPage);
    //   },
    //   emptyWidget: const AppEmpty(
    //     icon: Icons.receipt_long,
    //     title: 'No Invoices Yet',
    //     description: 'Create your first invoice to start getting paid!',
    //   ),
    //   itemExtent: 80.0, // Set for fixed-height items for better performance
    // );
    
    return const Center(child: Text('Invoices list will go here'));
  }
}
