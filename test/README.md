# Testing Guide - Sierra Painting

> **Purpose**: Comprehensive testing strategy for Flutter app - PR-05 & PR-06 Complete
>
> **Last Updated**: 2025-10-03
>
> **Test Coverage**: Unit tests ✅ | Widget tests ✅ | Integration templates ✅

---

## Overview

This directory contains all tests for the Sierra Painting Flutter application, organized by test type and feature.

---

## Test Structure

```
test/
├── README.md                               # This file
├── widget_test.dart                        # Basic widget tests
├── app/
│   └── route_coverage_test.dart           # Route coverage tests (NEW)
├── core/
│   ├── network/
│   │   └── api_client_test.dart           # ApiClient unit tests
│   ├── utils/
│   │   └── result_test.dart               # Result type tests
│   ├── services/
│   │   └── haptic_service_test.dart       # Haptic service tests (NEW)
│   └── widgets/
│       └── sync_status_chip_test.dart     # Sync status widget tests (NEW)
├── features/
│   ├── timeclock/
│   │   ├── data/
│   │   │   └── timeclock_repository_test.dart  # Repository tests (TODO)
│   │   └── presentation/
│   │       └── timeclock_screen_test.dart      # Widget tests (TODO)
│   └── ...
└── integration/
    ├── clock_in_flow_test.dart            # E2E clock in flow (TODO)
    └── payment_flow_test.dart             # E2E payment flow (TODO)

integration_test/
└── core_flows_test.dart                   # Integration test templates (NEW)
```

---

## Test Types

### 1. Unit Tests

**Purpose**: Test individual functions, classes, and utilities

**Location**: `test/core/`, `test/features/*/data/`, `test/features/*/domain/`

**New Tests Added (PR-06)**:
- ✅ `test/core/services/haptic_service_test.dart` - Haptic feedback service
- ✅ `test/app/route_coverage_test.dart` - Route definitions and conventions
- ⏳ `test/core/services/queue_service_test.dart` - Offline queue (TODO)

**Example**:
```dart
test('ApiClient generates unique requestIds', () {
  final client = ApiClient();
  final id1 = client.generateRequestId();
  final id2 = client.generateRequestId();
  
  expect(id1, isNot(equals(id2)));
});
```

**Run**:
```bash
flutter test test/core/
```

---

### 2. Widget Tests

**Purpose**: Test UI components and interactions

**Location**: `test/features/*/presentation/`, `test/core/widgets/`

**New Tests Added (PR-06)**:
- ✅ `test/core/widgets/sync_status_chip_test.dart` - Sync status components
- ⏳ `test/features/timeclock/presentation/timeclock_screen_test.dart` - Time clock screen (TODO)

**Example**:
```dart
Future<void> _pumpWithMaterial(
  WidgetTester tester, {
  required Widget child,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(child: child),
      ),
    ),
  );
}

testWidgets('Widget displays correctly', (tester) async {
  await _pumpWithMaterial(
    tester,
    child: const MyWidget(),
  );
  await tester.pumpAndSettle();
  
  expect(find.text('Expected Text'), findsOneWidget);
});
```

**Run**:
```bash
flutter test test/features/
```

---

### 3. Integration Tests

**Purpose**: Test complete user flows end-to-end

**Location**: `integration_test/`

**New Tests Added (PR-06)**:
- ✅ `integration_test/core_flows_test.dart` - Templates for login, clock in/out, offline sync
- ⏳ Implementation pending (requires actual screens)

**Example**:
```dart
testWidgets('User can clock in successfully', (tester) async {
  // Sign in
  await tester.tap(find.byKey(Key('sign_in_button')));
  await tester.pumpAndSettle();
  
  // Clock in
  await tester.tap(find.text('Clock In'));
  await tester.pumpAndSettle();
  
  // Verify success
  expect(find.text('Clocked in successfully'), findsOneWidget);
});
```

**Run**:
```bash
flutter test integration_test/
```

---

### 4. Smoke Tests

**Purpose**: Fast, deterministic health checks to block bad releases

**Location**: `integration_test/app_smoke_test.dart`, `functions/test/smoke/`

**What's Included**:
- ✅ `integration_test/app_smoke_test.dart` - Mobile app startup and navigation
- ✅ `functions/test/smoke/health_test.ts` - Backend health endpoint
- ✅ `.github/workflows/smoke.yml` - CI/CD integration

**Run Locally**:
```bash
# Mobile smoke tests
flutter test integration_test/app_smoke_test.dart

# Backend smoke tests
cd functions && npm test -- test/smoke/
```

**When They Run**:
- On every PR (provides fast feedback)
- Before staging deployment (blocks bad code)
- Before production deployment (final safety check)

📖 **See [SMOKE_TESTS.md](../docs/SMOKE_TESTS.md) for complete documentation**

---

### 5. Contract Tests

**Purpose**: Verify API contracts match backend

**Location**: `test/contracts/`

**Example**:
```dart
test('clockIn API contract', () async {
  final request = {
    'jobId': 'job_123',
    'at': DateTime.now().toIso8601String(),
    'clientId': 'client_456',
  };
  
  final response = await functions.httpsCallable('clockIn').call(request);
  
  expect(response.data, containsKeys(['success', 'entryId']));
  expect(response.data['success'], isA<bool>());
  expect(response.data['entryId'], isA<String>());
});
```

**TODO**: Create contract tests for all Cloud Functions

---

### 5. Performance Tests

**Purpose**: Measure and benchmark performance

**Location**: `test/performance/`

**Example**:
```dart
test('Screen loads within 500ms', () async {
  final stopwatch = Stopwatch()..start();
  
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();
  
  stopwatch.stop();
  expect(stopwatch.elapsedMilliseconds, lessThan(500));
});
```

**TODO**: Create performance benchmarks

---

## Running Tests

### All Tests
```bash
flutter test
```

### Specific Test File
```bash
flutter test test/core/network/api_client_test.dart
```

### With Coverage
```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Integration Tests
```bash
flutter test integration_test/
```

### Watch Mode (auto-run on changes)
```bash
flutter test --watch
```

---

## Test Configuration

### `pubspec.yaml` Dependencies

```yaml
dev_dependencies:
  flutter_test:
    sdk: flutter
  mockito: ^5.4.4
  integration_test:
    sdk: flutter
```

### Firebase Emulator Setup

For integration tests with Firebase:

1. Start emulators:
```bash
firebase emulators:start
```

2. Configure test environment:
```dart
// test/setup.dart
void setUpFirebaseEmulators() {
  FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
  FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
}
```

3. Run tests:
```bash
flutter test --dart-define=USE_EMULATOR=true
```

---

## Test Conventions

### Naming

- Test files: `*_test.dart`
- Widget tests: `*_widget_test.dart`
- Integration tests: `*_integration_test.dart`
- Test groups: Descriptive names matching feature/class

### Structure

```dart
void main() {
  group('Feature/Class Name', () {
    setUp(() {
      // Setup before each test
    });
    
    tearDown(() {
      // Cleanup after each test
    });
    
    test('should do something specific', () {
      // Arrange
      final input = 'test';
      
      // Act
      final result = doSomething(input);
      
      // Assert
      expect(result, equals('expected'));
    });
  });
}
```

---

## Coverage Goals

| Layer | Target Coverage | Current |
|-------|----------------|---------|
| Core utilities | 80% | - |
| Network layer | 70% | - |
| Repositories | 70% | - |
| Services | 60% | - |
| Widgets | 50% | - |
| Overall | 60% | - |

**TODO**: Set up coverage reporting in CI

---

## Testing Strategy by Layer

### Data Layer (Repositories)

**Test**:
- API call success paths
- Error handling and mapping
- Timeout and retry logic
- Offline queue integration
- Result type usage

**Mock**:
- ApiClient
- FirebaseFirestore
- QueueService

---

### Domain Layer

**Test**:
- Business logic
- Entity validation
- Domain rules
- Calculations

**No Mocks**: Pure logic

---

### Presentation Layer (Widgets)

**Test**:
- Widget rendering
- User interactions
- Navigation
- Error states
- Loading states

**Mock**:
- Repositories
- Providers

---

## Continuous Integration

### GitHub Actions Workflow

```yaml
- name: Run tests
  run: flutter test --coverage
  
- name: Upload coverage
  uses: codecov/codecov-action@v3
  with:
    file: ./coverage/lcov.info
```

**TODO**: Update `.github/workflows/ci.yml` with test steps

---

## Test Data

### Fixtures

Create test fixtures in `test/fixtures/`:

```dart
// test/fixtures/time_entry.dart
final testTimeEntry = TimeEntry(
  id: 'test_entry_1',
  orgId: 'test_org',
  userId: 'test_user',
  jobId: 'test_job',
  clockIn: DateTime.now(),
  clientId: 'test_client',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
);
```

### Factory Functions

```dart
TimeEntry createTestTimeEntry({
  String? id,
  DateTime? clockIn,
}) {
  return TimeEntry(
    id: id ?? 'test_entry',
    clockIn: clockIn ?? DateTime.now(),
    // ... other defaults
  );
}
```

---

## Debugging Tests

### Print Debug Info

```dart
test('something', () {
  debugPrint('Debug info: $variable');
  // ... test code
});
```

### Run Single Test

```bash
flutter test --name "specific test name"
```

### Enable Verbose Output

```bash
flutter test --verbose
```

---

## Best Practices

1. **Test Behavior, Not Implementation**: Test what the code does, not how it does it
2. **One Assert per Test**: Focus each test on a single behavior
3. **Use Descriptive Names**: Test names should explain what is being tested
4. **Arrange-Act-Assert**: Follow AAA pattern for clarity
5. **DRY**: Use setUp/tearDown and helper functions
6. **Fast Tests**: Keep tests fast (< 1s per test)
7. **Isolated Tests**: No dependencies between tests
8. **Mock External Dependencies**: Don't hit real APIs or databases

---

## Common Testing Patterns

### Widget Tests with MaterialApp+Scaffold

**All widget tests must wrap widgets in a MaterialApp+Scaffold harness** to prevent context and theme lookup failures.

**For standalone widgets (not full apps):**

```dart
Future<void> _pumpWithMaterial(
  WidgetTester tester, {
  required Widget child,
}) async {
  await tester.pumpWidget(
    ProviderScope( // if using Riverpod
      child: MaterialApp(
        home: Scaffold(
          body: Center(child: child),
        ),
      ),
    ),
  );
}

testWidgets('SyncStatusChip renders correctly', (tester) async {
  await _pumpWithMaterial(
    tester,
    child: const SyncStatusChip(status: SyncStatus.synced),
  );
  
  expect(find.text('Synced'), findsOneWidget);
});
```

**For full app tests:**

```dart
testWidgets('App builds without errors', (tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: SierraPaintingApp(), // Already contains MaterialApp
    ),
  );
  
  expect(find.text('Sierra Painting'), findsOneWidget);
});
```

### Testing Async Operations

```dart
test('async operation', () async {
  final result = await repository.fetchData();
  expect(result.isSuccess, true);
});
```

### Testing Streams

```dart
test('stream emits values', () async {
  final stream = repository.watchData();
  
  await expectLater(
    stream,
    emitsInOrder([
      predicate((value) => value == 'first'),
      predicate((value) => value == 'second'),
    ]),
  );
});
```

### Testing Errors

```dart
test('throws error on invalid input', () {
  expect(
    () => doSomething(null),
    throwsA(isA<ArgumentError>()),
  );
});
```

---

## TODO: Testing Roadmap

### Phase 1 (Current)
- [x] Basic unit tests for core utilities
- [x] Result type tests
- [x] ApiClient configuration tests

### Phase 2
- [ ] Repository tests with mocks
- [ ] Service layer tests
- [ ] Queue service tests

### Phase 3
- [ ] Widget tests for all screens
- [ ] Navigation tests
- [ ] Integration tests for critical flows

### Phase 4
- [x] Smoke tests for mobile and backend ✅ **DONE**
- [x] CI integration for smoke tests ✅ **DONE**
- [ ] Performance benchmarks
- [ ] Contract tests for all APIs

### Phase 5
- [x] Smoke tests in CI pipeline ✅ **DONE**
- [ ] Coverage reporting
- [ ] Automated performance regression tests

---

## Resources

- [Flutter Testing Docs](https://docs.flutter.dev/testing)
- [Mockito Package](https://pub.dev/packages/mockito)
- [Integration Testing](https://docs.flutter.dev/testing/integration-tests)
- [Widget Testing](https://docs.flutter.dev/cookbook/testing/widget)
- [Performance Testing](https://docs.flutter.dev/perf)

---

## Support

For questions about testing:
1. Check this README
2. Review existing tests for examples
3. Consult team members
4. Check Flutter testing documentation
