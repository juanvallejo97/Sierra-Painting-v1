# Operations Guide — Sierra Painting

> **Version:** V1  
> **Last Updated:** 2024-10-04  
> **Status:** Production-Ready

---

## Overview

This guide covers deployment, rollback procedures, monitoring, and operational runbooks for Sierra Painting.

---

## Table of Contents

1. [Deployment](#deployment)
2. [Rollback Procedures](#rollback-procedures)
3. [Monitoring & SLOs](#monitoring--slos)
4. [Runbooks](#runbooks)
5. [Feature Flags](#feature-flags)
6. [CI/CD Pipeline](#cicd-pipeline)

---

## Deployment

### Prerequisites

- GitHub Actions workflows configured
- Firebase projects set up (staging, production)
- Workload Identity Federation configured
- Environment secrets configured in GitHub

### Deployment Workflow

**Staging Deployment:**
```bash
# Automatic on push to main branch
git push origin main

# Deploys to staging environment automatically
# URL: https://sierra-painting-staging.web.app
```

**Production Deployment:**
```bash
# Create a release tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Triggers production workflow with manual approval gate
# Requires approval from authorized deployers
```

### Manual Deployment (Emergency)

**Functions Only:**
```bash
firebase use production
firebase deploy --only functions
```

**Firestore Rules Only:**
```bash
firebase deploy --only firestore:rules
```

**Full Deployment:**
```bash
firebase deploy
```

### Deployment Checklist

Before deploying to production:

- [ ] All tests passing in staging
- [ ] Security rules tested
- [ ] Performance metrics reviewed
- [ ] Breaking changes documented
- [ ] Rollback plan prepared
- [ ] Team notified
- [ ] Monitoring alerts configured

---

## Rollback Procedures

### Emergency Rollback

**Option 1: Redeploy Previous Version**
```bash
# Find the last working tag
git tag -l

# Checkout and deploy
git checkout v1.0.0
firebase use production
firebase deploy
```

**Option 2: Feature Flag Kill Switch**
```bash
# Disable problematic feature via Firebase Console
# Go to Remote Config → Update flag to false → Publish
```

**Option 3: Revert via GitHub**
```bash
# Create revert PR
git revert <commit-sha>
git push origin main

# Wait for CI/CD to deploy to staging
# Create release tag to deploy to production
```

### Rollback Decision Tree

1. **Minor UI bug**: Use feature flag to disable feature
2. **Data corruption risk**: Immediate rollback via git revert
3. **Performance degradation**: Review metrics, consider rollback
4. **Security vulnerability**: Immediate rollback + hotfix

### Post-Rollback

- [ ] Verify system stability
- [ ] Update incident log
- [ ] Root cause analysis
- [ ] Plan forward fix
- [ ] Communicate to stakeholders

---

## Monitoring & SLOs

### Service Level Objectives (SLOs)

**Availability:**
- Target: 99.5% uptime (monthly)
- Measurement: Firebase uptime monitoring

**Performance:**
- API Response Time: p95 < 500ms
- App Launch Time: p95 < 3 seconds
- Time to Interactive: p95 < 5 seconds

**Reliability:**
- Error Rate: < 1% of requests
- Crash-Free Users: > 99.5%

### Key Metrics to Monitor

**Firebase Console:**
- Firestore read/write operations
- Cloud Functions invocations and errors
- Authentication success/failure rates
- Storage bandwidth usage

**Firebase Performance:**
- App startup time
- Screen rendering time
- Network request latency
- Custom traces for critical operations

**Firebase Crashlytics:**
- Crash-free users percentage
- Top crashes by occurrence
- Fatal vs non-fatal errors

### Alerts

**Critical Alerts** (Page on-call):
- API error rate > 5%
- All functions failing
- Authentication completely down
- Database writes failing

**Warning Alerts** (Email/Slack):
- API error rate > 2%
- P95 latency > 1 second
- Crash rate > 1%
- Unusual traffic patterns

### Monitoring Setup

See [docs/ops/monitoring.md](docs/ops/monitoring.md) for detailed setup instructions.

---

## Runbooks

Operational procedures for common tasks.

### Available Runbooks

- **[EMULATORS](docs/EMULATORS.md)** - Local development with Firebase Emulators
- **[Runbooks Directory](docs/ops/runbooks/)** - Operational runbook templates

### Deployment Runbook

See [Deployment](#deployment) section above for step-by-step deployment procedures.

### Rollback Runbook

See [Rollback Procedures](#rollback-procedures) section above for emergency rollback procedures.

### Runbook Template

Each runbook should include:
- Purpose and when to use
- Prerequisites
- Step-by-step procedures
- Rollback plan
- Expected outcomes
- Troubleshooting tips
- Owner contact information

---

## Feature Flags

Feature flags allow gradual rollout and emergency kill switches.

### Flag Management

**Via Firebase Console:**
1. Go to Remote Config
2. Add/update parameter
3. Set default value
4. (Optional) Set conditional values for staging
5. Publish changes

**Flag Naming Convention:**
```
feature_<feature_name>_enabled
```

### Common Flags

```javascript
{
  "feature_stripe_payments_enabled": false,  // Kill switch for Stripe
  "feature_offline_sync_enabled": true,      // Offline queue
  "feature_admin_dashboard_v2": false,       // New admin UI
  "rollout_percentage": 10                   // Gradual rollout
}
```

### Usage in Code

**Flutter:**
```dart
final featureFlagService = ref.read(featureFlagServiceProvider);
final stripeEnabled = featureFlagService.getBool('feature_stripe_payments_enabled');

if (stripeEnabled) {
  // Show Stripe checkout
} else {
  // Manual payment only
}
```

For detailed feature flag strategy, see [docs/FEATURE_FLAGS.md](docs/FEATURE_FLAGS.md).

---

## CI/CD Pipeline

### Pipeline Overview

**Staging Pipeline** (on push to `main`):
1. Run linters (Flutter, Functions)
2. Type checking (Dart analyzer, TypeScript)
3. Unit tests (Flutter, Functions)
4. Integration tests with emulators
5. Build artifacts
6. Deploy to staging environment
7. Run smoke tests

**Production Pipeline** (on release tag):
1. All staging checks
2. Security scanning (CodeQL)
3. Manual approval gate
4. Deploy to production
5. Run production smoke tests
6. Notify team

### CI Configuration

GitHub Actions workflows are in `.github/workflows/`:
- `staging.yml` - Staging deployment
- `production.yml` - Production deployment with approval
- `ci.yml` - PR validation (lint, test, build)

### Deployment Environments

**Staging:**
- URL: `https://sierra-painting-staging.web.app`
- Firebase project: `sierra-painting-staging`
- Auto-deploys from `main` branch
- Test data only

**Production:**
- URL: `https://sierra-painting.web.app`
- Firebase project: `sierra-painting-prod`
- Manual approval required
- Production data

For detailed CI/CD implementation, see [docs/ops/CI_CD_IMPLEMENTATION.md](docs/ops/CI_CD_IMPLEMENTATION.md).

---

## Emergency Contacts

**On-Call Rotation:**
- Primary: Check PagerDuty schedule
- Secondary: Check PagerDuty schedule

**Escalation Path:**
1. On-call engineer (15 min response)
2. Team lead (30 min response)
3. Engineering manager (1 hour response)

---

## References

- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [SECURITY.md](SECURITY.md) - Security guidelines
- [docs/ops/](docs/ops/) - Detailed operational guides
- [docs/FEATURE_FLAGS.md](docs/FEATURE_FLAGS.md) - Feature flag management
- [docs/EMULATORS.md](docs/EMULATORS.md) - Local development guide
