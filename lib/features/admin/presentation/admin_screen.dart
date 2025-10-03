import 'package:flutter/material.dart';
import 'package:sierra_painting/core/widgets/app_navigation.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
      ),
      drawer: const AppDrawer(),
      body: const Center(
        child: Text('Admin Screen - RBAC Protected'),
      ),
      bottomNavigationBar: const AppNavigationBar(),
    );
  }
}
