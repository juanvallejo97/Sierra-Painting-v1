import 'package:flutter/material.dart';
import 'package:sierra_painting/core/widgets/app_navigation.dart';
import 'package:sierra_painting/design/design.dart';

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

    // TODO: Implement list with ListView.builder for performance
    return const Center(child: Text('Invoices list will go here'));
  }
}
