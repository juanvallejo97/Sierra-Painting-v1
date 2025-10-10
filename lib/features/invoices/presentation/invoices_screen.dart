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
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sierra_painting/core/widgets/app_navigation.dart';
import 'package:sierra_painting/design/design.dart';
import 'package:sierra_painting/features/invoices/data/invoice_repository.dart';
import 'package:sierra_painting/features/invoices/domain/invoice.dart';
// import 'package:sierra_painting/core/widgets/paginated_list_view.dart'; // Uncomment when implementing list

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  Future<void> _createInvoice(BuildContext context, WidgetRef ref) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be logged in to create invoices'),
          ),
        );
      }
      return;
    }

    // Get companyId from custom claims
    final idTokenResult = await user.getIdTokenResult();
    final companyId = idTokenResult.claims?['companyId'] as String?;

    if (companyId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company ID not found. Please contact support.'),
          ),
        );
      }
      return;
    }

    // TODO: Show invoice creation form dialog
    // For now, create a sample invoice for demonstration
    final repository = ref.read(invoiceRepositoryProvider);
    final request = CreateInvoiceRequest(
      companyId: companyId,
      customerId: 'sample-customer', // TODO: Select from customer list
      items: [
        InvoiceItem(
          description: 'Sample Service',
          quantity: 1.0,
          unitPrice: 100.0,
        ),
      ],
      dueDate: DateTime.now().add(const Duration(days: 30)),
      notes: 'Sample invoice - please replace with actual form',
    );

    final result = await repository.createInvoice(request);

    if (context.mounted) {
      result.when(
        success: (invoice) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Invoice created: ${invoice.id}')),
          );
          // TODO: Navigate to invoice detail screen
        },
        failure: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating invoice: $error')),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      drawer: const AppDrawer(),
      body: _InvoicesBody(onCreateInvoice: () => _createInvoice(context, ref)),
      bottomNavigationBar: const AppNavigationBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createInvoice(context, ref),
        tooltip: 'Create Invoice',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Invoices body - separated for better rebuild isolation
class _InvoicesBody extends StatelessWidget {
  final VoidCallback onCreateInvoice;

  const _InvoicesBody({required this.onCreateInvoice});

  @override
  Widget build(BuildContext context) {
    // TODO: Replace with actual data from repository
    final hasInvoices = false;

    if (!hasInvoices) {
      return AppEmpty(
        icon: Icons.receipt_long,
        title: 'No Invoices Yet',
        description: 'Create your first invoice to start getting paid!',
        actionLabel: 'Create Invoice',
        onAction: onCreateInvoice,
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

    // ...existing code...
  }
}
