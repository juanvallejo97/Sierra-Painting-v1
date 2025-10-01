# Sierra Painting Documentation

Welcome to the Sierra Painting documentation! This directory contains all the documentation you need to understand, set up, and contribute to the project.

## Quick Links

### Getting Started
- **[QUICKSTART.md](../QUICKSTART.md)** - Get up and running in 5 minutes
- **[SETUP.md](../SETUP.md)** - Comprehensive setup guide
- **[README.md](../README.md)** - Project overview and features

### Understanding the Project
- **[ARCHITECTURE.md](../ARCHITECTURE.md)** - System architecture and design
- **[CHANGELOG.md](../CHANGELOG.md)** - Version history and changes

### Contributing
- **[CONTRIBUTING.md](../CONTRIBUTING.md)** - How to contribute to the project

## Documentation Structure

```
docs/
├── index.md                    # This file
├── getting-started/           # Setup and configuration guides
├── features/                  # Feature-specific documentation
├── api/                       # API documentation
└── deployment/                # Deployment guides
```

## Key Technologies

- **Frontend**: Flutter (Dart) with Material Design 3
- **Backend**: Firebase (Auth, Firestore, Storage, Functions)
- **Functions**: TypeScript with Zod validation
- **State Management**: Provider
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

## Common Tasks

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

---

Last updated: 2024-10-01
