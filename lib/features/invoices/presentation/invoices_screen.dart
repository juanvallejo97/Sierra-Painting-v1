import 'package:flutter/material.dart';

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
      ),
      body: const Center(
        child: Text('Invoices Screen'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Create new invoice
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
