/// Feature Flags Debug Screen
///
/// PURPOSE:
/// - View all feature flags and their current state
/// - View system preferences (Reduce Motion, Battery Saver)
/// - Override flags in debug mode for testing
/// - Force refresh from Remote Config
/// - Monitor global panic flag status
///
/// USAGE:
/// - Navigate to this screen from Admin Settings
/// - Only visible in debug mode or to admins

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sierra_painting/core/feature_flags/feature_flags.dart';

class FeatureFlagsDebugScreen extends StatefulWidget {
  const FeatureFlagsDebugScreen({super.key});

  @override
  State<FeatureFlagsDebugScreen> createState() => _FeatureFlagsDebugScreenState();
}

class _FeatureFlagsDebugScreenState extends State<FeatureFlagsDebugScreen> {
  bool _isRefreshing = false;
  Map<FeatureFlag, bool> _flagStates = {};
  bool _reduceMotion = false;
  bool _batterySaver = false;

  @override
  void initState() {
    super.initState();
    _loadFlagStates();
    _loadSystemPreferences();
  }

  void _loadFlagStates() {
    setState(() {
      _flagStates = FeatureFlags.getAll();
    });
  }

  void _loadSystemPreferences() {
    setState(() {
      _reduceMotion = SystemPreferencesService.instance.reduceMotion;
      _batterySaver = SystemPreferencesService.instance.batterySaver;
    });
  }

  Future<void> _refreshFromRemoteConfig() async {
    setState(() => _isRefreshing = true);

    try {
      await FeatureFlags.refresh();
      _loadFlagStates();
      _loadSystemPreferences();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Flags refreshed from Remote Config'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to refresh: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _toggleFlag(FeatureFlag flag, bool newValue) {
    if (!kDebugMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Overrides only allowed in debug mode'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    FeatureFlags.override(flag, newValue);
    _loadFlagStates();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🔧 Overridden ${flag.name} → $newValue'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final panicMode = _flagStates[FeatureFlag.globalPanic] ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feature Flags Debug'),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshFromRemoteConfig,
            tooltip: 'Refresh from Remote Config',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // GLOBAL PANIC MODE WARNING
          if (panicMode) ...[
            Card(
              color: Colors.red.shade900,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Icon(Icons.warning_amber, size: 48, color: Colors.red.shade100),
                    const SizedBox(height: 8),
                    Text(
                      '🚨 GLOBAL PANIC MODE ACTIVE',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All feature flags are disabled',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.red.shade100,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // SYSTEM PREFERENCES
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings_system_daydream, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'System Preferences',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  _SystemPreferenceRow(
                    label: 'Reduce Motion',
                    value: _reduceMotion,
                    icon: Icons.animation,
                  ),
                  const SizedBox(height: 8),
                  _SystemPreferenceRow(
                    label: 'Battery Saver',
                    value: _batterySaver,
                    icon: Icons.battery_saver,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Flags with "respect" settings will auto-disable when these are active',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // FEATURE FLAGS
          Text(
            'Feature Flags',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          if (!kDebugMode)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'ℹ️ Overrides require debug mode',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
              ),
            ),

          // List all flags
          ...FeatureFlag.values.map((flag) {
            final isEnabled = _flagStates[flag] ?? false;
            final isPanicFlag = flag == FeatureFlag.globalPanic;

            return Card(
              color: isPanicFlag
                  ? (isEnabled ? Colors.red.shade50 : null)
                  : (isEnabled ? Colors.green.shade50 : null),
              child: ListTile(
                leading: Icon(
                  isPanicFlag
                      ? Icons.warning_amber
                      : (isEnabled ? Icons.check_circle : Icons.circle_outlined),
                  color: isPanicFlag
                      ? (isEnabled ? Colors.red : Colors.grey)
                      : (isEnabled ? Colors.green : Colors.grey),
                ),
                title: Text(
                  flag.name,
                  style: TextStyle(
                    fontWeight: isPanicFlag ? FontWeight.bold : FontWeight.normal,
                    color: isPanicFlag && isEnabled ? Colors.red.shade900 : null,
                  ),
                ),
                subtitle: _getFlagDescription(flag),
                trailing: kDebugMode
                    ? Switch(
                        value: isEnabled,
                        onChanged: (value) => _toggleFlag(flag, value),
                        activeTrackColor: isPanicFlag ? Colors.red.shade300 : null,
                        activeColor: isPanicFlag ? Colors.red : null,
                      )
                    : Chip(
                        label: Text(isEnabled ? 'ON' : 'OFF'),
                        backgroundColor: isEnabled ? Colors.green.shade100 : Colors.grey.shade200,
                      ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget? _getFlagDescription(FeatureFlag flag) {
    final descriptions = {
      FeatureFlag.globalPanic: 'CRITICAL: Emergency kill switch - disables ALL features',
      FeatureFlag.shimmerLoaders: 'Shimmer loading animations (respects Reduce Motion + Battery)',
      FeatureFlag.lottieAnimations: 'Lottie animations (respects Reduce Motion)',
      FeatureFlag.hapticFeedback: 'Haptic feedback (respects Battery Saver)',
      FeatureFlag.offlineQueueV2: 'Enhanced offline queue with conflict resolution',
      FeatureFlag.auditTrail: 'Audit trail logging for compliance',
      FeatureFlag.smartForms: 'Smart forms with autosave',
      FeatureFlag.kpiDrillDown: 'KPI drill-down navigation',
      FeatureFlag.conflictDetection: 'Time entry conflict detection',
    };

    final description = descriptions[flag];
    if (description == null) return null;

    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Text(
        description,
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _SystemPreferenceRow extends StatelessWidget {
  final String label;
  final bool value;
  final IconData icon;

  const _SystemPreferenceRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Chip(
          label: Text(
            value ? 'ACTIVE' : 'Inactive',
            style: TextStyle(
              fontSize: 12,
              color: value ? Colors.orange.shade900 : Colors.grey.shade700,
            ),
          ),
          backgroundColor: value ? Colors.orange.shade100 : Colors.grey.shade200,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        ),
      ],
    );
  }
}
