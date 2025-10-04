# Sierra Painting

[![Staging CI/CD](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/staging.yml/badge.svg)](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/staging.yml)
[![Production CI/CD](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/production.yml/badge.svg)](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/production.yml)
[![Flutter CI](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/ci.yml/badge.svg)](https://github.com/juanvallejo97/Sierra-Painting-v1/actions/workflows/ci.yml)

A mobile-first painting business management app that helps small businesses manage operations,
projects, estimates, invoices, and payments.

## Quickstart

**Expected time**: 5 minutes

**Prerequisites**: Flutter SDK ≥ 3.8.0, Node.js ≥ 18, Firebase CLI

```bash
# Clone and install dependencies
git clone https://github.com/juanvallejo97/Sierra-Painting-v1.git
cd Sierra-Painting-v1
flutter pub get

# Install Cloud Functions dependencies
cd functions && npm ci && cd ..

# Configure Firebase
firebase login
firebase use --add
flutterfire configure

# Start emulators (Terminal 1)
firebase emulators:start

# Run the app (Terminal 2)
flutter run
```

**Expected result**: App opens and connects to local Firebase emulators at
<http://localhost:4000>.

For detailed setup instructions, see [Getting started](docs/tutorials/getting-started.md).

## Key links

- **Documentation**: [docs/](docs/)
- **Contributing**: [CONTRIBUTING.md](CONTRIBUTING.md)
- **Security**: [SECURITY.md](SECURITY.md)
- **Changelog**: [GitHub Releases](https://github.com/juanvallejo97/Sierra-Painting-v1/releases)

## Compatibility

- **Language**: Dart (Flutter ≥ 3.8.0)
- **Backend**: Firebase (Auth, Firestore, Functions, Storage)
- **License**: MIT

## Support

- **Issues**: [GitHub Issues](https://github.com/juanvallejo97/Sierra-Painting-v1/issues)
- **Security reports**: See [SECURITY.md](SECURITY.md)

---

**Copyright © 2024 Sierra Painting**
