# Sierra Painting

> A professional mobile-first painting business management application built with **Flutter** and **Firebase**.

**[View Architecture](docs/Architecture.md)** · **[Migration Guide](docs/MIGRATION.md)** · **[ADRs](docs/ADRs/)**

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
bash
Copy code
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
bash
Copy code
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
Copy code
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
bash
Copy code
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

bash
Copy code
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
🚢 Deployment
Staging (auto on merge to main)
CI runs tests, deploys Functions & Rules to staging

Manual staging:

bash
Copy code
firebase use staging
firebase deploy
Production (tag-based)
bash
Copy code
git tag -a v1.0.0 -m "Sprint V1 release"
git push origin v1.0.0
# GitHub Actions builds & deploys to production
CI config: .github/workflows/ci.yml

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

Follow CONTRIBUTING.md

Run tests & lint before PR:
flutter test && flutter analyze && (cd functions && npm test && npm run lint)

Open a PR using the template

🆘 Troubleshooting
Emulators won’t start

bash
Copy code
lsof -ti:4000,8080,9099,5001,9199 | xargs kill -9
firebase emulators:start --clean
Flutter build fails

bash
Copy code
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
Functions deploy fails

bash
Copy code
cd functions
rm -rf node_modules lib
npm ci
npm run build
firebase deploy --only functions
More help: docs/EMULATORS.md · docs/APP_CHECK.md

📄 License
Copyright © 2024 Sierra Painting