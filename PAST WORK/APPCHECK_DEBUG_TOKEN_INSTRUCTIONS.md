# App Check Debug Token Setup (URGENT)

## Issue
Admin dashboard loading but data stuck - App Check blocking all Firestore requests with 400 errors.

## Immediate Fix (2 minutes)

### Step 1: Get Debug Token from Console

Open browser console on staging app (https://sierra-painting-staging.web.app) and run:

```javascript
// In browser console (F12 → Console tab)
localStorage.getItem('debug-token')
```

If null, generate one:

```javascript
// Generate debug token
const token = crypto.randomUUID();
localStorage.setItem('debug-token', token);
console.log('Debug Token:', token);
// Copy this token
```

### Step 2: Register in Firebase Console

1. Go to: https://console.firebase.google.com/project/sierra-painting-staging/appcheck/apps
2. Click on your web app
3. Click "Manage debug tokens"
4. Click "Add debug token"
5. Paste the token from Step 1
6. Give it a name: "Admin Testing - Oct 2025"
7. Click "Save"

### Step 3: Refresh Browser

Hard refresh the staging app (Ctrl+Shift+R or Cmd+Shift+R)

App should now load data properly.

---

## Alternative: Temporary Disable App Check (If Above Fails)

**WARNING**: Only use for testing, re-enable immediately after

### Disable Enforcement:

```bash
# In project root
flutter build web --release --dart-define=ENABLE_APP_CHECK=false
firebase deploy --only hosting --project sierra-painting-staging
```

### Re-enable After Testing:

```bash
flutter build web --release --dart-define=ENABLE_APP_CHECK=true
firebase deploy --only hosting --project sierra-painting-staging
```

---

## Verification

After registering debug token, check browser console for:

✅ **Success**: "App Check: activated on web (v3 site key detected)"
✅ **No errors**: No "AppCheck: 400 error" messages
✅ **Data loads**: Admin dashboard shows stats and entries

---

## Why This Happened

App Check is enabled in staging (ENABLE_APP_CHECK=true) but no debug token was registered for web testing.

**ReCAPTCHA v3** works in production with real users, but development/testing requires debug tokens.

---

## For Future Reference

**Debug Token Locations**:
- Web: Firebase Console → App Check → Web app → Manage debug tokens
- Android: Use debug.keystore SHA-256 fingerprint
- iOS: Use simulator device ID

**Token Expiry**: Debug tokens don't expire but can be revoked

---

**Execute Step 1-3 now to unblock the admin dashboard.** ⚡
