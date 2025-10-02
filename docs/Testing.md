# Testing Guide — Project Sierra

> **Version:** V1  
> **Last Updated:** 2024-10-02  
> **Status:** Board-Ready

---

## Overview

This document outlines the testing strategy for Project Sierra, including unit tests, integration tests with Firebase Emulators, and end-to-end (E2E) test scripts for the three golden paths.

---

## Testing Philosophy

- **Test Pyramid**: Majority unit tests, fewer integration tests, minimal E2E
- **Emulator-First**: All Firebase services tested locally via emulators
- **Golden Paths**: Focus on critical user journeys
- **Performance**: Track P95 < 2.5s target for key operations
- **Security**: Firestore Rules tested with emulator suite

---

## Test Infrastructure

### Flutter Tests

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/services/offline_queue_service_test.dart
```

### Cloud Functions Tests

```bash
cd functions

# Lint
npm run lint

# Type check
npm run typecheck

# Build
npm run build

# Unit tests (when implemented)
npm test

# Firestore Rules tests (requires emulators)
npm run test:rules
```

### Firebase Emulators

```bash
# Start all emulators
firebase emulators:start

# Start with seed data
firebase emulators:start --import=./seed-data

# Export data after testing
firebase emulators:export ./seed-data
```

**Emulator Ports:**
- Emulator UI: http://localhost:4000
- Firestore: http://localhost:8080
- Auth: http://localhost:9099
- Functions: http://localhost:5001
- Storage: http://localhost:9199

---

## Performance Targets

| Operation | Target (P95) | Monitoring |
|-----------|--------------|------------|
| Sign-in | ≤ 2.5s | Firebase Performance |
| Clock-in (online) | ≤ 2.5s | Firebase Performance |
| Clock-in (offline) | ≤ 500ms | Local timing |
| Jobs Today load | ≤ 2.0s | Firebase Performance |
| Offline sync (per item) | ≤ 5s | Local timing |
| PDF generation | ≤ 10s | Cloud Functions logs |
| Quote math calculation | ≤ 100ms | Local timing |
| Firestore query (indexed) | ≤ 500ms | Firebase Performance |

---

## E2E Test Scripts

### Golden Path 1: Auth & Time Tracking

**Objective:** Verify authentication and time clock functionality with offline support.

```bash
# Prerequisites
firebase emulators:start

# Test Steps
1. Open Flutter app (connects to emulators)
2. Sign up with test user:
   - Email: crew@test.com
   - Password: testpass123
   
3. Verify redirect to /timeclock screen

4. Clock in to test job:
   - Select job "Test Job 001"
   - Enable GPS (or continue without)
   - Tap "Clock In"
   - Verify "Clocked In" status with green indicator

5. Test offline mode:
   - Disable network (airplane mode or emulator network off)
   - Attempt to clock out
   - Verify "Pending Sync" chip appears
   - Re-enable network
   - Verify sync completes automatically within 5s

6. View timesheet:
   - Navigate to "My Timesheet"
   - Verify today's entry appears with correct timestamps
   - Verify GPS location (if captured)

# Expected Results
✅ Sign-up creates user in Auth emulator
✅ User document created in Firestore /users/{uid}
✅ Clock-in creates timeEntry in /jobs/{jobId}/timeEntries
✅ Offline queue stores pending clock-out
✅ Sync completes when online
✅ No duplicate entries (idempotency works)

# Validation in Emulator UI
- Auth: http://localhost:9099/auth - See new user
- Firestore: http://localhost:8080 - See /users and /timeEntries
- Activity Logs: Check /activityLog for TIME_IN event
```

---

### Golden Path 2: Estimate → Invoice → Mark Paid

**Objective:** Verify quote creation, PDF generation, invoice conversion, and manual payment workflow.

```bash
# Prerequisites
firebase emulators:start
# Authenticated as admin user (admin@test.com / testpass123)

# Test Steps
1. Create Estimate:
   - Navigate to Estimates
   - Tap "New Estimate"
   - Fill form:
     * Customer: "John Doe"
     * Address: "123 Main St"
     * Line Items:
       - Labor: 16 hours @ $50/hr = $800
       - Paint: 5 gallons @ $40/gal = $200
     * Tax Rate: 7.5%
     * Total: $1,075
   - Tap "Save Estimate"
   
2. Generate PDF:
   - Tap "Generate PDF"
   - Verify loading indicator
   - Wait for PDF generation (should complete in < 10s)
   - Verify PDF preview displays
   - Check Firebase Storage for PDF file

3. Convert to Invoice:
   - From estimate detail screen, tap "Convert to Invoice"
   - Verify invoice created with status "unpaid"
   - Verify invoice appears in Invoices list

4. Mark Paid (Manual - Admin Only):
   - From invoice detail, tap "Mark Paid"
   - Select payment method: "Check"
   - Enter reference: "CHK-12345"
   - Enter note: "Received check payment"
   - Tap "Submit"
   - Verify success message
   - Verify invoice status changes to "paid"

5. Verify Audit Trail:
   - Check Firestore Emulator UI
   - Navigate to /activityLog collection
   - Verify entries for:
     * ESTIMATE_CREATED
     * INVOICE_CREATED
     * INVOICE_MARK_PAID_MANUAL
   - Verify each log has: entity, action, actor, orgId, timestamp

# Expected Results
✅ Estimate created in /estimates collection
✅ PDF generated and stored in /estimates/{id}.pdf (Storage)
✅ Invoice created in /invoices with correct totals
✅ Invoice status="unpaid" initially
✅ markPaidManual function creates /payments/{id} document
✅ Invoice status updated to "paid" (server-side only)
✅ Audit logs created for all operations
✅ Idempotency: Duplicate mark-paid calls return same result

# Security Validation
- Attempt mark-paid as non-admin → Should fail with permission-denied
- Attempt to manually set invoice.paid=true in Firestore → Should be rejected by rules

# Validation in Emulator UI
- Firestore: /estimates, /invoices, /payments, /activityLog
- Storage: /estimates/{id}.pdf
- Functions: http://localhost:5001 - Check logs for createEstimatePdf, markPaidManual
```

---

### Golden Path 3: Lead Capture → Schedule

**Objective:** Verify public lead form submission and admin schedule assignment.

```bash
# Prerequisites
firebase emulators:start

# Test Steps - Part 1: Lead Submission (Public)
1. Open web app lead form (no authentication required):
   - Navigate to /lead-form (public route)
   
2. Fill lead form:
   - Name: "Jane Smith"
   - Email: "jane@example.com"
   - Phone: "(555) 123-4567"
   - Address: "456 Oak Ave, Springfield"
   - Details: "Need exterior house painting, 3 stories"
   - Complete captcha (if enabled)
   
3. Submit form:
   - Tap "Submit"
   - Verify success message
   - Verify form clears

# Test Steps - Part 2: Admin Review & Schedule (Admin)
4. Login as admin:
   - Email: admin@test.com
   - Password: testpass123

5. Review lead:
   - Navigate to Admin → Leads
   - Verify new lead appears in list
   - Tap lead to view details
   - Verify all submitted info displays correctly

6. Convert to Job & Schedule:
   - From lead detail, tap "Create Job"
   - Fill job details:
     * Job Name: "Jane Smith Exterior"
     * Scheduled Date: (select date 3 days from now)
     * Assign Crew: Select 2 crew members
     * Estimated Hours: 24
   - Tap "Create & Schedule"
   
7. Verify Schedule:
   - Navigate to Admin → Schedule
   - Verify new job appears on selected date
   - Verify assigned crew members see job in their "Jobs Today" (on scheduled date)

# Expected Results
✅ Lead created in /leads collection (public submission)
✅ createLead function called with App Check token
✅ Captcha verified (if enabled)
✅ Audit log created: entity="lead", action="created"
✅ Admin can view all leads
✅ Job created in /jobs collection
✅ Schedule entry created with date + assigned crew
✅ Crew members see job in their schedule

# Security Validation
- App Check token required for createLead (verify in Functions logs)
- Rate limiting: Submit 10 leads rapidly → Should be throttled
- XSS: Try submitting `<script>alert('XSS')</script>` in details → Should be sanitized

# Validation in Emulator UI
- Firestore: /leads, /jobs, /schedules
- Functions: http://localhost:5001 - Check createLead logs
- Activity Logs: /activityLog - See LEAD_CREATED, JOB_CREATED events
```

---

## Security Testing

### Firestore Rules Tests

Create `functions/src/tests/rules.spec.ts`:

```typescript
import * as testing from '@firebase/rules-unit-testing';

describe('Firestore Rules', () => {
  let testEnv: testing.RulesTestEnvironment;

  beforeAll(async () => {
    testEnv = await testing.initializeTestEnvironment({
      projectId: 'sierra-painting-test',
      firestore: {
        rules: fs.readFileSync('firestore.rules', 'utf8'),
      },
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  test('Deny read/write by default', async () => {
    const unauthedDb = testEnv.unauthenticatedContext().firestore();
    await testing.assertFails(unauthedDb.collection('invoices').get());
  });

  test('Allow authenticated users to read their own data', async () => {
    const authedDb = testEnv.authenticatedContext('user123').firestore();
    await testing.assertSucceeds(authedDb.collection('users').doc('user123').get());
  });

  test('Prevent client from setting invoice.paid', async () => {
    const authedDb = testEnv.authenticatedContext('user123', {
      role: 'admin',
      orgId: 'org1',
    }).firestore();
    
    // Create invoice first
    await authedDb.collection('invoices').doc('inv1').set({
      orgId: 'org1',
      amount: 1000,
      paid: false,
    });

    // Try to mark paid from client → Should fail
    await testing.assertFails(
      authedDb.collection('invoices').doc('inv1').update({ paid: true })
    );
  });

  test('Allow write to payments subcollection (write-only)', async () => {
    const authedDb = testEnv.authenticatedContext('user123', {
      role: 'admin',
      orgId: 'org1',
    }).firestore();

    await testing.assertSucceeds(
      authedDb.collection('invoices').doc('inv1')
        .collection('payments').doc('pay1').set({
          amount: 1000,
          method: 'check',
        })
    );

    // But cannot read
    await testing.assertFails(
      authedDb.collection('invoices').doc('inv1')
        .collection('payments').doc('pay1').get()
    );
  });
});
```

Run with:
```bash
cd functions
npm run test:rules
```

---

## CI/CD Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  functions:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '18'
          cache: 'npm'
          cache-dependency-path: functions/package-lock.json
      
      - name: Install dependencies
        working-directory: functions
        run: npm ci
      
      - name: Lint
        working-directory: functions
        run: npm run lint
      
      - name: Build
        working-directory: functions
        run: npm run build
      
      - name: Test
        working-directory: functions
        run: npm test
```

---

## Coverage Targets

| Component | Target | Current |
|-----------|--------|---------|
| Cloud Functions | 70% | TBD |
| Flutter Services | 80% | TBD |
| Firestore Rules | 100% | TBD |
| Critical Paths | 100% | TBD |

---

## Debugging Tips

### Emulator Debugging

1. **View Logs:**
   ```bash
   # Functions logs
   tail -f ~/.cache/firebase/emulators/logs/functions.log
   
   # Firestore logs
   tail -f ~/.cache/firebase/emulators/logs/firestore.log
   ```

2. **Inspect Data:**
   - Open Emulator UI: http://localhost:4000
   - Navigate to Firestore tab
   - Browse collections and documents

3. **Test Rules Manually:**
   - Use Firestore UI Rules Playground
   - Simulate authenticated/unauthenticated requests

### Performance Profiling

```dart
// In Flutter
final stopwatch = Stopwatch()..start();
await someOperation();
print('Operation took: ${stopwatch.elapsedMilliseconds}ms');
```

### Network Simulation

```bash
# Simulate slow network
# iOS Simulator: Settings → Developer → Network Link Conditioner → 3G
# Android Emulator: Settings → Network & Internet → Mobile network → (throttle)
```

---

## Test Data

### Seed Data

Create `seed-data/` directory with:

```json
// users.json
{
  "users": {
    "admin123": {
      "uid": "admin123",
      "email": "admin@test.com",
      "role": "admin",
      "orgId": "org1"
    },
    "crew123": {
      "uid": "crew123",
      "email": "crew@test.com",
      "role": "crew",
      "orgId": "org1"
    }
  }
}

// jobs.json
{
  "jobs": {
    "job001": {
      "name": "Test Job 001",
      "orgId": "org1",
      "scheduledDate": "2024-10-10",
      "crewIds": ["crew123"],
      "status": "scheduled"
    }
  }
}
```

Import with:
```bash
firebase emulators:start --import=./seed-data
```

---

## Accessibility Testing

- **Manual Testing:**
  - TalkBack (Android) / VoiceOver (iOS)
  - Verify 44pt minimum touch targets
  - Verify labels on all interactive elements
  
- **Automated:**
  ```dart
  testWidgets('Clock in button is accessible', (tester) async {
    await tester.pumpWidget(MyApp());
    
    final clockInButton = find.byKey(Key('clock_in_button'));
    expect(tester.getSemantics(clockInButton).label, 'Clock In');
    expect(tester.getSize(clockInButton).height, greaterThanOrEqualTo(44));
  });
  ```

---

## Summary

- ✅ Unit tests for critical business logic
- ✅ Emulator integration tests for Firebase services
- ✅ E2E scripts for 3 golden paths
- ✅ Performance monitoring with clear targets
- ✅ Security testing via Firestore Rules
- ✅ CI/CD integration for automated validation

For questions or issues, see [DEVELOPER_WORKFLOW.md](./DEVELOPER_WORKFLOW.md).
