# Deployment Checklist

> **Purpose**: Quick reference checklist for deploying Sierra Painting to staging and production
>
> **Last Updated**: 2024
>
> **Related Documentation**: See [rollout-rollback.md](./rollout-rollback.md) for detailed procedures

---

## Overview

This checklist ensures safe, consistent deployments to staging and production environments. Use this as a step-by-step guide for every deployment.

**Deployment Types:**
- **Staging**: Automatic on push to `main` branch
- **Production**: Manual on version tag (e.g., `v1.0.0`)

---

## Pre-Deployment Checklist

Complete ALL items before deploying:

### Code Quality
- [ ] All tests pass locally
  ```bash
  flutter test
  cd functions && npm test && cd ..
  ```
- [ ] Code has been reviewed and approved (PR merged)
- [ ] Linting passes with no errors
  ```bash
  flutter analyze
  cd functions && npm run lint && cd ..
  ```
- [ ] Build succeeds locally
  ```bash
  flutter build apk --debug
  cd functions && npm run build && cd ..
  ```

### Testing
- [ ] Unit tests pass (Flutter + Functions)
- [ ] Integration tests pass (if applicable)
- [ ] Smoke tests completed on local emulators
  ```bash
  firebase emulators:start
  # Test: Auth, Clock In/Out, Estimates, Invoices, Offline Sync
  ```
- [ ] E2E tests pass (if applicable)

### Security
- [ ] No hardcoded secrets or API keys in code
- [ ] Firestore security rules tested
  ```bash
  cd functions && npm run test:rules
  ```
- [ ] App Check configured for new callable functions
- [ ] Authentication/authorization checks in place
- [ ] Payment amount validation added (if payment-related)
- [ ] Sensitive fields protected in Firestore rules

### Configuration
- [ ] Environment variables updated (if needed)
- [ ] Firebase Remote Config flags configured
- [ ] Feature flags set to appropriate defaults
- [ ] Database indexes created (if needed)
  ```bash
  firebase deploy --only firestore:indexes
  ```

### Documentation
- [ ] Code comments added for complex logic
- [ ] API changes documented
- [ ] README updated (if applicable)
- [ ] Migration notes documented (if breaking changes)

### Planning
- [ ] Rollback plan documented
- [ ] Feature flags ready for gradual rollout
- [ ] Monitoring dashboards prepared
- [ ] On-call engineer assigned
- [ ] Team notified of deployment schedule

---

## Staging Deployment Checklist

### Pre-Deployment (Staging)
- [ ] All pre-deployment items completed (above)
- [ ] Create PR with story reference and checklist
- [ ] PR approved by at least one reviewer
- [ ] No merge conflicts with `main` branch

### Deployment (Staging)
- [ ] Merge PR to `main` branch
  ```bash
  git checkout main
  git pull origin main
  git merge --no-ff feature/your-feature
  git push origin main
  ```
- [ ] GitHub Actions workflow starts automatically
- [ ] Monitor workflow progress in GitHub Actions tab
- [ ] Verify deployment succeeds (check workflow logs)

### Post-Deployment (Staging)
- [ ] Smoke test deployed changes in staging
  - [ ] Authentication flow
  - [ ] Core features (clock in/out, estimates, invoices)
  - [ ] New feature functionality
  - [ ] Offline sync (if applicable)
- [ ] Check Firebase Console logs for errors
  ```
  Firebase Console → Functions → Logs
  ```
- [ ] Verify Crashlytics dashboard (no new crashes)
- [ ] Test feature flags work as expected
- [ ] Review Cloud Function metrics
  - [ ] Invocation count
  - [ ] Error rate < 1%
  - [ ] P95 latency < 2s
- [ ] Document any issues encountered
- [ ] Notify team of staging deployment status

### Go/No-Go Decision
- [ ] All smoke tests pass
- [ ] No critical bugs found
- [ ] Performance metrics acceptable
- [ ] Team approval to proceed to production

---

## Production Deployment Checklist

### Pre-Deployment (Production)
- [ ] All staging tests passed
- [ ] Staging validated for 24-48 hours minimum
- [ ] No critical issues in staging
- [ ] Feature flags configured in production Firebase project
- [ ] App Check tokens configured
  - [ ] Android: Play Integrity API enabled
  - [ ] iOS: DeviceCheck or App Attest enabled
  - [ ] Web: reCAPTCHA Enterprise configured
- [ ] Debug tokens registered (if needed for testing)
- [ ] Production Firebase project selected
  ```bash
  firebase use production
  ```
- [ ] Version number updated
  ```yaml
  # pubspec.yaml
  version: 1.0.0+1  # Update this
  ```

### Deployment (Production)
- [ ] Create and push version tag
  ```bash
  git checkout main
  git pull origin main
  git tag -a v1.0.0 -m "Release v1.0.0: [Brief description]"
  git push origin v1.0.0
  ```
- [ ] GitHub Actions workflow starts automatically
- [ ] Monitor workflow progress in GitHub Actions tab
- [ ] Verify workflow completes successfully
- [ ] Download release artifacts from GitHub Actions
  - [ ] `app-release.apk`
  - [ ] `app-release.aab`

### Initial Production Verification (0-1 hour)
- [ ] Deploy functions to production (automatic via workflow)
- [ ] Feature flags OFF initially (or canary at 5%)
- [ ] Monitor Cloud Functions logs for errors
  ```
  Firebase Console → Functions → Logs (Production Project)
  ```
- [ ] Check initial metrics (first hour)
  - [ ] Function invocations
  - [ ] Error rate
  - [ ] Latency (P95)
- [ ] Test critical paths with test accounts
  - [ ] Authentication
  - [ ] Clock in/out
  - [ ] Payment processing (if applicable)
- [ ] Verify no regression in existing features
- [ ] Check Crashlytics for new crashes

### Gradual Rollout (Production)

#### Phase 1: Internal Testing (0-5%, 1-3 days)
- [ ] Enable feature flag for internal users only
  ```
  Firebase Console → Remote Config → Conditions
  Condition: user.email in ['dev@example.com', 'qa@example.com']
  ```
- [ ] Internal team tests feature in production
- [ ] Monitor metrics for 24 hours minimum
  - [ ] Error rate < baseline + 5%
  - [ ] P95 latency < baseline + 10%
  - [ ] Crash-free rate > 99%
- [ ] Document any issues
- [ ] **Go/No-Go**: Proceed to canary or rollback

#### Phase 2: Canary (5-20%, 3-7 days)
- [ ] Enable feature flag for 5% of users
  ```
  Firebase Console → Remote Config
  Condition: percent <= 5
  ```
- [ ] Monitor metrics for 48 hours
  - [ ] Error rate
  - [ ] Latency
  - [ ] Crashlytics
  - [ ] User feedback
- [ ] If metrics green, expand to 20%
- [ ] Monitor 20% cohort for 48 hours
- [ ] **Go/No-Go**: Proceed to staged rollout or rollback

#### Phase 3: Staged Rollout (20-100%, 7-14 days)
- [ ] Expand to 50% if 20% cohort metrics green
- [ ] Monitor 50% cohort for 48 hours
- [ ] Expand to 100% if 50% cohort metrics green
- [ ] Monitor 100% for 24 hours
- [ ] **Decision**: Keep at 100% or rollback

#### Phase 4: General Availability (Permanent)
- [ ] Feature flag set to 100% (or `true` by default)
- [ ] Monitor metrics for 7 days
- [ ] Review user feedback and support tickets
- [ ] Update app with flag hardcoded to `true` in next release
- [ ] Remove flag from Remote Config after 2-4 weeks

### Post-Deployment (Production)
- [ ] Monitor production metrics for 24 hours continuously
- [ ] Review Cloud Logging for errors
  ```
  Cloud Console → Logging → Logs Explorer
  Filter: severity >= ERROR
  ```
- [ ] Check Crashlytics dashboard
  ```
  Firebase Console → Crashlytics
  Verify: Crash-free rate > 99%
  ```
- [ ] Review Performance dashboard
  ```
  Firebase Console → Performance
  Verify: Screen load times < 2s P95
  ```
- [ ] Review user feedback/support tickets
- [ ] Document lessons learned
- [ ] Update rollout percentage based on metrics
- [ ] Communicate deployment status to team
  ```
  🚀 Deployment Status: [Feature Name]
  Phase: [Canary/Staged/GA]
  Metrics: [Error rate, Latency, Crash-free rate]
  Next: [Action and date]
  ```

### App Store Submission (If Applicable)
- [ ] Test release build on physical devices
  - [ ] Android device testing
  - [ ] iOS device testing
- [ ] Prepare store listing updates
  - [ ] Screenshots
  - [ ] Release notes
  - [ ] Description updates
- [ ] Submit to Google Play Store
  - [ ] Upload AAB file
  - [ ] Complete release form
  - [ ] Submit for review
- [ ] Submit to Apple App Store
  - [ ] Upload IPA via Xcode/Transporter
  - [ ] Complete release form
  - [ ] Submit for review
- [ ] Monitor store review status
- [ ] Communicate release timeline to stakeholders

---

## Rollback Procedures

If issues are detected, follow these rollback procedures:

### Quick Rollback Checklist

- [ ] **1. Disable Feature Flag** (fastest method)
  ```
  Firebase Console → Remote Config → Set flag to false → Publish
  ```
- [ ] **2. Monitor Metrics** (verify issue is contained)
- [ ] **3. Communicate** (notify team and affected users)
- [ ] **4. Investigate Root Cause** (why did it fail?)
- [ ] **5. Plan Fix** (code change, config change, or permanent disable)

### Rollback Triggers

Rollback immediately if any of these occur:

| Severity | Error Rate | Latency | Crashes | Action | Timeline |
|----------|-----------|---------|---------|--------|----------|
| P0 | > 10% | > 5s P95 | > 5% | **Immediate rollback** | < 15 min |
| P1 | 5-10% | 3-5s P95 | 2-5% | **Rollback if not fixed in 1 hour** | < 1 hour |
| P2 | 2-5% | 2-3s P95 | 1-2% | **Monitor, fix in next release** | 1-7 days |

### Rollback Methods

#### Option 1: Feature Flag Rollback (Fastest)
- [ ] Set feature flag to `false` in Firebase Remote Config
- [ ] Publish changes
- [ ] Wait 1-5 minutes for propagation
- [ ] Verify feature is disabled
- [ ] Monitor metrics for recovery

#### Option 2: Cloud Functions Rollback
- [ ] List recent deployments: `firebase functions:list`
- [ ] Rollback function: `firebase functions:rollback <function-name>`
- [ ] Monitor Cloud Logging for errors
- [ ] Verify metrics recover

#### Option 3: Full Firestore Rules Rollback
- [ ] Revert rules: `git checkout HEAD~1 firestore.rules`
- [ ] Deploy rules: `firebase deploy --only firestore:rules`
- [ ] Monitor for resolution

#### Option 4: Full App Rollback (Slowest)
- [ ] Disable all new feature flags immediately
- [ ] Tag previous version: `git tag v1.0.1-rollback v1.0.0`
- [ ] Push tag: `git push origin v1.0.1-rollback`
- [ ] Submit rollback build to app stores
- [ ] Monitor for resolution

### Post-Rollback
- [ ] Document incident in post-mortem
- [ ] Identify root cause
- [ ] Create action items with owners
- [ ] Fix issue before re-deploying
- [ ] Communicate resolution to stakeholders

---

## Monitoring Dashboard

### Key Metrics to Monitor

#### Application Health
- **Crash-free rate**: > 99% (alert if < 98%)
- **Error rate**: < 1% (alert if > 2%)
- **ANR rate**: < 0.5% (alert if > 1%)

#### Performance
- **Screen load (P95)**: < 2s (alert if > 3s)
- **API latency (P95)**: < 1s (alert if > 2s)
- **Frame rate**: 60fps (alert if < 55fps)

#### Business Metrics
- **Clock-in success rate**: > 99% (alert if < 95%)
- **Payment success rate**: > 95% (alert if < 90%)
- **Offline sync failures**: < 5% (alert if > 10%)

### Monitoring Tools
- **Firebase Crashlytics**: Crash rate and stack traces
- **Firebase Performance**: Screen and network traces
- **Cloud Monitoring**: Function metrics and logs
- **Firebase Analytics**: Feature usage and user flows

### Access Points
- Firebase Console: https://console.firebase.google.com/
- Cloud Console: https://console.cloud.google.com/
- GitHub Actions: Repository → Actions tab
- App Store Connect: https://appstoreconnect.apple.com/
- Google Play Console: https://play.google.com/console/

---

## Emergency Contacts

| Role | Responsibility | Availability |
|------|---------------|--------------|
| Engineering Lead | Deployment approval, rollback decisions | 24/7 during rollout |
| Product Owner | Feature validation, user communication | Business hours |
| DevOps/On-Call | Infrastructure, monitoring, alerts | On-call rotation |
| Firebase Support | Firebase issues, quota limits | 24/7 (paid plan) |

---

## Related Documentation

- **[Rollout & Rollback Strategy](./rollout-rollback.md)**: Detailed deployment strategy and procedures
- **[Developer Workflow Guide](./DEVELOPER_WORKFLOW.md)**: Development process and Git workflow
- **[Security Guide](./Security.md)**: Security requirements and App Check setup
- **[Testing Guide](./Testing.md)**: Testing strategy and E2E scripts
- **[Feature Flags Documentation](./FEATURE_FLAGS.md)**: Feature flag management
- **[CI/CD Workflows](../.github/workflows/)**: GitHub Actions configuration

---

## Notes

### Best Practices
- **Always deploy to staging first** - Never deploy directly to production
- **Use feature flags** - Enable gradual rollout and quick rollback
- **Monitor continuously** - Watch metrics during and after deployment
- **Document everything** - Record decisions, issues, and lessons learned
- **Communicate proactively** - Keep team informed of deployment status
- **Test thoroughly** - Run smoke tests in each environment
- **Plan for rollback** - Always have a rollback plan before deploying

### Common Pitfalls to Avoid
- ❌ Skipping staging validation
- ❌ Deploying on Friday afternoon
- ❌ Rolling out to 100% immediately
- ❌ Not monitoring metrics post-deployment
- ❌ Forgetting to configure feature flags
- ❌ Not testing rollback procedures
- ❌ Deploying without approval
- ❌ Ignoring failed tests

### Deployment Timing
- ✅ **Best**: Tuesday-Thursday, 10am-2pm (business hours, early week)
- ⚠️ **Avoid**: Fridays, evenings, weekends, holidays
- ⚠️ **Caution**: Mondays (potential weekend issues), end of month (high load)

---

**Last Updated**: 2024  
**Document Owner**: Engineering Team  
**Review Cadence**: Quarterly or after major incidents
