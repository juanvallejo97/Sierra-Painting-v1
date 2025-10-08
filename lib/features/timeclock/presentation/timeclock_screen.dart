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
library;

import 'package:flutter/material.dart';

class TimeclockScreen extends StatelessWidget {
  const TimeclockScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sierra Painting')),
      // drawer: const AppDrawer(),
      // bottomNavigationBar: const AppNavigationBar(),
      body: const TimeclockBody(),
    );
  }
}

/// Router-free body used by tests and the real screen.
class TimeclockBody extends StatelessWidget {
  const TimeclockBody({super.key});
  @override
  Widget build(BuildContext context) {
    final String userEmail = 'User'; // TODO: wire to provider; keep null-safe default
    return Center(child: Text('Welcome, $userEmail', key: const Key('welcomeText')));
  }
}
