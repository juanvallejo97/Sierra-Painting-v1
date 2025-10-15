/// Worker Scaffold
///
/// PURPOSE:
/// Common scaffold widget for worker screens with bottom navigation.
///
/// FEATURES:
/// - Bottom navigation bar for worker features
/// - Consistent app bar
/// - Logout functionality
library;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sierra_painting/core/providers.dart';
import 'dart:async';

class WorkerScaffold extends ConsumerWidget {
  final String title;
  final Widget body;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const WorkerScaffold({
    super.key,
    required this.title,
    required this.body,
    this.floatingActionButton,
    this.actions,
  });

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...?actions,
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              unawaited(
                FirebaseAnalytics.instance.logEvent(name: 'worker_logout'),
              );
              if (!context.mounted) return;
              final confirmed = await _showLogoutConfirmation(context);
              if (confirmed && context.mounted) {
                await FirebaseAuth.instance.signOut();
                ref.invalidate(userProfileProvider);
                if (context.mounted) {
                  await Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              }
            },
          ),
        ],
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
