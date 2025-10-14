# iOS Deployment Setup

This document describes the complete process for deploying the Sierra Painting app to Apple's App Store, including TestFlight distribution for beta testing.

## Overview

iOS deployment requires:
- Building the app with Xcode on macOS
- Signing with valid certificates and provisioning profiles
- Archiving and uploading to App Store Connect
- Submitting for App Review

**Deployment Stages:**
- **TestFlight**: Internal and external beta testing
- **App Store**: Production release to all users

---

## Prerequisites

Before starting iOS deployment, ensure you have:

### Development Environment
- **macOS computer** (required for Xcode and iOS builds)
- **Xcode 14.0 or higher** installed from the Mac App Store
- **Flutter SDK 3.10.0 or higher** installed and configured
- **CocoaPods** installed (`sudo gem install cocoapods`)
- **Command Line Tools** installed (`xcode-select --install`)

### Apple Developer Account
- **Apple Developer Program** subscription (paid, $99/year)
  - Sign up at: https://developer.apple.com/programs/
  - Organization or Individual account
- Valid payment method on file
- Two-factor authentication enabled

### Required Access
- Access to Apple Developer Portal (developer.apple.com)
- Access to App Store Connect (appstoreconnect.apple.com)
- Access to Firebase Console for iOS app configuration

---

## Apple Developer Account Setup

### 1. Create App ID

1. Log in to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **Identifiers** → Click **+** button
4. Choose **App IDs** → Click **Continue**
5. Configure the App ID:
   - **Description**: Sierra Painting
   - **Bundle ID**: `com.sierrapainting.app` (Explicit)
   - **Capabilities**: Enable required capabilities:
     - ✅ Push Notifications
     - ✅ Background Modes (if needed)
     - ✅ Sign In with Apple (if using)
6. Click **Continue** → **Register**

### 2. Create Certificates

#### Development Certificate
Required for testing on physical devices:

```bash
# Generate Certificate Signing Request (CSR)
# Open Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority
# Save to disk as: CertificateSigningRequest.certSigningRequest
```

1. Go to **Certificates** → Click **+**
2. Select **Apple Development** → Click **Continue**
3. Upload the CSR file → Click **Continue**
4. Download the certificate → Double-click to install in Keychain

#### Distribution Certificate
Required for App Store submission:

1. Go to **Certificates** → Click **+**
2. Select **Apple Distribution** → Click **Continue**
3. Upload the CSR file (or generate a new one)
4. Download the certificate → Double-click to install in Keychain

### 3. Create Provisioning Profiles

#### Development Provisioning Profile

1. Go to **Profiles** → Click **+**
2. Select **iOS App Development** → Click **Continue**
3. Select your App ID (`com.sierrapainting.app`) → Click **Continue**
4. Select your development certificate → Click **Continue**
5. Select test devices → Click **Continue**
6. Name it: `Sierra Painting Development` → Click **Generate**
7. Download and double-click to install

#### App Store Provisioning Profile

1. Go to **Profiles** → Click **+**
2. Select **App Store** → Click **Continue**
3. Select your App ID → Click **Continue**
4. Select your distribution certificate → Click **Continue**
5. Name it: `Sierra Painting App Store` → Click **Generate**
6. Download and double-click to install

### 4. Register Devices (Optional for Development)

To test on physical devices:

1. Go to **Devices** → Click **+**
2. Enter device **Name** and **UDID**
   - Get UDID: Connect device → Finder/iTunes → Click on serial number
3. Click **Continue** → **Register**
4. Regenerate development provisioning profile to include new device

---

## Firebase iOS App Setup

### 1. Configure iOS App in Firebase

1. Log in to [Firebase Console](https://console.firebase.google.com)
2. Select **sierra-painting** project
3. Go to **Project Settings** (gear icon)
4. Scroll to **Your apps** section
5. Click **Add app** → Select **iOS**
6. Configure iOS app:
   - **Bundle ID**: `com.sierrapainting.app`
   - **App nickname**: Sierra Painting iOS (optional)
   - **App Store ID**: (leave blank until app is published)
7. Click **Register app**

### 2. Download GoogleService-Info.plist

1. In Firebase Console, click **Download GoogleService-Info.plist**
2. Save the file to your computer

### 3. Add GoogleService-Info.plist to Xcode

```bash
# Navigate to iOS project directory
cd ios

# Open Xcode workspace (not .xcodeproj!)
open Runner.xcworkspace
```

In Xcode:
1. Right-click **Runner** folder in Project Navigator
2. Select **Add Files to "Runner"...**
3. Navigate to downloaded `GoogleService-Info.plist`
4. ✅ Check **Copy items if needed**
5. ✅ Ensure **Target: Runner** is checked
6. Click **Add**

**Verify**: The file should appear in `ios/Runner/` directory and be visible in Xcode.

### 4. Configure APNs (Apple Push Notification service)

#### Generate APNs Authentication Key

1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Select **Keys** → Click **+**
4. Configure key:
   - **Key Name**: Sierra Painting APNs Key
   - ✅ Enable **Apple Push Notifications service (APNs)**
5. Click **Continue** → **Register**
6. Download the key file (`.p8`) - **Save it securely!**
   - ⚠️ You can only download it once
7. Note the **Key ID** (10 characters)
8. Note your **Team ID** (found in Membership section)

#### Upload APNs Key to Firebase

1. Go to Firebase Console → **Project Settings**
2. Select **Cloud Messaging** tab
3. Scroll to **iOS app configuration**
4. Click **Upload** under APNs Authentication Key
5. Upload your `.p8` key file
6. Enter **Key ID** and **Team ID**
7. Click **Upload**

**Verify**: APNs key should show as configured in Firebase Console.

---

## Build Configuration

### 1. Prepare iOS Build

Clean previous builds and install dependencies:

```bash
# Clean Flutter build artifacts
flutter clean

# Get Flutter dependencies
flutter pub get

# Install iOS dependencies via CocoaPods
cd ios
pod install
cd ..
```

**Expected output**: `ios/Podfile.lock` updated with all Firebase pods.

### 2. Configure Xcode Project

Open the Xcode workspace:

```bash
cd ios
open Runner.xcworkspace
```

#### Set Bundle Identifier

1. Select **Runner** project in Project Navigator
2. Select **Runner** target
3. Go to **General** tab
4. Verify **Bundle Identifier**: `com.sierrapainting.app`

#### Configure Signing

1. Go to **Signing & Capabilities** tab
2. Select **Automatically manage signing** (recommended)
   - **Team**: Select your Apple Developer team
   - Xcode will automatically provision certificates/profiles
3. Or **Manual signing**:
   - Uncheck **Automatically manage signing**
   - **Provisioning Profile**: Select appropriate profile
   - **Signing Certificate**: Select valid certificate

#### Configure Capabilities

Enable required capabilities:

1. Click **+ Capability** button
2. Add:
   - **Push Notifications** (for FCM)
   - **Background Modes** (check: Remote notifications)
   - **Sign In with Apple** (if using)

#### Set Deployment Target

1. Go to **General** tab
2. Set **Minimum Deployments**: iOS 12.0 or higher
   - Recommended: iOS 13.0+ for App Attest support

### 3. Set App Version

Update version in `pubspec.yaml`:

```yaml
version: 1.0.0+1
# Format: MAJOR.MINOR.PATCH+BUILD_NUMBER
# version: 1.0.1+2  (next release)
```

Build version is automatically synced to Xcode from pubspec.yaml.

### 4. Configure Build Settings (Optional)

In Xcode → **Build Settings** (search for these if needed):
- **Bitcode**: No (deprecated by Apple)
- **Swift Version**: 5.x (latest)
- **Optimization Level (Release)**: -O (optimize for speed)

---

## Build & Archive

### Option 1: Flutter Command Line (Recommended)

Build release version:

```bash
# Build iOS release (creates .app bundle, not ready for App Store)
flutter build ios --release

# Build with environment variables (if using .env file)
flutter build ios --release --dart-define-from-file=.env

# Build for specific configuration
flutter build ios --release --flavor production
```

**Output**: `build/ios/iphoneos/Runner.app`

⚠️ This creates a `.app` bundle, not an `.ipa` archive for App Store. You still need to use Xcode for archiving.

### Option 2: Xcode Archive (Required for App Store)

#### 1. Select Build Target

In Xcode:
1. Select **Any iOS Device** (Generic iOS Device) as build target
   - Do **NOT** select a simulator
   - Do **NOT** select a specific device
2. Verify **Runner** scheme is selected

#### 2. Clean Build Folder

1. **Product** → **Clean Build Folder** (⇧⌘K)
2. Wait for cleaning to complete

#### 3. Create Archive

1. **Product** → **Archive** (⌘B then archive)
2. Wait for build to complete (3-10 minutes)
3. Xcode Organizer will open automatically

**Build Errors?** See [Troubleshooting](#troubleshooting) section below.

#### 4. Validate Archive

In Xcode Organizer:
1. Select the archive
2. Click **Validate App**
3. Select distribution method: **App Store Connect**
4. Sign with: **Automatically manage signing** (or select manual profiles)
5. Click **Validate**
6. Wait for validation to complete
   - Should show ✅ No issues found

---

## App Store Connect Setup

### 1. Create App Record

1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Go to **My Apps** → Click **+** → **New App**
3. Configure:
   - **Platform**: iOS
   - **Name**: Sierra Painting
   - **Primary Language**: English (US)
   - **Bundle ID**: `com.sierrapainting.app` (from dropdown)
   - **SKU**: unique identifier (e.g., `sierra-painting-ios-001`)
   - **User Access**: Full Access
4. Click **Create**

### 2. Complete App Information

#### App Information

1. Go to **App Information** (left sidebar)
2. Fill required fields:
   - **Subtitle**: Brief tagline (30 characters max)
   - **Category**: Business (Primary), Productivity (Secondary)
   - **Content Rights**: Check if you own rights
   - **Privacy Policy URL**: Your privacy policy URL
   - **Support URL**: Your support/contact page URL

#### Pricing and Availability

1. Go to **Pricing and Availability**
2. Set **Price**: Free (or select price tier)
3. **Availability**: All territories (or select specific countries)

#### Age Rating

1. Go to **App Privacy** → **Age Rating**
2. Complete questionnaire
3. Expected rating: 4+ or 9+ depending on content

#### Privacy

1. Go to **App Privacy**
2. Click **Get Started**
3. Add data collection practices:
   - **Contact Info**: Email (for authentication)
   - **User Content**: Time entries, estimates, invoices
   - **Identifiers**: User ID
   - **Usage Data**: Analytics
4. For each data type:
   - ✅ Used for App Functionality
   - Link to account (if applicable)
5. **Save** and **Publish**

### 3. Prepare App Store Metadata

#### Screenshots

Required screenshot sizes (minimum 1 per size):
- **6.5" Display** (iPhone 14 Pro Max, 13 Pro Max): 1290 x 2796 pixels
- **5.5" Display** (iPhone 8 Plus): 1242 x 2208 pixels

Tips:
- Take screenshots on physical devices or simulators
- Use `flutter screenshot` command or Xcode simulator
- Show key features: Login, Time Clock, Estimates, Invoices
- Maximum 10 screenshots per localization

#### App Preview Videos (Optional)

- 15-30 seconds per video
- Same device sizes as screenshots
- Show app functionality in action

#### Description & Keywords

```
Description (4000 characters max):
Sierra Painting is a comprehensive business management app designed specifically for painting contractors. Track employee time, create professional estimates, manage invoices, and streamline your painting business operations.

Key Features:
• Employee Time Tracking - Clock in/out with GPS verification
• Professional Estimates - Create detailed quotes with line items
• Invoice Management - Generate and send invoices instantly
• Offline Support - Work without internet connectivity
• Real-time Sync - Automatic cloud synchronization
• Role-based Access - Admin, manager, and employee roles
• Firebase Integration - Secure cloud storage and authentication

Perfect for painting contractors who need reliable business management tools on the go.

Keywords (100 characters max, comma-separated):
painting,contractor,time clock,invoices,estimates,business,employee tracking
```

#### What's New in This Version

```
Version 1.0.0:
• Initial release
• Employee time tracking with GPS
• Estimate and invoice creation
• Offline-first architecture
• Role-based access control
• Firebase cloud sync
```

---

## Deployment to App Store

### TestFlight Distribution (Recommended First)

TestFlight allows beta testing before public release.

#### 1. Upload Build to App Store Connect

In Xcode Organizer:
1. Select your validated archive
2. Click **Distribute App**
3. Select **App Store Connect** → Click **Next**
4. Select **Upload** → Click **Next**
5. Distribution options:
   - ✅ **Include bitcode**: No (deprecated)
   - ✅ **Upload your app's symbols**: Yes (for crash reports)
   - ✅ **Manage Version and Build Number**: Automatically
6. Sign with: **Automatically manage signing**
7. Click **Upload**
8. Wait for upload to complete (5-15 minutes)

**Status**: Build will process in App Store Connect (~15-60 minutes)

#### 2. Enable TestFlight

1. Go to App Store Connect → **TestFlight** tab
2. Wait for build to finish processing (status: Ready to Submit)
3. Configure TestFlight info:
   - **Test Information**: What to test
   - **Feedback Email**: Your email for tester feedback
   - **Privacy Policy URL**: (if required)
4. Click **Save**

#### 3. Add Internal Testers

Internal testing (up to 100 users):
1. Go to **TestFlight** → **Internal Testing**
2. Click **+** next to Internal Testers
3. Add testers:
   - Enter name and email
   - They must have access to App Store Connect
4. Select build version to test
5. Testers receive email invitation immediately

#### 4. Add External Testers (Optional)

External testing (up to 10,000 users):
1. Go to **TestFlight** → **External Testing**
2. Create a new group: Click **+** → Name the group
3. Add testers by email (no App Store Connect access needed)
4. Select build to distribute
5. ⚠️ **Requires Beta App Review by Apple** (1-2 days)
6. Complete Beta App Review form:
   - Demo account credentials (if login required)
   - Testing instructions
   - Contact information
7. Submit for review

**Timeline**: Apple reviews within 24-48 hours.

#### 5. Testers Install via TestFlight

Testers:
1. Install **TestFlight** app from App Store
2. Open invitation email → Click **View in TestFlight**
3. Accept invitation → Install app
4. Provide feedback via TestFlight app

### Production App Store Release

After successful TestFlight testing:

#### 1. Submit for App Review

1. Go to App Store Connect → **App Store** tab
2. Click **+ Version or Platform** → **iOS**
3. Enter version number: `1.0.0`
4. Complete all required fields (if not done earlier)
5. Select build from TestFlight
6. Add **App Review Information**:
   - **Sign-in Required**: Yes
   - **Demo Account**:
     - Username: `demo@sierrapainting.app`
     - Password: `[secure password]`
   - **Contact Information**: Your email and phone
   - **Notes**: Any special instructions for reviewers
7. Click **Add for Review**

#### 2. Submit for Review

1. Review all information for accuracy
2. Click **Submit for Review**
3. Status changes to **Waiting for Review**

**Timeline**:
- **Waiting for Review**: 1-3 days
- **In Review**: 1-2 days
- **Pending Developer Release** or **Ready for Sale**: After approval

#### 3. Monitor Review Status

Check status in App Store Connect:
- **Waiting for Review**: In queue
- **In Review**: Apple is testing
- **Metadata Rejected**: Fix issues and resubmit
- **Rejected**: Address rejection reasons and resubmit
- **Pending Developer Release**: Approved, release manually
- **Ready for Sale**: Approved and released

#### 4. Release to App Store

If "Pending Developer Release":
1. Go to version details
2. Click **Release This Version**
3. App goes live within 24 hours

If "Automatically release":
- App releases automatically after approval

---

## Post-Deployment Verification

### 1. Download and Test

1. Search for "Sierra Painting" in App Store
2. Download and install the app
3. Test critical functionality:
   - ✅ App launches successfully
   - ✅ User can sign in with credentials
   - ✅ Push notifications work
   - ✅ Core features: Clock in/out, estimates, invoices
   - ✅ Offline mode works as expected
   - ✅ Data syncs to Firebase

### 2. Monitor Crashlytics

Check Firebase Console → **Crashlytics**:
- Monitor crash-free rate (target: > 99%)
- Review crash reports
- Verify symbolication is working (readable stack traces)

### 3. Monitor Performance

Check Firebase Console → **Performance**:
- App startup time (target: < 3s)
- Screen rendering times
- Network request latency

### 4. Verify Push Notifications

Test FCM push notifications:
```bash
# Send test notification via Firebase Console
# Console → Cloud Messaging → Send test message
```

Verify:
- ✅ Notification received on iOS device
- ✅ Tapping notification opens app
- ✅ Notification payload handled correctly

### 5. Test Stripe Integration (If Enabled)

If payment features are enabled:
- ✅ Payment sheet displays correctly
- ✅ Test mode transactions work
- ✅ Production mode (after enabling) processes real payments
- ✅ Receipts are generated

### 6. User Feedback

Monitor:
- App Store reviews and ratings
- Support tickets and user feedback
- Firebase Analytics for usage patterns
- Crash reports and error logs

---

## Troubleshooting

### Common Issues

#### Missing GoogleService-Info.plist

**Error**: `'GoogleService-Info.plist' not found`

**Solution**:
1. Download `GoogleService-Info.plist` from Firebase Console
2. Add to Xcode project in `ios/Runner/` directory
3. Ensure "Copy items if needed" is checked
4. Verify target is set to "Runner"
5. Clean build: Product → Clean Build Folder
6. Rebuild

#### Missing Provisioning Profile

**Error**: `No provisioning profile found`

**Solution**:
1. Open Xcode → Preferences → Accounts
2. Select your Apple ID → Download Manual Profiles
3. Or enable "Automatically manage signing" in target settings
4. Regenerate provisioning profile in Apple Developer Portal
5. Download and install new profile

#### Push Notification Setup Issues

**Error**: Notifications not received

**Solution**:
1. Verify APNs key is uploaded to Firebase Console
2. Check Push Notifications capability is enabled in Xcode
3. Verify Background Modes → Remote notifications is checked
4. Test with Firebase Console test message
5. Check device notification permissions: Settings → Sierra Painting → Notifications

#### Signing Issues

**Error**: `Code signing failed` or `Signing identity not found`

**Solution**:
1. Verify Apple Developer account is active (paid subscription)
2. Check certificate is valid and installed in Keychain
3. Verify bundle identifier matches: `com.sierrapainting.app`
4. Check Team ID matches in Xcode and Apple Developer Portal
5. Regenerate certificates if expired
6. Try automatic signing first before manual

#### Archive Build Fails

**Error**: Build fails when archiving

**Solution**:
1. Ensure CocoaPods dependencies are installed: `cd ios && pod install`
2. Clean build folder: Product → Clean Build Folder
3. Close Xcode and delete derived data:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
4. Reopen Xcode workspace (not .xcodeproj)
5. Select "Any iOS Device" as target (not simulator)
6. Archive again

#### App Store Connect Upload Fails

**Error**: Upload rejected or fails

**Solution**:
1. Verify Xcode is up to date (latest version)
2. Check Apple Developer account is in good standing
3. Ensure bundle ID matches registered App ID
4. Verify all required capabilities are configured
5. Check for Apple system status: https://developer.apple.com/system-status/
6. Try uploading with Transporter app instead

#### App Rejected in Review

**Rejection reasons** (common):
- Missing demo account credentials → Add in App Review Information
- Privacy policy missing → Add valid URL
- App crashes on launch → Fix crashes and resubmit
- Missing required metadata → Complete all App Store fields
- Guideline violations → Address specific feedback from Apple

**Solution**:
1. Read rejection reason carefully in Resolution Center
2. Address all issues mentioned
3. Increment build number in pubspec.yaml
4. Create new archive
5. Upload new build
6. Reply to Apple in Resolution Center
7. Resubmit for review

#### CocoaPods Issues

**Error**: `pod install` fails

**Solution**:
```bash
# Update CocoaPods
sudo gem install cocoapods

# Update pod repo
pod repo update

# Clean pod cache
pod cache clean --all

# Remove and reinstall
cd ios
rm -rf Pods Podfile.lock
pod install

# If still fails, try deintegrate and reinstall
pod deintegrate
pod install
```

---

## Bundle Identifier Note

⚠️ **Important**: The problem statement mentioned bundle ID `com.sierra.painting`, but the Firebase configuration and repository use **`com.sierrapainting.app`**. 

**Recommendation**: Use **`com.sierrapainting.app`** consistently across:
- Apple Developer Portal (App ID)
- Xcode project settings
- Firebase iOS app configuration
- GoogleService-Info.plist

If you need to change the bundle ID:
1. Update in Firebase Console (add new iOS app)
2. Download new GoogleService-Info.plist
3. Update in Xcode project settings
4. Update App ID in Apple Developer Portal
5. Regenerate provisioning profiles

---

## Additional Resources

### Documentation
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [App Store Connect Help](https://help.apple.com/app-store-connect/)
- [Flutter iOS Deployment](https://docs.flutter.dev/deployment/ios)
- [Firebase iOS Setup](https://firebase.google.com/docs/ios/setup)
- [TestFlight Documentation](https://developer.apple.com/testflight/)

### Tools
- [Xcode](https://developer.apple.com/xcode/) - IDE for iOS development
- [Transporter](https://apps.apple.com/app/transporter/id1450874784) - Upload builds to App Store Connect
- [Apple Configurator](https://apps.apple.com/app/apple-configurator-2/id1037126344) - Manage devices and provisioning
- [Firebase Console](https://console.firebase.google.com) - Manage Firebase services

### Support
- [Apple Developer Forums](https://developer.apple.com/forums/)
- [Flutter Community](https://flutter.dev/community)
- [Firebase Support](https://firebase.google.com/support)

---

## Related Documentation

- **[Android Staged Rollout](./ANDROID_STAGED_ROLLOUT.md)**: Android deployment process
- **[Deployment Checklist](./deployment_checklist.md)**: General deployment procedures
- **[App Check Setup](./APP_CHECK.md)**: Firebase App Check configuration
- **[Rollout & Rollback](./rollout-rollback.md)**: Deployment strategies

---

**Last Updated**: 2024-10-04  
**Document Owner**: Engineering Team  
**Review Cadence**: Before each iOS release
