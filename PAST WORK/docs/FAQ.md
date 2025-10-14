# FAQ

Frequently asked questions about Sierra Painting.

## General

### What is Sierra Painting?

Sierra Painting is a mobile-first business management application for painting companies. It helps
manage operations, projects, estimates, invoices, and payments.

### Who is it for?

Small to medium painting businesses that need offline-capable field tools and streamlined office
operations.

### What platforms does it support?

- Android (primary)
- iOS (planned)
- Web (admin features only)

## Development

### How do I get started?

See the [Getting started tutorial](tutorials/getting-started.md).

### Do I need a Firebase account?

Yes, you need a Firebase project for development. The free Spark plan is sufficient for local
development with emulators.

### Can I develop offline?

Yes! Firebase emulators run locally. You only need internet for initial setup and deployment.

### What's the difference between staging and production?

- **Staging**: Auto-deploys from `main` branch, used for testing
- **Production**: Manual deployment after approval, serves real users

### How do I run tests?

See [Run tests](how-to/run-tests.md).

## Architecture

### Why Flutter and Firebase?

See [Why Flutter and Firebase](explanation/why-flutter-firebase.md) and
[ADR-0001](ADRs/0001-tech-stack.md).

### What is offline-first architecture?

Apps work offline by default, queueing changes locally. When connectivity returns, changes sync to
the server. See [Offline-first design](explanation/offline-first.md).

### How does authentication work?

Firebase Authentication with email/password. Role-Based Access Control (RBAC) is enforced through:

- Custom claims in Firebase Auth
- Firestore security rules
- Route guards in the app

### How are payments handled?

Manual payments (check/cash) are primary. Stripe integration is optional. See
[Payment architecture](explanation/payment-architecture.md).

## Security

### How do I report a security vulnerability?

See [SECURITY.md](../SECURITY.md).

### Are credentials stored in the repository?

No. All credentials use environment variables or GitHub secrets. Service account keys are never
committed.

### What is App Check?

Firebase App Check protects backend APIs from abuse by verifying requests come from your authentic
app. See [Configure App Check](how-to/configure-app-check.md).

## Deployment

### How do I deploy to staging?

See [Deploy to staging](how-to/deploy-staging.md).

### How do I deploy to production?

See [Deploy to production](how-to/deploy-production.md).

### What if something breaks in production?

See [Roll back a deployment](how-to/rollback-deployment.md).

### How do I enable a feature flag?

Feature flags are managed through Firebase Remote Config. See
[Use feature flags](how-to/use-feature-flags.md).

## Troubleshooting

### Emulators won't start

Check if ports are already in use:

```bash
lsof -ti:4000,8080,9099,5001,9199 | xargs kill -9
firebase emulators:start --clean
```

### Flutter build fails

```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Functions deployment fails

```bash
cd functions
rm -rf node_modules lib
npm ci
npm run build
cd ..
firebase deploy --only functions
```

### Tests fail with "Cannot connect to Firebase"

Ensure emulators are running in a separate terminal:

```bash
firebase emulators:start
```

## Contributing

### How do I contribute?

See [CONTRIBUTING.md](../CONTRIBUTING.md).

### What's the code style?

Follow Dart/Flutter conventions. Run `flutter analyze` before committing.

### How do I write commit messages?

Use Conventional Commits format. See [CONTRIBUTING.md](../CONTRIBUTING.md).

---