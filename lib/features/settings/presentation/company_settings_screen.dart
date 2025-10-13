/// Company Settings Screen
///
/// PURPOSE:
/// Admin interface for company-wide settings that affect time tracking.
///
/// SETTINGS:
/// - Timezone: IANA timezone string (e.g., "America/New_York")
///   Used for: timesheet grouping, "today" calculation, week ranges
///   Note: Server stays UTC; client computes ranges in company TZ
///
/// - Require Geofence: Toggle for strict geofence enforcement
///   Default: true (recommended)
///   If false: geofence failures become warnings (not blocking)
///
/// - Max Shift Hours: Auto clock-out threshold
///   Default: 12 hours
///   Range: 8-24 hours
///   Worker is auto-clocked out after this duration
///
/// - Auto-Approve Time: Automatically approve entries after N days
///   Default: null (manual approval required)
///   Range: 1-30 days
///   If set, entries older than N days are auto-approved
///
/// - Default Hourly Rate: Default billing rate for invoicing
///   Used when creating invoice from time entries
///
/// VALIDATION RULES:
/// - Timezone must be valid IANA string (checked via timezone package)
/// - Max shift hours: 8 ≤ value ≤ 24
/// - Auto-approve days: null or 1 ≤ value ≤ 30
/// - Hourly rate: > 0, max 2 decimal places
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:sierra_painting/core/domain/company_settings.dart';  // TODO: Uncomment when implementing

/// Company Settings Screen
class CompanySettingsScreen extends ConsumerStatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  ConsumerState<CompanySettingsScreen> createState() =>
      _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends ConsumerState<CompanySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _hasChanges = false;

  // Form fields
  String _selectedTimezone = 'America/New_York';
  bool _requireGeofence = true;
  double _maxShiftHours = 12.0;
  int? _autoApproveDays;
  double _defaultHourlyRate = 0.0;

  // Common US timezones for quick select
  final List<String> _commonTimezones = [
    'America/New_York', // Eastern
    'America/Chicago', // Central
    'America/Denver', // Mountain
    'America/Los_Angeles', // Pacific
    'America/Phoenix', // Arizona (no DST)
    'America/Anchorage', // Alaska
    'Pacific/Honolulu', // Hawaii
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // TODO: Load from provider
    // final settings = await ref.read(companySettingsProvider.future);
    // setState(() {
    //   _selectedTimezone = settings.timezone;
    //   _requireGeofence = settings.requireGeofence;
    //   _maxShiftHours = settings.maxShiftHours.toDouble();
    //   _autoApproveDays = settings.autoApproveTime ? settings.autoApproveDays : null;
    //   _defaultHourlyRate = double.tryParse(settings.defaultHourlyRate ?? '0') ?? 0.0;
    // });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Settings'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _saveSettings,
              child: const Text('Save'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              onChanged: () {
                setState(() => _hasChanges = true);
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Timezone Setting
                  _buildSection(
                    title: 'Timezone',
                    icon: Icons.language,
                    description:
                        'Affects timesheet grouping and "today" calculation. '
                        'Server stays UTC; client computes ranges in this timezone.',
                    child: _buildTimezonePicker(),
                  ),
                  const SizedBox(height: 24),

                  // Geofence Setting
                  _buildSection(
                    title: 'Geofence Enforcement',
                    icon: Icons.location_on,
                    description:
                        'Require workers to be within job site geofence to clock in.',
                    child: SwitchListTile(
                      title: const Text('Require Geofence'),
                      subtitle: Text(
                        _requireGeofence
                            ? 'Hard gate: workers must be within geofence'
                            : 'Soft gate: geofence failures become warnings',
                      ),
                      value: _requireGeofence,
                      onChanged: (value) {
                        setState(() => _requireGeofence = value);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Max Shift Hours
                  _buildSection(
                    title: 'Max Shift Hours',
                    icon: Icons.access_time,
                    description:
                        'Workers are automatically clocked out after this duration. '
                        'Prevents runaway shifts.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Slider(
                          value: _maxShiftHours,
                          min: 8,
                          max: 24,
                          divisions: 16,
                          label: '${_maxShiftHours.toInt()}h',
                          onChanged: (value) {
                            setState(() => _maxShiftHours = value);
                          },
                        ),
                        Center(
                          child: Text(
                            '${_maxShiftHours.toInt()} hours',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _maxShiftHours > 12
                                      ? Colors.orange
                                      : Colors.green,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Auto-Approve Days
                  _buildSection(
                    title: 'Auto-Approve Time',
                    icon: Icons.check_circle_outline,
                    description:
                        'Automatically approve time entries after N days. '
                        'Leave blank for manual approval only.',
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Enable Auto-Approve'),
                          value: _autoApproveDays != null,
                          onChanged: (value) {
                            setState(() {
                              _autoApproveDays = value ? 7 : null;
                            });
                          },
                        ),
                        if (_autoApproveDays != null) ...[
                          const SizedBox(height: 12),
                          TextFormField(
                            initialValue: _autoApproveDays.toString(),
                            decoration: const InputDecoration(
                              labelText: 'Days until auto-approve',
                              suffixText: 'days',
                              border: OutlineInputBorder(),
                              helperText: 'Range: 1-30 days',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final days = int.tryParse(value);
                              if (days == null || days < 1 || days > 30) {
                                return 'Must be between 1 and 30';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              setState(() {
                                _autoApproveDays = int.tryParse(value);
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Default Hourly Rate
                  _buildSection(
                    title: 'Default Hourly Rate',
                    icon: Icons.attach_money,
                    description:
                        'Default billing rate for "Create Invoice from Time". '
                        'Can be overridden per invoice.',
                    child: TextFormField(
                      initialValue: _defaultHourlyRate > 0
                          ? _defaultHourlyRate.toStringAsFixed(2)
                          : '',
                      decoration: const InputDecoration(
                        labelText: 'Hourly Rate',
                        prefixText: '\$',
                        suffixText: '/hour',
                        border: OutlineInputBorder(),
                        helperText: 'Enter default billing rate',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return null; // Optional
                        }
                        final rate = double.tryParse(value);
                        if (rate == null || rate <= 0) {
                          return 'Must be a positive number';
                        }
                        // Check max 2 decimal places
                        if ((rate * 100).round() / 100 != rate) {
                          return 'Max 2 decimal places';
                        }
                        return null;
                      },
                      onChanged: (value) {
                        setState(() {
                          _defaultHourlyRate = double.tryParse(value) ?? 0.0;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Save button (large)
                  if (_hasChanges)
                    FilledButton(
                      onPressed: _isLoading ? null : _saveSettings,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                      child: const Text(
                        'Save Settings',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  /// Build section with title, icon, description
  Widget _buildSection({
    required String title,
    required IconData icon,
    required String description,
    required Widget child,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  /// Build timezone picker
  Widget _buildTimezonePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _selectedTimezone,
          decoration: const InputDecoration(
            labelText: 'Select Timezone',
            border: OutlineInputBorder(),
          ),
          items: _commonTimezones.map((tz) {
            return DropdownMenuItem(
              value: tz,
              child: Text(_formatTimezone(tz)),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedTimezone = value);
            }
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Selected: $_selectedTimezone',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  /// Format timezone for display
  String _formatTimezone(String tz) {
    final parts = tz.split('/');
    if (parts.length == 2) {
      return '${parts[1].replaceAll('_', ' ')} (${parts[0]})';
    }
    return tz;
  }

  /// Save settings
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // TODO: Call repository to save settings
      // final settings = CompanySettings(
      //   companyId: currentCompanyId,
      //   timezone: _selectedTimezone,
      //   requireGeofence: _requireGeofence,
      //   maxShiftHours: _maxShiftHours.toInt(),
      //   autoApproveTime: _autoApproveDays != null,
      //   autoApproveDays: _autoApproveDays,
      //   defaultHourlyRate: _defaultHourlyRate > 0 ? _defaultHourlyRate.toString() : null,
      // );
      //
      // await ref.read(companySettingsRepositoryProvider).update(settings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _hasChanges = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
