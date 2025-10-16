/// Admin Dashboard Home Screen
///
/// PURPOSE:
/// Main dashboard for admin users with real-time KPIs and quick actions
///
/// FEATURES:
/// - Real-time KPI cards (active workers, pending approvals, revenue)
/// - Quick action buttons (create job, invite worker, etc.)
/// - Recent activity feed
/// - Skeleton loading states
/// - Pull-to-refresh
///
/// HAIKU TODO:
/// - Create KPI providers for Firestore aggregation
/// - Build KPI card widgets
/// - Add action button grid
/// - Create activity feed widget
/// - Wire up navigation to detail screens
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers/auth_provider.dart';
import 'package:sierra_painting/core/providers.dart';
import 'package:sierra_painting/design/tokens.dart';
import 'package:sierra_painting/ui/widgets/version_indicator.dart';

/// KPI data class for dashboard metrics
class DashboardKPIs {
  final int activeWorkers;
  final int pendingTimeEntries;
  final int activeJobs;
  final double weeklyRevenue;

  DashboardKPIs({
    required this.activeWorkers,
    required this.pendingTimeEntries,
    required this.activeJobs,
    required this.weeklyRevenue,
  });
}

/// Provider for fetching real-time KPIs from Firestore
final dashboardKPIsProvider = FutureProvider<DashboardKPIs>((ref) async {
  final companyId = ref.watch(userCompanyProvider);
  if (companyId == null) {
    return DashboardKPIs(
      activeWorkers: 0,
      pendingTimeEntries: 0,
      activeJobs: 0,
      weeklyRevenue: 0.0,
    );
  }

  final db = FirebaseFirestore.instance;

  // Count active workers (clocked in right now)
  final activeWorkersSnap = await db
      .collection('companies/$companyId/time_entries')
      .where('status', isEqualTo: 'active')
      .count()
      .get();
  final activeWorkers = activeWorkersSnap.count ?? 0;

  // Count pending time entries
  final pendingEntriesSnap = await db
      .collection('companies/$companyId/time_entries')
      .where('status', isEqualTo: 'pending')
      .count()
      .get();
  final pendingTimeEntries = pendingEntriesSnap.count ?? 0;

  // Count active jobs (using 'active' boolean field, not 'status')
  final activeJobsSnap = await db
      .collection('companies/$companyId/jobs')
      .where('active', isEqualTo: true)
      .count()
      .get();
  final activeJobs = activeJobsSnap.count ?? 0;

  // Calculate weekly revenue (invoices paid in last 7 days)
  final weekStart = DateTime.now().subtract(const Duration(days: 7));
  final invoicesSnap = await db
      .collection('companies/$companyId/invoices')
      .where('status', isEqualTo: 'paid_cash')
      .where('paidAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
      .get();

  double weeklyRevenue = 0.0;
  for (final doc in invoicesSnap.docs) {
    final amount = doc.data()['amount'] as num?;
    if (amount != null) {
      weeklyRevenue += amount.toDouble();
    }
  }

  return DashboardKPIs(
    activeWorkers: activeWorkers,
    pendingTimeEntries: pendingTimeEntries,
    activeJobs: activeJobs,
    weeklyRevenue: weeklyRevenue,
  );
});

class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'assets/branding/dsierra_logo.jpg',
              height: 32,
              errorBuilder: (context, error, stackTrace) => const SizedBox(),
            ),
            const SizedBox(width: 12),
            const Text("D' Sierra Admin"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              unawaited(
                FirebaseAnalytics.instance.logEvent(name: 'admin_logout'),
              );
              if (!context.mounted) return;
              final confirmed = await _showLogoutConfirmation(context);
              if (confirmed && context.mounted) {
                await FirebaseAuth.instance.signOut();
                ref.invalidate(userProfileProvider);
                if (context.mounted) {
                  await Navigator.of(context)
                      .pushNamedAndRemoveUntil('/login', (route) => false);
                }
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardKPIsProvider);
            },
            child: const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(DesignTokens.spaceMD),
              child: AdminDashboardBody(),
            ),
          ),
          // Version indicator for cache debugging
          const Positioned(
            bottom: 8,
            right: 8,
            child: VersionIndicator(),
          ),
        ],
      ),
    );
  }
}

class AdminDashboardBody extends ConsumerWidget {
  const AdminDashboardBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kpisAsync = ref.watch(dashboardKPIsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // HAIKU TODO: Welcome header
        Text(
          'Dashboard',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: DesignTokens.spaceLG),

        // HAIKU TODO: KPI cards grid
        kpisAsync.when(
          data: (kpis) => _buildKPIGrid(context, kpis),
          loading: () => _buildKPISkeletons(),
          error: (error, stack) => Text('Error: $error'),
        ),

        const SizedBox(height: DesignTokens.spaceXL),

        // HAIKU TODO: Quick actions
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: DesignTokens.spaceMD),
        _buildQuickActions(context),

        const SizedBox(height: DesignTokens.spaceXL),

        // HAIKU TODO: Recent activity
        Text(
          'Recent Activity',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: DesignTokens.spaceMD),
        _buildRecentActivity(),
      ],
    );
  }

  Widget _buildKPIGrid(BuildContext context, DashboardKPIs kpis) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: DesignTokens.spaceMD,
      crossAxisSpacing: DesignTokens.spaceMD,
      childAspectRatio: 1.5,
      children: [
        _buildKPICard(
          context,
          'Active Workers',
          kpis.activeWorkers.toString(),
          Icons.people,
          DesignTokens.successGreen,
        ),
        _buildKPICard(
          context,
          'Pending Approvals',
          kpis.pendingTimeEntries.toString(),
          Icons.pending_actions,
          DesignTokens.warningAmber,
        ),
        _buildKPICard(
          context,
          'Active Jobs',
          kpis.activeJobs.toString(),
          Icons.work,
          DesignTokens.infoBlue,
        ),
        _buildKPICard(
          context,
          'Weekly Revenue',
          '\$${kpis.weeklyRevenue.toStringAsFixed(0)}',
          Icons.attach_money,
          DesignTokens.dsierraRed,
        ),
      ],
    );
  }

  Widget _buildKPICard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPISkeletons() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: DesignTokens.spaceMD,
      crossAxisSpacing: DesignTokens.spaceMD,
      childAspectRatio: 1.5,
      children: List.generate(4, (index) => _buildSkeletonCard()),
    );
  }

  Widget _buildSkeletonCard() {
    return Card(
      child: Container(
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Wrap(
      spacing: DesignTokens.spaceSM,
      runSpacing: DesignTokens.spaceSM,
      children: [
        _buildActionButton(context, 'Create Job', Icons.add_circle, () {
          Navigator.pushNamed(context, '/jobs/create');
        }),
        _buildActionButton(context, 'Invite Worker', Icons.person_add, () {
          Navigator.pushNamed(context, '/employees/new');
        }),
        _buildActionButton(context, 'New Invoice', Icons.receipt, () {
          Navigator.pushNamed(context, '/invoices/create');
        }),
        _buildActionButton(context, 'View Reports', Icons.analytics, () {
          Navigator.pushNamed(context, '/admin/review');
        }),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildActivityItem(
              Icons.check_circle,
              'Time Entry Approved',
              'John Doe\'s entry approved',
              DesignTokens.successGreen,
            ),
            const Divider(),
            _buildActivityItem(
              Icons.flag,
              'Entry Flagged',
              'Worker clocked in outside geofence',
              DesignTokens.warningAmber,
            ),
            const Divider(),
            _buildActivityItem(
              Icons.receipt,
              'Invoice Sent',
              'Invoice #INV-202501-0012 sent',
              DesignTokens.infoBlue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(
    IconData icon,
    String title,
    String subtitle,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// Show logout confirmation dialog
Future<bool> _showLogoutConfirmation(BuildContext context) async {
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        ),
      ) ??
      false;
}
