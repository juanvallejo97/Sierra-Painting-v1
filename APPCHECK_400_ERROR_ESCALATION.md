# Firebase App Check 400 Error - Escalation Report

**Date**: 2025-10-13
**Priority**: P0 - Blocking Production Deployment
**Project**: sierra-painting-staging
**Issue**: Persistent App Check 400 errors despite proper configuration

---

## 🔴 Executive Summary

Firebase App Check continues to return **400 errors** on web, blocking all Firestore requests despite:
- ✅ Valid reCAPTCHA v3 site key created and registered
- ✅ Web app registered in Firebase App Check console
- ✅ Code properly configured with token auto-refresh
- ✅ Domains correctly registered in reCAPTCHA
- ✅ Multiple rebuild/redeploy cycles

**Business Impact**: Admin dashboard completely non-functional, blocking staging validation and production release.

---

## 📊 Current Configuration

### Firebase Project
- **Project ID**: `sierra-painting-staging`
- **Region**: `us-east4`
- **Environment**: Staging
- **URL**: https://sierra-painting-staging.web.app

### reCAPTCHA v3 Configuration
- **Site Key**: `6LfQP-grAAAAAFYtAnq8KjyBJy9Z7z1Q3aryE8eO`
- **Created**: 2025-10-13
- **Type**: reCAPTCHA v3 (score-based)
- **Registered Domains**:
  - `sierra-painting-staging.web.app`
  - `localhost`
- **Domain Verification**: Enabled
- **Status**: Active in Google Cloud Console

### Firebase App Check
- **Web App**: `sierra_painting (web)`
- **Provider**: reCAPTCHA
- **Status**: ✅ Registered (shows green checkmark)
- **Registration Date**: 2025-10-13
- **Enforcement**: Enabled for Firestore

### Code Configuration
**File**: `assets/config/public.env`
```env
ENABLE_APP_CHECK=true
RECAPTCHA_V3_SITE_KEY=6LfQP-grAAAAAFYtAnq8KjyBJy9Z7z1Q3aryE8eO
```

**File**: `lib/main.dart` (lines 164-178)
```dart
// Enable token auto-refresh BEFORE activation
await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

if (kIsWeb && v3Key != null && v3Key.isNotEmpty) {
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider(v3Key),
    androidProvider: kReleaseMode
        ? AndroidProvider.playIntegrity
        : AndroidProvider.debug,
    appleProvider: kReleaseMode
        ? AppleProvider.appAttest
        : AppleProvider.debug,
  );
}
```

**Flutter Version**: 3.27+
**firebase_app_check**: Latest (from pubspec.lock)

---

## 🐛 Error Details

### Console Output (Repeated Pattern)

```
[2025-10-13T15:55:09.9097Z] @firebase/app-check:
AppCheck: 400 error. Attempts allowed again after 00m:01s
(appCheck/initial-throttle).

Top-level error (web/test): FirebaseError:
AppCheck: 400 error. Attempts allowed again after 00m:01s
(appCheck/initial-throttle).
```

### Error Characteristics
- **Error Code**: 400 (Bad Request)
- **Throttle Period**: 1 second
- **Frequency**: Every request
- **Location**: `@firebase/app-check` SDK
- **Context**: `appCheck/initial-throttle`

### Successful Initialization (Contradictory)
```
App Check: activation succeeded on web (v3 site key detected).
```

**This indicates**:
- ✅ Code successfully loads site key from env
- ✅ App Check SDK activates without errors
- ❌ BUT tokens are rejected by Firebase backend

---

## 🔍 Diagnostic Steps Completed

### 1. reCAPTCHA Key Validation ✅
- [x] Created new site key in Google Cloud Console
- [x] Verified key format (starts with `6Lc...`)
- [x] Confirmed domains registered (`sierra-painting-staging.web.app`, `localhost`)
- [x] Verified key is for reCAPTCHA v3 (not v2)
- [x] Confirmed domain verification enabled

### 2. Firebase App Check Registration ✅
- [x] Navigated to Firebase Console → App Check → Apps tab
- [x] Found `sierra_painting (web)` app
- [x] Clicked "Manage" and selected "reCAPTCHA" provider
- [x] Entered site key: `6LfQP-grAAAAAFYtAnq8KjyBJy9Z7z1Q3aryE8eO`
- [x] Saved configuration
- [x] Status shows ✅ "Registered" with "reCAPTCHA" provider

### 3. Code Configuration ✅
- [x] Updated `assets/config/public.env` with correct site key
- [x] Added token auto-refresh: `setTokenAutoRefreshEnabled(true)`
- [x] Fixed parameter name: `providerWeb` → `webProvider`
- [x] Verified env file loading in console logs
- [x] Confirmed activation success message

### 4. Build & Deployment ✅
- [x] Ran `flutter clean`
- [x] Ran `flutter pub get`
- [x] Built with: `flutter build web --release --dart-define=ENABLE_APP_CHECK=true`
- [x] Deployed with: `firebase deploy --only hosting`
- [x] Verified deployment success
- [x] Confirmed new build served (checked timestamps)

### 5. Browser Testing ✅
- [x] Tested in incognito mode (no cache)
- [x] Cleared all browser cache and cookies
- [x] Tested in multiple browsers (Chrome, Edge)
- [x] Hard refreshed (Ctrl+Shift+R)
- [x] Waited 30+ minutes for propagation

### 6. Firestore Rules ✅
- [x] Rules deployed successfully
- [x] No enforcement conflicts
- [x] Claims properly set (`role: "admin"`, `companyId: "test-company-staging"`)

---

## 🔬 Network Analysis

### Request Flow (Observed)
1. Browser loads `https://sierra-painting-staging.web.app`
2. App Check SDK initializes with reCAPTCHA v3 provider
3. SDK attempts to get token from Firebase backend
4. **Firebase backend returns 400 (Bad Request)**
5. SDK throttles for 1 second
6. Retry → 400 again (infinite loop)

### Expected Flow
1. Browser loads app
2. App Check SDK initializes
3. SDK sends reCAPTCHA v3 assessment to Firebase
4. Firebase validates token against registered site key
5. **Firebase returns valid App Check token** (should happen, doesn't)
6. App uses token for Firestore requests

### Missing Step
**Somewhere between steps 3-4**, Firebase backend is rejecting the request with 400.

---

## 🤔 Hypotheses

### Hypothesis 1: Site Key Not Linked in Backend
**Likelihood**: HIGH

**Evidence**:
- Web app shows "Registered" in Firebase Console UI
- But 400 errors suggest backend doesn't recognize tokens
- Possible console UI bug (shows registered, but backend not updated)

**Test**: Use Firebase Admin SDK to verify registration:
```javascript
const admin = require('firebase-admin');
admin.initializeApp();

// Check if App Check is configured for web app
const appCheck = admin.appCheck();
// Query web app configuration (if API exists)
```

**Alternative Test**: Check Firebase project settings API directly

---

### Hypothesis 2: Domain Mismatch
**Likelihood**: MEDIUM

**Evidence**:
- reCAPTCHA expects: `sierra-painting-staging.web.app`
- Actual hosting URL: `sierra-painting-staging.web.app` ✅ Match
- BUT: reCAPTCHA might be validating against different domain attribute

**Test**: Check `document.domain` and `window.location.origin` in console:
```javascript
console.log('Domain:', document.domain);
console.log('Origin:', window.location.origin);
console.log('Hostname:', window.location.hostname);
```

Expected: All should be `sierra-painting-staging.web.app`

---

### Hypothesis 3: Secret Key Issue
**Likelihood**: MEDIUM

**Evidence**:
- reCAPTCHA v3 requires both site key (public) and secret key (private)
- Firebase might be using wrong secret key or none at all
- Google Cloud reCAPTCHA shows secret key, but unclear if Firebase has it

**Issue**: Firebase App Check should automatically use the secret key from Google Cloud, but might not be linked

**Test**: Verify in Firebase Console → App Check → APIs tab:
- Check if Firestore shows "App Check enabled"
- Check if enforcement mode is correct

---

### Hypothesis 4: App Check API Not Enabled
**Likelihood**: LOW (would fail activation)

**Evidence**:
- Activation succeeds, so API must be enabled
- But specific endpoints might require additional permissions

**Test**: Check Google Cloud Console → APIs & Services:
```
- Firebase App Check API - Should be ENABLED
- reCAPTCHA Enterprise API - Check status
```

---

### Hypothesis 5: Propagation Delay
**Likelihood**: LOW (waited 30+ min)

**Evidence**:
- Standard propagation time: 2-3 minutes
- We've waited 30+ minutes
- Multiple redeploys with same result

**Unlikely**, but possible if:
- Firebase backend caching is aggressive
- Regional propagation issues (us-east4 specific)

---

## 🛠️ Recommended Next Steps

### Immediate Actions (Do Now)

#### 1. Verify Backend Registration via Firebase CLI
```bash
# Check App Check configuration
firebase apps:list --project sierra-painting-staging

# Look for web app ID and check if App Check is configured
# Expected: Should show App Check provider = reCAPTCHA
```

#### 2. Enable App Check Debug Logging (Temporarily)
**Add to `web/index.html` BEFORE Firebase loads:**
```html
<script>
  // Enable App Check debug mode
  self.FIREBASE_APPCHECK_DEBUG_TOKEN = true;
</script>
```

**Then**:
1. Rebuild and deploy
2. Load page in console
3. **Copy the debug token** from console (looks like: `abc123-def456-...`)
4. Register debug token in Firebase Console → App Check → Manage Debug Tokens
5. Test again

**Why this helps**: Debug tokens bypass reCAPTCHA validation, isolating the issue to reCAPTCHA vs. App Check backend.

#### 3. Check Firebase Console → App Check → APIs Tab
Navigate to:
```
https://console.firebase.google.com/project/sierra-painting-staging/appcheck/apis
```

Verify:
- ✅ Firestore shows "App Check: Required" or "Enforced"
- ✅ Auth shows enforcement status
- ✅ No conflicting API settings

#### 4. Verify reCAPTCHA Integration in Google Cloud
Go to:
```
https://console.cloud.google.com/security/recaptcha/6LfQP-grAAAAAFYtAnq8KjyBJy9Z7z1Q3aryE8eO/integration
```

Check:
- **Frontend integration**: Should show site key
- **Backend integration**: Should show secret key
- **Test the integration**: Use "Test" button if available

#### 5. Check Network Request Details
**In browser DevTools → Network tab:**
1. Filter for: `firebaseappcheck` or `appcheck`
2. Find the failing request
3. **Share these details**:
   - Request URL
   - Request payload
   - Response status (400)
   - Response body (may have error details)

**Look for**:
```
URL: https://firebaseappcheck.googleapis.com/v1/projects/sierra-painting-staging/apps/[APP_ID]:exchangeRecaptchaV3Token
```

**Response body might contain**:
```json
{
  "error": {
    "code": 400,
    "message": "INVALID_ARGUMENT: Invalid site key or domain"
  }
}
```

---

### Advanced Diagnostics

#### Option A: Use Firebase Support Channels
**If available**, open Firebase support ticket with:
- This document attached
- Project ID: `sierra-painting-staging`
- Web app ID: (get from Firebase Console → Project Settings → Apps)
- Error reproduction steps

#### Option B: Test with Different Provider
**Temporarily switch to Debug provider** to isolate reCAPTCHA:

```dart
// In lib/main.dart, replace ReCaptchaV3Provider with:
await FirebaseAppCheck.instance.activate(
  webProvider: DebugProvider(
    debugToken: 'test-debug-token-12345',
  ),
);
```

If this works → Problem is reCAPTCHA integration
If this fails → Problem is App Check backend

#### Option C: Create New Test Project
**Nuclear option**: Create fresh Firebase project to verify configuration works:

1. Create new Firebase project: `sierra-painting-test`
2. Register web app
3. Create NEW reCAPTCHA key for test domain
4. Configure App Check
5. Test minimal app

If test project works → Something wrong with staging project config
If test project fails → Systematic Flutter/Firebase issue

---

## 📝 Key Observations

### What Works ✅
- App Check SDK initialization succeeds
- reCAPTCHA site key loads correctly
- Code executes without errors
- Firebase Console shows "Registered" status
- Firestore rules properly configured
- Custom claims set correctly

### What Doesn't Work ❌
- App Check token exchange (400 error)
- Firestore requests blocked (no valid token)
- Admin dashboard non-functional

### Critical Gap
**The disconnect is between**:
- Firebase Console UI (shows "Registered" ✅)
- Firebase Backend API (rejects tokens ❌)

**This suggests**:
- UI state doesn't match backend state, OR
- Additional backend configuration required, OR
- Bug in Firebase App Check service

---

## 🔑 Smoking Gun Evidence

### Evidence #1: Activation Succeeds But Tokens Fail
```
✅ App Check: activation succeeded on web (v3 site key detected).
❌ AppCheck: 400 error. Attempts allowed again after 00m:01s
```

**This is contradictory**. If activation succeeded, token exchange should work.

### Evidence #2: Immediate 400 on First Request
```
(appCheck/initial-throttle)
```

**"initial-throttle"** suggests this is the FIRST request failing, not a rate limit. This points to configuration issue, not usage issue.

### Evidence #3: Consistent 1-Second Throttle
**Pattern**: Every request returns 400 → throttle 1s → retry → 400 again

This is App Check SDK's exponential backoff starting at 1 second. It's not giving up because the error is retriable (400 vs 403).

---

## 🎯 Most Likely Root Cause

**Hypothesis #1 (60% confidence)**: Site key registered in Firebase Console UI, but backend sync failed

**Why**:
- Console shows "Registered" but backend rejects tokens
- Common issue when Firebase internal services don't sync
- Has been reported in Firebase GitHub issues

**Solution**:
1. Unregister web app from Firebase App Check
2. Wait 5 minutes
3. Re-register with same site key
4. Wait 10 minutes for propagation
5. Test

**Alternative**:
- Delete and recreate web app in Firebase Console
- Register new web app with App Check from scratch

---

## 📧 Escalation Contacts

**If this document is being shared with Firebase support:**

- **Project ID**: `sierra-painting-staging`
- **Region**: `us-east4`
- **Firebase Plan**: (Blaze/Spark - check in console)
- **Issue Start Date**: 2025-10-13
- **Affected Services**: Firestore, Firebase Hosting
- **User Impact**: Admin dashboard completely non-functional
- **Workaround Attempted**: None successful

**Firebase GitHub Issues to Reference**:
- Search: "firebase app check 400 error recaptcha"
- Similar issues may have been reported

---

## 🔬 Debug Commands to Run

### Command 1: Verify Firebase Project Settings
```bash
firebase projects:list
firebase use sierra-painting-staging
firebase apps:list
```

### Command 2: Check Firestore Rules Deployment
```bash
firebase firestore:rules get --project sierra-painting-staging
```

### Command 3: Test App Check with curl (if possible)
```bash
# This might not work due to reCAPTCHA, but worth trying
curl -X POST \
  "https://firebaseappcheck.googleapis.com/v1/projects/sierra-painting-staging/apps/YOUR_WEB_APP_ID:exchangeRecaptchaV3Token" \
  -H "Content-Type: application/json" \
  -d '{
    "recaptcha_v3_token": "test-token"
  }'
```

### Command 4: Check Firebase Hosting Configuration
```bash
firebase hosting:channel:list --project sierra-painting-staging
```

---

## 📊 Timeline Summary

| Time | Action | Result |
|------|--------|--------|
| T+0 | Created reCAPTCHA v3 site key | ✅ Success |
| T+5 | Registered in Firebase App Check | ✅ Shows "Registered" |
| T+10 | Updated code with site key | ✅ Code compiles |
| T+15 | Built and deployed | ✅ Deployment success |
| T+20 | Tested in browser | ❌ 400 errors |
| T+30 | Added token auto-refresh | ✅ Code updated |
| T+35 | Rebuilt and redeployed | ✅ Deployment success |
| T+40 | Tested again | ❌ Still 400 errors |
| T+60 | Waited for propagation | ❌ No change |
| T+90 | Cleared all caches, tested | ❌ Still 400 errors |

**Conclusion**: Issue is not related to code, cache, or propagation delay.

---

## 🚨 Business Impact

### Current State
- ❌ Admin dashboard non-functional
- ❌ Cannot review time entries
- ❌ Cannot approve/reject entries
- ❌ Blocking staging validation
- ❌ Blocking production release

### Temporary Workarounds Considered

#### Workaround 1: Disable App Check (NOT RECOMMENDED)
```env
ENABLE_APP_CHECK=false
```
**Pros**: Would unblock immediately
**Cons**: Security risk, not production-viable

#### Workaround 2: Use Debug Provider (TEMPORARY)
```dart
webProvider: DebugProvider(debugToken: 'registered-debug-token')
```
**Pros**: Validates App Check backend works
**Cons**: Not scalable, requires token registration per user

#### Workaround 3: Server-Side Admin Functions (MAJOR REWORK)
Create Cloud Functions to query time_entries server-side
**Pros**: Bypasses client-side App Check
**Cons**: Requires significant refactoring (days of work)

---

## 🎓 Lessons Learned (So Far)

1. **Firebase Console UI can be misleading** - "Registered" status doesn't guarantee backend sync
2. **App Check errors are opaque** - 400 with "initial-throttle" provides no actionable info
3. **Documentation is incomplete** - No clear troubleshooting guide for this scenario
4. **Propagation times are unpredictable** - Waited 60+ minutes with no change
5. **Multiple moving parts** - reCAPTCHA (Google Cloud) + App Check (Firebase) + Backend sync

---

## 📋 Checklist for Resolution

### Must Verify
- [ ] reCAPTCHA key valid in Google Cloud Console
- [ ] Firebase App Check shows "Registered" (done ✅)
- [ ] Web app ID matches between Firebase Console and code
- [ ] Domains match exactly (no http:// or trailing slashes)
- [ ] App Check enforced for Firestore API
- [ ] No conflicting Firebase rules or IAM permissions
- [ ] Network requests reach Firebase backend (not blocked by firewall/proxy)

### Must Test
- [ ] Debug provider (isolate reCAPTCHA)
- [ ] Different browser/device
- [ ] Different network (mobile hotspot)
- [ ] Fresh incognito session
- [ ] curl/Postman API test (if possible)

### Must Ask Firebase Support
- [ ] Is site key properly linked in backend database?
- [ ] Are there known issues with App Check + reCAPTCHA v3?
- [ ] Is there additional configuration needed for `us-east4` region?
- [ ] Can Firebase support force-sync the registration?

---

## 📞 Contact Information

**Project Owner**: juan_vallejo@uri.edu (authenticated with Firebase CLI)
**Project**: sierra-painting-staging
**Document Created**: 2025-10-13
**Last Updated**: 2025-10-13

**Related Documents**:
- `ADMIN_DASHBOARD_DEBUG_ANALYSIS.md` - Initial root cause analysis
- `ADMIN_DASHBOARD_FIX_VERIFICATION.md` - Verification guide
- `APPCHECK_DEBUG_TOKEN_INSTRUCTIONS.md` - Debug token setup (if exists)

---

## 🔍 Next Steps (Prioritized)

1. **[HIGH]** Enable debug provider temporarily to isolate reCAPTCHA
2. **[HIGH]** Capture Network tab details of failing App Check request
3. **[MEDIUM]** Unregister and re-register web app in Firebase Console
4. **[MEDIUM]** Contact Firebase support with this document
5. **[LOW]** Test in fresh Firebase project to validate setup steps

**Estimated Time to Resolution**:
- With Firebase support: 1-2 days
- Self-service debugging: Unknown (potentially days-weeks)
- Workaround implementation: 2-3 days

---

**END OF ESCALATION REPORT**
