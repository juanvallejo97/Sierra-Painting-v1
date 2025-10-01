import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sierra_painting/core/providers/auth_provider.dart';

class TimeclockScreen extends ConsumerWidget {
  const TimeclockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Clock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(firebaseAuthProvider).signOut();
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context, user?.email),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time, size: 100),
            const SizedBox(height: 24),
            Text(
              'Welcome, ${user?.email ?? "User"}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: () {
                // Clock in logic
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Clock In'),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                // Clock out logic
              },
              icon: const Icon(Icons.stop),
              label: const Text('Clock Out'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, String? userEmail) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.format_paint, size: 48, color: Colors.white),
                const SizedBox(height: 8),
                Text(
                  'Sierra Painting',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: const Text('Time Clock'),
            onTap: () {
              context.go('/timeclock');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.request_quote),
            title: const Text('Estimates'),
            onTap: () {
              context.go('/estimates');
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Invoices'),
            onTap: () {
              context.go('/invoices');
              Navigator.pop(context);
            },
          ),
          if (userEmail?.contains('admin') ?? false)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text('Admin'),
              onTap: () {
                context.go('/admin');
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}
