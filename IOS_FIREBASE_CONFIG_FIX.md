# iOS Firebase Configuration Fix

**Status:** ⚠️ **MANUAL ACTION REQUIRED**
**Priority:** 🔴 **BLOCKS iOS STAGING DEPLOYMENT**
**Date:** 2025-10-12

---

## Problem

The iOS Firebase configuration currently points to the **dev project** instead of the staging project:

**Current (WRONG):**
```dart
// lib/firebase_options.dart:63-70
static const FirebaseOptions ios = FirebaseOptions(
  apiKey: 'AIzaSyDNe_2n0gBPDZiOdwYvq-3r-jsqWyZ_V6g',
  appId: '1:138777646966:ios:eb8f44789bae81f27e0c57',
  messagingSenderId: '138777646966',
  projectId: 'to-do-app-ac602',  // ❌ DEV PROJECT
  storageBucket: 'to-do-app-ac602.firebasestorage.app',
  iosBundleId: 'com.example.sierraPainting',
);
```

**Expected (CORRECT):**
```dart
static const FirebaseOptions ios = FirebaseOptions(
  projectId: 'sierra-painting-staging',  // ✅ STAGING PROJECT
  // ... other fields will be updated by flutterfire configure
);
```

---

## Impact

**Without this fix:**
- ❌ iOS builds will write to the **dev** Firestore database
- ❌ iOS users will not see data from staging
- ❌ Clock in/out on iOS will create entries in wrong project
- ❌ Cannot test iOS staging deployment
- ❌ Cannot release iOS app to staging TestFlight

**With this fix:**
- ✅ iOS writes to **staging** Firestore database
- ✅ iOS users see correct staging data
- ✅ All platforms (Web, Android, iOS) use same staging backend
- ✅ Can test iOS staging deployment end-to-end
- ✅ Can release to staging TestFlight

---

## Solution

### Step 1: Ensure Prerequisites

```bash
# Check Flutter version
flutter --version
# Should be >= 3.35.5

# Check flutterfire CLI is installed
dart pub global activate flutterfire_cli

# Authenticate with Firebase
firebase login
```

### Step 2: Run flutterfire configure

```bash
# From project root
flutterfire configure \
  --project=sierra-painting-staging \
  --platforms=ios \
  --ios-bundle-id=com.sierrapainting.app \
  --out=lib/firebase_options.dart \
  --overwrite-firebase-options

# OR without flags (interactive mode):
flutterfire configure
# Then select:
#   - Project: sierra-painting-staging
#   - Platforms: iOS only (deselect others)
#   - Bundle ID: com.sierrapainting.app
```

### Step 3: Verify Changes

```bash
# Check that ios projectId is now sierra-painting-staging
grep -A 5 "static const FirebaseOptions ios" lib/firebase_options.dart

# Expected output should include:
#   projectId: 'sierra-painting-staging',
```

### Step 4: Download Updated GoogleService-Info.plist

The `flutterfire configure` command should have prompted you to download the updated `GoogleService-Info.plist` file. If not:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select **sierra-painting-staging** project
3. Go to **Project Settings** → **General** → **Your apps** → **iOS app**
4. Click **Download GoogleService-Info.plist**
5. Replace `ios/Runner/GoogleService-Info.plist` with the downloaded file

### Step 5: Rebuild iOS App

```bash
# Clean build
flutter clean

# Rebuild with staging flavor
flutter build ios --release --dart-define=FLAVOR=staging

# OR run on simulator
flutter run -d <ios-simulator> --dart-define=USE_EMULATOR=false
```

---

## Verification

After applying the fix, verify iOS writes to staging:

1. **Run iOS app on simulator:**
   ```bash
   flutter run -d "iPhone 15 Pro"
   ```

2. **Sign in with test account:**
   - Email: test-worker@sierrapainting.com
   - Password: (from TEST_CREDENTIALS.md)

3. **Clock in to a job:**
   - Tap "Clock In" button
   - Grant location permission
   - Verify success message

4. **Check Firestore:**
   ```bash
   firebase firestore:get time_entries \
     --project sierra-painting-staging \
     --limit 1
   ```

5. **Expected:** You should see the iOS clock-in entry in staging Firestore

---

## Troubleshooting

### Error: "No such project: sierra-painting-staging"

**Cause:** You're not authenticated or don't have access to the project.

**Fix:**
```bash
firebase login --reauth
firebase projects:list
# Verify sierra-painting-staging appears in the list
```

### Error: "Invalid iOS bundle ID"

**Cause:** Bundle ID mismatch between Xcode and Firebase.

**Fix:**
1. Open `ios/Runner.xcworkspace` in Xcode
2. Check **Bundle Identifier** under **General** tab
3. Ensure it matches `com.sierrapainting.app`
4. Update in Firebase Console if needed

### Error: "GoogleService-Info.plist not found"

**Cause:** File not downloaded or placed in wrong location.

**Fix:**
```bash
# Download from Firebase Console
# Place at: ios/Runner/GoogleService-Info.plist

# Verify location:
ls -la ios/Runner/GoogleService-Info.plist
```

### iOS still writes to dev database

**Cause:** Cached build artifacts.

**Fix:**
```bash
flutter clean
cd ios && pod deintegrate && pod install && cd ..
flutter build ios --release --dart-define=FLAVOR=staging
```

---

## Why Manual?

This fix requires **manual execution** because:

1. **Firebase CLI authentication** - Requires interactive login with user credentials
2. **Project selection** - Requires confirming the correct Firebase project
3. **iOS-specific files** - Requires updating Xcode project and `GoogleService-Info.plist`
4. **Certificate verification** - May require Apple Developer account access

Claude Code cannot programmatically:
- Authenticate with Firebase CLI
- Access Firebase Console to download iOS config
- Modify Xcode project settings
- Verify Apple Developer certificates

---

## Related Files

- `lib/firebase_options.dart` - Firebase configuration for all platforms
- `ios/Runner/GoogleService-Info.plist` - iOS Firebase SDK configuration
- `ios/Runner.xcworkspace` - Xcode project
- `.firebaserc` - Firebase project aliases (already configured)

---

## Next Steps After Fix

1. ✅ Mark this task as complete in `HYGIENE_PATCH_EXECUTION_COMPLETE.md`
2. ✅ Run full iOS smoke test (sign in, clock in, clock out, view history)
3. ✅ Verify data in staging Firestore matches iOS actions
4. ✅ Deploy iOS app to TestFlight staging track (if applicable)

---

**Generated:** 2025-10-12
**By:** Claude Code Functionality Patch Phase 1
**Status:** Awaiting manual execution
