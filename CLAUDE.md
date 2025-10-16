# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Sierra Painting is a Flutter (mobile + web) application with Firebase backend for professional painting services management. This is a multi-tenant SaaS application with company-scoped data isolation enforced at the Firestore security rules level.

**Tech Stack:**
- Frontend: Flutter (Material 3) + Riverpod state management + GoRouter
- Backend: Firebase (Auth, Firestore, Cloud Functions in TypeScript, Storage)
- Local Storage: Hive (offline-first queue)
- Security: App Check (staging/prod), deny-by-default Firestore rules with custom claims RBAC
- Observability: Firebase Analytics, Performance Monitoring, Crashlytics

## Common Development Commands

### Flutter App

```bash
# Run web (most common for development)
flutter run -d chrome

# Run Android
flutter run -d emulator-5554

# Run with emulators (local backend)
flutter run --dart-define=USE_EMULATOR=true

# Code quality (lint + format)
pwsh ./scripts/dev.ps1 fix
# Or manually:
flutter analyze
dart fix --apply
flutter format .

# Tests
flutter test --concurrency=1              # All tests
flutter test test/path/to/test.dart       # Single test file
flutter test --plain-name "test name"     # By name
flutter test integration_test -d <device> # Integration tests

# Build for production
flutter build web --release
flutter build apk --release
flutter build appbundle --release
```

### Cloud Functions

**CRITICAL:** Always use `--prefix functions` or `cd functions` when working with backend code.

```bash
# Build TypeScript (required after any TS changes)
npm --prefix functions run build

# Type checking without full build
npm --prefix functions run typecheck

# Lint
npm --prefix functions run lint
npm --prefix functions run lint:fix

# Tests
npm --prefix functions run test

# Local development with emulator
npm --prefix functions run dev
# OR
firebase emulators:start --only functions
```

### Firebase Emulators

```bash
# Start all emulators
firebase emulators:start

# Emulator UI: http://localhost:4500
# Firestore: localhost:8080
# Functions: localhost:5001
# Auth: localhost:9099
# Storage: localhost:9199

# Seed test data
dart run tools/seed_fixtures.dart
```

### Deployment

```bash
# Build steps (required before deploy)
npm run predeploy:web        # flutter build web --release
npm run predeploy:functions  # npm --prefix functions run build

# Deploy
firebase deploy                     # All
firebase deploy --only functions    # Functions only
firebase deploy --only firestore:rules  # Rules only
firebase deploy --only hosting      # Web hosting only

# Firestore indexes
firebase deploy --only firestore:indexes
```

## Architecture Patterns

### Multi-Tenant Data Isolation

**CRITICAL:** All company-scoped data MUST include `companyId` field and follow the security model:

```
Firestore structure:
companies/{companyId}/
  ├── projects/{projectId}
  ├── jobs/{jobId}
  ├── estimates/{estimateId}
  ├── invoices/{invoiceId}
  ├── employees/{employeeId}
  └── ...

Security:
- Read: Any authenticated user in that company (via custom claim)
- Create/Update: Role-based (admin/manager/staff) + company match
- Custom claims: role, companyId (set via Cloud Functions)
```

**Firestore Rules Pattern:**
- Deny by default
- `authed()` - user is authenticated
- `isCompany(companyId)` - user's companyId claim matches path
- `hasAnyRole(["admin", "manager"])` - role-based checks
- `isOwner(uid)` - user owns the document

### Authentication & Authorization

**Provider hierarchy:**
```dart
firebaseAuthProvider → authStateProvider → currentUserProvider
                    ↓
              userClaimsProvider (auto-refreshes if claims missing)
                    ↓
         userRoleProvider + userCompanyProvider
```

**Custom Claims:**
- `role`: "admin", "manager", "staff", "worker"
- `companyId`: Company/organization ID
- Claims are set server-side via Cloud Functions
- `userClaimsProvider` auto-refreshes token ONCE if claims are missing

**RBAC in Routes:**
- `/admin` - redirects non-admins to `/timeclock`
- Router watches `authStateProvider` for reactive redirects
- Unauthenticated users → `/login`
- Authenticated users on `/login` → `/timeclock`

### Feature Structure (Vertical Slices)

Each feature follows clean architecture in `lib/features/<feature_name>/`:

```
feature_name/
├── domain/           # Business entities & logic (no framework deps)
│   └── model.dart    # Domain models with toFirestore/fromFirestore
├── data/             # Data layer (repositories, services)
│   └── repository.dart
└── presentation/     # UI layer (screens, widgets)
    ├── screen.dart
    └── widgets/
```

**Key Features:**
- `auth/` - Authentication (login, signup)
- `timeclock/` - Worker time tracking with GPS
- `jobs/` - Job management
- `estimates/` - Quote generation
- `invoices/` - Invoice management with workflow (draft → sent → paid_cash)
- `employees/` - Employee management with phone onboarding
- `admin/` - Admin dashboard

### State Management (Riverpod)

**Global providers in `lib/core/providers/`:**
- `auth_provider.dart` - Auth state, user claims, token refresh
- `firestore_provider.dart` - Firestore instance
- `providers.dart` - Central export of all providers

**Feature-specific providers:**
- Colocated with features in their directories
- Use `ref.watch()` for reactive dependencies
- Use `ref.read()` for one-time reads in callbacks

**Common pattern:**
```dart
final dataProvider = StreamProvider<List<Item>>((ref) {
  final companyId = ref.watch(userCompanyProvider);
  if (companyId == null) return Stream.value([]);

  return ref.watch(firestoreProvider)
    .collection('companies/$companyId/items')
    .snapshots()
    .map((snap) => snap.docs.map(Item.fromFirestore).toList());
});
```

### Cloud Functions Architecture

**Two schema systems (transitional state):**

1. **`src/schemas/index.ts`** - Lightweight, PRD-aligned schemas
   - Used by: Main entry point (`src/index.ts`)
   - Pattern: ≤10 lines, strict validation, no `.passthrough()`
   - Example: `TimeInSchema`, `ManualPaymentSchema`

2. **`src/lib/zodSchemas.ts`** - Comprehensive schemas with documentation
   - Used by: Individual function modules in domain folders
   - Pattern: Full validation, extended properties
   - Example: `InvoiceSchema`, `LeadSchema`

**IMPORTANT:** Schema property naming differs between the two:
- `schemas/index.ts`: `method`, `reference`, `note`
- `lib/zodSchemas.ts`: `paymentMethod`, `checkNumber`, `notes`

**Always match properties to the schema you're importing from.**

See `functions/SCHEMA_ARCHITECTURE.md` for complete details.

**Function types:**
- HTTP: `healthCheck`, `createLead`
- Callable: `markPaymentPaid` (admin-only)
- Triggers: `onUserCreate`, `onUserDelete`

### App Check Integration

**Environment-based:**
- Local/test: `ENABLE_APP_CHECK=false` (in `.env`)
- Staging/prod: `ENABLE_APP_CHECK=true`
- Web: ReCAPTCHA v3 (key in `RECAPTCHA_V3_SITE_KEY`)
- Mobile: Debug tokens (expire every 7 days)

**Test mode detection:**
```dart
--dart-define=FLUTTER_TEST=true  // Skips App Check, Crashlytics, Performance
```

### Offline-First Queue

**Pattern:**
```
User Action
  ↓
Optimistic UI Update
  ↓
Save to Hive Cache
  ↓
Enqueue for Sync
  ↓
Online? → Sync to Firestore → Update Cache → Confirm UI
Offline? → Keep in Queue → Auto-sync on reconnect
```

**Services:**
- `OfflineService` - Queue management
- `QueueService` - Deferred operations
- `SyncStatusChip` - UI feedback widget

### Performance Monitoring

**Traces:**
- `app_boot` - App startup to first frame
- `login_screen_load`, `timeclock_screen_load` - Screen loads
- Enabled in release mode only
- Skipped when `FLUTTER_TEST=true`

**PerformanceMonitor:**
```dart
final trace = monitor.startTrace('operation_name');
// ... operation ...
monitor.stopTrace(trace.name);
```

## Important Conventions

### When Adding New Features

1. Create feature directory: `lib/features/<name>/`
2. Follow domain/data/presentation structure
3. Add domain models with `toFirestore()` and `fromFirestore()` methods
4. Create Riverpod providers for data access
5. Add routes in `lib/app/router.dart` with appropriate guards
6. Write tests in `test/features/<name>/`

### When Adding Cloud Functions

1. Create function in appropriate domain folder under `functions/src/`
2. Import correct schema (see SCHEMA_ARCHITECTURE.md)
3. Export from `functions/src/index.ts`
4. Add endpoint config in `firebase.json` if HTTP function
5. **CRITICAL:** Run `npm --prefix functions run build` before testing
6. Add tests in `functions/src/__tests__/` or domain folder tests

### When Modifying Firestore Rules

1. Edit `firestore.rules`
2. Test rules: `npm run test:rules` (from root)
3. Deploy: `firebase deploy --only firestore:rules`
4. **NEVER** bypass company-scoped security checks
5. **ALWAYS** test with multiple companies to verify isolation

### When Working with Invoices

**Invoice workflow:**
```
draft → sent → paid_cash (manual payment)
              ↓
           overdue (computed: sent + past dueDate)
```

**Required fields (as of recent update):**
- `customerName` - Friendly display name (not just ID)
- `number` - Auto-generated format: `INV-YYYYMM-####`
- `subtotal` - Sum before tax
- `tax` - Tax amount
- `amount` - Total (subtotal + tax)

**Backwards compatibility:**
- Models include fallbacks for old documents missing new fields
- Status enum includes legacy `pending` and `paid` states

### When Running Tests

**Flutter tests:**
- Use `--concurrency=1` to avoid port conflicts with emulators
- Test harness in `test/helpers/test_harness.dart` for Firebase mocks
- Widget tests should be runnable on web and mobile

**Functions tests:**
- Jest-based in `functions/src/**/__tests__/`
- Security rules tests: `tests/rules/` (Vitest)
- Always run `npm --prefix functions run build` before testing changes

### Git Workflow

**Commit conventions:**
- Conventional commits enforced by Commitlint
- Husky pre-commit hooks run automatically
- CI runs on push to main/staging/production branches

**Branches:**
- `main` → production
- `staging` → staging environment
- Feature branches → create PR to main

## Critical Notes

### Schema Import Gotchas

**DON'T:**
```typescript
// index.ts using wrong schema source
import { TimeInSchema } from "./lib/zodSchemas"; // ERROR: doesn't exist
```

**DO:**
```typescript
// index.ts using correct source
import { TimeInSchema } from "./schemas";

// Domain function using correct source
import { ManualPaymentSchema } from "../lib/zodSchemas";
```

### Security Best Practices

- **NEVER** set sensitive fields client-side (e.g., `invoice.paid`, `paidAt`)
- **ALWAYS** validate company ownership in Cloud Functions
- **NEVER** commit `.env` files with secrets
- **ALWAYS** use service account JSON for CI (set `GOOGLE_APPLICATION_CREDENTIALS`)

### Performance Best Practices

- Use `ListView.builder` (not `ListView`) for long lists
- Implement pagination for large collections
- Cache Firestore reads where appropriate
- Use indexes for complex queries (defined in `firestore.indexes.json`)
- Lazy load images with `CachedImage` widget

### Web vs Mobile Differences

- **Crashlytics:** Mobile only (not web)
- **App Check:** ReCAPTCHA v3 (web), Debug tokens (mobile)
- **Performance monitoring:** Different trace names for platform-specific ops
- Ensure cross-platform testing for shared components

## Documentation References

- **Architecture:** `PAST WORK/docs/ARCHITECTURE.md` - Full architecture overview
- **Schema Guide:** `functions/SCHEMA_ARCHITECTURE.md` - Cloud Functions schemas
- **Copilot Rules:** `.github/copilot-instructions.md` - Project-specific conventions
- **Firebase Config:** `firebase.json` - Hosting, functions, emulator configuration
- **Firestore Rules:** `firestore.rules` - Security rules with inline comments
- **Instructions:** `instructions.yaml` - Project goals and validation steps
