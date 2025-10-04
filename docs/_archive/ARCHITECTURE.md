# Architecture Overview

## Technology Stack

- **Framework**: Flutter 3.8+
- **Language**: Dart 3.8+
- **State Management**: Riverpod 3.0+
- **Backend**: Firebase (Auth, Firestore, Cloud Functions, Storage)
- **Routing**: GoRouter 16.2+
- **Local Storage**: Hive 2.2+ (offline-first architecture)

## Project Structure

```
lib/
├── main.dart                    # Application entry point, Firebase initialization
├── firebase_options.dart        # Generated Firebase configuration
├── app/                         # App-level configuration
│   ├── app.dart                 # MaterialApp setup with theme
│   ├── router.dart              # GoRouter configuration with RBAC
│   └── theme.dart               # Legacy theme (consider consolidating)
├── core/                        # Shared infrastructure
│   ├── models/                  # Data models (QueueItem, etc.)
│   ├── network/                 # API client with retry logic
│   ├── providers/               # Riverpod providers (auth, Firestore)
│   ├── services/                # Business services
│   │   ├── haptic_service.dart  # Haptic feedback service
│   │   ├── offline_service.dart # Offline storage (Hive)
│   │   ├── queue_service.dart   # Offline queue management
│   │   └── feature_flag_service.dart # Firebase Remote Config
│   ├── telemetry/               # Observability services
│   ├── utils/                   # Utility functions
│   └── widgets/                 # Shared UI components
├── design/                      # Design system
│   ├── design.dart              # Barrel export for design system
│   ├── tokens.dart              # Design tokens (colors, spacing, etc.)
│   ├── theme.dart               # Material 3 theme configuration
│   └── components/              # Reusable UI components
│       ├── app_button.dart
│       ├── app_input.dart
│       ├── app_card.dart
│       └── ...
└── features/                    # Feature modules (feature-first structure)
    ├── auth/
    │   └── presentation/
    │       └── login_screen.dart
    ├── timeclock/
    │   ├── data/                # Data layer (repositories)
    │   ├── domain/              # Business logic
    │   └── presentation/        # UI layer
    ├── invoices/
    ├── estimates/
    ├── settings/
    └── admin/
```

## Architecture Principles

### 1. Feature-First Organization

Each feature is self-contained with its own data, domain, and presentation layers following Clean Architecture principles.

### 2. Dependency Injection via Riverpod

All services and providers are defined using Riverpod providers and injected where needed:

```dart
// Define provider
final hapticServiceProvider = Provider<HapticService>((ref) {
  return HapticService(ref);
});

// Use in widgets
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haptics = ref.read(hapticServiceProvider);
    // Use service
  }
}
```

### 3. Import Conventions

- **Cross-feature imports**: Always use `package:sierra_painting/...` syntax
- **Intra-feature imports**: Can use relative imports within the same feature
- **No deep relative imports**: Avoid `../../../` patterns

**Example:**
```dart
// ✅ Good - package import
import 'package:sierra_painting/core/services/haptic_service.dart';

// ❌ Bad - deep relative import
import '../../../core/services/haptic_service.dart';
```

### 4. Offline-First Architecture

The app implements an offline queue system:

1. User actions are immediately queued locally (Hive)
2. Queue items sync to Firebase when connectivity is available
3. UI optimistically updates before confirmation
4. Sync status is visible via `SyncStatusChip` widget

### 5. Provider Naming Conventions

Following ADR-0004 guidelines:

- **Data providers**: `xxxProvider` (e.g., `invoicesProvider`)
- **Controllers**: `xxxControllerProvider` (e.g., `invoiceControllerProvider`)
- **Services**: `xxxServiceProvider` (e.g., `hapticServiceProvider`)
- **Repositories**: `xxxRepositoryProvider` (e.g., `invoiceRepositoryProvider`)

## State Management

### Riverpod Providers

The app uses Riverpod for all state management:

- **Provider**: For immutable services/dependencies
- **StateProvider**: For simple mutable state
- **FutureProvider**: For async data that doesn't change
- **StreamProvider**: For real-time Firebase streams
- **StateNotifierProvider**: For complex state with business logic

### Main Providers

Located in `lib/core/providers/`:

- `firebaseAuthProvider` - Firebase Auth instance
- `currentUserProvider` - Current authenticated user
- `firestoreProvider` - Firestore instance
- `hapticServiceProvider` - Haptic feedback service
- `hapticEnabledProvider` - Haptic on/off state

## Firebase Integration

### Initialization Order (main.dart)

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `Firebase.initializeApp()` with platform-specific options
3. Firebase App Check (security layer)
4. Firebase Performance Monitoring
5. Firebase Crashlytics
6. Offline storage (Hive)
7. Feature flags (Remote Config)
8. Run app with `ProviderScope`

### Firebase Services Used

- **Authentication**: Email/password, role-based access
- **Firestore**: Primary database for invoices, estimates, time entries
- **Cloud Functions**: Server-side business logic, Stripe integration
- **Storage**: File/photo uploads
- **Remote Config**: Feature flags for gradual rollout
- **Performance**: Monitoring app performance
- **Crashlytics**: Error tracking and crash reporting
- **Analytics**: User behavior tracking

## Design System

The design system is centralized in `lib/design/`:

### Design Tokens

Defined in `tokens.dart`:
- Colors: `DesignTokens.primaryBlue`, `DesignTokens.successGreen`, etc.
- Spacing: `DesignTokens.spaceSM`, `DesignTokens.spaceMD`, etc.
- Border radius, font sizes, shadows, etc.

### Components

All components follow Material 3 guidelines:
- `AppButton` - Primary/secondary buttons with loading states
- `AppInput` - Text fields with validation
- `AppCard` - Content containers
- `AppBadge` - Status indicators
- `AppSkeleton` - Loading skeletons
- `AppEmpty` - Empty state displays

### Usage

```dart
import 'package:sierra_painting/design/design.dart';

// All design tokens and components are available
const padding = DesignTokens.spaceLG;
AppButton(label: 'Save', onPressed: () {});
```

## Testing Strategy

### Unit Tests

Located in `test/core/`:
- Service tests (e.g., `haptic_service_test.dart`)
- Utility tests (e.g., `result_test.dart`)
- Network tests (e.g., `api_client_test.dart`)

### Widget Tests

Located in `test/` feature directories:
- Screen tests for critical flows
- Component tests for reusable widgets

### Integration Tests

Located in `integration_test/`:
- End-to-end user flows
- Auth, clock-in, payment flows

### Coverage Goals

- Core services: ≥ 80%
- Repositories: ≥ 80%
- Widgets: ≥ 60%
- Overall: ≥ 70%

## Security Considerations

1. **Firebase App Check**: Protects backend from abuse
2. **Firestore Security Rules**: Server-side authorization
3. **RBAC**: Role-based access control via GoRouter guards
4. **Secrets Management**: No credentials in source code
5. **Input Validation**: Zod schemas in Cloud Functions

## Performance Optimizations

1. **Const constructors**: Used throughout for build performance
2. **Cached network images**: Via `cached_network_image` package
3. **Pagination**: Large lists use `PaginatedListView`
4. **Lazy loading**: Features load on-demand
5. **Firebase indexing**: Optimized Firestore queries

## Monitoring & Observability

- **Firebase Performance**: Tracks app startup, screen transitions
- **Firebase Crashlytics**: Crash reporting with stack traces
- **Firebase Analytics**: User behavior and funnel tracking
- **Custom traces**: Performance monitoring for critical operations

## Deployment

The app follows trunk-based development with feature flags:

1. Develop on feature branches
2. Merge to `main` via pull requests
3. CI validates formatting, analysis, tests, build
4. Features gated behind Remote Config flags
5. Gradual rollout via flag percentages
6. Emergency kill switches available

## References

- [ADR-0004: Riverpod State Management](docs/ADRs/0004-riverpod-state-management.md)
- [ADR-012: Sprint-Based Feature Flags](docs/adrs/012-sprint-based-flags.md)
- [AUDIT_SUMMARY.md](docs/AUDIT_SUMMARY.md) - Comprehensive code audit
- [GOVERNANCE.md](docs/GOVERNANCE.md) - Development standards
- [ONBOARDING.md](docs/ONBOARDING.md) - Developer setup guide
