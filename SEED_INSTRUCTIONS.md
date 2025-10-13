# Manual Seed Instructions - Firebase Console

## 🚨 ROOT CAUSE CONFIRMED

**The Firestore REST API query returned ZERO assignments** for test user `d5P01AlLCoaEAN5ua3hJFzcIJu2`.

This is why clock-in shows an infinite spinner - the `activeJobProvider` query succeeds but finds no data.

---

## 📝 MANUAL FIX (5 minutes via Firebase Console)

### Step 1: Create Job Document

1. Go to: https://console.firebase.google.com/project/sierra-painting-staging/firestore/data
2. Click **+ Start collection** (or navigate to existing `jobs` collection)
3. Collection ID: `jobs`
4. Document ID: `test-job-staging`
5. Add these fields:

| Field | Type | Value |
|-------|------|-------|
| `companyId` | string | `test-company-staging` |
| `name` | string | `Test Job Site - Staging` |
| `address` | string | `123 Test Street, Providence, RI` |
| `status` | string | `active` |
| `geofence` | map | *(see below)* |

**For the `geofence` map**, add these nested fields:
- `geofence.lat` (number): `41.8825`
- `geofence.lng` (number): `-71.3945`
- `geofence.radiusM` (number): `150`

6. Click **Save**

---

### Step 2: Create Assignment Document

1. In Firestore Console, navigate to `assignments` collection (or create it)
2. Click **+ Add document**
3. Document ID: `test-assignment-staging` (or Auto-ID)
4. Add these fields:

| Field | Type | Value |
|-------|------|-------|
| `userId` | string | `d5P01AlLCoaEAN5ua3hJFzcIJu2` |
| `companyId` | string | `test-company-staging` |
| `jobId` | string | `test-job-staging` |
| `active` | boolean | `true` |

5. Click **Save**

---

### Step 3: Verify Data

Run this query again to confirm assignment exists:

```bash
curl -s "https://firestore.googleapis.com/v1/projects/sierra-painting-staging/databases/(default)/documents:runQuery" \
  -H "Content-Type: application/json" \
  --data '{
    "structuredQuery": {
      "from": [{"collectionId":"assignments"}],
      "where": {
        "compositeFilter": {
          "op":"AND",
          "filters":[
            {"fieldFilter":{"field":{"fieldPath":"userId"},"op":"EQUAL","value":{"stringValue":"d5P01AlLCoaEAN5ua3hJFzcIJu2"}}},
            {"fieldFilter":{"field":{"fieldPath":"companyId"},"op":"EQUAL","value":{"stringValue":"test-company-staging"}}},
            {"fieldFilter":{"field":{"fieldPath":"active"},"op":"EQUAL","value":{"booleanValue":true}}}
          ]
        }
      },
      "limit": 1
    }
  }'
```

**Expected Output (should now show 1 document):**
```json
[
  {
    "document": {
      "name": "projects/sierra-painting-staging/databases/(default)/documents/assignments/test-assignment-staging",
      "fields": {
        "userId": {"stringValue": "d5P01AlLCoaEAN5ua3hJFzcIJu2"},
        ...
      }
    },
    "readTime": "..."
  }
]
```

---

### Step 4: Test Clock-In

1. **Hard refresh browser**: `Ctrl + Shift + R` (Windows) or `Cmd + Shift + R` (Mac)
2. Click **Clock In** button
3. **Expected console logs:**
   ```
   ✅ activeJobProvider: Found 1 assignments
   ✅ activeJobProvider: Job ID from assignment = test-job-staging
   ✅ activeJobProvider: Fetching job document...
   ✅ activeJobProvider: Job doc exists = true
   ✅ Step 7: Calling clockIn API...
   ✅ Step 7: API response received - ID: [entry-id]
   ```

4. **UI should show:**
   - "Clocked In" status
   - Job name and timer
   - Clock Out button appears

---

## 🎯 WHAT THIS FIXES

| Issue | Status Before | Status After |
|-------|---------------|--------------|
| Assignment query returns empty | ❌ | ✅ Returns 1 doc |
| activeJobProvider hangs | ❌ | ✅ Resolves quickly |
| UI shows infinite spinner | ❌ | ✅ Shows job details |
| Clock-in fails | ❌ | ✅ Creates time entry |

---

## 📊 EVIDENCE SUMMARY

### Question 1: Assignment Existence ❌
```json
[{"readTime": "2025-10-13T03:30:38.847843Z"}]
```
**Zero documents** → This is the blocker

### Question 2: Index Confirmation ✅
```json
{
  "collectionId": "assignments",
  "fields": [
    {"fieldPath": "userId", "order": "ASCENDING"},
    {"fieldPath": "companyId", "order": "ASCENDING"},
    {"fieldPath": "active", "order": "ASCENDING"}
  ]
}
```
**Deployed successfully** → Not the issue

### Question 3: Rules Allow Read ✅
```javascript
allow read: if authed() && resource.data.companyId == claimCompany();
```
**Rules are correct** → Would allow read if docs existed

### Question 4: App Check Status ⚠️
```json
{"verifications": {"auth": "VALID", "app": "MISSING"}}
```
**App Check present but disabled** → Not blocking

### Question 5: Logs Around Stall
```
🟢 activeJobProvider: Querying assignments...
[STALL - No "Found X assignments" log]
```
**Query succeeds but returns empty** → Confirmed

---

## 🔬 TECHNICAL ROOT CAUSE

**Code Flow:**
1. `activeJobProvider` queries Firestore at timeclock_providers.dart:125-135
2. Query succeeds with 200 OK
3. BUT snapshot.docs is empty (0 results)
4. Code returns `null` at line 141
5. Worker dashboard line 493 checks `if (job == null)`
6. Throws generic exception: "No active job assigned"
7. UI catches exception but shows "Unable to complete" with spinner

**Why No Timeout:**
- The Firestore query has a 10-second timeout (line 132-135)
- BUT the query **succeeds** (doesn't timeout)
- It just returns empty results
- The provider resolves to `null` almost instantly
- But UI rendering shows spinner while waiting for the error state

**Fix:**
Once assignment exists, query will return 1 document → `job != null` → clock-in proceeds to API call.

---

## 🚀 ALTERNATIVE: Automated Seed (if you have service account key)

If you have `firebase-service-account-staging.json`:

```bash
node seed_test_data.cjs
```

Otherwise, use the manual Console instructions above (faster).

---

## ✅ SUCCESS CRITERIA

After seeding, you should be able to:
1. ✅ Clock in successfully
2. ✅ See "Currently Working" status
3. ✅ See timer counting elapsed time
4. ✅ Clock out successfully
5. ✅ See completed time entry in "Recent Entries"

---

## 📞 NEXT STEPS AFTER FIX

Once clock-in works:
1. Test clock-out flow
2. Fix "This Week's Summary" index (separate issue)
3. Test admin dashboard
4. Re-enable App Check properly
5. Re-enable geofencing for production
