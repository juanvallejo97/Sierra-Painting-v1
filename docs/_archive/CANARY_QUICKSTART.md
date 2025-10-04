# Canary Deployment System - Quick Start Guide

## Overview

This repository now includes a complete canary deployment system for safely releasing Cloud Functions and mobile apps with progressive exposure (10% → 50% → 100%) and instant rollback capability.

## What's New

### 1. Deployment Scripts

Comprehensive deployment scripts in the `scripts/` and `scripts/deploy/` directories:

- **`deploy_canary.sh`** - Deploy with 10% traffic split
- **`promote_canary.sh`** - Promote to 50% or 100%
- **`rollback.sh`** - One-command rollback
- **`deploy/deploy.sh`** - Multi-environment deployment automation
- **`deploy/pre-deploy-checks.sh`** - Pre-deployment validation
- **`deploy/verify.sh`** - Post-deployment SLO verification

### 2. GitHub Actions Workflow

New workflow: `.github/workflows/release.yml`

Supports:
- Automatic canary deployment on git tags
- Manual workflow dispatch for promotion/rollback
- Smoke tests between stages
- Deployment history artifacts

### 3. Function Configuration

New file: `functions/src/config/deployment.ts`

Defines per-function settings:
- `minInstances` (for warm start)
- `maxInstances` (for scaling)
- `region` (us-central1)
- `memory` (128MB - 8GB)
- `timeoutSeconds`

### 4. Android Integration

New guide: `docs/ANDROID_STAGED_ROLLOUT.md`

Documents how to integrate Play Store staged rollouts using:
- Manual Play Console approach
- Fastlane automation
- Gradle Play Publisher

### 5. Deployment History

New directory: `.deployment-history/`

Tracks all deployments, promotions, and rollbacks as JSON files for audit purposes.

## Quick Start

### Multi-Environment Deployment

For dev and staging environments, use the unified deployment script:

```bash
# Deploy to dev environment
./scripts/deploy/deploy.sh --env dev

# Deploy to staging with verification
./scripts/deploy/deploy.sh --env staging
./scripts/deploy/verify.sh --env staging

# Deploy functions only to staging
./scripts/deploy/deploy.sh --env staging --functions-only
```

### Deploy Canary (10%) - Production Only

**Option A: Via Git Tag (Automatic)**
```bash
git tag v1.2.0
git push origin v1.2.0
# Workflow automatically deploys at 10%
```

**Option B: Manual Script**
```bash
./scripts/deploy_canary.sh --project sierra-painting-prod --tag v1.2.0
```

### Monitor Deployment

1. Run automated verification:
   ```bash
   ./scripts/deploy/verify.sh --env prod
   ```

2. Check Firebase Console:
   - https://console.firebase.google.com/project/sierra-painting-prod/functions

3. Check Cloud Run traffic split:
   - https://console.cloud.google.com/run?project=sierra-painting-prod

4. Monitor metrics (automated in verify.sh):
   - Error rate < 1% (prod) or < 2% (staging)
   - P95 latency < 2s (prod) or < 3s (staging)
   - No critical errors

5. Verify key user journeys:
   - Login functionality
   - Estimate creation
   - Invoice export

### Promote to 50%

**Option A: Via Workflow Dispatch**
1. Go to Actions tab in GitHub
2. Select "Release Workflow - Canary Deployment"
3. Click "Run workflow"
4. Select stage: `promote-50`
5. Select project: `sierra-painting-prod`

**Option B: Manual Script**
```bash
./scripts/promote_canary.sh --project sierra-painting-prod --stage 50
```

### Promote to 100%

After monitoring 50% for 6-24 hours:

**Option A: Via Workflow Dispatch**
- Same as above, but select stage: `promote-100`

**Option B: Manual Script**
```bash
./scripts/promote_canary.sh --project sierra-painting-prod --stage 100
```

### Rollback (If Issues Detected)

**Option A: Via Workflow Dispatch**
- Select stage: `rollback`

**Option B: Manual Script (Fast - Traffic Split)**
```bash
./scripts/rollback.sh --project sierra-painting-prod
# Routes 100% traffic to PREVIOUS revision in < 5 minutes
```

**Option C: Manual Script (Full Redeploy)**
```bash
./scripts/rollback.sh --project sierra-painting-prod --method redeploy --version v1.1.0
# Redeploys from git tag in ~10 minutes
```

## Workflow Diagram

```
┌─────────────────────────────────────────────────┐
│ 1. Push Tag (v1.2.0)                           │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│ 2. Workflow: Lint, Test, Build                 │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│ 3. Smoke Tests (Emulator)                      │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│ 4. Deploy Canary (10% Traffic)                 │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│ 5. Monitor for 6-24 hours                      │
│    - Error rate < 2%                           │
│    - P95 latency < 1s                          │
│    - No critical errors                        │
└─────────────────┬───────────────────────────────┘
                  │
                  ▼
        ┌─────────────────┐
        │ Issues Found?   │
        └────┬───────┬────┘
             │       │
          Yes│       │No
             │       │
             ▼       ▼
    ┌─────────┐  ┌────────────────────────┐
    │Rollback │  │Promote to 50%          │
    └─────────┘  └──────────┬─────────────┘
                            │
                            ▼
                 ┌────────────────────────┐
                 │Monitor for 6-24 hours  │
                 └──────────┬─────────────┘
                            │
                            ▼
                   ┌─────────────────┐
                   │ Issues Found?   │
                   └────┬───────┬────┘
                        │       │
                     Yes│       │No
                        │       │
                        ▼       ▼
                ┌─────────┐  ┌────────────────────┐
                │Rollback │  │Promote to 100%     │
                └─────────┘  └────────────────────┘
```

## Key Features

### 1. Progressive Exposure
- Start with 10% of users
- Gradual increase to 50%, then 100%
- Limits blast radius of issues

### 2. Automated Gates
- Smoke tests must pass before promotion
- Manual confirmation of metrics required
- Health checks before each stage

### 3. Instant Rollback
- Traffic split method: < 5 minutes
- Routes 100% to previous revision
- No code changes needed

### 4. Audit Trail
- All deployments recorded in `.deployment-history/`
- Workflow artifacts retained for 90 days
- Git history preserves full timeline

### 5. Multi-Platform Support
- Cloud Functions (Gen 2 with Cloud Run)
- Android (Play Store staged rollout)
- Future: iOS (TestFlight + App Store)

## Architecture

### Cloud Functions (Gen 2)
- Uses Cloud Run traffic splitting
- Maintains multiple revisions
- Routes traffic by percentage
- Instant rollback to PREVIOUS revision

### Function Configuration
- `minInstances: 1` for critical functions (warm start)
- `region: us-central1` (consistent region)
- `memory: 256MB` for most functions
- `timeoutSeconds: 30` for user-facing functions

### Android (Play Store)
- Staged rollout feature in Play Console
- Fastlane for automation
- Same 10% → 50% → 100% progression
- Halt/rollback via Play Console

## Monitoring Dashboard

### Firebase Console
- Function invocations, errors, latency
- https://console.firebase.google.com/project/sierra-painting-prod/functions

### Cloud Run Console
- Traffic split visualization
- Revision history
- https://console.cloud.google.com/run?project=sierra-painting-prod

### Error Reporting
- Real-time error tracking
- https://console.cloud.google.com/errors?project=sierra-painting-prod

### Crashlytics (Mobile)
- Crash-free rate
- ANR rate
- https://console.firebase.google.com/project/sierra-painting-prod/crashlytics

## Best Practices

1. **Always Tag Releases**
   ```bash
   git tag -a v1.2.0 -m "Release v1.2.0"
   git push origin v1.2.0
   ```

2. **Monitor Actively**
   - Set up alerts for error rate > 2%
   - Check metrics every 2-4 hours during rollout
   - Have on-call engineer during promotions

3. **Document Issues**
   - Keep notes in `.deployment-history/`
   - Update CHANGELOG.md
   - Post-mortem for rollbacks

4. **Test Internally First**
   - Use staging environment
   - Internal testing tracks
   - Beta user group

5. **Communicate**
   - Notify team when starting rollout
   - Share monitoring links
   - Announce completion

## Troubleshooting

### Traffic Split Not Working
- Check if functions are Gen 2 (Cloud Run)
- Gen 1 functions don't support traffic splitting
- Alternative: Use Firebase Remote Config

### High Error Rate
- Immediately halt promotion
- Review error logs
- Consider rollback if > 5%

### Performance Degradation
- Check cold start times
- Verify minInstances configuration
- Monitor P95 latency

### Rollback Failed
- Try alternative method (traffic → redeploy)
- Use Firebase Remote Config to disable features
- Contact Firebase support if needed

## Related Documentation

- [CANARY_DEPLOYMENT.md](docs/CANARY_DEPLOYMENT.md) - Detailed guide
- [ANDROID_STAGED_ROLLOUT.md](docs/ANDROID_STAGED_ROLLOUT.md) - Android setup
- [rollout-rollback.md](docs/rollout-rollback.md) - Rollback procedures
- [BACKEND_PERFORMANCE.md](docs/BACKEND_PERFORMANCE.md) - Performance optimization
- [scripts/README.md](scripts/README.md) - Script documentation

## Support

For issues or questions:
1. Check existing documentation
2. Review deployment history logs
3. Check Firebase/Cloud Run consoles
4. Contact team lead or DevOps

## Next Steps

1. **Deploy First Canary**: Use the scripts to deploy at 10%
2. **Monitor Metrics**: Set up dashboards and alerts
3. **Document Process**: Add team-specific notes
4. **Iterate**: Improve based on experience

---

**Ready to deploy?** Start with the Quick Start section above! 🚀
