import 'package:flutter/material.dart';
import 'package:sierra_painting/core/widgets/app_navigation.dart';

class EstimatesScreen extends StatelessWidget {
  const EstimatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Estimates'),
      ),
      drawer: const AppDrawer(),
      body: const Center(
        child: Text('Estimates Screen'),
      ),
      bottomNavigationBar: const AppNavigationBar(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Create new estimate
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
