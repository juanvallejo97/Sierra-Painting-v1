# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2024-10-01

### Added
- Initial project scaffold and repository setup
- Flutter application structure with Material Design 3
- Firebase integration (Auth, Firestore, Storage, Functions, App Check)
- Offline-first architecture with Hive local storage
- Feature flag system using Firebase Remote Config
- Deny-by-default Firestore security rules
- Storage security rules with file type and size validation
- Cloud Functions with TypeScript and Zod validation
- Manual payment processing (check/cash) with admin approval
- Optional Stripe integration behind feature flag
- Idempotent Stripe webhook handler
- Payment audit trail system
- WCAG 2.2 AA accessibility compliance
- CI/CD workflows for Flutter and Firebase Functions
- Security scanning workflow
- Comprehensive documentation (README, SETUP, ARCHITECTURE)
- Theme configuration with light and dark modes
- Basic widget tests

### Infrastructure
- GitHub Actions workflows for:
  - Flutter linting, testing, and building
  - Firebase Functions linting and building
  - Security checks and dependency audits
- Firebase project configuration
- Firestore indexes for optimized queries

### Documentation
- README.md with project overview
- SETUP.md with detailed setup instructions
- ARCHITECTURE.md with system design documentation
- CONTRIBUTING.md with contribution guidelines
- This CHANGELOG.md

[Unreleased]: https://github.com/juanvallejo97/Sierra-Painting-v1/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/juanvallejo97/Sierra-Painting-v1/releases/tag/v1.0.0
