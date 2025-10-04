# Rollout & Rollback Strategy

> **Purpose**: Deployment strategy, canary rollout procedures, and rollback plans for Sierra Painting
>
> **Last Updated**: 2024
>
> **Status**: Current (v2.0.0-refactor)

---

## Overview

This document defines the deployment strategy for Sierra Painting, including:
- Staged rollouts with canary cohorts
- Feature flag management
- Rollback procedures
- Monitoring and success criteria

---

## Deployment Environments

### 1. Development (Local)

**Purpose**: Local development and testing

**Configuration**:
- Firebase emulators (Auth, Firestore, Functions, Storage)
- Local Flutter debug build

**Access**: All developers

**Deployment**: Manual (`firebase emulators:start`)

**Data**: Synthetic test data

---

### 2. Staging

**Purpose**: Integration testing and QA

**Configuration**:
- Firebase project: `sierra-painting-staging`
- Branch: `main`
- Flutter debug/profile builds

**Access**: Development team, QA team

**Deployment**: 
- Automatic on push to `main`
- Via GitHub Actions (`.github/workflows/ci.yml`)

**Data**: Synthetic test data, anonymized production data

**URL**: N/A (mobile app), Cloud Functions: `https://us-central1-sierra-painting-staging.cloudfunctions.net`

---

### 3. Production

**Purpose**: Live customer-facing application

**Configuration**:
- Firebase project: `sierra-painting-prod`
- Tags: `v*` (e.g., `v1.0.0`, `v1.1.0`)
- Flutter release builds (APK/IPA)

**Access**: All users

**Deployment**:
- Manual trigger after staging validation
- Tag creation triggers build via GitHub Actions
- Manual app store submission (Android Play Store, Apple App Store)

**Data**: Live production data

**URL**: N/A (mobile app), Cloud Functions: `https://us-central1-sierra-painting-prod.cloudfunctions.net`

---

## Feature Flag Strategy

### Flag Types

#### 1. Development Flags
- **Purpose**: Hide incomplete features
- **Default**: `false`
- **Audience**: Developers only (via config override)
- **Example**: `feature_new_scheduler_enabled`

#### 2. Release Flags
- **Purpose**: Control feature rollout
- **Default**: `false` initially, `true` after validation
- **Audience**: Canary → stable cohorts
- **Example**: `feature_c3_mark_paid_enabled`

#### 3. Operational Flags
- **Purpose**: Runtime behavior control
- **Default**: `true` (safe defaults)
- **Audience**: All users
- **Example**: `offline_mode_enabled`, `gps_tracking_enabled`

#### 4. Kill Switches
- **Purpose**: Emergency feature disable
- **Default**: `true`
- **Audience**: All users
- **Example**: `stripe_payments_enabled`

---

### Flag Management

**Location**: Firebase Remote Config

**Update Process**:
1. Update flag in Firebase Console
2. Publish changes
3. Apps fetch new config (1-hour cache, or manual refresh)

**Client Defaults**: `lib/core/services/feature_flag_service.dart`

**Testing**: Override flags in emulator via Remote Config console

---

## Rollout Strategy

### Phase 1: Internal Testing (0-5%)

**Duration**: 1-3 days

**Audience**:
- Development team
- Internal beta testers

**Actions**:
1. Deploy to staging
2. Enable feature flag for internal users
3. Run smoke tests
4. Monitor dashboards

**Success Criteria**:
- No P0/P1 bugs
- All smoke tests pass
- No performance regressions

**Go/No-Go**: Development lead approval

---

### Phase 2: Canary (5-20%)

**Duration**: 3-7 days

**Audience**:
- Small cohort of production users
- Selected by Remote Config conditions (e.g., user ID hash)

**Actions**:
1. Deploy to production (feature flag OFF)
2. Enable feature flag for canary cohort (5%)
3. Monitor metrics for 24-48 hours
4. Expand to 20% if green

**Success Criteria**:
- Error rate < baseline + 5%
- P95 latency < baseline + 10%
- No critical bugs reported
- User feedback positive

**Monitoring**:
- Firebase Crashlytics (crash rate)
- Firebase Performance (latency)
- Cloud Logging (error logs)
- User support tickets

**Go/No-Go**: Product owner + engineering approval

**Rollback**: Disable feature flag if metrics degrade

---

### Phase 3: Staged Rollout (20-100%)

**Duration**: 7-14 days

**Audience**:
- Gradual expansion to all users
- Schedule: 20% → 50% → 100%

**Actions**:
1. Monitor 20% cohort for 48 hours
2. Expand to 50% if green
3. Monitor 50% cohort for 48 hours
4. Expand to 100% if green

**Success Criteria** (same as canary):
- Error rate < baseline + 5%
- P95 latency < baseline + 10%
- No critical bugs
- User feedback positive

**Monitoring**: Same as canary

**Go/No-Go**: Engineering lead approval per stage

**Rollback**: Reduce rollout percentage or disable flag

---

### Phase 4: General Availability

**Duration**: Permanent

**Audience**: All users

**Actions**:
1. Feature flag set to 100% (or `true` default)
2. Update app with flag hardcoded to `true` in next release
3. Remove flag from Remote Config after 2-4 weeks

**Success Criteria**:
- Stable error rates
- Stable performance
- Positive user feedback

---

## Rollback Procedures

### Types of Rollback

#### 1. Feature Flag Rollback (Fastest)

**When**: Feature has issues but rest of app is fine

**Time**: Immediate (< 5 minutes)

**Steps**:
1. Open Firebase Remote Config console
2. Set feature flag to `false` (or reduce percentage)
3. Publish changes
4. Apps fetch new config within 1 hour (or manual refresh)
5. Monitor for resolution

**Limitations**: Only works for flagged features

**Risk**: Low (no code change, no deployment)

---

#### 2. Cloud Functions Rollback

**When**: Backend function has issues

**Time**: 5-10 minutes

**Steps**:
1. List recent deployments:
   ```bash
   firebase functions:list
   ```
2. Rollback to previous version:
   ```bash
   firebase functions:rollback <function-name>
   ```
3. Monitor Cloud Logging for errors
4. Verify metrics recover

**Limitations**: Only rollbacks functions, not Firestore rules/indexes

**Risk**: Low (tested code)

---

#### 3. Full App Rollback

**When**: Critical issue affects multiple areas

**Time**: Depends on app store review (hours to days)

**Steps**:
1. **Immediate**: Disable all new feature flags
2. **Short-term**: Deploy previous release to staging
3. **Medium-term**: Tag previous stable version and redeploy
   ```bash
   git tag v1.0.1-rollback v1.0.0
   git push origin v1.0.1-rollback
   ```
4. **Long-term**: Submit rollback build to app stores
5. Monitor for resolution

**Limitations**: 
- Android: Can take 2-24 hours for review
- iOS: Can take 24-48 hours for review
- Users need to update app

**Risk**: Medium (previous version has been in production)

---

#### 4. Firestore Rules Rollback

**When**: Security rules break functionality

**Time**: 5-10 minutes

**Steps**:
1. Revert `firestore.rules` to previous version:
   ```bash
   git checkout HEAD~1 firestore.rules
   ```
2. Deploy rules:
   ```bash
   firebase deploy --only firestore:rules
   ```
3. Monitor for resolution

**Risk**: Low (rules don't affect data)

---

## Monitoring & Alerts

### Key Metrics

#### Application Health

| Metric | Baseline | Alert Threshold | Action |
|--------|----------|-----------------|--------|
| Crash-free rate | > 99% | < 98% | Investigate, consider rollback |
| Error rate | < 1% | > 2% | Investigate, consider rollback |
| ANR rate | < 0.5% | > 1% | Investigate performance |

#### Performance

| Metric | Baseline | Alert Threshold | Action |
|--------|----------|-----------------|--------|
| Screen load (P95) | < 2s | > 3s | Investigate, optimize |
| API latency (P95) | < 1s | > 2s | Check backend, network |
| Frame rate | 60fps | < 55fps | Profile, optimize |

#### Business Metrics

| Metric | Baseline | Alert Threshold | Action |
|--------|----------|-----------------|--------|
| Clock-in success rate | > 99% | < 95% | Check function, network |
| Payment success rate | > 95% | < 90% | Check Stripe, function |
| Offline sync failures | < 5% | > 10% | Check queue service |

---

### Alert Channels

1. **Firebase Crashlytics**: Email on crash spike
2. **Firebase Performance**: Dashboard monitoring
3. **Cloud Monitoring**: Alert policies for function errors
4. **Slack/Email**: Critical alerts to on-call engineer

---

### Dashboard

**Location**: Firebase Console

**Panels**:
1. **Crashlytics**: Crash-free rate, top crashes
2. **Performance**: Screen traces, network traces
3. **Analytics**: Feature usage, user flows
4. **Cloud Functions**: Invocations, errors, latency

**Access**: Development team, product owner

**Review Cadence**: 
- Real-time during rollout
- Daily during canary
- Weekly after GA

---

## Deployment Checklist

### Pre-Deployment

- [ ] All tests pass (unit, integration, E2E)
- [ ] Code reviewed and approved
- [ ] Staging environment validated
- [ ] Feature flags configured
- [ ] Rollback plan documented
- [ ] Monitoring dashboards ready
- [ ] On-call engineer assigned

### During Deployment

- [ ] Deploy to production
- [ ] Enable feature flag for canary cohort
- [ ] Monitor metrics for 1 hour
- [ ] Verify no errors in Cloud Logging
- [ ] Check Crashlytics dashboard
- [ ] Review Performance dashboard

### Post-Deployment

- [ ] Monitor metrics for 24 hours
- [ ] Review user feedback/support tickets
- [ ] Document any issues encountered
- [ ] Update rollout percentage if green
- [ ] Communicate status to team

---

## Canary Cohort Configuration

### Remote Config Conditions

**Example**: Canary users (5%)

```json
{
  "conditions": [
    {
      "name": "canary_users",
      "expression": "percent <= 5",
      "tagColor": "BLUE"
    }
  ],
  "parameters": {
    "feature_new_feature_enabled": {
      "defaultValue": { "value": "false" },
      "conditionalValues": {
        "canary_users": { "value": "true" }
      }
    }
  }
}
```

**Alternative**: User ID-based

```json
{
  "conditions": [
    {
      "name": "internal_users",
      "expression": "user.email in ['dev@example.com', 'qa@example.com']",
      "tagColor": "GREEN"
    }
  ]
}
```

---

## Rollback Decision Matrix

| Severity | Error Rate | Latency | Crashes | Action | Timeline |
|----------|-----------|---------|---------|--------|----------|
| P0 | > 10% | > 5s P95 | > 5% | **Immediate rollback** | < 15 min |
| P1 | 5-10% | 3-5s P95 | 2-5% | **Rollback if not fixed in 1 hour** | < 1 hour |
| P2 | 2-5% | 2-3s P95 | 1-2% | **Monitor, fix in next release** | 1-7 days |
| P3 | < 2% | < 2s P95 | < 1% | **Monitor, fix when convenient** | > 7 days |

---

## Communication Plan

### Internal Communication

**Channels**: Slack, email

**Audience**: Development team, QA, product owner

**Frequency**:
- Pre-deployment: Deployment notification
- During rollout: Daily status updates
- Post-deployment: Final summary

**Template**:
```
🚀 Deployment Status: [Feature Name]

Phase: Canary (5%)
Start: [Date/Time]
Duration: [X days]

Metrics:
✅ Error rate: 0.5% (baseline: 0.8%)
✅ P95 latency: 850ms (baseline: 900ms)
✅ Crash-free: 99.5% (baseline: 99.4%)

Next: Expand to 20% on [Date]
```

---

### User Communication

**Channels**: In-app notifications, email

**Audience**: End users (crew, admins)

**Frequency**: Major feature launches only

**Template**:
```
🎉 New Feature: [Feature Name]

We've added [brief description].

How to use:
1. [Step 1]
2. [Step 2]

Questions? Contact support@sierrapainting.com
```

---

## Emergency Contacts

| Role | Contact | Availability |
|------|---------|--------------|
| Engineering Lead | [Name/Email] | 24/7 during rollout |
| Product Owner | [Name/Email] | Business hours |
| DevOps | [Name/Email] | On-call rotation |
| Firebase Support | Firebase Console | 24/7 (paid plan) |

---

## Post-Mortem Process

**When**: After any rollback or incident

**Timeline**: Within 48 hours of resolution

**Participants**: Engineering team, product owner, affected parties

**Template**:

```markdown
# Post-Mortem: [Incident Title]

## Summary
Brief description of what happened

## Timeline
- [Time]: Event 1
- [Time]: Event 2
- ...

## Root Cause
Technical explanation of the issue

## Impact
- Users affected: [Number/Percentage]
- Duration: [Time]
- Business impact: [Description]

## Resolution
How the issue was resolved

## Action Items
1. [ ] Action 1 - Owner: [Name] - Due: [Date]
2. [ ] Action 2 - Owner: [Name] - Due: [Date]

## Lessons Learned
What we learned and how to prevent in future
```

---

## CI/CD Pipeline

### GitHub Actions Workflow

**File**: `.github/workflows/ci.yml`

**Triggers**:
- Push to `main` → Deploy to staging
- Tag `v*` → Deploy to production (manual approval)

**Jobs**:
1. **Test**: Run unit tests, integration tests
2. **Lint**: Run Flutter analyzer, ESLint
3. **Build**: Build APK/IPA
4. **Deploy**: Deploy Cloud Functions, Firestore rules

**Secrets Required**:
- `FIREBASE_TOKEN`: Firebase CLI token
- `ANDROID_KEYSTORE`: Android signing key
- `IOS_CERTIFICATE`: iOS signing certificate

---

## Version Management

### Semantic Versioning

**Format**: `MAJOR.MINOR.PATCH`

**Examples**:
- `v1.0.0`: Initial release
- `v1.1.0`: New feature (backward compatible)
- `v1.1.1`: Bug fix (backward compatible)
- `v2.0.0`: Breaking change

**Tags**: Git tags with `v` prefix

**Changelog**: Maintained in GitHub Releases

---

## Testing Before Rollout

### Smoke Tests (Required)

1. **Authentication**
   - Sign up new user
   - Log in existing user
   - Log out

2. **Time Clock**
   - Clock in to job
   - Clock out from job
   - View time entries

3. **Estimates**
   - Create estimate
   - View estimate
   - Edit estimate

4. **Invoices**
   - Create invoice
   - View invoice
   - Mark as paid (admin)

5. **Offline**
   - Enable airplane mode
   - Perform action (clock in)
   - Disable airplane mode
   - Verify sync

**Tool**: Manual testing or E2E test suite

**Duration**: 30-60 minutes

**Pass Criteria**: All tests pass

---

## Related Documentation

- [Architecture Overview](./Architecture.md)
- [Feature Flags](./FEATURE_FLAGS.md)
- [CI/CD Configuration](../.github/workflows/ci.yml)
- [Testing Strategy](./Testing.md)
- [Performance Monitoring](./perf-playbook-fe.md)
