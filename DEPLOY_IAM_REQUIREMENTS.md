# Firebase Deployment IAM Requirements

## Required Roles for sierra-staging Deployment

Grant the deployer account (CI service account or your Google account) these roles on the `sierra-staging` project:

### 1. Service Account User
**Role:** `roles/iam.serviceAccountUser`
**Resource:** `sierra-staging@appspot.gserviceaccount.com` (runtime service account)
**Why:** Allows deployment to act as the Cloud Functions runtime service account

### 2. Cloud Functions Developer
**Role:** `roles/cloudfunctions.developer`
**Why:** Deploy, update, and delete Cloud Functions

### 3. Artifact Registry Reader
**Role:** `roles/artifactregistry.reader`
**Why:** Cloud Functions v2 stores container images in Artifact Registry

### 4. Cloud Build Editor
**Role:** `roles/cloudbuild.builds.editor`
**Why:** Functions v2 uses Cloud Build to create container images

### 5. Cloud Run Admin
**Role:** `roles/run.admin`
**Why:** Cloud Functions v2 runs on Cloud Run infrastructure

## Grant Permissions via Console

1. Visit: https://console.cloud.google.com/iam-admin/iam?project=sierra-staging

2. Click **"GRANT ACCESS"**

3. Enter the principal (email or service account)

4. Add each role listed above

5. Click **"Save"**

## Grant Permissions via gcloud CLI

```bash
# Set project
gcloud config set project sierra-staging

# Replace DEPLOYER_EMAIL with your account email or service account
DEPLOYER_EMAIL="your-email@example.com"

# Grant all required roles
gcloud projects add-iam-policy-binding sierra-staging \
  --member="user:${DEPLOYER_EMAIL}" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding sierra-staging \
  --member="user:${DEPLOYER_EMAIL}" \
  --role="roles/cloudfunctions.developer"

gcloud projects add-iam-policy-binding sierra-staging \
  --member="user:${DEPLOYER_EMAIL}" \
  --role="roles/artifactregistry.reader"

gcloud projects add-iam-policy-binding sierra-staging \
  --member="user:${DEPLOYER_EMAIL}" \
  --role="roles/cloudbuild.builds.editor"

gcloud projects add-iam-policy-binding sierra-staging \
  --member="user:${DEPLOYER_EMAIL}" \
  --role="roles/run.admin"
```

## Verify Permissions

```bash
# List your permissions
gcloud projects get-iam-policy sierra-staging \
  --flatten="bindings[].members" \
  --format="table(bindings.role)" \
  --filter="bindings.members:${DEPLOYER_EMAIL}"
```

## Deploy Once Permissions Are Granted

```bash
# Build functions
npm --prefix functions run build

# Deploy to staging
firebase deploy --only functions --project sierra-staging

# Verify deployment
firebase functions:list --project sierra-staging
```

## Troubleshooting

**Error:** "Missing permissions required for functions deploy"
**Fix:** Ensure all 5 roles are granted and wait ~1 minute for IAM propagation

**Error:** "Permission denied on Artifact Registry"
**Fix:** Grant `roles/artifactregistry.reader` role

**Error:** "Cloud Build API not enabled"
**Fix:** Enable Cloud Build API:
```bash
gcloud services enable cloudbuild.googleapis.com --project=sierra-staging
```
