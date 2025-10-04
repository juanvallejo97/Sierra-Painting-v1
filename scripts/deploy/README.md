# Deployment Scripts

This directory contains automated deployment scripts for the Sierra Painting application.

## Overview

The deployment system supports:
- Multi-environment deployments (dev, staging, prod)
- Pre-deploy validation and smoke tests
- Post-deploy verification with SLO checks
- Feature flag integration
- Rollback procedures

## Scripts

### deploy.sh

Main deployment script supporting all environments.

```bash
# Deploy to staging
./scripts/deploy/deploy.sh --env staging

# Deploy functions only to production
./scripts/deploy/deploy.sh --env prod --functions-only

# Deploy with pre-checks skipped (not recommended)
./scripts/deploy/deploy.sh --env dev --skip-checks

# Dry run to see what would be deployed
./scripts/deploy/deploy.sh --env staging --dry-run
```

**Options:**
- `--env <environment>` - Target environment (dev, staging, prod) [required]
- `--skip-checks` - Skip pre-deploy validation
- `--functions-only` - Deploy only Cloud Functions
- `--rules-only` - Deploy only Firestore/Storage rules
- `--hosting-only` - Deploy only hosting
- `--dry-run` - Show deployment plan without executing

### pre-deploy-checks.sh

Runs validation checks before deployment:
- Smoke tests
- Feature flag verification
- Database migration checks
- Security rules tests
- Rollback plan validation

Called automatically by `deploy.sh` unless `--skip-checks` is used.

```bash
./scripts/deploy/pre-deploy-checks.sh staging
```

### verify.sh

Post-deployment verification with SLO probes and key journey testing.

```bash
# Standard verification
./scripts/deploy/verify.sh --env staging

# Quick checks only (< 5 minutes)
./scripts/deploy/verify.sh --env prod --quick

# Full verification suite
./scripts/deploy/verify.sh --env staging --full
```

**Verifies:**
- Function availability
- Error rate < 2% (staging) or < 1% (prod)
- P95 latency < 3s (staging) or < 2s (prod)
- Key user journeys:
  - Login functionality
  - Estimate creation
  - Invoice export
- Security rules enforcement
- Performance monitoring
- Crash monitoring

## Deployment Workflow

### Standard Deployment

```bash
# 1. Deploy to environment
./scripts/deploy/deploy.sh --env staging

# 2. Verify deployment
./scripts/deploy/verify.sh --env staging

# 3. Monitor for issues
# Check dashboards linked in verification output

# 4. If issues found, rollback
../rollback.sh --project sierra-painting-staging
```

### Canary Deployment (Production)

For production deployments, use the canary deployment system:

```bash
# 1. Deploy canary (10% traffic)
../deploy_canary.sh --project sierra-painting-prod --tag v1.2.0

# 2. Verify canary
./verify.sh --env prod --quick

# 3. Monitor for 6-24 hours
# Check error rates, latency, user feedback

# 4. Promote to 50%
../promote_canary.sh --project sierra-painting-prod --stage 50

# 5. Monitor and promote to 100%
../promote_canary.sh --project sierra-painting-prod --stage 100
```

## Environment Configuration

Environments are configured in `.firebaserc`:

- **dev**: `sierra-painting-dev` - Development and testing
- **staging**: `sierra-painting-staging` - Pre-production validation
- **prod**: `sierra-painting-prod` - Live production

## Pre-Deploy Hooks

The deployment system includes pre-deploy hooks configured in `firebase.json`:

### Hosting Pre-Deploy
- Runs `pre-deploy-checks.sh`
- Validates smoke tests pass

### Functions Pre-Deploy
- Runs `npm run lint`
- Runs `npm run typecheck`
- Runs `npm test`
- Blocks deployment on failures

## SLO Targets

### Staging
- **Error Rate**: < 2%
- **P95 Latency**: < 3s
- **Function Availability**: > 99%
- **Cold Start**: < 5s

### Production
- **Error Rate**: < 1%
- **P95 Latency**: < 2s
- **Function Availability**: > 99.9%
- **Cold Start**: < 5s

## Key User Journeys

Critical flows to verify after deployment:

### 1. Login
- User signup with email/password
- User login
- Token refresh
- Logout

### 2. Estimate Creation
- Create new estimate
- Add line items
- Calculate totals
- Save estimate
- View in list

### 3. Invoice Export
- Convert estimate to invoice
- Generate PDF
- Mark as sent
- Record payment
- View payment history

## Feature Flags

Feature flags are managed via Firebase Remote Config:

```bash
# List all flags
../remote-config/manage-flags.sh list --project sierra-painting-prod

# Enable a feature
../remote-config/manage-flags.sh enable feature_new_ui --project sierra-painting-prod

# Disable a feature (instant rollback)
../remote-config/manage-flags.sh disable feature_new_ui --project sierra-painting-prod
```

## Rollback Procedures

### Quick Rollback (< 5 minutes)
```bash
# Route 100% traffic to previous revision
../rollback.sh --project sierra-painting-prod
```

### Full Rollback (redeploy from tag)
```bash
# Redeploy previous version from git tag
../rollback.sh --project sierra-painting-prod --method redeploy --version v1.1.0
```

### Feature Flag Rollback (instant)
```bash
# Disable problematic feature
../remote-config/manage-flags.sh disable feature_name --project sierra-painting-prod
```

## Database Migrations

### Guidelines for Reversible Migrations

1. **Additive Changes** (safe):
   - Add new fields (optional)
   - Add new collections
   - Add new indexes

2. **Breaking Changes** (require backfill):
   - Rename fields
   - Change field types
   - Remove fields
   - Schema restructuring

3. **Migration Pattern**:
   ```
   1. Add new field (optional)
   2. Backfill data (gradual)
   3. Update code to use new field
   4. Deploy code changes
   5. Remove old field (after verification)
   ```

4. **Rollback Support**:
   - Keep old fields during transition
   - Document rollback steps in MIGRATION_NOTES.md
   - Test rollback procedure before deployment

## Monitoring Dashboards

After deployment, monitor these dashboards:

### Firebase Console
`https://console.firebase.google.com/project/{PROJECT_ID}`

### Cloud Functions
`https://console.cloud.google.com/functions/list?project={PROJECT_ID}`

### Logs
`https://console.cloud.google.com/logs/query?project={PROJECT_ID}`

### Error Reporting
`https://console.cloud.google.com/errors?project={PROJECT_ID}`

### Performance
`https://console.firebase.google.com/project/{PROJECT_ID}/performance`

### Crashlytics
`https://console.firebase.google.com/project/{PROJECT_ID}/crashlytics`

## Deployment History

All deployments are logged to `.deployment-history/`:
- Deployment records
- Verification reports
- Rollback logs
- Canary promotion logs

## CI/CD Integration

The deployment scripts integrate with GitHub Actions:

- **Staging**: Automatic deployment on push to `main`
- **Production**: Manual deployment on tag `v*`
- **Smoke Tests**: Run in all workflows
- **Verification**: Post-deploy checks in CI

See `.github/workflows/` for workflow definitions.

## Troubleshooting

### Pre-deploy checks fail
```bash
# Run checks manually to see details
./scripts/deploy/pre-deploy-checks.sh staging

# Fix issues and retry
./scripts/deploy/deploy.sh --env staging
```

### Deployment fails
```bash
# Check Firebase CLI authentication
firebase login

# Verify project access
firebase projects:list

# Check deployment logs
firebase deploy --debug
```

### Post-verification fails
```bash
# Review verification report
cat .deployment-history/verification-{env}-{timestamp}.txt

# Check monitoring dashboards
# Fix issues or rollback
```

## Best Practices

1. **Always verify before promoting**: Run verification after each deployment
2. **Monitor actively**: Check dashboards frequently during rollout
3. **Use canary for prod**: Deploy to 10% → 50% → 100% for production
4. **Test rollback**: Practice rollback procedures regularly
5. **Document migrations**: Keep MIGRATION_NOTES.md up to date
6. **Feature flag risky changes**: Use flags for easy rollback
7. **Retain artifacts**: Keep deployment logs for audit trail

## Related Documentation

- [CANARY_QUICKSTART.md](../../CANARY_QUICKSTART.md) - Canary deployment guide
- [VERIFICATION_CHECKLIST.md](../../VERIFICATION_CHECKLIST.md) - Verification procedures
- [docs/rollout-rollback.md](../../docs/rollout-rollback.md) - Rollback procedures
- [docs/CANARY_DEPLOYMENT.md](../../docs/CANARY_DEPLOYMENT.md) - Detailed deployment guide
- [FIREBASE_CONFIGURATION.md](../../FIREBASE_CONFIGURATION.md) - Firebase setup

## Support

For issues or questions:
1. Check deployment logs in `.deployment-history/`
2. Review Firebase/Cloud Run consoles
3. Check GitHub Actions workflow runs
4. Contact team lead or DevOps
