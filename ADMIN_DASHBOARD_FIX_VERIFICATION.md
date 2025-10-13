# Admin Dashboard Fix - Verification Guide

**Date**: 2025-10-13
**Branch**: `admin/fix-infinite-loading-claims-refresh`
**Deployed to**: https://sierra-painting-staging.web.app

---

## ✅ Changes Deployed

### 1. Force ID Token Refresh (Auth Provider)
**File**: `lib/core/providers/auth_provider.dart`

- Added `userClaimsProvider` that automatically refreshes token if `role` or `companyId` claims are missing
- Updated `userRoleProvider` and `userCompanyProvider` to use the new claims provider
- This prevents infinite loading when users have cached tokens without claims

**Debug output**: Look for `🔄 Forcing ID token refresh` in browser console

### 2. Timeout & Error UI (Admin Queries)
**Files**:
- `lib/features/admin/data/admin_time_entry_repository.dart`
- `lib/features/admin/presentation/admin_review_screen.dart`

- Added 8-second timeout to Firestore queries
- Explicit error UI with:
  - Timeout detection (`TimeoutException`)
  - "Refresh Claims & Retry" button for timeouts
  - "Retry" button for other errors

**Test**: If admin dashboard times out, you should see:
- Orange clock icon
- "Can't load admin data" message
- "Refresh Claims & Retry" button

### 3. Firestore Rules - Bypass Removed
**File**: `firestore.rules`

- Removed temporary `hasAnyRole(["admin"])` bypass
- Now strictly enforces `companyId` claim matching

**This means**: Admin users MUST have both `role: "admin"` AND `companyId: "test-company-staging"` claims set

### 4. App Check Debug Token Removed
**File**: `web/index.html`

- Removed debug token from production build
- App Check will now use ReCAPTCHA v3 for web clients

---

## 🧪 Verification Checklist

### Pre-Test: Verify Custom Claims Are Set

Run this script to confirm claims are set server-side:

```bash
node verify_claims.cjs
```

**Expected output**:
```
👤 Admin User:
   UID: yqLJSx5NH1YHKa9WxIOhCrqJcPp1
   Email: [admin email]
   Custom Claims: {
     "role": "admin",
     "companyId": "test-company-staging",
     "updatedAt": [timestamp]
   }

✅ Admin claims are correct!
```

If claims are NOT set, run:
```bash
node fix_admin_claims.cjs
```

---

### Test 1: Claims Force-Refresh

**Scenario**: User with cached token (no claims) logs in

**Steps**:
1. Open https://sierra-painting-staging.web.app in **incognito mode**
2. Log in with admin credentials
3. Open browser console (F12)
4. Look for: `🔄 Forcing ID token refresh — missing role/companyId claims`
5. Look for: `✅ Claims loaded: {role: "admin", companyId: "test-company-staging", ...}`

**Expected**: Dashboard loads successfully without infinite spinners

**Browser Console Commands** (paste into console):
```javascript
// Check current claims
firebase.auth().currentUser.getIdTokenResult().then(r => {
  console.log('🔍 Current claims:', r.claims);
  console.log('   role:', r.claims.role);
  console.log('   companyId:', r.claims.companyId);
});
```

**Expected output**:
```
🔍 Current claims: {role: "admin", companyId: "test-company-staging", ...}
   role: admin
   companyId: test-company-staging
```

---

### Test 2: Admin Queries Succeed

**Scenario**: Admin dashboard loads pending time entries

**Steps**:
1. Navigate to `/dashboard` (should auto-route to Admin Review Screen)
2. Wait up to 8 seconds for data to load
3. Check summary stats card (should show counts)
4. Check entry list tabs (Outside Geofence, >12 Hours, etc.)

**Browser Console Commands**:
```javascript
// Manual query test
const db = firebase.firestore();
db.collection('time_entries')
  .where('companyId', '==', 'test-company-staging')
  .where('status', '==', 'pending')
  .orderBy('clockInAt', 'desc')
  .limit(3)
  .get()
  .then(s => {
    console.log('✅ Query succeeded! Found', s.size, 'documents');
    s.forEach(doc => console.log('  -', doc.id, doc.data()));
  })
  .catch(error => {
    console.error('❌ Query failed:', error.code, error.message);
  });
```

**Expected output**:
```
✅ Query succeeded! Found [N] documents
  - [entry ID] {companyId: "test-company-staging", status: "pending", ...}
```

---

### Test 3: Timeout Error Handling

**Scenario**: Simulate timeout by breaking network (optional advanced test)

**Steps**:
1. Open DevTools → Network tab
2. Throttle to "Slow 3G" or "Offline"
3. Refresh admin dashboard
4. Wait 8 seconds
5. Should see timeout error UI with "Refresh Claims & Retry" button

**OR** manually trigger timeout:

In browser console, override Firestore query temporarily:
```javascript
// This is just a test - don't do this in production!
// Override query to simulate timeout
const originalGet = firebase.firestore.Query.prototype.get;
firebase.firestore.Query.prototype.get = function() {
  return new Promise((resolve, reject) => {
    setTimeout(() => reject(new Error('TimeoutException: Simulated timeout')), 9000);
  });
};
```

Then refresh `/dashboard`. Should show timeout error UI.

---

### Test 4: Firestore Rules Enforcement

**Scenario**: Verify rules require `companyId` claim

**Browser Console Test**:
```javascript
// Test 1: Query with valid claim (should succeed)
firebase.auth().currentUser.getIdTokenResult().then(r => {
  console.log('Current companyId claim:', r.claims.companyId);

  if (r.claims.companyId !== 'test-company-staging') {
    console.warn('⚠️  companyId claim is missing or incorrect!');
  }
});

// Test 2: Try to read time_entries (should succeed if claim is valid)
firebase.firestore().collection('time_entries')
  .where('companyId', '==', 'test-company-staging')
  .limit(1)
  .get()
  .then(s => console.log('✅ Read permission granted, found', s.size, 'docs'))
  .catch(e => console.error('❌ Read permission denied:', e.code, e.message));
```

**Expected output**:
```
Current companyId claim: test-company-staging
✅ Read permission granted, found [N] docs
```

---

### Test 5: UI States - No Infinite Spinners

**Check all these states render correctly**:

| State | What to Check | Expected UI |
|-------|---------------|-------------|
| **Loading** | Initial load | Spinner for max 8 seconds |
| **Success** | Data loaded | Summary stats + entry list |
| **Empty** | No entries | "No [category] entries" + "All caught up!" |
| **Timeout** | Query timeout | Orange clock icon + "Refresh Claims & Retry" button |
| **Permission Denied** | Missing claims | Error icon + "Retry" button |
| **No Role** | User has no role claim | Router shows "No Role Assigned" screen with "Refresh Claims" button |

**To test "No Role" screen**:
1. Clear custom claims for test user (using Firebase Console or script)
2. Log in again
3. Should see "No Role Assigned" screen with "Refresh Claims" button
4. Click button → should force token refresh and retry

---

## 📊 Success Criteria

✅ **All must pass**:

1. ✅ Custom claims verified (role + companyId set)
2. ✅ Console shows `🔄 Forcing ID token refresh` on first load (if cached token had no claims)
3. ✅ Console shows `✅ Claims loaded: {role: "admin", ...}`
4. ✅ Admin dashboard loads without infinite spinners
5. ✅ Summary stats card shows counts (not spinner forever)
6. ✅ Entry list shows data or "All caught up!" (not spinner forever)
7. ✅ Manual Firestore query succeeds in console
8. ✅ No `permission-denied` errors in console
9. ✅ No App Check 400/403 errors
10. ✅ Timeout error UI shows "Refresh Claims & Retry" button when timeout occurs

---

## 🚨 Troubleshooting

### Issue: "No Role Assigned" screen shows

**Cause**: User doesn't have `role` claim in token

**Fix**:
1. Run: `node fix_admin_claims.cjs`
2. Log out and log back in
3. **OR** click "Refresh Claims" button on screen

---

### Issue: Query returns `permission-denied`

**Cause**: User doesn't have `companyId` claim in token

**Check claims**:
```javascript
firebase.auth().currentUser.getIdTokenResult().then(r => {
  console.log('role:', r.claims.role);
  console.log('companyId:', r.claims.companyId);
});
```

**Fix**:
1. Run: `node fix_admin_claims.cjs`
2. Log out and log back in
3. **OR** click "Refresh Claims & Retry" button in error UI

---

### Issue: Dashboard still shows loading spinners

**Possible causes**:
1. Claims not refreshed in browser (cached token)
2. No data in `time_entries` collection
3. Firestore index still building

**Debug steps**:

**Step 1**: Check if token has claims
```javascript
firebase.auth().currentUser.getIdTokenResult().then(r => {
  console.log('Claims:', r.claims);
  if (!r.claims.role || !r.claims.companyId) {
    console.error('❌ Claims missing! Run fix_admin_claims.cjs and log out/in');
  }
});
```

**Step 2**: Check if data exists
```bash
firebase firestore:get time_entries --project sierra-painting-staging --limit 5
```

**Step 3**: Check Firestore Console for index status
- Go to: https://console.firebase.google.com/project/sierra-painting-staging/firestore/indexes
- Ensure index for `companyId + status + clockInAt` shows "Enabled"

**Step 4**: Enable Firestore debug logging
```javascript
firebase.firestore.setLogLevel('debug');
```
Then refresh and check console for query errors.

---

### Issue: App Check errors (400/403)

**This should NOT happen** since we removed the debug token and App Check should use ReCAPTCHA v3.

**If you see App Check errors**:
1. Check web/index.html is deployed (no debug token)
2. Check Firebase Console → App Check → Web app is registered
3. Check ReCAPTCHA v3 is enabled for the domain

---

## 🎯 Final Validation

**Run all 5 tests above**. Copy/paste results into PR comment.

**Format**:
```markdown
## Verification Results

### Test 1: Claims Force-Refresh
✅ PASS - Console shows token refresh and claims loaded

### Test 2: Admin Queries Succeed
✅ PASS - Query returned 3 documents

### Test 3: Timeout Error Handling
✅ PASS - Timeout UI showed "Refresh Claims & Retry" button

### Test 4: Firestore Rules Enforcement
✅ PASS - Read permission granted with valid claim

### Test 5: UI States
✅ PASS - All states render correctly, no infinite spinners

### Screenshots
[Attach screenshots of console, admin dashboard, error UI]
```

---

## 🔧 Additional Debug Scripts

### Force Sign Out and Re-Auth (Console)

```javascript
const email = firebase.auth().currentUser.email;
const password = prompt('Enter password to refresh session:');

firebase.auth().signOut().then(() => {
  console.log('✅ Signed out');
  return firebase.auth().signInWithEmailAndPassword(email, password);
}).then(() => {
  console.log('✅ Signed back in - token refreshed');
  window.location.reload();
});
```

### Check Function Logs (CLI)

```bash
firebase functions:log --project sierra-painting-staging --limit 50 | grep -Ei "error|app-check|took"
```

---

## 📝 Notes

- **Claims must be set server-side** using `fix_admin_claims.cjs` or `setUserRole` Cloud Function
- **Token refresh happens automatically** on first load if claims are missing (via `userClaimsProvider`)
- **Timeout is 8 seconds** for all admin queries - if network is slow, error UI will show
- **No debug token in production** - App Check uses ReCAPTCHA v3
- **Firestore rules strictly enforce `companyId`** - no admin bypass

---

## 🚀 Deployment Summary

**Deployed to**: https://sierra-painting-staging.web.app
**Firestore Rules**: Deployed (bypass removed)
**Hosting**: Deployed (debug token removed)
**Custom Claims**: Set for admin and worker users

**Next Steps**:
1. Run verification tests above
2. Copy results to PR comment
3. If all pass, merge to main
4. Deploy to production

**Rollback if needed**:
```bash
git checkout main
firebase deploy --only hosting,firestore:rules --project sierra-painting-staging
```
