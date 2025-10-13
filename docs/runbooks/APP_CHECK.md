# App Check Troubleshooting Runbook

**Project:** Sierra Painting Staging
**Last Updated:** 2025-10-12
**Owner:** Security Team

---

## Quick Diagnostics

```bash
# Check if App Check is enabled
grep "ENABLE_APP_CHECK" assets/config/public.env

# Test App Check enforcement
curl -X POST https://us-east4-sierra-painting-staging.cloudfunctions.net/clockIn
# Expected: 403 Forbidden (if App Check enabled)
# Expected: 401 Unauthorized (if App Check bypassed but no auth)
```

---

## Scenario 1: Web App - 403 Forbidden Errors

**Symptoms:**
- Users cannot login
- All Firebase operations return 403
- Browser console shows "App Check token rejected"

**Diagnosis:**

1. **Check ReCAPTCHA v3 configuration:**
```bash
# Verify site key is set
grep "RECAPTCHA_V3_SITE_KEY" assets/config/public.env

# Expected: RECAPTCHA_V3_SITE_KEY=6Lf...
```

2. **Check browser console:**
```
F12 → Console Tab
Look for:
✅ "App Check: activation succeeded"
❌ "App Check: activation failed"
❌ "reCAPTCHA site key not found"
```

**Fix A: Missing or Invalid Site Key**

```bash
# Get current site key from Google reCAPTCHA Admin
# https://www.google.com/recaptcha/admin

# Update public.env
echo "RECAPTCHA_V3_SITE_KEY=<your-site-key>" >> assets/config/public.env

# Rebuild and redeploy
flutter build web --release
firebase deploy --only hosting --project sierra-painting-staging
```

**Fix B: Enable Debug Token (Local Development)**

1. Open `web/index.html`, add before Firebase init:
```html
<script>
  // Enable App Check debug mode
  self.FIREBASE_APPCHECK_DEBUG_TOKEN = true;
</script>
```

2. Open browser console, copy debug token:
```
App Check debug token: "ABC123-DEF456-GHI789..."
```

3. Register token in Firebase Console:
```
Firebase Console → App Check → Manage debug tokens → Add debug token
Paste token, set name: "Valle Local Dev"
```

4. Refresh browser - App Check should work

**Expected Time:** 5-10 minutes

---

## Scenario 2: Mobile App - App Check Failures

**Symptoms:**
- Android/iOS app shows "Connection failed"
- Logs show "App Check token missing or invalid"

**Diagnosis:**

1. **Check App Check configuration:**
```bash
# Android: Check SHA-1 fingerprint registered
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# iOS: Check bundle ID matches Firebase Console
```

2. **Verify platform provider:**
```dart
// lib/main.dart
// Ensure correct provider for platform:
androidProvider: kReleaseMode
    ? AndroidProvider.playIntegrity
    : AndroidProvider.debug,
```

**Fix A: Register Debug Token (Development Builds)**

```bash
# Android: Logcat output shows debug token
adb logcat | grep "App Check debug token"

# iOS: Xcode console shows debug token
# Register in Firebase Console (same as web)
```

**Fix B: Configure Play Integrity (Production Android)**

1. Firebase Console → App Check → Apps → Android
2. Click "Play Integrity" → Enable
3. Add SHA-256 fingerprint from Play Console
4. Rebuild and test

**Expected Time:** 15-30 minutes

---

## Scenario 3: Functions - App Check Bypass Not Working

**Symptoms:**
- Cloud Functions returning 403 even with valid token
- Local emulator can't bypass App Check

**Diagnosis:**

```bash
# Check function enforcement
grep -r "enforceAppCheck" functions/src/

# Check if function has appCheck config
```

**Fix A: Disable Enforcement (Staging Only)**

```typescript
// functions/src/index.ts
export const myFunction = onCall(
  {
    // STAGING: Allow unenforced App Check
    enforceAppCheck: false,  // <-- Add this
  },
  async (request) => {
    // ...
  }
);
```

**Fix B: Use Emulator Bypass**

```bash
# Start emulator with App Check disabled
export FIRESTORE_EMULATOR_HOST=localhost:8080
export FIREBASE_AUTH_EMULATOR_HOST=localhost:9099
firebase emulators:start
```

**Expected Time:** 5 minutes

---

## Scenario 4: Token Quota Exhausted

**Symptoms:**
- Intermittent 403 errors
- Errors only affect high-traffic users
- Firebase Console shows quota warnings

**Diagnosis:**

```bash
# Check App Check usage
# Firebase Console → App Check → Usage tab
# Look for "Quota exceeded" warning
```

**Fix: Increase Quota or Optimize Token Usage**

1. **Short-term:** Increase quota in Firebase Console
2. **Long-term:** Optimize token refresh rate:
```dart
// Reduce token refresh frequency
await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(false);
// Manually refresh only when needed
await FirebaseAppCheck.instance.getToken(forceRefresh: true);
```

**Expected Time:** 2-5 minutes

---

## Scenario 5: ReCAPTCHA Score Too Low

**Symptoms:**
- Some users get 403 errors
- ReCAPTCHA console shows low scores (<0.5)
- More common on VPN/proxy users

**Diagnosis:**

```bash
# Check ReCAPTCHA Admin Console
# https://www.google.com/recaptcha/admin
# View analytics → Check score distribution
```

**Fix: Adjust Score Threshold**

```dart
// lib/main.dart
await FirebaseAppCheck.instance.activate(
  providerWeb: ReCaptchaV3Provider(
    v3Key,
    // Lower threshold for staging (default: 0.5)
    threshold: 0.3,  // <-- Add this
  ),
);
```

**Expected Time:** 5-10 minutes

---

## Emergency: Disable App Check Entirely

**⚠️ LAST RESORT - Security risk!**

**When to Use:**
- App Check blocking all users
- No time to debug (P0 incident)
- Temporary measure while fixing

**Steps:**

1. **Disable in environment config:**
```bash
# Edit assets/config/public.env
ENABLE_APP_CHECK=false
```

2. **Rebuild and redeploy:**
```bash
flutter build web --release
firebase deploy --only hosting --project sierra-painting-staging
```

3. **Disable enforcement in functions:**
```typescript
// functions/src/index.ts
export const clockIn = onCall(
  { enforceAppCheck: false },
  async (request) => { ... }
);
```

4. **Redeploy functions:**
```bash
npm --prefix functions run build
firebase deploy --only functions --project sierra-painting-staging
```

**Expected Time:** 15-20 minutes
**Follow-up:** Re-enable within 24 hours after fix identified

---

## Verification Commands

**Test Web App Check:**
```bash
# Should return 403 if App Check enabled and no token
curl -X POST https://us-east4-sierra-painting-staging.cloudfunctions.net/clockIn

# Test with valid token (from browser)
# Open DevTools → Network → Find request with X-Firebase-AppCheck header
curl -X POST https://us-east4-sierra-painting-staging.cloudfunctions.net/clockIn \
  -H "X-Firebase-AppCheck: <token-from-browser>"
```

**Test Mobile App Check:**
```bash
# Android: Check logs
adb logcat | grep -i "appcheck"

# iOS: Check Xcode console
# Look for "App Check token obtained"
```

---

## Common Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| `403 Forbidden` | App Check token invalid/missing | Register debug token or fix config |
| `APPCHECK_TOKEN_REJECTED` | Token expired or revoked | Refresh token, check quota |
| `reCAPTCHA site key not found` | Missing RECAPTCHA_V3_SITE_KEY | Add to public.env |
| `App Check: activation failed` | Network issue or invalid config | Check browser console for details |
| `PERMISSION_DENIED` | Firestore rules + App Check both failing | Fix rules first, then App Check |

---

## Configuration Checklist

- [ ] `ENABLE_APP_CHECK=true` in assets/config/public.env
- [ ] `RECAPTCHA_V3_SITE_KEY` set (web)
- [ ] reCAPTCHA site registered at https://www.google.com/recaptcha/admin
- [ ] Firebase Console → App Check → All apps enabled
- [ ] Debug tokens registered for dev devices
- [ ] Play Integrity enabled (Android production)
- [ ] App Attest enabled (iOS production)

---

## References

- [Firebase App Check Docs](https://firebase.google.com/docs/app-check)
- [ReCAPTCHA Admin Console](https://www.google.com/recaptcha/admin)
- [App Check Debug Tokens Guide](https://firebase.google.com/docs/app-check/flutter/debug-provider)

---

**Last Tested:** 2025-10-12 (staging environment)
**Next Review:** 2025-11-12
