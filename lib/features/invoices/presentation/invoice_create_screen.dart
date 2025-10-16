/// Enhanced Invoice Creation Screen
///
/// PURPOSE:
/// Create professional invoices with D'Sierra branding
/// Supports draft → sent → paid workflow
///
/// FEATURES:
/// - Customer name and tax rate fields
/// - Line item editor (description, quantity, rate)
/// - Real-time subtotal/tax/total calculation
/// - Auto-generated invoice numbers (INV-YYYYMM-####)
/// - PDF generation with D'Sierra logo
/// - Save as draft or send immediately
///
/// HAIKU TODO:
/// - Enhance existing invoice form
/// - Add customer name field (not just ID)
/// - Add tax rate selector
/// - Implement PDF template with branding
/// - Wire up send email functionality
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers/auth_provider.dart';
import 'package:sierra_painting/design/tokens.dart';

class InvoiceCreateScreen extends ConsumerStatefulWidget {
  final String? invoiceId; // For editing existing draft

  const InvoiceCreateScreen({super.key, this.invoiceId});

  @override
  ConsumerState<InvoiceCreateScreen> createState() => _InvoiceCreateScreenState();
}

class _InvoiceCreateScreenState extends ConsumerState<InvoiceCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  double _taxRate = 0.0825; // Default 8.25%
  final List<LineItem> _lineItems = [];
  String? _invoiceNumber;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.invoiceId != null) {
      _loadInvoice(widget.invoiceId!);
    } else {
      // Add one empty line item and generate invoice number
      _lineItems.add(LineItem());
      _generateInvoiceNumber();
    }
  }

  /// Generate auto-incrementing invoice number (INV-YYYYMM-####)
  Future<void> _generateInvoiceNumber() async {
    try {
      final companyId = ref.read(userCompanyProvider);
      if (companyId == null) return;

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0);

      final invoicesSnap = await FirebaseFirestore.instance
          .collection('companies/$companyId/invoices')
          .where('createdAt',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(monthEnd))
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      int nextNumber = 1;
      if (invoicesSnap.docs.isNotEmpty) {
        final lastNumber = invoicesSnap.docs.first.data()['number'] as String;
        final parts = lastNumber.split('-');
        nextNumber = int.parse(parts[2]) + 1;
      }

      setState(() {
        _invoiceNumber =
            'INV-${now.year}${now.month.toString().padLeft(2, '0')}-${nextNumber.toString().padLeft(4, '0')}';
      });
    } catch (e) {
      debugPrint('Error generating invoice number: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.invoiceId == null ? 'New Invoice' : 'Edit Invoice'),
        actions: [
          // HAIKU TODO: Save as draft button
          TextButton(
            onPressed: _saveDraft,
            child: const Text('SAVE DRAFT'),
          ),
          // HAIKU TODO: Preview PDF button
          IconButton(
            icon: const Icon(Icons.preview),
            onPressed: _previewPDF,
            tooltip: 'Preview PDF',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(DesignTokens.spaceMD),
          children: [
            // HAIKU TODO: Invoice number display (auto-generated)
            _buildInvoiceNumber(),

            const SizedBox(height: DesignTokens.spaceLG),

            // HAIKU TODO: Customer name field
            TextFormField(
              controller: _customerNameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter customer name';
                }
                return null;
              },
            ),

            const SizedBox(height: DesignTokens.spaceMD),

            // HAIKU TODO: Tax rate selector
            _buildTaxRateSelector(),

            const SizedBox(height: DesignTokens.spaceLG),

            // HAIKU TODO: Line items section
            Text(
              'Line Items',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: DesignTokens.spaceMD),
            ..._buildLineItems(),

            // HAIKU TODO: Add line item button
            OutlinedButton.icon(
              onPressed: _addLineItem,
              icon: const Icon(Icons.add),
              label: const Text('Add Line Item'),
            ),

            const SizedBox(height: DesignTokens.spaceXL),

            // HAIKU TODO: Totals summary
            _buildTotalsSummary(),

            const SizedBox(height: DesignTokens.spaceXL),

            // HAIKU TODO: Send invoice button
            FilledButton.icon(
              onPressed: _sendInvoice,
              icon: const Icon(Icons.send),
              label: const Text('Send Invoice'),
              style: FilledButton.styleFrom(
                backgroundColor: DesignTokens.dsierraRed,
                padding: const EdgeInsets.all(DesignTokens.spaceMD),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceNumber() {
    final invoiceNumber = _invoiceNumber ?? 'Generating...';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Row(
          children: [
            const Icon(Icons.receipt_long),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invoice Number',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  invoiceNumber,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaxRateSelector() {
    return Row(
      children: [
        const Text('Tax Rate:'),
        const SizedBox(width: 12),
        Expanded(
          child: Slider(
            value: _taxRate,
            min: 0.0,
            max: 0.15,
            divisions: 30,
            label: '${(_taxRate * 100).toStringAsFixed(2)}%',
            onChanged: (value) {
              setState(() {
                _taxRate = value;
              });
            },
          ),
        ),
        Text('${(_taxRate * 100).toStringAsFixed(2)}%'),
      ],
    );
  }

  List<Widget> _buildLineItems() {
    return _lineItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      return _buildLineItemCard(index, item);
    }).toList();
  }

  Widget _buildLineItemCard(int index, LineItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.spaceMD),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Item ${index + 1}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (_lineItems.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, color: DesignTokens.errorRed),
                    onPressed: () {
                      setState(() {
                        _lineItems.removeAt(index);
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // HAIKU TODO: Description field
            TextFormField(
              controller: item.descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g., Interior painting',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // HAIKU TODO: Quantity field
                Expanded(
                  child: TextFormField(
                    controller: item.quantityController,
                    decoration: const InputDecoration(labelText: 'Qty'),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                // HAIKU TODO: Rate field
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: item.rateController,
                    decoration: const InputDecoration(
                      labelText: 'Rate',
                      prefixText: '\$',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                // HAIKU TODO: Line total
                Expanded(
                  child: Text(
                    '\$${item.total.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsSummary() {
    // HAIKU TODO: Calculate totals
    final subtotal = _lineItems.fold(0.0, (sum, item) => sum + item.total);
    final tax = subtotal * _taxRate;
    final total = subtotal + tax;

    return Card(
      color: DesignTokens.dsierraRed.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Column(
          children: [
            _buildTotalRow('Subtotal', subtotal),
            const Divider(),
            _buildTotalRow('Tax (${(_taxRate * 100).toStringAsFixed(2)}%)', tax),
            const Divider(),
            _buildTotalRow(
              'Total',
              total,
              isTotal: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isTotal
              ? Theme.of(context).textTheme.titleLarge
              : Theme.of(context).textTheme.bodyLarge,
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: isTotal
              ? Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: DesignTokens.dsierraRed,
                  )
              : Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(LineItem());
    });
  }

  void _loadInvoice(String invoiceId) {
    // TODO: Load invoice from Firestore for editing
    // This would populate _customerNameController, _taxRate, _lineItems
    // and _invoiceNumber from existing invoice document
  }

  Future<void> _saveDraft() async {
    if (!_formKey.currentState!.validate() || _invoiceNumber == null) return;

    setState(() => _isLoading = true);
    try {
      final companyId = ref.read(userCompanyProvider);
      final userId = ref.read(currentUserProvider)?.uid;
      if (companyId == null || userId == null) return;

      final subtotal =
          _lineItems.fold(0.0, (sum, item) => sum + item.total);
      final tax = subtotal * _taxRate;
      final total = subtotal + tax;

      // Save invoice as draft
      await FirebaseFirestore.instance
          .collection('companies/$companyId/invoices')
          .doc(widget.invoiceId)
          .set({
            'number': _invoiceNumber,
            'customerName': _customerNameController.text,
            'lineItems': _lineItems
                .map((item) => {
                      'description': item.descriptionController.text,
                      'quantity': double.tryParse(item.quantityController.text) ?? 0,
                      'rate': double.tryParse(item.rateController.text) ?? 0,
                    })
                .toList(),
            'subtotal': subtotal,
            'taxRate': _taxRate,
            'tax': tax,
            'amount': total,
            'status': 'draft',
            'createdBy': userId,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice saved as draft')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving draft: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _previewPDF() async {
    // TODO: Generate PDF preview using pdf package
    // Show PDF in a dialog or new screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF preview coming soon')),
    );
  }

  Future<void> _sendInvoice() async {
    if (!_formKey.currentState!.validate() || _invoiceNumber == null) return;

    setState(() => _isLoading = true);
    try {
      final companyId = ref.read(userCompanyProvider);
      if (companyId == null) return;

      // First save as draft
      await _saveDraft();

      // Call Cloud Function to send email
      await FirebaseFunctions.instance
          .httpsCallable('sendInvoiceEmail')
          .call({
            'invoiceId': widget.invoiceId,
            'invoiceNumber': _invoiceNumber,
            'customerName': _customerNameController.text,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice sent successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending invoice: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    for (final item in _lineItems) {
      item.dispose();
    }
    super.dispose();
  }
}

class LineItem {
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController quantityController = TextEditingController(text: '1');
  final TextEditingController rateController = TextEditingController();

  double get total {
    final qty = double.tryParse(quantityController.text) ?? 0;
    final rate = double.tryParse(rateController.text) ?? 0;
    return qty * rate;
  }

  void dispose() {
    descriptionController.dispose();
    quantityController.dispose();
    rateController.dispose();
  }
}
