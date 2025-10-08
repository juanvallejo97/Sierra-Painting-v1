import 'package:flutter/material.dart';
import 'package:sierra_painting/mock_ui/components/app_scaffold.dart';

class PlaygroundHome extends StatelessWidget {
  const PlaygroundHome({super.key});

  @override
  Widget build(BuildContext context) {
    final demos = <_Demo>[
      _Demo('Widget Zoo', Icons.auto_awesome, '/zoo'),
      _Demo('Theme Lab', Icons.palette_outlined, '/theme'),
      _Demo('Jobs List', Icons.list_alt, '/jobs'),
      _Demo('Jobs Board', Icons.view_kanban, '/jobs-board'),
      _Demo('Estimate Editor', Icons.description, '/estimate'),
      _Demo('Invoice Preview', Icons.receipt_long, '/invoice'),
      _Demo('Time Tracker', Icons.timer, '/time'),
      _Demo('Photos Gallery', Icons.photo_library, '/photos'),
    ];
    return AppScaffold(
      title: 'Playground',
      body: GridView.count(
        padding: const EdgeInsets.all(16),
        crossAxisCount: MediaQuery.of(context).size.width > 1000
            ? 4
            : (MediaQuery.of(context).size.width > 700 ? 3 : 2),
        children: [
          for (final d in demos)
            Card(
              child: InkWell(
                onTap: () => Navigator.of(context).pushNamed(d.route),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [Icon(d.icon, size: 40), const SizedBox(height: 8), Text(d.title)],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Demo {
  final String title;
  final IconData icon;
  final String route;
  _Demo(this.title, this.icon, this.route);
}
