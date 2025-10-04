# Development Guide — Sierra Painting

> **Purpose**: Local setup, development workflow, code style, and contribution guidelines  
> **Last Updated**: 2024  
> **Status**: Production-Ready

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Development Workflow](#development-workflow)
3. [Code Style](#code-style)
4. [Testing Guidelines](#testing-guidelines)
5. [Commit Conventions](#commit-conventions)
6. [Pull Request Process](#pull-request-process)
7. [Troubleshooting](#troubleshooting)

---

## Getting Started

### Prerequisites

**Required Tools**:
- **Flutter SDK** ≥ 3.8.0 — [Install](https://flutter.dev/docs/get-started/install)
- **Dart SDK** ≥ 3.8.0 (bundled with Flutter)
- **Node.js** ≥ 18 — [Install](https://nodejs.org/)
- **Firebase CLI** — `npm install -g firebase-tools`
- **Git** and a code editor (VS Code recommended)

**Recommended VS Code Extensions**:
- Dart
- Flutter
- ESLint
- Prettier
- Error Lens
- GitLens

---

### Initial Setup

**1. Clone and Install Dependencies**

```bash
# Clone repository
git clone https://github.com/juanvallejo97/Sierra-Painting-v1.git
cd Sierra-Painting-v1

# Install Flutter dependencies
flutter pub get

# (Optional) Generate code
flutter pub run build_runner build --delete-conflicting-outputs

# Install Functions dependencies
cd functions
npm ci
cd ..
```

**2. Firebase Setup**

```bash
# Login to Firebase
firebase login

# Select project
firebase use default

# Or use specific environment
firebase use staging  # or dev, production
```

**3. Start Emulators**

```bash
# Terminal 1: Start Firebase emulators
firebase emulators:start

# This starts:
# - Auth emulator (port 9099)
# - Firestore emulator (port 8080)
# - Functions emulator (port 5001)
# - Storage emulator (port 9199)
# - Emulator UI (port 4000)
```

**4. Run Application**

```bash
# Terminal 2: Run Flutter app
flutter run

# Or run on specific device
flutter devices
flutter run -d chrome  # Web
flutter run -d <device-id>  # Mobile device
```

**5. Verify Setup**

```bash
# Flutter
flutter doctor
flutter analyze
flutter test

# Functions
cd functions
npm run typecheck
npm run lint
npm run build
npm test
```

---

## Development Workflow

### Story-Driven Development

We use **story-driven development** with clear acceptance criteria:

1. **Pick a story** from backlog (`docs/Backlog.md` or GitHub Issues)
2. **Read thoroughly**: User story, acceptance criteria, data models, dependencies
3. **Create feature branch**: `git checkout -b feat/B1-clock-in`
4. **Write tests first** (TDD approach)
5. **Implement minimal code** to pass tests
6. **Verify locally** with emulators
7. **Commit with story reference**: `feat(B1): implement offline clock-in`
8. **Create PR** with story link and description
9. **Address review feedback**
10. **Merge and close story**

---

### Test-Driven Development (TDD)

Follow the **Red-Green-Refactor** cycle:

**Step 1: RED** — Write a failing test
```dart
test('should create time entry with GPS', () async {
  final result = await clockInService.clockIn(
    jobId: 'job123',
    timestamp: DateTime.now(),
    location: Location(lat: 37.7749, lng: -122.4194),
  );
  
  expect(result.isSuccess, true);
  expect(result.data.jobId, 'job123');
});
```

**Step 2: GREEN** — Write minimal code to pass
```dart
Future<Result<TimeEntry>> clockIn({
  required String jobId,
  required DateTime timestamp,
  required Location location,
}) async {
  final entry = TimeEntry(
    jobId: jobId,
    clockInTime: timestamp,
    location: location,
  );
  await repository.save(entry);
  return Result.success(entry);
}
```

**Step 3: REFACTOR** — Improve code quality
- Extract methods
- Remove duplication
- Improve naming
- Add documentation

---

### Local Testing

**Unit Tests**:
```bash
# Run all Flutter tests
flutter test

# Run with coverage
flutter test --coverage

# View coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

**Integration Tests**:
```bash
# Run integration tests
flutter test integration_test/

# Or with specific device
flutter test integration_test/ -d chrome
```

**Firestore Rules Tests**:
```bash
cd firestore-tests
npm test
```

**Functions Tests**:
```bash
cd functions
npm test
```

**Smoke Tests** (End-to-End):
```bash
# Run smoke tests
flutter test integration_test/app_smoke_test.dart

# Or via Makefile
make smoke
```

---

## Code Style

### Dart/Flutter

Follow **[Effective Dart](https://dart.dev/guides/language/effective-dart)** and **[Flutter Style Guide](https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo)**.

**Key Conventions**:

```dart
// ✅ Good: Clear naming, const constructor, proper formatting
class InvoiceCard extends StatelessWidget {
  const InvoiceCard({
    required this.invoice,
    this.onTap,
    super.key,
  });

  final Invoice invoice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(invoice.number),
        subtitle: Text('\$${invoice.total.toStringAsFixed(2)}'),
        trailing: invoice.paid
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.pending, color: Colors.orange),
        onTap: onTap,
      ),
    );
  }
}
```

**File Headers** (for complex files):
```dart
/// Time clock service for crew time tracking.
///
/// **Responsibilities**:
/// - Clock in/out operations
/// - GPS validation
/// - Offline queue management
///
/// **Invariants**:
/// - Cannot clock in to multiple jobs simultaneously
/// - Clock out requires prior clock in
///
/// **Performance**: O(1) for clock operations (cached)
library;
```

**Formatting**:
```bash
# Format all Dart code
dart format .

# Check formatting without changes
dart format --output=none --set-exit-if-changed .
```

**Linting**:
```bash
# Run analyzer
flutter analyze

# Fix auto-fixable issues
dart fix --apply
```

---

### TypeScript/JavaScript (Functions)

Follow **[Google TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html)**.

**Key Conventions**:

```typescript
// ✅ Good: Type-safe, documented, error handling
/**
 * Marks an invoice as paid (admin-only).
 *
 * @param data - Invoice ID and payment details
 * @param context - Callable function context
 * @returns Payment record
 */
export const markInvoicePaid = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    // Auth check
    if (!context.auth) {
      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be authenticated'
      );
    }

    // Validate input with Zod
    const { invoiceId, amount, method } = markPaidSchema.parse(data);

    // Business logic
    const payment = await createPayment({
      invoiceId,
      amount,
      method,
      processedBy: context.auth.uid,
    });

    // Audit log
    await auditLog({
      action: 'mark_invoice_paid',
      userId: context.auth.uid,
      entityType: 'invoice',
      entityId: invoiceId,
    });

    return payment;
  });
```

**Linting**:
```bash
cd functions
npm run lint
npm run lint:fix
```

**Type Checking**:
```bash
cd functions
npm run typecheck
```

---

## Testing Guidelines

### Test Structure

```dart
// Good test structure
group('ClockInService', () {
  late ClockInService service;
  late MockTimeclockRepository repository;

  setUp(() {
    repository = MockTimeclockRepository();
    service = ClockInService(repository);
  });

  group('clockIn', () {
    test('should create time entry with valid data', () async {
      // Arrange
      final jobId = 'job123';
      final timestamp = DateTime.now();
      when(() => repository.save(any())).thenAnswer((_) async => unit);

      // Act
      final result = await service.clockIn(
        jobId: jobId,
        timestamp: timestamp,
      );

      // Assert
      expect(result.isSuccess, true);
      expect(result.data.jobId, jobId);
      verify(() => repository.save(any())).called(1);
    });

    test('should fail if already clocked in', () async {
      // Arrange
      when(() => repository.getActiveEntry(any())).thenAnswer(
        (_) async => Some(TimeEntry(...)),
      );

      // Act
      final result = await service.clockIn(jobId: 'job123');

      // Assert
      expect(result.isFailure, true);
      expect(result.error, 'Already clocked in to another job');
    });
  });
});
```

### Test Coverage Goals

- **Unit tests**: 80%+ coverage
- **Widget tests**: Critical UI components
- **Integration tests**: Key user journeys
- **Rules tests**: All security rules
- **Functions tests**: All callable functions

---

## Commit Conventions

Use **[Conventional Commits](https://www.conventionalcommits.org/)** format:

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `chore`: Maintenance tasks
- `refactor`: Code refactoring
- `test`: Test additions/changes
- `ci`: CI/CD changes
- `perf`: Performance improvements

**Scopes**:
- `auth`: Authentication
- `timeclock`: Time tracking
- `estimates`: Estimates feature
- `invoices`: Invoicing feature
- `admin`: Admin dashboard
- `functions`: Cloud Functions
- `rules`: Firestore rules

**Examples**:
```bash
feat(timeclock): add GPS validation for clock in
fix(invoices): correct tax calculation rounding error
docs(deployment): update canary rollout procedures
chore(deps): upgrade Flutter to 3.10.0
refactor(auth): extract user role helpers
test(rules): add tests for time entry access
ci(workflows): add automated dependency updates
perf(db): optimize job list query with composite index
```

---

## Pull Request Process

### Before Creating PR

- [ ] All tests pass locally (`flutter test`, `npm test`)
- [ ] Code formatted (`dart format .`, `npm run lint`)
- [ ] No analyzer warnings (`flutter analyze`)
- [ ] Documentation updated (if needed)
- [ ] Feature flag configured (if new feature)
- [ ] Migration plan documented (if breaking change)

---

### PR Template

Use the following template:

```markdown
## What
Brief description of changes

## Why
Why this change is needed

## How
How the change was implemented

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Smoke tests passed
- [ ] Tested on emulators
- [ ] Tested on physical device (Android/iOS)

## Checklist
- [ ] Code formatted and linted
- [ ] Tests pass
- [ ] Documentation updated
- [ ] No secrets in code
- [ ] Feature flag added (if applicable)
- [ ] Migration notes documented (if applicable)

## Screenshots
(if UI changes)

## Related Issues
Closes #123
Relates to #456
```

---

### Code Review Guidelines

**As a reviewer**:
- Check for security issues (auth, data validation, secrets)
- Verify tests cover edge cases
- Ensure code follows style guide
- Look for performance anti-patterns (N+1 queries, unbounded lists)
- Provide constructive feedback

**As an author**:
- Respond to all comments
- Address feedback or explain why not
- Keep PRs small and focused (< 500 lines)
- Link related stories/issues

---

## Troubleshooting

### Flutter Issues

**Issue**: `flutter doctor` reports errors

**Solution**:
```bash
# Update Flutter
flutter upgrade

# Clear cache
flutter clean
flutter pub get

# Re-run doctor
flutter doctor -v
```

---

**Issue**: Build fails with Gradle errors (Android)

**Solution**:
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk
```

---

**Issue**: iOS build fails

**Solution**:
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter build ios
```

---

### Firebase Issues

**Issue**: Emulators fail to start

**Solution**:
```bash
# Kill existing emulator processes
lsof -ti:4000 | xargs kill -9  # Emulator UI
lsof -ti:8080 | xargs kill -9  # Firestore
lsof -ti:9099 | xargs kill -9  # Auth

# Clear emulator data
rm -rf ~/.cache/firebase/emulators

# Restart
firebase emulators:start
```

---

**Issue**: Functions deployment fails

**Solution**:
```bash
cd functions

# Clear build cache
rm -rf lib node_modules

# Reinstall and rebuild
npm ci
npm run build

# Deploy
firebase deploy --only functions
```

---

### Common Errors

**Error**: "No Firebase App '[DEFAULT]' has been created"

**Solution**: Ensure `Firebase.initializeApp()` is called in `main.dart` before any Firebase usage.

---

**Error**: "Null check operator used on a null value"

**Solution**: Check for null before using `!` operator. Use `?.` or `??` instead:
```dart
// Bad
final name = user!.displayName;

// Good
final name = user?.displayName ?? 'Unknown';
```

---

**Error**: "MissingPluginException"

**Solution**:
```bash
flutter clean
flutter pub get
flutter run
```

---

## Related Documentation

- [README.md](../README.md) - Project overview and quick start
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture
- [TESTING.md](./Testing.md) - Detailed testing guide
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Deployment procedures
- [SECURITY.md](./SECURITY.md) - Security guidelines
- [docs/DEVELOPER_WORKFLOW.md](./DEVELOPER_WORKFLOW.md) - Detailed workflow

---

## Support

For development questions:
1. Check this guide and related docs
2. Review existing code for examples
3. Check GitHub Issues for similar problems
4. Ask in team chat
5. Open a new issue if unresolved

---

**Last Updated**: 2024  
**Owner**: Engineering Team  
**Review Schedule**: Quarterly
