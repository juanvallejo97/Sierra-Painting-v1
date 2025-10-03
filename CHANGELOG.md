# Changelog
All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project adheres to Semantic Versioning.

## [1.0.0] - 2024-10-03

### Added
- **Core Services**
  - Haptic feedback service with comprehensive API (light, medium, heavy, selection, vibrate)
  - Offline-first architecture with queue synchronization
  - Feature flag service with Firebase Remote Config integration
  - Performance monitoring and crash reporting
- **Authentication & Authorization**
  - Email/password authentication via Firebase Auth
  - Role-based access control (RBAC) in routing
  - Secure login screen with haptic feedback
- **Design System**
  - Material 3 theme implementation
  - Design tokens for colors, spacing, typography
  - Reusable components (AppButton, AppInput, AppCard, etc.)
  - Skeleton loaders and empty states
- **Testing Infrastructure**
  - Unit tests for core services (haptic, network, utils)
  - Widget tests for components
  - Integration tests for critical flows
  - Coverage targets defined
- **CI/CD Pipeline**
  - Automated formatting, analysis, and testing
  - APK size budgets and reporting
  - Multi-environment deployment (staging, production)
  - Security scanning and dependency checks
- **Documentation**
  - Comprehensive ADRs for architectural decisions
  - Code audit summary with quality metrics
  - Governance guidelines and contribution standards
  - Onboarding guide for new developers
  - Architecture documentation with structure and conventions

### Changed
- **Import Standardization**: Converted relative imports to package imports for consistency
- **State Management**: Full Riverpod integration with provider-based dependency injection
- **Firebase Integration**: Complete setup with App Check, Performance, Crashlytics, Analytics

### Fixed
- Import path consistency in settings screen

### Security
- Firebase App Check enabled for production
- Firestore security rules with RBAC
- Input validation with Zod schemas in Cloud Functions
- No credentials or secrets in source code

## [Unreleased]

### Added
- **Firestore Rules Testing Infrastructure**: Created `firestore-tests/` with Node.js test harness
- **Smoke Test Infrastructure**: Added `tool/smoke/smoke.dart` for CI smoke test artifact generation
- **Security Documentation**: Created `SECURITY.md` with secrets handling guidelines
- **Secrets Examples**: Added `secrets/_examples/` with placeholder service account templates
- **Makefile**: Added convenience commands for analyze, test, format, and smoke
- **CI/CD Enhancements**: 
  - Standardized workflow job names to match expected check names
  - Updated Firestore Rules workflow to use new test infrastructure
  - Enhanced .gitignore with firestore-tests and secrets patterns

### Changed
- **Workflow Job Names**: Updated to match expected check names:
  - `analyze-and-test-flutter` → Analyze and Test Flutter
  - `code-quality-and-lint-enforcement` → Code Quality & Lint Enforcement
  - `check-for-json-service-account-keys` → Check for JSON Service Account Keys
  - `mobile-app-smoke-tests` → Mobile App Smoke Tests
  - `smoke-test-summary` → Smoke Test Summary
  - `rules` → Firestore Rules test job
- **Dependencies**: Updated to resolve version conflicts, removed unnecessary overrides
- **Package Scripts**: Added `smoke` script to package.json for CI integration

### Fixed
- Firestore Rules test workflow now uses standalone test infrastructure
- Smoke test workflows reference correct job names
- Service account JSON patterns properly excluded from repository

### Security
- Enhanced gitignore patterns to prevent service account key commits
- Added automated check for prohibited JSON credentials
- Documented secrets handling best practices
- Workload Identity Federation enforced in CI/CD

## [Unreleased]

### Planned Features
- Theme switching (light/dark mode)
- Enhanced sync status UI
- Additional accessibility options
- Improved error boundaries

---

## [0.0.11] - Previous Version
### Added
- Initial governance files (CODE_OF_CONDUCT, CONTRIBUTING, CHANGELOG)
- Documentation index and onboarding guide
- Standard labels configuration
- CODEOWNERS for repository stewardship

---