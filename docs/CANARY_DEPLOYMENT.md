# Canary Deployment Guide

> **Purpose**: Safe deployment strategy with gradual rollout and monitoring
>
> **Last Updated**: 2024
>
> **Status**: Active

---

## Overview

Canary deployment is a release strategy that gradually rolls out changes to a small subset of users before making it available to everyone. This minimizes risk and allows for quick rollback if issues arise.

---

## Deployment Strategy

### Mobile App (Play Store)

**Staged Rollout Percentages:**
```
Stage 1: 10% → Monitor 24h → Gate
Stage 2: 50% → Monitor 24h → Gate
Stage 3: 100% → Full release
```

**Gates (Checks before proceeding):**
- ✅ Crash-free sessions ≥ 99.5%
- ✅ No performance regressions (P95 latency)
- ✅ No critical bugs reported
- ✅ Error rate < baseline + 1%

### Backend (Cloud Functions)

**Traffic Split:**
```
Canary: 5% → Monitor 24h → Gate
Main: 95%

If stable:
Canary: 25% → Monitor 6h → Gate
Main: 75%

If stable:
Full deployment: 100%
```

---

## Part 1: Mobile App Deployment

### 1.1 Prepare Release

**Version Bump:**
```yaml
# pubspec.yaml
version: 1.2.0+5  # 1.2.0 = version, 5 = build number
```

**Build Release:**
```bash
# Clean build
flutter clean
flutter pub get

# Build AAB (Android App Bundle)
flutter build appbundle --release

# Verify size
ls -lh build/app/outputs/bundle/release/app-release.aab
```

**Pre-Release Checklist:**
- [ ] All tests pass
- [ ] APK size within budget
- [ ] Feature flags configured
- [ ] Changelogs updated
- [ ] Team notified
- [ ] Rollback plan documented

### 1.2 Upload to Play Console

**Internal Testing (Alpha):**
1. Google Play Console → Your App → Testing → Internal testing
2. Upload AAB
3. Add to internal testing track
4. Test with team (5-10 people)
5. Verify:
   - App installs
   - Core flows work
   - No crashes
   - Performance acceptable

**Closed Testing (Beta):**
1. Promote from Internal → Closed testing
2. Add beta testers (50-100 users)
3. Monitor for 2-3 days
4. Review feedback and metrics

### 1.3 Staged Rollout to Production

**Stage 1: 10% Rollout**
```
Day 1: Release to 10% of users
```

**Steps:**
1. Play Console → Production → Create new release
2. Upload AAB
3. Release name: "v1.2.0 - Performance improvements"
4. Set rollout percentage: 10%
5. Click "Review release"
6. Click "Start rollout"

**Monitor (24 hours):**
- Firebase Crashlytics → Crash-free rate
- Firebase Performance → App start time, P95
- Play Console → Crashes & ANRs
- User reviews (1-2 star reviews)
- Support tickets

**Decision Point:**
- ✅ **Pass gates** → Proceed to Stage 2
- ❌ **Fail gates** → Halt rollout, investigate, rollback if critical

**Stage 2: 50% Rollout**
```
Day 2: Increase to 50% of users
```

**Steps:**
1. Play Console → Production → Update rollout
2. Increase to 50%
3. Monitor for 24 hours

**Monitor (24 hours):**
- Same metrics as Stage 1
- Watch for patterns in crashes
- Monitor server load

**Decision Point:**
- ✅ **Pass gates** → Proceed to Stage 3
- ❌ **Fail gates** → Halt, investigate, rollback if needed

**Stage 3: 100% Rollout**
```
Day 3: Full release
```

**Steps:**
1. Play Console → Production → Update rollout
2. Set to 100%
3. Continue monitoring for 7 days

### 1.4 Monitoring Dashboard

**Key Metrics:**

| Metric | Source | Target | Alert Threshold |
|--------|--------|--------|-----------------|
| Crash-free sessions | Crashlytics | ≥99.5% | <99% |
| ANR rate | Play Console | <0.5% | >1% |
| App start P95 | Firebase Perf | <2.5s | >3s |
| 1-star reviews | Play Console | <5% | >10% |
| Error rate | Crashlytics | <0.1% | >0.5% |

**Alert Configuration:**
```
If crash-free rate < 99%:
  → Email: engineering@
  → Slack: #incidents
  → Action: Investigate immediately

If P95 latency > 3s:
  → Email: engineering@
  → Action: Monitor, prepare rollback

If 1-star reviews spike (>10%):
  → Email: product@, engineering@
  → Action: Review user feedback
```

---

## Part 2: Backend Deployment

### 2.1 Prepare Functions

**Update Function:**
```typescript
// functions/src/index.ts
export const myFunctionV2 = functions
  .runWith({
    minInstances: 1,
    maxInstances: 10,
  })
  .https.onCall(async (data, context) => {
    // New implementation
  });
```

**Keep Old Version Running:**
```typescript
// Keep old version for rollback
export const myFunction = functions
  .runWith({ minInstances: 1 })
  .https.onCall(async (data, context) => {
    // Old implementation
  });
```

### 2.2 Deploy Canary

**Option A: Traffic Splitting (Cloud Run)**

If using Cloud Run for Functions (2nd gen):

```bash
# Deploy new version with traffic split
gcloud run services update-traffic myFunction \
  --to-revisions=LATEST=5,PREVIOUS=95 \
  --project=sierra-painting
```

**Option B: Feature Flag (Recommended)**

Use Firebase Remote Config for gradual rollout:

```typescript
// Client-side
final useV2 = remoteConfig.getBool('use_my_function_v2');
final functionName = useV2 ? 'myFunctionV2' : 'myFunction';
final result = await functions.httpsCallable(functionName).call(data);
```

**Remote Config:**
```json
{
  "use_my_function_v2": {
    "defaultValue": { "value": false },
    "conditionalValues": {
      "internal_users": { "value": true },
      "beta_users": { "value": true }
    },
    "percentageOptions": [
      { "percentage": 5, "value": true }
    ]
  }
}
```

### 2.3 Gradual Rollout

**Stage 1: Internal Users (Day 0)**
- Enable for internal testing
- 5-10 users
- Monitor for 24 hours

**Stage 2: 5% Canary (Day 1)**
```
Remote Config:
  use_my_function_v2: 5% → true
```
- Monitor for 24 hours

**Stage 3: 25% Canary (Day 2)**
```
Remote Config:
  use_my_function_v2: 25% → true
```
- Monitor for 6 hours

**Stage 4: 100% (Day 3)**
```
Remote Config:
  use_my_function_v2: 100% → true
```
- Deprecate old function after 7 days

### 2.4 Monitoring Functions

**Key Metrics:**

| Metric | Source | Target | Alert |
|--------|--------|--------|-------|
| Error rate | Cloud Functions | <1% | >2% |
| P95 latency | Cloud Functions | <500ms | >1s |
| Execution time | Cloud Functions | <5s | >10s |
| Invocations | Cloud Functions | Stable | Spike |

**Cloud Monitoring Queries:**
```
// Error rate
sum(rate(firebase.googleapis.com/function/execution_count{status!="ok"}[5m])) 
/ sum(rate(firebase.googleapis.com/function/execution_count[5m]))

// P95 latency
histogram_quantile(0.95, 
  sum(rate(firebase.googleapis.com/function/execution_time_bucket[5m])) 
  by (le, function_name)
)
```

---

## Part 3: Rollback Procedures

### 3.1 Mobile App Rollback

**Halt Rollout:**
1. Play Console → Production
2. Click "Halt rollout"
3. Confirm action

**Rollback Release:**
1. Play Console → Production
2. Select previous stable version
3. Click "Resume rollout"
4. Set to 100%

**Timeline:**
- Halt: Immediate
- Rollback deployed: 15 minutes
- 50% users on old version: 6 hours
- 90% users on old version: 24-48 hours

### 3.2 Backend Rollback

**Option A: Traffic Split**
```bash
# Revert to previous version
gcloud run services update-traffic myFunction \
  --to-revisions=PREVIOUS=100 \
  --project=sierra-painting
```

**Option B: Feature Flag**
```json
// Remote Config
{
  "use_my_function_v2": false
}
```

Publish changes → Takes effect immediately

**Option C: Re-deploy Old Code**
```bash
# Checkout previous version
git checkout v1.1.0

# Deploy
cd functions
npm run deploy
```

**Timeline:**
- Feature flag: < 5 minutes
- Traffic split: < 5 minutes
- Re-deploy: < 10 minutes

---

## Part 4: Decision Matrix

### When to Proceed

| Stage | Criteria | Monitor Duration |
|-------|----------|------------------|
| Internal → Beta | No critical bugs | 24h |
| Beta → 10% | Crash-free ≥99.5% | 48h |
| 10% → 50% | All gates pass | 24h |
| 50% → 100% | All gates pass | 24h |

### When to Halt

**Immediate Halt Triggers:**
- Critical security vulnerability
- Data loss/corruption
- Crash rate > 2%
- Payment processing failures
- Auth system failures

**Warning Triggers (Monitor Closely):**
- Crash-free rate 99.0-99.5%
- P95 latency increased >50%
- Error rate 1-2%
- User complaints about specific feature

### When to Rollback

**Rollback Triggers:**
- Halt for > 24h with no fix
- Critical issue affecting > 5% users
- Data integrity concerns
- Security vulnerability exploited
- Multiple gate failures

---

## Part 5: Communication

### Internal Updates

**Slack Template:**
```
🚀 Deployment Update: v1.2.0

Status: Stage 2 (50% rollout)
Started: 2024-01-15 10:00 PST
Gates: ✅ Passing

Metrics:
  Crash-free: 99.7% ✅
  P95 latency: 2.1s ✅
  Error rate: 0.05% ✅

Next: Full rollout in 24h (if gates pass)
```

### User Communication

**Status Page (if issues):**
```
⚠️ Gradual Rollout in Progress

We're rolling out version 1.2.0 to improve performance.
Some users may experience brief delays during deployment.

Status: Deploying → Monitoring → Complete
ETA: 48 hours
```

---

## Checklists

### Pre-Deployment Checklist
- [ ] Version bumped
- [ ] Changelog updated
- [ ] Feature flags configured
- [ ] Rollback plan documented
- [ ] Team notified
- [ ] Monitoring dashboards ready
- [ ] On-call engineer assigned

### During Deployment Checklist
- [ ] Internal testing passed
- [ ] Beta testing passed
- [ ] 10% rollout monitoring complete
- [ ] 50% rollout monitoring complete
- [ ] All gates passed at each stage
- [ ] No critical issues reported

### Post-Deployment Checklist
- [ ] 100% rollout complete
- [ ] Monitoring continued for 7 days
- [ ] User feedback reviewed
- [ ] Performance metrics stable
- [ ] Postmortem (if issues occurred)
- [ ] Documentation updated

---

## Related Documentation

- [Performance Budgets](./PERFORMANCE_BUDGETS.md)
- [Performance Rollback](./PERFORMANCE_ROLLBACK.md)
- [Deployment Checklist](./deployment_checklist.md)
- [Rollout & Rollback Guide](./rollout-rollback.md)

---

## Quick Reference

**Halt Play Store Rollout:**
```
Play Console → Production → Halt rollout
```

**Backend Feature Flag:**
```
Firebase Console → Remote Config → Publish
```

**Check Metrics:**
```
Crashlytics: firebase.google.com/project/.../crashlytics
Performance: firebase.google.com/project/.../performance
Functions: console.cloud.google.com/functions
```
