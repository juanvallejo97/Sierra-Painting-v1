# Developer Workflow Guide

## Overview
This guide outlines the recommended workflow for implementing features in Sierra Painting, using story-driven development with best practices from top tech companies.

## Quick Start

```bash
# 1. Pick a story from the sprint backlog
cd docs/stories/v1/
cat B1-clock-in.md  # Read the full story

# 2. Create a feature branch
git checkout -b feature/B1-clock-in-offline

# 3. Verify DoR (Definition of Ready)
# Check that dependencies are complete, schemas defined, etc.

# 4. Write tests first (TDD approach)
# - Add unit tests
# - Add integration tests (emulator)
# - Add E2E tests if applicable

# 5. Implement minimal code to pass tests

# 6. Verify locally
flutter test                    # Run Flutter tests
cd functions && npm test        # Run function tests (when available)
firebase emulators:start        # Test with emulators

# 7. Commit with story reference
git add .
git commit -m "feat(B1): implement offline clock-in queue"

# 8. Push and create PR
git push origin feature/B1-clock-in-offline
# Create PR with story link in description

# 9. After PR approval, merge and close story
```

## Story-Driven Development

### 1. Story Selection
Choose stories in priority order:
- **P0 (Must-have)**: Critical path, blocking other work
- **P1 (Should-have)**: Important but not blocking
- **P2 (Nice-to-have)**: Polish and optimization

Check dependencies before starting:
```bash
# Story B2 depends on B1
# Don't start B2 until B1 is complete
```

### 2. Read and Understand
Before coding, thoroughly read:
- **User Story**: Understand the user value
- **Acceptance Criteria**: Know what "done" looks like
- **Data Models**: Review Zod schemas and Firestore structure
- **Security**: Check Firestore rules requirements
- **Testing Strategy**: Plan your test approach

### 3. Test-Driven Development (TDD)

#### Red → Green → Refactor

```bash
# Step 1: RED - Write failing test
# Example: functions/test/clockIn.test.ts
describe('B1: Clock-in', () => {
  it('should create time entry with GPS', async () => {
    const result = await clockIn({
      jobId: 'job123',
      at: Date.now(),
      geo: { lat: 37.7749, lng: -122.4194 },
      clientId: uuid.v4(),
    });
    
    expect(result.success).toBe(true);
    // Test fails because clockIn not implemented yet
  });
});

# Step 2: GREEN - Implement minimal code
# Add clockIn function in functions/src/index.ts

# Step 3: REFACTOR - Clean up code
# Extract helpers, improve readability
# Tests still pass
```

### 4. Implementation Guidelines

#### Keep Changes Minimal
- **Do**: Add only what the story requires
- **Don't**: Refactor unrelated code
- **Don't**: Fix unrelated bugs
- **Don't**: Add "nice-to-have" features

#### Follow Existing Patterns
```typescript
// ✅ DO: Follow existing function structure
export const clockIn = functions
  .runWith({ enforceAppCheck: true })
  .https.onCall(async (data, context) => {
    // 1. Auth check
    if (!context.auth) throw HttpsError('unauthenticated');
    
    // 2. Validate input
    const validated = TimeInSchema.parse(data);
    
    // 3. Check idempotency
    // 4. Business logic
    // 5. Create audit log
    // 6. Return result
  });

// ❌ DON'T: Introduce new patterns without discussion
```

#### Add Telemetry and Audit Logs
Every user action should be observable:
```typescript
// Analytics event
functions.logger.info('Clock-in success', {
  userId: context.auth.uid,
  jobId: validated.jobId,
  hasGeo: !!validated.geo,
});

// Audit log entry
await db.collection('activity_logs').add({
  timestamp: admin.firestore.FieldValue.serverTimestamp(),
  entity: 'time_entry',
  action: 'TIME_IN',
  actorUid: context.auth.uid,
  orgId: userOrgId,
  details: { jobId, entryId, hasGeo },
});
```

## Local Development

### Setup
```bash
# Install dependencies
flutter pub get
cd functions && npm install

# Configure Firebase
firebase login
flutterfire configure

# Start emulators
firebase emulators:start
```

### Running Tests

#### Flutter Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/features/timeclock/clock_in_test.dart

# Run with coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

#### Function Tests
```bash
cd functions

# Run all tests (when implemented)
npm test

# Run specific test
npm test -- clockIn.test.ts

# Run with coverage
npm run test:coverage
```

### Linting and Formatting
```bash
# Flutter
flutter analyze
flutter format lib/

# Functions
cd functions
npm run lint
npm run lint:fix  # Auto-fix issues
```

## Git Workflow

### Branch Naming
```bash
# Feature branches
feature/B1-clock-in-offline
feature/C3-mark-paid-idempotency
feature/D1-lead-form-validation

# Bug fixes
fix/B1-duplicate-clock-in
fix/auth-token-refresh

# Documentation
docs/B7-timesheet-story
docs/adr-performance-monitoring

# Refactoring
refactor/extract-auth-helpers
```

### Commit Messages
Follow [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Format: <type>(<scope>): <description>

# Feature
feat(B1): implement offline clock-in queue
feat(C3): add manual payment with audit trail

# Fix
fix(B1): prevent duplicate clock-in entries
fix(auth): handle token expiry gracefully

# Documentation
docs(stories): add B7 timesheet story
docs(adr): create ADR-013 for telemetry

# Test
test(B1): add integration tests for clock-in
test(auth): add E2E sign-in flow

# Refactor
refactor(auth): extract role check helper
refactor(functions): consolidate error handling

# Chore
chore(deps): update firebase-functions to 4.5.0
chore(ci): add performance monitoring
```

### Pull Request Process

#### 1. Create PR with Story Reference
```markdown
## Story
Implements: docs/stories/v1/B1-clock-in.md

## Changes
- Added `clockIn` callable function with idempotency
- Implemented offline queue in Flutter with Hive
- Added GPS permission handling with fallback
- Created activity log entries for audit trail

## Testing
- ✅ Unit tests: Zod validation, idempotency
- ✅ Integration tests: Firestore rules, function execution
- ✅ E2E test: offline → online sync

## DoD Checklist
- [x] Code implemented
- [x] Tests pass (unit + integration)
- [x] Rules deployed to staging
- [x] Telemetry events wired
- [x] Audit logging working
- [x] Documentation updated
- [x] Performance: P95 ≤ 2.5s verified

## Screenshots
[Attach screenshots of UI changes if applicable]

## Deployment Notes
- Requires Firestore index deployment
- No breaking changes
- Safe to rollback
```

#### 2. Code Review Guidelines

**For Reviewers**:
- ✅ Verify story acceptance criteria met
- ✅ Check tests cover edge cases
- ✅ Ensure security rules enforced
- ✅ Validate telemetry/audit logs present
- ✅ Review performance impact
- ❌ Don't request unrelated changes
- ❌ Don't bikeshed minor style issues

**For Authors**:
- Respond to feedback promptly
- Explain design decisions
- Update tests based on feedback
- Keep discussions in PR comments

#### 3. Merge and Deploy
```bash
# After approval
git checkout main
git pull origin main
git merge --no-ff feature/B1-clock-in-offline
git push origin main

# Deploy to staging (automatic via CI/CD)
# Verify in staging environment
# Tag for production when ready
git tag v1.0.0
git push origin v1.0.0
```

## Testing Best Practices

### Unit Tests
- Test one thing at a time
- Use descriptive test names
- Mock external dependencies
- Aim for ≥80% coverage

```dart
// ✅ Good: Descriptive, focused
test('TimeInSchema validates GPS coordinates', () {
  final data = {
    'jobId': 'job123',
    'at': DateTime.now().millisecondsSinceEpoch,
    'geo': {'lat': 37.7749, 'lng': -122.4194},
    'clientId': Uuid().v4(),
  };
  
  expect(() => TimeInSchema.parse(data), returnsNormally);
});

// ❌ Bad: Vague, tests multiple things
test('clock in works', () {
  // Too broad, unclear what's being tested
});
```

### Integration Tests
- Use Firebase emulators
- Test actual data flow
- Verify security rules
- Check idempotency

```typescript
// Run against emulator
describe('B1: Clock-in integration', () => {
  beforeAll(() => {
    // Start emulator
  });
  
  it('should enforce Firestore rules', async () => {
    const userAuth = testEnv.authenticatedContext('user123');
    const adminAuth = testEnv.authenticatedContext('admin123', {
      role: 'admin',
    });
    
    // User can create own entry
    await expect(
      userAuth.firestore().collection('jobs/job1/timeEntries').add({
        userId: 'user123',
        // ...
      })
    ).resolves.toBeDefined();
    
    // User cannot create entry for someone else
    await expect(
      userAuth.firestore().collection('jobs/job1/timeEntries').add({
        userId: 'other-user',
        // ...
      })
    ).rejects.toThrow('permission-denied');
  });
});
```

### E2E Tests
- Test user journeys
- Use Flutter integration tests
- Run on real devices when possible

```dart
// test_driver/app_test.dart
testWidgets('Sign-in → Clock-in → Clock-out flow', (tester) async {
  // Sign in
  await tester.pumpWidget(MyApp());
  await tester.enterText(find.byKey(Key('email')), 'test@example.com');
  await tester.enterText(find.byKey(Key('password')), 'password123');
  await tester.tap(find.byKey(Key('sign-in')));
  await tester.pumpAndSettle();
  
  // Should see Jobs Today
  expect(find.text('Jobs Today'), findsOneWidget);
  
  // Clock in
  await tester.tap(find.text('Clock In'));
  await tester.pumpAndSettle();
  
  // Should see confirmation
  expect(find.textContaining('Clocked in'), findsOneWidget);
});
```

## Performance Monitoring

### Targets
- P95 latency ≤ 2.5s for critical operations
- Cold start ≤ 3s
- Time to interactive ≤ 5s

### Measuring Performance
```typescript
// In Cloud Functions
const startTime = Date.now();

// ... operation ...

const duration = Date.now() - startTime;
functions.logger.info('Operation duration', {
  operation: 'clock_in',
  durationMs: duration,
});
```

```dart
// In Flutter
final stopwatch = Stopwatch()..start();

// ... operation ...

stopwatch.stop();
print('Clock-in duration: ${stopwatch.elapsedMilliseconds}ms');

// Send to analytics
FirebaseAnalytics.instance.logEvent(
  name: 'clock_in_duration',
  parameters: {'duration_ms': stopwatch.elapsedMilliseconds},
);
```

## Deployment

### Staging (Automatic on `main` branch)
```bash
# Merge to main triggers CI/CD
git checkout main
git merge feature/B1-clock-in-offline
git push origin main

# GitHub Actions automatically:
# 1. Runs tests
# 2. Builds Flutter app
# 3. Builds functions
# 4. Deploys to staging project
```

### Production (Manual on version tags)
```bash
# After staging verification
git tag -a v1.0.0 -m "Sprint V1 release"
git push origin v1.0.0

# GitHub Actions automatically:
# 1. Runs all tests
# 2. Builds release APK
# 3. Deploys functions to production
# 4. Creates GitHub release
```

## Troubleshooting

### Common Issues

#### "Function not found" error
```bash
# Ensure function is exported in index.ts
export const clockIn = functions.https.onCall(...)

# Rebuild and redeploy
cd functions
npm run build
firebase deploy --only functions:clockIn
```

#### Firestore permission denied
```bash
# Check rules match your test case
firebase emulators:start
# Open Emulator UI: http://localhost:4000
# Check Rules tab

# Verify user has correct role
const userDoc = await db.collection('users').doc(uid).get();
console.log(userDoc.data()?.role);  // Should be 'admin', 'crewLead', or 'crew'
```

#### Offline sync not working
```dart
// Verify Hive initialized
await Hive.initFlutter();
if (!Hive.isAdapterRegistered(0)) {
  Hive.registerAdapter(QueueItemAdapter());
}
final box = await Hive.openBox<QueueItem>('queue');

// Check queue items
print('Pending items: ${box.values.where((i) => !i.processed).length}');
```

## Resources

### Internal Documentation
- [ADR-011: Story-Driven Development](../adrs/011-story-driven-development.md)
- [ADR-006: Idempotency Strategy](../adrs/006-idempotency-strategy.md)
- [Story Template](../stories/README.md)
- [Sprint Plan](../stories/v1/SPRINT_PLAN.md)

### External Resources
- [Firebase Functions Best Practices](https://firebase.google.com/docs/functions/best-practices)
- [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started)
- [Flutter Testing](https://flutter.dev/docs/testing)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Test-Driven Development](https://en.wikipedia.org/wiki/Test-driven_development)

## Getting Help

1. **Check documentation**: Start with ADRs and story files
2. **Review similar code**: Look at existing implementations
3. **Ask in PR comments**: Tag reviewers with specific questions
4. **Team chat**: Discuss in #engineering channel
5. **Pair programming**: Schedule time with team member
