# Staging Verification Checklist - Admin Dashboard Final Hardening

**Branch**: `admin/final-debug-harden`
**Deployment URL**: https://sierra-painting-staging.web.app
**Date**: October 13, 2025

---

## ✅ Changes Implemented

### 1. App Check Configuration ✅
- **Web App ID**: `1:271985878317:web:554db8ba14a801be589fa4` (verified match)
- **Debug Token**: Removed from public index.html
- **reCAPTCHA v3**: Configured for staging domains
- **Status**: Clean and production-ready

### 2. Claims Freshness ✅
- **Enhancement**: Auto-refresh ID token if role or companyId claims are missing
- **File**: `lib/core/auth/user_role.dart:132-139`
- **Logic**: Detects missing claims → forces `getIdToken(true)` → re-fetches claims
- **Logging**: Prints before/after refresh for debugging

### 3. Provider Deadlock Prevention ✅
- **No `.future` waits**: All admin providers use synchronous `currentCompanyIdProvider`
- **keepAlive()**: Prevents provider dispose/re-create cycles
- **Hard timeouts**: All Firestore queries use `Future.any([q.get(), delayed(...)])`
- **Status**: Already implemented from previous session

### 4. Firestore Index Alignment ✅
- **Index**: `collectionId: time_entries, fields: [companyId ASC, clockInAt DESC]`
- **Status**: Deployed and enabled
- **Query**: Matches index exactly (no status filter by default)

### 5. Probes & Telemetry ✅
- **ProviderObserver**: Logs provider lifecycle in debug mode
- **Single-doc probe**: `testSingleDocRead()` method in repository
- **Refresh token action**: Button in admin UI to manually refresh claims
- **Admin plumbing probe**: Shows green/orange/red status for diagnostics

### 6. Fallback Switch ✅
- **Environment flag**: `ADMIN_USE_STATUS_FILTER`
- **Default**: `false` (uses new 2-field index)
- **Emergency use**: Set to `true` to use old 3-field index with status filter
- **Command**: `flutter build web --release --dart-define=ENABLE_APP_CHECK=true --dart-define=ADMIN_USE_STATUS_FILTER=true`

---

## 📋 Verification Steps

### Step 1: App Check Verification
Navigate to staging and check browser console:

**Expected Logs**:
```
App Check: activation succeeded (debug mode enabled in index.html).
```

**Check for 400 errors**:
- Open DevTools → Network tab
- Filter for "exchangeRecaptchaV3Token" or "getAppCheckToken"
- **Expected**: 200 OK responses (no 400 Bad Request)

**Status**: ⬜ Pending verification

---

### Step 2: Claims Loading
After login, check console for:

**Expected Logs**:
```
Claims loaded: {role: admin, companyId: test-company-staging, updatedAt: ...}
```

**If claims missing on first load**:
```
[UserProfile] Claims missing (role=null, companyId=null), forcing refresh...
[UserProfile] After refresh: role=admin, companyId=test-company-staging
```

**Status**: ⬜ Pending verification

---

### Step 3: Admin Dashboard Load Time
1. Login as admin user
2. Navigate to "Time Entry Review" screen
3. **Start timer** when page loads
4. **Stop timer** when entries appear (or error shown)

**Expected**: Dashboard loads in **≤ 3 seconds**

**Check Console Logs**:
```
[AdminRepo] getPendingEntries START - companyId=test-company-staging
[AdminRepo] Executing query (fallback=all-entries)...
[AdminRepo] ✅ SUCCESS - docs=7
```

**Status**: ⬜ Pending verification

---

### Step 4: Admin Probe Status
Check the bottom of the admin screen for probe chip:

**Expected States**:
- 🟢 **Green** `OK_test-company-staging` → Provider chain works
- 🟠 **Orange** `NO_COMPANY_YET` → Waiting for claims
- 🔵 **Blue** `LOADING` → Provider initializing
- 🔴 **Red** `ERROR` → Provider error

**Expected Result**: 🟢 Green within 1-2 seconds

**Status**: ⬜ Pending verification

---

### Step 5: Query Success/Timeout
Check if queries complete or timeout:

**Success Case** (expected):
```
[AdminRepo] ✅ SUCCESS - docs=N
```
Then UI shows N entry cards (or "All caught up!" if 0)

**Timeout Case** (if index not ready):
```
[AdminRepo] ❌ ERROR: TimeoutException: time_entries query timeout (20s)
```
Then UI shows error banner with "Refresh admin token" button

**Status**: ⬜ Pending verification

---

### Step 6: Network Tab - No App Check Rejections
In DevTools → Network tab:

1. Filter for requests to Firestore
2. Look for `RunQuery` or `BatchGet` requests
3. Check response status

**Expected**:
- All Firestore requests: **200 OK**
- No 401 Unauthorized (App Check working)
- No 403 Forbidden (Rules working)
- No 400 Bad Request (App Check token valid)

**Status**: ⬜ Pending verification

---

### Step 7: Firestore Index Status
Navigate to Firebase Console → Firestore → Indexes:

**URL**: https://console.firebase.google.com/project/sierra-painting-staging/firestore/indexes

**Check for index**:
- **Collection**: `time_entries`
- **Fields**: `companyId (ASC)`, `clockInAt (DESC)`
- **Status**: **Enabled** ✅ (not "Building")

**Screenshot**: ⬜ Take screenshot of index list

**Status**: ⬜ Pending verification

---

### Step 8: Function Logs - No App Check Errors
Navigate to Firebase Console → Functions → Logs:

**URL**: https://console.firebase.google.com/project/sierra-painting-staging/functions/logs

**Check for**:
- ❌ No "App Check token verification failed" errors
- ❌ No "Missing App Check token" warnings
- ✅ Cloud Functions execute successfully

**Status**: ⬜ Pending verification

---

### Step 9: UI Rendering
Verify admin dashboard UI renders correctly:

**Expected**:
- ✅ Tab headers show counts (e.g., "Outside Fence 7")
- ✅ Entry cards render with all fields
- ✅ No infinite loading spinners
- ✅ Approve/Reject buttons are functional
- ✅ Search box works
- ✅ "Refresh admin token" button visible

**Status**: ⬜ Pending verification

---

### Step 10: Refresh Token Action
Test the manual refresh action:

1. Click "Refresh admin token" button at top
2. Wait for refresh to complete
3. Check console logs

**Expected Logs**:
```
[UserProfile] Claims missing (role=..., companyId=...), forcing refresh...
[UserProfile] After refresh: role=admin, companyId=test-company-staging
[AdminRepo] getPendingEntries START - companyId=test-company-staging
[AdminRepo] ✅ SUCCESS - docs=N
```

**Expected UI**: Dashboard re-loads with fresh data

**Status**: ⬜ Pending verification

---

## 🐛 Troubleshooting

### If Dashboard Still Hangs

**Check 1: Index Status**
- Go to Firestore Console → Indexes
- Verify "Enabled" status (not "Building")
- Wait 5-10 minutes if still building

**Check 2: Use Fallback Index**
```bash
flutter build web --release \
  --dart-define=ENABLE_APP_CHECK=true \
  --dart-define=ADMIN_USE_STATUS_FILTER=true

firebase deploy --only hosting --project sierra-painting-staging
```

**Check 3: Verify Claims**
- Console should show: `Claims loaded: {role: admin, companyId: test-company-staging}`
- If missing, click "Refresh admin token" button

---

### If App Check 400 Errors

**Check 1: reCAPTCHA Domains**
- Go to Google Cloud Console → Security → reCAPTCHA Enterprise
- Verify domains include:
  - `sierra-painting-staging.web.app`
  - `sierra-painting-staging.firebaseapp.com`
  - `localhost` (for dev)

**Check 2: Web App ID**
- Verify `firebase_options.dart` web appId matches Firebase Console
- Current: `1:271985878317:web:554db8ba14a801be589fa4`

**Check 3: Token Refresh**
- Try logging out and back in
- Clear browser cache
- Check for debug tokens in console (should not exist in production)

---

### If No Entries Show

**Check 1: Data Exists**
- Go to Firestore Console → Data → `time_entries` collection
- Verify documents exist with `companyId: "test-company-staging"`

**Check 2: Query Logs**
- Console should show `[AdminRepo] ✅ SUCCESS - docs=0` or `docs=N`
- If shows `docs=0`, create test entries manually

**Check 3: Status Filter**
- Current query shows ALL entries (no status filter)
- If you need pending-only, use fallback flag

---

## 📸 Evidence to Collect

### Required Screenshots:
1. ✅ **Admin Dashboard** - Showing loaded entries with counts
2. ✅ **Console Logs** - SUCCESS message with document count
3. ✅ **Firestore Indexes** - Showing "Enabled" status
4. ✅ **Network Tab** - 200 OK responses for Firestore queries
5. ✅ **Admin Probe** - Green status at bottom of screen

### Required Console Logs:
```
Claims loaded: {role: admin, companyId: test-company-staging, ...}
[AdminRepo] getPendingEntries START - companyId=test-company-staging
[AdminRepo] Executing query (fallback=all-entries)...
[AdminRepo] ✅ SUCCESS - docs=7
```

### Optional Logs (for debugging):
```
🟢 add userProfileProvider
🟢 add currentCompanyIdProvider
🔁 update pendingEntriesProvider -> AsyncValue<List<TimeEntry>>
```

---

## ✅ Definition of Done

All of the following must be true:

- [ ] Admin dashboard loads in ≤ 3 seconds
- [ ] Console shows `[AdminRepo] ✅ SUCCESS - docs=N`
- [ ] No App Check 400 errors in Network tab
- [ ] Firestore index shows "Enabled" status
- [ ] Admin probe shows green `OK_test-company-staging`
- [ ] Entry cards render with all fields
- [ ] No infinite loading spinners
- [ ] Refresh token button works
- [ ] No timeout errors after 20 seconds
- [ ] Rules enforced (companyId-based access)

---

## 🚀 Next Steps After Verification

### If All Checks Pass ✅
1. Take all required screenshots
2. Copy console logs to file
3. Commit verification evidence
4. Push branch to GitHub
5. Create PR with evidence

### If Any Check Fails ❌
1. Document the exact failure
2. Copy error logs
3. Take screenshot of error
4. Post in this thread for debugging
5. Do NOT create PR until resolved

---

## 📝 Commit History

### Current Branch Commits:
```
1b7c3ed - admin: force ID-token refresh if claims missing; already have no .future waits and hard timeouts
```

### Previous Session Commits (Already in Main):
```
a7c1cdf - debug: enable Firestore web logging in debug builds
b748f13 - debug: add single-doc read probe
5d5ac16 - admin: add ENV switch for fallback
faed99a - admin: align query with new index; enforce hard timeout
999f74f - debug: temporarily show ALL statuses for testing
4483c50 - fix: deploy indexes to correct (default) database
...
```

---

## 🔗 Relevant Links

- **Staging URL**: https://sierra-painting-staging.web.app
- **Firebase Console**: https://console.firebase.google.com/project/sierra-painting-staging
- **Firestore Indexes**: https://console.firebase.google.com/project/sierra-painting-staging/firestore/indexes
- **Functions Logs**: https://console.firebase.google.com/project/sierra-painting-staging/functions/logs
- **App Check**: https://console.firebase.google.com/project/sierra-painting-staging/appcheck

---

*Document generated: October 13, 2025*
*Branch: admin/final-debug-harden*
*Deployment: Staging (verified pending)*
