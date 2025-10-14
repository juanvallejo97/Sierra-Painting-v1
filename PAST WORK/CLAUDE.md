# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

D'Sierra Painting is a Flutter application (web + Android) with Firebase backend for professional painting services management. The stack includes:

- **Frontend**: Flutter (Material 3) with Riverpod state management
- **Backend**: Firebase (Auth, Firestore, Cloud Functions, Storage)
- **Security**: App Check enforcement (staging/prod), Firestore rules
- **Observability**: Firebase Analytics, Performance Monitoring, Crashlytics (consent-gated)

## Development Commands

### Flutter App

**Run the app:**
```bash
# Web
flutter run -d chrome

# Android (with emulator running)
flutter run -d emulator-5554

# With Firebase emulators
flutter run --dart-define=USE_EMULATOR=true
```

**Testing:**
```bash
# All tests (run sequentially to avoid port conflicts)
flutter test --concurrency=1

# Single test file
flutter test test/path/to/test.dart

# Integration tests on Android
flutter test integration_test -d <device>

# Widget tests only
flutter test test/

# Run specific test by name
flutter test --plain-name "test name"
```

**Code quality:**
```bash
# Fix lint issues and format code
pwsh ./scripts/dev.ps1 fix

# Or manually:
flutter analyze
dart fix --apply
flutter format .
```

### Cloud Functions

**Working directory**: Always use `functions/` directory or `--prefix functions`

```bash
# Build TypeScript functions
npm --prefix functions run build

# Type check without building
npm --prefix functions run typecheck

# Lint
npm --prefix functions run lint
npm --prefix functions run lint:fix

# Test functions
npm --prefix functions run test

# Run functions emulator
npm --prefix functions run dev
# OR
firebase emulators:start --only functions
```

### Firebase Emulators

**Start all emulators:**
```bash
firebase emulators:start
```

**Emulator ports:**
- UI: http://localhost:4500
- Firestore: http://localhost:8080
- Functions: http://localhost:5001
- Auth: http://localhost:9099
- Storage: http://localhost:9199

**Seed test data:**
```bash
dart run tools/seed_fixtures.dart
```

### Testing & CI

**Run tests locally (Windows):**
```bash
pwsh ./scripts/run_tests_windows.ps1
```

**Functions build guard:**
```bash
pwsh ./scripts/ci_functions_guard.ps1
```

**Smoke tests:**
```bash
# Android smoke test
pwsh ./scripts/dev.ps1 smoke

# Web smoke test
npm run smoke:local
```

### Deployment

**Deploy functions:**
```bash
npm --prefix functions run predeploy  # Build first
firebase deploy --only functions
```

**Deploy to specific environment:**
```bash
# Canary deployment
./scripts/deploy_canary.sh

# Promote canary to production
./scripts/promote_canary.sh

# Rollback
./scripts/rollback.sh
```

**Full deployment (requires build):**
```bash
npm run predeploy:web    # flutter build web --release
npm run predeploy:functions
firebase deploy
```

## Architecture

### Frontend Structure

```
lib/
├── core/                          # Shared infrastructure
│   ├── providers/                 # Riverpod providers (auth, firestore)
│   ├── services/                  # Services (feature flags, offline, queue, haptics)
│   ├── telemetry/                 # Analytics, performance, error tracking
│   ├── privacy/                   # Consent management
│   ├── widgets/                   # Reusable widgets
│   └── utils/                     # Utilities, validators
├── features/                      # Feature modules
│   ├── auth/                      # Authentication (login, signup)
│   ├── admin/                     # Admin panel
│   ├── estimates/                 # Quote generation
│   ├── invoices/                  # Invoice management
│   ├── jobs/                      # Job tracking
│   ├── settings/                  # App settings
│   └── timeclock/                 # Time tracking
├── router.dart                    # Route definitions
└── main.dart                      # App entry point
```

### Backend Structure

```
functions/src/
├── config/                        # Configuration (deployment, env)
├── middleware/                    # Express middleware (app check, validation)
├── ops/                           # Operational tools (feature flags)
└── payments/                      # Stripe integration
```

### State Management

- **Riverpod** for state management
- Providers exported from `lib/core/providers.dart` for easy import
- Feature-specific providers in their respective feature directories

### Routing

- Uses `MaterialApp` with `onGenerateRoute` (lib/router.dart)
- Routes: `/`, `/login`, `/signup`, `/forgot`, `/dashboard`, `/settings/privacy`
- AnalyticsRouteObserver tracks navigation events

### Firebase Integration

**App Check:**
- Environment controlled: `.env` (local), `.env.staging`, `.env.production`
- `ENABLE_APP_CHECK=false` for local dev/tests
- `ENABLE_APP_CHECK=true` for staging/prod
- Debug tokens for development (see docs/APP_CHECK.md)
- Web uses ReCAPTCHA v3 (key in `RECAPTCHA_V3_SITE_KEY`)

**Environments:**
- Set via `--dart-define=USE_EMULATOR=true` for local emulators
- See `.firebaserc` for project configurations

**Performance monitoring:**
- `app_boot` trace tracks app initialization to first frame
- Enabled in release mode, skipped in tests (`FLUTTER_TEST=true`)

**Crashlytics:**
- Enabled on mobile (not web)
- Skipped in test mode
- User consent-gated

### Offline Support

- Hive for local storage (queue operations)
- Queue service for deferred operations
- Sync status tracking with `SyncStatusChip` widget

### Feature Flags

- Remote Config backed feature flags
- Providers in `lib/core/services/feature_flag_service.dart`
- Flags: `clockIn`, `clockOut`, `jobsToday`, `createQuote`, `markPaid`, `stripeCheckout`, `offlineMode`, `gpsTracking`

## Testing Patterns

### Test Mode Detection

Tests set `--dart-define=FLUTTER_TEST=true` to skip:
- App Check activation
- Crashlytics initialization
- Performance monitoring

### Widget Tests

- Use `WidgetTester` with `pumpWidget`
- Mock Firebase services using test harness in `test/helpers/test_harness.dart`
- Web parity tests ensure components work on both web and mobile

### Integration Tests

- Located in `integration_test/`
- Run on real devices/emulators
- Test end-to-end flows (auth, core flows, smoke tests)

### Functions Tests

- Jest-based tests in `functions/src/**/__tests__/`
- Use `@firebase/rules-unit-testing` for Firestore rules
- Run with `npm --prefix functions run test`

## Important Notes

### When Running Single Tests

Use absolute paths from project root:
```bash
flutter test test/smoke_login_test.dart
```

### When Editing Functions

**Always** run `npm --prefix functions run build` after TypeScript changes. The predeploy hook does this automatically, but manual testing requires it.

### When Working with App Check

- Debug tokens expire every 7 days
- Register in Firebase Console → App Check → Manage debug tokens
- See comprehensive guide in `docs/APP_CHECK.md`

### When Making Commits

- Husky pre-commit hooks run automatically
- Commitlint enforces conventional commits
- CI runs on push to main/staging/production branches

### Windows Development

This project supports Windows development:
- Use PowerShell scripts in `scripts/*.ps1`
- Main dev script: `pwsh ./scripts/dev.ps1 [web|android|fix|smoke]`

## Common Workflows

### Adding a New Feature

1. Create feature directory: `lib/features/feature_name/`
2. Add models, providers, views, controllers
3. Export providers from feature if needed
4. Add routes in `lib/router.dart`
5. Add tests in `test/features/feature_name/`

### Adding a Cloud Function

1. Create function in `functions/src/`
2. Export from `functions/src/index.ts`
3. Add endpoint config in `firebase.json` if HTTP function
4. Build: `npm --prefix functions run build`
5. Test with emulator: `firebase emulators:start --only functions`
6. Add tests in `functions/src/**/__tests__/`

### Updating Firestore Rules

1. Edit `firestore.rules`
2. Test: `./scripts/test-rules.sh`
3. Deploy: `firebase deploy --only firestore:rules`

### Debugging App Check Issues

1. Check logs for debug token
2. Register token in Firebase Console
3. Verify `ENABLE_APP_CHECK` environment variable
4. See rollback procedure in `docs/APP_CHECK.md` if needed

## Documentation

Key documentation files:
- `docs/architecture/overview.md` - Architecture summary
- `docs/APP_CHECK.md` - Comprehensive App Check guide
- `docs/EMULATORS.md` - Emulator setup and usage
- `docs/ops/CANARY_DEPLOYMENT.md` - Deployment strategies
- `docs/adr/` - Architectural decision records

## Deployment Strategy

- **main** branch → production
- **staging** branch → staging environment
- **Canary**: Use scripts in `scripts/deploy_canary.sh` for gradual rollout
- CI/CD via GitHub Actions (`.github/workflows/deploy.yml`)
