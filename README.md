# Sierra Painting - Project Sienna

A modern Flutter-based painting application for small business management with Firebase backend.

## 🎯 Overview

Sierra Painting is a mobile-first application built with Flutter and Firebase, designed to help small painting businesses manage their operations, projects, and payments efficiently. The project follows **story-driven development** with comprehensive documentation and best practices from top tech companies.

## 📚 Documentation

### Getting Started
- **[Setup Guide](SETUP.md)** - Initial setup and configuration
- **[Quickstart](QUICKSTART.md)** - Get up and running quickly
- **[Developer Workflow](docs/DEVELOPER_WORKFLOW.md)** - Complete development guide

### Architecture & Decisions
- **[Architecture Overview](ARCHITECTURE.md)** - System architecture and data flow
- **[ADRs](docs/adrs/README.md)** - Architecture Decision Records
  - [ADR-006: Idempotency Strategy](docs/adrs/006-idempotency-strategy.md)
  - [ADR-011: Story-Driven Development](docs/adrs/011-story-driven-development.md)
  - [ADR-012: Sprint-Based Feature Flags](docs/adrs/012-sprint-based-flags.md)

### User Stories & Sprints
- **[Story Overview](docs/stories/README.md)** - Story-driven development guide
- **[Sprint V1 Plan](docs/stories/v1/SPRINT_PLAN.md)** - Current sprint details
- **[Story Example: B1 (Clock-in)](docs/stories/v1/B1-clock-in.md)** - Detailed story template

### Features & Operations
- **[Feature Flags](docs/FEATURE_FLAGS.md)** - Feature flag management
- **[App Check Setup](docs/APP_CHECK.md)** - Security and API protection
- **[Emulators Guide](docs/EMULATORS.md)** - Local development with Firebase emulators

### Project Status
- **[Implementation Summary](IMPLEMENTATION_SUMMARY.md)** - Recent changes and fixes
- **[Validation Checklist](VALIDATION_CHECKLIST.md)** - Pre-deployment verification
- **[Verification Report](VERIFICATION_REPORT.md)** - Post-deployment validation

## 🏗️ Tech Stack

### Frontend
- **Flutter** (Material Design 3)
- **Riverpod** - State management
- **go_router** - Navigation with RBAC guards
- **Hive** - Offline queue management
- **Mobile-first** design approach
- **WCAG 2.2 AA** accessibility compliance

### Backend
- **Firebase Authentication** - User management
- **Cloud Firestore** - NoSQL database with deny-by-default security rules
- **Firebase Storage** - File storage for images and documents
- **Cloud Functions** - TypeScript + Zod validation
- **Firebase App Check** - Security against abuse
- **Firebase Remote Config** - Feature flags

### Payments
- **Primary**: Manual check/cash payments with admin approval and audit trail
- **Optional**: Stripe Checkout (behind feature flag)

## 🎯 Development Methodology

This project follows **Story-Driven Development** with:
- **User Stories**: BDD-style acceptance criteria (Given/When/Then)
- **Sprint Planning**: Features organized by sprint (V1, V2, V3, V4)
- **Feature Flags**: Progressive rollout with Firebase Remote Config
- **Idempotency**: Prevent duplicate operations (offline, retries, webhooks)
- **Audit Trail**: Complete activity logging for compliance
- **Observability**: Telemetry events and structured logging

See [ADR-011: Story-Driven Development](docs/adrs/011-story-driven-development.md) for details.

## 📂 Project Structure

```
sierra_painting/
├── lib/
│   ├── core/
│   │   ├── config/           # App configuration
│   │   ├── services/         # Core services (offline, feature flags)
│   │   ├── providers/        # Riverpod providers
│   │   └── models/           # Data models
│   ├── features/             # Feature modules (auth, timeclock, etc.)
│   └── shared/               # Shared widgets and components
├── functions/
│   └── src/
│       ├── index.ts          # Main Cloud Functions
│       ├── schemas/          # Zod validation schemas
│       ├── services/         # Business logic
│       └── stripe/           # Stripe webhook handlers
├── docs/
│   ├── adrs/                 # Architecture Decision Records
│   ├── stories/              # User stories by sprint
│   └── runbooks/             # Operational guides
├── test/                     # Flutter tests
├── firestore.rules           # Firestore security rules (deny-by-default)
├── firestore.indexes.json    # Required database indexes
├── storage.rules             # Storage security rules
└── firebase.json             # Firebase configuration
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.0.0)
- Node.js 18+
- Firebase CLI
- Git

### Quick Setup

```bash
# 1. Clone the repository
git clone https://github.com/juanvallejo97/Sierra-Painting-v1.git
cd Sierra-Painting-v1

# 2. Install dependencies
flutter pub get
cd functions && npm install && cd ..

# 3. Configure Firebase
firebase login
flutterfire configure

# 4. Start emulators for local development
firebase emulators:start

# 5. Run the app
flutter run
```

See [SETUP.md](SETUP.md) for detailed setup instructions.

### Development Workflow

```bash
# 1. Pick a story from the sprint backlog
cat docs/stories/v1/B1-clock-in.md

# 2. Create a feature branch
git checkout -b feature/B1-clock-in-offline

# 3. Implement with TDD (Test-Driven Development)
flutter test                    # Run tests
cd functions && npm test        # Run function tests

# 4. Commit with story reference
git commit -m "feat(B1): implement offline clock-in queue"

# 5. Create PR with DoD checklist
# See docs/DEVELOPER_WORKFLOW.md for complete guide
```

See [Developer Workflow Guide](docs/DEVELOPER_WORKFLOW.md) for complete details.

## ✨ Key Features

### Security (Epic A)
- Email/password authentication via Firebase Auth
- Role-based access control (admin, crewLead, crew)
- App Check for API abuse prevention
- Deny-by-default Firestore security rules
- Comprehensive audit trails

### Time Clock (Epic B)
- Clock-in/out with GPS tracking (optional)
- Offline queue with automatic sync
- Idempotent operations (no duplicate entries)
- Overlap prevention (no concurrent shifts)
- Admin time edit with audit trail (V3-V4)

### Invoicing (Epic C)
- Create estimates with PDF generation
- Quote → Invoice conversion
- Manual payment processing (check/cash)
- Optional Stripe Checkout (feature flag)
- Payment audit trails

### Lead Management (Epic D)
- Public lead form with spam prevention
- Lead review and qualification
- Job scheduling with crew assignment
- Conflict detection and capacity hints

### Operations & Observability (Epic E)
- CI/CD with GitHub Actions
- Firestore rules testing (emulator)
- Telemetry and structured logging
- Activity log for compliance
- KPI dashboard (V4)

## 🧪 Testing

### Flutter Tests
```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Function Tests
```bash
cd functions
npm test                    # Run all tests (when implemented)
npm run test:coverage       # Coverage report
```

### Integration Tests (Emulator)
```bash
# Start emulators
firebase emulators:start

# Run integration tests
cd functions
npm run test:integration
```

### E2E Tests
```bash
# Run Flutter integration tests
flutter test integration_test/
```

See test examples in:
- [Story B1 Testing Strategy](docs/stories/v1/B1-clock-in.md#testing-strategy)
- [Developer Workflow - Testing](docs/DEVELOPER_WORKFLOW.md#testing-best-practices)

## 🔒 Security

### Firestore Rules (Deny-by-Default)
```javascript
// Default: DENY all access
match /{document=**} {
  allow read, write: if false;
}

// Explicit permissions required
match /users/{userId} {
  allow read: if isOwner(userId) || isAdmin();
  allow update: if isOwner(userId) && !modifiesRole();
}

match /jobs/{jobId}/timeEntries/{entryId} {
  allow create: if isAuthenticated() && isOwnEntry();
  allow read: if isOwnEntry() || isAdmin();
  allow update, delete: if false;  // Server-only
}
```

### Key Security Principles
- **Deny-by-default**: All rules start with explicit deny
- **Client cannot set paid**: Invoice payment fields are server-only
- **Idempotency**: Prevent duplicate financial transactions
- **App Check**: API abuse prevention
- **Audit logs**: Complete activity trail

See [Security Architecture](ARCHITECTURE.md#security-architecture) for details.

## 🚢 Deployment

### Staging (Automatic)
```bash
# Merge to main triggers CI/CD
git checkout main
git merge feature/B1-clock-in-offline
git push origin main

# GitHub Actions automatically:
# 1. Runs tests
# 2. Deploys functions to staging
# 3. Deploys rules to staging
```

### Production (Manual)
```bash
# Tag version for production deployment
git tag -a v1.0.0 -m "Sprint V1 release"
git push origin v1.0.0

# GitHub Actions automatically:
# 1. Runs all tests
# 2. Builds release APK
# 3. Deploys to production
# 4. Creates GitHub release
```

See [CI/CD Workflows](.github/workflows/) for pipeline details.

## 🎛️ Feature Flags

Features are controlled via Firebase Remote Config:

```dart
// Check if feature is enabled
final clockInEnabled = ref.watch(clockInEnabledProvider);

if (clockInEnabled) {
  return ClockInButton();
} else {
  return ComingSoonBanner();
}
```

### Current Flags
- ✅ `feature_b1_clock_in_enabled: true` (V1, active)
- ✅ `feature_b2_clock_out_enabled: true` (V1, active)
- 🔒 `feature_c1_create_quote_enabled: false` (V2, gated)
- 🔒 `feature_c5_stripe_checkout_enabled: false` (V4, optional)

See [Feature Flags Guide](docs/FEATURE_FLAGS.md) for complete documentation.

## 📊 Performance Targets

| Operation | Target (P95) | Status |
|-----------|--------------|--------|
| Sign-in | ≤ 2.5s | ✅ Met |
| Clock-in (online) | ≤ 2.5s | ✅ Met |
| Jobs Today load | ≤ 2.0s | ✅ Met |
| Offline sync | ≤ 5s per item | ✅ Met |

Monitored via Firebase Performance and structured logging.

## 🏃 Sprint Status

### Sprint V1 (Current) - MVP Foundation
**Focus**: Authentication + Time Clock + Observability

- ✅ A1: Sign-in/out
- ✅ A2: Admin roles
- 🔄 A5: App Check
- 🔄 B1: Clock-in (offline + GPS)
- 📋 B2: Clock-out
- 📋 B3: Jobs Today
- 📋 E1: CI/CD gates
- 📋 E3: Telemetry + Audit

**Cut Line**: A1, A2, B1, B2, E1, E3 must ship

### Sprint V2 (Upcoming) - Invoicing
**Focus**: Quotes, Invoices, Manual Payments

- 📋 C1: Create quote + PDF
- 📋 C2: Quote → Invoice
- 📋 C3: Manual mark-paid
- 📋 B5: Auto clock-out safety
- 📋 B7: My timesheet

**Cut Line**: Ship C1-C3, defer B7 if tight

See [Sprint V1 Plan](docs/stories/v1/SPRINT_PLAN.md) for details.


## Contributing

1. Create a feature branch
2. Make your changes
3. Run tests and linting
4. Submit a pull request

## License


Copyright © 2024 Sierra Painting. All rights reserved.

## Support
For issues or questions, please open an issue on GitHub. 
