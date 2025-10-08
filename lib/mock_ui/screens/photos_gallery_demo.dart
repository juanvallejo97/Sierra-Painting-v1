import 'package:flutter/material.dart';
import '../components/app_scaffold.dart';

class PhotosGalleryDemo extends StatefulWidget {
  const PhotosGalleryDemo({super.key});
  @override State<PhotosGalleryDemo> createState() => _PhotosGalleryDemoState();
}

class _PhotosGalleryDemoState extends State<PhotosGalleryDemo> {
  final List<Color> _colors = List.generate(9, (i) => Colors.primaries[i % Colors.primaries.length]);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Photos',
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: _colors.length,
              itemBuilder: (_, i) => Container(color: _colors[i], child: const Icon(Icons.image, color: Colors.white)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _colors.add(Colors.primaries[_colors.length % Colors.primaries.length])),
                    icon: const Icon(Icons.add_a_photo),
                    label: const Text('Add mock photo'),
                  ),
                  const Spacer(),
                  OutlinedButton.icon(onPressed: () => setState(() => _colors.clear()),
                    icon: const Icon(Icons.delete_sweep_outlined), label: const Text('Clear'))
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
