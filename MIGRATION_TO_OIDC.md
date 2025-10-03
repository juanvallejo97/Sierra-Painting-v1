# Migration to Workload Identity Federation - Implementation Guide

## Overview

This repository has been updated to use GCP Workload Identity Federation instead of long-lived service account JSON keys for CI/CD authentication.

**Status:** ✅ Code changes complete - Awaiting GCP configuration

---

## What Changed

### Workflow Files Updated

- ✅ `.github/workflows/staging.yml` - Uses OIDC authentication
- ✅ `.github/workflows/production.yml` - Uses OIDC authentication
- ✅ `.github/workflows/prevent-json-credentials.yml` - New policy enforcement
- ✅ `.github/workflows/security.yml` - Enhanced secret scanning

### Documentation Updated

- ✅ `docs/ops/gcp-workload-identity-setup.md` - **NEW** Complete setup guide
- ✅ `docs/ops/github-environments.md` - Updated for OIDC
- ✅ `docs/ops/CI_CD_IMPLEMENTATION.md` - Updated authentication section
- ✅ `docs/Security.md` - Added Workload Identity mention

### Scripts Updated

- ✅ `scripts/ci/firebase-login.sh` - Validates OIDC (rejects JSON keys)

---

## Required Actions (Repository Administrator)

### Step 1: Complete GCP Workload Identity Setup

Follow the comprehensive guide:
📖 **[docs/ops/gcp-workload-identity-setup.md](docs/ops/gcp-workload-identity-setup.md)**

This involves:
1. Enable required GCP APIs
2. Create Workload Identity Pool for staging
3. Create Workload Identity Pool for production
4. Create `ci-deployer` service accounts (one per environment)
5. Grant least-privilege IAM roles
6. Bind service accounts to Workload Identity
7. Extract configuration values

**Time estimate:** 30-45 minutes per environment

---

### Step 2: Update GitHub Environment Configuration

#### For Staging Environment

1. Navigate to: https://github.com/juanvallejo97/Sierra-Painting-v1/settings/environments/staging
2. **Remove old secret:** `FIREBASE_SERVICE_ACCOUNT` (if exists)
3. **Add new variables:**
   - Variable name: `GCP_WORKLOAD_IDENTITY_PROVIDER`
   - Value: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider`
   
   - Variable name: `GCP_SERVICE_ACCOUNT`
   - Value: `ci-deployer@sierra-painting-staging.iam.gserviceaccount.com`

#### For Production Environment

1. Navigate to: https://github.com/juanvallejo97/Sierra-Painting-v1/settings/environments/production
2. **Remove old secret:** `FIREBASE_SERVICE_ACCOUNT` (if exists)
3. **Add new variables:**
   - Variable name: `GCP_WORKLOAD_IDENTITY_PROVIDER`
   - Value: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider`
   
   - Variable name: `GCP_SERVICE_ACCOUNT`
   - Value: `ci-deployer@sierra-painting-prod.iam.gserviceaccount.com`

**Note:** Use environment **variables**, not secrets. The security comes from the Workload Identity binding, not from hiding these values.

---

### Step 3: Verify Deployment

1. **Test staging deployment:**
   ```bash
   git checkout main
   git pull
   # Push will trigger staging deployment
   ```

2. **Check workflow logs:**
   - Navigate to: https://github.com/juanvallejo97/Sierra-Painting-v1/actions
   - Verify "Authenticate to Google Cloud" step succeeds
   - Expected: "Successfully configured Workload Identity Federation authentication"

3. **Test production deployment:**
   ```bash
   # Create a test tag
   git tag v1.0.0-test
   git push origin v1.0.0-test
   ```
   - Approve deployment when prompted
   - Verify successful deployment

---

### Step 4: Revoke Old Service Account Keys

Once you've verified OIDC authentication works:

1. **List existing keys:**
   ```bash
   # For staging
   gcloud iam service-accounts keys list \
     --iam-account=firebase-adminsdk-XXXXX@sierra-painting-staging.iam.gserviceaccount.com \
     --project=sierra-painting-staging
   
   # For production
   gcloud iam service-accounts keys list \
     --iam-account=firebase-adminsdk-XXXXX@sierra-painting-prod.iam.gserviceaccount.com \
     --project=sierra-painting-prod
   ```

2. **Delete old keys:**
   ```bash
   gcloud iam service-accounts keys delete KEY_ID \
     --iam-account=SERVICE_ACCOUNT_EMAIL \
     --project=PROJECT_ID
   ```

3. **Verify in GitHub:**
   - Ensure `FIREBASE_SERVICE_ACCOUNT` secrets are removed from both environments

---

### Step 5: Enable GitHub Secret Scanning

1. Navigate to: https://github.com/juanvallejo97/Sierra-Painting-v1/settings/security_analysis
2. Enable:
   - ✅ Secret scanning
   - ✅ Push protection (blocks commits with secrets)
3. Review existing alerts (if any) and resolve

---

## Rollback Plan (Emergency Only)

If you need to temporarily revert to JSON keys:

1. **Create temporary service account key:**
   ```bash
   gcloud iam service-accounts keys create temp-key.json \
     --iam-account=ci-deployer@PROJECT_ID.iam.gserviceaccount.com \
     --project=PROJECT_ID
   ```

2. **Store in GitHub secret:**
   - Add secret `FIREBASE_SERVICE_ACCOUNT` with JSON content

3. **Revert workflow changes:**
   ```yaml
   # In staging.yml and production.yml
   - name: Authenticate to Google Cloud
     uses: google-github-actions/auth@v2
     with:
       credentials_json: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
   ```

4. **After resolution, migrate back to OIDC and delete the key!**

---

## Verification Checklist

After completing the migration:

- [ ] GCP Workload Identity Pool created for staging
- [ ] GCP Workload Identity Pool created for production
- [ ] Service accounts created with least-privilege roles
- [ ] GitHub environment variables configured (staging)
- [ ] GitHub environment variables configured (production)
- [ ] Old `FIREBASE_SERVICE_ACCOUNT` secrets removed
- [ ] Staging deployment tested and successful
- [ ] Production deployment tested and successful
- [ ] Old service account keys revoked
- [ ] GitHub Secret Scanning enabled
- [ ] Policy workflow running successfully
- [ ] Team notified of changes
- [ ] Documentation reviewed

---

## Monitoring and Maintenance

### Monthly Tasks

- [ ] Review Workload Identity Federation logs for failed auth attempts
- [ ] Verify no JSON keys exist in repository or GitHub secrets

### Quarterly Tasks

- [ ] Audit IAM roles on `ci-deployer` service accounts
- [ ] Review and remove unused permissions
- [ ] Verify attribute conditions on Workload Identity Providers
- [ ] Test rollback procedure

---

## Troubleshooting

### Error: "Permission denied on service account"

**Cause:** Workload Identity binding not configured or incorrect.

**Solution:** Verify the binding:
```bash
gcloud iam service-accounts get-iam-policy ci-deployer@PROJECT_ID.iam.gserviceaccount.com \
  --project=PROJECT_ID
```

Should show `roles/iam.workloadIdentityUser` for the GitHub repository.

### Error: "Workload Identity Provider not found"

**Cause:** Provider doesn't exist or wrong project number.

**Solution:** List all providers:
```bash
gcloud iam workload-identity-pools list \
  --location=global \
  --project=PROJECT_ID
```

### Error: "Invalid token audience"

**Cause:** Provider configuration mismatch.

**Solution:** Verify the provider configuration and ensure it matches what's in GitHub variables.

### Deployment fails with "insufficient permissions"

**Cause:** Service account doesn't have required IAM roles.

**Solution:** Review and re-add IAM roles as documented in the setup guide.

---

## Support

- **GCP Workload Identity issues:** See [gcp-workload-identity-setup.md](docs/ops/gcp-workload-identity-setup.md)
- **GitHub workflow issues:** See [github-environments.md](docs/ops/github-environments.md)
- **General CI/CD questions:** See [CI_CD_IMPLEMENTATION.md](docs/ops/CI_CD_IMPLEMENTATION.md)
- **Security questions:** See [Security.md](docs/Security.md)

---

## Benefits Achieved

✅ **No long-lived credentials** stored in GitHub Secrets  
✅ **Automatic rotation** - tokens expire after 1 hour  
✅ **Least privilege** - minimal IAM roles per environment  
✅ **Audit trail** - all auth attempts logged in GCP  
✅ **Policy enforcement** - automated checks prevent JSON key reintroduction  
✅ **Reduced attack surface** - no key leakage possible  
✅ **Compliance ready** - meets SOC2, ISO 27001 requirements  

---

**Last Updated:** 2024  
**Migration Status:** Code complete, awaiting GCP configuration  
**Owner:** DevOps Team / Repository Administrators
