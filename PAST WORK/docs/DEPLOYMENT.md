# Deployment Guide — Sierra Painting

> **Purpose**: Definitive deployment, rollout, and rollback procedures  
> **Last Updated**: 2024  
> **Status**: Production-Ready

---

## Table of Contents

1. [Overview](#overview)
2. [Deployment Environments](#deployment-environments)
3. [Pre-Deployment Checklist](#pre-deployment-checklist)
4. [Deployment Procedures](#deployment-procedures)
5. [Canary Rollout Strategy](#canary-rollout-strategy)
6. [Monitoring & Gates](#monitoring--gates)
7. [Rollback Procedures](#rollback-procedures)
8. [Feature Flags](#feature-flags)
9. [Troubleshooting](#troubleshooting)

---

## Overview

Sierra Painting uses a multi-environment deployment strategy with canary rollouts and instant rollback capability:

- **Dev**: Local emulators for development
- **Staging**: Integration testing on `main` branch
- **Production**: Live customer-facing deployment on version tags

**Key Principles**:
- Progressive rollout (10% → 50% → 100%)
- Gate-based promotion with SLO monitoring
- Instant rollback via traffic routing or feature flags
- Pre-deploy validation hooks
- Automated deployment history tracking

---

## Deployment Environments

### 1. Development (Local)

**Purpose**: Local development and testing

**Configuration**:
- Firebase emulators (Auth, Firestore, Functions, Storage)
- Local Flutter debug build
- Synthetic test data

**Setup**:
```bash
firebase emulators:start
flutter run
```

**Access**: All developers

---

### 2. Staging

**Purpose**: Integration testing and QA

**Configuration**:
- Firebase project: `sierra-painting-staging`
- Branch: `main`
- Flutter debug/profile builds

**Deployment**:
```bash
# Automatic on push to main via CI
# Or manual deployment:
./scripts/deploy/deploy.sh --env staging

# Verify deployment
./scripts/deploy/verify.sh --env staging
```

**Access**: Development team, QA team

**Data**: Synthetic test data, anonymized production data

---

### 3. Production

**Purpose**: Live customer-facing application

**Configuration**:
- Firebase project: `sierra-painting-prod`
- Tags: `v*` (e.g., `v1.0.0`, `v1.1.0`)
- Flutter release builds (APK/IPA)

**Deployment**:
- Manual trigger after staging validation
- Tag creation triggers canary deployment
- Progressive rollout via traffic splitting

**Access**: All users

**Data**: Live production data

---

## Pre-Deployment Checklist

Complete **ALL** items before deploying to production:

### Code Quality
- [ ] All tests pass locally (`flutter test` + `cd functions && npm test`)
- [ ] Code reviewed and approved (PR merged)
- [ ] Linting passes with no errors (`flutter analyze`, `npm run lint`)
- [ ] Build succeeds locally (`flutter build apk`, `npm run build`)

### Testing
- [ ] Unit tests pass (Flutter + Functions)
- [ ] Integration tests pass
- [ ] Smoke tests completed on emulators
- [ ] Key user journeys verified:
  - Authentication (login/logout)
  - Time clock (clock in/out)
  - Estimates (create/view/export)
  - Invoices (create/mark paid)
  - Offline sync

### Security
- [ ] No hardcoded secrets or API keys
- [ ] Firestore security rules tested (`npm run test:rules`)
- [ ] App Check configured for callable functions
- [ ] Authentication/authorization checks in place
- [ ] Payment validation added (if payment-related)

### Configuration
- [ ] Environment variables updated (if needed)
- [ ] Firebase Remote Config flags configured
- [ ] Feature flags set to safe defaults
- [ ] Database indexes created (`firebase deploy --only firestore:indexes`)

### Documentation
- [ ] Code comments added for complex logic
- [ ] API changes documented
- [ ] Migration notes documented (if breaking changes)
- [ ] Rollback plan documented

### Planning
- [ ] Team notified of deployment schedule
- [ ] On-call engineer assigned
- [ ] Monitoring dashboards open
- [ ] Rollback commands ready

---

## Deployment Procedures

### Multi-Environment Deployment

For dev and staging environments:

```bash
# Deploy to dev
./scripts/deploy/deploy.sh --env dev

# Deploy to staging with verification
./scripts/deploy/deploy.sh --env staging
./scripts/deploy/verify.sh --env staging

# Deploy functions only
./scripts/deploy/deploy.sh --env staging --functions-only
```

### Production Deployment (Canary)

**Option A: Via Git Tag (Recommended)**
```bash
# Create and push version tag
git tag v1.2.0
git push origin v1.2.0

# GitHub Actions automatically deploys at 10% traffic
```

**Option B: Manual Script**
```bash
./scripts/deploy_canary.sh --project sierra-painting-prod --tag v1.2.0
```

**What happens**:
1. Pre-deploy checks run (smoke tests, rules tests, migrations)
2. Functions deploy with 10% traffic split
3. Deployment metadata saved to `.deployment-history/`
4. Monitoring begins

---

## Canary Rollout Strategy

### Cloud Functions (Backend)

Progressive traffic split with monitoring gates:

```
Stage 1: 10% → Monitor 24h → Gate ✅
Stage 2: 50% → Monitor 6h → Gate ✅
Stage 3: 100% → Full deployment
```

**Promotion Commands**:
```bash
# Promote to 50%
./scripts/promote_canary.sh --project sierra-painting-prod --stage 50

# Promote to 100%
./scripts/promote_canary.sh --project sierra-painting-prod --stage 100
```

### Mobile App (Play Store)

Staged rollout via Google Play Console:

```
Stage 1: Internal Testing (Alpha) → 5-10 users → 24h
Stage 2: Closed Testing (Beta) → 50-100 users → 2-3 days
Stage 3: Production Rollout → 10% → 50% → 100%
```

**Procedure**:
1. Build release: `flutter build appbundle --release`
2. Upload AAB to Play Console
3. Start with Internal Testing
4. Promote to Closed Testing after validation
5. Promote to Production with staged rollout (10% → 50% → 100%)

---

## Monitoring & Gates

### Success Criteria (Gates)

Before promoting to next stage, verify:

- ✅ **Crash-free sessions** ≥ 99.5%
- ✅ **Error rate** < baseline + 1%
- ✅ **P95 latency** no regression (< 10% increase)
- ✅ **No critical bugs** reported
- ✅ **Key user journeys** working (auth, clock in/out, estimates, invoices)

### Monitoring Tools

```bash
# Automated verification
./scripts/deploy/verify.sh --env prod

# Firebase Console
https://console.firebase.google.com/project/sierra-painting-prod/functions

# Cloud Run traffic split
https://console.cloud.google.com/run?project=sierra-painting-prod

# Logs
firebase functions:log --project sierra-painting-prod
```

### SLO Thresholds

| Metric | Target | Action if Exceeded |
|--------|--------|-------------------|
| Error rate | < 0.5% | Rollback if > 1% |
| P95 latency | < 500ms | Investigate if > 700ms |
| Crash rate | < 0.5% | Rollback if > 1% |
| Success rate | > 99% | Rollback if < 98% |

---

## Rollback Procedures

### Instant Rollback (Traffic Routing)

**Fastest method** — shifts traffic back to previous version:

```bash
# One-command rollback
./scripts/rollback.sh --project sierra-painting-prod

# Or manually route 100% to previous version
gcloud run services update-traffic FUNCTION_NAME \
  --to-revisions=PREVIOUS_REVISION=100 \
  --project sierra-painting-prod
```

**Impact**: Takes effect immediately (< 1 minute)

### Feature Flag Rollback

**Best for specific features** — disable feature without redeployment:

```bash
# Disable feature via Firebase Remote Config
./scripts/remote-config/manage-flags.sh --set feature_new_scheduler_enabled=false
```

**Impact**: Takes effect on next app fetch (typically < 5 minutes)

### Code Rollback

**Last resort** — redeploy previous version:

```bash
# Option 1: Revert merge commit
git revert -m 1 <merge-commit-hash>
git push origin main

# Option 2: Cherry-pick from backup
git checkout backup/pre-refactor -- path/to/file.dart
git commit -m "Restore file from pre-refactor"
git push origin main

# Option 3: Redeploy previous tag
git checkout v1.1.0
./scripts/deploy_canary.sh --project sierra-painting-prod --tag v1.1.0-rollback
```

**Impact**: Requires full deployment cycle (5-10 minutes)

### Database Rollback

For schema changes, follow the three-phase migration pattern:

**Phase 1: Additive** (deploy new fields, keep old fields)  
**Phase 2: Dual-write** (write to both old and new fields)  
**Phase 3: Cleanup** (remove old fields after validation)

**Rollback**: Revert to Phase 1 or Phase 2 depending on where failure occurred.

See [DATABASE.md](./DATABASE.md) for detailed migration procedures.

---

## Feature Flags

### Flag Types

1. **Development Flags**: Hide incomplete features
   - Default: `false`
   - Audience: Developers only
   - Example: `feature_new_scheduler_enabled`

2. **Release Flags**: Control feature rollout
   - Default: `false` initially, `true` after validation
   - Audience: Canary → stable cohorts
   - Example: `feature_c3_mark_paid_enabled`

3. **Operational Flags**: Runtime behavior control
   - Default: `true` (safe defaults)
   - Example: `stripe_webhooks_enabled`

### Managing Flags

```bash
# List all flags
./scripts/remote-config/manage-flags.sh --list

# Set flag value
./scripts/remote-config/manage-flags.sh --set flag_name=true

# Deploy config
firebase deploy --only remoteconfig --project sierra-painting-prod
```

### Best Practices

- Always use flags for risky features
- Document flag purpose and owner
- Set safe defaults (fail closed)
- Test both enabled/disabled states
- Clean up flags after stable rollout

---

## Troubleshooting

### Deployment Fails

**Issue**: Pre-deploy checks fail

**Solution**:
1. Check error output from `pre-deploy-checks.sh`
2. Fix failing tests or smoke tests
3. Re-run: `./scripts/deploy/pre-deploy-checks.sh staging`
4. Retry deployment

---

**Issue**: Functions deployment timeout

**Solution**:
1. Increase timeout in `firebase.json`: `"timeout": "60s"`
2. Optimize function cold start (reduce dependencies)
3. Retry deployment with `--force` flag

---

### Canary Issues

**Issue**: Error rate spike after canary deployment

**Solution**:
1. Check logs: `firebase functions:log --project sierra-painting-prod`
2. Identify root cause
3. If critical, rollback immediately: `./scripts/rollback.sh --project sierra-painting-prod`
4. Fix issue, test in staging, retry deployment

---

**Issue**: Cannot promote canary

**Solution**:
1. Verify gates passed: `./scripts/deploy/verify.sh --env prod`
2. Check monitoring dashboards for SLO violations
3. If stable, force promotion: `./scripts/promote_canary.sh --project sierra-painting-prod --stage 50 --force`

---

### Mobile App Issues

**Issue**: Play Store rejects AAB

**Solution**:
1. Check Play Console error message
2. Common issues:
   - Version code not incremented
   - Missing permissions
   - Signing configuration
3. Fix and rebuild: `flutter build appbundle --release`

---

**Issue**: Crash rate spike after rollout

**Solution**:
1. Check Firebase Crashlytics
2. Halt rollout in Play Console (pause staged rollout)
3. Fix crash, deploy hotfix
4. Resume rollout after validation

---

## Related Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) - System architecture and design
- [SECURITY.md](./SECURITY.md) - Security patterns and rules
- [DATABASE.md](./DATABASE.md) - Schema, migrations, and indexes
- [OPERATIONS.md](./OPERATIONS.md) - Runbooks and incident response
- [TESTING.md](./Testing.md) - Test strategy and procedures

---

## Support

For deployment issues:
1. Check this guide and related docs
2. Review deployment history: `.deployment-history/`
3. Check Firebase Console logs
4. Contact on-call engineer
5. Escalate to team lead if unresolved

---

**Last Updated**: 2024  
**Owner**: Engineering Team  
**Review Schedule**: Quarterly
