import 'package:flutter/material.dart';
import 'package:sierra_painting/core/widgets/app_navigation.dart';
import 'package:sierra_painting/design/design.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      drawer: const AppDrawer(),
      body: const _AdminBody(),
      bottomNavigationBar: const AppNavigationBar(),
    );
  }
}

/// Admin body - separated for better rebuild isolation
class _AdminBody extends StatelessWidget {
  const _AdminBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceLG),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.admin_panel_settings, size: 100),
            const SizedBox(height: DesignTokens.spaceLG),
            Text(
              'Admin Panel',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: DesignTokens.spaceSM),
            Text(
              'RBAC Protected',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: DesignTokens.spaceXL),
            const Text(
              'Admin features coming soon...',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
