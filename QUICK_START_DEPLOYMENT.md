# Quick Start: v0.0.15 Deployment Gates

**Time Required**: 90 minutes
**Status**: Ready to execute
**Location**: `/home/j-p-v/AppDev/Sierra-Painting-v1`

---

## 🚀 COPY-PASTE COMMANDS (Execute in Order)

### Step 1: Setup Staging Environment (30 min)
```bash
cd /home/j-p-v/AppDev/Sierra-Painting-v1

# Run automated setup
./scripts/setup-staging-firebase.sh

# Follow prompts and verify:
# - Firebase project created/confirmed
# - firebase_options_staging.dart generated
# - .firebaserc updated
# - .env.staging created

# MANUAL: Get ReCAPTCHA key
# 1. Go to: https://console.firebase.google.com/project/sierra-painting-staging/appcheck
# 2. Add Web app
# 3. Enable ReCAPTCHA v3
# 4. Copy site key
# 5. Add to .env.staging:
#    RECAPTCHA_V3_SITE_KEY=<your-key-here>
```

### Step 2: Run Security Tests (15 min)
```bash
# Install test dependencies
cd tests/rules
npm install
cd ../..

# Run comprehensive security validation
./scripts/test-firestore-rules.sh

# Expected: All tests passing
# If any fail: STOP and review failures
```

### Step 3: Configure Remote Config (10 min)
```bash
# Switch to staging
firebase use staging

# Set all flags (safe defaults - ALL OFF)
firebase remoteconfig:set global_panic false
firebase remoteconfig:set panic_disable_new_ui true
firebase remoteconfig:set ux_animations_enabled false
firebase remoteconfig:set ux_reduce_motion_default true
firebase remoteconfig:set shimmer_loaders_enabled false
firebase remoteconfig:set lottie_animations_enabled false
firebase remoteconfig:set telemetry_enabled false
firebase remoteconfig:set offline_queue_v2_enabled false
firebase remoteconfig:set audit_trail_enabled false
firebase remoteconfig:set smart_forms_enabled false
firebase remoteconfig:set kpi_drill_down_enabled false
firebase remoteconfig:set conflict_detection_enabled false
firebase remoteconfig:set haptic_feedback_enabled false

# Verify
firebase remoteconfig:get

# Deploy rules and indexes
firebase deploy --only firestore:rules,firestore:indexes
```

### Step 4: Build for Mobile (10 min)
```bash
# Android
flutter build apk --dart-define=FLAVOR=staging

# iOS (Mac only)
flutter build ios --dart-define=FLAVOR=staging

# Note APK location for testing:
# build/app/outputs/flutter-apk/app-release.apk
```

### Step 5: Device Testing (30 min)
```
MANUAL TESTING REQUIRED:

Install APK/IPA on 3 devices:
1. Low-tier:  Android 8 / iPhone 7 (2GB RAM)
2. Mid-tier:  Android 12 / iPhone 11 (4GB RAM)
3. High-tier: Android 14 / iPhone 15 (8GB RAM)

For each device, verify:
[ ] App launches without crash
[ ] Startup time < 2.5s (mid-tier)
[ ] Battery saver detection works (check logs)
[ ] Feature flags load successfully
[ ] No ANR/freeze warnings
[ ] Navigate to /admin/feature-flags works (if admin)

If ANY device crashes: STOP - NO-GO
```

### Step 6: Backup & Rollback (5 min)
```bash
# Create pre-deployment backup
./scripts/pre-deploy-backup.sh --staging

# Verify backup created
ls -la backups/

# Test rollback (dry run)
./scripts/rollback-v0015.sh --staging --dry-run

# Verify execution completes in < 2 minutes
```

---

## ✅ GATE PASS/FAIL CHECKLIST

Quick verification after each step:

### ✅ Gate 1: Environment Parity
- [ ] `firebase_options_staging.dart` exists
- [ ] `.firebaserc` has staging alias
- [ ] `.env.staging` has ReCAPTCHA key
- [ ] App launches with: "App Flavor: Staging"

### ✅ Gate 2: Rules Hardening
- [ ] Test script completes successfully
- [ ] All 20+ tests passing
- [ ] 0 failures reported
- [ ] "Security verification complete" message shown

### ✅ Gate 3: Consent & Telemetry
- [x] Already validated (21 tests passing)
- [x] ConsentManager integrated
- [x] PIISanitizer active

### ✅ Gate 4: Remote Config
- [ ] All 12 flags configured
- [ ] All flags show in `firebase remoteconfig:get`
- [ ] Rules and indexes deployed
- [ ] No deployment errors

### ✅ Gate 5: Device Testing
- [ ] 0 crashes on launch (all devices)
- [ ] Battery detection logs visible
- [ ] Feature flags fetch successful
- [ ] Cold start < 2.5s (mid-tier)

### ✅ Gate 6: Rollback Ready
- [ ] Backup folder created with timestamp
- [ ] Contains remoteconfig JSON
- [ ] Dry-run completes without errors
- [ ] Execution time < 2 minutes

---

## 🚨 FAILURE RESPONSES

### If Security Tests Fail
```bash
# Review failure details in console output
# Common issues:
# - Firestore emulator not running
# - Rules file syntax error
# - Test dependencies not installed

# Fix and retry:
./scripts/test-firestore-rules.sh
```

### If Device Crashes
```bash
# Collect crash logs
adb logcat > crash-log-$(date +%Y%m%d-%H%M).txt  # Android
# iOS: Xcode Devices → View Device Logs

# STOP deployment - NO-GO
# Create issue with:
# - Device specs
# - Crash stack trace
# - Steps to reproduce
```

### If Rollback Fails
```bash
# Manual rollback:
firebase use staging
firebase remoteconfig:set global_panic true
firebase remoteconfig:set panic_disable_new_ui true
firebase hosting:clone sierra-painting-staging:live rollback

# Document failure and create fix
```

---

## ⏰ TIMING CHECKPOINTS

| Time | Checkpoint | Expected Status |
|------|-----------|-----------------|
| T+0 | Start | Begin staging setup |
| T+30 | Gate 1 | Environment ready |
| T+45 | Gate 2 | Security tests passing |
| T+55 | Gate 4 | Remote Config configured |
| T+65 | Builds | APK/IPA ready |
| T+85 | Gate 5 | Device testing complete |
| T+90 | Gate 6 | Backup & rollback verified |
| T+90 | **DECISION** | **GO/NO-GO for staging** |

---

## 📊 SUCCESS CRITERIA

### Required for GO Decision
- [ ] All 6 gates passed
- [ ] Total execution time < 2 hours
- [ ] 0 critical failures
- [ ] Rollback proven working
- [ ] Backup created successfully

### Automatic NO-GO Triggers
- [ ] Any security test fails
- [ ] Crash on any device
- [ ] Cross-tenant data leak
- [ ] Rollback script errors
- [ ] PII found in test logs

---

## 🎯 AFTER GATES PASS

### Immediate Actions
```bash
# Tag current version
git tag v0.0.15-ready-for-staging
git push --tags

# Document results
echo "Gate execution completed at $(date)" >> gate-completion.log
echo "All gates: PASS" >> gate-completion.log
```

### Next Steps
1. Schedule staging deployment for tomorrow
2. Create deployment plan document
3. Notify stakeholders
4. Prepare 90-minute smoke test checklist

---

## 📞 QUICK REFERENCE

**Scripts**:
- Setup: `./scripts/setup-staging-firebase.sh`
- Security Tests: `./scripts/test-firestore-rules.sh`
- Backup: `./scripts/pre-deploy-backup.sh --staging`
- Rollback: `./scripts/rollback-v0015.sh --staging --dry-run`

**Key Files**:
- Checklist: `PRE_FLIGHT_CHECKLIST.md`
- Readiness: `DEPLOYMENT_READINESS_v0.0.15.md`
- This Guide: `QUICK_START_DEPLOYMENT.md`

**Commands**:
- Check flavor: `flutter run --dart-define=FLAVOR=staging -d chrome`
- Build staging: `flutter build web --dart-define=FLAVOR=staging`
- Switch project: `firebase use staging`

---

*Quick Start Guide*
*Estimated Total Time: 90 minutes*
*Last Updated: 2025-10-16*
