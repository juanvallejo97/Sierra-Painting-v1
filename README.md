# Sierra Painting v1

A comprehensive painting business management application built with Flutter and Firebase.

## Features

- **Time Clock**: Track employee hours with clock in/out functionality
- **Estimates**: Create and manage customer estimates with PDF generation
- **Invoices**: Generate and track invoices with payment processing
- **Admin Panel**: Role-based access control for administrative functions
- **Offline Support**: Works offline with Firestore persistence and Hive queue
- **Material 3 UI**: Modern, responsive design with Material Design 3

## Architecture

### Flutter App
- **State Management**: Riverpod for reactive state management
- **Routing**: go_router with RBAC guards for role-based navigation
- **Local Storage**: Hive for offline queue management
- **Database**: Cloud Firestore with offline persistence enabled

### Folder Structure
```
lib/
├── app/                    # App-level configuration and routing
├── core/                   # Core utilities and shared resources
│   ├── models/            # Shared data models
│   ├── providers/         # Riverpod providers
│   ├── services/          # Core services (queue, etc.)
│   ├── utils/             # Utility functions
│   └── constants/         # App constants
└── features/              # Feature modules
    ├── auth/              # Authentication
    ├── timeclock/         # Time tracking
    ├── estimates/         # Estimates management
    ├── invoices/          # Invoice management
    └── admin/             # Admin panel
```

### Firebase Services

#### Cloud Functions (TypeScript + Zod)
- **createLead**: Create a new customer lead
- **createEstimatePdf**: Generate PDF estimates
- **markPaidManual**: Mark invoices as paid (check/cash) with audit trail
- **createCheckoutSession** (optional): Stripe payment integration
- **stripeWebhook** (optional): Idempotent Stripe webhook handler

#### Security Rules
- **Deny-by-default**: All access denied unless explicitly allowed
- **Invoice Protection**: Clients cannot set `invoice.paid` field
- **Audit Trail**: All payment modifications are logged

## Setup Instructions

### Prerequisites
- Flutter SDK (3.16.0 or higher)
- Firebase CLI
- Node.js (18 or higher)
- A Firebase project

### 1. Clone the Repository
```bash
git clone https://github.com/juanvallejo97/Sierra-Painting-v1.git
cd Sierra-Painting-v1
```

### 2. Configure Firebase

#### Initialize Firebase Project
```bash
firebase login
firebase use --add
```

#### Configure FlutterFire
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for Flutter
flutterfire configure
```

This will update `lib/firebase_options.dart` with your actual Firebase credentials.

#### Deploy Security Rules
```bash
firebase deploy --only firestore:rules,storage:rules
```

### 3. Setup Flutter App
```bash
# Install dependencies
flutter pub get

# Generate code (for Hive adapters)
flutter pub run build_runner build --delete-conflicting-outputs

# Run the app
flutter run
```

### 4. Setup Cloud Functions
```bash
cd functions

# Install dependencies
npm install

# Build TypeScript
npm run build

# Deploy functions
firebase deploy --only functions
```

### 5. Firebase Emulators (Development)
```bash
# Start all emulators
firebase emulators:start

# The emulators will start on:
# - Auth: http://localhost:9099
# - Firestore: http://localhost:8080
# - Functions: http://localhost:5001
# - Storage: http://localhost:9199
# - UI: http://localhost:4000
```

To use emulators in your Flutter app, update the Firebase initialization in `lib/main.dart`:
```dart
// For emulator use
await FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
```

## Development

### Running Tests
```bash
# Flutter tests
flutter test

# Functions tests
cd functions
npm test
```

### Linting
```bash
# Flutter
flutter analyze

# Functions
cd functions
npm run lint
```

### Building for Production
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

## CI/CD

GitHub Actions workflows are configured for:

### Continuous Integration (`ci.yml`)
- Runs on all PRs and pushes
- Flutter: format, analyze, test, build
- Functions: lint, build

### Staging Deployment (`deploy-staging.yml`)
- Triggers on push to `main` branch
- Deploys functions and rules to staging environment

### Production Deployment (`deploy-production.yml`)
- Triggers on version tags (e.g., `v1.0.0`)
- Builds release APK and App Bundle
- Deploys to production Firebase project
- Uploads build artifacts

### Required Secrets
Add these to your GitHub repository secrets:
- `FIREBASE_TOKEN`: Firebase CI token (get via `firebase login:ci`)

## Optional: Stripe Integration

To enable Stripe payment processing:

1. Add Stripe API keys to Firebase config:
```bash
firebase functions:config:set stripe.secret_key="sk_live_..."
```

2. Update the `createCheckoutSession` and `stripeWebhook` functions in `functions/src/index.ts`

3. Add Stripe dependency:
```bash
cd functions
npm install stripe
```

## Security

- **Authentication**: Firebase Authentication required for all operations
- **Authorization**: Role-based access control (RBAC)
- **Firestore Rules**: Deny-by-default with explicit permissions
- **Audit Trail**: All payment modifications logged with user, timestamp, and IP
- **Invoice Protection**: Clients cannot directly modify payment status

## Admin Setup

To grant admin privileges to a user:

1. Create the user account through Firebase Authentication
2. Add a document in the `users` collection:
```json
{
  "email": "admin@example.com",
  "isAdmin": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

## Contributing

1. Create a feature branch
2. Make your changes
3. Run tests and linting
4. Submit a pull request

## License

Copyright © 2024 Sierra Painting. All rights reserved. 
