# Firebase App Check Setup & Debug Guide

Firebase App Check protects your backend resources from abuse by ensuring requests come from authentic instances of your app.

## Overview

App Check works by:
1. Verifying your app's authenticity with an attestation provider
2. Issuing a time-limited token
3. Validating the token on your backend before processing requests

## Setup for Flutter

### 1. Install Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  firebase_app_check: ^0.2.1+8
```

Run:
```bash
flutter pub get
```

### 2. Initialize App Check

Update `lib/main.dart`:

```dart
import 'package:firebase_app_check/firebase_app_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize App Check
  await FirebaseAppCheck.instance.activate(
    // For Android
    androidProvider: AndroidProvider.playIntegrity,
    // For iOS
    appleProvider: AppleProvider.appAttest,
    // For web
    webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
  );

  runApp(const MyApp());
}
```

### 3. Configure Providers

#### Android (Play Integrity)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to App Check
4. Register your Android app
5. Enable Play Integrity API in Google Cloud Console

No code changes needed - Play Integrity is automatic.

#### iOS (App Attest)

1. Register your iOS app in Firebase Console → App Check
2. App Attest is enabled automatically on iOS 14+
3. For iOS 13 and below, falls back to DeviceCheck

#### Web (reCAPTCHA v3)

1. Get a reCAPTCHA v3 site key from [Google reCAPTCHA](https://www.google.com/recaptcha/admin)
2. Register site key in Firebase Console → App Check
3. Update the `ReCaptchaV3Provider` with your site key

## Debug Mode

⚠️ **Debug tokens should NEVER be used in production builds!**

### Enable Debug Mode

Debug mode allows you to test App Check without having valid attestations.

#### Flutter Debug Mode

Add to `lib/main.dart` (debug builds only):

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Only for debug builds
  if (kDebugMode) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  } else {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
      appleProvider: AppleProvider.appAttest,
    );
  }

  runApp(const MyApp());
}
```

#### Get Debug Token

Run your app in debug mode and check the logs:

**Android (Logcat):**
```
I/FirebaseAppCheck: App Check debug token: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
```

**iOS (Console):**
```
[Firebase/AppCheck][I-FAA001001] App Check debug token: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
```

**Flutter Console:**
```dart
void main() async {
  // ... Firebase init ...
  
  if (kDebugMode) {
    final token = await FirebaseAppCheck.instance.getToken();
    print('🔐 App Check Debug Token: $token');
  }
}
```

### Register Debug Token

1. Copy the debug token from logs
2. Go to Firebase Console → App Check
3. Click "Manage debug tokens"
4. Add the debug token with a description (e.g., "John's Dev Phone")
5. Save

The token is now valid for 7 days.

## Enforce App Check

### In HTTP Functions (Using Middleware)

For HTTP functions (onRequest), use the `requireAppCheck` middleware:

```typescript
import { requireAppCheck } from './middleware/appCheck';
import * as functions from 'firebase-functions';

export const myHttpEndpoint = functions.https.onRequest(
  requireAppCheck(async (req, res) => {
    // Your handler logic here
    // App Check is already verified by middleware
    res.status(200).send({ success: true });
  })
);
```

The middleware is located at `functions/src/middleware/appCheck.ts`.

**Note**: For callable functions, use `enforceAppCheck: true` in runWith config (see below) instead of middleware.

### In Firestore Rules

Add App Check validation to your rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    function hasValidAppCheck() {
      return request.app.appCheck.token.aud[0] == request.app.projectId;
    }
    
    match /invoices/{invoiceId} {
      // Require App Check for all invoice operations
      allow read, write: if hasValidAppCheck() && isAdmin();
    }
  }
}
```

### In Cloud Functions

Protect callable functions:

```typescript
import * as functions from 'firebase-functions';

export const markPaymentPaid = functions
  .runWith({
    // Enforce App Check
    enforceAppCheck: true,
  })
  .https.onCall(async (data, context) => {
    // Verify App Check token exists
    if (!context.app) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'The function must be called from an App Check verified app.'
      );
    }
    
    // Your function logic here
  });
```

For HTTP functions:

```typescript
export const stripeWebhook = functions.https.onRequest(async (req, res) => {
  // App Check is not enforced for webhooks from external services
  // Use webhook signature verification instead
  
  const sig = req.headers['stripe-signature'];
  // ... verify signature ...
});
```

### In Storage Rules

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /invoices/{invoiceId} {
      allow read: if request.auth != null && 
                     request.app.appCheck.token.aud[0] == request.app.projectId;
    }
  }
}
```

## Testing App Check

### Test Valid App Check

1. Run app in debug mode with registered debug token
2. Try to call protected functions
3. Should succeed

### Test Invalid App Check

1. Remove debug token from Firebase Console
2. Try to call protected functions
3. Should fail with "App Check token is invalid"

### Manual Testing with curl

Get a valid App Check token:

```dart
final token = await FirebaseAppCheck.instance.getToken();
print('Token: ${token?.token}');
```

Use in API calls:

```bash
curl -X POST https://us-central1-<project-id>.cloudfunctions.net/markPaymentPaid \
  -H "Content-Type: application/json" \
  -H "X-Firebase-AppCheck: <your-token>" \
  -d '{"invoiceId": "test", "amount": 100}'
```

## Monitoring & Metrics

### View App Check Metrics

1. Go to Firebase Console → App Check
2. Click on "Metrics" tab
3. View:
   - Valid vs Invalid requests
   - Requests by app/platform
   - Token generation rate

### Set Up Alerts

Create Cloud Monitoring alerts for:
- High invalid request rate (potential abuse)
- Low token generation (integration issues)
- Failed attestations

## Replay Protection

App Check tokens are single-use. The same token cannot be used twice.

Enable replay protection in Cloud Functions:

```typescript
export const sensitiveOperation = functions
  .runWith({
    enforceAppCheck: true,
    // Enable replay attack protection
    consumeAppCheckToken: true,
  })
  .https.onCall(async (data, context) => {
    // This function consumes the App Check token
    // Replaying the same request will fail
  });
```

## Troubleshooting

### "App Check token is invalid"

**Causes:**
- Debug token not registered in Firebase Console
- Debug token expired (7 days)
- Wrong Firebase project ID
- App Check not initialized in app

**Solutions:**
1. Check debug token is registered
2. Generate new debug token if expired
3. Verify `google-services.json` / `GoogleService-Info.plist` has correct project ID
4. Ensure `FirebaseAppCheck.instance.activate()` is called before Firebase operations

### "Play Integrity API not enabled"

**Solution:**
1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project
3. Enable "Play Integrity API"
4. Wait 5-10 minutes for propagation

### "App not registered with App Check"

**Solution:**
1. Go to Firebase Console → App Check
2. Click "Register app"
3. Select your app (Android/iOS/Web)
4. Follow registration steps

### Tokens Not Generated

**Check:**
1. Internet connectivity
2. Firebase project ID is correct
3. App Check is initialized before Firebase operations
4. No AdBlockers interfering (Web)

### High Invalid Request Rate

**Investigate:**
- Unauthorized apps accessing your backend
- Compromised API keys
- Bots/scrapers

**Actions:**
1. Review App Check metrics
2. Rotate API keys if compromised
3. Enforce App Check in all rules
4. Enable replay protection

## Production Checklist

Before going to production:

- [ ] Remove all debug tokens from app code
- [ ] Verify production attestation providers are configured (Play Integrity, App Attest)
- [ ] Test with production build on real devices
- [ ] Enforce App Check in Firestore, Storage, and Functions
- [ ] Set up monitoring alerts
- [ ] Document debug token registration process for team
- [ ] Test token refresh behavior
- [ ] Verify token expiration handling

## Best Practices

1. **Never commit debug tokens** to version control
2. **Use debug tokens only in debug builds** - check with `kDebugMode`
3. **Enforce App Check on sensitive operations** - payments, admin functions
4. **Monitor invalid request rates** - set up alerts
5. **Rotate debug tokens regularly** - every 7 days for active development
6. **Test with production builds** before releasing
7. **Document the process** for new team members

## Rollout Plan

### Environment Configuration

The app uses a `--dart-define` flag to control App Check:

```bash
# Debug build (App Check disabled or using debug provider)
flutter run

# Release build with App Check enabled
flutter build apk --release --dart-define=ENABLE_APP_CHECK=true
flutter build ios --release --dart-define=ENABLE_APP_CHECK=true

# Staging/Canary with App Check enabled
flutter build apk --dart-define=ENABLE_APP_CHECK=true
```

By default:
- **Debug builds**: Use debug provider (or disabled)
- **Release builds**: Always enabled with production providers (Play Integrity/App Attest)

### Phased Rollout Strategy

**Phase 1: Staging Environment**
1. Deploy app with `ENABLE_APP_CHECK=true` to staging
2. Deploy Cloud Functions with `enforceAppCheck: true`
3. Update Firestore and Storage rules with App Check validation
4. Test with debug tokens
5. Monitor metrics for 24-48 hours
6. Verify crash-free rate remains stable

**Phase 2: Canary Environment**
1. Deploy to canary with 5-10% of users
2. Monitor Firebase DebugView for App Check tokens
3. Check invalid request rates
4. Verify no increase in authentication errors
5. Monitor for 48-72 hours

**Phase 3: Production Environment**
1. Deploy to production with gradual rollout (10% → 50% → 100%)
2. Monitor key metrics:
   - Crash-free rate
   - Invalid request rate
   - User authentication success rate
   - API latency (should be ≤50ms overhead)
3. Keep rollback plan ready

### Enforcement Script

Use the provided script to manage App Check enforcement across environments:

```bash
# Dry-run to preview changes
./scripts/app_check_enforce.sh --dry-run staging

# Enable App Check in staging
./scripts/app_check_enforce.sh staging

# Enable in production
./scripts/app_check_enforce.sh prod

# Disable if needed (rollback)
./scripts/app_check_enforce.sh --disable staging
```

## Break-Glass Rollback Procedure

If App Check causes issues in production, follow these steps immediately:

### Step 1: Disable Enforcement in Backend (Immediate - 5 minutes)

**Option A: Cloud Functions (Fastest)**
```typescript
// Comment out enforceAppCheck in affected functions
export const myFunction = functions
  .runWith({
    // enforceAppCheck: true,  // TEMPORARILY DISABLED
  })
  .https.onCall(async (data, context) => {
    // Your logic
  });
```

Deploy functions only:
```bash
firebase deploy --only functions
```

**Option B: Security Rules (Firestore/Storage)**
```javascript
// Comment out App Check validation temporarily
// function hasValidAppCheck() {
//   return request.app.appCheck.token.aud[0] == request.app.projectId;
// }

match /collection/{doc} {
  // allow read, write: if hasValidAppCheck() && otherConditions;
  allow read, write: if otherConditions;  // TEMPORARILY: App Check disabled
}
```

Deploy rules:
```bash
firebase deploy --only firestore:rules,storage
```

### Step 2: Disable in Mobile App (Next Release - Hours)

Update `lib/main.dart`:
```dart
// Temporarily disable App Check
const enableAppCheck = String.fromEnvironment('ENABLE_APP_CHECK', defaultValue: 'false');
// Force disable: const shouldEnableAppCheck = false;
```

Or deploy with flag:
```bash
flutter build apk --release --dart-define=ENABLE_APP_CHECK=false
```

### Step 3: Use Enforcement Script

```bash
# Disable App Check enforcement
./scripts/app_check_enforce.sh --disable prod

# Redeploy affected services
firebase deploy --only functions,firestore:rules,storage
```

### Step 4: Investigate and Fix

1. Check Firebase Console → App Check → Metrics
2. Review error logs for App Check failures
3. Verify provider configuration (Play Integrity, App Attest)
4. Check for known issues:
   - Android devices below API level 19
   - iOS devices below iOS 14 without DeviceCheck
   - Network issues preventing token generation
5. Test fix in staging before re-enabling

### Step 5: Re-enable with Fix

1. Deploy fix to staging
2. Test thoroughly
3. Enable in canary (5-10% traffic)
4. Monitor for 48 hours
5. Gradual rollout to production

## Monitoring & Alerts

Set up these alerts in Firebase Console:

1. **Invalid Request Rate** > 5% → Critical
2. **App Check Token Failures** > 1% → Warning
3. **API Latency** increase > 100ms → Warning
4. **Crash-free Rate** drop > 0.5% → Critical

Monitor these metrics during rollout:
- App Check verification success rate
- Token generation latency
- Backend request success rate
- User-reported authentication issues

## Resources

- [Firebase App Check Documentation](https://firebase.google.com/docs/app-check)
- [Play Integrity API](https://developer.android.com/google/play/integrity)
- [App Attest](https://developer.apple.com/documentation/devicecheck/establishing_your_app_s_integrity)
- [App Check with Cloud Functions](https://firebase.google.com/docs/app-check/cloud-functions)
- [App Check Monitoring](https://firebase.google.com/docs/app-check/monitor-metrics)
