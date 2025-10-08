import 'package:flutter/material.dart';
import 'package:sierra_painting/mock_ui/components/app_scaffold.dart';
import 'package:sierra_painting/mock_ui/fakers.dart';

class InvoicePreviewDemo extends StatelessWidget {
  const InvoicePreviewDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final items = fakeLineItems();
    final subtotal = items.fold(0.0, (s, i) => s + i.total);
    final tax = subtotal * 0.0825;
    final total = subtotal + tax;

    return AppScaffold(
      title: 'Invoice Preview',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              title: const Text('Sierra Painting, Inc.'),
              subtitle: Text(
                'Invoice #INV-${DateTime.now().millisecondsSinceEpoch % 10000}',
              ),
              trailing: const Icon(Icons.picture_as_pdf),
            ),
          ),
          for (final it in items)
            Card(
              child: ListTile(
                title: Text(it.desc),
                subtitle: Text('${it.qty} x \$${it.price.toStringAsFixed(2)}'),
                trailing: Text('\$${it.total.toStringAsFixed(2)}'),
              ),
            ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text('Subtotal'),
              trailing: Text('\$${subtotal.toStringAsFixed(2)}'),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Tax 8.25%'),
              trailing: Text('\$${tax.toStringAsFixed(2)}'),
            ),
          ),
          Card(
            child: ListTile(
              title: const Text('Total'),
              trailing: Text('\$${total.toStringAsFixed(2)}'),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.payment),
            label: const Text('Take payment'),
          ),
        ],
      ),
    );
  }
}
