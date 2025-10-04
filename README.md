# Sierra Painting

[![CI Pipeline](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/ci.yml/badge.svg)](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/ci.yml)
[![Staging](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/staging.yml/badge.svg)](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/staging.yml)
[![Production](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/production.yml/badge.svg)](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/production.yml)

> **Professional mobile painting business management system** — Flutter + Firebase with offline-first architecture, RBAC, and production-ready deployment pipelines.

---

## Overview

Sierra Painting is a **production-ready mobile application** for painting contractors to manage projects, time tracking, estimates, invoices, and payments. Built with enterprise patterns: deny-by-default security, reversible migrations, canary deployments, and comprehensive audit trails.

**Key Features**:
- 📱 Cross-platform mobile (iOS/Android) with Flutter
- ⚡ Offline-first with automatic sync
- 🔒 Deny-by-default security (RBAC + App Check)
- 📊 Real-time time tracking with GPS validation
- 💼 Estimates, invoices, and payment processing
- 🚀 Progressive deployment (10% → 50% → 100%)
- 📈 Full observability (Crashlytics, Performance, Analytics)

---

## Quick Start

### Prerequisites
- **Flutter SDK** ≥ 3.8.0 — [Install](https://flutter.dev/docs/get-started/install)
- **Node.js** ≥ 18 — [Install](https://nodejs.org/)
- **Firebase CLI** — `npm install -g firebase-tools`

### Setup (3 commands)

```bash
# 1. Clone and install dependencies
git clone https://github.com/juanvallejo97/Sierra-Painting-v1.git
cd Sierra-Painting-v1 && flutter pub get && cd functions && npm ci && cd ..

# 2. Configure Firebase
firebase login && firebase use --add

# 3. Start development
firebase emulators:start          # Terminal 1
flutter run                       # Terminal 2
```

**Emulator UI**: http://localhost:4000

---

## Documentation

### Core Guides
- **[Architecture](docs/ARCHITECTURE.md)** — System design, data flow, and technology stack
- **[Deployment](docs/DEPLOYMENT.md)** — Canary rollout, monitoring, and rollback procedures
- **[Security](docs/Security.md)** — Firestore rules, App Check, threat model, and audit logging
- **[Database](docs/DATABASE.md)** — Schema, indexes, migrations, and optimization
- **[Operations](docs/OPERATIONS.md)** — Runbooks, monitoring, incident response
- **[Development](docs/DEVELOPMENT.md)** — Local setup, code style, testing, and workflow
- **[Testing](docs/Testing.md)** — Unit, integration, and smoke test strategies

### Additional Resources
- **[ADRs](docs/adrs/)** — Architecture decision records
- **[Migration Guide](docs/MIGRATION.md)** — V1 ship-readiness refactor notes
- **[Feature Flags](docs/FEATURE_FLAGS.md)** — Feature flag management
- **[App Check](docs/APP_CHECK.md)** — Firebase App Check setup
- **[Emulators](docs/EMULATORS.md)** — Local development with Firebase emulators
- **[Developer Workflow](docs/DEVELOPER_WORKFLOW.md)** — Story-driven development process

---

## Tech Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Frontend** | Flutter (Material 3) | Cross-platform mobile |
| **State** | Riverpod | Reactive state management |
| **Routing** | go_router | RBAC-enabled navigation |
| **Offline** | Hive | Local storage + sync queue |
| **Backend** | Firebase | Auth, Firestore, Storage, Functions |
| **Functions** | TypeScript + Zod | Type-safe serverless logic |
| **Payments** | Manual/Stripe | Check/cash + optional cards |
| **Security** | App Check + Rules | Deny-by-default authorization |
| **Observability** | Firebase Suite | Crashlytics, Performance, Analytics |

**Why this stack?** See [ADR-0001](docs/adrs/001-tech-stack.md)

---

## Project Structure

```
/
├── lib/                      # Flutter application
│   ├── app/                  # Bootstrap, theme, RBAC router
│   ├── core/                 # Services, providers, utilities
│   │   ├── services/         # Auth, Firestore, offline queue
│   │   ├── telemetry/        # Analytics, logging, crashlytics
│   │   └── utils/            # Result types, helpers
│   ├── features/             # Feature modules (auth, timeclock, etc.)
│   └── design/               # Design system (tokens, components)
├── functions/                # Cloud Functions (TypeScript)
│   ├── src/
│   │   ├── lib/              # Shared (audit, idempotency, schemas)
│   │   ├── leads/            # Lead management functions
│   │   ├── pdf/              # PDF generation
│   │   ├── payments/         # Payment processing
│   │   └── tests/            # Functions and rules tests
├── docs/                     # Canonical documentation
│   ├── ARCHITECTURE.md       # System architecture
│   ├── DEPLOYMENT.md         # Deployment procedures
│   ├── SECURITY.md           # Security guide
│   ├── DATABASE.md           # Schema and migrations
│   ├── OPERATIONS.md         # Runbooks
│   ├── DEVELOPMENT.md        # Developer guide
│   ├── adrs/                 # Architecture decision records
│   └── _archive/             # Historical documentation
├── .github/workflows/        # CI/CD pipelines
├── firebase.json             # Firebase configuration
├── firestore.rules           # Deny-by-default security rules
├── firestore.indexes.json    # Composite indexes
└── storage.rules             # Storage security rules
```

---

## Security

### Firestore Rules (Deny-by-Default)

```javascript
// Default: DENY ALL
match /{document=**} {
  allow read, write: if false;
}

// Explicit grants with RBAC
match /users/{userId} {
  allow read: if isOwner(userId) || isAdmin();
  allow update: if isOwner(userId) && !modifiesRole();
}

match /jobs/{jobId}/timeEntries/{entryId} {
  allow create: if isAuthenticated() && isOwnEntry();
  allow read: if isOwnEntry() || isAdmin();
  allow update, delete: if false; // Server-only
}

match /invoices/{invoiceId} {
  allow read: if isOrgMember();
  allow create, update: if isAdmin();
  // paid/paidAt fields are server-only (callable function)
}
```

**Security Principles**:
- ✅ Deny-by-default; explicit org-scoped grants
- ✅ Server-side authority for sensitive operations
- ✅ App Check enforcement on callable functions
- ✅ Immutable audit logs for payments/invoices
- ✅ No secrets in code (GitHub secrets + OIDC)

**See**: [docs/Security.md](docs/Security.md) for full threat model and test strategy.

---

## Deployment

### Environments

- **Dev**: Local emulators for development
- **Staging**: `sierra-painting-staging` (auto-deploy on `main`)
- **Production**: `sierra-painting-prod` (canary deployment on tags)

### Canary Deployment (Production)

```bash
# Create version tag
git tag v1.2.0 && git push origin v1.2.0

# GitHub Actions automatically:
# 1. Deploys at 10% traffic
# 2. Monitors SLOs for 24h
# 3. Gate: Promote to 50% (manual approval)
# 4. Monitors SLOs for 6h
# 5. Gate: Promote to 100% (manual approval)

# Or use scripts directly
./scripts/deploy_canary.sh --project sierra-painting-prod --tag v1.2.0
./scripts/promote_canary.sh --project sierra-painting-prod --stage 50
```

### Rollback (< 1 minute)

```bash
# Instant traffic routing rollback
./scripts/rollback.sh --project sierra-painting-prod

# Or feature flag killswitch
firebase remoteconfig:get --project sierra-painting-prod
# Set flag to false, publish
```

**See**: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for complete deployment procedures.

---

## Testing & Validation

```bash
# Flutter tests
flutter test --coverage

# Functions tests
cd functions && npm test

# Firestore rules tests
cd firestore-tests && npm test

# Lint & analyze
flutter analyze
cd functions && npm run lint

# Smoke tests (E2E)
flutter test integration_test/app_smoke_test.dart
```

**Coverage Targets**: 80%+ for services/repositories, 100% for security rules.

**See**: [docs/Testing.md](docs/Testing.md) for detailed testing strategy.

---

## Contributing

We welcome contributions! Please:

1. **Read**: [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) for setup and workflow
2. **Follow**: Conventional Commits (`feat(scope): message`)
3. **Test**: Ensure all tests pass (`flutter test`, `npm test`)
4. **Document**: Update docs for breaking changes
5. **Security**: Never commit secrets (see `.gitignore`)

**Code of Conduct**: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)

---

## Security Disclosure

If you discover a security vulnerability:

1. **Do NOT** open a public issue
2. Email maintainers directly: [contact info in docs/Security.md](docs/Security.md)
3. Allow reasonable time for fix before disclosure

We follow responsible disclosure practices and will credit security researchers.

---

## License

This project is licensed under the [MIT License](LICENSE).

---

## Support & Contact

- **Documentation**: Start with [docs/](docs/) directory
- **Issues**: [GitHub Issues](https://github.com/juanvallejo97/Sierra-Painting-v1/issues)
- **Discussions**: [GitHub Discussions](https://github.com/juanvallejo97/Sierra-Painting-v1/discussions)

---

**Version**: 1.0.0  
**Last Updated**: 2024  
**Status**: Production-Ready
