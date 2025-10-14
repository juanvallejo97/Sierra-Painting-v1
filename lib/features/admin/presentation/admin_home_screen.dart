import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/auth/user_role.dart';
import 'package:sierra_painting/core/services/logger_service.dart';
import 'package:sierra_painting/core/widgets/admin_scaffold.dart';
import 'package:sierra_painting/features/admin/presentation/providers/admin_review_providers.dart';

/// Lightweight Admin Home Screen
/// Shows overview stats and quick actions
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counts = ref.watch(exceptionCountsProvider);

    int pending = 0;
    int outside = 0;

    counts.when(
      data: (m) {
        pending = m['totalPending'] ?? 0;
        outside = m['outsideGeofence'] ?? 0;
      },
      loading: () {},
      error: (_, _) {},
    );

    return AdminScaffold(
      title: 'Admin Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () => _refreshAdminToken(ref),
          tooltip: 'Refresh Token',
        ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final crossAxisCount = constraints.maxWidth > 800 ? 3 : 1;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: 2.2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    children: [
                      _StatCard(
                        title: 'Pending Entries',
                        value: pending,
                        icon: Icons.pending_actions,
                        color: Colors.orange,
                      ),
                      _StatCard(
                        title: 'Outside Geofence (24h)',
                        value: outside,
                        icon: Icons.location_off,
                        color: Colors.red,
                      ),
                      const _StatCard(
                        title: 'Latency P95',
                        valueText: '—',
                        icon: Icons.speed,
                        color: Colors.blue,
                        subtitle: 'Data pending',
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ElevatedButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/admin/review'),
                  icon: const Icon(Icons.list),
                  label: const Text('Review Entries'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshAdminToken(WidgetRef ref) async {
    final logger = ref.read(loggerServiceProvider);
    try {
      logger.debug('Refreshing admin token...');
      await FirebaseAnalytics.instance.logEvent(name: 'admin_refresh_token');
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      ref.invalidate(userProfileProvider);
      ref.invalidate(currentCompanyIdProvider);
      ref.invalidate(exceptionCountsProvider);
      ref.invalidate(outsideGeofenceEntriesProvider);
      logger.info('Token refreshed successfully');
    } catch (e) {
      logger.error('Token refresh failed', error: e);
    }
  }
}

/// Stat card widget
class _StatCard extends StatelessWidget {
  final String title;
  final int? value;
  final String? valueText;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _StatCard({
    required this.title,
    this.value,
    this.valueText,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        valueText ?? value?.toString() ?? '0',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
