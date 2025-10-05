/// App Navigation - Bottom Navigation Bar
///
/// PURPOSE:
/// Shared bottom navigation widget for consistent navigation across screens.
/// Optimized for performance with const constructors and minimal rebuilds.
///
/// PERFORMANCE:
/// - Uses const constructor where possible
/// - Minimal rebuilds (only active tab changes)
/// - Cached navigation items
library app_navigation;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sierra_painting/core/providers/auth_provider.dart';
import 'package:sierra_painting/core/services/haptic_service.dart';

/// Navigation items
class NavigationItem {
  final String route;
  final IconData icon;
  final String label;
  final bool adminOnly;

  const NavigationItem({
    required this.route,
    required this.icon,
    required this.label,
    this.adminOnly = false,
  });
}

/// Navigation items list (const for performance)
const List<NavigationItem> _navigationItems = [
  NavigationItem(
    route: '/timeclock',
    icon: Icons.access_time,
    label: 'Time Clock',
  ),
  NavigationItem(
    route: '/estimates',
    icon: Icons.request_quote,
    label: 'Estimates',
  ),
  NavigationItem(
    route: '/invoices',
    icon: Icons.receipt_long,
    label: 'Invoices',
  ),
  NavigationItem(
    route: '/admin',
    icon: Icons.admin_panel_settings,
    label: 'Admin',
    adminOnly: true,
  ),
];

/// App Navigation Bar
class AppNavigationBar extends ConsumerWidget {
  const AppNavigationBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.email?.contains('admin') ?? false;
    final currentRoute = GoRouterState.of(context).matchedLocation;
    final hapticService = ref.read(hapticServiceProvider);

    // Filter items based on admin status
    final visibleItems = _navigationItems
        .where((item) => !item.adminOnly || isAdmin)
        .toList();

    // Find current index
    final currentIndex = visibleItems.indexWhere(
      (item) => currentRoute.startsWith(item.route),
    );

    return BottomNavigationBar(
      currentIndex: currentIndex >= 0 ? currentIndex : 0,
      onTap: (index) async {
        // Selection haptic feedback on tab change
        await hapticService.selection();
        final route = visibleItems[index].route;
        context.go(route);
      },
      type: BottomNavigationBarType.fixed,
      items: visibleItems
          .map(
            (item) => BottomNavigationBarItem(
              icon: Icon(item.icon),
              label: item.label,
            ),
          )
          .toList(),
    );
  }
}

/// App Drawer - For mobile drawer navigation
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isAdmin = user?.email?.contains('admin') ?? false;

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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                if (user?.email != null)
                  Text(
                    user!.email!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.white70),
                  ),
              ],
            ),
          ),
          ..._navigationItems
              .where((item) => !item.adminOnly || isAdmin)
              .map(
                (item) => ListTile(
                  leading: Icon(item.icon),
                  title: Text(item.label),
                  onTap: () {
                    context.go(item.route);
                    Navigator.pop(context);
                  },
                ),
              ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () async {
              await ref.read(firebaseAuthProvider).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
    );
  }
}
