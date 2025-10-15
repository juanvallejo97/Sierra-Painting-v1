import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers.dart';
import 'package:sierra_painting/core/widgets/logout_dialog.dart';

/// Admin Scaffold with Persistent Drawer Navigation
/// Provides consistent navigation for all admin screens
class AdminScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final FloatingActionButton? floatingActionButton;

  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      drawer: _AdminDrawer(),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// Admin Navigation Drawer
class _AdminDrawer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentRoute = ModalRoute.of(context)?.settings.name ?? '';

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
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  size: 48,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Admin Portal',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  FirebaseAuth.instance.currentUser?.email ?? '',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _DrawerItem(
            icon: Icons.home,
            title: 'Home',
            route: '/admin/home',
            currentRoute: currentRoute,
            onTap: () {
              FirebaseAnalytics.instance.logEvent(name: 'admin_nav_home');
              Navigator.pushReplacementNamed(context, '/admin/home');
            },
          ),
          _DrawerItem(
            icon: Icons.list,
            title: 'Time Review',
            route: '/admin/review',
            currentRoute: currentRoute,
            onTap: () {
              FirebaseAnalytics.instance.logEvent(name: 'admin_nav_review');
              Navigator.pushReplacementNamed(context, '/admin/review');
            },
          ),
          _DrawerItem(
            icon: Icons.work,
            title: 'Jobs',
            route: '/jobs',
            currentRoute: currentRoute,
            onTap: () {
              FirebaseAnalytics.instance.logEvent(name: 'admin_nav_jobs');
              Navigator.pushNamed(context, '/jobs');
            },
          ),
          _DrawerItem(
            icon: Icons.request_quote,
            title: 'Estimates',
            route: '/estimates',
            currentRoute: currentRoute,
            onTap: () {
              FirebaseAnalytics.instance.logEvent(name: 'admin_nav_estimates');
              Navigator.pushNamed(context, '/estimates');
            },
          ),
          _DrawerItem(
            icon: Icons.receipt_long,
            title: 'Invoices',
            route: '/invoices',
            currentRoute: currentRoute,
            onTap: () {
              FirebaseAnalytics.instance.logEvent(name: 'admin_nav_invoices');
              Navigator.pushNamed(context, '/invoices');
            },
          ),
          _DrawerItem(
            icon: Icons.people,
            title: 'Employees',
            route: '/employees',
            currentRoute: currentRoute,
            onTap: () {
              FirebaseAnalytics.instance.logEvent(name: 'admin_nav_employees');
              Navigator.pushNamed(context, '/employees');
            },
          ),
          _DrawerItem(
            icon: Icons.settings,
            title: 'Settings',
            route: '/settings',
            currentRoute: currentRoute,
            onTap: () {
              FirebaseAnalytics.instance.logEvent(name: 'admin_nav_settings');
              Navigator.pushNamed(context, '/settings');
            },
          ),
          const Divider(),
          Semantics(
            label: 'Sign Out',
            hint: 'Sign out of your account and return to login screen',
            button: true,
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sign Out',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () async {
                // Fire-and-forget analytics event
                unawaited(
                  FirebaseAnalytics.instance.logEvent(name: 'admin_logout'),
                );
                if (!context.mounted) return;
                Navigator.pop(context); // Close drawer first
                if (!context.mounted) return;
                final confirmed = await showLogoutConfirmation(context);
                if (confirmed && context.mounted) {
                  // Sign out from Firebase
                  await FirebaseAuth.instance.signOut();

                  // Invalidate auth and profile providers to clear cached state
                  ref.invalidate(userProfileProvider);

                  // Clear navigation stack and go to login
                  if (context.mounted) {
                    await Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Drawer Item Widget
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String route;
  final String currentRoute;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.title,
    required this.route,
    required this.currentRoute,
    required this.onTap,
  });

  bool get isSelected =>
      currentRoute == route || currentRoute.startsWith('$route/');

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: title,
      hint: 'Navigate to $title',
      button: true,
      selected: isSelected,
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurface,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.1),
        onTap: () {
          Navigator.pop(context); // Close drawer
          onTap();
        },
      ),
    );
  }
}
