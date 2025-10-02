# Migration Guide: Enterprise-Grade Skeleton Refactor

> **Project:** Sierra Painting  
> **Scope:** Old Structure → Professional Skeleton  
> **Type:** Non-breaking additive refactor (primarily documentation, structure, placeholders)

---

## Overview

This refactor upgrades the repository from a working prototype to an enterprise-grade skeleton with:

- Comprehensive documentation and ADRs
- Clean Architecture (data / domain / presentation)
- Security-by-default (deny-by-default rules, RBAC, App Check)
- Offline-first strategy with explicit sync state
- Observability hooks and CI/CD consolidation
- Function signatures and headers (no implementations changed unless noted)

**Migration Type:** **Non-Breaking Additive Changes** — We add structure, docs, and placeholders without removing existing functionality. Some files move/rename for clarity.

---

## Repository Structure: Before → After

### Root Level Files

**Before**
/
├── README.md
├── ARCHITECTURE.md
├── CHANGELOG.md
├── CONTRIBUTING.md
├── QUICKSTART.md
├── SETUP.md
├── VALIDATION_CHECKLIST.md
├── VERIFICATION_REPORT.md
├── PROJECT_SUMMARY.md
├── IMPLEMENTATION_SUMMARY.md
├── .gitignore
├── firebase.json
├── .firebaserc
├── firestore.rules
├── firestore.indexes.json
├── storage.rules
├── analysis_options.yaml
├── pubspec.yaml
└── pubspec.lock

markdown
Copy code

**After**
/
├── README.md # ✨ Enhanced: Quickstart, emulators, flags, golden paths
├── .gitignore # Kept (may include new patterns)
├── .gitattributes # 🆕 Normalize LF + union merges for .md/.gitignore
├── .editorconfig # 🆕 Consistent editor settings
├── firebase.json # ✨ Enhanced: Emulator config
├── .firebaserc # Kept (staging/prod aliases supported)
├── firestore.rules # ✨ Enhanced: Comments, org scoping, deny-by-default
├── firestore.indexes.json # ✨ Enhanced: Required composite indexes
├── storage.rules # ✨ Enhanced: Signed URL notes
├── analysis_options.yaml # Kept
├── pubspec.yaml # Kept
├── pubspec.lock # Kept
└── LICENSE # Kept

yaml
Copy code

**Rationale:** Modern dev standards (.editorconfig, .gitattributes), improved docs and emulator support.

---

### Documentation Directory

**Before**
docs/
├── KickoffTicket.md
├── APP_CHECK.md
├── EMULATORS.md
└── index.md

markdown
Copy code

**After**
docs/
├── KickoffTicket.md # ✨ Enhanced: Google-style epic
├── Architecture.md # 🆕 Comprehensive architecture overview
├── Backlog.md # 🆕 Kanban table with story IDs
├── EnhancementsAndAdvice.md # 🆕 Senior review + risk register
├── MIGRATION.md # 🆕 This file
├── ADRs/
│ └── 0001-tech-stack.md # 🆕 Flutter + Firebase rationale
├── APP_CHECK.md # Kept
├── EMULATORS.md # Kept
└── index.md # Kept

yaml
Copy code

**Rationale:** ADRs for decision history; single-source README; clear backlog.

---

### GitHub Configuration

**Before**
.github/
├── workflows/
│ ├── ci.yml
│ ├── functions-ci.yml
│ ├── flutter-ci.yml
│ ├── deploy-staging.yml
│ ├── deploy-production.yml
│ ├── security.yml
│ └── .yml
└── PULL_REQUEST_TEMPLATE.md

markdown
Copy code

**After**
.github/
├── ISSUE_TEMPLATE/
│ ├── story.md # 🆕 User story template
│ ├── bug.md # 🆕 Bug report template
│ └── tech-task.md # 🆕 Technical task template
├── workflows/
│ └── ci.yml # ✨ Consolidated pipeline (Flutter + Functions + deploy)
└── PULL_REQUEST_TEMPLATE.md # Kept

yaml
Copy code

**Rationale:** Standardize issues; consolidate CI with emulator support, staged deploys.

**Destructive Changes:** Remove redundant workflows; fold into single `ci.yml`.

---

### Cloud Functions

**Before**
functions/
├── src/
│ ├── index.ts
│ ├── schemas/index.ts
│ ├── services/pdf-service.ts
│ └── stripe/webhookHandler.ts
├── package.json
├── tsconfig.json
└── .eslintrc.json

markdown
Copy code

**After**
functions/
├── src/
│ ├── index.ts # ✨ Exports wiring only
│ ├── lib/ # 🆕 Shared utilities
│ │ ├── zodSchemas.ts # 🆕 Validation schemas
│ │ ├── audit.ts # 🆕 Audit trail helpers
│ │ ├── idempotency.ts # 🆕 Idempotency helpers
│ │ └── stripe.ts # 🆕 Stripe helpers (optional)
│ ├── leads/
│ │ └── createLead.ts # 🆕 App Check & captcha validation (signature)
│ ├── pdf/
│ │ └── createEstimatePdf.ts # 🆕 HTML→PDF→Storage (signature)
│ ├── payments/
│ │ ├── markPaidManual.ts # 🆕 Admin-only callable (signature)
│ │ ├── createCheckoutSession.ts # 🆕 Optional Stripe (signature)
│ │ └── stripeWebhook.ts # 🆕 Optional webhook (signature)
│ └── tests/
│ ├── rules.spec.ts # 🆕 Firestore rules tests (stub)
│ └── payments.spec.ts # 🆕 Payment tests (stub)
├── package.json
├── tsconfig.json
└── .eslintrc.json

markdown
Copy code

**Rationale:** Domain-based layout; signatures + doc comments; shared libs; test stubs.

**Destructive Moves:**
- `schemas/index.ts` → `lib/zodSchemas.ts`
- `services/pdf-service.ts` → `pdf/createEstimatePdf.ts`
- `stripe/webhookHandler.ts` → `payments/stripeWebhook.ts`

---

### Flutter App Structure

**Before**
lib/
├── main.dart
├── firebase_options.dart
├── app/
│ ├── app.dart
│ └── router.dart
├── core/
│ ├── config/
│ │ ├── firebase_options.dart
│ │ └── theme_config.dart
│ ├── models/queue_item.dart
│ ├── providers/
│ │ ├── auth_provider.dart
│ │ └── firestore_provider.dart
│ └── services/
│ ├── feature_flag_service.dart
│ ├── offline_service.dart
│ └── queue_service.dart
└── features/
├── auth/presentation/login_screen.dart
├── timeclock/presentation/timeclock_screen.dart
├── estimates/presentation/estimates_screen.dart
├── invoices/presentation/invoices_screen.dart
└── admin/presentation/admin_screen.dart

markdown
Copy code

**After**
lib/
├── main.dart # ✨ Header comments
├── firebase_options.dart # Kept (generated)
├── app/
│ ├── app.dart # ✨ Material 3 tokens
│ ├── router.dart # ✨ RBAC guards, error boundaries
│ └── theme.dart # 🆕 Theme configuration
├── core/
│ ├── services/ # ✨ API signatures
│ │ ├── auth_service.dart # 🆕 Auth API
│ │ ├── firestore_service.dart # 🆕 Firestore API
│ │ ├── storage_service.dart # 🆕 Storage API
│ │ ├── offline_queue_service.dart # ✨ Renamed from queue_service.dart
│ │ ├── feature_flag_service.dart # ✨ Expanded flags
│ │ └── telemetry_service.dart # 🆕 Analytics & logs API
│ ├── utils/result.dart # 🆕 Result/Either type
│ ├── models/queue_item.dart # Enhanced headers
│ └── providers/
│ ├── auth_provider.dart # Kept
│ └── firestore_provider.dart # Kept
└── features/
├── auth/ (data/domain/presentation) # 🆕 Repositories, entities, usecases
├── timeclock/ (data/domain/presentation)
├── estimates/ (data/domain/presentation)
├── invoices/ (data/domain/presentation)
├── admin/ (data/domain/presentation)
└── website/presentation/lead_form_screen.dart # 🆕 Public lead form

markdown
Copy code

**Rationale:** Clean Architecture, service abstractions, explicit result types, telemetry hooks.

**Destructive Rename:** `queue_service.dart` → `offline_queue_service.dart`.

---

## Detailed Change Log

### Files Added (New)
| File | Purpose |
|------|---------|
| `.editorconfig` | Consistent code formatting |
| `.gitattributes` | LF normalization + union merges |
| `docs/Backlog.md` | Product backlog (Kanban) |
| `docs/Architecture.md` | Architecture reference |
| `docs/EnhancementsAndAdvice.md` | Senior review + risks |
| `docs/MIGRATION.md` | This migration guide |
| `docs/ADRs/0001-tech-stack.md` | Tech stack ADR |
| `.github/ISSUE_TEMPLATE/*` | Story, Bug, Tech Task templates |
| `functions/src/lib/*` | Shared utilities (zod, audit, idempotency, stripe) |
| `functions/src/{leads,pdf,payments}/*` | Domain function stubs/signatures |
| `functions/src/tests/*` | Test stubs |
| `lib/app/theme.dart` | App theming |
| `lib/core/services/*.dart` | Service APIs |
| `lib/core/utils/result.dart` | Result/Either type |
| `lib/features/*/{data,domain,presentation}` | Clean Architecture stubs |
| `lib/features/website/*` | Public lead form placeholder |

### Files Modified (Enhanced)
| File | Changes |
|------|---------|
| `README.md` | Quickstart, emulator guide, flags, golden paths |
| `docs/KickoffTicket.md` | Up-leveled epic format |
| `firebase.json` | Added emulator config |
| `firestore.rules` | Org-scoping, deny-by-default, comments |
| `firestore.indexes.json` | Required composite indexes |
| `storage.rules` | Signed URL comments |
| `.github/workflows/ci.yml` | Consolidated jobs, emulator support |
| App files (`main.dart`, `app.dart`, `router.dart`) | Headers, guards, errors |

### Files Removed (Consolidated/Obsolete)
| File | Reason | Migration |
|------|--------|-----------|
| `QUICKSTART.md` | Merged into README | N/A |
| `SETUP.md` | Merged into README | N/A |
| `VALIDATION_CHECKLIST.md` | Replaced by PR/Issue templates | N/A |
| `VERIFICATION_REPORT.md` | CI/CD supersedes | N/A |
| `PROJECT_SUMMARY.md` | Replaced by `docs/Architecture.md` | N/A |
| `IMPLEMENTATION_SUMMARY.md` | Superseded by MIGRATION.md | N/A |
| Multiple `.github/workflows/*.yml` | Consolidated into `ci.yml` | N/A |
| `functions/src/schemas/index.ts` | Moved | `lib/zodSchemas.ts` |
| `functions/src/services/pdf-service.ts` | Moved | `pdf/createEstimatePdf.ts` |
| `functions/src/stripe/webhookHandler.ts` | Moved | `payments/stripeWebhook.ts` |

---

## Import Path Updates

**Functions (TypeScript)**
```ts
// Old
import {schemas} from './schemas';
import {generatePdf} from './services/pdf-service';
import {handleStripeWebhook} from './stripe/webhookHandler';

// New
import {schemas} from './lib/zodSchemas';
import {createEstimatePdf} from './pdf/createEstimatePdf';
import {stripeWebhook} from './payments/stripeWebhook';
Flutter (Dart)

dart
Copy code
// Old
import 'package:sierra_painting/core/services/queue_service.dart';

// New
import 'package:sierra_painting/core/services/offline_queue_service.dart';
Rebuild Steps
Prerequisites
bash
Copy code
flutter --version       # >= 3.10.0
node --version          # >= 18.0.0
firebase --version      # >= 12.0.0
1) Create Backup Branch
bash
Copy code
git checkout main
git checkout -b backup/pre-refactor
git push origin backup/pre-refactor
2) Merge the Refactor Branch
bash
Copy code
git checkout main
git merge refactor/sierra-skeleton
3) Reinstall Dependencies
bash
Copy code
# Flutter
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

# Functions
cd functions
npm ci
cd ..
4) Analyze, Build, and Test
bash
Copy code
# Flutter
flutter analyze
flutter test

# Functions
cd functions
npm run lint
npm run typecheck
npm run build
cd ..
5) Start Emulators
bash
Copy code
firebase emulators:start
Verify:

Auth: 9099 | Firestore: 8080 | Functions: 5001 | Storage: 9199 | UI: 4000

6) Run the App
bash
Copy code
flutter run
Check:

Login & nav work

Offline queue shows pending/synced states

Feature flags load as expected

7) Deploy to Staging
bash
Copy code
firebase deploy --only firestore:rules,storage:rules --project staging
firebase deploy --only functions --project staging
Rollback Plan
Option 1: Revert Merge

bash
Copy code
git revert -m 1 <merge-commit-hash>
git push origin main
Option 2: Restore From Backup

bash
Copy code
git checkout backup/pre-refactor
git checkout -b main-restored
git push origin main-restored -f
Option 3: Cherry-Pick File(s)

bash
Copy code
git checkout backup/pre-refactor -- path/to/file.dart
git commit -m "Restore file from pre-refactor"
git push origin main
Key Architectural Changes
File Headers Required in all code files:

Purpose, responsibilities, public API, invariants, performance, security, TODOs

Offline-First with Explicit Sync State

All writes via offline_queue_service.dart; UI shows “Pending Sync” badges; auto reconcile on reconnect

Security-by-Default

Deny-by-default Firestore rules; client cannot set invoice.paid/paidAt; App Check on callables; audit logging for payments

Payment Posture

Primary: Manual check/cash (markPaidManual)

Optional: Stripe Checkout behind Remote Config (payments.stripeEnabled)

Observability

Structured logs {entity, action, actor, orgId, ts}; analytics events; performance traces; Crashlytics

Feature Flags (Remote Config)
Flag	Type	Default	Description
payments.stripeEnabled	boolean	false	Toggle Stripe payments
features.pdfGeneration	boolean	true	Enable server-side PDF generation
features.offlineMode	boolean	true	Enable offline queue & sync

Environment Variables
Cloud Functions (.env or Secret Manager)

bash
Copy code
# Stripe (optional)
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
Flutter (no secrets committed)

App Check debug tokens in .env.debug (gitignored)

Firebase config in lib/firebase_options.dart (generated)

Breaking Changes
Developers

Import paths updated (see Import Path Updates)

Theme config moved to lib/app/theme.dart

Providers split from service APIs (clear separation)

Users

No breaking UX changes — refactor is internal.

Post-Migration Checklist
 CI/CD passing on PRs

 Emulators start successfully

 App builds & runs on Android and iOS

 Auth → Dashboard flow works

 RBAC guards working as intended

 Offline queue shows pending/sync states

 Feature flags pull correctly

 Functions deploy to staging

 Firestore & Storage rules deploy cleanly

 Issue templates render in GitHub

 ADRs readable and linked from README

Validation Checklist
 flutter analyze clean

 cd functions && npm run lint && npm run typecheck && npm run build

 firebase emulators:start all services up

 flutter run connects to emulators

 No secrets committed (git log --all --source --full-history -S "sk_live_")

Support
Check docs/Architecture.md for design decisions

Review file headers for contracts and invariants

Open a Tech Task using .github/ISSUE_TEMPLATE/tech-task.md

Summary
This refactor elevates Sierra Painting to an enterprise-grade codebase:

Documentation & ADRs ensure shared understanding

Clean Architecture improves testability and evolution

Security & Offline are first-class

CI/CD is streamlined and reliable

Most changes are additive; a few moves/renames are documented above. Follow the rebuild steps and validation checklists to complete the migration confidently.