import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/haptic_service.dart';

/// Settings screen for app preferences
///
/// Features:
/// - Haptic feedback toggle
/// - Theme preference (future)
/// - Motion reduction toggle (future)
/// - Accessibility options
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final hapticEnabled = ref.watch(hapticEnabledProvider);
    final hapticService = ref.watch(hapticServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // Accessibility Section
          _buildSectionHeader(context, 'Accessibility'),
          SwitchListTile(
            title: const Text('Haptic Feedback'),
            subtitle: const Text('Vibration feedback for taps and actions'),
            value: hapticEnabled,
            onChanged: (value) {
              // Provide immediate haptic feedback on toggle
              if (value) {
                hapticService.light();
              }
              
              // Update state
              ref.read(hapticEnabledProvider.notifier).state = value;
              hapticService.setEnabled(value);
              
              // Show confirmation
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    value
                        ? 'Haptic feedback enabled'
                        : 'Haptic feedback disabled',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            secondary: const Icon(Icons.vibration),
          ),
          const Divider(),
          
          // Theme Section (placeholder for future implementation)
          _buildSectionHeader(context, 'Appearance'),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            subtitle: const Text('System default'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              hapticService.light();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Theme selection coming soon'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
          const Divider(),
          
          // About Section
          _buildSectionHeader(context, 'About'),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('1.0.0+1'),
          ),
          ListTile(
            leading: const Icon(Icons.policy),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              hapticService.light();
              // TODO: Open privacy policy
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () {
              hapticService.light();
              // TODO: Open terms of service
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
