# App Check Enablement Guide

**Purpose**: Enable Firebase App Check to protect against bot attacks and credential harvesting
**Reference**: T-001 (P0-SEC-001)
**Owner**: Security Team
**Last Updated**: 2025-10-13
**Priority**: 🔴 **CRITICAL - P0 BLOCKER**

---

## Overview

Firebase App Check protects backend resources (Firestore, Cloud Functions, Storage) from abuse by verifying requests come from legitimate apps. Currently App Check is **DISABLED**, leaving the web app vulnerable to:

- Bot attacks
- Credential harvesting
- Unauthorized API access
- DDoS attacks
- Resource abuse

**Issue**: P0-SEC-001 - `ENABLE_APP_CHECK=false` in `assets/config/public.env:10`
**Impact**: **CRITICAL** - Web vulnerable to bot attacks, credential harvesting
**Priority**: T+0 (must complete before launch)
**Size**: M (4-6h for full enablement + testing)

---

## Current State

**File**: `assets/config/public.env:10`
```env
ENABLE_APP_CHECK=false  # ❌ CRITICAL SECURITY ISSUE
```

**Risk**: All Firebase backend resources are accessible without attestation verification.

---

## App Check Providers by Platform

| Platform | Provider | Verification Method |
|----------|----------|---------------------|
| **Web** | ReCAPTCHA v3 | Score-based bot detection |
| **Android** | Play Integrity API | Device + app integrity |
| **iOS** | App Attest | Hardware-backed attestation |

---

## Implementation Roadmap

### Phase 1: Web (ReCAPTCHA v3) - **T+0 Priority**
- Estimated time: 2-3 hours
- Required for: Web app protection
- Blocker: Yes (P0-SEC-001)

### Phase 2: Android (Play Integrity) - **T+0 Priority**
- Estimated time: 1-2 hours
- Required for: Android app protection
- Blocker: Yes (P0-SEC-001)

### Phase 3: iOS (App Attest) - **Post-MVP** (if iOS supported)
- Estimated time: 1-2 hours
- Required for: iOS app protection
- Blocker: Only if iOS in MVP scope (see open_questions.md)

---

## Phase 1: Enable App Check for Web (ReCAPTCHA v3)

### Step 1.1: Register ReCAPTCHA v3 Site

1. Go to [Google reCAPTCHA Admin Console](https://www.google.com/recaptcha/admin)
2. Click **+ (Add)** to create a new site
3. Configure:
   - **Label**: `Sierra Painting - Staging`
   - **reCAPTCHA type**: **v3**
   - **Domains**: Add all domains:
     - `localhost`
     - `sierra-painting-staging.web.app`
     - `sierra-painting-staging.firebaseapp.com`
     - Your custom domain (if any)
   - **Owners**: Add team emails
   - Accept Terms of Service
4. Click **Submit**
5. **Copy Site Key** (you'll need this)

**Example Site Key**: `6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI`

**Repeat for Production**:
- Label: `Sierra Painting - Production`
- Domains: Production domains only

---

### Step 1.2: Register Web App in Firebase Console

1. Navigate to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `sierra-painting-staging`
3. Go to **Build → App Check**
4. Click **Apps** tab
5. Find your web app or click **+ Add app**
6. Select **Web** platform
7. Configure:
   - **App nickname**: `Sierra Painting Web`
   - **App Check provider**: **reCAPTCHA v3**
   - **reCAPTCHA site key**: Paste key from Step 1.1
8. Click **Register**

---

### Step 1.3: Configure App Check in Flutter Code

**File**: `lib/main.dart` (MODIFY)

**Add App Check initialization**:

```dart
import 'package:firebase_app_check/firebase_app_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ NEW: Initialize App Check
  await _initializeAppCheck();

  runApp(MyApp());
}

/// Initialize Firebase App Check
Future<void> _initializeAppCheck() async {
  // Skip App Check in tests
  if (const bool.fromEnvironment('FLUTTER_TEST')) {
    debugPrint('[AppCheck] Skipped (test mode)');
    return;
  }

  // Check if App Check should be enabled (from .env)
  const enableAppCheck = bool.fromEnvironment(
    'ENABLE_APP_CHECK',
    defaultValue: false,
  );

  if (!enableAppCheck) {
    debugPrint('[AppCheck] Disabled (ENABLE_APP_CHECK=false)');
    return;
  }

  // Activate App Check with appropriate provider
  await FirebaseAppCheck.instance.activate(
    // Web: ReCAPTCHA v3
    webRecaptchaSiteKey: const String.fromEnvironment(
      'RECAPTCHA_V3_SITE_KEY',
      defaultValue: '',
    ),
    // Android: Play Integrity
    androidProvider: AndroidProvider.playIntegrity,
    // iOS: App Attest (if supported)
    // appleProvider: AppleProvider.appAttest,
  );

  debugPrint('[AppCheck] Activated successfully');
}
```

---

### Step 1.4: Update Environment Variables

**File**: `assets/config/public.env` (LOCAL - keep DISABLED)
```env
ENABLE_APP_CHECK=false
RECAPTCHA_V3_SITE_KEY=  # Not needed for local dev
```

**File**: `.env.staging` (MODIFY)
```env
ENABLE_APP_CHECK=true  # ✅ ENABLE for staging
RECAPTCHA_V3_SITE_KEY=6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI  # ← Your key
```

**File**: `.env.production` (MODIFY)
```env
ENABLE_APP_CHECK=true  # ✅ ENABLE for production
RECAPTCHA_V3_SITE_KEY=<PRODUCTION_KEY>  # ← Different key
```

**NOTE**: Never commit ReCAPTCHA keys to git! Use environment-specific files.

---

### Step 1.5: Enable App Check Enforcement in Firebase Console

**IMPORTANT**: Enable enforcement AFTER testing with debug tokens!

1. Firebase Console → App Check
2. Click **APIs** tab
3. For each resource, click **⋮ → Enforce**:
   - [x] Cloud Firestore
   - [x] Cloud Functions (all functions)
   - [x] Cloud Storage
   - [x] Realtime Database (if used)

**⚠️ WARNING**: Enforcing without proper setup will break your app! Test with debug tokens first.

---

## Phase 2: Enable App Check for Android (Play Integrity)

### Step 2.1: Enable Play Integrity API

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your Firebase project
3. Navigate to **APIs & Services → Library**
4. Search for **"Play Integrity API"**
5. Click **Enable**

---

### Step 2.2: Register Android App in Firebase Console

1. Firebase Console → App Check → Apps tab
2. Find your Android app or click **+ Add app**
3. Configure:
   - **App nickname**: `Sierra Painting Android`
   - **App Check provider**: **Play Integrity**
4. Click **Register**

---

### Step 2.3: Configure Play Integrity in Flutter

**No additional code needed** - already configured in `main.dart` Step 1.3:
```dart
androidProvider: AndroidProvider.playIntegrity,
```

---

### Step 2.4: Test on Android Device

1. Build release APK:
   ```bash
   flutter build apk --release
   ```

2. Install on real device (emulator not supported for Play Integrity)
3. Open app and verify:
   - No 401 errors in logs
   - App Check token visible in Firebase Console → App Check → Metrics

---

## Debug Tokens (Local Development)

### Why Debug Tokens?

App Check blocks requests from development environments (localhost, emulators) by default. Debug tokens allow local development while enforcing App Check in staging/prod.

---

### Step D.1: Generate Debug Token

**Web (Chrome DevTools)**:
1. Run app: `flutter run -d chrome`
2. Open Chrome DevTools → Console
3. Look for App Check debug token in logs:
   ```
   [Firebase App Check] Debug token: abcd1234-5678-90ef-ghij-klmnopqrstuv
   ```
4. Copy the token

**Alternative (Programmatic)**:
```dart
// Add to main.dart (temporary, for debug token generation)
Future<void> _initializeAppCheck() async {
  await FirebaseAppCheck.instance.activate(...);

  // ✅ Get debug token (only in debug mode)
  if (kDebugMode) {
    final token = await FirebaseAppCheck.instance.getToken();
    debugPrint('[AppCheck] Debug Token: ${token?.token}');
  }
}
```

---

### Step D.2: Register Debug Token in Firebase Console

1. Firebase Console → App Check
2. Click **Apps** tab
3. Find your web app
4. Click **⋮ → Manage debug tokens**
5. Click **Add debug token**
6. Paste token from Step D.1
7. Add description: `Claude - Local Dev`
8. Set expiration: **7 days** (default)
9. Click **Save**

**NOTE**: Debug tokens expire every 7 days. You'll need to regenerate and re-register.

---

## Testing Checklist

### Pre-Enforcement Testing (Debug Tokens)

1. **Local Web Development**:
   - [ ] Register debug token (Step D.2)
   - [ ] Run: `flutter run -d chrome`
   - [ ] Verify: No 401 errors in console
   - [ ] Test: Login, Firestore queries, Cloud Function calls
   - [ ] Verify: All operations succeed

2. **Staging Web**:
   - [ ] Deploy with `ENABLE_APP_CHECK=true`
   - [ ] Open staging URL
   - [ ] Verify: ReCAPTCHA badge visible (bottom-right corner)
   - [ ] Test: Login, dashboard, data loading
   - [ ] Check: Firebase Console → App Check → Metrics (should show requests)

3. **Android (Real Device)**:
   - [ ] Build release APK
   - [ ] Install on real device (Play Integrity requires physical device)
   - [ ] Verify: No 401 errors
   - [ ] Test: Full app functionality
   - [ ] Check: App Check Metrics show Android requests

---

### Post-Enforcement Testing

**⚠️ Only enforce after pre-enforcement tests pass!**

1. **Enforce App Check** (Firebase Console → App Check → APIs → Enforce)
2. **Test Invalid Requests**:
   ```bash
   # Try accessing Firestore without App Check token
   curl -X POST https://firestore.googleapis.com/v1/projects/sierra-painting-staging/databases/(default)/documents/users \
     -H "Authorization: Bearer <VALID_FIREBASE_ID_TOKEN>"
   # Expected: 401 Unauthorized (App Check token missing)
   ```

3. **Test Valid Requests**:
   - Open app (staging or Android)
   - Perform actions: login, load data, create document
   - Verify: All succeed (no 401 errors)

4. **Monitor Metrics**:
   - Firebase Console → App Check → Metrics
   - Verify: Request counts increasing
   - Check: No spike in failed requests

---

## Rollback Procedure

If issues arise after enforcement:

### Quick Rollback (Emergency)

1. Firebase Console → App Check → APIs
2. Click **⋮** next to each resource
3. Select **Unenforced**
4. Wait 1-2 minutes for propagation
5. Test app functionality

**Downtime**: ~2 minutes

---

### Full Rollback (Disable App Check)

1. Update `.env.staging`:
   ```env
   ENABLE_APP_CHECK=false
   ```

2. Redeploy:
   ```bash
   flutter build web --release --dart-define=ENABLE_APP_CHECK=false
   firebase deploy --only hosting:staging
   ```

3. Unenforce APIs in Firebase Console (Step above)

**Downtime**: ~10 minutes (redeploy + propagation)

---

## Monitoring & Alerting

### Key Metrics to Monitor

1. **App Check Request Counts** (Firebase Console → App Check → Metrics)
   - Track: Requests per day
   - Alert: Sudden drop (may indicate enforcement issue)

2. **Failed Request Rate**
   - Track: 401 Unauthorized responses
   - Alert: >5% failed requests

3. **Debug Token Usage**
   - Track: Debug tokens in use
   - Alert: Production using debug tokens (security risk)

### Alerting Setup

**Cloud Monitoring Alert Policy**:
```yaml
Display Name: "App Check - High 401 Rate"
Condition:
  Metric: firebaseappcheck.googleapis.com/network/request_count
  Filter: response_code = 401
  Threshold: >100 requests in 5 min
  Duration: 5 minutes
Notification Channels:
  - Email: security@example.com
  - Slack: #security-alerts
```

---

## Troubleshooting

### Issue: "App Check token request failed"

**Symptoms**:
- Console error: `App Check token fetch failed`
- 401 errors on all requests

**Causes**:
1. ReCAPTCHA site key not configured
2. Domain not whitelisted in ReCAPTCHA console
3. Network blocking ReCAPTCHA CDN

**Solutions**:
1. Verify `RECAPTCHA_V3_SITE_KEY` in `.env.staging`
2. Add domain to ReCAPTCHA whitelist
3. Check firewall/proxy settings

---

### Issue: "Play Integrity API not enabled"

**Symptoms**:
- Android app crashes on startup
- Error: `Play Integrity API is not enabled`

**Solutions**:
1. Enable Play Integrity API in Google Cloud Console (Step 2.1)
2. Wait 5-10 minutes for propagation
3. Rebuild and reinstall app

---

### Issue: Debug token expired

**Symptoms**:
- Local dev suddenly returns 401 errors
- Was working yesterday, broken today

**Solutions**:
1. Generate new debug token (Step D.1)
2. Register in Firebase Console (Step D.2)
3. Restart app

**Prevention**: Set calendar reminder to refresh tokens every 6 days

---

### Issue: ReCAPTCHA badge not visible

**Symptoms**:
- No "reCAPTCHA badge" in bottom-right corner
- App Check not initializing

**Solutions**:
1. Verify `ENABLE_APP_CHECK=true` in environment
2. Check console for App Check errors
3. Verify ReCAPTCHA site key correct
4. Ensure `_initializeAppCheck()` called before Firebase usage

---

## Security Best Practices

1. **Never Commit Keys**:
   - Add `.env.staging`, `.env.production` to `.gitignore`
   - Use environment-specific files only

2. **Rotate Keys Regularly**:
   - ReCAPTCHA keys: Every 6 months
   - Debug tokens: Expire in 7 days (automatic)

3. **Monitor Abuse**:
   - Review App Check Metrics weekly
   - Alert on sudden traffic spikes
   - Investigate 401 error patterns

4. **Enforce Everywhere**:
   - Enable for ALL Firebase resources (Firestore, Functions, Storage)
   - No exceptions for "internal" functions

5. **Production Debug Tokens**:
   - **NEVER** use debug tokens in production
   - Remove all debug token code before production deploy
   - Audit: Search codebase for `FirebaseAppCheck.setTokenAutoRefreshEnabled(false)`

---

## Acceptance Criteria (T-001)

- [x] **Implementation guide created**: This document
- [ ] ReCAPTCHA v3 site registered (staging + prod)
- [ ] ReCAPTCHA keys added to `.env.staging`, `.env.production`
- [ ] App Check initialized in `lib/main.dart`
- [ ] Web app registers with Firebase App Check
- [ ] Android app uses Play Integrity
- [ ] Debug tokens registered for local dev
- [ ] Pre-enforcement testing complete (no 401 errors)
- [ ] App Check enforced in Firebase Console (staging)
- [ ] Post-enforcement testing complete
- [ ] Invalid tokens receive 401 responses
- [ ] Monitoring alerts configured
- [ ] Deployed to staging successfully

**Status**: 📋 Guide complete (awaiting implementation)

---

## Timeline

| Phase | Duration | Owner | Blocker |
|-------|----------|-------|---------|
| **Phase 1.1-1.4**: Web ReCAPTCHA setup | 2h | Security Team | P0 |
| **Phase 1.5**: Enforce (after testing) | 30min | Security Team | P0 |
| **Phase 2**: Android Play Integrity | 1h | Mobile Team | P0 |
| **Testing**: Pre + Post enforcement | 1h | QA Team | P0 |
| **Monitoring**: Alerts setup | 30min | DevOps Team | - |
| **Total** | **4-6h** | - | - |

---

## Related Tasks

- **T-002**: Rotate exposed credentials (secrets management)
- **T-014**: Add route guards (authentication layer)
- **T-020**: Structured logging (security event tracking)
- **T-042**: Lighthouse CI (performance impact of ReCAPTCHA)

---

## References

- [Firebase App Check Documentation](https://firebase.google.com/docs/app-check)
- [ReCAPTCHA v3 Guide](https://developers.google.com/recaptcha/docs/v3)
- [Play Integrity API](https://developer.android.com/google/play/integrity)
- [App Check Flutter Plugin](https://firebase.flutter.dev/docs/app-check/overview)

---

## Action Items

**Immediate** (T+0, within 48h):
1. [ ] Register ReCAPTCHA v3 sites (staging + prod)
2. [ ] Register web app in Firebase App Check
3. [ ] Update `.env.staging` with keys
4. [ ] Initialize App Check in `main.dart`
5. [ ] Generate and register debug tokens
6. [ ] Test locally with debug tokens
7. [ ] Deploy to staging
8. [ ] Enforce App Check in staging (after testing)
9. [ ] Enable Play Integrity for Android
10. [ ] Monitor for 24h

**Follow-up** (Week 1):
1. [ ] Review App Check Metrics
2. [ ] Configure monitoring alerts
3. [ ] Deploy to production
4. [ ] Document debug token refresh process
5. [ ] Train team on App Check troubleshooting

---

**Last Updated**: 2025-10-13
**Next Review**: After T-001 implementation (staging validation)
**Security Review**: Required before production enforcement
