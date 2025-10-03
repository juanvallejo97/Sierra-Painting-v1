# GitHub Environments Setup Guide

> **Purpose**: Instructions for configuring GitHub Environments for Sierra Painting CI/CD
>
> **Last Updated**: 2024

---

## Overview

Sierra Painting uses GitHub Environments to manage deployment secrets and require manual approvals for production deployments.

**Environments:**
- `staging` - Automatic deployment on push to `main`
- `production` - Manual approval required for tag-based deployments

---

## Environment Setup

### Prerequisites

- Repository admin access
- Firebase service account credentials
- Firebase project IDs for staging and production

---

## Creating Environments

### 1. Navigate to Repository Settings

1. Go to: https://github.com/juanvallejo97/Sierra-Painting-v1/settings/environments
2. Click "New environment"

### 2. Create Staging Environment

**Name:** `staging`

**Deployment branches:**
- ✅ Selected branches only
- Add rule: `main`

**Environment variables (not secrets!):**
- `GCP_WORKLOAD_IDENTITY_PROVIDER`
  - Value: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider`
  - Get from: GCP Workload Identity setup (see [gcp-workload-identity-setup.md](./gcp-workload-identity-setup.md))
- `GCP_SERVICE_ACCOUNT`
  - Value: `ci-deployer@sierra-painting-staging.iam.gserviceaccount.com`
  - Get from: GCP service account created in Workload Identity setup
- `FIREBASE_PROJECT_ID` (optional)
  - Value: `sierra-painting-staging`

**Protection rules:**
- ⬜ Required reviewers (not needed for staging)
- ⬜ Wait timer (not needed for staging)
- ⬜ Deployment branches (configured above)

### 3. Create Production Environment

**Name:** `production`

**Deployment branches:**
- ✅ All branches (to allow tag-based deployments)

**Environment variables (not secrets!):**
- `GCP_WORKLOAD_IDENTITY_PROVIDER`
  - Value: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider`
  - Get from: GCP Workload Identity setup (see [gcp-workload-identity-setup.md](./gcp-workload-identity-setup.md))
  - ⚠️ **IMPORTANT**: Use production project's Workload Identity Provider
- `GCP_SERVICE_ACCOUNT`
  - Value: `ci-deployer@sierra-painting-prod.iam.gserviceaccount.com`
  - Get from: GCP service account created in Workload Identity setup
- `FIREBASE_PROJECT_ID` (optional)
  - Value: `sierra-painting-prod`

**Protection rules:**
- ✅ **Required reviewers**: 1 reviewer
  - Add: Repository maintainers or specific users who can approve production deployments
- ⬜ Wait timer: 0 minutes (or set delay if desired)
- ✅ **Deployment branches**: All branches (to allow tags)

---

## Getting GCP Workload Identity Configuration

### For Staging

Follow the [GCP Workload Identity Setup Guide](./gcp-workload-identity-setup.md) to:

1. Create Workload Identity Pool in `sierra-painting-staging`
2. Create Workload Identity Provider bound to GitHub
3. Create `ci-deployer` service account with minimum required roles
4. Bind service account to Workload Identity Pool
5. Get configuration values:
   - `GCP_WORKLOAD_IDENTITY_PROVIDER`: Full provider path
   - `GCP_SERVICE_ACCOUNT`: Service account email

### For Production

Follow the same steps for `sierra-painting-prod`:

1. Create Workload Identity Pool in `sierra-painting-prod`
2. Create Workload Identity Provider bound to GitHub
3. Create `ci-deployer` service account with minimum required roles
4. Bind service account to Workload Identity Pool
5. Get configuration values:
   - `GCP_WORKLOAD_IDENTITY_PROVIDER`: Full provider path
   - `GCP_SERVICE_ACCOUNT`: Service account email

**⚠️ Security Notes:**
- Each environment has its own Workload Identity Pool and service account
- No long-lived credentials are stored in GitHub
- Authentication tokens are short-lived and automatically rotated
- Access is restricted to specific GitHub repository via attribute conditions
- IAM roles follow principle of least privilege

---

## Verifying Setup

### Test Staging Deployment

1. Make a small change and push to `main` branch:
   ```bash
   git checkout main
   echo "# Test" >> README.md
   git add README.md
   git commit -m "test: Verify staging deployment"
   git push origin main
   ```

2. Check GitHub Actions:
   - Go to: https://github.com/juanvallejo97/Sierra-Painting-v1/actions
   - Verify "Staging CI/CD Pipeline" workflow starts
   - Check that deployment to staging succeeds

### Test Production Deployment (Manual Approval)

1. Create a test tag:
   ```bash
   git tag v0.0.1-test
   git push origin v0.0.1-test
   ```

2. Check GitHub Actions:
   - Go to: https://github.com/juanvallejo97/Sierra-Painting-v1/actions
   - Verify "Production CI/CD Pipeline" workflow starts
   - Workflow should **wait for approval** at production deployment step

3. Approve deployment:
   - Click on the workflow run
   - Click "Review deployments"
   - Select "production" environment
   - Click "Approve and deploy"
   - Workflow should complete after approval

4. Clean up test tag:
   ```bash
   git tag -d v0.0.1-test
   git push origin :refs/tags/v0.0.1-test
   ```

---

## Environment Configuration

### Staging Environment

**Purpose**: Integration testing and QA

**Deployment Trigger:**
- Automatic on push to `main` branch

**Approval Required:** No

**Usage:**
```yaml
# In .github/workflows/staging.yml
environment: staging
```

**Secrets Available:**
- None (uses Workload Identity Federation)

**Variables Available:**
- `GCP_WORKLOAD_IDENTITY_PROVIDER` - Workload Identity Provider path
- `GCP_SERVICE_ACCOUNT` - Service account email for staging

### Production Environment

**Purpose**: Live customer-facing application

**Deployment Trigger:**
- Manual, on version tag push (e.g., `v1.0.0`)

**Approval Required:** Yes (1 reviewer)

**Usage:**
```yaml
# In .github/workflows/production.yml
environment:
  name: production
  url: https://console.firebase.google.com/project/sierra-painting-prod/overview
```

**Secrets Available:**
- None (uses Workload Identity Federation)

**Variables Available:**
- `GCP_WORKLOAD_IDENTITY_PROVIDER` - Workload Identity Provider path
- `GCP_SERVICE_ACCOUNT` - Service account email for production

---

## Troubleshooting

### Issue: "Environment not found"

**Cause:** Environment hasn't been created in repository settings

**Solution:**
1. Go to repository Settings → Environments
2. Create the required environment (staging or production)
3. Re-run the workflow

### Issue: "Secret not found"

**Cause:** `FIREBASE_SERVICE_ACCOUNT` secret not configured in environment

**Solution:**
1. Go to repository Settings → Environments → [Environment name]
2. Add secret: `FIREBASE_SERVICE_ACCOUNT`
3. Paste Firebase service account JSON
4. Re-run the workflow

### Issue: "Deployment waiting for approval" (Production)

**Expected behavior:** Production deployments require manual approval

**Solution:**
1. Go to Actions tab
2. Click on the workflow run
3. Click "Review deployments"
4. Select "production"
5. Click "Approve and deploy"

### Issue: "User not authorized to approve"

**Cause:** User is not in the list of required reviewers

**Solution:**
1. Repository admin: Go to Settings → Environments → production
2. Add user to "Required reviewers" list
3. User can now approve deployments

---

## Security Best Practices

### Service Account Management

- ✅ Use separate service accounts for staging and production
- ✅ Grant minimum required permissions (via IAM roles, not direct keys)
- ✅ Use Workload Identity Federation (no JSON keys)
- ✅ Monitor service account usage in Cloud Console
- ✅ Review IAM roles quarterly and remove unused permissions
- ✅ Enable audit logging for all service account activities
- ❌ Never commit service account JSON to git
- ❌ Never create long-lived service account keys
- ❌ Never share Workload Identity configuration outside team
- ❌ Don't use production credentials in staging

### Access Control

- ✅ Limit production environment approvers to senior engineers/leads
- ✅ Use branch protection rules on `main` branch
- ✅ Require PR reviews before merging
- ✅ Enable GitHub Advanced Security (secret scanning, dependency review)
- ✅ Audit environment changes regularly

### Workflow Security

- ✅ Use `google-github-actions/auth@v2` with Workload Identity Federation
- ✅ Add `permissions: { id-token: write, contents: read }` to jobs
- ✅ Pin workflow action versions (e.g., `@v4` not `@latest`)
- ✅ Use `--non-interactive` flag for Firebase CLI commands
- ✅ Set `continue-on-error: false` for critical steps
- ✅ Review workflow logs after each deployment
- ❌ Never use `credentials_json` parameter (use `workload_identity_provider`)
- ❌ Never set `GOOGLE_APPLICATION_CREDENTIALS` environment variable

---

## Maintenance

### Regular Tasks

**Monthly:**
- [ ] Review environment access (who has approval rights)
- [ ] Check for unused secrets
- [ ] Verify workflow runs are succeeding

**Quarterly:**
- [ ] Review IAM roles for CI/CD service accounts
- [ ] Audit Workload Identity Federation logs for suspicious activity
- [ ] Review and update deployment procedures
- [ ] Audit security settings
- [ ] Verify attribute conditions on Workload Identity Providers

**After Major Changes:**
- [ ] Update environment variables if needed
- [ ] Test both staging and production workflows
- [ ] Document any configuration changes

---

## Related Documentation

- [GCP Workload Identity Setup](./gcp-workload-identity-setup.md) ⭐ **Required Reading**
- [Staging Workflow](../../.github/workflows/staging.yml)
- [Production Workflow](../../.github/workflows/production.yml)
- [Prevent JSON Credentials Policy](../../.github/workflows/prevent-json-credentials.yml)
- [Deployment Checklist](../deployment_checklist.md)
- [Rollout & Rollback Strategy](../rollout-rollback.md)
- [Security Guide](../Security.md)

---

## Support

**Issues with GitHub Environments:**
- GitHub Docs: https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment
- Repository maintainers

**Issues with GCP Workload Identity:**
- [GCP Workload Identity Setup Guide](./gcp-workload-identity-setup.md)
- Google Cloud IAM: https://console.cloud.google.com/iam-admin
- Workload Identity Federation: https://cloud.google.com/iam/docs/workload-identity-federation

**Issues with Firebase Authentication:**
- Firebase Docs: https://firebase.google.com/docs/admin/setup
- Google Cloud IAM: https://console.cloud.google.com/iam-admin
- [ ] Document any configuration changes

---

## Related Documentation

- [GCP Workload Identity Setup](./gcp-workload-identity-setup.md) ⭐ **Required Reading**
- [Staging Workflow](../../.github/workflows/staging.yml)
- [Production Workflow](../../.github/workflows/production.yml)
- [Prevent JSON Credentials Policy](../../.github/workflows/prevent-json-credentials.yml)
- [Deployment Checklist](../deployment_checklist.md)
- [Rollout & Rollback Strategy](../rollout-rollback.md)
- [Security Guide](../Security.md)

---

## Support

**Issues with GitHub Environments:**
- GitHub Docs: https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment
- Repository maintainers

**Issues with GCP Workload Identity:**
- [GCP Workload Identity Setup Guide](./gcp-workload-identity-setup.md)
- Google Cloud IAM: https://console.cloud.google.com/iam-admin
- Workload Identity Federation: https://cloud.google.com/iam/docs/workload-identity-federation

**Issues with Firebase Authentication:**
- Firebase Docs: https://firebase.google.com/docs/admin/setup
- Google Cloud IAM: https://console.cloud.google.com/iam-admin

---

**Last Updated**: 2024  
**Review Schedule**: Quarterly  
**Owner**: DevOps Team
