# Project structure

This document describes the directory structure and organization of Sierra Painting.

## Root directory

```
/
├── .github/          # GitHub Actions workflows and templates
├── android/          # Android platform code
├── docs/             # Documentation (this directory)
├── functions/        # Cloud Functions (TypeScript)
├── ios/              # iOS platform code (when supported)
├── lib/              # Flutter application code
├── scripts/          # Build and deployment scripts
├── test/             # Flutter unit and widget tests
├── tests/            # Firestore rules tests
├── tool/             # Development tools (smoke tests)
└── web/              # Web platform code (admin only)
```

## Flutter app structure (`lib/`)

```
lib/
├── main.dart                    # Application entry point
├── firebase_options.dart        # Firebase configuration (generated)
├── app/
│   ├── app.dart                 # MaterialApp setup
│   ├── router.dart              # go_router configuration with RBAC
│   └── theme.dart               # Material 3 theme
├── core/
│   ├── services/                # Core services
│   │   ├── auth_service.dart
│   │   ├── firestore_service.dart
│   │   ├── offline_service.dart
│   │   └── feature_flag_service.dart
│   ├── telemetry/               # Observability
│   │   ├── analytics.dart
│   │   ├── crashlytics.dart
│   │   └── logger.dart
│   ├── utils/                   # Helper utilities
│   └── constants/               # App constants
├── features/                    # Feature modules
│   ├── auth/                    # Authentication
│   │   ├── data/                # Data sources and repositories
│   │   ├── domain/              # Business logic and models
│   │   └── presentation/        # UI screens and widgets
│   ├── timeclock/               # Time tracking
│   ├── estimates/               # Quote/estimate creation
│   ├── invoices/                # Invoice management
│   ├── payments/                # Payment processing
│   └── admin/                   # Admin dashboard
└── widgets/                     # Shared UI components
    ├── app_button.dart
    ├── app_input.dart
    ├── cached_image.dart
    └── paginated_list_view.dart
```

## Cloud Functions structure (`functions/`)

```
functions/
├── src/
│   ├── index.ts                 # Function exports
│   ├── lib/                     # Shared utilities
│   │   ├── audit.ts             # Audit logging
│   │   ├── idempotency.ts       # Idempotency handling
│   │   └── zodSchemas.ts        # Type-safe schemas
│   ├── leads/                   # Lead management functions
│   │   └── createLead.ts
│   ├── pdf/                     # PDF generation
│   │   └── createEstimatePdf.ts
│   ├── payments/                # Payment processing
│   │   ├── markPaidManual.ts
│   │   └── stripeWebhook.ts
│   └── tests/                   # Function tests
├── package.json                 # Node.js dependencies
└── tsconfig.json                # TypeScript configuration
```

## Documentation structure (`docs/`)

```
docs/
├── README.md                    # Documentation index
├── GLOSSARY.md                  # Terms and acronyms
├── FAQ.md                       # Frequently asked questions
├── tutorials/                   # Learning-oriented guides
│   ├── README.md
│   └── getting-started.md
├── how-to/                      # Problem-solving guides
│   ├── README.md
│   ├── run-tests.md
│   └── deploy-staging.md
├── reference/                   # Technical descriptions
│   ├── README.md
│   └── project-structure.md    # This file
├── explanation/                 # Conceptual discussions
│   ├── README.md
│   └── architecture.md
├── adrs/                        # Architecture Decision Records
├── stories/                     # User stories
│   ├── v1/, v2/, v3/, v4/       # Sprint-organized stories
│   └── epics/                   # Epic overviews
└── _archive/                    # Outdated documentation
```

## Scripts directory (`scripts/`)

```
scripts/
├── ci/                          # CI/CD helper scripts
├── smoke/                       # Smoke test runners
├── quality.sh                   # Quality checks (lint, analyze)
├── generate-docs.sh             # Generate API documentation
└── measure_startup.sh           # Performance measurement
```

## Configuration files

- `.firebaserc` - Firebase project aliases
- `firebase.json` - Firebase configuration (emulators, hosting)
- `firestore.rules` - Firestore security rules
- `firestore.indexes.json` - Firestore composite indexes
- `storage.rules` - Cloud Storage security rules
- `pubspec.yaml` - Flutter dependencies
- `analysis_options.yaml` - Dart linting rules

## Naming conventions

### Files

- Dart files: `snake_case.dart`
- Test files: `*_test.dart`
- Generated files: `*.g.dart` (excluded from git)

### Directories

- Feature modules: `snake_case/`
- Test directories: Same name as source directory

### Classes

- Classes: `PascalCase`
- Widgets: `PascalCase` (suffix with Widget for clarity)
- Services: `PascalCase` (suffix with Service)

## Git branches

- `main` - Main development branch (auto-deploys to staging)
- `feature/*` - Feature branches
- `fix/*` - Bug fix branches
- `docs/*` - Documentation branches
- `release/*` - Release branches (stricter CI)

## Environment separation

- **Staging**: `sierra-painting-staging` (Firebase project)
- **Production**: `sierra-painting-prod` (Firebase project)
- **Local**: Firebase emulators

## Next steps

- [Getting started](../tutorials/getting-started.md)
- [Naming conventions](naming-conventions.md)
- [System architecture](../explanation/architecture.md)

---