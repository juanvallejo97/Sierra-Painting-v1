# Sierra Painting

[![Staging CI/CD](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/staging.yml/badge.svg)](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/staging.yml)
[![Production CI/CD](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/production.yml/badge.svg)](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/production.yml)
[![Flutter CI](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/ci.yml/badge.svg)](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/ci.yml)

> A professional mobile-first painting business management application built with **Flutter** and **Firebase**.

**[View Architecture](docs/Architecture.md)** · **[Migration Guide](docs/MIGRATION.md)** · **[ADRs](docs/ADRs/)** · **[Code Audit](docs/AUDIT_SUMMARY.md)** · **[Governance](docs/GOVERNANCE.md)** · **[Performance](docs/PERFORMANCE_IMPLEMENTATION.md)**

---

## 🎯 Overview

Sierra Painting helps small painting businesses manage operations, projects, estimates/invoices, and payments efficiently. The project follows **story-driven development** with comprehensive documentation and best practices.

---

## ⚡ Quick Start

### Prerequisites
- **Flutter SDK** ≥ 3.8.0 — [Install](https://flutter.dev/docs/get-started/install)
- **Node.js** ≥ 18 — [Install](https://nodejs.org/)
- **Firebase CLI** — [Install](https://firebase.google.com/docs/cli#install_the_firebase_cli)
- **Git** and a code editor (VS Code recommended)

### 1) Clone & Install

```bash
# Clone the repository
git clone https://github.com/juanvallejo97/Sierra-Painting-v1.git
cd Sierra-Painting-v1

# Flutter deps
flutter pub get

# (Optional) Generate adapters, etc.
flutter pub run build_runner build --delete-conflicting-outputs

# Cloud Functions deps
cd functions
npm ci
cd ..
2) Firebase Setup
bash
Copy code
firebase login
firebase projects:list         # or create a project in the Firebase Console
firebase use --add             # select or add an alias (e.g., staging, prod)

# Generate Flutter firebase_options.dart
flutterfire configure
3) Start Dev Environment
# Terminal 1: Emulators
firebase emulators:start

# Terminal 2: Run the app (connects to emulators)
flutter run

# Optional: Watch for codegen
flutter pub run build_runner watch
Emulator UI: http://localhost:4000
Firestore: http://localhost:8080 · Auth: http://localhost:9099 · Functions: http://localhost:5001 · Storage: http://localhost:9199

🧭 Golden Paths
GP1: Auth & Time Tracking
Sign up (Auth emulator) → 2) Clock in/out (offline queue to Firestore) → 3) View today’s jobs & entries

GP2: Estimate → Invoice → Payment
Create estimate with line items → 2) Generate PDF (Cloud Function) → 3) Convert to invoice → 4) Mark paid (admin-only with audit trail)

GP3: Lead Capture → Schedule
Submit lead via web form (App Check + captcha) → 2) Admin reviews → 3) Schedule job (lite scheduler)

📚 Documentation
Architecture: docs/Architecture.md

Migration Guide: docs/MIGRATION.md

ADRs: docs/ADRs/

Feature Flags: docs/FEATURE_FLAGS.md

App Check Setup: docs/APP_CHECK.md

Emulators Guide: docs/EMULATORS.md

Developer Workflow: docs/DEVELOPER_WORKFLOW.md

UI/UX Overhaul: docs/ui_overhaul_mobile.md

Note: Older standalone setup/quickstart docs were consolidated into the README and docs above.

🏗️ Tech Stack
Layer	Technology	Purpose
Frontend	Flutter (Material 3)	Cross-platform mobile app
State	Riverpod	Reactive state & DI
Routing	go_router	Declarative navigation with RBAC guards
Offline	Hive	Local storage + sync queue
Backend	Firebase (Auth, Firestore, Storage, Functions)	Serverless backend
Functions	TypeScript + Zod	Type-safe serverless logic
Payments	Manual primary, Stripe optional	Check/cash + optional card payments
Security	App Check + Firestore Rules	Deny-by-default authorization
Observability	Crashlytics, Performance, Analytics	Monitoring & debugging

Why this stack? See ADR-0001.

🎯 Development Methodology
User Stories with BDD acceptance criteria (Given/When/Then)

Sprint Planning (V1, V2, V3, V4)

Feature Flags via Firebase Remote Config for progressive rollout

Idempotency for offline retries & webhooks

Audit Trail for sensitive operations

Observability with structured logs & performance traces

See ADR-011 (Story-Driven Development) for details.

📂 Project Structure
/
├── lib/                      # Flutter application
│   ├── app/                  # App bootstrap, theme, router (RBAC)
│   ├── core/                 # Services, models, utilities
│   │   ├── services/         # auth, firestore, storage, offline_queue, feature_flags
│   │   ├── telemetry/        # analytics, logging, crashlytics
│   │   └── utils/            # result types, helpers
│   ├── features/             # Feature modules (data/domain/presentation)
│   │   ├── auth/             # Login, sign-up, role checks
│   │   ├── timeclock/        # Clock in/out, jobs today
│   │   ├── estimates/        # Quote builder, PDF preview
│   │   ├── invoices/         # Invoice list, mark paid
│   │   ├── admin/            # Dashboard, schedule lite
│   │   └── website/          # Lead form (Flutter Web)
│   └── widgets/              # Shared UI components
├── functions/                # Cloud Functions (TypeScript + Zod)
│   ├── src/
│   │   ├── index.ts          # Export wiring
│   │   ├── lib/              # Shared (audit, idempotency, schemas)
│   │   ├── leads/            # createLead
│   │   ├── pdf/              # createEstimatePdf
│   │   ├── payments/         # markPaidManual, Stripe (optional)
│   │   └── tests/            # Rules & functions tests
├── docs/                     # Documentation
│   ├── Architecture.md
│   ├── MIGRATION.md
│   ├── FEATURE_FLAGS.md
│   ├── APP_CHECK.md
│   ├── EMULATORS.md
│   └── ADRs/
├── .github/
│   ├── workflows/            # CI/CD (analyze, test, deploy)
│   └── ISSUE_TEMPLATE/       # Story, bug, tech-task templates
├── firebase.json             # Emulators & hosting
├── firestore.rules           # Security rules (deny-by-default)
├── firestore.indexes.json    # Database indexes
└── storage.rules             # Storage rules
🛡️ Security
Firestore Rules (deny-by-default) — excerpt:

javascript

match /{document=**} {
  allow read, write: if false;
}

match /users/{userId} {
  allow read: if isOwner(userId) || isAdmin();
  allow update: if isOwner(userId) && !modifiesRole();
}

match /jobs/{jobId}/timeEntries/{entryId} {
  allow create: if isAuthenticated() && isOwnEntry();
  allow read: if isOwnEntry() || isAdmin();
  allow update, delete: if false; // Server-only
}
Principles

Deny-by-default; org-scoped explicit allows

Client cannot set invoice.paid / invoice.paidAt (server-only)

App Check enforced on callable functions

Audit logs for all payment operations

See Security Architecture.

🧪 Test, Lint & Analyze

# Flutter tests
flutter test

# Flutter analyze
flutter analyze

# Cloud Functions tests
cd functions
npm test
npm run test:rules       # requires emulators running
npm run lint
npm run typecheck
cd ..
Integration & E2E
bash
Copy code
# Emulators
firebase emulators:start

# Functions integration tests
cd functions
npm run test:integration
cd ..

# Flutter E2E
flutter test integration_test/
🧰 Environment Setup
App Check (Debug Mode)
Run flutter run to get the debug token in logs

Register it in Firebase Console → App Check → Debug tokens

(Optional) Save locally:

echo "APP_CHECK_DEBUG_TOKEN=your-token-here" > .env.debug
/.env.debug is gitignored.

Feature Flags (Remote Config)
Flag	Type	Default	Description
payments.stripeEnabled	boolean	false	Enable Stripe payments
features.pdfGeneration	boolean	true	Server-side PDF generation
features.offlineMode	boolean	true	Offline queue & sync

Example:

dart
Copy code
final clockInEnabled = ref.watch(clockInEnabledProvider);
return clockInEnabled ? const ClockInButton() : const ComingSoonBanner();
## 🚢 Deployment

### CI/CD Pipeline

Sierra Painting uses GitHub Actions for automated CI/CD with separate workflows for staging and production.

**Workflows:**
- **[Staging Pipeline](.github/workflows/staging.yml)** - Auto-deploys on push to `main`
- **[Production Pipeline](.github/workflows/production.yml)** - Deploys on version tags with manual approval
- **[CI Tests](.github/workflows/ci.yml)** - Runs on all PRs

**Pipeline Stages:**
1. **Setup** - Cache dependencies (Flutter, Node, Gradle)
2. **Lint & Test** - Flutter analyze + test, Functions lint + test
3. **Build Check** - Validate Flutter builds (APK for staging, release builds for production)
4. **Emulator Smoke** - Run smoke tests against Firebase emulators
5. **Deploy Indexes** - Deploy Firestore indexes
6. **Deploy Functions** - Deploy Cloud Functions with authentication
7. **Post Checks** - Print monitoring links and deployment status

### Staging Deployment (Automatic)

**Trigger:** Push to `main` branch

```bash
git checkout main
git pull origin main
git merge feature/my-feature
git push origin main

# GitHub Actions automatically:
# 1. Runs all tests
# 2. Builds Flutter app
# 3. Deploys to staging project
```

**Environment:** `sierra-painting-staging`

**Manual staging deploy:**
```bash
firebase use staging
firebase deploy
```

### Production Deployment (Manual Approval)

**Trigger:** Version tag push (e.g., `v1.0.0`)

```bash
# After staging validation
git tag -a v1.0.0 -m "Sprint V1 release"
git push origin v1.0.0

# GitHub Actions will:
# 1. Run all tests
# 2. Build release APK/AAB
# 3. Wait for manual approval (required)
# 4. Deploy to production after approval
# 5. Create GitHub Release
```

**Environment:** `sierra-painting-prod`

**Approval:** Required (configured in GitHub Environments)

### GitHub Environments Setup

**Required Configuration:**
- `staging` environment - No approval needed
- `production` environment - Requires 1 reviewer approval

**Secrets:**
- `FIREBASE_SERVICE_ACCOUNT` - Service account JSON for Firebase deployment

See [GitHub Environments Setup Guide](docs/ops/github-environments.md) for detailed configuration.

### Deployment Scripts

**Helper scripts available:**
- `scripts/ci/firebase-login.sh` - Validate Firebase authentication
- `scripts/smoke/run.sh` - Run emulator smoke tests
- `scripts/remote-config/manage-flags.sh` - Manage feature flags
- `scripts/rollback/rollback-functions.sh` - Emergency rollback

### Monitoring Post-Deployment

**Staging:**
- Firebase Console: https://console.firebase.google.com/project/sierra-painting-staging
- Cloud Functions Logs: https://console.cloud.google.com/logs/query?project=sierra-painting-staging

**Production:**
- Firebase Console: https://console.firebase.google.com/project/sierra-painting-prod
- Cloud Functions Logs: https://console.cloud.google.com/logs/query?project=sierra-painting-prod
- Crashlytics: Monitor for 24 hours post-deployment

See [Monitoring Guide](docs/ops/monitoring.md) for detailed monitoring procedures.

### Rollback Procedures

If issues are detected post-deployment:

1. **Feature Flag Rollback** (fastest):
   ```bash
   scripts/remote-config/manage-flags.sh disable FEATURE_FLAG --project production
   ```

2. **Code Rollback** (requires redeployment):
   ```bash
   # Checkout previous version
   git checkout v1.x.x
   
   # Deploy
   cd functions && npm ci && npm run build
   firebase deploy --only functions --project production
   ```

See [Rollback Procedures](docs/ui/ROLLBACK_PROCEDURES.md) for detailed rollback steps.

📊 Performance Targets
Operation	Target (P95)
Sign-in	≤ 2.5s
Clock-in (online)	≤ 2.5s
Jobs Today load	≤ 2.0s
Offline sync	≤ 5s per item
PDF generation	≤ 10s

Monitored via Firebase Performance & structured logs.

🧑‍💻 Contributing
Create a branch: git checkout -b feature/my-feature

Use issue templates in .github/ISSUE_TEMPLATE/

Follow these guidelines:
- Use conventional commit messages (feat:, fix:, docs:, etc.)
- Run tests & lint before PR:
  ```bash
  flutter test && flutter analyze && (cd functions && npm test && npm run lint)
  ```
- Do not include secrets in code or PRs
- Ensure CI passes before requesting review

Open a PR using the template

🆘 Troubleshooting
Emulators won’t start

lsof -ti:4000,8080,9099,5001,9199 | xargs kill -9
firebase emulators:start --clean
Flutter build fails

flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
Functions deploy fails

cd functions
rm -rf node_modules lib
npm ci
npm run build
firebase deploy --only functions
More help: docs/EMULATORS.md · docs/APP_CHECK.md

---

## ⚡ Performance & Optimization

Sierra Painting follows strict performance budgets and best practices:

**📊 Key Metrics:**
- Cold Start P90: < 2.0s
- APK Size: < 50MB (enforced in CI)
- Frame Rate: 60fps sustained
- Crash-free Rate: ≥ 99.5%

**🛠️ Tools & Infrastructure:**
- Firebase Performance Monitoring (automatic tracking)
- Firebase Crashlytics (error tracking)
- CI performance budgets (APK size checks)
- Pre-commit hooks (code quality)

**📚 Documentation:**
- [Performance Implementation Guide](docs/PERFORMANCE_IMPLEMENTATION.md) - Central guide
- [Performance Budgets](docs/PERFORMANCE_BUDGETS.md) - Metrics and targets
- [Backend Performance](docs/BACKEND_PERFORMANCE.md) - Cloud Functions optimization
- [Firebase Setup](docs/FIREBASE_SETUP.md) - Monitoring setup
- [Frontend Playbook](docs/perf-playbook-fe.md) - Best practices

**🚀 Quick Start:**
```bash
# Install pre-commit hooks
./scripts/install-hooks.sh

# Measure app startup
./scripts/measure_startup.sh

# Use optimized widgets
import 'package:sierra_painting/core/widgets/cached_image.dart';
import 'package:sierra_painting/core/widgets/paginated_list_view.dart';
```

---

📄 License
Copyright © 2024 Sierra Painting
