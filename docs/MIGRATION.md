# Migration Guide: Old Structure → Professional Skeleton

This document maps the old repository structure to the new professional skeleton and provides step-by-step instructions for rebuilding the project.

## Overview

This refactoring transforms the Sierra Painting repository from an ad-hoc structure into a production-ready, scalable architecture with:
- **Clear separation of concerns** (data/domain/presentation layers)
- **Comprehensive documentation** with file headers explaining purpose, contracts, and invariants
- **Security-by-default** posture (deny-by-default rules, no client writes to payment fields)
- **Offline-first** architecture with explicit sync state
- **Observability** hooks (structured logging, analytics stubs, performance traces)

## File Mapping: Old → New

### Root Configuration Files

| Old | New | Change |
|-----|-----|--------|
| `.gitignore` | `.gitignore` | Enhanced with more patterns |
| N/A | `.gitattributes` | **NEW**: Union merge for .md and .gitignore |
| N/A | `.editorconfig` | **NEW**: Consistent code style |
| `firebase.json` | `firebase.json` | Kept (verified emulators config) |
| `.firebaserc` | `.firebaserc` | Enhanced with staging/prod aliases |
| `firestore.rules` | `firestore.rules` | Enhanced with more comments |
| `firestore.indexes.json` | `firestore.indexes.json` | Enhanced with collection-group indexes |
| `storage.rules` | `storage.rules` | Enhanced with comments |
| `pubspec.yaml` | `pubspec.yaml` | Kept (all deps already present) |
| `analysis_options.yaml` | `analysis_options.yaml` | Kept |

### Documentation

| Old | New | Change |
|-----|-----|--------|
| `README.md` | `README.md` | **REWRITTEN**: Task-based quickstart |
| `docs/KickoffTicket.md` | `docs/KickoffTicket.md` | **UPDATED**: Reflects new skeleton |
| `ARCHITECTURE.md` | `docs/Architecture.md` | **MOVED & UPDATED**: More detailed |
| N/A | `docs/MIGRATION.md` | **NEW**: This file |
| N/A | `docs/ADRs/0001-tech-stack.md` | **NEW**: Tech stack rationale |
| `docs/APP_CHECK.md` | `docs/APP_CHECK.md` | Kept |
| `docs/EMULATORS.md` | `docs/EMULATORS.md` | Kept |
| `QUICKSTART.md` | **DELETED** | Merged into README.md |
| `PROJECT_SUMMARY.md` | **DELETED** | Replaced by MIGRATION.md |
| `IMPLEMENTATION_SUMMARY.md` | **DELETED** | Obsolete after refactor |
| `VALIDATION_CHECKLIST.md` | **DELETED** | Replaced by PR checklist |
| `VERIFICATION_REPORT.md` | **DELETED** | Obsolete after refactor |
| `CHANGELOG.md` | `CHANGELOG.md` | Kept |
| `CONTRIBUTING.md` | `CONTRIBUTING.md` | Kept |
| `SETUP.md` | **DELETED** | Merged into README.md |

### GitHub Configuration

| Old | New | Change |
|-----|-----|--------|
| `.github/workflows/*.yml` | `.github/workflows/ci.yml` | **CONSOLIDATED**: Single CI workflow |
| `.github/PULL_REQUEST_TEMPLATE.md` | `.github/PULL_REQUEST_TEMPLATE.md` | Kept |
| N/A | `.github/ISSUE_TEMPLATE/story.md` | **NEW**: User story template |
| N/A | `.github/ISSUE_TEMPLATE/bug.md` | **NEW**: Bug report template |
| N/A | `.github/ISSUE_TEMPLATE/tech-task.md` | **NEW**: Tech task template |

### Cloud Functions

| Old Path | New Path | Change |
|----------|----------|--------|
| `functions/src/index.ts` | `functions/src/index.ts` | **UPDATED**: Wiring only, imports from lib/ |
| `functions/src/schemas/index.ts` | `functions/src/lib/zodSchemas.ts` | **MOVED & RENAMED** |
| `functions/src/services/pdf-service.ts` | `functions/src/pdf/createEstimatePdf.ts` | **RESTRUCTURED** |
| `functions/src/stripe/webhookHandler.ts` | `functions/src/payments/stripeWebhook.ts` | **MOVED** |
| N/A | `functions/src/lib/audit.ts` | **NEW**: Audit log helpers |
| N/A | `functions/src/lib/idempotency.ts` | **NEW**: Idempotency helpers |
| N/A | `functions/src/lib/stripe.ts` | **NEW**: Optional Stripe helpers |
| N/A | `functions/src/leads/createLead.ts` | **NEW**: Lead creation callable |
| N/A | `functions/src/payments/markPaidManual.ts` | **NEW**: Manual payment function |
| N/A | `functions/src/payments/createCheckoutSession.ts` | **NEW**: Stripe checkout (optional) |
| N/A | `functions/src/tests/rules.spec.ts` | **NEW**: Rules tests stub |
| N/A | `functions/src/tests/payments.spec.ts` | **NEW**: Payment tests stub |

### Flutter App (lib/)

#### Core

| Old Path | New Path | Change |
|----------|----------|--------|
| `lib/main.dart` | `lib/main.dart` | **UPDATED**: Enhanced headers |
| `lib/app/app.dart` | `lib/app/app.dart` | **UPDATED**: Enhanced headers |
| `lib/app/router.dart` | `lib/app/router.dart` | **UPDATED**: RBAC guards, detailed comments |
| N/A | `lib/app/theme.dart` | **NEW**: Extracted from config |
| `lib/firebase_options.dart` | `lib/firebase_options.dart` | Kept (generated) |
| `lib/core/config/firebase_options.dart` | **DELETED** | Duplicate, use root-level |
| `lib/core/config/theme_config.dart` | **DELETED** | Moved to app/theme.dart |
| `lib/core/models/queue_item.dart` | `lib/core/models/queue_item.dart` | **UPDATED**: Enhanced headers |
| `lib/core/providers/auth_provider.dart` | `lib/core/services/auth_service.dart` | **RENAMED & RESTRUCTURED** |
| `lib/core/providers/firestore_provider.dart` | `lib/core/services/firestore_service.dart` | **RENAMED & RESTRUCTURED** |
| `lib/core/services/feature_flag_service.dart` | `lib/core/services/feature_flag_service.dart` | **UPDATED**: Enhanced headers |
| `lib/core/services/offline_service.dart` | `lib/core/services/storage_service.dart` | **RENAMED** |
| `lib/core/services/queue_service.dart` | `lib/core/services/offline_queue_service.dart` | **RENAMED & ENHANCED** |
| N/A | `lib/core/services/app_check_service.dart` | **NEW**: App Check service |
| N/A | `lib/core/telemetry/telemetry_service.dart` | **NEW**: Analytics + logging |
| N/A | `lib/core/utils/result.dart` | **NEW**: Error handling types |

#### Features

Each feature now has complete data/domain/presentation structure with file headers:

| Old Path | New Path | Change |
|----------|----------|--------|
| `lib/features/auth/presentation/login_screen.dart` | `lib/features/auth/presentation/login_screen.dart` | **ENHANCED**: Headers, a11y notes |
| N/A | `lib/features/auth/data/auth_repository.dart` | **NEW**: Auth repository |
| N/A | `lib/features/auth/domain/user.dart` | **NEW**: User model |
| N/A | `lib/features/auth/domain/role.dart` | **NEW**: Role enum |
| `lib/features/timeclock/presentation/timeclock_screen.dart` | `lib/features/timeclock/presentation/timeclock_screen.dart` | **ENHANCED** |
| N/A | `lib/features/timeclock/data/timeclock_repository.dart` | **NEW** |
| N/A | `lib/features/timeclock/domain/time_entry.dart` | **NEW** |
| `lib/features/estimates/presentation/estimates_screen.dart` | `lib/features/estimates/presentation/estimates_screen.dart` | **ENHANCED** |
| N/A | `lib/features/estimates/data/estimate_repository.dart` | **NEW** |
| N/A | `lib/features/estimates/domain/estimate.dart` | **NEW** |
| N/A | `lib/features/estimates/domain/line_item.dart` | **NEW** |
| `lib/features/invoices/presentation/invoices_screen.dart` | `lib/features/invoices/presentation/invoices_screen.dart` | **ENHANCED** |
| N/A | `lib/features/invoices/data/invoice_repository.dart` | **NEW** |
| N/A | `lib/features/invoices/domain/invoice.dart` | **NEW** |
| `lib/features/admin/presentation/admin_screen.dart` | `lib/features/admin/presentation/admin_screen.dart` | **ENHANCED** |
| N/A | `lib/features/website/presentation/lead_form.dart` | **NEW**: Lead form placeholder |
| N/A | `lib/widgets/` | **NEW**: Shared widgets directory |

## Deleted Files and Rationale

### Documentation (Consolidated/Obsolete)
- `QUICKSTART.md` → Merged into README.md for single-entry experience
- `PROJECT_SUMMARY.md` → Replaced by MIGRATION.md (this file)
- `IMPLEMENTATION_SUMMARY.md` → Obsolete; new structure is documented in Architecture.md
- `VALIDATION_CHECKLIST.md` → Replaced by DoD in issue templates and PR checklist
- `VERIFICATION_REPORT.md` → Obsolete; CI workflow validates
- `SETUP.md` → Merged into README.md

### Code (Reorganized)
- `lib/core/config/firebase_options.dart` → Duplicate; use root `lib/firebase_options.dart`
- `lib/core/config/theme_config.dart` → Moved to `lib/app/theme.dart`
- Multiple workflow files → Consolidated into single `ci.yml` with matrix builds

## Rebuild Steps

### 1. Install Dependencies

```bash
# Flutter dependencies
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

# Cloud Functions dependencies
cd functions
npm ci
cd ..
```

### 2. Firebase Configuration

```bash
# If not configured, run:
# flutterfire configure

# Verify firebase projects
firebase projects:list

# Set up aliases (if using staging/prod)
firebase use --add
```

### 3. Start Emulators

```bash
# Start all emulators
firebase emulators:start

# In another terminal, run the app
flutter run
```

### 4. Run Tests

```bash
# Flutter tests
flutter test

# Cloud Functions tests
cd functions
npm test
cd ..

# Security rules tests (requires emulators running)
cd functions
npm run test:rules
cd ..
```

### 5. Build

```bash
# Flutter analyze
flutter analyze

# Functions build
cd functions
npm run build
cd ..
```

## Key Architectural Changes

### 1. **File Headers Required**
Every file now has a header comment explaining:
- **Purpose**: What this file does
- **Responsibilities**: Key functions/classes
- **Public API**: Exported interfaces
- **Invariants**: Constraints that must hold
- **Performance**: Considerations for scale
- **Security**: Auth/authz notes
- **TODOs**: Implementation notes

### 2. **Offline-First with Explicit Sync State**
- All user-impacting writes go through `offline_queue_service.dart`
- UI shows "Pending Sync" badges for queued operations
- Automatic reconciliation when online

### 3. **Security-by-Default**
- Firestore rules deny by default
- Clients cannot set `invoice.paid` or `invoice.paidAt`
- App Check enforced on callable functions
- Audit logging for all payment operations

### 4. **Payment Posture**
- **Primary**: Manual check/cash (admin "mark paid" + audit)
- **Optional**: Stripe Checkout behind `payments.stripeEnabled` flag
- Stripe webhook validates signature + idempotency

### 5. **Observability**
- Structured logs: `{ entity, action, actor, orgId, timestamp, ... }`
- Analytics events stubbed with clear naming
- Performance traces for critical operations
- Crashlytics for error reporting

### 6. **Accessibility**
- WCAG 2.2 AA compliance
- 48x48 minimum touch targets
- Semantic labels on all interactive elements
- Text scaling support (up to 130%)

## Feature Flags

Configure in Firebase Remote Config:

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `payments.stripeEnabled` | boolean | `false` | Enable Stripe payments |
| `features.pdfGeneration` | boolean | `true` | Enable server-side PDF generation |
| `features.offlineMode` | boolean | `true` | Enable offline queue |

## Environment Variables

### Cloud Functions (.env - not committed)

```bash
# Stripe (optional, only if payments.stripeEnabled = true)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Other service credentials
# (Use Secret Manager in production)
```

### Flutter (no secrets in repo)

- App Check debug tokens in `.env.debug` (gitignored)
- Firebase config in `lib/firebase_options.dart` (generated by flutterfire CLI)

## Breaking Changes

### For Developers
1. **Import paths changed**: `lib/core/providers/*` → `lib/core/services/*`
2. **Theme config moved**: `lib/core/config/theme_config.dart` → `lib/app/theme.dart`
3. **Function structure**: Old `functions/src/schemas/` → `functions/src/lib/zodSchemas.ts`

### For Users
- **No breaking changes**: This is a code reorganization, not a feature change

## Rollback Plan

If issues arise:
```bash
git checkout main
flutter pub get
cd functions && npm ci && cd ..
firebase emulators:start
```

## Validation Checklist

After migration, verify:
- [ ] `flutter analyze` passes with no errors
- [ ] `cd functions && npm run lint` passes
- [ ] `cd functions && npm run build` succeeds
- [ ] `firebase emulators:start` starts all emulators
- [ ] `flutter run` connects to emulators
- [ ] Basic user flow works (Auth → Dashboard)
- [ ] All documentation links are valid
- [ ] No secrets in repository (`git log --all --source --full-history -S "sk_live_"`)

## Support

For questions or issues with migration:
1. Check `docs/Architecture.md` for design decisions
2. Review file headers for implementation notes
3. Open an issue using `.github/ISSUE_TEMPLATE/tech-task.md`
