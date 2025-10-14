# Route Analytics Implementation Plan

**Purpose**: Track user navigation to debug routing issues and understand user flows
**Reference**: T-009 (P0-UI-002)
**Owner**: Frontend Team
**Last Updated**: 2025-10-13

---

## Overview

Implementing `NavigatorObserver` to log all route changes to Firebase Analytics. Currently `lib/main.dart:267` has `navigatorObservers: []` (empty list), preventing navigation tracking.

**Issue**: P0-UI-002 - Missing NavigatorObserver
**Impact**: Cannot track user navigation, impossible to debug routing issues
**Priority**: T+0 Quick Win (2h effort)
**Size**: S

---

## Current State

**File**: `lib/main.dart:267`
```dart
MaterialApp(
  title: 'Sierra Painting',
  theme: ThemeData(...),
  onGenerateRoute: AppRouter.generateRoute,
  navigatorObservers: [],  // ❌ EMPTY - No tracking
)
```

**Problems**:
- No visibility into user navigation patterns
- Cannot debug routing issues in production
- Missing data for UX improvements
- No analytics for screen views

---

## Proposed Solution

### Architecture

```
┌─────────────────────────────────────┐
│       MaterialApp                    │
│  navigatorObservers: [               │
│    AnalyticsRouteObserver()  ←─────┼─── NEW
│  ]                                  │
└─────────────────────────────────────┘
                ↓
    Every route change triggers:
    - didPush()    → Log "screen_view" event
    - didPop()     → Log "screen_exit" event
    - didReplace() → Log "screen_replace" event
                ↓
        Firebase Analytics
```

---

## Implementation Steps

### Step 1: Create AnalyticsRouteObserver Class

**File**: `lib/core/telemetry/analytics_route_observer.dart` (NEW)

```dart
import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Observes route changes and logs them to Firebase Analytics.
///
/// Usage:
/// ```dart
/// MaterialApp(
///   navigatorObservers: [AnalyticsRouteObserver()],
///   ...
/// )
/// ```
class AnalyticsRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logScreenView(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _logScreenView(newRoute);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _logScreenView(previousRoute, isReturn: true);
    }
  }

  /// Log screen view to Firebase Analytics
  void _logScreenView(Route<dynamic> route, {bool isReturn = false}) {
    // Only log named routes (skip dialogs, modal bottom sheets, etc.)
    if (route is! PageRoute) {
      return;
    }

    final String? screenName = route.settings.name;
    if (screenName == null || screenName.isEmpty) {
      debugPrint('[AnalyticsRouteObserver] Skipping unnamed route');
      return;
    }

    // Clean route name (remove leading slash, query params)
    final cleanName = _cleanRouteName(screenName);

    // Log to Firebase Analytics
    _analytics.logEvent(
      name: 'screen_view',
      parameters: {
        'screen_name': cleanName,
        'screen_class': route.runtimeType.toString(),
        'is_return': isReturn,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );

    debugPrint('[AnalyticsRouteObserver] Logged: $cleanName (return: $isReturn)');
  }

  /// Clean route name for analytics
  /// Examples:
  ///   /dashboard -> dashboard
  ///   /admin/users?id=123 -> admin_users
  String _cleanRouteName(String routeName) {
    // Remove leading slash
    String cleaned = routeName.startsWith('/') ? routeName.substring(1) : routeName;

    // Remove query parameters
    if (cleaned.contains('?')) {
      cleaned = cleaned.split('?').first;
    }

    // Replace slashes with underscores for consistency
    cleaned = cleaned.replaceAll('/', '_');

    // Handle empty (home route)
    if (cleaned.isEmpty) {
      cleaned = 'home';
    }

    return cleaned;
  }
}
```

---

### Step 2: Update main.dart

**File**: `lib/main.dart` (MODIFY)

**Before**:
```dart
MaterialApp(
  title: 'Sierra Painting',
  theme: themeData,
  onGenerateRoute: AppRouter.generateRoute,
  navigatorObservers: [],  // ❌ Empty
)
```

**After**:
```dart
import 'package:sierra_painting/core/telemetry/analytics_route_observer.dart';

MaterialApp(
  title: 'Sierra Painting',
  theme: themeData,
  onGenerateRoute: AppRouter.generateRoute,
  navigatorObservers: [
    AnalyticsRouteObserver(),  // ✅ Added
  ],
)
```

---

### Step 3: Ensure All Routes Are Named

**File**: `lib/router.dart` (VERIFY)

All routes should have explicit names:
```dart
static Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case '/':
      return MaterialPageRoute(
        builder: (_) => const HomeScreen(),
        settings: const RouteSettings(name: '/'),  // ✅ Named
      );

    case '/login':
      return MaterialPageRoute(
        builder: (_) => const LoginScreen(),
        settings: const RouteSettings(name: '/login'),  // ✅ Named
      );

    case '/dashboard':
      return MaterialPageRoute(
        builder: (_) => const DashboardScreen(),
        settings: const RouteSettings(name: '/dashboard'),  // ✅ Named
      );

    // ... more routes
  }
}
```

**Action**: Audit all routes to ensure `settings.name` is set.

---

### Step 4: Add Unit Tests

**File**: `test/core/telemetry/analytics_route_observer_test.dart` (NEW)

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:sierra_painting/core/telemetry/analytics_route_observer.dart';

@GenerateMocks([FirebaseAnalytics])
import 'analytics_route_observer_test.mocks.dart';

void main() {
  group('AnalyticsRouteObserver', () {
    late AnalyticsRouteObserver observer;
    late MockFirebaseAnalytics mockAnalytics;

    setUp(() {
      mockAnalytics = MockFirebaseAnalytics();
      observer = AnalyticsRouteObserver();
      // Inject mock (requires refactor to accept analytics instance)
    });

    test('logs screen_view on didPush', () {
      final route = MaterialPageRoute(
        builder: (_) => Container(),
        settings: const RouteSettings(name: '/dashboard'),
      );

      observer.didPush(route, null);

      // Verify logEvent called with correct parameters
      verify(mockAnalytics.logEvent(
        name: 'screen_view',
        parameters: argThat(contains('screen_name')),
      )).called(1);
    });

    test('cleans route names correctly', () {
      // Test route name cleaning logic
      expect(observer._cleanRouteName('/dashboard'), 'dashboard');
      expect(observer._cleanRouteName('/admin/users'), 'admin_users');
      expect(observer._cleanRouteName('/jobs?id=123'), 'jobs');
      expect(observer._cleanRouteName('/'), 'home');
    });

    test('skips unnamed routes', () {
      final route = MaterialPageRoute(
        builder: (_) => Container(),
        settings: const RouteSettings(name: null),
      );

      observer.didPush(route, null);

      // Verify logEvent NOT called
      verifyNever(mockAnalytics.logEvent(
        name: anyNamed('name'),
        parameters: anyNamed('parameters'),
      ));
    });
  });
}
```

**Action**: Implement tests after creating observer class.

---

### Step 5: Test in Development

#### Local Testing

```bash
# Run app with emulators
flutter run -d chrome

# Navigate through screens
# 1. Open app (/ route)
# 2. Navigate to /login
# 3. Navigate to /dashboard
# 4. Navigate back

# Check console output for log statements:
# [AnalyticsRouteObserver] Logged: home (return: false)
# [AnalyticsRouteObserver] Logged: login (return: false)
# [AnalyticsRouteObserver] Logged: dashboard (return: false)
# [AnalyticsRouteObserver] Logged: login (return: true)
```

#### Firebase Analytics DebugView

1. Enable debug mode on Android:
   ```bash
   adb shell setprop debug.firebase.analytics.app com.example.sierra_painting
   ```

2. Or web (Chrome DevTools console):
   ```javascript
   window['ga-disable-GA_MEASUREMENT_ID'] = false;
   ```

3. Navigate to Firebase Console → Analytics → DebugView
4. Verify `screen_view` events appear in real-time
5. Check event parameters:
   - `screen_name`: dashboard, login, etc.
   - `screen_class`: MaterialPageRoute
   - `is_return`: true/false
   - `timestamp`: ISO 8601

---

### Step 6: Validate in Staging

1. Deploy to staging:
   ```bash
   flutter build web --release
   firebase deploy --only hosting:staging
   ```

2. Open staging URL on mobile device
3. Navigate through critical paths:
   - Home → Login → Dashboard → Settings
   - Admin panel navigation
   - Back button presses
4. Check Firebase Analytics (24h delay for non-debug events):
   - Navigate to Analytics → Events → screen_view
   - Verify event counts match navigation patterns

---

## Analytics Event Schema

### Event Name
`screen_view` (Firebase Analytics standard event)

### Event Parameters

| Parameter | Type | Example | Description |
|-----------|------|---------|-------------|
| `screen_name` | String | `dashboard` | Route name (cleaned) |
| `screen_class` | String | `MaterialPageRoute` | Route class type |
| `is_return` | Boolean | `false` | True if navigating back |
| `timestamp` | String | `2025-10-13T10:30:00Z` | ISO 8601 timestamp |

### Additional Context (Automatic)
Firebase Analytics automatically adds:
- `user_id` (if set)
- `user_properties` (device, OS, app version)
- `session_id`
- `engagement_time_msec`

---

## Usage Examples

### Example 1: Track Screen Views
```dart
// No code changes needed!
// Just navigate normally:
Navigator.pushNamed(context, '/dashboard');
// → Automatically logs: screen_view(screen_name: dashboard)
```

### Example 2: Debug Routing Issues
1. User reports: "App stuck on loading screen"
2. Check Firebase Analytics → screen_view events
3. Filter by user_id → see last screen visited
4. Identify if user reached expected screen or stuck elsewhere

### Example 3: Analyze User Flows
1. Navigate to Firebase Analytics → Path Analysis
2. Select starting point: `/login`
3. View common paths:
   - `/login` → `/dashboard` (80% of users)
   - `/login` → `/forgot` → `/login` (15% of users)
   - `/login` → exit app (5% drop-off)

---

## Troubleshooting

### Events Not Appearing in DebugView

**Check:**
- [ ] Debug mode enabled (see Step 5 above)
- [ ] Firebase Analytics initialized in `main.dart`
- [ ] `google-services.json` (Android) or `GoogleService-Info.plist` (iOS) present
- [ ] Internet connection available (analytics batches events)

### Unnamed Routes

**Symptom**: Console shows "Skipping unnamed route"

**Fix**: Ensure all routes have explicit names:
```dart
MaterialPageRoute(
  builder: (_) => MyScreen(),
  settings: const RouteSettings(name: '/my-screen'),  // ← Add this
)
```

### Duplicate Events

**Symptom**: Each navigation logs 2 events

**Cause**: Multiple NavigatorObservers in stack

**Fix**: Verify only one `AnalyticsRouteObserver` in `navigatorObservers` list

---

## Performance Considerations

### Overhead
- **Negligible**: `logEvent()` is async and non-blocking
- **Batching**: Firebase Analytics batches events every ~1 minute
- **Offline**: Events cached locally, uploaded when online

### Privacy
- **PII**: Route names should NOT contain PII (user IDs, emails, etc.)
- **Sanitization**: Clean route names before logging (done in `_cleanRouteName`)
- **Consent**: Analytics respects user consent (already implemented via P0-COMP-006)

---

## Acceptance Criteria (T-009)

- [x] **Implementation plan created**: This document
- [ ] `AnalyticsRouteObserver` class created
- [ ] `AnalyticsRouteObserver` added to `MaterialApp.navigatorObservers`
- [ ] All routes have explicit names
- [ ] Unit tests added
- [ ] Tested in local dev (console logs visible)
- [ ] Tested in DebugView (events appear in real-time)
- [ ] Deployed to staging
- [ ] `screen_view` events visible in Firebase Analytics console

**Status**: 📋 Plan complete (awaiting implementation)

---

## Related Tasks

- **T-042**: Add Lighthouse CI budgets (performance)
- **T-027**: Gate telemetry behind user consent (P0-COMP-006)
- **T-020**: Structured error logging (same telemetry service)

---

## Future Enhancements (Post-MVP)

1. **Custom Events**: Track specific actions (button clicks, form submissions)
2. **User Properties**: Set custom properties (role: admin, plan: free)
3. **Conversion Funnels**: Track multi-step flows (signup, checkout)
4. **A/B Testing**: Use analytics for feature flag decisions
5. **Crash Correlation**: Link Crashlytics errors to screen_view events

---

## Action Items

**Immediate** (within 2h):
1. [ ] Create `lib/core/telemetry/analytics_route_observer.dart`
2. [ ] Update `lib/main.dart` to add observer
3. [ ] Audit `lib/router.dart` for unnamed routes
4. [ ] Test locally (console logs)

**Follow-up** (within 1 day):
1. [ ] Create unit tests for observer
2. [ ] Test in DebugView (real-time validation)
3. [ ] Deploy to staging
4. [ ] Monitor analytics for 24h

**Week 1**:
1. [ ] Review analytics data with team
2. [ ] Identify high-traffic screens
3. [ ] Document common user flows
4. [ ] Adjust screen naming conventions if needed

---

## References

- [Firebase Analytics DebugView](https://firebase.google.com/docs/analytics/debugview)
- [Flutter Navigator API](https://api.flutter.dev/flutter/widgets/Navigator-class.html)
- [RouteObserver Class](https://api.flutter.dev/flutter/widgets/RouteObserver-class.html)
- [Firebase screen_view Event](https://support.google.com/analytics/answer/9234069)

---

**Last Updated**: 2025-10-13
**Next Review**: After T-009 implementation
