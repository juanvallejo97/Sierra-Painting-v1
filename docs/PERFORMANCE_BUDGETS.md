# Performance Budgets

> **Purpose**: Define and enforce performance budgets for the Sierra Painting application
>
> **Last Updated**: 2024
>
> **Status**: Active

---

## Overview

Performance budgets are quantifiable limits on metrics that affect user experience. This document defines our budgets and enforcement mechanisms.

---

## Budget Definition

### Mobile App (Flutter)

| Metric | Target (P50) | Budget (P90) | Critical (P95) | Notes |
|--------|--------------|--------------|----------------|-------|
| **Cold Start** | < 1.5s | < 2.0s | < 2.5s | Time to first frame |
| **Warm Start** | < 0.8s | < 1.2s | < 1.5s | App in background |
| **First Frame** | < 300ms | < 500ms | < 800ms | Time to skeleton UI |
| **APK Size** | < 30MB | < 50MB | < 60MB | Release APK |
| **AAB Size** | < 25MB | < 40MB | < 50MB | Release bundle |
| **Frame Rate** | 60fps | 55fps | 50fps | Sustained performance |
| **Jank %** | < 0.5% | < 1.0% | < 2.0% | % of frames >16ms |
| **Memory Peak** | < 200MB | < 300MB | < 400MB | During normal use |

### Backend (Cloud Functions)

| Metric | Target (P50) | Budget (P90) | Critical (P95) | Notes |
|--------|--------------|--------------|----------------|-------|
| **API Response** | < 200ms | < 300ms | < 500ms | Warmed functions |
| **Cold Start** | < 1.5s | < 3.0s | < 5.0s | First invocation |
| **Auth Calls** | < 150ms | < 250ms | < 400ms | Clock in/out |
| **Read Operations** | < 100ms | < 200ms | < 300ms | Firestore reads |
| **Write Operations** | < 200ms | < 400ms | < 600ms | Firestore writes |

### Network

| Metric | Target (P50) | Budget (P90) | Critical (P95) | Notes |
|--------|--------------|--------------|----------------|-------|
| **Payload Size** | < 50KB | < 100KB | < 200KB | Per API call |
| **Image Size** | < 200KB | < 500KB | < 1MB | Compressed |
| **Bundle Transfer** | < 10MB | < 20MB | < 30MB | First load |

---

## CI Enforcement

### Automated Checks

The CI pipeline enforces budgets on every PR:

```yaml
# .github/workflows/ci.yml
- name: Check APK size budget
  run: |
    APK_SIZE=$(stat -c%s "build/app/outputs/flutter-apk/app-release.apk")
    APK_SIZE_MB=$((APK_SIZE / 1024 / 1024))
    MAX_SIZE_MB=50
    if [ $APK_SIZE_MB -gt $MAX_SIZE_MB ]; then
      echo "❌ APK size exceeds budget!"
      exit 1
    fi
```

### Budget Violations

When a PR violates budgets:

1. **CI Fails**: The PR is blocked from merging
2. **Comment Posted**: Automated comment shows violation details
3. **Review Required**: Team lead must approve override
4. **Justification**: PR description must explain why and mitigation plan

---

## Measurement Tools

### Flutter App

**Startup Time:**
```bash
# Measure cold start
./scripts/measure_startup.sh [device_id]

# Output: build/startup_metrics.json
```

**Frame Rate & Jank:**
```dart
// Enable performance overlay in app
import 'package:sierra_painting/core/widgets/performance_overlay.dart';

// Use in development
PerformanceOverlay.allRasterizeAndGpuTimes();
```

**Memory:**
```bash
# Flutter DevTools
flutter run --profile
# Open DevTools → Memory tab
```

**APK Size:**
```bash
flutter build apk --release --analyze-size
```

### Backend

**Cloud Functions:**
- Firebase Console → Functions → Metrics
- Cloud Trace for detailed traces
- Cloud Logging for request logs

**Firestore:**
- Firebase Console → Firestore → Usage
- Query performance tracked in logs

---

## Firebase Performance Monitoring

### Automatic Traces

Firebase Performance SDK tracks:
- App startup time
- Screen render times
- Network requests
- Custom traces

**Setup:**
```dart
// Already integrated in lib/main.dart
import 'package:firebase_performance/firebase_performance.dart';

// Automatic tracking enabled in release mode
final performance = FirebasePerformance.instance;
```

### Custom Traces

**Screen Performance:**
```dart
class _MyScreenState extends State<MyScreen> with PerformanceMonitorMixin {
  @override
  String get screenName => 'my_screen';

  @override
  void initState() {
    super.initState();
    startScreenTrace(); // Automatically tracked
  }

  @override
  void dispose() {
    stopScreenTrace(); // Reports to Firebase
    super.dispose();
  }
}
```

**Custom Operations:**
```dart
final trace = FirebasePerformance.instance.newTrace('operation_name');
await trace.start();
// ... perform operation
trace.putAttribute('status', 'success');
trace.setMetric('items_processed', 42);
await trace.stop();
```

---

## Budget Tuning

### When to Adjust Budgets

**Increase Budget** if:
- New features inherently require more resources
- Platform limitations prevent meeting current budget
- User metrics show acceptable experience above current budget

**Decrease Budget** if:
- Optimizations consistently beat current budget by >20%
- Competitor apps set new baseline
- User metrics show need for better performance

### Approval Process

1. **Propose Change**: Create issue with justification
2. **Data Required**: 
   - Current performance metrics
   - User impact analysis
   - Competitor benchmarks
   - Implementation cost
3. **Team Review**: Engineering lead + PM approval
4. **Update Docs**: Update this file and CI configs
5. **Communicate**: Notify team of new budgets

---

## Performance Dashboard

### Firebase Console

**Real User Monitoring:**
1. Navigate to Firebase Console → Performance
2. View app startup, network, and custom traces
3. Filter by app version, device, network type
4. Set alerts for P90/P95 violations

**Key Metrics to Monitor:**
- App startup duration (P50, P90, P95)
- Screen render times
- Network request duration and success rate
- Custom trace performance

### CI Dashboard

**GitHub Actions:**
- PR comments show APK size
- Build artifacts include metrics
- Trends tracked over time

---

## Budget Violation Response

### Immediate Actions

**If CI Fails:**
1. **Investigate**: Review changes causing violation
2. **Quick Fix**: 
   - Remove unused dependencies
   - Optimize images
   - Defer heavy operations
3. **Workaround**: Feature flag to disable if critical
4. **Document**: Add note to PR about violation and plan

### Long-term Solutions

**For Size Violations:**
- Audit dependencies (remove unused, find lighter alternatives)
- Enable code shrinking and obfuscation
- Split features into dynamic modules
- Compress assets more aggressively

**For Startup Violations:**
- Defer non-critical initializations
- Use `addPostFrameCallback` for secondary tasks
- Optimize Firebase SDK initialization
- Profile with DevTools to find bottlenecks

**For Runtime Violations:**
- Move work to isolates
- Reduce widget rebuilds
- Implement pagination
- Cache more aggressively

---

## Related Documentation

- [Frontend Performance Playbook](./perf-playbook-fe.md)
- [Implementation Summary](./IMPLEMENTATION_SUMMARY.md)
- [Testing Strategy](./Testing.md)
- [CI/CD Workflows](../.github/workflows/)

---

## Monitoring & Alerts

### Alert Configuration

**Firebase Performance:**
```
Metric: app_start_trace
Condition: P90 > 2500ms
Action: Email to engineering@
```

**Cloud Functions:**
```
Metric: execution_time
Condition: P95 > 5000ms
Function: clockIn
Action: Email to oncall@
```

### Weekly Reviews

Team reviews performance metrics every Monday:
- Trend analysis
- Budget violations
- User complaints correlation
- Optimization opportunities

---

## Budget History

| Date | Metric | Old Budget | New Budget | Reason |
|------|--------|------------|------------|--------|
| 2024-01 | Cold Start P90 | 2.5s | 2.0s | Improved init |
| 2024-01 | APK Size | 60MB | 50MB | Deps cleanup |

---

## Quick Reference

**Check Budgets Locally:**
```bash
# APK size
flutter build apk --release
ls -lh build/app/outputs/flutter-apk/app-release.apk

# Startup time
./scripts/measure_startup.sh

# Memory & performance
flutter run --profile
# Open DevTools
```

**View in Firebase:**
```
Firebase Console → Performance → App start trace
```

**CI Status:**
```
GitHub PR → Checks → Flutter CI → Check APK size budget
```
