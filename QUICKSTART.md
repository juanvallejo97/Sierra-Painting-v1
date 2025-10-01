# Quick Start Guide

Get Sierra Painting up and running in minutes!

## Prerequisites

- Flutter SDK 3.0+
- Node.js 18+
- Firebase account
- Git

## 5-Minute Setup

### 1. Clone & Install (2 min)

```bash
# Clone repository
git clone https://github.com/juanvallejo97/Sierra-Painting-v1.git
cd Sierra-Painting-v1

# Install Flutter dependencies
flutter pub get

# Install Functions dependencies
cd functions && npm install && cd ..
```

### 2. Firebase Setup (2 min)

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Create/select project
firebase use --add

# Generate Flutter configuration
flutterfire configure
```

### 3. Deploy Backend (1 min)

```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules,storage:rules

# Build and deploy functions
cd functions && npm run build && cd ..
firebase deploy --only functions
```

### 4. Run the App

```bash
# Start app
flutter run
```

## What You Get

✅ Material Design 3 UI  
✅ Firebase Authentication  
✅ Offline-first storage  
✅ Secure Firestore rules  
✅ Cloud Functions backend  
✅ CI/CD workflows  
✅ Accessibility support  

## Next Steps

1. **Customize Theme**: Edit `lib/core/config/theme_config.dart`
2. **Add Features**: Create modules in `lib/features/`
3. **Configure Payments**: See [SETUP.md](SETUP.md) for payment setup
4. **Deploy**: See [SETUP.md](SETUP.md) for production deployment

## Troubleshooting

**Flutter not found?**
```bash
flutter doctor
```

**Firebase issues?**
```bash
firebase login
firebase projects:list
```

**Build errors?**
```bash
flutter clean
flutter pub get
```

## Get Help

- 📖 [Full Setup Guide](SETUP.md)
- 🏗️ [Architecture](ARCHITECTURE.md)
- 🤝 [Contributing](CONTRIBUTING.md)
- 🐛 [Report Issues](https://github.com/juanvallejo97/Sierra-Painting-v1/issues)

## Common Commands

```bash
# Run app
flutter run

# Run tests
flutter test

# Lint code
flutter analyze

# Format code
flutter format .

# Build release
flutter build apk --release

# Deploy functions
cd functions && npm run build && firebase deploy --only functions

# View logs
firebase functions:log
```

---

**Need more details?** Check out [SETUP.md](SETUP.md) for comprehensive instructions!
