import 'package:flutter/material.dart';

class EstimatesScreen extends StatelessWidget {
  const EstimatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estimates'),
      ),
      body: const Center(
        child: Text('Estimates Screen'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Create new estimate
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
