# Firestore Security Rules Testing

This directory contains comprehensive security rules tests for the Sierra Painting Firestore database.

## Overview

The rules tests validate:
- **Authentication requirements**: All operations require authenticated users
- **Owner-based access control**: Users can only modify their own resources
- **Schema validation**: Required fields and type checks are enforced
- **Server timestamp enforcement**: `updatedAt` must be set by server
- **Admin overrides**: Admins can access all resources in their organization

## Running Tests Locally

### Option 1: Using the Helper Script (Recommended)

The easiest way to run rules tests locally:

```bash
# From project root
./scripts/test-rules.sh
```

This script will:
1. Check if Firebase CLI is installed (and install if needed)
2. Start the Firestore emulator automatically
3. Run all rules tests
4. Clean up emulator on exit

### Option 2: Manual Setup

If you prefer manual control:

```bash
# Install Firebase CLI (if not already installed)
npm install -g firebase-tools@13.23.1

# Terminal 1: Start emulator
firebase emulators:start --only firestore --project sierra-painting-test

# Terminal 2: Run tests
cd functions
npm run test:rules
```

### Option 3: Run All Tests

To run both rules tests and function tests:

```bash
cd functions
npm test
```

## Test Structure

Tests are organized into the following categories:

### 1. Authentication Tests
- Deny unauthenticated read/write operations
- Verify auth requirement for all collections

### 2. Jobs Collection - Owner CRUD
- Owner can create jobs with valid schema
- Owner can read their own jobs
- Owner can update their own jobs
- Owner can delete their own jobs

### 3. Jobs Collection - Non-Owner Access
- Non-owner cannot create jobs with different ownerId
- Non-owner cannot update jobs they don't own
- Non-owner cannot delete jobs they don't own
- Users in same org can read jobs (but not modify)
- Users in different org cannot read jobs

### 4. Schema Validation
- Reject jobs without required `orgId` field
- Reject jobs without required `status` field
- Reject jobs without required `ownerId` field
- Reject jobs with null values in required fields
- Reject updates that change `ownerId`

### 5. Admin Access
- Admin can read any job in their org
- Admin can update any job
- Admin can delete any job

### 6. Other Collections
- Users collection access control
- Payments collection (read-only for clients)
- Activity logs (admin-only)

## CI/CD Integration

Rules tests run automatically in CI via `.github/workflows/rules-test.yml`:

- **Triggers**: On PR to main, or push to main when rules files change
- **Runs**: Automatically starts emulator and runs all tests
- **Blocks**: PRs cannot merge if rules tests fail
- **Comments**: Adds PR comment if tests fail with link to logs

## Writing New Tests

When adding new collections or updating rules:

1. Add schema validation functions to `firestore.rules`
2. Add test cases to `functions/src/test/rules.test.ts`
3. Run tests locally: `./scripts/test-rules.sh`
4. Ensure all tests pass before committing

### Test Template

```typescript
describe('Your Collection - Feature', () => {
  test('Should allow valid operation', async () => {
    const userDb = testEnv
      .authenticatedContext('user1', {
        orgs: { org1: true },
      })
      .firestore();

    await assertSucceeds(
      userDb.collection('your_collection').doc('doc1').set({
        // Valid data
      })
    );
  });

  test('Should reject invalid operation', async () => {
    const userDb = testEnv.unauthenticatedContext().firestore();

    await assertFails(
      userDb.collection('your_collection').doc('doc1').get()
    );
  });
});
```

## Troubleshooting

### Emulator Won't Start

If the emulator fails to start:

```bash
# Check if port 8080 is already in use
lsof -i :8080

# Kill any existing emulator processes
pkill -f "firebase.*emulator"

# Try starting again
firebase emulators:start --only firestore
```

### Tests Timing Out

If tests time out:
- Ensure emulator is running before tests start
- Increase timeout in test if needed: `jest.setTimeout(30000)`
- Check emulator logs for errors

### Rules Not Loading

If rules don't seem to apply:
- Verify `firestore.rules` syntax is valid
- Check that test is reading correct rules file path
- Try restarting emulator

## Emergency Rollback

If deployed rules are blocking legitimate traffic, see rollback procedures in:
- `docs/Security.md` → "Emergency Rollback Procedure"

Quick rollback:
```bash
# Revert to previous commit
git show <previous-commit>:firestore.rules > firestore.rules
firebase deploy --only firestore:rules
```

## Resources

- [Firebase Rules Unit Testing Guide](https://firebase.google.com/docs/rules/unit-tests)
- [Firestore Security Rules Documentation](https://firebase.google.com/docs/firestore/security/get-started)
- [Project Security Documentation](../../../docs/Security.md)
