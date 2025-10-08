import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sierra_painting/core/privacy/consent_api.dart';
import 'package:sierra_painting/core/privacy/consent_store.dart';
import 'package:url_launcher/url_launcher_string.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});
  static const route = '/settings/privacy';
  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  late final PrivacyConsent _consent;
  bool _analytics = false;
  bool _crash = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _consent = PrivacyConsent(ConsentStore());
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _consent.applyFromDisk();
    final s = ConsentStore();
    final a = await s.getAnalytics() ?? true; // default opt-in
    final c = await s.getCrash() ?? true; // default opt-in
    setState(() {
      _analytics = a;
      _crash = c;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final privacyUrl = dotenv.env['PRIVACY_POLICY_URL'] ?? '';
    final termsUrl = dotenv.env['TERMS_URL'] ?? '';
    final support = dotenv.env['SUPPORT_EMAIL'] ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Support')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SwitchListTile(
                  title: const Text('Allow Analytics'),
                  subtitle: const Text(
                    'Help us improve with anonymous usage analytics.',
                  ),
                  value: _analytics,
                  onChanged: (v) async {
                    setState(() => _analytics = v);
                    await _consent.setAnalytics(v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Allow Crash Reports'),
                  subtitle: const Text(
                    'Send crash diagnostics to improve stability.',
                  ),
                  value: _crash,
                  onChanged: (v) async {
                    setState(() => _crash = v);
                    await _consent.setCrash(v);
                  },
                ),
                const Divider(),
                ListTile(
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => launchUrlString(
                    privacyUrl,
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                ListTile(
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => launchUrlString(
                    termsUrl,
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Contact Support'),
                  subtitle: Text(
                    support.isEmpty ? 'support unavailable' : support,
                  ),
                  onTap: support.isEmpty
                      ? null
                      : () => launchUrlString(
                          'mailto:$support?subject=Support%20Request',
                        ),
                ),
              ],
            ),
    );
  }
}
