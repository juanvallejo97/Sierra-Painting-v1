# Performance & Cohesion Overhaul - Implementation Guide

> **Purpose**: Central guide for the Sierra Painting performance optimization initiative
>
> **Last Updated**: 2024
>
> **Status**: Phase 1 Complete

---

## 📋 Overview

This document provides a comprehensive overview of the performance and cohesion improvements implemented for the Sierra Painting application, following the performance engineering playbook.

**Objectives:**
- ✅ Minimize startup, jank, and network latency
- ✅ Enforce codebase cohesion with standards and guardrails
- ✅ Ship safely with continuous verification

---

## 🎯 What's Implemented

### Infrastructure (✅ Complete)

**Firebase Integration:**
- Firebase Performance Monitoring SDK
- Firebase Crashlytics for error tracking
- Firebase Analytics for user insights
- Automatic app startup tracking
- Network request monitoring
- Custom trace support

**CI/CD Enhancements:**
- APK size budget enforcement (50MB)
- Automated PR size reports
- Pre-commit hooks (formatting + linting)
- Performance checklist in PR template

**Optimized Widgets:**
- `CachedImage` - Automatic image caching
- `CachedCircleImage` - Avatar/profile pictures
- `PaginatedListView` - Lazy loading lists
- `PaginatedGridView` - Grid layouts with pagination

**Scripts:**
- `scripts/measure_startup.sh` - Startup time measurement
- `scripts/install-hooks.sh` - Pre-commit hook installer
- `scripts/git-hooks/pre-commit` - Code quality checks

**Documentation:**
- [Performance Budgets](./PERFORMANCE_BUDGETS.md) - Metrics and targets
- [Backend Performance](./BACKEND_PERFORMANCE.md) - Cloud Functions optimization
- [Performance Rollback](./PERFORMANCE_ROLLBACK.md) - Emergency procedures
- [Firebase Setup](./FIREBASE_SETUP.md) - Step-by-step setup
- [Canary Deployment](./CANARY_DEPLOYMENT.md) - Safe rollout strategy

---

## 📊 Performance Budgets

### Mobile App

| Metric | Target (P50) | Budget (P90) | Critical (P95) |
|--------|--------------|--------------|----------------|
| Cold Start | < 1.5s | < 2.0s | < 2.5s |
| First Frame | < 300ms | < 500ms | < 800ms |
| APK Size | < 30MB | < 50MB | < 60MB |
| Frame Rate | 60fps | 55fps | 50fps |
| Jank % | < 0.5% | < 1.0% | < 2.0% |

### Backend

| Metric | Target (P50) | Budget (P90) | Critical (P95) |
|--------|--------------|--------------|----------------|
| API Response | < 200ms | < 300ms | < 500ms |
| Cold Start | < 1.5s | < 3.0s | < 5.0s |
| Auth Calls | < 150ms | < 250ms | < 400ms |

**Enforcement:**
- ✅ CI checks APK size on every PR
- ⏳ Startup time checks (manual)
- 📝 TODO: Automated performance tests

---

## 🚀 Quick Start

### For Developers

**1. Install Pre-commit Hooks:**
```bash
./scripts/install-hooks.sh
```

**2. Use Optimized Widgets:**
```dart
// Instead of Image.network
CachedImage(
  imageUrl: 'https://example.com/image.jpg',
  width: 300,
  height: 200,
)

// Instead of ListView
PaginatedListView<Job>(
  itemBuilder: (context, job, index) => JobTile(job: job),
  onLoadMore: () => repository.fetchNextPage(),
)
```

**3. Track Performance:**
```dart
// Screen tracking (already available)
class _MyScreenState extends State<MyScreen> with PerformanceMonitorMixin {
  @override
  String get screenName => 'my_screen';

  @override
  void initState() {
    super.initState();
    startScreenTrace(); // Auto-tracked in Firebase
  }

  @override
  void dispose() {
    stopScreenTrace();
    super.dispose();
  }
}
```

**4. Follow PR Checklist:**
- Check the Performance Checklist section in PR template
- Ensure APK size is within budget
- Test in profile mode with DevTools

### For DevOps

**1. Set up Firebase:**
- Follow [Firebase Setup Guide](./FIREBASE_SETUP.md)
- Enable Performance Monitoring
- Enable Crashlytics
- Configure alerts

**2. Deploy with Canary:**
- Follow [Canary Deployment Guide](./CANARY_DEPLOYMENT.md)
- Use staged rollout (10% → 50% → 100%)
- Monitor gates at each stage

**3. Configure Monitoring:**
```
Firebase Console → Performance → Alerts
  - App start P90 > 2.5s → Email team
  - Crash-free rate < 99.5% → Slack alert
```

---

## 📈 Optimization Checklist

### App Startup (High Impact)

- [x] Firebase Performance tracking enabled
- [ ] Defer non-critical initialization
- [ ] Use `addPostFrameCallback` for secondary tasks
- [ ] Show native splash + skeleton UI
- [ ] Record Android Baseline Profiles

**Current Status:** Tracking enabled, manual optimizations pending

### UI Thread (High Impact)

- [x] Performance monitoring mixin available
- [ ] Audit widgets for `const` usage
- [ ] Move heavy JSON parsing to isolates
- [ ] Split long work into chunks
- [ ] Profile with DevTools

**Tools Available:**
- `PerformanceMonitorMixin` for screen tracking
- `PerformanceTrackedWidget` for build time tracking
- `PerformanceTracking` extension for async operations

### Lists & Pagination (High Impact)

- [x] `PaginatedListView` widget created
- [x] `PaginatedGridView` widget created
- [ ] Migrate existing lists to builders
- [ ] Implement Firestore cursor pagination
- [ ] Prefetch next page at 80% scroll

**Migration Path:**
1. Identify lists with >10 items
2. Replace with `PaginatedListView`
3. Implement pagination in repository
4. Test memory usage

### Image Optimization (High Impact)

- [x] `cached_network_image` dependency added
- [x] `CachedImage` widget created
- [ ] Replace `Image.network` calls
- [ ] Configure cache headers
- [ ] Optimize image sizes

**Migration Path:**
1. Find all `Image.network` usages
2. Replace with `CachedImage`
3. Set appropriate width/height
4. Test cache hit rates

### Backend (High Impact)

- [ ] Add `minInstances: 1` to critical functions
- [ ] Hoist imports to global scope
- [ ] Configure regional deployment
- [ ] Implement scheduled warm-ups
- [ ] Batch API calls where possible

**Priority Functions:**
- `clockIn` - High traffic
- `clockOut` - High traffic
- `createLead` - User-facing

### Offline & Resilience (Medium Impact)

- [x] Offline service implemented
- [x] Queue service for writes
- [ ] Enable Firestore offline persistence
- [ ] Add connectivity banner
- [ ] Test offline scenarios

---

## 📝 Best Practices

### Widget Performance

**Do:**
```dart
// ✅ Use const
const Text('Hello');

// ✅ Localize rebuilds
Consumer(
  builder: (context, ref, child) {
    final value = ref.watch(valueProvider);
    return Text(value);
  },
)

// ✅ Use builders for lists
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) => ItemTile(items[index]),
)
```

**Don't:**
```dart
// ❌ Non-const widgets
Text('Hello');

// ❌ Rebuild entire tree
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(provider);
    return Column(
      children: [
        // Entire column rebuilds when value changes
      ],
    );
  }
}

// ❌ Build all items
ListView(
  children: items.map((item) => ItemTile(item)).toList(),
)
```

### Network Calls

**Do:**
```dart
// ✅ Add timeout
final response = await http.get(url).timeout(
  const Duration(seconds: 30),
);

// ✅ Track performance
final trace = PerformanceMonitor().startTrace('api_call');
try {
  final result = await fetchData();
  trace.setAttribute('status', 'success');
  return result;
} finally {
  trace.stop();
}
```

**Don't:**
```dart
// ❌ No timeout
final response = await http.get(url);

// ❌ No tracking
final result = await fetchData();
```

### Firestore Queries

**Do:**
```dart
// ✅ Use limit
final query = collection
  .limit(50)
  .get();

// ✅ Use cursor pagination
final query = collection
  .limit(50)
  .startAfterDocument(lastDoc)
  .get();
```

**Don't:**
```dart
// ❌ Unbounded query
final query = collection.get();

// ❌ Load all pages at once
final allDocs = await collection.get();
```

---

## 🎬 Next Steps

### Phase 2: Code Optimization (Next Sprint)

**Week 1-2:**
- [ ] Audit widgets for `const` usage
- [ ] Migrate 5 key screens to optimized widgets
- [ ] Replace Image.network with CachedImage
- [ ] Add minInstances to 3 critical functions

**Week 3-4:**
- [ ] Implement Firestore pagination
- [ ] Move heavy operations to isolates
- [ ] Add performance tests
- [ ] Set up Firebase dashboards

### Phase 3: Monitoring & Iteration (Month 2)

- [ ] Measure baseline performance
- [ ] Create performance dashboards
- [ ] Set up automated alerts
- [ ] Run performance tests in CI
- [ ] Iterate based on real metrics

### Phase 4: Advanced Optimization (Month 3)

- [ ] Android Baseline Profiles
- [ ] Code splitting
- [ ] Lazy module loading
- [ ] Advanced caching strategies
- [ ] Multi-region deployment

---

## 🔧 Troubleshooting

### APK Size Over Budget

**Actions:**
1. Run `flutter build apk --analyze-size`
2. Check for large assets
3. Remove unused dependencies
4. Enable code shrinking

### Slow Startup

**Actions:**
1. Run `scripts/measure_startup.sh`
2. Profile with DevTools
3. Defer non-critical initialization
4. Check for heavy imports

### List Performance Issues

**Actions:**
1. Switch to ListView.builder
2. Add itemExtent if fixed height
3. Implement pagination
4. Use RepaintBoundary

---

## 📚 Reference Documentation

**Internal:**
- [Performance Budgets](./PERFORMANCE_BUDGETS.md)
- [Backend Performance](./BACKEND_PERFORMANCE.md)
- [Performance Rollback](./PERFORMANCE_ROLLBACK.md)
- [Firebase Setup](./FIREBASE_SETUP.md)
- [Canary Deployment](./CANARY_DEPLOYMENT.md)
- [Frontend Playbook](./perf-playbook-fe.md)

**External:**
- [Flutter Performance Best Practices](https://docs.flutter.dev/perf/best-practices)
- [Firebase Performance Monitoring](https://firebase.google.com/docs/perf-mon)
- [Firebase Crashlytics](https://firebase.google.com/docs/crashlytics)

---

## 🤝 Contributing

When contributing performance improvements:

1. **Measure First**: Get baseline metrics
2. **Make Small Changes**: One optimization at a time
3. **Measure Again**: Compare before/after
4. **Document**: Update docs with learnings
5. **Share**: Present findings to team

**PR Template:**
```markdown
## Performance Improvement

**Metric:** [App startup / List scroll / Image loading]
**Baseline:** [Current performance]
**After:** [New performance]
**Improvement:** [X% faster / X MB smaller]

**Testing:**
- [ ] Measured with DevTools
- [ ] Tested on low-end device
- [ ] Checked memory usage
- [ ] No regressions in other areas
```

---

## 📞 Support

**Questions?**
- Check documentation first
- Ask in #engineering Slack
- Create GitHub issue with `[Performance]` tag

**Report Issues:**
- Performance regression: High priority
- Budget violation: Blocker
- CI failure: Investigate before merging

---

## ✨ Success Criteria

**Phase 1 (Complete):**
- ✅ Firebase Performance/Crashlytics integrated
- ✅ CI budgets enforced
- ✅ Optimized widgets available
- ✅ Documentation complete

**Phase 2 (In Progress):**
- [ ] 50% of screens using optimized widgets
- [ ] 80% of images using CachedImage
- [ ] 90% of lists using builders
- [ ] All critical functions have minInstances

**Phase 3 (Planned):**
- [ ] Cold start P90 < 2s
- [ ] APK size < 40MB
- [ ] Crash-free rate > 99.5%
- [ ] Automated performance tests in CI

**Final Goal:**
- App startup P90 < 2s
- 60fps sustained in all screens
- APK size < 50MB
- Crash-free rate ≥ 99.5%
- Zero performance budget violations

---

**Last Updated:** 2024  
**Version:** 1.0  
**Status:** Phase 1 Complete, Phase 2 In Progress
