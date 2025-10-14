# Migration Notes: CI/CD Workflow & Dependency Audit

## Overview
This document describes the changes made to fix all GitHub Actions workflows and stabilize the dependency tree for the Sierra Painting v1 application.

## Changes Made

### 1. Dependency Cleanup

**Problem**: `dart_code_metrics` package conflicted with `uuid` v4 and was causing pub solver issues.

**Solution**: 
- Removed `dart_code_metrics` from `pubspec.yaml` dev_dependencies
- Removed `very_good_analysis` in favor of `flutter_lints` (standard Flutter linting)
- Added `mocktail` for test mocking support
- Kept `uuid: ^4.2.2` on latest stable version

**Files Modified**:
- `pubspec.yaml`: Updated dev_dependencies section
- `analysis_options.yaml`: Switched from `very_good_analysis` to `flutter_lints` with custom rules

### 2. Analysis Options Standardization

**Problem**: Analysis options were overly complex and used deprecated packages.

**Solution**: 
- Adopted `package:flutter_lints/flutter.yaml` as the baseline
- Added strict analyzer settings (strict-casts, strict-inference, strict-raw-types)
- Added custom lint rules for code quality (prefer_const_constructors, require_trailing_commas, etc.)
- Properly excluded generated files and build artifacts

**Files Modified**:
- `analysis_options.yaml`: Complete rewrite following Flutter best practices

### 3. Workflow Standardization

**Problem**: Workflows had inconsistent naming, used outdated actions, referenced non-existent dart_code_metrics, and mixed PowerShell/bash syntax.

**Solution**: Created 5 new standardized workflows following org requirements:

#### A. Code Quality Checks (`.github/workflows/code_quality.yml`)
- Job name: `code-quality-and-lint-enforcement` (matches org gate)
- Runs: format check, analyze
- No dart_code_metrics references
- Uses: Flutter stable, ubuntu-latest, bash shell
- Includes pub cache for faster builds

#### B. Flutter CI (consolidated into `.github/workflows/ci.yml`)
- **Note**: Previously standalone as `flutter_ci.yml`, now part of comprehensive `ci.yml`
- The `ci.yml` workflow now handles all Flutter, Functions, and build jobs with matrix strategy
- Job names: `analyze`, `test`, `build` (with platform matrix: android, ios, web)
- Includes: analyze, test with coverage, multi-platform builds
- Uses: Java 17, Gradle caching, Flutter stable

#### C. Firestore Rules (`.github/workflows/firestore_rules.yml`)
- Job name: `rules` (matches org gate)
- Uses: Node 20 for emulator compatibility
- Runs: firestore-tests via npm test
- No `firebase use` calls (uses emulator)

#### D. Secrets Check (`.github/workflows/secrets_check.yml`)
- Job name: `check-for-json-service-account-keys` (matches org gate)
- Scans for service account JSON patterns
- Enforces Workload Identity Federation
- Pure bash implementation

#### E. Smoke Tests (`.github/workflows/smoke_tests.yml`)
- Job names: `mobile-app-smoke-tests`, `smoke-test-summary` (match org gates)
- Tests: `integration_test/app_boot_smoke_test.dart`
- Generates: `build/smoke/smoke_results.json` artifact
- Two-stage pipeline with artifact download

**Files Created**:
- `.github/workflows/code_quality.yml`
- `.github/workflows/ci.yml` (comprehensive pipeline consolidating Flutter, Functions, Rules tests)
- `.github/workflows/firestore_rules.yml`
- `.github/workflows/secrets_check.yml`
- `.github/workflows/smoke_tests.yml`

**Files Removed** (Phase 2 Consolidation):
- `.github/workflows/flutter_ci.yml` (consolidated into `ci.yml`)

**Old Workflows**: The old workflows (`ci.yml`, `quality.yml`, `rules-test.yml`, `prevent-json-credentials.yml`, `smoke.yml`) should be removed after validating the new ones work.

### 4. Test Infrastructure

**Problem**: `integration_test/app_boot_smoke_test.dart` was referenced but didn't exist.

**Solution**: Created minimal boot smoke test that:
- Launches app and waits for first frame
- Measures startup time
- Validates MaterialApp or Scaffold renders
- Has 3000ms budget for CI environments
- Logs performance metrics

**Files Created**:
- `integration_test/app_boot_smoke_test.dart`

### 5. Smoke Test Artifact Generation

**Files Verified**:
- `tool/smoke/smoke.dart`: Already existed, generates `build/smoke/smoke_results.json`
- Workflow uploads this artifact for summary job

## Version Constraints

All workflows now use these standardized versions:

| Tool | Version | Rationale |
|------|---------|-----------|
| Flutter | `stable` channel | Latest stable features |
| Java | `17` | LTS, required for Android builds |
| Node | `20` | LTS, required for Firebase emulators |
| Actions | `@v4` | Latest major versions pinned |
| Flutter Action | `subosito/flutter-action@v2` | Official recommendation |

## Environment Variables

Workflows use these env vars (set at workflow level):

```yaml
FIREBASE_PROJECT_PROD: to-do-app-ac602
HOSTING_SITE_PROD: sierra-prod
FLUTTER_CHANNEL: stable
```

**Important**: Never use `firebase use` in CI. Always pass `--project` and `--site` explicitly.

## Shell & OS Standards

- **OS**: `ubuntu-latest` only (Linux runners)
- **Shell**: `bash` explicitly specified on all `run:` steps
- **No PowerShell**: All `$Env:` syntax removed
- **Env vars**: Use `env:` blocks or inline `export VAR=value`

## Testing Locally

### Install Dependencies
```bash
flutter pub get
```

### Run Analysis
```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
```

### Run Tests
```bash
flutter test --coverage
```

### Run Smoke Test
```bash
flutter test integration_test/app_boot_smoke_test.dart
dart run tool/smoke/smoke.dart
```

### Run Firestore Rules Tests
```bash
cd firestore-tests
npm install
npm test
```

## Expected CI Outcomes

All five required checks should now pass:

1. ✅ **Code Quality Checks / Code Quality & Lint Enforcement (pull_request)**
2. ✅ **Flutter CI / Analyze and Test Flutter (pull_request)**
3. ✅ **Security - Firestore Rules / rules (pull_request)**
4. ✅ **Security - Prevent JSON Credentials / Check for JSON Service Account Keys (pull_request)**
5. ✅ **Smoke Tests / Mobile App Smoke Tests (pull_request)**
6. ✅ **Smoke Tests / Smoke Test Summary (pull_request)**

## Breaking Changes

None. All changes are CI/CD infrastructure only.

## Future Enhancements

- Add code coverage reporting
- Add APK size tracking
- Add performance budgets dashboard
- Integrate with deployment pipelines

## Troubleshooting

### Pub Get Fails
If `flutter pub get` fails with version conflicts, verify:
1. Flutter SDK is on stable channel
2. No manual edits to pubspec.yaml
3. Delete pubspec.lock and try again

### Tests Fail
If integration tests fail:
1. Check app_boot_smoke_test.dart matches app structure
2. Verify MaterialApp/Scaffold exist in main.dart
3. Increase timeout budget if CI is slow

### Rules Tests Fail
If Firestore rules tests fail:
1. Ensure Node 20 is installed
2. Check firestore-tests/package.json has correct deps
3. Verify firestore.rules syntax is valid

## References

- [Flutter CI Best Practices](https://docs.flutter.dev/deployment/cd)
- [GitHub Actions for Flutter](https://github.com/subosito/flutter-action)
- [Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite)
