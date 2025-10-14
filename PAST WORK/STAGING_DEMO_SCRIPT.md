# Staging Demo Script — Geofenced Timeclock MVP

**Purpose**: Live demonstration for client showing "it just works" functionality on staging environment.

**Duration**: 15 minutes

**Participants**: 1 demo operator + client stakeholders

**Environment**: `sierra-painting-staging` Firebase project

---

## Pre-Demo Setup (5 minutes before)

### 1. Verify Staging Environment

```bash
# Confirm on staging
firebase use staging
firebase projects:list

# Check functions deployed
firebase functions:list

# Verify indexes
firebase firestore:indexes
```

### 2. Load Seed Data

```bash
# Run seed script (creates company, users, jobs)
npm run seed:staging

# Or dry-run first to see what will be created:
npm run seed:staging:check
```

### 3. Test Devices Ready

- **Android device** or emulator with GPS enabled
- **Laptop/tablet** for admin web view (Chrome)
- Both logged into **staging** environment

### 4. Verify Feature Flags

Firebase Console → Remote Config → Staging:

```json
{
  "timeclock_enabled": true,
  "admin_review_enabled": true,
  "invoice_from_time_enabled": true,
  "testing_allowlist": ""
}
```

---

## Automated E2E Test (Optional, 8 minutes)

**Purpose**: Run automated end-to-end test to validate the complete demo flow before live demonstration.

### Quick Start

**Linux/macOS**:
```bash
./tools/e2e/run_e2e.sh
```

**Windows**:
```powershell
pwsh tools/e2e/run_e2e.ps1
```

### What the E2E Test Does

The automated test exercises the full demo path:

1. ✅ Creates test company, admin, worker, job, and assignment
2. ✅ Worker login flow
3. ✅ Worker sees job assignment
4. ✅ Worker clocks in (simulated GPS within geofence)
5. ✅ Worker clocks out
6. ✅ Admin login flow
7. ✅ Admin sees pending entry in review screen
8. ✅ Admin approves entry
9. ✅ Verifies entry status is 'approved'
10. ✅ Cleans up test data

### Expected Results

- **Duration**: <8 minutes
- **Status**: All steps pass with green checkmarks
- **SLO**: E2E test completes within 480 seconds

### Script Details

The automation script:
- Builds Cloud Functions from TypeScript
- Starts Firebase emulators (Firestore, Functions, Auth)
- Runs integration test: `integration_test/e2e_demo_test.dart`
- Stops emulators automatically
- Reports pass/fail with timing

### When to Run

**Before live demo**:
- Run 1 hour before client demonstration
- Validates staging environment is healthy
- Catches configuration issues early

**In CI/CD**:
- Run on every PR to staging branch
- Gates production deployment
- Ensures no regressions

### Troubleshooting

**Test fails with "Emulators failed to start"**:
```bash
# Kill existing emulator processes
pkill -f "firebase.*emulators"

# Or on Windows:
Get-Process | Where-Object { $_.ProcessName -like "*java*" } | Stop-Process -Force
```

**Test fails with timeout**:
- Check `emulator.log` for errors
- Verify Firebase CLI is up to date: `npm install -g firebase-tools`
- Ensure ports 8080, 5001, 9099 are not in use

**Functions not found**:
```bash
# Manually build functions
npm --prefix functions run build

# Verify build output exists
ls functions/lib
```

---

## Demo Flow

### **Act 1: Worker Clock-In (3 minutes)**

**Narrative**: "Field worker arrives at job site and clocks in from their phone."

#### Steps:

1. **Open Worker Dashboard** (mobile device)
   - Login as: `demo-worker@staging.test` / `Demo123!`
   - Show clean, simple interface
   - Point out: "One big button — that's it"

2. **Show Job Card**
   - Point out job name: "Maple Ave Interior"
   - Address: "1234 Maple Ave, Albany, NY"
   - Distance: "Within geofence" (or "150m away" if testing remotely)

3. **Tap "Clock In"**
   - **Expected**: GPS location acquired (≤2s)
   - **Expected**: Success toast: "✓ Clocked in successfully"
   - **Show**: Timer starts, "Currently Working" status

**Talking Points**:
- GPS verifies worker is at job site
- No fake locations accepted — geofence enforced server-side
- Instant feedback (≤2s end-to-end)

### **Act 2: Clock-Out with Soft Failure (2 minutes)**

**Narrative**: "Worker finishes and clocks out, but GPS drifts slightly outside geofence."

#### Steps:

1. **Simulate Location Drift** (if testing with mock GPS)
   - Move GPS slightly outside radius (or just proceed with actual location)

2. **Tap "Clock Out"**
   - **Expected**: Success with warning: "⚠ Clocked out with warning"
   - **Expected**: Warning text: "Outside geofence. Entry flagged for review."
   - **Show**: Entry closes, timer stops

**Talking Points**:
- Clock-out is "soft" — doesn't block worker
- Worker might legitimately leave job site before clocking out
- Admin reviews exceptions later (next act)

### **Act 3: Admin Review — Exception Handling (5 minutes)**

**Narrative**: "Admin reviews time entries, focusing on exceptions first."

#### Steps:

1. **Open Admin Review** (web browser)
   - Login as: `demo-admin@staging.test` / `Demo123!`
   - Navigate to: "Review Time Entries"

2. **Show Exception Tabs**
   - Point out tabs with badges:
     - **Outside Geofence** (1) ← our flagged entry
     - **>12h** (0)
     - **Auto Clock-Out** (0)
     - **Overlapping** (0)
     - **Disputed** (0)
     - **All Pending** (1)

3. **Click "Outside Geofence" Tab**
   - **Show**: Entry with worker name, job, times
   - **Show**: Orange "Geo Out" badge
   - **Show**: Distance: "35m from job site"

4. **Review Entry Details**
   - Click on entry to expand
   - **Show**: Full timestamps, duration, location metadata
   - **Point out**: Audit trail (when created, by whom)

5. **Bulk Approve**
   - Check the entry
   - Click "Approve" button
   - **Expected**: Success toast: "1 entry approved"
   - **Show**: Entry disappears from exceptions, badge count → 0

**Talking Points**:
- Exception-first design surfaces issues requiring attention
- Bulk actions for efficiency (can approve 50+ entries at once)
- Clear visual indicators (badges, colors)
- Complete audit trail for compliance

### **Act 4: Create Invoice from Time (3 minutes)**

**Narrative**: "Admin bills customer based on approved time entries."

#### Steps:

1. **Navigate to "All Pending" Tab**
   - **Show**: Now-approved entry listed

2. **Select Entry for Invoicing**
   - Check the approved entry
   - Click "Create Invoice" button

3. **Fill Invoice Dialog**
   - **Customer**: "Taylor Home" (auto-selected from job)
   - **Hourly Rate**: "$65.00"
   - **Summary**: "1 entry, 8.5 hours"
   - **Total**: "$552.50" (calculated)

4. **Click "Create Invoice"**
   - **Expected**: Loading (≤2s)
   - **Expected**: Success: "Invoice INV-001 created"

5. **Show Entry Now Locked**
   - Entry displays green "Invoiced" badge
   - Edit button disabled (greyed out)
   - Tooltip: "Invoiced entries cannot be edited"

**Talking Points**:
- Time entries lock when invoiced (immutable)
- Prevents accidental changes to billed hours
- Atomic operation — all entries lock together or none do
- Creates audit record for compliance

### **Act 5: Customer View (Optional, 2 minutes)**

**Narrative**: "Customer receives invoice with itemized labor hours."

#### Steps:

1. **Navigate to Customer Dashboard**
   - Switch to customer view (or open in private window)
   - Login as: `demo-customer@staging.test` / `Demo123!`

2. **View Invoice**
   - **Show**: Invoice INV-001 listed
   - **Show**: Line item: "Labor — Maple Ave Interior: 8.5h @ $65/hr"
   - **Show**: Total: "$552.50"
   - **Show**: Due date, payment status

**Talking Points**:
- Customer-facing view is read-only
- Clear itemization by job
- Links back to time entries for transparency

---

## Failure Scenarios (Show if time permits)

### Scenario A: Clock In Outside Geofence

**Setup**: Move GPS >200m from job site before clicking "Clock In"

**Expected**:
- Error: "You are 215m from the job site. Move closer to clock in."
- "Explain Issue" button appears
- Worker **cannot** proceed (hard gate)

**Talking Point**: Prevents workers from clocking in before arriving at job.

### Scenario B: Clock In Without Assignment

**Setup**: Use worker account without job assignment

**Expected**:
- Error: "No assignments for today. Contact your manager."
- No jobs shown in dashboard

**Talking Point**: Workers must be explicitly assigned before clocking in.

---

## Seed Data Specification

### Company

```json
{
  "id": "demo-company-staging",
  "name": "Sierra Painting – Staging Demo",
  "timezone": "America/New_York",
  "requireGeofence": true,
  "maxShiftHours": 12,
  "defaultHourlyRate": "65.00"
}
```

### Users

**Admin**:
```json
{
  "uid": "staging-demo-admin-001",
  "email": "demo-admin@staging.test",
  "password": "Demo123!",
  "displayName": "Demo Admin",
  "companyId": "demo-company-staging",
  "role": "admin"
}
```

**Worker**:
```json
{
  "uid": "staging-demo-worker-001",
  "email": "demo-worker@staging.test",
  "password": "Demo123!",
  "displayName": "Demo Worker",
  "companyId": "demo-company-staging",
  "role": "worker"
}
```

**Customer** (read-only):
```json
{
  "uid": "staging-demo-customer-001",
  "email": "demo-customer@staging.test",
  "password": "Demo123!",
  "displayName": "Taylor Home",
  "companyId": "demo-company-staging",
  "role": "customer"
}
```

### Job

```json
{
  "id": "staging-demo-job-001",
  "companyId": "demo-company-staging",
  "name": "Maple Ave Interior",
  "address": {
    "street": "1234 Maple Ave",
    "city": "Albany",
    "state": "NY",
    "zip": "12203"
  },
  "lat": 42.6526,
  "lng": -73.7562,
  "radiusM": 125,
  "customerId": "staging-demo-customer-001",
  "status": "active",
  "startDate": "2025-10-01",
  "endDate": "2025-12-31"
}
```

### Assignment

```json
{
  "id": "staging-demo-assignment-001",
  "companyId": "demo-company-staging",
  "userId": "staging-demo-worker-001",
  "jobId": "staging-demo-job-001",
  "active": true,
  "startDate": "2025-10-01T00:00:00Z",
  "endDate": "2025-12-31T23:59:59Z"
}
```

### Customer

```json
{
  "id": "staging-demo-customer-001",
  "companyId": "demo-company-staging",
  "name": "Taylor Home",
  "email": "demo-customer@staging.test",
  "phone": "(518) 555-0100",
  "address": {
    "street": "1234 Maple Ave",
    "city": "Albany",
    "state": "NY",
    "zip": "12203"
  }
}
```

---

## Seed Script Template

```dart
// tools/seed_staging_demo.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> main() async {
  // Initialize Firebase with staging config
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: 'staging-api-key',
      projectId: 'sierra-painting-staging',
      // ... other options
    ),
  );

  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuth.instance;

  print('Seeding staging demo data...');

  // Create company
  await db.collection('companies').doc('demo-company-staging').set({
    'name': 'Sierra Painting – Staging Demo',
    'timezone': 'America/New_York',
    'requireGeofence': true,
    'maxShiftHours': 12,
    'defaultHourlyRate': '65.00',
    'createdAt': FieldValue.serverTimestamp(),
  });
  print('✓ Company created');

  // Create users (use Firebase Admin SDK for production)
  try {
    await auth.createUserWithEmailAndPassword(
      email: 'demo-worker@staging.test',
      password: 'Demo123!',
    );
    print('✓ Worker user created');
  } catch (e) {
    print('Worker user already exists');
  }

  // Create job, assignment, customer...
  // (See full seed data above)

  print('✓ Staging demo data seeded successfully');
  print('Ready for demo!');
}
```

---

## Post-Demo Cleanup

```bash
# Delete demo data
firebase firestore:delete --all-collections --force --recursive \
  "companies/demo-company-staging"

# Delete demo users (via Firebase Console → Authentication)
# Or use Admin SDK:
firebase auth:delete demo-worker@staging.test
firebase auth:delete demo-admin@staging.test
firebase auth:delete demo-customer@staging.test
```

---

## Troubleshooting

### Issue: GPS not available in emulator

**Solution**: Use Android Studio AVR with location set to Albany, NY (42.6526, -73.7562)

### Issue: Function timeout (>10s)

**Cause**: Cold start on staging

**Solution**: Pre-warm function:
```bash
curl -X POST https://us-east4-sierra-painting-staging.cloudfunctions.net/clockIn \
  -H "Content-Type: application/json" \
  -d '{"test": true}'
```

### Issue: Rules deny access

**Cause**: Custom claims not set

**Solution**: Set claims via Admin SDK:
```bash
firebase auth:set-claims demo-worker@staging.test --claims '{"company_id":"demo-company-staging","role":"worker"}'
```

### Issue: Feature flag not updating

**Cause**: Remote Config cache (15min minimum fetch interval)

**Solution**: Clear app data or wait 15 minutes

---

## Success Metrics

Demo is successful if:

✅ Clock-in completes in ≤2s
✅ Geofence validation works (inside → success, outside → error)
✅ Admin Review shows flagged entry
✅ Bulk approve works (entry disappears from exceptions)
✅ Invoice creation locks entries in ≤5s
✅ No errors/crashes during demo

---

## Next Steps (Discuss with client)

1. **Canary rollout plan**: Start with admins + 2-3 test workers
2. **Training materials**: Video walkthrough for workers
3. **Support playbook**: Common issues + resolutions
4. **Monitoring dashboard**: Real-time SLOs (latency, success rate)
5. **Production cutover date**: Target date for full rollout
