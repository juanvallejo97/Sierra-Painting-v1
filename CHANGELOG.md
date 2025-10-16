# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.13] - 2025-10-15

### Added
- **Invoice Undo Feature (CHK-01)**: 15-second undo window for invoice status changes
  - `revertStatus()` method with transactional status history tracking
  - SnackBar with "Undo" action for markAsSent() and markAsPaidCash()
  - Audit trail maintained in statusHistory array
  - Unit tests for status reversion and round-trip totals integrity
- **Manual Onboarding Documentation (CHK-04)**: Comprehensive employee onboarding guide
  - Created `docs/onboarding_manual.md` with step-by-step instructions
  - Added help button in Employees screen linking to manual onboarding docs
  - Renamed "Add Employee" to "Add Employee (manual)" to clarify process
  - In-app dialog explaining manual onboarding workflow

### Changed
- Version bumped from 0.0.12+12 to 0.0.13+13
- Invoice repository now uses transactions for status changes to maintain history
- Employees list screen clarifies that phone-based invites are not yet implemented

### Fixed
- Invoice status changes now properly maintain audit history for undo functionality
- Eliminated confusion around non-existent SMS invite feature

## [0.0.12] - 2024-10-04

### Added
- Reconstructed complete `pubspec.yaml` with all dependencies from scratch
  - Added all Firebase packages: core, auth, storage, firestore, functions, app_check, remote_config, crashlytics, performance, analytics
  - Added state management: flutter_riverpod, provider
  - Added routing: go_router
  - Added local storage: hive, hive_flutter, shared_preferences, path_provider
  - Added networking: http, connectivity_plus
  - Added payments: flutter_stripe
  - Added utilities: uuid, intl, material_color_utilities
  - Added dev dependencies: build_runner, hive_generator, mockito, flutter_lints, analyzer, integration_test
- Created `ARCHITECTURE.md` documenting app structure, conventions, and patterns
- Created `CONTRIBUTING.md` with comprehensive development workflow guidelines
- Created `CHANGELOG.md` for tracking version history and changes

### Fixed
- Fixed critically corrupted `pubspec.yaml` file (was only 326 bytes with placeholder content)
- Fixed Firestore Rules workflow job name to match exact CI requirements (changed from "Firestore Rules Tests" to "rules")
- Corrected all dependency versions to match lock file versions
- Added proper dependency overrides with detailed justification comments

### Changed
- Updated environment SDK constraint to `>=3.3.0 <4.0.0` (was unspecified)
- Set package name to `sierra_painting` with proper metadata
- Bumped version from 0.0.0 to 0.0.12+12 (following existing versioning scheme)
- Standardized all workflow job names for 6 required CI checks

### Verified
- All 6 CI workflow names and job names match exact requirements:
  1. ✅ Code Quality Checks / Code Quality & Lint Enforcement
  2. ✅ Flutter CI / Analyze and Test Flutter
  3. ✅ Security - Firestore Rules / rules
  4. ✅ Security - Prevent JSON Credentials / Check for JSON Service Account Keys
  5. ✅ Smoke Tests / Mobile App Smoke Tests
  6. ✅ Smoke Tests / Smoke Test Summary
- Smoke test infrastructure complete (integration_test/, tool/smoke/)
- Firestore rules test infrastructure complete (firestore-tests/)
- Test infrastructure complete (test/ with comprehensive coverage)
- Documentation files verified (SECURITY.md exists, .gitignore comprehensive)

### Security
- Documented dependency override justifications in pubspec.yaml
- Verified no service account keys committed
- Verified secrets/_examples/ has proper placeholder files
- Firestore rules hardened with proper authentication checks
- analysis_options.yaml uses flutter_lints with strict settings

## [0.0.11] - Previous Version

### Note
Previous versions may have incomplete changelog entries. This changelog was established as part of the enterprise remediation effort.

---

## Version Numbering Scheme

- **Major (0.x.x)**: Breaking changes or major feature releases
- **Minor (x.0.x)**: New features, backward compatible
- **Patch (x.x.0)**: Bug fixes, backward compatible

The `+build` suffix indicates the build number for app stores.
