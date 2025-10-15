/// Invoices List Screen
///
/// PURPOSE:
/// Shows list of all invoices for admins to manage and track payments.
///
/// FEATURES:
/// - List of invoices with status, customer, amount, and due date
/// - Search by customer ID
/// - Filter by status
/// - Tap to view details
/// - Empty state for no invoices
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/widgets/admin_scaffold.dart';
import 'package:sierra_painting/features/invoices/domain/invoice.dart';
import 'package:sierra_painting/features/invoices/presentation/providers/invoice_list_provider.dart';

class InvoicesScreen extends ConsumerStatefulWidget {
  const InvoicesScreen({super.key});

  @override
  ConsumerState<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends ConsumerState<InvoicesScreen> {
  String _searchQuery = '';
  InvoiceStatus? _statusFilter;

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoiceListProvider);

    return AdminScaffold(
      title: 'Invoices',
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          tooltip: 'Filter',
          onPressed: _showFilterDialog,
        ),
      ],
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search invoices by customer...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),

          // Invoices List
          Expanded(
            child: invoicesAsync.when(
              data: (invoices) {
                // Apply search and filters
                var filteredInvoices = invoices;

                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  filteredInvoices = invoices.where((invoice) {
                    return invoice.customerName.toLowerCase().contains(query) ||
                        invoice.customerId.toLowerCase().contains(query) ||
                        (invoice.number?.toLowerCase().contains(query) ??
                            false);
                  }).toList();
                }

                if (_statusFilter != null) {
                  filteredInvoices = filteredInvoices
                      .where((invoice) => invoice.status == _statusFilter)
                      .toList();
                }

                if (filteredInvoices.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          invoices.isEmpty
                              ? 'No invoices yet'
                              : 'No matching invoices',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          invoices.isEmpty
                              ? 'Create your first invoice to get started'
                              : 'Try adjusting your search or filters',
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
                  itemCount: filteredInvoices.length,
                  itemBuilder: (context, index) {
                    return _buildInvoiceCard(filteredInvoices[index]);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text(
                        'Error loading invoices',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: const TextStyle(fontSize: 14),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(invoiceListProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, '/invoices/create'),
        icon: const Icon(Icons.add),
        label: const Text('New Invoice'),
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    Color statusColor;
    IconData statusIcon;

    // Determine actual status (check if overdue)
    final effectiveStatus =
        invoice.isOverdue &&
            (invoice.status == InvoiceStatus.pending ||
                invoice.status == InvoiceStatus.sent)
        ? InvoiceStatus.overdue
        : invoice.status;

    switch (effectiveStatus) {
      case InvoiceStatus.draft:
        statusColor = Colors.grey;
        statusIcon = Icons.edit;
        break;
      case InvoiceStatus.sent:
        statusColor = Colors.blue;
        statusIcon = Icons.send;
        break;
      case InvoiceStatus.paid:
      case InvoiceStatus.paidCash:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case InvoiceStatus.pending:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
        break;
      case InvoiceStatus.overdue:
        statusColor = Colors.red;
        statusIcon = Icons.warning;
        break;
      case InvoiceStatus.cancelled:
        statusColor = Colors.grey;
        statusIcon = Icons.cancel;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(statusIcon, color: statusColor, size: 32),
        title: Text(
          invoice.number ?? 'Invoice #${invoice.id?.substring(0, 8) ?? 'NEW'}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Customer: ${invoice.customerName}',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              '\$${invoice.amount.toStringAsFixed(2)} ${invoice.currency}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Due: ${_formatDate(invoice.dueDate)}'),
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
                    _getStatusLabel(effectiveStatus),
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
        onTap: () => Navigator.pushNamed(context, '/invoices/${invoice.id}'),
      ),
    );
  }

  String _getStatusLabel(InvoiceStatus status) {
    switch (status) {
      case InvoiceStatus.draft:
        return 'DRAFT';
      case InvoiceStatus.sent:
        return 'SENT';
      case InvoiceStatus.paid:
        return 'PAID';
      case InvoiceStatus.paidCash:
        return 'PAID (CASH)';
      case InvoiceStatus.pending:
        return 'PENDING';
      case InvoiceStatus.overdue:
        return 'OVERDUE';
      case InvoiceStatus.cancelled:
        return 'CANCELLED';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Invoices'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Status:'),
            const SizedBox(height: 8),
            ...InvoiceStatus.values.map((status) {
              return RadioListTile<InvoiceStatus?>(
                title: Text(_getStatusLabel(status)),
                value: status,
                groupValue: _statusFilter,
                onChanged: (value) {
                  setState(() {
                    _statusFilter = value;
                  });
                  Navigator.pop(context);
                },
              );
            }),
            RadioListTile<InvoiceStatus?>(
              title: const Text('All'),
              value: null,
              groupValue: _statusFilter,
              onChanged: (value) {
                setState(() {
                  _statusFilter = null;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
