import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers/auth_provider.dart';
import 'package:sierra_painting/core/widgets/app_navigation.dart';
import 'package:sierra_painting/core/services/feature_flag_service.dart';

class TimeclockScreen extends ConsumerWidget {
  const TimeclockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Clock'),
      ),
      drawer: const AppDrawer(),
      body: const _TimeclockBody(),
      bottomNavigationBar: const AppNavigationBar(),
    );
  }
}

/// Timeclock body - separated for better rebuild isolation
class _TimeclockBody extends ConsumerWidget {
  const _TimeclockBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final clockInEnabled = ref.watch(clockInEnabledProvider);
    final clockOutEnabled = ref.watch(clockOutEnabledProvider);

    return Center(
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
          if (clockInEnabled)
            FilledButton.icon(
              onPressed: () {
                // Clock in logic - TODO: integrate with repository
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Clock In'),
            ),
          const SizedBox(height: 16),
          if (clockOutEnabled)
            OutlinedButton.icon(
              onPressed: () {
                // Clock out logic - TODO: integrate with repository
              },
              icon: const Icon(Icons.stop),
              label: const Text('Clock Out'),
            ),
        ],
      ),
    );
  }
}
