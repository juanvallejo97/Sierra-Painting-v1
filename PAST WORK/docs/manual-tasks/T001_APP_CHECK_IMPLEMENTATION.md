# T-001: Enable App Check Implementation Guide

**Priority**: P0 - CRITICAL (Security Blocker)
**Estimated Time**: 30-45 minutes
**Prerequisites**: Firebase Console admin access
**Status**: ⏳ Awaiting manual configuration

---

## Overview

App Check protects your Firebase resources from abuse by verifying that requests come from your authentic app. Currently **disabled** in the codebase, this is a critical security gap.

**Risk**: Without App Check, malicious actors can:
- Bypass rate limits
- Access Firebase services directly
- Drain quota/budget
- Access Firestore data (limited by rules, but still exposed)

---

## Current State

### Code Status
✅ **App Check code is already implemented** in `lib/main.dart`:
```dart
Future<void> _activateAppCheck() async {
  final enableAppCheck = (dotenv.env['ENABLE_APP_CHECK'] ?? 'true').toLowerCase() == 'true';

  if (!enableAppCheck) {
    debugPrint('App Check: disabled via env');
    return; // Currently returns here
  }

  // Web: ReCaptchaV3Provider
  // Android: PlayIntegrity (prod) / Debug (dev)
  // iOS: AppAttest (prod) / Debug (dev)
}
```

### Configuration Files
- `.env` (local): `ENABLE_APP_CHECK=false`
- `.env.staging`: `ENABLE_APP_CHECK=true` (needs verification)
- `.env.production`: `ENABLE_APP_CHECK=true` (needs configuration)
- `web/index.html`: Debug mode enabled for testing

---

## Implementation Steps

### Phase 1: Staging Configuration (30 min)

#### Step 1: Verify reCAPTCHA v3 Configuration
1. Navigate to Firebase Console: https://console.firebase.google.com/project/sierra-painting-staging/appcheck
2. Click **Apps** tab
3. Verify Web app registration:
   - ✅ App should be listed
   - ✅ Provider: reCAPTCHA v3
   - ✅ Site key should match `RECAPTCHA_V3_SITE_KEY` in `.env.staging`

**If not configured**:
1. Click **Register app** → Select Web app
2. Choose **reCAPTCHA v3** provider
3. Copy the site key
4. Update `.env.staging`:
   ```bash
   RECAPTCHA_V3_SITE_KEY=6Lf...your-key
   ENABLE_APP_CHECK=true
   ```

#### Step 2: Register Debug Token (Development/Testing)
1. Deploy current code to staging:
   ```bash
   firebase deploy --project sierra-painting-staging
   ```

2. Open https://sierra-painting-staging.web.app in Chrome

3. Open **Developer Console** (F12)

4. Look for this message:
   ```
   Firebase App Check debug token: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
   ```

5. Copy the debug token

6. In Firebase Console → App Check → **Debug tokens** tab:
   - Click **Add debug token**
   - Paste token
   - Set name: `staging-local-dev`
   - Set expiry: 7 days (renewable)
   - Click **Save**

#### Step 3: Verify App Check is Active
1. Refresh https://sierra-painting-staging.web.app

2. Open Network tab in DevTools

3. Look for requests to Firebase services:
   - Headers should include: `X-Firebase-AppCheck: <token>`

4. Check console for:
   ```
   App Check: activation succeeded (debug mode enabled in index.html)
   ```

5. Test admin dashboard:
   - Log in as admin user
   - Navigate to `/admin/home`
   - Should load without 401 errors

**If you see errors**:
- Check that debug token is registered correctly
- Verify `.env.staging` has `ENABLE_APP_CHECK=true`
- Check Cloud Functions logs for App Check errors

#### Step 4: Test Without Debug Token (Optional)
1. Remove debug token from Firebase Console (or use incognito mode)

2. Refresh app

3. reCAPTCHA should work automatically (invisible challenge)

4. Verify App Check token is still present in network requests

---

### Phase 2: Production Configuration (15 min)

**⚠️ WARNING**: Only proceed after staging is verified working

#### Step 1: Configure Production App Check
1. Navigate to: https://console.firebase.google.com/project/sierra-painting-prod/appcheck

2. Register Web app with reCAPTCHA v3:
   - Get site key from Google reCAPTCHA admin console
   - Or reuse staging key (if same domain)

3. Update `.env.production`:
   ```bash
   RECAPTCHA_V3_SITE_KEY=6Lf...prod-key
   ENABLE_APP_CHECK=true
   ```

#### Step 2: Deploy to Production
```bash
# Build with production env
flutter build web --release

# Deploy
firebase deploy --project sierra-painting-prod --only hosting
```

#### Step 3: Monitor Production
1. Check Firebase Console → App Check → Metrics:
   - Tokens issued: Should increase
   - Token rejections: Should be low
   - Invalid requests: Monitor for attacks

2. Check Cloud Functions logs:
   ```bash
   firebase functions:log --project sierra-painting-prod --limit 50
   ```

3. Look for App Check errors:
   - `403 Forbidden` - App Check token missing
   - `UNAUTHENTICATED` - Invalid token

#### Step 4: Android/iOS Configuration (Future)

**Android (Play Integrity)**:
1. Firebase Console → App Check → Android app
2. Enable **Play Integrity** provider
3. SHA-256 fingerprints from Google Play Console
4. No code changes needed (already implemented)

**iOS (App Attest)**:
1. Firebase Console → App Check → iOS app
2. Enable **App Attest** provider
3. Add App ID from Apple Developer account
4. No code changes needed (already implemented)

---

## Rollback Plan

If App Check causes issues in production:

### Quick Disable (5 min)
1. SSH into hosting or update env:
   ```bash
   ENABLE_APP_CHECK=false
   ```

2. Redeploy:
   ```bash
   firebase deploy --project sierra-painting-prod --only hosting
   ```

### Alternative: Use Remote Config (10 min)
Instead of `.env`, use Firebase Remote Config:

1. Firebase Console → Remote Config
2. Add parameter: `enable_app_check` = `false`
3. Update code to check Remote Config first

---

## Verification Checklist

### Staging
- [ ] reCAPTCHA v3 site key configured
- [ ] Debug token registered (7-day expiry)
- [ ] App Check token present in network requests
- [ ] Admin dashboard loads without errors
- [ ] Cloud Functions accept requests
- [ ] No 401/403 errors in console

### Production
- [ ] Production reCAPTCHA key configured
- [ ] App Check metrics showing tokens issued
- [ ] No spike in 403 errors
- [ ] User flows work (login, clock-in, admin)
- [ ] Mobile apps tested (if deployed)

---

## Troubleshooting

### Error: "App Check token missing"
**Cause**: Client not sending token
**Fix**:
1. Verify `ENABLE_APP_CHECK=true` in env
2. Check `_activateAppCheck()` is called in `main()`
3. Verify reCAPTCHA site key is correct

### Error: "App Check token invalid"
**Cause**: Token expired or site key mismatch
**Fix**:
1. Verify debug token is registered in Firebase Console
2. Check token expiry (max 7 days)
3. Re-register debug token

### Error: "reCAPTCHA challenge failed"
**Cause**: User failed reCAPTCHA (rare)
**Fix**:
1. User should retry
2. Check reCAPTCHA score threshold in Firebase Console
3. Consider using reCAPTCHA Enterprise for better UX

### High token rejection rate
**Cause**: Possible attack or misconfiguration
**Fix**:
1. Check App Check metrics for patterns
2. Review Firebase Console → App Check → Alerts
3. Verify site key matches deployment
4. Check for expired debug tokens

---

## Monitoring & Alerts

### Firebase Console Dashboards
1. **App Check Overview**:
   - https://console.firebase.google.com/project/sierra-painting-prod/appcheck

2. **Metrics to Monitor**:
   - Tokens issued/day (should be high)
   - Token rejections (should be < 1%)
   - Invalid requests blocked (attackers)

3. **Set Up Alerts**:
   - Firebase Console → App Check → Alerts
   - Alert on: High rejection rate (> 5%)
   - Notification: Slack/Email

### Cloud Functions Logs
```bash
# Check for App Check errors
firebase functions:log --project sierra-painting-prod | grep "AppCheck"

# Monitor rejection rate
firebase functions:log --project sierra-painting-prod | grep "403 Forbidden"
```

---

## Security Best Practices

### ✅ DO
- Use reCAPTCHA v3 for web (invisible)
- Use Play Integrity for Android production
- Use App Attest for iOS production
- Rotate debug tokens every 7 days
- Monitor App Check metrics weekly
- Set up alerts for high rejection rates

### ❌ DON'T
- Use debug provider in production
- Share debug tokens publicly
- Disable App Check without reason
- Ignore high rejection rates
- Forget to register mobile apps

---

## Cost Implications

### Free Tier (Current)
- **reCAPTCHA v3**: Free (included with Firebase)
- **Play Integrity**: 10,000 calls/month free
- **App Attest**: 10,000 calls/month free

### Paid (If Exceeded)
- **Play Integrity**: $0.0005 per call after 10k
- **App Attest**: $0.0005 per call after 10k
- **reCAPTCHA Enterprise**: Optional upgrade for better UX

**Expected Cost (at 100k MAU)**:
- Web: $0 (reCAPTCHA v3 is always free)
- Android: ~$45/month (100k - 10k) * $0.0005
- iOS: ~$45/month (100k - 10k) * $0.0005
- **Total**: ~$90/month for full protection

**ROI**: Protects against:
- Quota exhaustion ($$$)
- Data scraping
- API abuse
- Malicious traffic

---

## Post-Implementation

### Week 1
- [ ] Monitor App Check metrics daily
- [ ] Check for 403/401 spike in error logs
- [ ] Verify user flows work (smoke tests)
- [ ] Rotate debug tokens if expired

### Week 2-4
- [ ] Review App Check rejection patterns
- [ ] Set up automated alerts
- [ ] Document any issues/edge cases
- [ ] Plan Android/iOS rollout (if applicable)

### Long-term
- [ ] Monthly review of App Check metrics
- [ ] Quarterly rotation of debug tokens
- [ ] Annual review of reCAPTCHA score threshold
- [ ] Consider reCAPTCHA Enterprise for better UX

---

## References

- **Firebase App Check Docs**: https://firebase.google.com/docs/app-check
- **reCAPTCHA v3 Docs**: https://developers.google.com/recaptcha/docs/v3
- **Play Integrity Docs**: https://developer.android.com/google/play/integrity
- **App Attest Docs**: https://developer.apple.com/documentation/devicecheck/attestation

---

## Support

**Questions?**
- Firebase Support: https://firebase.google.com/support/contact/troubleshooting
- Stack Overflow: `firebase-app-check` tag
- Firebase Slack: #app-check channel

**Escalation**:
If App Check causes production issues:
1. Disable immediately (see Rollback Plan)
2. Document the error
3. Contact Firebase Support with logs
4. Re-enable once resolved

---

**Status**: ⏳ Ready for implementation
**Owner**: DevOps Team
**Due Date**: Within 48 hours (CRITICAL priority)
