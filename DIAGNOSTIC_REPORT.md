# Comprehensive Diagnostic Report - Clock-In Failure

**Generated:** 2025-10-13 03:22 UTC
**Project:** sierra-painting-staging
**Environment:** Staging (us-east4)

---

## EXECUTIVE SUMMARY

Clock-in functionality is **BLOCKED** at the assignment query stage. The UI never reaches the Cloud Function API call. Based on console logs and code analysis, the issue is one of the following:

1. **No active assignment exists** for the test user in Firestore
2. **App Check** is still blocking despite `ENFORCE_APPCHECK=false`
3. **Firestore rules** are blocking the assignments query
4. **Missing composite index** for assignments query

---

## EVIDENCE FROM CONSOLE LOGS

### What's Working:
✅ Location services enabled
✅ Location permission granted (LocationPermissionStatus.granted)
✅ Location obtained (lat: 41.88254659756, lng: -71.394537760, accuracy: 111m)
✅ activeJobProvider starts execution
✅ User UID retrieved: `d5P01AlLCoaEAN5ua3hJFzcIJu2`
✅ Company ID claim retrieved: `test-company-staging`
✅ Starting assignments query...

### What's NOT Working:
❌ **Assignments query never returns** - No debug log for "Found X assignments"
❌ **No API call is made** - Never reaches Step 7 (Calling clockIn API)
❌ **App Check 400 errors** continue in console despite `ENFORCE_APPCHECK=false`
❌ **UI shows spinner indefinitely** - No error, no success

---

## ROOT CAUSE ANALYSIS

### Issue #1: Assignments Query Hanging or Failing

**Code Location:** `lib/features/timeclock/presentation/providers/timeclock_providers.dart:124-135`

```dart
final assignmentsQuery = await db
    .collection('assignments')
    .where('userId', isEqualTo: user.uid)
    .where('companyId', isEqualTo: company)
    .where('active', isEqualTo: true)
    .limit(1)
    .get()
    .timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('Assignment query timed out'),
    );
```

**Why it's failing:**
1. **No active assignment**: The test user may not have an assignment record in Firestore
2. **Firestore rules blocking**: Rules require authentication and company match
3. **Missing index**: Multi-field query (userId + companyId + active) may require composite index

**Evidence:**
- Console log shows "Querying assignments..." but NEVER shows "Found X assignments"
- No timeout error is shown (would appear after 10 seconds)
- UI shows loading spinner in job section (the grey loading bar)

---

### Issue #2: App Check Still Enforcing

**Evidence from Console:**
```
AppCheck: Requests throttled due to previous 400 error.
Attempts allowed again after 00m:03s (appCheck/throttled).
```

**Code Location:** `functions/.env:6`
```bash
ENFORCE_APPCHECK=false
```

**Problem:**
- Setting environment variable doesn't disable App Check on the **client side**
- The Flutter web app is still trying to get App Check tokens
- Even though server-side enforcement is disabled, client-side is throwing errors

**Impact:**
- These errors are likely red herrings (not blocking the clock-in)
- But they indicate App Check is not properly configured for web

---

### Issue #3: Firestore Rules May Block Assignments Read

**Code Location:** `firestore.rules:209-223`

```javascript
match /assignments/{assignmentId} {
  // Read: Anyone in the same company
  allow read: if authed()
    && resource.data.companyId == claimCompany();

  // Create/Update/Delete: Admin/Manager only
  allow create, update, delete: if authed()
    && hasAnyRole(["admin", "manager"])
    && (
      // On create, must set companyId
      (request.resource.data.companyId == claimCompany()) ||
      // On update/delete, existing must match
      (resource.data.companyId == claimCompany())
    );
}
```

**Rule Analysis:**
- Read requires: `authed()` AND `resource.data.companyId == claimCompany()`
- This means the user must have a `companyId` custom claim
- The claim must match the `companyId` field on the assignment document

**Verification Needed:**
1. Does the test user have `companyId` custom claim set?
2. Do assignment documents have the correct `companyId` field?

---

### Issue #4: Missing Composite Index for Assignments

**Current Index:** `firestore.indexes.json` has these assignment indexes:

```json
{
  "collectionGroup": "assignments",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "companyId", "order": "ASCENDING" },
    { "fieldPath": "active", "order": "ASCENDING" }
  ]
}
```

**BUT** this is a `collectionGroup` index, not a `collectionId` index!

The query in the code uses `db.collection('assignments')` which is **NOT** a collection group query.

**Fix Required:** Add a regular collection index:
```json
{
  "collectionId": "assignments",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "companyId", "order": "ASCENDING" },
    { "fieldPath": "active", "order": "ASCENDING" }
  ]
}
```

---

## DATA VALIDATION CHECKLIST

### Critical Data That Must Exist:

1. **User Custom Claims:**
   - UID: `d5P01AlLCoaEAN5ua3hJFzcIJu2`
   - Must have: `{ "role": "worker", "companyId": "test-company-staging" }`

2. **Assignment Document:**
   - Collection: `assignments`
   - Must have document where:
     - `userId == "d5P01AlLCoaEAN5ua3hJFzcIJu2"`
     - `companyId == "test-company-staging"`
     - `active == true`
     - `jobId` points to valid job

3. **Job Document:**
   - Collection: `jobs`
   - Must have document where:
     - `companyId == "test-company-staging"`
     - Has `latitude` and `longitude` fields for geofence
     - Has `address` and `name`

---

## RECOMMENDED ACTIONS (Priority Order)

### 🔴 CRITICAL - Action #1: Verify Test Data Exists

**Command to check user claims:**
```powershell
firebase auth:export users.json --project sierra-painting-staging
# Then search for user d5P01AlLCoaEAN5ua3hJFzcIJu2
```

**Command to check assignments:**
```bash
# Open Firestore console and manually query:
# Collection: assignments
# Filter: userId == "d5P01AlLCoaEAN5ua3hJFzcIJu2"
# Filter: active == true
```

**If no data exists:** Need to run seed script or manually create test data

---

### 🔴 CRITICAL - Action #2: Add Missing Firestore Index

**File:** `firestore.indexes.json`

**Add this index:**
```json
{
  "collectionId": "assignments",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "userId", "order": "ASCENDING" },
    { "fieldPath": "companyId", "order": "ASCENDING" },
    { "fieldPath": "active", "order": "ASCENDING" }
  ]
}
```

**Deploy:**
```bash
firebase deploy --only firestore:indexes --project sierra-painting-staging
```

---

### 🟡 MEDIUM - Action #3: Add Error Handling in activeJobProvider

**Problem:** Current code silently fails if query times out or returns empty

**Fix:** Add better error handling and debug logs

**Code Change:** `lib/features/timeclock/presentation/providers/timeclock_providers.dart:103-167`

Add try-catch and more granular logging:
```dart
try {
  final assignmentsQuery = await db.collection('assignments')...;
  debugPrint('🟢 activeJobProvider: Query returned ${assignmentsQuery.docs.length} docs');

  if (assignmentsQuery.docs.isEmpty) {
    debugPrint('🔴 activeJobProvider: No active assignment found for user');
    throw Exception('No active job assigned. Contact your manager.');
  }
} catch (e, stack) {
  debugPrint('🔴 activeJobProvider ERROR: $e');
  debugPrint('🔴 Stack: $stack');
  rethrow;
}
```

---

### 🟡 MEDIUM - Action #4: Fix App Check Client-Side

**Problem:** Web app tries to use App Check even when server enforcement is disabled

**Options:**

**Option A:** Properly configure App Check for web
1. Register web app in Firebase Console → App Check
2. Add debug token for staging domain
3. Ensure ReCAPTCHA site key is correct

**Option B:** Disable App Check entirely in Flutter web for staging
1. Edit `lib/main.dart` and conditionally skip App Check activation
2. Use `--dart-define=ENABLE_APP_CHECK=false` when building

---

### 🟢 LOW - Action #5: Improve UI Feedback

**Problem:** User sees infinite spinner with no error message

**Fix:** Add timeout to activeJobProvider and show error to user

**Code Change:** `lib/features/timeclock/presentation/worker_dashboard_screen.dart:489`

Wrap provider read in try-catch:
```dart
try {
  final job = await ref.read(activeJobProvider.future)
    .timeout(const Duration(seconds: 15));
  if (job == null) {
    throw Exception('No active job assigned. Contact your manager.');
  }
} on TimeoutException {
  throw Exception('Failed to load job assignment. Check your connection.');
}
```

---

## QUICK DEBUG COMMAND SEQUENCE

Run these commands to gather intelligence:

```powershell
# 1. Check if assignment exists
# Go to Firebase Console → Firestore → assignments collection
# Manually look for userId == "d5P01AlLCoaEAN5ua3hJFzcIJu2"

# 2. Check user's custom claims
firebase auth:export users.json --project sierra-painting-staging
# Search for "d5P01AlLCoaEAN5ua3hJFzcIJu2" in the JSON

# 3. Check function environment variables
firebase functions:config:get --project sierra-painting-staging

# 4. Check Firestore indexes status
firebase firestore:indexes --project sierra-painting-staging
```

---

## HYPOTHESIS RANKING

Based on evidence, here's the likelihood of each root cause:

| Hypothesis | Likelihood | Evidence |
|------------|-----------|----------|
| **No active assignment in database** | **90%** | Console shows query starts but never completes, no timeout error |
| **Missing Firestore composite index** | **70%** | Index exists as collectionGroup, not collectionId |
| **User missing companyId custom claim** | **30%** | Console shows claim retrieved successfully |
| **App Check blocking query** | **10%** | Errors shown but shouldn't block client-side Firestore reads |
| **Firestore rules blocking** | **10%** | Rules look correct for authenticated users |

---

## IMMEDIATE NEXT STEP

**Manually check Firebase Console for test data:**

1. Go to: https://console.firebase.google.com/project/sierra-painting-staging/firestore
2. Navigate to `assignments` collection
3. Check if ANY document exists where:
   - `userId == "d5P01AlLCoaEAN5ua3hJFzcIJu2"`
   - `active == true`
   - `companyId == "test-company-staging"`

**If NO documents exist:** The test user has no job assignment. Need to create one.

**If documents exist:** The query is failing due to missing index or rules issue.

---

## CONCLUSION

The clock-in flow is **blocked at Step 5** (Getting active job). The `activeJobProvider` Firestore query for assignments either:

1. **Returns zero results** (most likely - no test data)
2. **Fails due to missing index** (very likely)
3. **Times out silently** (possible due to no error handling)

**The App Check errors are a distraction** - they don't prevent client-side Firestore queries.

**Next action:** Check Firestore Console for assignment data. If missing, create test assignment. Then add the missing composite index for the assignments collection.
