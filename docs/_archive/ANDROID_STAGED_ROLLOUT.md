# Android Staged Rollout Setup

This document describes how to integrate staged rollout for Android releases via Google Play Store.

## Overview

The canary deployment strategy for Android apps uses Google Play Store's staged rollout feature to progressively release to a percentage of users:

- **Stage 1**: 10% → Monitor 24h → Gate
- **Stage 2**: 50% → Monitor 24h → Gate  
- **Stage 3**: 100% → Full release

## Option 1: Manual Play Console (Simple)

### Initial Setup

1. Build and sign your release AAB:
   ```bash
   flutter build appbundle --release
   ```

2. Upload to Play Console:
   - Go to https://play.google.com/console
   - Select your app
   - Navigate to Release → Production
   - Click "Create new release"
   - Upload `app-release.aab`

### Staged Rollout Process

1. **Start at 10%**:
   - In the release form, select "Staged rollout"
   - Set percentage to 10%
   - Submit for review
   - Wait for Google approval (typically 1-2 days)

2. **Monitor for 24 hours**:
   - Check crashlytics for crash-free rate
   - Monitor Play Console for ANR rate
   - Review user ratings and feedback
   - Check Firebase Performance Monitoring

3. **Promote to 50%**:
   - Return to Play Console → Production
   - Click "Increase rollout" on active release
   - Change percentage to 50%
   - Monitor for another 24 hours

4. **Promote to 100%**:
   - Return to Play Console → Production
   - Click "Complete rollout"
   - Release becomes available to all users

### Rollback

If issues are detected during rollout:

1. **Halt Rollout**:
   - Play Console → Production
   - Click "Halt rollout" on active release
   - This stops new users from getting the update

2. **Create Rollback Release** (if needed):
   - Checkout previous stable tag: `git checkout v1.x.x`
   - Build: `flutter build appbundle --release`
   - Upload new release with incremented version code
   - Set to 100% rollout

## Option 2: Fastlane (Automated)

### Installation

1. Install Fastlane:
   ```bash
   # macOS
   brew install fastlane
   
   # or via RubyGems
   gem install fastlane
   ```

2. Initialize Fastlane:
   ```bash
   cd android
   fastlane init
   ```

3. Configure Google Play credentials:
   - Follow: https://docs.fastlane.tools/getting-started/android/setup/
   - Create service account in Google Cloud Console
   - Download JSON key file
   - Store as `android/fastlane/google-play-key.json` (add to .gitignore)

### Fastfile Configuration

Create `android/fastlane/Fastfile`:

```ruby
default_platform(:android)

platform :android do
  desc "Deploy a new version to Google Play (Staged Rollout)"
  lane :deploy_staged do |options|
    gradle(
      task: "bundle",
      build_type: "Release"
    )
    
    upload_to_play_store(
      track: 'production',
      rollout: '0.1',  # 10% initial rollout
      aab: '../build/app/outputs/bundle/release/app-release.aab',
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end
  
  desc "Promote staged rollout to next percentage"
  lane :promote_staged do |options|
    percentage = options[:percentage] || 0.5  # Default to 50%
    
    upload_to_play_store(
      track: 'production',
      rollout: percentage.to_s,
      skip_upload_apk: true,
      skip_upload_aab: true,
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end
  
  desc "Complete rollout to 100%"
  lane :complete_rollout do
    upload_to_play_store(
      track: 'production',
      rollout: '1.0',  # 100%
      skip_upload_apk: true,
      skip_upload_aab: true,
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end
  
  desc "Halt staged rollout"
  lane :halt_rollout do
    upload_to_play_store(
      track: 'production',
      rollout: '0.0',  # Halt
      skip_upload_apk: true,
      skip_upload_aab: true,
      skip_upload_metadata: true,
      skip_upload_images: true,
      skip_upload_screenshots: true
    )
  end
end
```

### Usage

```bash
# Deploy at 10%
cd android
fastlane deploy_staged

# Promote to 50%
fastlane promote_staged percentage:0.5

# Promote to 100%
fastlane complete_rollout

# Halt rollout
fastlane halt_rollout
```

### GitHub Actions Integration

Add to `.github/workflows/release.yml`:

```yaml
  deploy_android_staged:
    name: Deploy Android (10% Staged)
    runs-on: ubuntu-latest
    needs: [build_flutter_release]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.0'
          bundler-cache: true
          working-directory: android
      
      - name: Setup Fastlane
        run: |
          cd android
          gem install fastlane
          bundle install
      
      - name: Deploy to Play Store (10%)
        env:
          GOOGLE_PLAY_KEY_JSON: ${{ secrets.GOOGLE_PLAY_KEY_JSON }}
        run: |
          cd android
          echo "$GOOGLE_PLAY_KEY_JSON" > fastlane/google-play-key.json
          fastlane deploy_staged
```

## Option 3: Gradle Play Publisher

### Installation

Add to `android/app/build.gradle`:

```gradle
plugins {
    id 'com.android.application'
    id 'com.github.triplet.play' version '3.8.4'
}

play {
    serviceAccountCredentials = file("../fastlane/google-play-key.json")
    track = "production"
    releaseStatus = "draft"
    defaultToAppBundles = true
}
```

### Usage

```bash
# Build and upload at 10% rollout
cd android
./gradlew publishBundle \
  --track production \
  --release-status inProgress \
  --user-fraction 0.1

# Promote to 50%
./gradlew promoteReleaseArtifact \
  --track production \
  --user-fraction 0.5

# Promote to 100%
./gradlew promoteReleaseArtifact \
  --track production \
  --release-status completed
```

## Monitoring and Gates

Before promoting each stage, verify:

### Crash-Free Rate
```
Target: ≥ 99.5%
Check: Firebase Crashlytics Dashboard
```

### ANR Rate
```
Target: < 0.5%
Check: Play Console → Vitals → ANRs
```

### Performance
```
Target: App start P95 < 2.5s
Check: Firebase Performance Monitoring
```

### User Feedback
```
Target: 1-star reviews < 5%
Check: Play Console → Reviews
```

## Rollback Procedure

### Quick Halt
```bash
# Via Fastlane
cd android
fastlane halt_rollout

# Or manually in Play Console
# → Production → Active release → "Halt rollout"
```

### Full Rollback
1. Checkout previous stable version:
   ```bash
   git checkout v1.x.x
   ```

2. Increment version code in `android/app/build.gradle`:
   ```gradle
   versionCode 124  // Previous was 123
   versionName "1.2.3-rollback"
   ```

3. Build and deploy:
   ```bash
   flutter build appbundle --release
   cd android
   fastlane deploy_staged
   fastlane complete_rollout  # 100% immediately
   ```

## Best Practices

1. **Always tag releases**: Tag git commits with version for easy rollback
2. **Monitor actively**: Set up alerts for crash rate, ANR, and performance
3. **Document issues**: Keep notes on why/when rollbacks occur
4. **Test internally**: Use internal testing track before production
5. **Communicate**: Notify team when starting/completing staged rollouts

## References

- [Play Console Staged Rollout](https://support.google.com/googleplay/android-developer/answer/6346149)
- [Fastlane Documentation](https://docs.fastlane.tools/actions/upload_to_play_store/)
- [Gradle Play Publisher](https://github.com/Triple-T/gradle-play-publisher)
- [Flutter Release Guide](https://docs.flutter.dev/deployment/android)
