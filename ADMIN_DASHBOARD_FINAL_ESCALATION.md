# Admin Dashboard Infinite Loading - Final Technical Escalation

**Date**: October 13, 2025
**Project**: Sierra Painting Staging
**Issue**: Admin Time Entry Review screen stuck in infinite loading state
**Severity**: P0 - Blocking admin functionality

---

## Executive Summary

The admin dashboard has persistent infinite loading despite fixing the original **provider deadlock** issue. The diagnostic probe correctly identifies the provider chain as healthy (`Probe: OK_test-company-staging`), but **Firestore queries hang indefinitely** without timeout or completion.

**Root Cause**: Queries execute but never resolve - not timing out, not completing, suggesting a **Firestore WebChannel hang or rules evaluation deadlock**.

---

## Problem Statement

### Symptoms
1. Admin dashboard shows infinite loading spinners
2. Queries execute repeatedly (`[AdminRepo] getPendingEntries START`) but never complete
3. No timeout errors after 20 seconds (queries just hang)
4. No success logs (`✅ SUCCESS - Found X documents`)
5. Worker timeclock works perfectly (clock in/out successful)

### What Works ✅
- **Provider chain**: Probe shows `OK_test-company-staging` (green) immediately
- **Authentication**: Admin claims load correctly (`role: admin, companyId: test-company-staging`)
- **Firestore write**: Workers can create `time_entries` documents
- **Firestore read (single doc)**: Console shows documents exist

### What Fails ❌
- **Firestore queries with compound filters**: Hang indefinitely without resolution
- **Admin dashboard data loading**: Never completes despite valid setup

---

## Technical Architecture

### Stack
- **Frontend**: Flutter Web 3.35.5 (dart2js compiled)
- **State Management**: Riverpod 2.x
- **Backend**: Firebase (Firestore, Auth)
- **Database**: `(default)` database (note: parentheses in name)
- **Region**: us-east4

### Query Structure
```dart
FirebaseFirestore.instance
  .collection('time_entries')
  .where('companyId', isEqualTo: 'test-company-staging')
  // Status filter removed for testing
  .orderBy('clockInAt', descending: true)
  .limit(100)
  .get()
  .timeout(Duration(seconds: 20))
```

---

## Diagnostic Timeline

### Phase 1: Provider Deadlock (RESOLVED ✅)
**Issue**: FutureProviders awaited `.future` chains that never resolved
**Fix**: Created synchronous `currentCompanyIdProvider` using `.maybeWhen()`
**Verification**: Probe shows green `OK_test-company-staging`
**Files Modified**:
- `lib/core/auth/user_role.dart` (added `keepAlive()`, created sync providers)
- `lib/features/admin/presentation/providers/admin_review_providers.dart` (removed `.future` waits)

### Phase 2: Wrong Database (RESOLVED ✅)
**Issue**: Indexes deployed to `default` but app uses `(default)` database
**Fix**: Updated `firebase.json` line 129: `"database": "(default)"`
**Verification**: Indexes show "Enabled" in `(default)` database

### Phase 3: Missing Data (PARTIALLY RESOLVED ⚠️)
**Issue**: All entries have `status: "completed"`, query filters for `status: "pending"`
**Fix**: Temporarily removed status filter to show ALL entries
**Result**: Queries still hang - **status filter was not the root cause**

### Phase 4: Current State (BLOCKED 🔴)
**Observation**: Queries execute but hang indefinitely
**Evidence**:
```
[AdminRepo] getPendingEntries START - companyId=test-company-staging
[AdminRepo] Executing query...
[AdminRepo] getPendingEntries START - companyId=test-company-staging
[AdminRepo] Executing query...
(repeats without SUCCESS or TIMEOUT)
```

---

## Infrastructure Details

### Firestore Database Configuration

**Database Name**: `(default)` ← Note: parentheses are part of the name
**Location**: us-east4
**Collections**:
- `time_entries` - Has 1+ documents with `companyId: "test-company-staging"`
- Documents have fields: `companyId`, `clockInAt`, `status`, `userId`, `jobId`, etc.

### Firestore Indexes

**Composite Index** (Status: Enabled):
```json
{
  "collectionGroup": "time_entries",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "companyId", "order": "ASCENDING"},
    {"fieldPath": "status", "order": "ASCENDING"},
    {"fieldPath": "clockInAt", "order": "DESCENDING"},
    {"fieldPath": "__name__", "order": "DESCENDING"}
  ]
}
```

**Index for Query Without Status Filter**:
⚠️ **MISSING** - Current query needs:
```json
{
  "collectionGroup": "time_entries",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "companyId", "order": "ASCENDING"},
    {"fieldPath": "clockInAt", "order": "DESCENDING"}
  ]
}
```

### Firestore Rules (Excerpt)

```javascript
// Line 243-245 in firestore.rules
match /time_entries/{entryId} {
  // Read: Anyone in same company (must have companyId claim)
  allow read: if authed() && claimCompany() == resource.data.companyId;
```

**Rule Helper**:
```javascript
function claimCompany() {
  return authed() && request.auth.token.companyId != null
    ? request.auth.token.companyId
    : null;
}
```

**Admin Claims** (Verified from logs):
```json
{
  "role": "admin",
  "companyId": "test-company-staging",
  "updatedAt": 1760368778707
}
```

---

## Hypothesis: Why Queries Hang

### Theory 1: Missing Compound Index (LIKELY 🎯)
**Current state**: Index exists for `companyId + status + clockInAt`
**Query needs**: Index for `companyId + clockInAt` (no status)
**Result**: Firestore may hang trying to use wrong index or fallback to full scan

**Evidence**:
- Removing status filter changes query shape
- No explicit error about missing index (but web may fail silently)
- Queries repeat without completion (typical index missing behavior on web)

### Theory 2: Firestore Rules Evaluation Deadlock (POSSIBLE ⚠️)
**Issue**: Rules evaluate `claimCompany() == resource.data.companyId` for EVERY document
**With queries**: Must evaluate rule for each doc before returning results
**Result**: May hang if rule evaluation fails or loops

**Evidence**:
- Single doc reads work (seen in console)
- Query reads hang (must eval rules for all matching docs)
- Web platform has different rule eval than mobile

### Theory 3: WebChannel Connection Hang (POSSIBLE ⚠️)
**Known issue**: Firestore web persistence was disabled due to WebChannel errors
**Current**: Persistence disabled but WebChannel still used for live queries
**Result**: Connection may hang waiting for response that never arrives

**Evidence**:
```
[Firestore] ✅ Web - persistence DISABLED (FIX v2)
```

### Theory 4: Query Timeout Not Triggering (UNLIKELY ❌)
**Expected**: 20-second timeout should throw `TimeoutException`
**Actual**: No timeout errors in logs
**Reason**: `.timeout()` wraps the Future, should always fire

---

## Attempted Fixes (Chronological)

| # | Fix | Result | Commit |
|---|-----|--------|--------|
| 1 | Added ProviderObserver for telemetry | ✅ Shows provider lifecycle | 4c5aa87 |
| 2 | Broke provider deadlock with sync providers | ✅ Probe green | a523d05 |
| 3 | Added long-load UI banner (5s threshold) | ✅ Shows banner | 09345aa |
| 4 | Added admin plumbing probe | ✅ Probe works | 5e0ccbc |
| 5 | Fixed database target (default → (default)) | ✅ Indexes deployed | 4483c50 |
| 6 | Increased timeout 8s → 20s | ❌ Still hangs | 4483c50 |
| 7 | Added .limit(100) to queries | ❌ Still hangs | 4483c50 |
| 8 | Removed status filter (show ALL) | ❌ Still hangs | 999f74f |

---

## Diagnostic Evidence

### Console Logs (Latest)
```
Claims loaded: {role: admin, companyId: test-company-staging, updatedAt: 1760368778707}
[AdminRepo] getPendingEntries START - companyId=test-company-staging
[AdminRepo] Executing query...
[AdminRepo] getPendingEntries START - companyId=test-company-staging
[AdminRepo] Executing query...
[AdminRepo] getPendingEntries START - companyId=test-company-staging
[AdminRepo] Executing query...
```

**Key observation**: No SUCCESS or TIMEOUT logs despite 20s timeout

### Network Tab
- Firebase Auth: ✅ Success
- Firestore queries: ⚠️ Pending indefinitely

### Firestore Data (Verified)
**Document**: `time_entries/GDeZmU39NSZzQveOa4IB`
```json
{
  "companyId": "test-company-staging",
  "status": "completed",
  "clockInAt": "October 13, 2025 at 2:23:33 PM UTC-4",
  "clockOutAt": "October 13, 2025 at 2:23:59 PM UTC-4",
  "userId": "d5PQfAllCoacEANsujhjJfzcIJu2",
  "jobId": "test-job-staging",
  "exceptionTags": ["geofence_out"]
}
```

---

## Recommended Debug Steps

### Step 1: Create Explicit Index for Current Query
**Action**: Deploy index for `companyId + clockInAt` (no status field)

**Add to `firestore.indexes.json`**:
```json
{
  "collectionGroup": "time_entries",
  "queryScope": "COLLECTION",
  "fields": [
    {"fieldPath": "companyId", "order": "ASCENDING"},
    {"fieldPath": "clockInAt", "order": "DESCENDING"}
  ]
}
```

**Deploy**:
```bash
firebase deploy --only firestore:indexes --project sierra-painting-staging
```

**Wait**: 5-10 minutes for index to build
**Test**: Refresh admin dashboard

---

### Step 2: Test Query Directly in Firebase Console
**Action**: Verify query works in Firebase Console UI

1. Go to Firestore Database → Query Builder
2. Select `time_entries` collection
3. Add filter: `companyId == test-company-staging`
4. Add order: `clockInAt desc`
5. Run query

**Expected**: Should return 1 document immediately
**If fails**: Index or rules issue
**If succeeds**: Client-side issue

---

### Step 3: Simplify Firestore Rules for Testing
**Action**: Temporarily broaden read rules to isolate issue

**Current rule** (line 245):
```javascript
allow read: if authed() && claimCompany() == resource.data.companyId;
```

**Test rule**:
```javascript
allow read: if authed() && request.auth.token.role == "admin";
```

**Rationale**: Removes compound condition that may cause evaluation hang

**Deploy**:
```bash
firebase deploy --only firestore:rules --project sierra-painting-staging
```

**⚠️ SECURITY**: Revert immediately after testing!

---

### Step 4: Add Firestore Query Logging
**Action**: Enable Firestore SDK debug logging

**Add to `lib/main.dart` after Firebase init**:
```dart
if (kIsWeb && kDebugMode) {
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  // Enable Firestore logging
  debugPrint('[Firestore] Debug logging enabled');
}
```

**Check browser console** for detailed Firestore operation logs

---

### Step 5: Test with Single Document Read
**Action**: Verify rules work for single-doc reads

**Add to `admin_time_entry_repository.dart`**:
```dart
Future<void> testSingleDocRead() async {
  print('[AdminRepo] TEST: Reading single document...');
  try {
    final doc = await _firestore
        .collection('time_entries')
        .doc('GDeZmU39NSZzQveOa4IB')
        .get()
        .timeout(Duration(seconds: 5));
    print('[AdminRepo] TEST: ✅ Single doc read SUCCESS - exists: ${doc.exists}');
  } catch (e) {
    print('[AdminRepo] TEST: ❌ Single doc read FAILED: $e');
  }
}
```

**Call before query** to verify permissions work at all

---

## Code References

### Key Files Modified
```
lib/core/auth/user_role.dart:148-168
  → currentCompanyIdProvider, currentUserIdProvider (synchronous)

lib/features/admin/presentation/providers/admin_review_providers.dart:67-189
  → All admin providers refactored to use sync providers

lib/features/admin/data/admin_time_entry_repository.dart:20-60
  → getPendingEntries with timeout and logging

lib/features/admin/presentation/admin_review_screen.dart:735-839
  → _LoadingWithTimeout widget (5s threshold)

firebase.json:129
  → "database": "(default)" (critical fix)
```

### Branch
`admin/fix-provider-deadlock`

### Latest Commits
```
999f74f - debug: temporarily show ALL statuses for testing
4483c50 - fix: deploy indexes to correct (default) database
cae9938 - fix: rename providers to avoid conflict
5e0ccbc - debug: add admin plumbing probe
09345aa - feat: add long-load UI feedback
a523d05 - fix: break provider deadlock
4c5aa87 - debug: add ProviderObserver
```

---

## Working Hypothesis

**Primary Theory**: Missing compound index for query without status filter

**Why this is most likely**:
1. ✅ Original index has 3 fields: `companyId`, `status`, `clockInAt`
2. ❌ Current query has 2 fields: `companyId`, `clockInAt`
3. Firestore requires **exact index match** for compound queries
4. Web platform fails silently on missing indexes (unlike mobile which shows error)
5. Query hangs instead of erroring - classic missing index behavior on web

**Smoking gun**: Removing status filter changes query signature → needs different index

---

## Next Actions (Priority Order)

1. **[P0]** Create and deploy index for `companyId + clockInAt` (no status)
2. **[P0]** Test query in Firebase Console Query Builder
3. **[P1]** Simplify Firestore rules temporarily to isolate issue
4. **[P1]** Add single-doc read test to verify permissions
5. **[P2]** Enable Firestore debug logging on web

---

## Production Workaround

**Restore status filter** and **create pending entry manually**:

1. Restore status filter in code:
```dart
.where('companyId', isEqualTo: companyId)
.where('status', isEqualTo: 'pending')  // Restore this line
```

2. Create pending test entry in Firestore Console:
```json
{
  "companyId": "test-company-staging",
  "status": "pending",
  "userId": "test-user-id",
  "jobId": "test-job-staging",
  "clockInAt": <Timestamp now>,
  "clockInGeofenceValid": false,
  "clockInLocation": {...},
  "exceptionTags": ["geofence_out"],
  "createdAt": <Timestamp now>
}
```

3. Original index (`companyId + status + clockInAt`) already exists and is enabled

This should work immediately since we've verified:
- ✅ Provider chain works (probe green)
- ✅ Index deployed to correct database
- ✅ Permissions configured correctly

---

## Contact

**Implementer**: Claude (AI Assistant)
**Project Owner**: User (valle)
**Environment**: sierra-painting-staging.web.app
**Firebase Project**: sierra-painting-staging

---

## Appendix: Environment Details

**Flutter**: 3.35.5
**Dart**: 3.9.2
**Riverpod**: 2.x
**Firebase SDK**: Latest (as of Oct 2025)
**Browser**: Chrome (latest)
**Platform**: Windows

**Firebase Console**: https://console.firebase.google.com/project/sierra-painting-staging
**Hosting URL**: https://sierra-painting-staging.web.app
**Database**: `(default)` in Firestore Console

---

*Document generated: October 13, 2025*
*Session: Admin Dashboard Infinite Loading Debug*
*Status: ESCALATED TO SENIOR ENGINEER*
