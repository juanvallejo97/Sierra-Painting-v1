import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sierra_painting/core/providers.dart';
import 'package:sierra_painting/core/widgets/logout_dialog.dart';

/// General Settings Screen
/// Provides logout, permissions, and app preferences
/// Implements MASTER_UX_BLUEPRINT.md Section C.4 - Permission Management
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  LocationPermission? _locationPermission;
  bool _isServiceEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final permission = await Geolocator.checkPermission();
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      setState(() {
        _locationPermission = permission;
        _isServiceEnabled = serviceEnabled;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: RefreshIndicator(
        onRefresh: _checkPermissions,
        child: ListView(
          children: [
            // Permissions Section
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Permissions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            _buildPermissionsCard(),

            const Divider(height: 32),

            // General Settings
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'General',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
            const ListTile(
              leading: Icon(Icons.account_circle),
              title: Text('Account'),
              subtitle: Text('Profile settings'),
            ),
            const ListTile(
              leading: Icon(Icons.notifications),
              title: Text('Notifications'),
              subtitle: Text('Manage notifications'),
            ),
            const ListTile(
              leading: Icon(Icons.privacy_tip),
              title: Text('Privacy'),
              subtitle: Text('Privacy settings'),
              trailing: Icon(Icons.chevron_right),
            ),

            const Divider(height: 32),

            // Logout
            Semantics(
              label: 'Sign Out',
              hint: 'Sign out of your account and return to login screen',
              button: true,
              child: ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () async {
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
      ),
    );
  }

  Widget _buildPermissionsCard() {
    if (_isLoading) {
      return const Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Location Services
          ListTile(
            leading: Icon(
              Icons.location_on,
              color: _isServiceEnabled ? Colors.green : Colors.grey,
            ),
            title: const Text('Location Services'),
            subtitle: Text(_isServiceEnabled ? 'Enabled' : 'Disabled'),
            trailing: !_isServiceEnabled
                ? IconButton(
                    icon: const Icon(Icons.settings),
                    tooltip: 'Open Settings',
                    onPressed: _openLocationSettings,
                  )
                : const Icon(Icons.check_circle, color: Colors.green),
          ),
          const Divider(),

          // Location Permission
          ListTile(
            leading: Icon(Icons.gps_fixed, color: _getPermissionColor()),
            title: const Text('Location Permission'),
            subtitle: Text(_getPermissionText()),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_needsUpgrade())
                  TextButton(
                    onPressed: _requestPermissionUpgrade,
                    child: const Text('Upgrade'),
                  ),
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  tooltip: 'Permission Info',
                  onPressed: _showPermissionInfo,
                ),
              ],
            ),
          ),

          // Open Settings Button
          if (_locationPermission == LocationPermission.denied ||
              _locationPermission == LocationPermission.deniedForever ||
              !_isServiceEnabled)
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openLocationSettings,
                  icon: const Icon(Icons.settings),
                  label: const Text('Open Location Settings'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getPermissionColor() {
    switch (_locationPermission) {
      case LocationPermission.always:
        return Colors.green;
      case LocationPermission.whileInUse:
        return Colors.blue;
      case LocationPermission.denied:
      case LocationPermission.deniedForever:
        return Colors.red;
      case LocationPermission.unableToDetermine:
      case null:
        return Colors.grey;
    }
  }

  String _getPermissionText() {
    switch (_locationPermission) {
      case LocationPermission.always:
        return 'Always (Recommended)';
      case LocationPermission.whileInUse:
        return 'While Using App (Upgrade recommended)';
      case LocationPermission.denied:
        return 'Denied (Location features disabled)';
      case LocationPermission.deniedForever:
        return 'Permanently Denied';
      case LocationPermission.unableToDetermine:
      case null:
        return 'Unknown';
    }
  }

  bool _needsUpgrade() {
    return _locationPermission == LocationPermission.whileInUse;
  }

  Future<void> _requestPermissionUpgrade() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Upgrade Permission'),
        content: const Text(
          'For best performance with geofence timeclock, please allow location access "Always".\n\n'
          'This allows the app to track your location even when not actively using it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _openLocationSettings();
    }
  }

  Future<void> _openLocationSettings() async {
    await openAppSettings();
    // Wait for user to return and re-check permissions
    Future.delayed(const Duration(seconds: 1), _checkPermissions);
  }

  void _showPermissionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 12),
            Text('Location Permission'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This app requires location permission for:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildInfoItem(
                Icons.access_time,
                'Time Clock',
                'Verify you\'re at the job site when clocking in/out',
              ),
              const SizedBox(height: 8),
              _buildInfoItem(
                Icons.location_on,
                'Geofence',
                'Ensure entries are made within valid work locations',
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.verified_user,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Your Privacy',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Location is only used for timeclock validation. '
                      'We do not track your location outside of work hours.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade700),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
