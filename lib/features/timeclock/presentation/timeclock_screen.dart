/// Timeclock Screen
///
/// PURPOSE:
/// Primary screen for time clock operations (clock in/out).
/// Displays current clock status and provides quick access to time tracking.
///
/// FEATURES:
/// - Clock in/out functionality
/// - Current job selection
/// - Time entry history
/// - Offline queue status
/// - GPS location tracking (when enabled)
///
/// OFFLINE BEHAVIOR:
/// Operations are queued when offline and synced when connection restores.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers/auth_provider.dart';
import 'package:sierra_painting/core/widgets/app_navigation.dart';
import 'package:sierra_painting/core/services/feature_flag_service.dart';
import 'package:sierra_painting/design/design.dart';

class TimeclockScreen extends ConsumerWidget {
  const TimeclockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Time Clock')),
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
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceLG),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.access_time, size: 100),
            const SizedBox(height: DesignTokens.spaceLG),
            Text(
              'Welcome, ${user?.email ?? "User"}',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: DesignTokens.spaceXXL),
            if (clockInEnabled)
              AppButton(
                label: 'Clock In',
                icon: Icons.play_arrow,
                onPressed: () {
                  // Clock in logic - TODO: integrate with repository
                },
              ),
            const SizedBox(height: DesignTokens.spaceMD),
            if (clockOutEnabled)
              AppButton(
                label: 'Clock Out',
                icon: Icons.stop,
                variant: ButtonVariant.outlined,
                onPressed: () {
                  // Clock out logic - TODO: integrate with repository
                },
              ),
          ],
        ),
      ),
    );
  }
}
