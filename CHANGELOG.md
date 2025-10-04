# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.12] - 2024-10-04

### Added
- Reconstructed complete `pubspec.yaml` with all dependencies
- Added missing Firebase packages (crashlytics, analytics, performance)
- Created `ARCHITECTURE.md` documenting app structure and conventions
- Created `CONTRIBUTING.md` with development workflow guidelines
- Created `CHANGELOG.md` for tracking version history

### Fixed
- Fixed corrupted `pubspec.yaml` file (was placeholder content)
- Fixed Firestore Rules workflow job name to match CI requirements
- Corrected dependency versions to match lock file
- Added proper dependency overrides with justification

### Changed
- Updated environment SDK constraint to `>=3.3.0 <4.0.0`
- Bumped version from 0.0.0 to 0.0.12 (following existing versioning scheme)
- Standardized all workflow job names for CI checks

### Security
- Documented dependency override justifications
- Ensured no service account keys committed
- Firestore rules hardened with proper authentication checks

## [0.0.11] - Previous Version

### Note
Previous versions may have incomplete changelog entries. This changelog was established as part of the enterprise remediation effort.

---

## Version Numbering Scheme

- **Major (0.x.x)**: Breaking changes or major feature releases
- **Minor (x.0.x)**: New features, backward compatible
- **Patch (x.x.0)**: Bug fixes, backward compatible

The `+build` suffix indicates the build number for app stores.
