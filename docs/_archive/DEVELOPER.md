# Developer Guide — Sierra Painting

> **Last Updated:** 2024-10-04  
> **Status:** Production-Ready

---

## Overview

This guide covers contribution guidelines, code style, development workflow, and state management decisions for Sierra Painting developers.

---

## Table of Contents

1. [Getting Started](#getting-started)
2. [Development Workflow](#development-workflow)
3. [Code Style](#code-style)
4. [State Management](#state-management)
5. [Testing Guidelines](#testing-guidelines)
6. [Pull Request Process](#pull-request-process)
7. [Branching Strategy](#branching-strategy)

---

## Getting Started

### Quick Setup

See the [README.md](README.md) for complete setup instructions.

**TL;DR:**
```bash
git clone https://github.com/juanvallejo97/Sierra-Painting-v1.git
cd Sierra-Painting-v1
flutter pub get
cd functions && npm ci && cd ..
firebase emulators:start  # Terminal 1
flutter run               # Terminal 2
```

### Required Tools

- **Flutter SDK** ≥ 3.8.0
- **Dart SDK** ≥ 3.8.0
- **Node.js** ≥ 18
- **Firebase CLI** - `npm install -g firebase-tools@13.23.1`
- **Git**
- **VS Code** (recommended) or your preferred IDE

### Recommended VS Code Extensions

- Dart
- Flutter
- ESLint
- Prettier
- Error Lens
- GitLens

---

## Development Workflow

### Story-Driven Development

We use story-driven development with clear acceptance criteria:

1. **Pick a story** from the backlog (see `docs/stories/`)
2. **Read thoroughly**: User story, acceptance criteria, data models
3. **Check dependencies**: Ensure prerequisite stories are complete
4. **Create feature branch**: `git checkout -b feature/B1-clock-in`
5. **Write tests first** (TDD approach)
6. **Implement minimal code** to pass tests
7. **Verify locally** with emulators
8. **Commit with story reference**: `feat(B1): implement offline clock-in`
9. **Create PR** with story link
10. **Address review feedback**
11. **Merge and close story**

See [docs/DEVELOPER_WORKFLOW.md](docs/DEVELOPER_WORKFLOW.md) for detailed workflow.

### Test-Driven Development (TDD)

Follow the Red-Green-Refactor cycle:

**Step 1: RED** - Write a failing test
```dart
test('should create time entry with GPS', () async {
  final result = await clockInService.clockIn(
    jobId: 'job123',
    timestamp: DateTime.now(),
    location: Location(lat: 37.7749, lng: -122.4194),
  );
  
  expect(result.isSuccess, true);
});
```

**Step 2: GREEN** - Write minimal code to pass
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

**Step 3: REFACTOR** - Improve code quality
- Extract methods
- Remove duplication
- Improve naming
- Add documentation

---

## Code Style

### Dart / Flutter

**Follow Official Guidelines:**
- [Effective Dart](https://dart.dev/guides/language/effective-dart)
- [Flutter Style Guide](https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo)

**Key Conventions:**

```dart
// ✅ Good: Clear naming, const constructor
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
        subtitle: Text(invoice.clientName),
        onTap: onTap,
      ),
    );
  }
}

// ❌ Bad: No const, unclear naming
class IC extends StatelessWidget {
  IC(this.i, this.c);
  Invoice i;
  Function? c;
  
  Widget build(context) {
    return Card(child: ListTile(title: Text(i.number), onTap: c));
  }
}
```

**Import Conventions:**

```dart
// ✅ Good: Package imports for cross-feature references
import 'package:sierra_painting/core/services/haptic_service.dart';
import 'package:sierra_painting/features/auth/domain/models/user.dart';

// ✅ Good: Relative imports within same feature
import '../domain/models/invoice.dart';
import '../data/repositories/invoice_repository.dart';

// ❌ Bad: Deep relative imports across features
import '../../../auth/domain/models/user.dart';
```

**Formatting:**
```bash
# Auto-format all Dart files
dart format .

# Check formatting without applying
dart format --output=none --set-exit-if-changed .
```

**Linting:**
```bash
# Run Dart analyzer
flutter analyze

# With strict mode
flutter analyze --fatal-infos
```

### TypeScript / Cloud Functions

**Follow Official Guidelines:**
- [TypeScript Style Guide](https://google.github.io/styleguide/tsguide.html)
- [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript)

**Key Conventions:**

```typescript
// ✅ Good: Clear types, validation
export const createInvoice = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // Validate with Zod
  const input = invoiceSchema.parse(data);

  const invoice = await db.collection('invoices').add({
    ...input,
    createdBy: context.auth.uid,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, invoiceId: invoice.id };
});

// ❌ Bad: No validation, unclear types
export const ci = functions.https.onCall(async (d, c) => {
  const i = await db.collection('invoices').add(d);
  return i.id;
});
```

**Formatting & Linting:**
```bash
cd functions

# Format with Prettier
npm run format

# Lint with ESLint
npm run lint

# Type check
npm run typecheck
```

---

## State Management

### Riverpod Architecture

**Decision:** We use [Riverpod](https://riverpod.dev/) for state management (see [ADR-0004](docs/adrs/0004-riverpod-state-management.md)).

**Rationale:**
- Compile-safe dependency injection
- Better testability than Provider
- Great DevTools integration
- Minimal boilerplate

### Provider Types

**Provider** - Immutable dependencies:
```dart
final hapticServiceProvider = Provider<HapticService>((ref) {
  return HapticService(ref);
});
```

**StateProvider** - Simple mutable state:
```dart
final counterProvider = StateProvider<int>((ref) => 0);

// Usage
final count = ref.watch(counterProvider);
ref.read(counterProvider.notifier).state++;
```

**FutureProvider** - Async data:
```dart
final invoiceProvider = FutureProvider.family<Invoice, String>((ref, id) async {
  return ref.read(invoiceRepositoryProvider).getInvoice(id);
});
```

**StreamProvider** - Real-time data:
```dart
final invoicesStreamProvider = StreamProvider<List<Invoice>>((ref) {
  return ref.read(invoiceRepositoryProvider).watchInvoices();
});
```

**StateNotifierProvider** - Complex state:
```dart
class InvoiceListNotifier extends StateNotifier<AsyncValue<List<Invoice>>> {
  InvoiceListNotifier(this.ref) : super(const AsyncValue.loading()) {
    _fetchInvoices();
  }

  final Ref ref;

  Future<void> _fetchInvoices() async {
    try {
      final invoices = await ref.read(invoiceRepositoryProvider).getInvoices();
      state = AsyncValue.data(invoices);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final invoiceListProvider = StateNotifierProvider<InvoiceListNotifier, AsyncValue<List<Invoice>>>((ref) {
  return InvoiceListNotifier(ref);
});
```

### Naming Conventions

- **Services**: `xxxServiceProvider` (e.g., `hapticServiceProvider`)
- **Repositories**: `xxxRepositoryProvider` (e.g., `invoiceRepositoryProvider`)
- **Data providers**: `xxxProvider` (e.g., `currentUserProvider`)
- **State notifiers**: `xxxNotifierProvider` (e.g., `invoiceListNotifierProvider`)

---

## Testing Guidelines

### Test Structure

```
test/
├── core/
│   ├── services/
│   │   └── haptic_service_test.dart
│   └── utils/
│       └── result_test.dart
└── features/
    ├── auth/
    │   └── login_screen_test.dart
    └── invoices/
        ├── data/
        │   └── invoice_repository_test.dart
        └── presentation/
            └── invoice_list_screen_test.dart
```

### Unit Tests

Test individual functions and classes in isolation:

```dart
void main() {
  group('HapticService', () {
    late HapticService service;

    setUp(() {
      service = HapticService();
    });

    test('should provide light impact', () {
      expect(() => service.lightImpact(), returnsNormally);
    });

    test('should handle disabled haptics gracefully', () {
      service.setEnabled(false);
      expect(() => service.lightImpact(), returnsNormally);
    });
  });
}
```

### Widget Tests

Test UI components:

```dart
void main() {
  testWidgets('InvoiceCard displays invoice info', (tester) async {
    final invoice = Invoice(
      id: '1',
      number: 'INV-001',
      clientName: 'John Doe',
      amount: 500.0,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InvoiceCard(invoice: invoice),
        ),
      ),
    );

    expect(find.text('INV-001'), findsOneWidget);
    expect(find.text('John Doe'), findsOneWidget);
  });
}
```

### Integration Tests

Test complete user flows:

```dart
void main() {
  testWidgets('User can create and view invoice', (tester) async {
    await tester.pumpWidget(const MyApp());
    
    // Navigate to invoice creation
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    
    // Fill form
    await tester.enterText(find.byKey(const Key('clientName')), 'John Doe');
    await tester.enterText(find.byKey(const Key('amount')), '500');
    
    // Submit
    await tester.tap(find.text('Create Invoice'));
    await tester.pumpAndSettle();
    
    // Verify
    expect(find.text('Invoice Created'), findsOneWidget);
  });
}
```

### Coverage Goals

- Core services: ≥ 80%
- Repositories: ≥ 80%
- Widgets: ≥ 60%
- Overall: ≥ 70%

**Run with coverage:**
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## Pull Request Process

### Before Creating PR

- [ ] All tests passing locally
- [ ] Code formatted (`dart format .`)
- [ ] No analyzer warnings (`flutter analyze`)
- [ ] Coverage requirements met
- [ ] Documentation updated
- [ ] Manual testing completed

### PR Checklist

- [ ] Descriptive title (follows conventional commits)
- [ ] Linked to issue or story
- [ ] Description explains what and why
- [ ] Screenshots/videos for UI changes
- [ ] Breaking changes documented
- [ ] Tests added/updated
- [ ] CI passing

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(invoices): add PDF export functionality
fix(auth): resolve token refresh issue
docs(readme): update setup instructions
chore(deps): upgrade firebase_core to 2.20.0
test(invoices): add integration tests for creation flow
```

**Format:**
```
<type>(<scope>): <subject>

<body (optional)>

<footer (optional)>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Code style (formatting, no logic change)
- `refactor`: Code refactoring
- `test`: Adding/updating tests
- `chore`: Maintenance (deps, config)
- `ci`: CI/CD changes

---

## Branching Strategy

### Branch Naming

```
feature/<story-id>-<short-description>
fix/<issue-id>-<short-description>
docs/<description>
chore/<description>
```

**Examples:**
```
feature/B1-clock-in-offline
fix/123-invoice-pdf-rendering
docs/update-architecture
chore/upgrade-dependencies
```

### Branch Lifecycle

1. Create from `main`: `git checkout -b feature/B1-clock-in`
2. Develop and commit regularly
3. Keep up to date: `git pull origin main --rebase`
4. Push and create PR
5. Address review feedback
6. Squash and merge (or rebase merge)
7. Delete branch after merge

### Main Branch Protection

- Requires PR approval
- CI must pass
- No direct commits to `main`
- Linear history preferred

---

## Code of Conduct

By contributing, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

---

## Additional Resources

- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [docs/DEVELOPER_WORKFLOW.md](docs/DEVELOPER_WORKFLOW.md) - Detailed workflow guide
- [docs/Testing.md](docs/Testing.md) - Testing strategy
- [docs/adrs/](docs/adrs/) - Architecture Decision Records
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guidelines
