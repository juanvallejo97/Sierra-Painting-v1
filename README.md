# Sierra Painting

> A professional mobile-first painting business management application built with Flutter and Firebase.

**[View Architecture](docs/Architecture.md)** | **[Migration Guide](docs/MIGRATION.md)** | **[ADRs](docs/ADRs/)**

---

## Quick Start

### Prerequisites
- **Flutter SDK** ≥ 3.8.0 ([Install](https://flutter.dev/docs/get-started/install))
- **Node.js** ≥ 18 ([Install](https://nodejs.org/))
- **Firebase CLI** ([Install](https://firebase.google.com/docs/cli#install_the_firebase_cli))
- **Git** and a code editor (VS Code recommended)

### 1. Clone and Install

```bash
# Clone the repository
git clone https://github.com/juanvallejo97/Sierra-Painting-v1.git
cd Sierra-Painting-v1

# Install Flutter dependencies
flutter pub get

# Generate Hive adapters for offline storage
flutter pub run build_runner build --delete-conflicting-outputs

# Install Cloud Functions dependencies
cd functions
npm ci
cd ..
```

### 2. Firebase Setup

```bash
# Login to Firebase
firebase login

# List projects (or create one at console.firebase.google.com)
firebase projects:list

# Link to your Firebase project
firebase use --add

# Generate Flutter Firebase configuration
flutterfire configure
```

### 3. Start Development Environment

```bash
# Terminal 1: Start Firebase emulators
firebase emulators:start

# Terminal 2: Run Flutter app (it will connect to emulators)
flutter run

# Optional Terminal 3: Watch for Dart code generation
flutter pub run build_runner watch
```

**Emulator UI:** http://localhost:4000  
**Firestore Emulator:** http://localhost:8080  
**Auth Emulator:** http://localhost:9099

---

## What Can You Do?

### Golden Path 1: Authentication & Time Tracking
1. **Sign up** via the app (creates user in Auth emulator)
2. **Clock in/out** on a job (writes to Firestore with offline queue)
3. **View today's jobs** and time entries

### Golden Path 2: Estimate → Invoice → Payment
1. **Create an estimate** with line items
2. **Generate PDF** (server-side via Cloud Function)
3. **Convert to invoice** (mark as sent)
4. **Mark as paid** (admin only, with audit trail)

### Golden Path 3: Lead Capture → Schedule
1. **Submit a lead** via web form (validates App Check + captcha)
2. **Admin reviews** in dashboard
3. **Schedule job** with crew assignment (lite scheduler placeholder)

---

## Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Frontend** | Flutter (Material 3) | Cross-platform mobile app |
| **Offline** | Hive | Local storage + sync queue |
| **Backend** | Firebase (Auth, Firestore, Storage, Functions) | Serverless backend |
| **Functions** | TypeScript + Zod | Type-safe serverless functions |
| **Payments** | Manual (primary), Stripe (optional) | Check/cash + optional card payments |
| **Security** | App Check + Firestore Rules | Deny-by-default authorization |
| **Observability** | Crashlytics, Performance Monitoring, Analytics | Monitoring and debugging |

**Why this stack?** See [ADR-0001: Tech Stack](docs/ADRs/0001-tech-stack.md)

---

## Project Structure

```
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
│   │   ├── lib/              # Shared utilities (audit, idempotency, schemas)
│   │   ├── leads/            # createLead
│   │   ├── pdf/              # createEstimatePdf
│   │   ├── payments/         # markPaidManual, stripe (optional)
│   │   └── tests/            # Rules tests, function tests
├── docs/                     # Documentation
│   ├── Architecture.md       # System design
│   ├── KickoffTicket.md      # Requirements
│   ├── MIGRATION.md          # Old→new file mapping
│   └── ADRs/                 # Architecture decision records
├── .github/
│   ├── workflows/            # CI/CD (analyze, test, deploy)
│   └── ISSUE_TEMPLATE/       # Story, bug, tech-task templates
├── firebase.json             # Firebase config (emulators, hosting)
├── firestore.rules           # Security rules (deny-by-default)
├── firestore.indexes.json    # Database indexes
└── storage.rules             # Storage security rules
```

**Detailed structure:** See [Architecture.md](docs/Architecture.md)

---

## Environment Setup

### App Check (Debug Mode for Development)

App Check protects backend APIs from abuse. In development, use debug tokens:

```bash
# 1. Run the app once to get the debug token from console logs
flutter run

# 2. Register the debug token in Firebase Console:
#    Firebase Console → App Check → Apps → [Your App] → Debug tokens

# 3. (Optional) Store token locally for reuse
echo "APP_CHECK_DEBUG_TOKEN=your-token-here" > .env.debug
# Add .env.debug to .gitignore (already included)
```

**Docs:** [docs/APP_CHECK.md](docs/APP_CHECK.md)

### Feature Flags (Firebase Remote Config)

Configure behavior without deploying code:

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `payments.stripeEnabled` | boolean | `false` | Enable Stripe card payments |
| `features.pdfGeneration` | boolean | `true` | Server-side PDF for estimates |
| `features.offlineMode` | boolean | `true` | Local queue for offline writes |

**Set in:** Firebase Console → Remote Config

### Emulator Ports

| Service | Port | URL |
|---------|------|-----|
| Emulator UI | 4000 | http://localhost:4000 |
| Auth | 9099 | http://localhost:9099 |
| Firestore | 8080 | http://localhost:8080 |
| Functions | 5001 | http://localhost:5001 |
| Storage | 9199 | http://localhost:9199 |

**Docs:** [docs/EMULATORS.md](docs/EMULATORS.md)

---

## Development Workflows

### Run Tests

```bash
# Flutter unit tests
flutter test

# Flutter widget tests
flutter test test/widget_test.dart

# Cloud Functions tests
cd functions
npm test

# Security rules tests (requires emulators running)
npm run test:rules
cd ..
```

### Lint & Analyze

```bash
# Flutter
flutter analyze

# Cloud Functions
cd functions
npm run lint
npm run typecheck
cd ..
```

### Build

```bash
# Flutter (Android)
flutter build apk --release
flutter build appbundle --release

# Flutter (iOS)
flutter build ios --release

# Flutter (Web)
flutter build web --release

# Cloud Functions
cd functions
npm run build  # Output: functions/lib/
cd ..
```

---

## Deployment

### Staging (Auto-deploys on merge to main)

```bash
# Manual staging deployment
firebase use staging
firebase deploy
```

### Production (Tag-based)

```bash
# Create a version tag
git tag v1.0.0
git push origin v1.0.0

# GitHub Actions will automatically deploy to production
```

**CI/CD:** `.github/workflows/ci.yml`

---

## Key Features

### Security
- **Deny-by-default** Firestore security rules
- **App Check** for API abuse prevention
- **Role-based access control** (Admin, Crew Lead, Crew)
- **Audit trails** for all payment operations
- **Client restrictions**: Cannot write `invoice.paid` or `invoice.paidAt`

### Offline Support
- Local caching with Hive
- Offline write queue with automatic sync
- **Pending Sync** UI badges for queued operations
- Automatic reconciliation when online

### Accessibility (WCAG 2.2 AA)
- Minimum 48x48 touch targets
- Semantic labels on all interactive elements
- Text scaling support (up to 130%)
- High contrast color schemes
- Screen reader compatibility

### Payment Processing
- **Primary**: Manual check/cash (admin "mark paid" + audit trail)
- **Optional**: Stripe Checkout (behind `payments.stripeEnabled` flag)
- Idempotent webhook handlers
- Complete audit trail for all transactions

### Performance Targets
- **P50 < 1s** for API calls
- **P95 < 2.5s** for API calls
- **PDF generation ≤ 10s**
- **App launch < 3s** on mid-range devices

---

## Architecture Highlights

### Security Posture
1. **Firestore Rules**: Deny-by-default; explicit allow for org-scoped reads/writes
2. **Payment Protection**: Only Cloud Functions can set `invoice.paid` and `invoice.paidAt`
3. **Role Enforcement**: Admin checks at router level + Firestore rules
4. **App Check**: Enforced on all callable functions (anti-abuse)
5. **Audit Logging**: Immutable activity log for sensitive operations

### Offline-First Strategy
- **Local Queue**: Hive-backed queue for writes when offline
- **Sync State**: UI shows "Pending Sync" badge for queued operations
- **Reconciliation**: Automatic retry with exponential backoff
- **Conflict Resolution**: Last-write-wins (timestamps)

### Observability
- **Structured Logs**: `{ entity, action, actor, orgId, timestamp, ... }`
- **Crashlytics**: Auto-capture unhandled exceptions
- **Performance Monitoring**: Screen load times, API call durations, PDF generation
- **Analytics Events**: Feature usage, user flows (names stubbed)

**Full details:** [docs/Architecture.md](docs/Architecture.md)

---

## Contributing

1. **Create a branch**: `git checkout -b feature/my-feature`
2. **Use issue templates**: `.github/ISSUE_TEMPLATE/`
3. **Follow conventions**: See [CONTRIBUTING.md](CONTRIBUTING.md)
4. **Run tests**: `flutter test && cd functions && npm test`
5. **Lint code**: `flutter analyze && cd functions && npm run lint`
6. **Submit PR**: Use the PR template

**Code of Conduct:** Be respectful, inclusive, and professional.

---

## Troubleshooting

### Emulators Won't Start
```bash
# Kill existing processes
lsof -ti:4000,8080,9099,5001,9199 | xargs kill -9

# Clear emulator data
firebase emulators:start --clean
```

### Flutter Build Fails
```bash
# Clean build artifacts
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Functions Deployment Fails
```bash
# Rebuild functions
cd functions
rm -rf node_modules lib
npm ci
npm run build
firebase deploy --only functions
```

**More help:** See [docs/EMULATORS.md](docs/EMULATORS.md) and [docs/APP_CHECK.md](docs/APP_CHECK.md)

---

## License

Copyright © 2024 Sierra Painting. All rights reserved.

---

## Support

- **Issues**: [GitHub Issues](https://github.com/juanvallejo97/Sierra-Painting-v1/issues)
- **Docs**: [docs/](docs/)
- **ADRs**: [docs/ADRs/](docs/ADRs/)

For questions about architecture decisions, see the [Architecture Decision Records](docs/ADRs/).
