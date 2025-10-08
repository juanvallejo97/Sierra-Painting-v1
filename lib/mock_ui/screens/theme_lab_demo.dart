import 'package:flutter/material.dart';
import '../components/app_scaffold.dart';
import '../demo_state.dart';

class ThemeLabDemo extends StatelessWidget {
  const ThemeLabDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final c = DemoScope.of(context);
    final palettes = <Color>[
      const Color(0xFF2563EB), const Color(0xFF16A34A), const Color(0xFF9333EA),
      const Color(0xFFEA580C), const Color(0xFFE11D48), const Color(0xFF0891B2),
      const Color(0xFF0EA5E9), const Color(0xFF22C55E), const Color(0xFFF59E0B),
    ];

    return AppScaffold(
      title: 'Theme Lab',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Seed color', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final col in palettes)
              GestureDetector(
                onTap: () => c.setSeed(col),
                child: Container(width: 40, height: 40, decoration: BoxDecoration(
                  color: col, shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).colorScheme.outline),
                )),
              ),
          ]),
          const SizedBox(height: 16),
          Text('Corner radius: ${c.radius.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleLarge),
          Slider(min: 0, max: 32, divisions: 32, value: c.radius, onChanged: c.setRadius),
          const SizedBox(height: 8),
          Text('Density: ${c.density.toStringAsFixed(1)} (‑2 compact → +2 comfy)', style: Theme.of(context).textTheme.titleLarge),
          Slider(min: -2, max: 2, divisions: 16, value: c.density, onChanged: c.setDensity),
          const SizedBox(height: 24),
          Text('Preview', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 12, children: const [
            _PreviewCard(title: 'Elevated', child: ElevatedButton(onPressed: null, child: Text('Elevated'))),
            _PreviewCard(title: 'Filled', child: FilledButton(onPressed: null, child: Text('Filled'))),
            _PreviewCard(title: 'Outlined', child: OutlinedButton(onPressed: null, child: Text('Outlined'))),
            _PreviewCard(title: 'Chip', child: Chip(label: Text('Chip'))),
            _PreviewCard(title: 'TextField', child: SizedBox(width: 220, child: TextField(decoration: InputDecoration(labelText: 'Label')))),
            _PreviewCard(title: 'Switch', child: Switch(value: true, onChanged: null)),
            _PreviewCard(title: 'Slider', child: SizedBox(width: 160, child: Slider(value: .6, onChanged: (_){}))),
          ]),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String title; final Widget child;
  const _PreviewCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        child,
      ]),
    ));
  }
}
