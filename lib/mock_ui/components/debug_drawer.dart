import 'package:flutter/material.dart';
import 'package:sierra_painting/mock_ui/demo_state.dart';

class DebugDrawer extends StatelessWidget {
  const DebugDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final c = DemoScope.of(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(child: Text('Debug Controls')),
          SwitchListTile(
            title: const Text('Dark mode'),
            value: c.darkMode,
            onChanged: c.setDark,
          ),
          SwitchListTile(
            title: const Text('Right‑to‑left (RTL)'),
            value: c.rtl,
            onChanged: c.setRtl,
          ),
          ListTile(
            title: const Text('Text scale'),
            subtitle: Slider(
              min: 0.8,
              max: 1.6,
              divisions: 8,
              value: c.textScale,
              onChanged: c.setScale,
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Simulate loading'),
            value: c.simulateLoading,
            onChanged: c.setLoading,
          ),
          SwitchListTile(
            title: const Text('Simulate error'),
            value: c.simulateError,
            onChanged: c.setError,
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Tip: these flags affect all demo screens.'),
          ),
        ],
      ),
    );
  }
}
