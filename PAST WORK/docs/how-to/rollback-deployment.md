# Roll back a deployment

This guide shows you how to roll back a deployment if issues are detected.

## When to roll back

Roll back when:

- Critical bugs affect core functionality
- Performance degrades significantly
- Data integrity issues discovered
- Security vulnerability exposed

**Do not roll back for**:

- Minor UI issues
- Non-critical bugs
- Issues that can be fixed with feature flags

## Rollback methods

### Method 1: Feature flags (fastest)

Use feature flags for quick rollback without redeployment.

1. Identify problematic feature:

   ```bash
   # Check recent deployments
   git log --oneline -10
   ```

2. Disable feature flag in Firebase Console:

   - Visit Remote Config
   - Find relevant flag (e.g., `features.newInvoiceFlow`)
   - Set to `false`
   - Publish changes

3. Verify flag updated:

   ```bash
   # Check current config
   firebase remoteconfig:get
   ```

**Downtime**: None (changes propagate in < 1 minute)

### Method 2: Redeploy previous version

Use for issues that can't be fixed with feature flags.

1. Identify previous stable version:

   ```bash
   git tag --sort=-version:refname | head -5
   ```

2. Checkout previous version:

   ```bash
   git checkout v1.2.0  # Replace with stable version
   ```

3. Redeploy:

   ```bash
   # Staging first
   firebase use staging
   firebase deploy

   # After verification, production
   firebase use production
   firebase deploy
   ```

**Downtime**: 5-15 minutes during deployment

### Method 3: Cloud Functions rollback

Use for function-specific issues without full app rollback.

1. List recent function versions:

   ```bash
   gcloud functions list --project=sierra-painting-prod
   ```

2. Roll back specific function:

   ```bash
   # Roll back to previous version
   gcloud functions deploy FUNCTION_NAME \
     --project=sierra-painting-prod \
     --runtime=nodejs18 \
     --source=PREVIOUS_SOURCE \
     --entry-point=ENTRY_POINT
   ```

3. Verify rollback:

   ```bash
   gcloud functions describe FUNCTION_NAME --project=sierra-painting-prod
   ```

**Downtime**: < 5 minutes for single function

## Rollback procedure

### 1. Assess impact

1. Check error rates:

   ```bash
   # View recent errors
   firebase crashlytics:reports
   ```

2. Check affected users:

   - Review Crashlytics dashboard
   - Check Firebase Analytics for user impact
   - Review support tickets/reports

3. Document issue:

   - Create incident report
   - Note symptoms and affected features
   - Record when issue started

### 2. Notify team

1. Post in deployment channel:

   ```
   🚨 PRODUCTION ISSUE
   Version: v1.3.0
   Impact: Invoice creation failing
   Action: Rolling back to v1.2.0
   ETA: 10 minutes
   ```

2. Notify stakeholders:

   - Product owner
   - Support team
   - Affected users (if major)

### 3. Execute rollback

Choose appropriate method (feature flag, redeploy, or function rollback).

For full redeploy:

```bash
# 1. Checkout stable version
git checkout v1.2.0

# 2. Verify tests still pass
flutter test
cd functions && npm test && cd ..

# 3. Deploy to production
firebase use production
firebase deploy

# 4. Verify deployment
npm run smoke:production
```

### 4. Verify rollback

1. Run smoke tests:

   ```bash
   npm run smoke:production
   ```

2. Test affected functionality manually

3. Monitor for 30 minutes:

   - Error rates return to normal
   - Performance metrics stable
   - User reports decrease

### 5. Document and follow up

1. Update incident report with resolution

2. Create post-mortem:

   - What went wrong
   - Why it wasn't caught in testing
   - How to prevent in future

3. Plan fix:

   - Create issue for proper fix
   - Add tests to prevent regression
   - Schedule fix for next sprint

## Emergency contacts

- **DevOps lead**: [Contact info]
- **Product owner**: [Contact info]
- **On-call engineer**: Check PagerDuty

## Prevention

Prevent future rollbacks:

- Always test in staging first
- Use canary deployments for risky changes
- Enable feature flags for new features
- Monitor metrics after deployment
- Have rollback plan before deploying

## Troubleshooting

**Rollback fails with "Invalid version"**:

- Ensure tag exists: `git tag | grep v1.2.0`
- Try fetching tags: `git fetch --tags`

**Functions won't deploy**:

- Check GCP permissions
- Verify billing enabled
- Review Cloud Functions logs

**Feature flag not updating**:

- Check Remote Config publish status
- Verify app has internet connection
- Wait up to 12 hours for full propagation

## Next steps

- [Deploy to production](deploy-production.md)
- [Monitor performance](check-performance.md)
- [View Cloud Functions logs](view-function-logs.md)

---