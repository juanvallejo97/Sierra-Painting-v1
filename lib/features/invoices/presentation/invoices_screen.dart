import 'package:flutter/material.dart';
import 'package:sierra_painting/core/widgets/app_navigation.dart';

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
      ),
      drawer: const AppDrawer(),
      body: const Center(
        child: Text('Invoices Screen'),
      ),
      bottomNavigationBar: const AppNavigationBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Create new invoice
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
