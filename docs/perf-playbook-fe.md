# Frontend Performance Playbook

> **Purpose**: Performance optimization guidelines and best practices for Sierra Painting Flutter app
>
> **Last Updated**: 2024
>
> **Status**: Living Document

---

## Overview

This playbook provides actionable performance guidelines for Flutter development at Sierra Painting, with a focus on mobile-first performance and 60fps smooth animations.

---

## Performance Targets

### Mobile (Flutter)

| Metric | Target (P50) | Target (P95) | Notes |
|--------|-------------|--------------|-------|
| Frame rate | 60fps | 60fps | Device max (120fps on capable devices) |
| Frame build time | < 8ms | < 16ms | 16ms = 60fps budget |
| Screen render | < 300ms | < 500ms | Initial paint |
| Network action | < 100ms | < 200ms | After warm cache |
| App startup (cold) | < 2s | < 3s | First frame |
| App startup (warm) | < 500ms | < 1s | Resume from background |

### API Performance

| Operation | Target (P50) | Target (P95) | Notes |
|-----------|-------------|--------------|-------|
| Firestore read (cached) | < 50ms | < 100ms | Local cache hit |
| Firestore read (network) | < 500ms | < 1s | Network fetch |
| Firestore write | < 200ms | < 300ms | With offline support |
| Cloud Function call | < 500ms | < 1s | Warm function |
| Cold start | < 2s | < 2.5s | First invocation |

---

## Core Principles

### 1. Const Widgets Everywhere

**Why**: Dart optimizes `const` widgets by reusing instances, reducing memory and rebuild overhead.

**Rule**: Use `const` for any widget that doesn't depend on runtime state.

**Example**:
```dart
// ❌ Bad - Widget rebuilt every time
return Text('Hello');

// ✅ Good - Widget reused
return const Text('Hello');

// ✅ Good - Const constructor
class MyWidget extends StatelessWidget {
  const MyWidget({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return const Text('Hello');
  }
}
```

**Quick Win**: Add `const` to all static widgets (Text, Icon, Padding, etc.)

---

### 2. Localize State

**Why**: Minimize rebuild scope - only rebuild widgets that need updating.

**Rule**: Place `Consumer`/`ref.watch()` as deep in the widget tree as possible.

**Example**:
```dart
// ❌ Bad - Entire screen rebuilds on counter change
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(counterProvider);
    return Scaffold(
      body: Column(
        children: [
          ExpensiveWidget(), // Rebuilds unnecessarily!
          Text('Count: $counter'),
        ],
      ),
    );
  }
}

// ✅ Good - Only counter widget rebuilds
class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ExpensiveWidget(), // Doesn't rebuild!
          Consumer(
            builder: (context, ref, child) {
              final counter = ref.watch(counterProvider);
              return Text('Count: $counter');
            },
          ),
        ],
      ),
    );
  }
}
```

---

### 3. Avoid Heavy Work on UI Thread

**Why**: UI thread blocks cause frame drops (jank).

**Rule**: Use `compute()` or isolates for CPU-intensive work.

**Example**:
```dart
// ❌ Bad - Blocks UI thread
List<String> processData(List<String> data) {
  return data.map((item) => item.toUpperCase()).toList();
}

// ✅ Good - Runs in separate isolate
Future<List<String>> processDataAsync(List<String> data) async {
  return compute(_processData, data);
}

List<String> _processData(List<String> data) {
  return data.map((item) => item.toUpperCase()).toList();
}
```

**Use For**:
- JSON parsing (large payloads)
- Image processing
- Complex calculations
- Data transformations

---

### 4. Lazy Loading

**Why**: Don't build widgets that aren't visible.

**Rule**: Use `ListView.builder` or `GridView.builder` for long lists.

**Example**:
```dart
// ❌ Bad - All items built upfront
ListView(
  children: items.map((item) => ItemTile(item)).toList(),
)

// ✅ Good - Items built on-demand
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemTile(items[index]),
)
```

**Use For**:
- Any list with > 10 items
- Infinite scroll
- Dynamic content

---

### 5. Image Optimization

**Why**: Images are the largest assets and most expensive to decode.

**Rule**: Use appropriate image sizes and caching.

**Example**:
```dart
// ❌ Bad - Large image, no caching
Image.network('https://example.com/large-image.jpg')

// ✅ Good - Cached network image with placeholder
CachedNetworkImage(
  imageUrl: 'https://example.com/image.jpg',
  placeholder: (context, url) => const CircularProgressIndicator(),
  errorWidget: (context, url, error) => const Icon(Icons.error),
  cacheKey: 'image-key',
  maxHeight: 200, // Limit decode size
  maxWidth: 200,
)
```

**Best Practices**:
- Use WebP format (smaller files)
- Set `cacheWidth` and `cacheHeight` to decode at display size
- Use `precacheImage()` for critical images
- Lazy load images outside viewport

---

### 6. Minimize Rebuilds

**Why**: Every rebuild has a cost, even if the output is the same.

**Rule**: Use `AnimatedBuilder` to scope animations, avoid `setState()` on large widgets.

**Example**:
```dart
// ❌ Bad - Entire widget rebuilds on every animation frame
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(seconds: 1));
    _controller.addListener(() => setState(() {})); // Rebuilds everything!
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ExpensiveWidget(), // Rebuilds every frame!
        Container(
          width: _controller.value * 100,
          child: const Text('Animated'),
        ),
      ],
    );
  }
}

// ✅ Good - Only animated widget rebuilds
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(seconds: 1));
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const ExpensiveWidget(), // Doesn't rebuild!
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Container(
            width: _controller.value * 100,
            child: child,
          ),
          child: const Text('Animated'), // Built once!
        ),
      ],
    );
  }
}
```

---

## Flutter-Specific Optimizations

### 1. Use RepaintBoundary

**Why**: Isolate expensive widgets to their own layer for efficient repainting.

**Rule**: Wrap widgets that don't change but have siblings that do.

**Example**:
```dart
Column(
  children: [
    RepaintBoundary(
      child: ComplexStaticChart(), // Won't repaint when counter changes
    ),
    Text('Counter: $counter'),
  ],
)
```

**Use For**:
- Complex charts/graphs
- Images
- Static content with dynamic siblings

---

### 2. Avoid Opacity Widget

**Why**: `Opacity` is expensive - it forces a compositing layer.

**Rule**: Use `AnimatedOpacity` or paint-level opacity instead.

**Example**:
```dart
// ❌ Bad - Forces expensive compositing
Opacity(
  opacity: 0.5,
  child: MyWidget(),
)

// ✅ Good - Uses paint-level opacity
ColorFiltered(
  colorFilter: ColorFilter.mode(
    Colors.white.withOpacity(0.5),
    BlendMode.dstIn,
  ),
  child: MyWidget(),
)

// ✅ Best - Animated transitions
AnimatedOpacity(
  opacity: isVisible ? 1.0 : 0.0,
  duration: const Duration(milliseconds: 300),
  child: MyWidget(),
)
```

---

### 3. Avoid ClipPath/ClipRRect

**Why**: Clipping is expensive, especially on every frame.

**Rule**: Use `BorderRadius` on containers or decoration instead.

**Example**:
```dart
// ❌ Bad - Expensive clipping
ClipRRect(
  borderRadius: BorderRadius.circular(10),
  child: Image.network('url'),
)

// ✅ Good - Decoration clipping (faster)
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(10),
    image: DecorationImage(
      image: NetworkImage('url'),
      fit: BoxFit.cover,
    ),
  ),
)
```

---

### 4. ListView Performance

**Why**: Large lists can cause memory issues and slow scrolling.

**Rule**: Use `ListView.builder` with `itemExtent` or `prototypeItem`.

**Example**:
```dart
// ❌ Bad - Flutter has to measure every item
ListView.builder(
  itemCount: 1000,
  itemBuilder: (context, index) => ItemTile(items[index]),
)

// ✅ Good - Flutter knows item height upfront
ListView.builder(
  itemCount: 1000,
  itemExtent: 80.0, // Fixed height
  itemBuilder: (context, index) => ItemTile(items[index]),
)

// ✅ Good - Flutter measures prototype once
ListView.builder(
  itemCount: 1000,
  prototypeItem: ItemTile(items.first),
  itemBuilder: (context, index) => ItemTile(items[index]),
)
```

---

### 5. Dispose Controllers

**Why**: Memory leaks cause performance degradation over time.

**Rule**: Always dispose controllers in `dispose()`.

**Example**:
```dart
class MyWidget extends StatefulWidget {
  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late TextEditingController _controller;
  late AnimationController _animController;
  
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _animController = AnimationController(vsync: this);
  }
  
  @override
  void dispose() {
    _controller.dispose(); // ✅ Always dispose
    _animController.dispose(); // ✅ Always dispose
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);
  }
}
```

---

## Firestore Performance

### 1. Enable Offline Persistence

**Status**: ✅ Already enabled in `lib/core/providers/firestore_provider.dart`

**Configuration**:
```dart
firestore.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);
```

---

### 2. Use Indexes for Queries

**Why**: Queries without indexes fail in production.

**Rule**: Add composite indexes to `firestore.indexes.json` for complex queries.

**Example**:
```json
{
  "indexes": [
    {
      "collectionGroup": "timeEntries",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "orgId", "order": "ASCENDING" },
        { "fieldPath": "userId", "order": "ASCENDING" },
        { "fieldPath": "clockIn", "order": "DESCENDING" }
      ]
    }
  ]
}
```

---

### 3. Limit Query Results

**Why**: Large result sets slow down queries and increase bandwidth.

**Rule**: Always use `.limit()` for lists.

**Example**:
```dart
// ❌ Bad - Fetches all documents
final snapshot = await collection.get();

// ✅ Good - Limits results
final snapshot = await collection.limit(50).get();

// ✅ Better - Paginate with cursor
final snapshot = await collection
  .limit(50)
  .startAfterDocument(lastDocument)
  .get();
```

---

### 4. Use Snapshot Listeners Wisely

**Why**: Real-time listeners use bandwidth and trigger rebuilds.

**Rule**: Only use listeners for data that needs real-time updates.

**Example**:
```dart
// ❌ Bad - Real-time for static data
collection.snapshots().listen((snapshot) { /* ... */ });

// ✅ Good - One-time fetch for static data
final snapshot = await collection.get();

// ✅ Good - Real-time only when needed
if (requiresRealtime) {
  collection.snapshots().listen((snapshot) { /* ... */ });
} else {
  final snapshot = await collection.get();
}
```

---

## Offline & Network Resilience

### 1. Offline Queue

**Status**: ✅ Implemented in `lib/core/services/queue_service.dart`

**Usage**:
```dart
final queueService = ref.read(queueServiceProvider);
await queueService.enqueue(
  operation: 'clockIn',
  data: { 'jobId': '123', 'at': DateTime.now() },
);
```

---

### 2. Optimistic Updates

**Rule**: Update UI immediately, rollback on error.

**Example**:
```dart
// Update UI optimistically
setState(() {
  item.status = 'completed';
});

try {
  // Persist to backend
  await updateItem(item);
} catch (e) {
  // Rollback on error
  setState(() {
    item.status = 'pending';
  });
  showError('Failed to update item');
}
```

---

### 3. Network Timeouts

**Rule**: Always set timeouts for network operations.

**TODO**: Implement HTTP client with timeout and retry logic

**Example**:
```dart
try {
  final response = await http.get(url).timeout(
    const Duration(seconds: 10),
  );
} on TimeoutException {
  // Handle timeout
} catch (e) {
  // Handle other errors
}
```

---

## Profiling & Debugging

### 1. Flutter DevTools

**Usage**:
```bash
flutter pub global activate devtools
flutter pub global run devtools
```

**Tools**:
- **Performance**: CPU profiler, frame timeline
- **Memory**: Heap snapshot, allocation tracking
- **Network**: HTTP traffic inspection

**Metrics to Watch**:
- Frame render time (should be < 16ms for 60fps)
- Raster time (GPU work)
- Build time per widget
- Memory usage (watch for leaks)

---

### 2. Performance Overlay

**Enable**: In app code or via DevTools

**Code**:
```dart
MaterialApp(
  showPerformanceOverlay: true, // Shows frame times
  // ...
)
```

**Indicators**:
- Green bars: Good (< 16ms)
- Yellow/red bars: Frame drops (> 16ms)

---

### 3. Timeline Analysis

**Record**:
```bash
flutter run --profile
# Interact with app
# Press 'r' to save timeline
```

**Analyze**: Open in Chrome DevTools Performance tab

**Look For**:
- Long build/layout/paint phases
- Expensive widgets
- Unnecessary rebuilds

---

## Testing Performance

### 1. Integration Tests with Timing

**Example**:
```dart
testWidgets('Screen loads within 500ms', (tester) async {
  final stopwatch = Stopwatch()..start();
  
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();
  
  stopwatch.stop();
  expect(stopwatch.elapsedMilliseconds, lessThan(500));
});
```

---

### 2. Benchmark Tests

**Example**:
```dart
void main() {
  group('Performance benchmarks', () {
    test('Parse large JSON', () async {
      final stopwatch = Stopwatch()..start();
      
      final result = await compute(parseJson, largeJsonString);
      
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(100));
    });
  });
}
```

---

## Package Audit

### Current Dependencies

Review `pubspec.yaml` for bloat:

**Essential**:
- firebase_core, firebase_auth, cloud_firestore (required)
- go_router, flutter_riverpod (architecture)
- hive, hive_flutter (offline)

**Optional** (evaluate if needed):
- flutter_stripe (if not using Stripe, remove)
- connectivity_plus (if not checking network state, remove)

**Rule**: Remove unused dependencies to reduce binary size

---

## Build Optimization

### 1. Split APKs by ABI

**Configuration**: `android/app/build.gradle`

```gradle
android {
  splits {
    abi {
      enable true
      reset()
      include 'armeabi-v7a', 'arm64-v8a', 'x86_64'
      universalApk false
    }
  }
}
```

**Result**: Smaller APK size (40-60% reduction)

---

### 2. Obfuscation & Minification

**Build Command**:
```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

**Benefits**:
- Smaller binary size
- Code protection
- Faster startup (slightly)

---

## Monitoring & Metrics

### Firebase Performance Monitoring

**Status**: Mentioned in docs, TODO: verify implementation

**Setup**:
```dart
import 'package:firebase_performance/firebase_performance.dart';

// Custom traces
final trace = FirebasePerformance.instance.newTrace('screen_load');
await trace.start();
// ... do work
await trace.stop();
```

**Metrics to Track**:
- Screen transition time
- API call duration
- Offline sync latency

---

### Analytics Events

**Track**:
- Feature usage
- Error rates
- Performance issues (slow screens)

**Example**:
```dart
FirebaseAnalytics.instance.logEvent(
  name: 'screen_load_slow',
  parameters: {
    'screen': 'timeclock',
    'load_time_ms': 2500,
  },
);
```

---

## Checklist for New Features

Before merging any PR:

- [ ] Added `const` to all static widgets
- [ ] State changes localized (minimal rebuild scope)
- [ ] Heavy work offloaded to isolates
- [ ] Lists use `.builder()` pattern
- [ ] Images cached and sized appropriately
- [ ] Controllers disposed properly
- [ ] Firestore queries have indexes
- [ ] Network calls have timeouts
- [ ] Optimistic updates for writes
- [ ] Performance tested with DevTools
- [ ] No frame drops in profile mode
- [ ] Memory leaks checked

---

## Quick Wins (Immediate Actions)

1. **Add `const` to all Text/Icon widgets** (5-10% build time improvement)
2. **Use `ListView.builder` for all lists** (prevents OOM on large lists)
3. **Enable `itemExtent` on fixed-height lists** (10-20% scroll performance)
4. **Add `RepaintBoundary` around static content** (reduces repaints)
5. **Profile with DevTools** (identify actual bottlenecks)

---

## Related Documentation

- [Architecture Overview](./Architecture.md)
- [Testing Strategy](./Testing.md)
- [Firestore Performance](https://firebase.google.com/docs/firestore/best-practices)
- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
