# GCP Workload Identity Federation Setup for GitHub Actions

## Overview

This guide explains how to configure GCP Workload Identity Federation to allow GitHub Actions to authenticate to Google Cloud Platform without using long-lived service account JSON keys.

**Security Benefits:**
- ✅ No long-lived credentials stored in GitHub Secrets
- ✅ Automatic credential rotation by GCP
- ✅ Principle of least privilege with scoped IAM roles
- ✅ Audit trail of all authentication attempts
- ✅ Reduced risk of credential leakage

---

## Prerequisites

- GCP project admin access for `sierra-painting-staging` and `sierra-painting-prod`
- GitHub repository admin access
- `gcloud` CLI installed and authenticated
- Owner or Security Admin role on GCP projects

---

## Part 1: Enable Required APIs

For both staging and production projects, enable the required APIs:

```bash
# Set your project
export PROJECT_ID="sierra-painting-staging"  # or sierra-painting-prod

# Enable required APIs
gcloud services enable iamcredentials.googleapis.com \
  --project="${PROJECT_ID}"

gcloud services enable cloudresourcemanager.googleapis.com \
  --project="${PROJECT_ID}"

gcloud services enable sts.googleapis.com \
  --project="${PROJECT_ID}"
```

---

## Part 2: Create Workload Identity Pool

Create a Workload Identity Pool for GitHub Actions:

```bash
# Set variables
export PROJECT_ID="sierra-painting-staging"  # Change for each environment
export WORKLOAD_IDENTITY_POOL="github-actions-pool"
export WORKLOAD_IDENTITY_PROVIDER="github-actions-provider"
export REPO_OWNER="juanvallejo97"
export REPO_NAME="Sierra-Painting-v1"

# Create Workload Identity Pool
gcloud iam workload-identity-pools create "${WORKLOAD_IDENTITY_POOL}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool" \
  --description="Workload Identity Pool for GitHub Actions CI/CD"

# Get the pool ID (you'll need this)
export WORKLOAD_IDENTITY_POOL_ID=$(gcloud iam workload-identity-pools describe "${WORKLOAD_IDENTITY_POOL}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --format="value(name)")

echo "Pool ID: ${WORKLOAD_IDENTITY_POOL_ID}"
```

---

## Part 3: Create Workload Identity Provider

Create a provider within the pool for GitHub:

```bash
# Create the provider
gcloud iam workload-identity-pools providers create-oidc "${WORKLOAD_IDENTITY_PROVIDER}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${WORKLOAD_IDENTITY_POOL}" \
  --display-name="GitHub Actions Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == '${REPO_OWNER}'" \
  --issuer-uri="https://token.actions.githubusercontent.com"

# Get the provider resource name
export WORKLOAD_IDENTITY_PROVIDER_ID=$(gcloud iam workload-identity-pools providers describe "${WORKLOAD_IDENTITY_PROVIDER}" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="${WORKLOAD_IDENTITY_POOL}" \
  --format="value(name)")

echo "Provider ID: ${WORKLOAD_IDENTITY_PROVIDER_ID}"
```

**Important:** The `attribute-condition` restricts access to only repositories owned by the specified GitHub organization/user.

---

## Part 4: Create CI/CD Service Account

Create a dedicated service account with least-privilege permissions:

```bash
# Create service account
export SERVICE_ACCOUNT_NAME="ci-deployer"
export SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

gcloud iam service-accounts create "${SERVICE_ACCOUNT_NAME}" \
  --project="${PROJECT_ID}" \
  --description="CI/CD deployment service account for GitHub Actions" \
  --display-name="CI/CD Deployer"
```

---

## Part 5: Grant IAM Roles (Least Privilege)

Grant only the minimum required roles to the service account:

```bash
# For Firebase Functions deployment
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/cloudfunctions.developer" \
  --condition=None

# For Cloud Build (used by Firebase deploy)
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/cloudbuild.builds.editor" \
  --condition=None

# For Artifact Registry (function container images)
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/artifactregistry.reader" \
  --condition=None

# For Firestore Rules deployment
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/datastore.indexAdmin" \
  --condition=None

# For Storage Rules deployment
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/firebase.admin" \
  --condition=None

# For Service Account token creation (required for impersonation)
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/iam.serviceAccountUser" \
  --condition=None
```

**Note on roles:**
- `cloudfunctions.developer`: Deploy and manage Cloud Functions
- `cloudbuild.builds.editor`: Create and manage Cloud Build jobs
- `artifactregistry.reader`: Read container images for functions
- `datastore.indexAdmin`: Deploy Firestore indexes
- `firebase.admin`: Deploy Firebase rules and configuration
- `iam.serviceAccountUser`: Allow service account impersonation

**Optional roles** (add if needed):
```bash
# If using Cloud Run instead of Cloud Functions
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/run.admin" \
  --condition=None

# If using Firebase Hosting
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/firebasehosting.admin" \
  --condition=None
```

---

## Part 6: Bind Service Account to Workload Identity

Allow GitHub Actions to impersonate the service account:

```bash
# Allow the Workload Identity Pool to impersonate the service account
gcloud iam service-accounts add-iam-policy-binding "${SERVICE_ACCOUNT_EMAIL}" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${WORKLOAD_IDENTITY_POOL_ID}/attribute.repository/${REPO_OWNER}/${REPO_NAME}"

# Verify the binding
gcloud iam service-accounts get-iam-policy "${SERVICE_ACCOUNT_EMAIL}" \
  --project="${PROJECT_ID}"
```

---

## Part 7: Get Configuration Values for GitHub

Extract the values needed for GitHub Actions workflows:

```bash
# Get the Workload Identity Provider full path
echo "WORKLOAD_IDENTITY_PROVIDER:"
echo "projects/$(gcloud projects describe ${PROJECT_ID} --format='value(projectNumber)')/locations/global/workloadIdentityPools/${WORKLOAD_IDENTITY_POOL}/providers/${WORKLOAD_IDENTITY_PROVIDER}"

# Get the Service Account email
echo ""
echo "SERVICE_ACCOUNT:"
echo "${SERVICE_ACCOUNT_EMAIL}"

# Get Project ID
echo ""
echo "PROJECT_ID:"
echo "${PROJECT_ID}"
```

**Save these values!** You'll need them for GitHub Actions configuration.

---

## Part 8: Configure GitHub Repository

### 8.1 Update Environment Secrets

Navigate to your repository settings:
1. Go to: https://github.com/juanvallejo97/Sierra-Painting-v1/settings/environments

#### For Staging Environment:

1. Click on `staging` environment
2. **Remove** the old secret: `FIREBASE_SERVICE_ACCOUNT` (if it exists)
3. Add new environment variables (not secrets):
   - `GCP_WORKLOAD_IDENTITY_PROVIDER`: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider`
   - `GCP_SERVICE_ACCOUNT`: `ci-deployer@sierra-painting-staging.iam.gserviceaccount.com`

#### For Production Environment:

1. Click on `production` environment
2. **Remove** the old secret: `FIREBASE_SERVICE_ACCOUNT` (if it exists)
3. Add new environment variables (not secrets):
   - `GCP_WORKLOAD_IDENTITY_PROVIDER`: `projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/github-actions-pool/providers/github-actions-provider`
   - `GCP_SERVICE_ACCOUNT`: `ci-deployer@sierra-painting-prod.iam.gserviceaccount.com`

**Note:** These are stored as variables, not secrets, because they're not sensitive. The security comes from the Workload Identity Federation binding.

---

## Part 9: Verification

Test the setup with a workflow run:

1. Push a commit to trigger the staging workflow
2. Check the "Authenticate to Google Cloud" step in the workflow logs
3. Verify successful authentication without JSON keys

Expected log output:
```
Successfully configured Workload Identity Federation authentication
Authenticated as: ci-deployer@PROJECT_ID.iam.gserviceaccount.com
```

---

## Part 10: Audit and Monitoring

### View Authentication Attempts

```bash
# View Workload Identity Federation logs
gcloud logging read "resource.type=iam_service_account AND protoPayload.methodName=GenerateAccessToken" \
  --project="${PROJECT_ID}" \
  --limit=50 \
  --format=json

# View service account activity
gcloud logging read "protoPayload.authenticationInfo.principalEmail=${SERVICE_ACCOUNT_EMAIL}" \
  --project="${PROJECT_ID}" \
  --limit=50
```

### Set Up Alerts

Create alerts for suspicious activity:

```bash
# Alert on failed authentication attempts
gcloud alpha monitoring policies create \
  --project="${PROJECT_ID}" \
  --notification-channels=YOUR_CHANNEL_ID \
  --display-name="Failed Workload Identity Auth" \
  --condition-display-name="High failure rate" \
  --condition-threshold-value=5 \
  --condition-threshold-duration=300s \
  --condition-filter='resource.type="iam_service_account" AND severity="ERROR"'
```

---

## Troubleshooting

### Error: "Permission denied on service account"

**Cause:** Workload Identity binding not configured correctly.

**Solution:**
```bash
# Re-run the binding command
gcloud iam service-accounts add-iam-policy-binding "${SERVICE_ACCOUNT_EMAIL}" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${WORKLOAD_IDENTITY_POOL_ID}/attribute.repository/${REPO_OWNER}/${REPO_NAME}"
```

### Error: "Workload Identity Pool not found"

**Cause:** Pool doesn't exist or wrong project.

**Solution:**
```bash
# List all pools
gcloud iam workload-identity-pools list --location=global --project="${PROJECT_ID}"
```

### Error: "Invalid audience"

**Cause:** Provider configuration mismatch.

**Solution:**
```bash
# Verify provider configuration
gcloud iam workload-identity-pools providers describe "${WORKLOAD_IDENTITY_PROVIDER}" \
  --workload-identity-pool="${WORKLOAD_IDENTITY_POOL}" \
  --location=global \
  --project="${PROJECT_ID}"
```

---

## Rollback Plan

If you need to revert to JSON keys temporarily:

1. Create a new service account key:
   ```bash
   gcloud iam service-accounts keys create key.json \
     --iam-account="${SERVICE_ACCOUNT_EMAIL}" \
     --project="${PROJECT_ID}"
   ```

2. Store the key as a GitHub secret: `FIREBASE_SERVICE_ACCOUNT`

3. Update workflow to use `credentials_json` instead of `workload_identity_provider`

4. **Remember to delete the key after migrating back to OIDC!**

---

## Security Best Practices

- ✅ Use separate Workload Identity Pools per environment (staging/production)
- ✅ Use separate service accounts per environment
- ✅ Restrict provider attribute conditions to specific repositories
- ✅ Regularly audit service account permissions with `gcloud iam roles describe`
- ✅ Enable GCP audit logging for all IAM operations
- ✅ Review Workload Identity Federation logs weekly
- ✅ Use environment protection rules in GitHub for production
- ❌ Never share Workload Identity Provider IDs publicly (though not sensitive, keep internal)
- ❌ Don't grant `roles/owner` or `roles/editor` to CI/CD service accounts
- ❌ Don't disable attribute conditions on the provider

---

## Maintenance

### Quarterly Review Checklist

- [ ] Review service account IAM roles (remove unused)
- [ ] Check for failed authentication attempts in logs
- [ ] Verify attribute conditions are still correct
- [ ] Update documentation if roles changed
- [ ] Test rollback procedure

### When to Update

- **New deployment target**: Add corresponding IAM role
- **Repository renamed**: Update attribute condition
- **Project restructure**: Recreate provider with new conditions
- **Security incident**: Rotate by deleting and recreating pool

---

## Related Documentation

- [GitHub Actions Workflow Updates](./github-environments.md)
- [CI/CD Implementation](./CI_CD_IMPLEMENTATION.md)
- [Security Guide](../Security.md)
- [Google Cloud Workload Identity Federation](https://cloud.google.com/iam/docs/workload-identity-federation)
- [GitHub OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)

---

**Last Updated**: 2024  
**Review Schedule**: Quarterly  
**Owner**: DevOps Team / Repository Administrators
