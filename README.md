# Sierra Painting - Project Sienna

A modern Flutter-based painting application for small business management with Firebase backend.

## Overview

Sierra Painting is a mobile-first application built with Flutter and Firebase, designed to help small painting businesses manage their operations, projects, and payments efficiently.

## Tech Stack

### Frontend
- **Flutter** (Material Design 3)
- **Mobile-first** design approach
- **Offline-first** architecture using Hive
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

## Project Structure

```
sierra_painting/
├── lib/
│   ├── core/
│   │   ├── config/           # App configuration
│   │   ├── services/         # Core services (offline, feature flags)
│   │   └── utils/            # Utility functions
│   ├── features/             # Feature modules
│   └── shared/               # Shared widgets and components
├── functions/
│   └── src/
│       ├── index.ts          # Main Cloud Functions
│       └── stripe/           # Stripe webhook handlers
├── test/                     # Flutter tests
├── firestore.rules           # Firestore security rules (deny-by-default)
├── storage.rules             # Storage security rules
└── firebase.json             # Firebase configuration
```

## Getting Started

### Prerequisites
- Flutter SDK 3.19.0 (includes Dart 3.3.0)
- Node.js 18+
- Firebase CLI
- Git

### Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/juanvallejo97/Sierra-Painting-v1.git
   cd Sierra-Painting-v1
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Install Firebase Functions dependencies**
   ```bash
   cd functions
   npm install
   cd ..
   ```

4. **Configure Firebase**
   ```bash
   # Install Firebase CLI if not already installed
   npm install -g firebase-tools
   
   # Login to Firebase
   firebase login
   
   # Initialize Firebase in your project
   firebase init
   
   # Generate Firebase configuration for Flutter
   flutterfire configure
   ```

5. **Set up environment variables**
   ```bash
   cd functions
   cp .env.example .env
   # Edit .env with your actual values
   ```

### Running the App

```bash
# Run in debug mode
flutter run

# Run tests
flutter test

# Build for production
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

### Local verification checklist

Run these commands before pushing changes to ensure CI parity:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart format .
flutter analyze
flutter test
```

### Deploying Cloud Functions

```bash
cd functions
npm run build
firebase deploy --only functions
```

### Deploying Firestore Rules

```bash
firebase deploy --only firestore:rules
firebase deploy --only storage:rules
```

## Key Features

### Security
- **Deny-by-default** Firestore security rules
- **App Check** for API abuse prevention
- **Role-based access control** (admin, user)
- **Audit trails** for all payment operations

### Offline Support
- Local caching with Hive
- Automatic sync when online
- Pending operations queue

### Accessibility
- WCAG 2.2 AA compliant
- Minimum 48x48 touch targets
- Proper semantic labels
- Text scaling support (up to 130%)

### Payment Processing
- Manual check/cash payments with admin approval
- Optional Stripe integration (feature flag controlled)
- Idempotent webhook handlers
- Complete audit trail

## CI/CD

The project includes GitHub Actions workflows for:
- **Flutter CI**: Linting, testing, and building
- **Functions CI**: TypeScript compilation and linting
- **Security**: Dependency audits and rules validation

## Development

### Code Style
- Flutter: Uses `analysis_options.yaml` with strict linting
- TypeScript: ESLint with Google style guide
- Formatting: `flutter format` for Dart code

### Testing
```bash
# Run Flutter tests
flutter test

## Development

### Running Tests
```bash
# Flutter tests
flutter test

# Functions tests
main
cd functions
npm test
```

### Linting
```bash
# Lint Flutter code
flutter analyze

# Functions
main
cd functions
npm run lint
```

## Feature Flags

Feature flags are managed via Firebase Remote Config:
- `stripe_enabled`: Enable/disable Stripe payments (default: false)
- `offline_mode_enabled`: Enable/disable offline mode (default: true)

## Performance

- Target: P95 latency < 2s for critical operations
- Offline-first for instant UI response
- Optimistic updates with background sync


## Contributing

1. Create a feature branch
2. Make your changes
3. Run tests and linting
4. Submit a pull request

## License


Copyright © 2024 Sierra Painting. All rights reserved.

## Support
For issues or questions, please open an issue on GitHub. 
