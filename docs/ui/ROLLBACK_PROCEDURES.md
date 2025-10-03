# Rollback Procedures

This document outlines procedures for safely rolling back changes in case of issues.

## Table of Contents

1. [Quick Rollback Checklist](#quick-rollback-checklist)
2. [Feature Flag Rollback](#feature-flag-rollback)
3. [Code Rollback](#code-rollback)
4. [Database Rollback](#database-rollback)
5. [Monitoring & Validation](#monitoring--validation)

---

## Quick Rollback Checklist

When you need to rollback changes immediately:

- [ ] **1. Disable Feature Flag** (fastest, no deployment)
- [ ] **2. Monitor Metrics** (verify issue is contained)
- [ ] **3. Communicate** (notify team and users if needed)
- [ ] **4. Investigate Root Cause** (why did it fail?)
- [ ] **5. Plan Fix** (code change, config change, or permanent disable)

---

## Feature Flag Rollback

### Why Feature Flags?

Feature flags allow instant rollback without code deployment:
- Turn off problematic features in seconds
- Granular control (e.g., disable for specific users)
- No app store approval needed
- No user action required

### Available Feature Flags

Location: `lib/core/services/feature_flag_service.dart`

| Flag | Purpose | Default | Rollback Impact |
|------|---------|---------|-----------------|
| `feature_b1_clock_in_enabled` | Clock in functionality | ON | Users can't clock in |
| `feature_b2_clock_out_enabled` | Clock out functionality | ON | Users can't clock out |
| `feature_b3_jobs_today_enabled` | Jobs today view | ON | Jobs view hidden |
| `feature_c1_create_quote_enabled` | Quote creation | OFF | Quote creation disabled |
| `feature_c3_mark_paid_enabled` | Mark invoice paid | OFF | Can't mark paid |
| `feature_c5_stripe_checkout_enabled` | Stripe payments | OFF | Stripe disabled |
| `offline_mode_enabled` | Offline queue | ON | No offline support |
| `gps_tracking_enabled` | GPS location | ON | No location tracking |

### How to Disable a Feature Flag

#### Option 1: Firebase Console (Recommended)

1. Open [Firebase Console](https://console.firebase.google.com)
2. Navigate to your project
3. Go to **Remote Config**
4. Find the feature flag (e.g., `feature_b1_clock_in_enabled`)
5. Change value from `true` to `false`
6. Click **Publish Changes**
7. Changes propagate within 1 minute

#### Option 2: Firebase CLI

```bash
# Get current config
firebase remoteconfig:get -o config.json

# Edit config.json to change flag value
# "feature_b1_clock_in_enabled": { "defaultValue": { "value": "false" } }

# Upload modified config
firebase remoteconfig:publish config.json
```

#### Option 3: REST API

```bash
curl -X PATCH \
  https://firebaseremoteconfig.googleapis.com/v1/projects/YOUR_PROJECT_ID/remoteConfig \
  -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "Content-Type: application/json" \
  -d '{
    "parameters": {
      "feature_b1_clock_in_enabled": {
        "defaultValue": {
          "value": "false"
        }
      }
    }
  }'
```

### Verification

After disabling a flag:

1. **Wait 1-5 minutes** for Remote Config to propagate
2. **Force refresh** in the app (if implemented)
3. **Verify behavior** by testing the feature
4. **Check metrics** to confirm rollback

```dart
// Force refresh Remote Config (if needed)
await FeatureFlagService().refresh();

// Verify flag is disabled
final isEnabled = FeatureFlagService().isEnabled('feature_b1_clock_in_enabled');
debugPrint('Clock in enabled: $isEnabled'); // Should print: false
```

---

## Code Rollback

### When Feature Flags Aren't Enough

If you need to rollback code changes:
- Performance regression (high CPU, memory leaks)
- Crashes that can't be fixed quickly
- Breaking changes to critical flows
- Security vulnerabilities

### Git Rollback Steps

#### 1. Identify the Bad Commit

```bash
# View recent commits
git log --oneline -10

# Example output:
# abc1234 Add new invoice screen
# def5678 Fix clock in validation
# 789ghij Update theme colors
```

#### 2. Revert the Commit

**Option A: Revert (Recommended - creates new commit)**
```bash
# Revert a specific commit
git revert abc1234

# Revert multiple commits
git revert abc1234 def5678

# Push the revert
git push origin main
```

**Option B: Reset (Caution - rewrites history)**
```bash
# Reset to previous commit (use only if not pushed)
git reset --hard def5678

# Force push (dangerous!)
git push --force origin main
```

#### 3. Create Hotfix Branch

For production issues:

```bash
# Create hotfix branch from main
git checkout -b hotfix/revert-invoice-screen main

# Revert the problematic commit
git revert abc1234

# Push hotfix branch
git push origin hotfix/revert-invoice-screen

# Create pull request and merge immediately
```

#### 4. Deploy Rollback

```bash
# Build new version
flutter build apk --release
flutter build ios --release

# Deploy to Firebase
firebase hosting:deploy

# Or trigger CI/CD pipeline
git push origin main
```

### App Store Rollback

If bad code is already in production:

#### Android (Google Play)

1. Open [Google Play Console](https://play.google.com/console)
2. Go to **Production** → **Releases**
3. Find the previous working version
4. Click **Promote** to make it active
5. Or create a new release with reverted code

**Note**: Rollback is immediate for new installs, but existing users won't auto-downgrade.

#### iOS (App Store)

**Bad news**: Apple doesn't support rollback.

**Options**:
1. Submit an emergency hotfix (24-48 hour review)
2. Request expedited review (explain critical bug)
3. Use Firebase Remote Config to disable features

---

## Database Rollback

### Firestore Rollback

Firestore doesn't have built-in rollback. **Be careful!**

#### Backup Before Changes

```bash
# Export Firestore data
gcloud firestore export gs://your-backup-bucket/backup-$(date +%Y%m%d)

# Import from backup (if needed)
gcloud firestore import gs://your-backup-bucket/backup-20250101
```

#### Schema Changes

If you added new fields or collections:

**Safe approach**:
- New fields are optional (don't break old versions)
- Old app versions ignore new fields
- New app versions handle missing fields

**Example**:
```dart
// Old version
final name = doc.data()?['name'] as String?;

// New version (backward compatible)
final name = doc.data()?['name'] as String?;
final displayName = doc.data()?['displayName'] as String? ?? name; // Fallback
```

### Cloud Functions Rollback

#### Rollback to Previous Version

```bash
# List function versions
gcloud functions list --filter="name:clockIn"

# Rollback to previous version
firebase deploy --only functions:clockIn --force

# Or specify exact version
gcloud functions deploy clockIn --source=./functions --runtime=nodejs18
```

#### Disable Function

```bash
# Delete function (extreme)
gcloud functions delete clockIn

# Or comment out export in functions/src/index.ts
# export { clockIn } from './timeclock/clockIn';
```

---

## Monitoring & Validation

### Pre-Rollback Checklist

Before rolling back, verify the issue:

1. **Check Error Rates**: Is it a real issue or isolated?
2. **Review User Reports**: How many users affected?
3. **Test Locally**: Can you reproduce the issue?
4. **Check Metrics**: Performance, crashes, errors

### Post-Rollback Checklist

After rolling back, verify success:

- [ ] **Error rate decreased** (check Firebase Crashlytics)
- [ ] **Users can access features** (test manually)
- [ ] **Metrics returned to normal** (check dashboards)
- [ ] **No new issues introduced** (monitor for 1 hour)

### Metrics to Monitor

#### Immediate (1-5 minutes)
- Error rate
- Crash rate
- API success rate

#### Short-term (1 hour)
- User session length
- Feature usage rates
- Customer support tickets

#### Long-term (24 hours)
- Daily active users
- Retention rate
- Revenue impact

### Monitoring Tools

```dart
// Log rollback event
telemetryService.logEvent('FEATURE_ROLLED_BACK', {
  'feature': 'clock_in',
  'reason': 'high_error_rate',
  'affectedUsers': estimatedCount,
  'rollbackMethod': 'feature_flag',
});
```

---

## Communication Plan

### Who to Notify

**Immediate**:
- Engineering team (Slack/Teams)
- Product manager
- On-call engineer

**If User-Facing**:
- Customer support team
- Marketing (if announced feature)
- Affected users (in-app message)

### Communication Template

```
🚨 ROLLBACK ALERT

Feature: Clock In (feature_b1_clock_in_enabled)
Status: DISABLED
Reason: High error rate (15% of clock-ins failing)
Impact: Users cannot clock in via app
Workaround: Use manual time entry
ETA: Fix in 2-4 hours
Owner: @engineer-name

Timeline:
- 10:00 AM: Issue detected
- 10:05 AM: Feature flag disabled
- 10:10 AM: Metrics confirmed stable
- Next: Investigating root cause

Updates: This channel
```

---

## Root Cause Analysis

After rolling back, investigate:

### Questions to Answer

1. **What happened?**
   - Exact error messages
   - Steps to reproduce
   - Affected users/devices

2. **Why did it happen?**
   - Code bug?
   - Config issue?
   - Infrastructure problem?
   - Deployment issue?

3. **Why wasn't it caught?**
   - Missing test?
   - Test didn't cover edge case?
   - Works in dev but not prod?

4. **How can we prevent it?**
   - Add test coverage
   - Improve staging environment
   - Better monitoring
   - Gradual rollout

### Post-Mortem Template

```markdown
# Post-Mortem: Clock In Feature Rollback

## Summary
Clock in feature was rolled back due to 15% error rate.

## Timeline
- 10:00 AM: Issue detected by monitoring
- 10:05 AM: Feature flag disabled
- 10:10 AM: Verified stable
- 12:00 PM: Fix deployed
- 02:00 PM: Feature re-enabled

## Root Cause
Missing null check for GPS coordinates. When GPS was disabled,
app crashed attempting to clock in.

## Impact
- 150 users affected
- 45 minutes of downtime
- 12 support tickets

## What Went Well
- Feature flag allowed instant rollback
- Monitoring detected issue quickly
- Team responded within 5 minutes

## What Could Be Improved
- Add test for GPS disabled scenario
- Better error handling for missing GPS
- Gradual rollout (10% → 50% → 100%)

## Action Items
- [ ] Add GPS disabled test (@engineer)
- [ ] Implement gradual rollout (@pm)
- [ ] Update error handling guide (@tech-lead)
```

---

## Gradual Rollout (Prevent Rollbacks)

### Canary Deployment

Release to small percentage of users first:

```dart
// In Remote Config, set conditions
{
  "feature_b1_clock_in_enabled": {
    "conditions": [
      {
        "name": "canary_users",
        "condition": "user_percent <= 10",
        "value": "true"
      }
    ],
    "defaultValue": "false"
  }
}
```

### Rollout Strategy

1. **Day 1**: 10% of users
2. **Day 2**: 25% of users (if metrics good)
3. **Day 3**: 50% of users
4. **Day 4**: 100% of users

If issues arise at any stage, rollback is limited to that percentage.

---

## Quick Reference

### Emergency Contacts

- **On-Call Engineer**: [slack channel]
- **Product Manager**: [name]
- **DevOps**: [contact]

### Emergency Commands

```bash
# Disable feature flag
firebase remoteconfig:get -o config.json
# Edit config.json
firebase remoteconfig:publish config.json

# Revert code
git revert [commit-hash]
git push origin main

# Check error rate
# Visit: https://console.firebase.google.com/project/YOUR_PROJECT/crashlytics
```

### Decision Tree

```
Issue detected
  ├─ Affects < 5% users → Monitor, fix in normal cycle
  ├─ Affects 5-20% users → Disable feature flag
  └─ Affects > 20% users → Emergency rollback + all-hands

Critical bug (security, data loss)
  └─ Immediate rollback + incident response
```

---

**Last Updated**: 2025-10-03  
**Review**: After each rollback, update this document  
**Owner**: Engineering Team
