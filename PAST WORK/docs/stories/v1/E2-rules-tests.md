# E2: Firestore Rules Tests (Initial)

**Epic**: E (Operations & Observability) | **Priority**: P0 | **Sprint**: V1 | **Est**: M | **Risk**: M

## User Story
As a Developer, I WANT automated Firestore rules tests, SO THAT security rules are verified before deployment.

## Dependencies
- **A1** (Sign-in): Rules tests need auth context
- **A2** (Roles): Rules tests need role-based access checks

## Acceptance Criteria (BDD)

### Success Scenario: Run Rules Tests
**GIVEN** I have Firestore rules defined  
**WHEN** I run `npm test` in functions directory  
**THEN** rules tests execute in emulator  
**AND** all security scenarios pass

### Success Scenario: Painter Access
**GIVEN** rules test creates a painter user  
**WHEN** test tries to read own time entry  
**THEN** read succeeds (allowed)  
**WHEN** test tries to read another painter's entry  
**THEN** read fails (denied)

### Success Scenario: Admin Access
**GIVEN** rules test creates an admin user  
**WHEN** test tries to read any user's time entry in their org  
**THEN** read succeeds (allowed)  
**WHEN** test tries to read entry in different org  
**THEN** read fails (denied)

### Edge Case: Unauthenticated Access
**GIVEN** rules test has no auth context  
**WHEN** test tries to read any document  
**THEN** read fails (denied)

### Performance
- **Target**: Rules tests complete in P95 ≤ 30 seconds
- **Metric**: Time to run full test suite

## Test Setup

### Firestore Rules Test Configuration
```typescript
// functions/test/rules.test.ts
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import * as fs from 'fs';

let testEnv: any;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'test-project',
    firestore: {
      rules: fs.readFileSync('../firestore.rules', 'utf8'),
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

describe('Time Entry Rules', () => {
  test('Painter can read own entry', async () => {
    const painter = testEnv.authenticatedContext('painter1', {
      role: 'painter',
      orgId: 'org1',
    });
    
    await testEnv.withSecurityRulesDisabled(async (context: any) => {
      await context.firestore()
        .collection('jobs').doc('job1')
        .collection('timeEntries').doc('entry1')
        .set({
          userId: 'painter1',
          orgId: 'org1',
          clockIn: Date.now(),
          clockOut: null,
        });
    });
    
    const read = painter.firestore()
      .collection('jobs').doc('job1')
      .collection('timeEntries').doc('entry1')
      .get();
    
    await assertSucceeds(read);
  });
  
  test('Painter cannot read other painter entry', async () => {
    const painter2 = testEnv.authenticatedContext('painter2', {
      role: 'painter',
      orgId: 'org1',
    });
    
    const read = painter2.firestore()
      .collection('jobs').doc('job1')
      .collection('timeEntries').doc('entry1')
      .get();
    
    await assertFails(read);
  });
  
  test('Admin can read all entries in org', async () => {
    const admin = testEnv.authenticatedContext('admin1', {
      role: 'admin',
      orgId: 'org1',
    });
    
    const read = admin.firestore()
      .collection('jobs').doc('job1')
      .collection('timeEntries').doc('entry1')
      .get();
    
    await assertSucceeds(read);
  });
  
  test('Unauthenticated cannot read', async () => {
    const unauth = testEnv.unauthenticatedContext();
    
    const read = unauth.firestore()
      .collection('jobs').doc('job1')
      .collection('timeEntries').doc('entry1')
      .get();
    
    await assertFails(read);
  });
});
```

### Package.json Scripts
```json
{
  "scripts": {
    "test:rules": "jest --testPathPattern=rules.test.ts",
    "test": "npm run test:rules && jest --testPathPattern=functions.test.ts"
  }
}
```

## Definition of Done (DoD)
- [ ] Rules test framework set up (@firebase/rules-unit-testing)
- [ ] Tests for time entry read permissions (painter, admin, unauth)
- [ ] Tests for user document permissions
- [ ] Tests for job document permissions
- [ ] Tests run in CI pipeline
- [ ] All tests pass
- [ ] Demo: modify rule → test fails → fix rule → test passes

## Notes

### Implementation Tips
- Use `@firebase/rules-unit-testing` package (v2+)
- Run emulator automatically with test environment
- Mock data with `withSecurityRulesDisabled` for setup
- Test both positive (assertSucceeds) and negative (assertFails) cases

### References
- [Firestore Rules Unit Testing](https://firebase.google.com/docs/rules/unit-tests)
- [ADR-011: Story-Driven Development](../../adrs/011-story-driven-development.md)
