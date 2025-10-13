# App Check Debug Provider Test

**Date**: 2025-10-13
**Purpose**: Isolate whether App Check 400 errors are caused by reCAPTCHA integration or broader backend issues
**Deployed to**: https://sierra-painting-staging.web.app

---

## What Was Changed

### 1. Enabled Debug Mode in `web/index.html`
Added before Firebase scripts:
```html
<script>
  self.FIREBASE_APPCHECK_DEBUG_TOKEN = true;
</script>
```

### 2. Updated `lib/main.dart` Comments
Added explanation that debug mode in index.html will override reCAPTCHA provider during testing.

---

## How Debug Mode Works

When `self.FIREBASE_APPCHECK_DEBUG_TOKEN = true` is set in HTML:
- Firebase SDK detects the flag on page load
- Prints a debug token to browser console (looks like: `ABC123-DEF456-...`)
- After you register that token in Firebase Console, SDK uses debug provider instead of reCAPTCHA
- This lets us test if App Check backend works independent of reCAPTCHA

**If debug provider works**: Problem is reCAPTCHA integration
**If debug provider fails**: Problem is App Check backend

---

## Steps to Test

### Step 1: Load Page and Get Debug Token

1. Open in **incognito mode**: https://sierra-painting-staging.web.app
2. Open browser console (F12)
3. Look for this message:
   ```
   Firebase App Check debug token: ABC123-DEF456-GHI789-...
   ```
4. **Copy the entire token** (it's long, usually 40+ characters)

**Troubleshooting**:
- If you don't see the token, refresh the page
- Token appears BEFORE any other Firebase logs
- Should appear within 1-2 seconds of page load

---

### Step 2: Register Debug Token in Firebase Console

1. Go to: https://console.firebase.google.com/project/sierra-painting-staging/appcheck
2. Click **"Apps"** tab (top of page)
3. Scroll down to **"Debug tokens"** section
4. Click **"Manage debug tokens"**
5. Click **"Add debug token"**
6. Paste the token you copied
7. Give it a name: `Debug Test - 2025-10-13`
8. Click **"Add"**
9. Status should show: ✅ **"Active"**

**Troubleshooting**:
- If "Add debug token" is grayed out, check you have Editor/Owner role
- Token must be exact match (no spaces, no line breaks)
- Token expires after 7 days

---

### Step 3: Test Admin Dashboard

1. **Refresh the page**: https://sierra-painting-staging.web.app
2. Log in with admin credentials
3. Open browser console (F12)
4. Watch for these log messages:

**Expected if debug provider works**:
```
✅ App Check: activation succeeded (debug mode enabled in index.html).
✅ Claims loaded: {role: "admin", companyId: "test-company-staging", ...}
```

**NO MORE 400 errors**:
```
❌ AppCheck: 400 error. Attempts allowed again after 00m:01s  <-- Should NOT appear
```

5. Navigate to `/dashboard`
6. Admin dashboard should load **without infinite spinners**
7. Summary stats should show counts
8. Entry list should show data or "All caught up!"

---

### Step 4: Verify Firestore Queries Work

Open browser console and run:

```javascript
// Check current App Check token
firebase.appCheck().getToken().then(result => {
  console.log('✅ App Check token obtained:', result.token.substring(0, 20) + '...');
}).catch(error => {
  console.error('❌ App Check token failed:', error);
});

// Test Firestore query
firebase.firestore().collection('time_entries')
  .where('companyId', '==', 'test-company-staging')
  .where('status', '==', 'pending')
  .limit(3)
  .get()
  .then(snapshot => {
    console.log('✅ Firestore query succeeded! Found', snapshot.size, 'documents');
    snapshot.forEach(doc => console.log('  -', doc.id));
  })
  .catch(error => {
    console.error('❌ Firestore query failed:', error.code, error.message);
  });
```

**Expected output**:
```
✅ App Check token obtained: eyJhbGciOiJSUzI1NiIs...
✅ Firestore query succeeded! Found 3 documents
  - entry-id-1
  - entry-id-2
  - entry-id-3
```

---

## Test Results

### ✅ SUCCESS: Debug Provider Works

**Means**:
- App Check backend is functioning correctly
- Problem is with reCAPTCHA integration specifically
- ReCAPTCHA site key configuration, registration, or domain validation is broken

**Next Steps**:
1. Unregister web app from Firebase App Check console
2. Re-register with reCAPTCHA provider using the site key: `6LfQP-grAAAAAFYtAnq8KjyBJy9Z7z1Q3aryE8eO`
3. Verify reCAPTCHA console shows correct domains
4. Wait 5-10 minutes for propagation
5. Remove debug token flag from `web/index.html`
6. Rebuild and redeploy
7. Test again - should work

**Alternative Fix**: Create NEW reCAPTCHA site key in different Google account and re-register

---

### ❌ FAILURE: Debug Provider Also Fails

**Means**:
- Problem is NOT reCAPTCHA-specific
- App Check backend has broader issue
- Could be:
  - Firebase project misconfiguration
  - App Check service outage
  - Region/endpoint routing problem
  - IAM permissions issue

**Next Steps**:
1. Submit escalation document `APPCHECK_400_ERROR_ESCALATION.md` to Firebase support
2. Include screenshot of debug token registration
3. Include console logs showing 400 errors even with debug provider
4. Request Firebase engineering team investigation
5. Consider temporary workaround: Disable App Check in staging (`ENABLE_APP_CHECK=false`)

---

## Console Commands for Debugging

### Check App Check Token Status
```javascript
firebase.appCheck().getToken(true).then(r => {
  console.log('Token obtained:', r.token.substring(0, 30) + '...');
}).catch(e => {
  console.error('Token failed:', e.code, e.message);
});
```

### Check Current User Claims
```javascript
firebase.auth().currentUser.getIdTokenResult().then(r => {
  console.log('User claims:', r.claims);
  console.log('  role:', r.claims.role);
  console.log('  companyId:', r.claims.companyId);
});
```

### Enable Firestore Debug Logging
```javascript
firebase.firestore.setLogLevel('debug');
```

---

## Rollback Instructions

If test fails and you need to revert to production config:

```bash
# Revert index.html changes
git checkout web/index.html

# Revert main.dart changes
git checkout lib/main.dart

# Rebuild and redeploy
flutter build web --release --dart-define=ENABLE_APP_CHECK=true
firebase deploy --only hosting --project sierra-painting-staging
```

---

## Timeline

| Time | Action | Result |
|------|--------|--------|
| 10:XX | Enabled debug mode in code | ✅ Committed |
| 10:XX | Built web app | ✅ Succeeded |
| 10:XX | Deployed to staging | ✅ Live at sierra-painting-staging.web.app |
| NEXT | Register debug token | ⏳ Awaiting user action |
| NEXT | Test admin dashboard | ⏳ Awaiting results |

---

## Critical Success Factors

For this test to be conclusive:

1. ✅ Debug mode enabled in index.html (`self.FIREBASE_APPCHECK_DEBUG_TOKEN = true`)
2. ✅ Code deployed to staging
3. ⏳ Debug token copied from console
4. ⏳ Debug token registered in Firebase Console
5. ⏳ Page refreshed after registration
6. ⏳ Console checked for 400 errors
7. ⏳ Admin dashboard tested

---

## Support Resources

- **Firebase App Check docs**: https://firebase.google.com/docs/app-check/web/debug-provider
- **Firebase Console (App Check)**: https://console.firebase.google.com/project/sierra-painting-staging/appcheck
- **Escalation document**: `APPCHECK_400_ERROR_ESCALATION.md`
- **Admin dashboard**: https://sierra-painting-staging.web.app/dashboard

---

**Next action**: Follow Steps 1-4 above to complete the test and determine root cause.
