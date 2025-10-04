# Sierra Painting Documentation

Welcome to the Sierra Painting documentation! This directory contains all the documentation you need to understand, set up, and contribute to the project.

## Canonical Navigation

This documentation follows the [Diátaxis](https://diataxis.fr/) framework for clarity and ease of navigation.

### 🚀 Getting Started (Tutorials)
- **[README](../README.md)** - Quickstart guide to get running in minutes

### 📖 Reference Documentation
- **[ARCHITECTURE](../ARCHITECTURE.md)** - System components, flows, and ADR index
- **[SECURITY](../SECURITY.md)** - Threat model and security rules testing
- **[Testing](./Testing.md)** - Testing strategy and guidelines

### 🔧 How-To Guides (Operational)
- **[DEPLOYMENT_INSTRUCTIONS](../DEPLOYMENT_INSTRUCTIONS.md)** - Comprehensive deployment guide with environment setup scripts
- **[OPERATIONS](../OPERATIONS.md)** - Deploy, rollback, monitoring, and SLOs
- **[DEVELOPER](../DEVELOPER.md)** - Development workflow, code style, and contribution guidelines
- **[EMULATORS](./EMULATORS.md)** - Local development with Firebase Emulators
- **[FEATURE_FLAGS](./FEATURE_FLAGS.md)** - Feature flag management
- **[iOS Deployment](./IOS_DEPLOYMENT.md)** - Complete iOS deployment guide with App Store submission
- **[Android Staged Rollout](./ANDROID_STAGED_ROLLOUT.md)** - Android deployment and Play Store rollout
- **[Deployment Checklist](./deployment_checklist.md)** - Pre-deployment, deployment, and post-deployment checklists

### 💡 Explanation (Understanding)
- **[Migration Guide](./MIGRATION.md)** - V1 refactoring and migration notes
- **[EnhancementsAndAdvice](./EnhancementsAndAdvice.md)** - Performance recommendations
- **[ui_overhaul_mobile](./ui_overhaul_mobile.md)** - UI/UX overhaul specification

### 📚 Additional Resources
- **[ADRs](./adrs/)** - Architecture Decision Records with template
- **[Stories](./stories/)** - User stories organized by sprint
- **[Operations](./ops/)** - Detailed operational guides and runbooks

## Key Technologies

- **Frontend**: Flutter (Dart) with Material Design 3
- **Backend**: Firebase (Auth, Firestore, Storage, Functions)
- **Functions**: TypeScript with Zod validation
- **State Management**: Riverpod (see [ADR-0004](./adrs/0004-riverpod-state-management.md))
- **Local Storage**: Hive (offline-first)
- **Payments**: Manual (check/cash) + Optional Stripe

## Project Structure Overview

```
Sierra-Painting-v1/
├── lib/                       # Flutter application code
│   ├── core/                 # Core functionality
│   ├── features/             # Feature modules
│   └── shared/               # Shared components
├── functions/                 # Firebase Cloud Functions
│   └── src/                  # TypeScript source code
├── test/                      # Test files
├── .github/workflows/         # CI/CD pipelines
└── docs/                      # Documentation
```

## Quick Commands

### Development
```bash
flutter run              # Run the app
flutter test            # Run tests
flutter analyze         # Lint code
```

### Firebase
```bash
firebase deploy --only functions    # Deploy functions
firebase deploy --only firestore    # Deploy Firestore rules
firebase functions:log              # View logs
```

### Testing
```bash
flutter test --coverage            # Run with coverage
cd functions && npm test          # Test functions
```

## Support & Community

- **Issues**: [GitHub Issues](https://github.com/juanvallejo97/Sierra-Painting-v1/issues)
- **Discussions**: [GitHub Discussions](https://github.com/juanvallejo97/Sierra-Painting-v1/discussions)

## License

This project is licensed under the MIT License - see [LICENSE](../LICENSE) file for details.

