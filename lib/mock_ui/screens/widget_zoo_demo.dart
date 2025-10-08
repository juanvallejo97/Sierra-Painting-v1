import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sierra_painting/mock_ui/components/app_scaffold.dart';

class WidgetZooDemo extends StatelessWidget {
  const WidgetZooDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return const DefaultTabController(
      length: 5,
      child: AppScaffold(
        title: 'Widget Zoo',
        bottom: TabBar(
          isScrollable: true,
          tabs: [
            Tab(text: 'Typography'),
            Tab(text: 'Controls'),
            Tab(text: 'Data'),
            Tab(text: 'Layout'),
            Tab(text: 'Motion/FX'),
          ],
        ),
        body: TabBarView(children: [_TypographyTab(), _ControlsTab(), _DataTab(), _LayoutTab(), _MotionFxTab()]),
      ),
    );
  }
}

// -------------- TYPOGRAPHY --------------
class _TypographyTab extends StatelessWidget {
  const _TypographyTab();
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Display Large', style: t.displayLarge?.copyWith(letterSpacing: 1)),
        Text('Display Medium', style: t.displayMedium?.copyWith(fontWeight: FontWeight.w300)),
        Text(
          'Headline Large',
          style: t.headlineLarge?.copyWith(
            shadows: const [Shadow(blurRadius: 4, color: Colors.black26, offset: Offset(1, 2))],
          ),
        ),
        const Divider(),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Rich',
                style: t.headlineSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
              TextSpan(text: 'Text ', style: t.headlineSmall),
              TextSpan(
                text: 'with ',
                style: t.titleLarge?.copyWith(decoration: TextDecoration.underline),
              ),
              TextSpan(
                text: 'spans ',
                style: t.titleLarge?.copyWith(fontStyle: FontStyle.italic),
              ),
              TextSpan(text: 'and icons  ', style: t.titleLarge),
              const WidgetSpan(child: Icon(Icons.text_fields, size: 28)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            Chip(label: Text('Label Large', style: t.labelLarge)),
            Chip(label: Text('Body Medium', style: t.bodyMedium)),
            Chip(label: Text('Body Small', style: t.bodySmall)),
            Chip(
              label: Text('Mono', style: t.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Paragraph style demo', style: t.titleMedium),
                const SizedBox(height: 8),
                const Text(
                  'Coat the walls with color and clarity. This long paragraph wraps to demonstrate line height, letter spacing, and contrast behavior across surfaces. Adjust text scale and dark mode in Debug to test legibility.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// -------------- CONTROLS --------------
class _ControlsTab extends StatefulWidget {
  const _ControlsTab();
  @override
  State<_ControlsTab> createState() => _ControlsTabState();
}

class _ControlsTabState extends State<_ControlsTab> {
  bool s1 = true, s2 = false;
  double slider = .4;
  int seg = 0;
  double rating = 3;
  final _ctl = TextEditingController(text: '123 Main St');

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          runSpacing: 12,
          spacing: 12,
          children: [
            FilledButton(onPressed: () {}, child: const Text('Primary')),
            ElevatedButton(onPressed: () {}, child: const Text('Elevated')),
            OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
            TextButton(onPressed: () {}, child: const Text('Text')),
            IconButton(onPressed: () {}, icon: const Icon(Icons.favorite_border)),
            const Badge(label: Text('9'), child: Icon(Icons.notifications_outlined)),
          ],
        ),
        const Divider(),
        Row(
          children: [
            Switch(value: s1, onChanged: (v) => setState(() => s1 = v)),
            Switch.adaptive(value: s2, onChanged: (v) => setState(() => s2 = v)),
            const SizedBox(width: 12),
            Checkbox(value: s1, onChanged: (v) => setState(() => s1 = v ?? s1)),
            const SizedBox(width: 12),
            Radio<int>(value: 1, groupValue: seg, onChanged: (v) => setState(() => seg = v!)),
            Radio<int>(value: 2, groupValue: seg, onChanged: (v) => setState(() => seg = v!)),
          ],
        ),
        const SizedBox(height: 8),
        Slider(value: slider, onChanged: (v) => setState(() => slider = v)),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Day')),
            ButtonSegment(value: 1, label: Text('Week')),
            ButtonSegment(value: 2, label: Text('Month')),
          ],
          selected: {seg},
          onSelectionChanged: (s) => setState(() => seg = s.first),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ctl,
          decoration: const InputDecoration(labelText: 'Address', prefixIcon: Icon(Icons.home_outlined)),
        ),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 8,
          children: [
            Chip(label: Text('Open'), avatar: Icon(Icons.radio_button_unchecked, size: 16)),
            Chip(label: Text('In progress'), avatar: Icon(Icons.more_horiz, size: 16)),
            Chip(label: Text('Done'), avatar: Icon(Icons.check_circle_outline, size: 16)),
            InputChip(label: Text('Filter: Exterior')),
            ChoiceChip(label: Text('High priority'), selected: true),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ElevatedButton.icon(
              onPressed: () => _showDate(context),
              icon: const Icon(Icons.event),
              label: const Text('Pick date'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _showTime(context),
              icon: const Icon(Icons.schedule),
              label: const Text('Pick time'),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _showSnack(context),
              icon: const Icon(Icons.info_outline),
              label: const Text('Snack'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _showDialog(context),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Dialog'),
            ),
          ],
        ),
      ],
    );
  }

  void _showSnack(BuildContext c) => ScaffoldMessenger.of(
    c,
  ).showSnackBar(const SnackBar(content: Text('Saved! (mock)'), duration: Duration(seconds: 1)));

  Future<void> _showDialog(BuildContext c) async {
    await showDialog<void>(
      context: c,
      builder: (_) => AlertDialog(
        title: const Text('Confirm'),
        content: const Text('Do you want to apply these settings?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Apply')),
        ],
      ),
    );
  }

  Future<void> _showDate(BuildContext c) async {
    await showDatePicker(context: c, firstDate: DateTime(2020), lastDate: DateTime(2030), initialDate: DateTime.now());
  }

  Future<void> _showTime(BuildContext c) async {
    await showTimePicker(context: c, initialTime: TimeOfDay.now());
  }
}

// -------------- DATA DISPLAY --------------
class _DataTab extends StatefulWidget {
  const _DataTab();
  @override
  State<_DataTab> createState() => _DataTabState();
}

class _DataTabState extends State<_DataTab> {
  final data = List.generate(
    30,
    (i) => ('J${1000 + i}', 'Exterior Paint', 'Elk Grove', i.isEven ? 'open' : 'in_progress'),
  );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.account_circle)),
            title: const Text('Alex Customer'),
            subtitle: const Text('742 Evergreen Terrace'),
            trailing: FilledButton.tonal(onPressed: () {}, child: const Text('Call')),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('Title')),
              DataColumn(label: Text('City')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              for (final r in data.take(6))
                DataRow(
                  cells: [DataCell(Text(r.$1)), DataCell(Text(r.$2)), DataCell(Text(r.$3)), DataCell(Text(r.$4))],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          itemCount: 9,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemBuilder: (_, i) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.primaries[i * 2 % Colors.primaries.length],
                  Colors.primaries[(i * 2 + 5) % Colors.primaries.length],
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ExpansionTile(
          title: const Text('More details'),
          children: List.generate(
            3,
            (i) => ListTile(leading: const Icon(Icons.check_circle_outline), title: Text('Completed step ${i + 1}')),
          ),
        ),
        const SizedBox(height: 12),
        const _ReorderableDemo(),
      ],
    );
  }
}

class _ReorderableDemo extends StatefulWidget {
  const _ReorderableDemo();
  @override
  State<_ReorderableDemo> createState() => _ReorderableDemoState();
}

class _ReorderableDemoState extends State<_ReorderableDemo> {
  final items = List.generate(5, (i) => 'Task ${i + 1}');
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ReorderableListView(
        buildDefaultDragHandles: true,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        onReorder: (a, b) {
          setState(() {
            final item = items.removeAt(a);
            items.insert(b > a ? b - 1 : b, item);
          });
        },
        children: [
          for (final it in items)
            ListTile(key: ValueKey(it), title: Text(it), leading: const Icon(Icons.drag_indicator)),
        ],
      ),
    );
  }
}

// -------------- LAYOUT --------------
class _LayoutTab extends StatelessWidget {
  const _LayoutTab();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _box('Fixed 120×80', const Size(120, 80)),
            _box('Square 100', const Size(100, 100)),
            _box('Wide 200×80', const Size(200, 80)),
            _box('Tall 80×160', const Size(80, 160)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _gradientCard(context, 'Responsive 1')),
            Expanded(child: _gradientCard(context, 'Responsive 2')),
            Expanded(child: _gradientCard(context, 'Responsive 3')),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: SizedBox(
            height: 160,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Color(0x662563EB), Color(0x660EA5E9)]),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        color: Colors.white.withOpacity(0.2),
                        padding: const EdgeInsets.all(12),
                        child: const Text('Glassmorphism ✨'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SizedBox(height: 160, child: CustomPaint(painter: _RainbowPainter())),
        ),
      ],
    );
  }

  Widget _box(String label, Size size) => Container(
    width: size.width,
    height: size.height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF10B981)]),
      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(1, 2))],
    ),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    ),
  );

  Widget _gradientCard(BuildContext c, String title) => Card(
    child: Container(
      height: 80,
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF9333EA), Color(0xFFEA580C)])),
      child: Center(
        child: Text(title, style: Theme.of(c).textTheme.titleMedium!.copyWith(color: Colors.white)),
      ),
    ),
  );
}

class _RainbowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final colors = [Colors.red, Colors.orange, Colors.yellow, Colors.green, Colors.blue, Colors.purple];
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    for (int i = 0; i < colors.length; i++) {
      paint.color = colors[i].withOpacity(.7);
      final rect = Rect.fromLTWH(10.0 + i * 8, 10.0 + i * 8, size.width - 20 - i * 16, size.height - 20 - i * 16);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(12 + i * 3.0)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -------------- MOTION / FX --------------
class _MotionFxTab extends StatefulWidget {
  const _MotionFxTab();
  @override
  State<_MotionFxTab> createState() => _MotionFxTabState();
}

class _MotionFxTabState extends State<_MotionFxTab> {
  double size = 100;
  Color color = Colors.amber;
  bool cross = false;
  double angle = 0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            ElevatedButton(onPressed: () => setState(() => size = size == 100 ? 160 : 100), child: const Text('Size')),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => setState(() => color = color == Colors.amber ? Colors.teal : Colors.amber),
              child: const Text('Color'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: () => setState(() => cross = !cross), child: const Text('Crossfade')),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: () => setState(() => angle += math.pi / 6), child: const Text('Rotate')),
          ],
        ),
        const SizedBox(height: 12),
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black26)],
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 500),
          crossFadeState: cross ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: _boxy(Colors.indigo, 'A'),
          secondChild: _boxy(Colors.pink, 'B'),
        ),
        const SizedBox(height: 12),
        Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: angle),
            duration: const Duration(milliseconds: 400),
            builder: (_, a, child) => Transform.rotate(angle: a, child: child),
            child: _boxy(Colors.green, 'R'),
          ),
        ),
        const SizedBox(height: 12),
        const _HeroDemo(),
        const SizedBox(height: 12),
        LinearProgressIndicator(value: (size - 100) / 60),
      ],
    );
  }

  Widget _boxy(Color c, String t) => Container(
    width: 100,
    height: 100,
    color: c,
    child: Center(
      child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 24)),
    ),
  );
}

class _HeroDemo extends StatelessWidget {
  const _HeroDemo();
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        for (final color in [Colors.red, Colors.blue, Colors.green])
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _HeroDetail(color: color))),
            child: Hero(tag: color, child: _circle(color, 40)),
          ),
      ],
    );
  }

  Widget _circle(Color c, double r) => Container(
    width: r,
    height: r,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );
}

class _HeroDetail extends StatelessWidget {
  final Color color;
  const _HeroDetail({required this.color});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Hero(
          tag: color,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
