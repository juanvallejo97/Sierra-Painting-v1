# Deploy to production

This guide shows you how to deploy Sierra Painting to production.

## Prerequisites

- All tests passing in staging
- Product owner approval
- Production Firebase project access
- 24-hour monitoring plan after deployment

## Deployment process

Production deployments use GitHub Actions with manual approval.

### 1. Prepare release

1. Ensure staging is stable:

   ```bash
   # Check staging deployment
   firebase use staging
   firebase deploy --dry-run
   ```

2. Update CHANGELOG.md with release notes

3. Create a release tag:

   ```bash
   git checkout main
   git pull origin main
   git tag -a v1.0.0 -m "Sprint V1 release"
   ```

### 2. Trigger deployment

1. Push the tag:

   ```bash
   git push origin v1.0.0
   ```

2. Monitor GitHub Actions:

   - Visit [GitHub Actions](https://github.com/juanvallejo97/Sierra-Painting-v1/actions)
   - Click on the triggered workflow
   - Wait for tests and builds to complete

**Expected duration**: 5-10 minutes for tests and builds

### 3. Approve deployment

1. After tests pass, GitHub Actions pauses for approval

2. Review the deployment request:

   - Verify all checks passed
   - Review changes since last release
   - Confirm monitoring plan in place

3. Approve deployment (requires Production Deployer role)

**Approval timeout**: 24 hours (workflow auto-cancels after)

### 4. Monitor deployment

1. Deployment continues automatically after approval

2. Monitor Cloud Functions deployment:

   ```bash
   # Watch function logs
   gcloud functions logs read --project=sierra-painting-prod --limit=50
   ```

3. Check Firebase Console:

   - Visit https://console.firebase.google.com/project/sierra-painting-prod
   - Verify Functions deployed successfully
   - Check Firestore rules updated

**Expected duration**: 5-15 minutes

### 5. Verify deployment

1. Run smoke tests:

   ```bash
   firebase use production
   npm run smoke:production
   ```

2. Test critical flows manually:

   - Sign in as admin
   - Create test time entry
   - Generate test invoice
   - Mark test invoice paid (admin only)

3. Monitor for 24 hours:

   - Crashlytics for crashes
   - Performance monitoring for regressions
   - Cloud Functions logs for errors

## Manual deployment (emergency only)

Use manual deployment only in emergencies when CI is unavailable.

1. Ensure you're using production project:

   ```bash
   firebase use production
   ```

2. Run tests locally:

   ```bash
   flutter test
   cd functions && npm test && cd ..
   ```

3. Deploy:

   ```bash
   firebase deploy
   ```

**Warning**: Manual deployments bypass approval workflows. Document reason in deployment notes.

## Rollback

If issues are detected, see [Roll back a deployment](rollback-deployment.md).

## Troubleshooting

**Approval timeout exceeded**:

- Create new tag with incremented version
- Push new tag to trigger workflow again

**Functions deployment fails**:

- Check Cloud Functions logs for errors
- Verify Node.js version matches `engines` in package.json
- Contact DevOps team if GCP permissions issue

**Firestore rules deployment fails**:

- Validate rules: `firebase deploy --only firestore:rules --dry-run`
- Check for syntax errors in `firestore.rules`

## Post-deployment checklist

- [ ] All smoke tests pass
- [ ] Critical flows tested manually
- [ ] Monitoring configured for 24 hours
- [ ] Team notified of deployment
- [ ] GitHub Release created
- [ ] CHANGELOG.md updated
- [ ] Rollback plan reviewed

## Next steps

- [Monitor performance](check-performance.md)
- [Roll back deployment](rollback-deployment.md) (if needed)
- [View Cloud Functions logs](view-function-logs.md)

---