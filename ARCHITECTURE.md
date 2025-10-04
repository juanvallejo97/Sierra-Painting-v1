# Architecture

## Overview
Sierra Painting is a Flutter-based mobile application for professional painting services management.

## Project Structure

### Core (`lib/core`)
Shared services and providers used throughout the application:

- **`services/`**: Core business services
  - `haptic_service.dart`: Tactile feedback for user interactions
  - `feature_flag_service.dart`: Runtime feature toggles
  - `offline_service.dart`: Local storage and offline-first architecture
  - `queue_service.dart`: Background operation queue with sync

- **`providers/`**: Riverpod providers for dependency injection
  - `auth_provider.dart`: Firebase Auth state management
  - `firestore_provider.dart`: Firestore collections
  - `providers.dart`: Barrel file for all providers

- **`widgets/`**: Reusable UI components
- **`models/`**: Core data models
- **`utils/`**: Utility functions and helpers

### Features (`lib/features`)
Feature-first organization with presentation/domain/data layers:

- **`auth/`**: Authentication and user management
  - `presentation/`: Login screens and UI
  - `domain/`: Auth business logic
  - `data/`: Auth data sources

- **`timeclock/`**: Employee time tracking
- **`estimates/`**: Quote generation
- **`invoices/`**: Payment management
- **Additional features...**

### Design System (`lib/design`)
Material Design 3 theme configuration and design tokens

### Application (`lib/app`)
- `app.dart`: Root widget configuration
- `router.dart`: Go Router navigation setup

## State Management
Uses **Riverpod** for dependency injection and state management (per ADR-0004)

## Import Convention
All cross-feature imports must use package imports:
```dart
import 'package:sierra_painting/core/services/haptic_service.dart';
import 'package:sierra_painting/features/auth/presentation/login_screen.dart';
```

Never use relative imports for cross-feature dependencies.

## Firebase Integration
- **Authentication**: Firebase Auth for user sign-in
- **Database**: Cloud Firestore with offline persistence
- **Storage**: Firebase Storage for images
- **Functions**: Cloud Functions for backend logic
- **Analytics**: Firebase Analytics for usage tracking
- **Crashlytics**: Firebase Crashlytics for error reporting
- **Performance**: Firebase Performance for monitoring

## Offline-First Architecture
The app supports offline operation with automatic synchronization:

1. User actions are queued locally via `queue_service.dart`
2. Hive is used for local data persistence
3. When connectivity is restored, queued operations sync automatically
4. UI shows sync status via `sync_status_chip.dart`

## Testing Strategy
- **Unit tests**: `test/` directory mirrors `lib/` structure
- **Integration tests**: `integration_test/` for end-to-end flows
- **Smoke tests**: Fast health checks in CI pipeline

## CI/CD Pipeline
GitHub Actions workflows:
- Code quality checks (format, analyze)
- Unit and integration tests
- Firestore rules validation
- Security scanning
- Smoke tests

## Security
- Service account keys are never committed
- Firestore rules enforce data access policies
- App Check validates client authenticity
- All API calls use authentication tokens
