# Firebase Performance & Crashlytics Setup

> **Purpose**: Step-by-step guide to enable Firebase Performance Monitoring and Crashlytics
>
> **Last Updated**: 2024
>
> **Status**: Active

---

## Overview

This guide walks through enabling Firebase Performance Monitoring and Crashlytics for the Sierra Painting Flutter app.

**Prerequisites:**
- Firebase project already configured
- Flutter app connected to Firebase
- Admin access to Firebase Console

---

## Part 1: Firebase Performance Monitoring

### 1.1 Enable in Firebase Console

1. **Navigate to Performance**
   ```
   Firebase Console → Your Project → Performance
   ```

2. **Enable Performance Monitoring**
   - Click "Get Started"
   - Review data collection notice
   - Click "Enable Performance Monitoring"

3. **Verify SDK Integration**
   - SDKs already added in `pubspec.yaml`:
     ```yaml
     firebase_performance: ^0.10.0+9
     ```
   - Already integrated in `lib/main.dart`
   - Automatic traces enabled in release builds

### 1.2 Configure Performance Settings

**Default Trace Configuration:**
```dart
// lib/main.dart (already configured)
final performance = FirebasePerformance.instance;

if (kReleaseMode) {
  await performance.setPerformanceCollectionEnabled(true);
}
```

**Automatic Traces Collected:**
- ✅ App startup time
- ✅ Screen render times (via PerformanceMonitorMixin)
- ✅ Network requests (HTTP/HTTPS)
- ✅ Custom traces (manual)

### 1.3 Custom Trace Example

```dart
import 'package:firebase_performance/firebase_performance.dart';

Future<void> loadData() async {
  final trace = FirebasePerformance.instance.newTrace('load_data');
  await trace.start();
  
  try {
    // Your code
    final data = await fetchData();
    
    trace.putAttribute('status', 'success');
    trace.setMetric('items_count', data.length);
  } catch (e) {
    trace.putAttribute('status', 'error');
    trace.putAttribute('error', e.toString());
  } finally {
    await trace.stop();
  }
}
```

### 1.4 Screen Performance Tracking

**Already implemented** via `PerformanceMonitorMixin`:

```dart
// Use in any screen
class _MyScreenState extends State<MyScreen> with PerformanceMonitorMixin {
  @override
  String get screenName => 'my_screen';

  @override
  void initState() {
    super.initState();
    startScreenTrace(); // Automatic tracking
  }

  @override
  void dispose() {
    stopScreenTrace();
    super.dispose();
  }
}
```

### 1.5 View Performance Data

**Firebase Console:**
1. Navigate to Performance → Dashboard
2. View metrics:
   - App start time (P50, P90, P95)
   - Screen render times
   - Network requests
   - Custom traces

**Filter By:**
- App version
- Device type
- Network type (WiFi/cellular)
- Country
- Time range

---

## Part 2: Firebase Crashlytics

### 2.1 Enable in Firebase Console

1. **Navigate to Crashlytics**
   ```
   Firebase Console → Your Project → Crashlytics
   ```

2. **Enable Crashlytics**
   - Click "Get Started"
   - Follow setup wizard
   - Click "Enable Crashlytics"

### 2.2 Android Setup

1. **Update `android/app/build.gradle`:**
   ```gradle
   plugins {
       id 'com.android.application'
       id 'kotlin-android'
       id 'com.google.gms.google-services'
       id 'com.google.firebase.crashlytics' // Add this
   }
   
   dependencies {
       // ... existing dependencies
       implementation platform('com.google.firebase:firebase-bom:32.0.0')
       implementation 'com.google.firebase:firebase-crashlytics'
   }
   ```

2. **Update `android/build.gradle`:**
   ```gradle
   buildscript {
       dependencies {
           classpath 'com.google.gms:google-services:4.3.15'
           classpath 'com.google.firebase:firebase-crashlytics-gradle:2.9.9' // Add this
       }
   }
   ```

### 2.3 iOS Setup

1. **Crashlytics Auto-Enabled** via Firebase SDK
   - Already configured via `firebase_crashlytics` package
   - No additional setup needed for basic functionality

2. **Optional: Upload dSYM Files** (for symbolication)
   ```bash
   # In Xcode → Build Phases → Add Run Script
   "${PODS_ROOT}/FirebaseCrashlytics/run"
   ```

### 2.4 Crashlytics Integration

**Already configured** in `lib/main.dart`:

```dart
// Catch Flutter errors
FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

// Catch async errors
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  return true;
};
```

### 2.5 Manual Error Logging

**Log Non-Fatal Errors:**
```dart
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

try {
  // Risky operation
} catch (error, stackTrace) {
  // Log to Crashlytics
  await FirebaseCrashlytics.instance.recordError(
    error,
    stackTrace,
    reason: 'User action failed',
    fatal: false,
  );
  
  // Show user-friendly message
  showError('Operation failed');
}
```

**Add Custom Keys:**
```dart
// Add context for debugging
FirebaseCrashlytics.instance.setCustomKey('user_id', userId);
FirebaseCrashlytics.instance.setCustomKey('screen', 'jobs_list');
FirebaseCrashlytics.instance.setCustomKey('action', 'clock_in');
```

**Set User Identifier:**
```dart
// In auth flow after login
FirebaseCrashlytics.instance.setUserIdentifier(user.uid);
```

### 2.6 Test Crashlytics

**Force a test crash:**
```dart
// Add to debug menu or test button
ElevatedButton(
  onPressed: () {
    FirebaseCrashlytics.instance.crash(); // Only for testing!
  },
  child: const Text('Test Crash'),
)
```

**Verify in Console:**
1. Build and run app: `flutter run --release`
2. Trigger test crash
3. Wait 5-10 minutes
4. Check Firebase Console → Crashlytics

---

## Part 3: Testing & Verification

### 3.1 Performance Testing

**Build Release APK:**
```bash
flutter build apk --release
```

**Install on Device:**
```bash
flutter install --release
```

**Monitor Performance:**
1. Use app normally for 5-10 minutes
2. Navigate through different screens
3. Trigger network requests
4. Check Firebase Console → Performance (data appears in ~1 hour)

### 3.2 Crashlytics Testing

**Test Crash Reporting:**
```bash
# Build and install
flutter build apk --release
flutter install --release

# Use app and trigger crash
# Wait 5-10 minutes
# Check Firebase Console → Crashlytics
```

**Verify Issues Appear:**
- Issue count
- Stack trace
- Device info
- Custom keys

---

## Part 4: CI/CD Integration

### 4.1 Build Configuration

**Enable in CI:**
```yaml
# .github/workflows/ci.yml
- name: Build APK with Crashlytics
  run: flutter build apk --release
  env:
    FIREBASE_CRASHLYTICS_BUILD_ID: ${{ github.run_id }}
```

### 4.2 Symbolication

**Android ProGuard:**
```gradle
// android/app/build.gradle
buildTypes {
    release {
        minifyEnabled true
        proguardFiles getDefaultProguardFile('proguard-android.txt')
        
        // Upload mapping file to Crashlytics
        firebaseCrashlytics {
            mappingFileUploadEnabled true
        }
    }
}
```

---

## Part 5: Monitoring & Alerts

### 5.1 Performance Alerts

**Create Alert:**
1. Firebase Console → Performance → Dashboard
2. Click "Create Alert"
3. Configure:
   - Metric: App start time
   - Threshold: P90 > 2500ms
   - Notification: Email to team

**Recommended Alerts:**
- App start P90 > 2.5s
- Screen render P95 > 1s
- Network request P90 > 500ms

### 5.2 Crash Alerts

**Create Alert:**
1. Firebase Console → Crashlytics → Dashboard
2. Click bell icon → "Manage Alerts"
3. Configure:
   - New issue detected
   - Issue spike (>1% crash rate)
   - Notification: Email + Slack

**Alert Channels:**
- Email (always on)
- Slack (recommended)
- PagerDuty (for critical apps)

### 5.3 Dashboard Setup

**Key Metrics to Track:**
- Crash-free users (target: >99.5%)
- App start time (P50, P90, P95)
- Screen load times
- Network success rate
- Custom business metrics

---

## Part 6: Best Practices

### 6.1 Performance

**Do:**
- ✅ Use custom traces for critical operations
- ✅ Track screen load times
- ✅ Monitor network requests
- ✅ Set meaningful attribute names
- ✅ Track business metrics (checkout flow, etc.)

**Don't:**
- ❌ Create too many custom traces (overhead)
- ❌ Log sensitive data in attributes
- ❌ Use long trace names (>100 chars)
- ❌ Leave traces running indefinitely

### 6.2 Crashlytics

**Do:**
- ✅ Set user identifiers (for support)
- ✅ Add custom keys for context
- ✅ Log non-fatal errors
- ✅ Test crash reporting before launch
- ✅ Review crashes daily

**Don't:**
- ❌ Log PII in custom keys
- ❌ Ignore non-fatal errors
- ❌ Skip symbolication setup
- ❌ Disable in debug builds

### 6.3 Privacy

**Data Collected:**
- Device model, OS version
- App version, build number
- Network type (WiFi/cellular)
- Country (approximate)
- Performance metrics
- Crash stack traces

**Not Collected:**
- Personal information (unless logged)
- User content
- Precise location
- Health data

**Compliance:**
- Add to privacy policy
- Request user consent (if required by law)
- Disable for users who opt out

---

## Part 7: Troubleshooting

### 7.1 No Performance Data

**Check:**
- [ ] Performance enabled in Firebase Console
- [ ] App built in release mode
- [ ] Performance collection enabled in code
- [ ] Waited 1+ hour for data to appear
- [ ] App version uploaded to Play Store (for distribution)

**Solution:**
```bash
# Verify in release build
flutter build apk --release
flutter install --release
# Use app for 5+ minutes
```

### 7.2 No Crash Reports

**Check:**
- [ ] Crashlytics enabled in Firebase Console
- [ ] Gradle plugin added (Android)
- [ ] App restarted after crash
- [ ] Waited 5+ minutes
- [ ] Built in release mode

**Solution:**
```bash
# Force test crash
FirebaseCrashlytics.instance.crash();

# Build and install
flutter build apk --release
flutter install --release
```

### 7.3 Unsymbolicated Stack Traces

**Android:**
- Ensure ProGuard mapping uploaded
- Enable `mappingFileUploadEnabled`
- Check `build/outputs/mapping/` exists

**iOS:**
- Upload dSYM files
- Add upload script to Xcode
- Check bitcode settings

---

## Quick Start Checklist

- [ ] Enable Performance in Firebase Console
- [ ] Enable Crashlytics in Firebase Console
- [ ] Update Android Gradle files (Crashlytics plugin)
- [ ] Build release APK and test
- [ ] Verify data appears in console (1 hour delay)
- [ ] Set up alerts for critical metrics
- [ ] Add to monitoring dashboard
- [ ] Test crash reporting
- [ ] Document in privacy policy
- [ ] Train team on using dashboards

---

## Related Documentation

- [Performance Budgets](./PERFORMANCE_BUDGETS.md)
- [Implementation Summary](./IMPLEMENTATION_SUMMARY.md)
- [Firebase Performance Docs](https://firebase.google.com/docs/perf-mon)
- [Firebase Crashlytics Docs](https://firebase.google.com/docs/crashlytics)

---

## Support

**Firebase Console:**
```
https://console.firebase.google.com/project/[PROJECT-ID]
```

**Documentation:**
- Performance: https://firebase.google.com/docs/perf-mon
- Crashlytics: https://firebase.google.com/docs/crashlytics
- Flutter: https://firebase.google.com/docs/flutter/setup

**Issues:**
- GitHub: Open issue with `[Firebase]` prefix
- Stack Overflow: Tag `firebase-performance` or `firebase-crashlytics`
