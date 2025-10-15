/// Invoice Create Screen
///
/// PURPOSE:
/// Full-page form for creating new invoices.
/// Handles line items, validation, and total calculation.
///
/// FEATURES:
/// - Customer and job ID fields
/// - Dynamic line items (add/remove)
/// - Real-time total calculation
/// - Date picker for due date
/// - Form validation
/// - Loading/error states
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sierra_painting/core/money/money.dart';
import 'package:sierra_painting/design/design.dart';
import 'package:sierra_painting/features/invoices/domain/invoice.dart';
import 'package:sierra_painting/features/invoices/presentation/providers/invoice_form_provider.dart';

class InvoiceCreateScreen extends ConsumerStatefulWidget {
  const InvoiceCreateScreen({super.key});

  @override
  ConsumerState<InvoiceCreateScreen> createState() =>
      _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends ConsumerState<InvoiceCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerIdController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _jobIdController = TextEditingController();
  final _taxRateController = TextEditingController(text: '0.0');
  final _notesController = TextEditingController();

  // Line items state
  final List<_LineItemData> _lineItems = [_LineItemData()];

  DateTime _dueDate = DateTime.now().add(
    const Duration(days: 7),
  ); // Default 7 days

  @override
  void dispose() {
    _customerIdController.dispose();
    _customerNameController.dispose();
    _jobIdController.dispose();
    _taxRateController.dispose();
    _notesController.dispose();
    for (final item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }

  Money _calculateSubtotal() {
    return _lineItems.fold(Money.zero, (total, item) {
      final quantity = double.tryParse(item.quantityController.text) ?? 0.0;
      final unitPrice =
          Money.tryParse(item.unitPriceController.text) ?? Money.zero;
      final discount =
          Money.tryParse(item.discountController.text) ?? Money.zero;

      // Calculate: (unitPrice * quantity) - discount
      final lineTotal = unitPrice.multiply(quantity).subtract(discount);
      return total.add(lineTotal);
    });
  }

  Money _calculateTax() {
    final taxRate = double.tryParse(_taxRateController.text) ?? 0.0;
    return _calculateSubtotal().percentage(taxRate);
  }

  Money _calculateTotal() {
    return _calculateSubtotal().add(_calculateTax());
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(_LineItemData());
    });
  }

  void _removeLineItem(int index) {
    if (_lineItems.length > 1) {
      setState(() {
        _lineItems[index].dispose();
        _lineItems.removeAt(index);
      });
    }
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Convert line items to domain models
    final items = _lineItems.map((item) {
      return InvoiceItem(
        description: item.descriptionController.text,
        quantity: double.parse(item.quantityController.text),
        unitPrice: double.parse(item.unitPriceController.text),
        discount: item.discountController.text.isNotEmpty
            ? double.parse(item.discountController.text)
            : null,
      );
    }).toList();

    // Submit form
    ref
        .read(invoiceFormProvider.notifier)
        .createInvoice(
          customerId: _customerIdController.text,
          customerName: _customerNameController.text,
          jobId: _jobIdController.text,
          items: items,
          taxRate: double.tryParse(_taxRateController.text) ?? 0.0,
          notes: _notesController.text,
          dueDate: _dueDate,
        );
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(invoiceFormProvider);
    final theme = Theme.of(context);

    // Listen for successful creation
    ref.listen<InvoiceFormState>(invoiceFormProvider, (previous, next) {
      if (next.createdInvoice != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invoice created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      } else if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Invoice'),
        actions: [
          if (formState.isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: CircularProgressIndicator(),
              ),
            )
          else
            Semantics(
              label: 'Save Invoice',
              hint: 'Save the invoice',
              button: true,
              child: TextButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.save),
                label: const Text('Save'),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(DesignTokens.spaceLG),
          children: [
            // Header
            Text(
              'Invoice Details',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceMD),

            // Customer Name
            AppInput(
              controller: _customerNameController,
              label: 'Customer Name',
              hint: 'Enter customer name',
              prefixIcon: Icons.person,
              keyboardType: TextInputType.text,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Customer name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: DesignTokens.spaceMD),

            // Customer ID
            AppInput(
              controller: _customerIdController,
              label: 'Customer ID',
              hint: 'Enter customer ID (for reference)',
              prefixIcon: Icons.badge,
              keyboardType: TextInputType.text,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Customer ID is required';
                }
                return null;
              },
            ),
            const SizedBox(height: DesignTokens.spaceMD),

            // Job ID (optional)
            AppInput(
              controller: _jobIdController,
              label: 'Job ID (Optional)',
              hint: 'Enter job ID',
              prefixIcon: Icons.work,
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: DesignTokens.spaceMD),

            // Tax Rate
            AppInput(
              controller: _taxRateController,
              label: 'Tax Rate (%)',
              hint: 'Enter tax rate (e.g., 8.5 for 8.5%)',
              prefixIcon: Icons.percent,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}), // Trigger total recalculation
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final rate = double.tryParse(value);
                  if (rate == null || rate < 0 || rate > 100) {
                    return 'Invalid tax rate';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: DesignTokens.spaceMD),

            // Due Date
            AppCard(
              child: ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Due Date'),
                subtitle: Text(DateFormat('MMM d, yyyy').format(_dueDate)),
                trailing: const Icon(Icons.edit),
                onTap: _selectDueDate,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceLG),

            // Line Items Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Line Items',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addLineItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceSM),

            // Line items list
            ..._lineItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return _LineItemCard(
                key: ValueKey(item),
                item: item,
                index: index,
                canRemove: _lineItems.length > 1,
                onRemove: () => _removeLineItem(index),
                onChanged: () => setState(() {}), // Trigger total recalculation
              );
            }),

            const SizedBox(height: DesignTokens.spaceMD),

            // Total Breakdown
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(DesignTokens.spaceMD),
                child: Column(
                  children: [
                    // Subtotal
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Subtotal', style: theme.textTheme.titleMedium),
                        Text(
                          _calculateSubtotal().format(),
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
                        Text(
                          'Tax (${_taxRateController.text}%)',
                          style: theme.textTheme.titleMedium,
                        ),
                        Text(
                          _calculateTax().format(),
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
                          'Total',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _calculateTotal().format(),
                          style: theme.textTheme.headlineSmall?.copyWith(
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
            const SizedBox(height: DesignTokens.spaceLG),

            // Notes
            Text(
              'Notes (Optional)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceSM),
            AppInput(
              controller: _notesController,
              label: 'Notes',
              hint: 'Add any additional notes',
              maxLines: 4,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: DesignTokens.spaceXL),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: 'Create Invoice',
                icon: Icons.check,
                onPressed: formState.isLoading ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Line item data holder
class _LineItemData {
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController unitPriceController = TextEditingController();
  final TextEditingController discountController = TextEditingController();

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    unitPriceController.dispose();
    discountController.dispose();
  }
}

/// Line item card widget
class _LineItemCard extends StatelessWidget {
  final _LineItemData item;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _LineItemCard({
    super.key,
    required this.item,
    required this.index,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with remove button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Item ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (canRemove)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: onRemove,
                    tooltip: 'Remove item',
                  ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceSM),

            // Description
            AppInput(
              controller: item.descriptionController,
              label: 'Description',
              hint: 'Item description',
              keyboardType: TextInputType.text,
              onChanged: (_) => onChanged(),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Description is required';
                }
                return null;
              },
            ),
            const SizedBox(height: DesignTokens.spaceSM),

            // Quantity and Unit Price
            Row(
              children: [
                Expanded(
                  child: AppInput(
                    controller: item.quantityController,
                    label: 'Quantity',
                    hint: '0',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => onChanged(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: DesignTokens.spaceSM),
                Expanded(
                  child: AppInput(
                    controller: item.unitPriceController,
                    label: 'Unit Price',
                    hint: '0.00',
                    keyboardType: TextInputType.number,
                    onChanged: (_) => onChanged(),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spaceSM),

            // Discount
            AppInput(
              controller: item.discountController,
              label: 'Discount (Optional)',
              hint: '0.00',
              keyboardType: TextInputType.number,
              onChanged: (_) => onChanged(),
              validator: (value) {
                if (value != null &&
                    value.isNotEmpty &&
                    double.tryParse(value) == null) {
                  return 'Invalid discount amount';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
