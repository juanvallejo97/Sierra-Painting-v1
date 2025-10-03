# Route Map - Sierra Painting Flutter App

> **Purpose**: Complete mapping of all routes, navigation flows, and deep links in the Flutter application
>
> **Last Updated**: 2024
>
> **Status**: Current (v2.0.0-refactor)

---

## Overview

The Sierra Painting Flutter app uses `go_router` for declarative routing with role-based access control (RBAC). This document maps all routes, their guards, and navigation flows.

---

## Route Configuration

**Router Location**: `lib/app/router.dart`

**Router Provider**: `routerProvider` (Riverpod)

**Features**:
- Declarative routing with `GoRouter`
- Role-based access guards
- Deep link support
- Authentication state-based redirects
- Error handling with custom error screen

---

## Routes

### Public Routes

#### `/login`
- **Screen**: `LoginScreen`
- **File**: `lib/features/auth/presentation/login_screen.dart`
- **Purpose**: User authentication (sign-in/sign-up)
- **Auth Required**: No
- **Role Required**: None
- **Guards**: 
  - If already authenticated → redirect to `/timeclock`
- **Deep Link**: `sierrapainting://login`
- **Query Params**: None
- **Performance Target**: Screen render < 500ms
- **Feature Flag**: None

---

### Authenticated Routes

All routes below require authentication. Unauthenticated users are redirected to `/login`.

#### `/timeclock`
- **Screen**: `TimeclockScreen`
- **File**: `lib/features/timeclock/presentation/timeclock_screen.dart`
- **Purpose**: Clock in/out, view today's jobs, time entries
- **Auth Required**: Yes
- **Role Required**: Any (crew, crew_lead, admin)
- **Guards**:
  - Authentication check
- **Deep Link**: `sierrapainting://timeclock`
- **Query Params**: 
  - `jobId` (optional): Pre-select job for clock-in
- **Navigation From**:
  - Login (after successful sign-in)
  - Bottom navigation bar
  - Deep link (push notification)
- **Navigation To**:
  - `/estimates` (bottom nav)
  - `/invoices` (bottom nav)
  - `/admin` (bottom nav, if admin)
- **Performance Target**: 
  - Screen render < 500ms
  - Jobs list load < 2.0s (P95)
- **Feature Flags**:
  - `feature_b1_clock_in_enabled`: Show clock-in button
  - `feature_b2_clock_out_enabled`: Show clock-out button
  - `feature_b3_jobs_today_enabled`: Show jobs list
  - `gps_tracking_enabled`: Request GPS permission

---

#### `/estimates`
- **Screen**: `EstimatesScreen`
- **File**: `lib/features/estimates/presentation/estimates_screen.dart`
- **Purpose**: Create and manage customer estimates
- **Auth Required**: Yes
- **Role Required**: crew_lead, admin
- **Guards**:
  - Authentication check
  - Role check (TODO: implement proper guard)
- **Deep Link**: `sierrapainting://estimates`
- **Query Params**:
  - `estimateId` (optional): Open specific estimate
  - `action=create` (optional): Open create estimate form
- **Navigation From**:
  - Bottom navigation bar
  - `/invoices` (convert estimate to invoice)
- **Navigation To**:
  - `/timeclock` (bottom nav)
  - `/invoices` (bottom nav, convert to invoice)
  - `/admin` (bottom nav, if admin)
- **Performance Target**: 
  - Screen render < 500ms
  - Estimates list load < 2.0s (P95)
- **Feature Flags**:
  - `feature_c1_create_quote_enabled`: Show create button

---

#### `/invoices`
- **Screen**: `InvoicesScreen`
- **File**: `lib/features/invoices/presentation/invoices_screen.dart`
- **Purpose**: View and manage invoices, mark as paid
- **Auth Required**: Yes
- **Role Required**: crew_lead, admin (mark paid: admin only)
- **Guards**:
  - Authentication check
  - Role check for mark paid action
- **Deep Link**: `sierrapainting://invoices`
- **Query Params**:
  - `invoiceId` (optional): Open specific invoice
  - `action=markPaid` (optional): Open mark paid dialog
- **Navigation From**:
  - Bottom navigation bar
  - `/estimates` (after converting estimate)
  - Deep link (email notification)
- **Navigation To**:
  - `/timeclock` (bottom nav)
  - `/estimates` (bottom nav)
  - `/admin` (bottom nav, if admin)
- **Performance Target**: 
  - Screen render < 500ms
  - Invoices list load < 2.0s (P95)
- **Feature Flags**:
  - `feature_c3_mark_paid_enabled`: Show mark paid button
  - `feature_c5_stripe_checkout_enabled`: Show Stripe payment option

---

#### `/admin`
- **Screen**: `AdminScreen`
- **File**: `lib/features/admin/presentation/admin_screen.dart`
- **Purpose**: Admin dashboard, user management, audit logs
- **Auth Required**: Yes
- **Role Required**: admin
- **Guards**:
  - Authentication check
  - Admin role check → redirect to `/timeclock` if not admin
- **Deep Link**: `sierrapainting://admin`
- **Query Params**: None
- **Navigation From**:
  - Bottom navigation bar (admin only)
- **Navigation To**:
  - `/timeclock` (bottom nav)
  - `/estimates` (bottom nav)
  - `/invoices` (bottom nav)
- **Performance Target**: 
  - Screen render < 500ms
- **Feature Flags**: None

---

## Navigation Flow Diagram

```
┌──────────┐
│  /login  │ ← Initial route (if not authenticated)
└────┬─────┘
     │ Sign in
     ▼
┌──────────────┐
│  /timeclock  │ ← Default authenticated route
└──────┬───────┘
       │
       ├─────────────┐
       │             │
       ▼             ▼
┌─────────────┐  ┌──────────┐
│ /estimates  │  │ /invoices│
└─────────────┘  └──────────┘
       │             │
       └─────┬───────┘
             │
             ▼ (admin only)
       ┌──────────┐
       │  /admin  │
       └──────────┘
```

---

## Deep Link Configuration

### Android (`android/app/src/main/AndroidManifest.xml`)

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="sierrapainting" />
</intent-filter>
```

### iOS (`ios/Runner/Info.plist`)

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>sierrapainting</string>
    </array>
  </dict>
</array>
```

### Supported Deep Links

| Deep Link | Route | Auth Required | Notes |
|-----------|-------|---------------|-------|
| `sierrapainting://login` | `/login` | No | Direct to login |
| `sierrapainting://timeclock` | `/timeclock` | Yes | Direct to time clock |
| `sierrapainting://timeclock?jobId=123` | `/timeclock` | Yes | Pre-select job |
| `sierrapainting://estimates` | `/estimates` | Yes | Direct to estimates |
| `sierrapainting://estimates?estimateId=123` | `/estimates` | Yes | Open specific estimate |
| `sierrapainting://invoices` | `/invoices` | Yes | Direct to invoices |
| `sierrapainting://invoices?invoiceId=123` | `/invoices` | Yes | Open specific invoice |
| `sierrapainting://admin` | `/admin` | Yes (Admin) | Direct to admin panel |

**TODO**: Implement deep link handling in screens

---

## Navigation Guards

### Authentication Guard

**Location**: `lib/app/router.dart` - `redirect` callback

**Logic**:
```dart
if (!isLoggedIn && !isLoginRoute) {
  return '/login';
}
if (isLoggedIn && isLoginRoute) {
  return '/timeclock';
}
```

**Applied To**: All routes except `/login`

---

### Role-Based Guards

#### Admin Guard

**Location**: `lib/app/router.dart` - `/admin` route redirect

**Logic**:
```dart
redirect: (context, state) {
  final user = ref.read(authStateProvider).value;
  final isAdmin = user?.email?.contains('admin') ?? false;
  return isAdmin ? null : '/timeclock';
}
```

**Applied To**: `/admin` route

**TODO**: Implement proper role checking via Firestore user document

---

### Feature Flag Guards

**Location**: Individual screens

**Logic**: Check feature flag before showing UI elements

**Example**:
```dart
final clockInEnabled = ref.watch(clockInEnabledProvider);
if (clockInEnabled) {
  // Show clock-in button
}
```

**Applied To**: Feature-specific UI elements

---

## Error Handling

### Error Screen

**Location**: `lib/core/widgets/error_screen.dart`

**Displayed When**:
- Invalid route
- Navigation error
- Route guard failure

**Display**:
- Error message
- Requested path
- "Go Home" button → `/timeclock`

---

## Navigation Patterns

### Bottom Navigation

**Implementation**: `BottomNavigationBar` in each screen

**Routes**:
1. Timeclock (`/timeclock`)
2. Estimates (`/estimates`)
3. Invoices (`/invoices`)
4. Admin (`/admin`) - Only visible if admin

**State**: Managed by `GoRouter` - current route highlights active tab

**TODO**: Extract to shared widget for consistency

---

### Back Navigation

**Behavior**: 
- Android back button: Go back in history
- iOS swipe back: Go back in history
- App bar back button: Go back in history

**Special Cases**:
- `/timeclock` as root: Back button exits app (Android)
- Dialogs: Back button closes dialog

---

### Forward Navigation

**Methods**:
1. `context.go('/route')` - Replace current route
2. `context.push('/route')` - Push new route
3. `context.pushNamed('route')` - Push by name (TODO: implement named routes)

**Used For**:
- Tab navigation: `context.go()`
- Detail views: `context.push()`
- Deep links: `context.go()` with params

---

## Prefetching Strategy

### Current State
- No prefetching implemented

### Recommended Strategy

1. **User Profile Prefetch**
   - When: After login
   - What: User document, organization data
   - Where: `auth_provider.dart`

2. **Jobs List Prefetch**
   - When: On app start (if authenticated)
   - What: Today's jobs for time clock
   - Where: `timeclock_screen.dart` initState

3. **Navigation Intent Prefetch**
   - When: User hovers/touches tab (web/tablet)
   - What: Data for target screen
   - Where: Bottom navigation bar

**TODO**: Implement prefetching strategy

---

## Route Transitions

### Current
- Default Material page transitions

### Recommended
- Fade transition for tab switches
- Slide transition for detail views
- Modal transition for dialogs

**TODO**: Customize transitions via `pageBuilder`

---

## Performance Metrics

### Screen Render Times (Target)

| Screen | Target (P50) | Target (P95) |
|--------|-------------|--------------|
| `/login` | < 300ms | < 500ms |
| `/timeclock` | < 400ms | < 500ms |
| `/estimates` | < 400ms | < 500ms |
| `/invoices` | < 400ms | < 500ms |
| `/admin` | < 400ms | < 500ms |

### Navigation Times (Target)

| Action | Target |
|--------|--------|
| Tab switch | < 100ms |
| Detail view push | < 200ms |
| Back navigation | < 100ms |
| Deep link | < 500ms |

---

## Testing Requirements

### Route Tests

1. **Authentication Flow**
   - Unauthenticated user → redirected to `/login`
   - Authenticated user → redirected to `/timeclock`
   - Login success → navigate to `/timeclock`

2. **RBAC Tests**
   - Non-admin user → blocked from `/admin`
   - Admin user → access to `/admin`

3. **Deep Link Tests**
   - Valid deep link → navigate to route
   - Invalid deep link → error screen
   - Deep link with params → params passed correctly

4. **Navigation Tests**
   - Bottom nav → switches routes
   - Back button → goes back
   - Error route → shows error screen

**TODO**: Implement route tests in `test/app/router_test.dart`

---

## Migration & Compatibility

### Breaking Changes
- None (v2.0.0-refactor maintains route compatibility)

### Deprecated Routes
- None

### Future Routes
- `/profile` - User profile editing
- `/settings` - App settings
- `/jobs/:jobId` - Job details view
- `/estimates/:estimateId` - Estimate details
- `/invoices/:invoiceId` - Invoice details
- `/schedule` - Job scheduling (V3)
- `/reports` - Business reports (V4)

---

## Related Documentation

- [Architecture Overview](./Architecture.md)
- [RBAC Documentation](./Security.md)
- [Feature Flags](./FEATURE_FLAGS.md)
- [Router Implementation](../lib/app/router.dart)
