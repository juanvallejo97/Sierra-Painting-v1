# Validation Ready - Automated Setup Complete

**Status:** ✅ All automated setup complete, ready for Flutter app tests
**Date:** 2025-10-11
**Project:** sierra-painting-staging

---

## ✅ **Completed Automated Setup**

### 1. User Roles Set ✅
- **Admin UID:** `yqLJSx5NH1YHKa9WxIOhCrqJcPp1`
  - Custom claims: `{ role: 'admin', companyId: 'test-company-staging' }`
  - Firestore user doc updated
- **Worker UID:** `d5POlAllCoacEAN5uajhJfzcIJu2`
  - Custom claims: `{ role: 'worker', companyId: 'test-company-staging' }`
  - Firestore user doc updated

### 2. Test Data Created ✅
- **Company:** `test-company-staging`
  - Name: "Test Company - Staging"
  - Status: active
- **Job:** `test-job-staging`
  - Location: Painted Ladies, San Francisco, CA
  - Geofence: lat: 37.7793, lng: -122.4193, radius: 150m
  - Status: active
- **Assignment:** Worker linked to Job
  - Worker: d5POlAllCoacEAN5uajhJfzcIJu2
  - Job: test-job-staging
  - Status: active

### 3. Test 6: Auto-Clockout Dry-Run ✅ PASS
```json
{
  "processed": 0,
  "entries": []
}
```
- ✅ Function executed successfully
- ✅ Dry-run confirmed (no changes committed)
- ⚠️  Missing index warning (expected, handled gracefully)

---

## 📱 **Manual Tests Required (Tests 1-5)**

**IMPORTANT:** These MUST be run via Flutter app (not Console) to validate App Check enforcement.

### Test Credentials

**Worker Login:**
- UID: `d5POlAllCoacEAN5uajhJfzcIJu2`
- Role: worker
- Company: test-company-staging
- Assigned Job: test-job-staging (SF, 37.7793, -122.4193, 150m radius)

**Admin Login:**
- UID: `yqLJSx5NH1YHKa9WxIOhCrqJcPp1`
- Role: admin
- Company: test-company-staging

*(If you don't have the email/passwords for these UIDs, check Firebase Console → Authentication)*

---

### **Test 1: Clock In (Inside Geofence)** ⏸️

**Via Flutter App:**
1. Login with worker credentials
2. Navigate to time clock screen
3. **Ensure GPS is at test location** (37.7793, -122.4193) OR enable location mocking
4. Tap "Clock In"
5. Time the response

**Expected:**
- ✅ Success in ≤2s
- ✅ Entry ID displayed/stored
- ✅ No errors

**Capture:**
- Response time: ___ ms
- Entry ID: ___________

---

### **Test 2: Idempotency** ⏸️

**Via Flutter App:**
1. Immediately tap "Clock In" again (within 5 seconds)
2. App should reuse same `clientEventId` from Test 1

**Expected:**
- ✅ Same entry ID returned (from Test 1)
- ✅ No duplicate entry created
- ✅ Toast: "Already clocked in"

**Verify:**
- Same entry ID? YES / NO
- Firebase logs show "Idempotent replay detected"? YES / NO

---

### **Test 3: Clock Out (Outside Geofence)** ⏸️

**Via Flutter App:**
1. **Change GPS to outside geofence** (e.g., lat: 37.800, lng: -122.500) OR move physically
2. Tap "Clock Out"

**Expected:**
- ✅ Clock out succeeds with warning
- ✅ Toast: "Clocked out outside geofence... Entry flagged for review."

**Verify in Firestore Console:**
Navigate to: `/timeEntries/<entry-id-from-test-1>`

Check fields:
```
exceptionTags: ["geofence_out"]
geoOkOut: false
distanceAtOutM: <number>
```

**Capture:**
- exceptionTags present? YES / NO
- distanceAtOutM: ___ meters

---

### **Test 4: Bulk Approve** ⏸️

**Via Flutter App:**
1. Logout, login as **admin** user
2. Navigate to **Exceptions tab**
3. Verify badge shows count ≥ 1
4. Select the geofence exception from Test 3
5. Tap "Approve"

**Expected:**
- ✅ Success toast
- ✅ Badge count decreases
- ✅ Entry removed from Exceptions list

**Verify in Firestore Console:**
Check `/timeEntries/<entry-id>`:
```
approved: true
approvedBy: "yqLJSx5NH1YHKa9WxIOhCrqJcPp1"
approvedAt: <timestamp>
```

Check `/auditLog/<audit-id>`:
```
action: "approve_time_entry"
actorUid: "yqLJSx5NH1YHKa9WxIOhCrqJcPp1"
targetId: "<entry-id>"
```

**Capture:**
- Approved? YES / NO
- Audit trail created? YES / NO

---

### **Test 5: Create Invoice from Time** ⏸️

**Via Flutter App:**
1. Still logged in as admin
2. Navigate to approved time entries
3. Select the entry from Test 1
4. Tap "Create Invoice"
5. Enter:
   - Rate: $50/hour
   - Customer: "Test Customer"
   - Due date: 2025-11-10
6. Submit

**Expected:**
- ✅ Invoice created
- ✅ Success message with total amount
- ✅ Navigate to invoice detail screen

**Verify in Firestore Console:**
Check `/invoices/<invoice-id>`:
```
status: "pending"
amount: <calculated>
timeEntryIds: ["<entry-id>"]
createdAt: <timestamp>
```

Check `/timeEntries/<entry-id>`:
```
invoiceId: "<invoice-id>"
invoicedAt: <timestamp>
```

**Capture:**
- Invoice created? YES / NO
- Amount: $_____
- Entries locked with invoiceId? YES / NO

---

## 📊 **Additional Verification**

### Capture Proof Logs

**Run in terminal:**
```bash
firebase functions:log --project sierra-painting-staging --only clockIn,clockOut,bulkApproveTimeEntries --limit 50
```

**Find and copy these 3 lines:**
1. `clockIn: Success { uid: "...", jobId: "...", entryId: "...", ... }`
2. `clockIn: Idempotent replay detected { uid: "...", entryId: "...", ... }`
3. `bulkApproveTimeEntries: Complete { adminUid: "...", approved: 1, ... }`

### Check Metrics

**Firebase Console:** https://console.firebase.google.com/project/sierra-painting-staging/functions/usage

**For clockIn function:**
- Click `clockIn` → "Metrics" tab
- Check "Execution times" p95: ___ ms (target: < 300ms, alert: > 600ms)
- Check "Invocations" for cold start spikes (should be 0)

**For clockOut function:**
- Click `clockOut` → "Metrics" tab
- Check "Execution times" p95: ___ ms

**Capture:**
- clockIn p95: ___ ms
- clockOut p95: ___ ms
- Cold starts: 0? YES / NO

### Verify Indexes

**Firebase Console:** https://console.firebase.google.com/project/sierra-painting-staging/firestore/indexes

**Check all indexes show ACTIVE (green checkmark):**
- Key index: `(companyId, exceptionTags, clockInAt DESC)`

**Capture:**
- All indexes ACTIVE? YES / NO

---

## 📝 **Results Template**

**When you complete tests 1-5, paste this template with results:**

```
## VALIDATION RESULTS

Smoke Tests:
1. Clock In: PASS/FAIL – ___ ms (Entry ID: ___)
2. Idempotency: PASS/FAIL – Same ID: YES/NO
3. Clock Out: PASS/FAIL – exceptionTags present: YES/NO, distance: ___ m
4. Bulk Approve: PASS/FAIL – Audit OK: YES/NO
5. Create Invoice: PASS/FAIL – Amount: $___, Locked: YES/NO
6. Auto-Clockout: ✅ PASS – processed: 0, dryRun: true

Proof Logs (paste 3 lines):
1. clockIn: Success ...
2. Idempotent replay ...
3. bulkApproveTimeEntries: Complete ...

p95 Metrics:
- clockIn: ___ ms
- clockOut: ___ ms
- Cold starts: 0 (YES/NO)

Indexes: ACTIVE (YES/NO)

Issues: (describe or write NONE)
```

---

## 🚀 **Next Steps After You Post Results**

### If ALL GREEN ✅
I will immediately:
1. Stamp **STAGING: GO** in decision document
2. Tag release: `v1.0.0-demo`
3. Execute production canary deployment
4. ETA to prod: ~30 minutes

### If YELLOW ⚠️ (1-2 failures)
I will:
1. Analyze the specific failure
2. Provide targeted fix
3. Guide retest of failed items

### If RED 🛑 (Critical blocker)
I will:
1. Identify root cause
2. Propose rollback if needed
3. Create fix plan

---

## ⚡ **Quick Troubleshooting**

**"Not inside geofence"**
- Use test coords: 37.7793, -122.4193
- Enable location mocking in developer options
- OR temporarily increase `radiusM` to 250 in Firestore

**"Permission denied" on admin operations**
- Force token refresh in app (restart app)
- Verify admin role in Firebase Console → Authentication → user → Custom claims

**"UNAUTHENTICATED" error**
- You're testing via Console instead of Flutter app
- App Check requires Flutter app (not curl/console)

**"User not assigned to job"**
- Verify assignment exists in Firestore `/assignments` collection
- Check `active: true` and `userId` matches

---

## 📍 **Current Status**

- ✅ Roles set
- ✅ Test data created
- ✅ Test 6 automated test passed
- ⏸️  Tests 1-5 awaiting your execution via Flutter app

**Execute tests 1-5 via Flutter app and post results back using the template above.**

**I'm standing by to stamp STAGING: GO and execute prod canary immediately upon GREEN confirmation.** 🚀
