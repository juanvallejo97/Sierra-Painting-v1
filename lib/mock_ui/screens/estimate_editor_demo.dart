import 'package:flutter/material.dart';
import '../components/app_scaffold.dart';
import '../fakers.dart';

class EstimateEditorDemo extends StatefulWidget {
  const EstimateEditorDemo({super.key});
  @override State<EstimateEditorDemo> createState() => _EstimateEditorDemoState();
}

class _EstimateEditorDemoState extends State<EstimateEditorDemo> {
  final _form = GlobalKey<FormState>();
  final _items = List<LineItem>.from(fakeLineItems());

  double get total => _items.fold(0, (s, it) => s + it.total);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Estimate Editor',
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Client', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(decoration: const InputDecoration(labelText: 'Name'), initialValue: 'Alex Customer', validator: _req),
            TextFormField(decoration: const InputDecoration(labelText: 'Address'), initialValue: '742 Evergreen Terrace', validator: _req),
            const SizedBox(height: 16),
            Text('Line items', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (int i=0; i<_items.length; i++) _itemRow(i),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() => _items.add(LineItem('New item', 1, 0))),
              icon: const Icon(Icons.add),
              label: const Text('Add line item'),
            ),
            const Divider(height: 32),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Total: \$${total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineSmall),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                if (_form.currentState?.validate() ?? false) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Estimate saved (mock).')));
                }
              },
              child: const Text('Save'),
            )
          ],
        ),
      ),
    );
  }

  String? _req(String? v) => (v==null || v.trim().isEmpty) ? 'Required' : null;

  Widget _itemRow(int i) {
    final it = _items[i];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              initialValue: it.desc,
              decoration: const InputDecoration(labelText: 'Description'),
              onChanged: (v) => it.desc = v,
              validator: _req,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: it.qty.toString(),
              decoration: const InputDecoration(labelText: 'Qty'),
              keyboardType: TextInputType.number,
              onChanged: (v) => it.qty = int.tryParse(v) ?? it.qty,
              validator: (v) => (int.tryParse(v ?? '') == null) ? 'Int' : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: it.price.toStringAsFixed(2),
              decoration: const InputDecoration(labelText: 'Price'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) => it.price = double.tryParse(v) ?? it.price,
              validator: (v) => (double.tryParse(v ?? '') == null) ? 'Num' : null,
            ),
          ),
          const SizedBox(width: 8),
          Text('\$${it.total.toStringAsFixed(2)}'),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => _items.removeAt(i))),
        ]),
      ),
    );
  }
}
