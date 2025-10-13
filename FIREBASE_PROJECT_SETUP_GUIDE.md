# Firebase Project Setup Guide - Option B

**Goal**: Create separate staging and production Firebase projects with proper configuration.

**Timeline**: 30-60 minutes

---

## Step 1: Create Firebase Projects

### Option 1A: Via Firebase Console (Recommended - Easiest)

1. **Open Firebase Console**: https://console.firebase.google.com/

2. **Create Staging Project**:
   - Click "Add project"
   - Project name: `Sierra Painting Staging`
   - Project ID: `sierra-painting-staging` (important: must match exactly)
   - Accept terms
   - **Disable** Google Analytics (we'll enable manually later)
   - Click "Create project"
   - Wait for project creation (~30 seconds)

3. **Create Production Project**:
   - Click "Add project" again
   - Project name: `Sierra Painting Production`
   - Project ID: `sierra-painting-prod` (important: must match exactly)
   - Accept terms
   - **Disable** Google Analytics initially
   - Click "Create project"

### Option 1B: Via Firebase CLI (Alternative)

If you prefer CLI:

```bash
# Install Firebase tools (if not already installed)
npm install -g firebase-tools

# Ensure you're logged in
firebase login

# Create staging project (interactive)
firebase projects:create sierra-painting-staging

# Create production project (interactive)
firebase projects:create sierra-painting-prod
```

---

## Step 2: Enable Required Services

For **BOTH** staging and production projects, enable these services:

### Via Firebase Console:

#### Staging Project (sierra-painting-staging)

1. **Select project**: https://console.firebase.google.com/project/sierra-painting-staging

2. **Enable Firestore**:
   - Left sidebar → Build → Firestore Database
   - Click "Create database"
   - Start in **test mode** (we'll deploy rules later)
   - Location: **`us-east4`** (Northern Virginia - closest to your location)
   - Click "Enable"

3. **Enable Authentication**:
   - Left sidebar → Build → Authentication
   - Click "Get started"
   - Sign-in method → Enable "Email/Password"
   - Save

4. **Enable Storage**:
   - Left sidebar → Build → Storage
   - Click "Get started"
   - Start in **test mode**
   - Location: **`us-east4`** (must match Firestore location)
   - Click "Done"

5. **Enable App Check**:
   - Left sidebar → Build → App Check
   - Register your web app
   - Get reCAPTCHA v3 site key
   - Save to `.env.staging` file

#### Production Project (sierra-painting-prod)

Repeat the same steps for production:
- https://console.firebase.google.com/project/sierra-painting-prod
- Enable Firestore, Authentication, Storage, App Check

---

## Step 3: Configure Local Environment

Update `.firebaserc` to use the new projects:

```json
{
  "projects": {
    "default": "to-do-app-ac602",
    "dev": "to-do-app-ac602",
    "staging": "sierra-painting-staging",
    "production": "sierra-painting-prod"
  },
  "targets": {
    "sierra-painting-staging": {
      "hosting": {
        "staging": ["sierra-painting-staging"]
      }
    },
    "sierra-painting-prod": {
      "hosting": {
        "prod": ["sierra-painting-prod"]
      }
    }
  }
}
```

---

## Step 4: Deploy Indexes

### Deploy to Staging First

```bash
# Switch to staging
firebase use staging

# Verify you're on the right project
firebase use

# Deploy indexes
firebase deploy --only firestore:indexes

# Expected output:
# ✔ firestore: deployed indexes in firestore.indexes.json successfully
```

### Monitor Index Build

```bash
# Check index status
# Go to: https://console.firebase.google.com/project/sierra-painting-staging/firestore/indexes
```

Wait for all 11 indexes to show **"Enabled"** status (typically 5-15 minutes).

### Deploy to Production

Once staging indexes are verified:

```bash
# Switch to production
firebase use production

# Deploy indexes
firebase deploy --only firestore:indexes
```

---

## Step 5: Deploy Security Rules

### Deploy Rules to Staging

```bash
# Make sure you have the fixed rules
# (Already created in firestore.rules.fixed)

# Backup current rules
cp firestore.rules firestore.rules.backup

# Apply fixed rules
cp firestore.rules.fixed firestore.rules

# Switch to staging
firebase use staging

# Deploy rules
firebase deploy --only firestore:rules

# Expected: ✔ cloud.firestore: rules file compiled successfully (0 warnings)
```

### Test Rules in Staging

```bash
# Run rules tests against staging emulator
npm --prefix functions run test -- rules.test.ts
npm --prefix functions run test -- storage-rules.test.ts
```

### Deploy Rules to Production

Once staging rules are verified:

```bash
# Switch to production
firebase use production

# Deploy rules
firebase deploy --only firestore:rules
```

---

## Step 6: Verify Deployment

### Checklist for Staging

- [ ] Project created: `sierra-painting-staging`
- [ ] Firestore enabled with indexes
- [ ] All 11 indexes show "Enabled" status
- [ ] Authentication enabled (Email/Password)
- [ ] Storage enabled
- [ ] App Check configured
- [ ] Security rules deployed (0 warnings)
- [ ] Rules tests pass

### Checklist for Production

- [ ] Project created: `sierra-painting-prod`
- [ ] Firestore enabled with indexes
- [ ] All 11 indexes show "Enabled" status
- [ ] Authentication enabled (Email/Password)
- [ ] Storage enabled
- [ ] App Check configured
- [ ] Security rules deployed (0 warnings)

---

## Step 7: Update Environment Files

Create environment-specific configs:

### `.env.staging`

```bash
ENABLE_APP_CHECK=true
RECAPTCHA_V3_SITE_KEY=<your-staging-recaptcha-key>
FIREBASE_PROJECT_ID=sierra-painting-staging
```

### `.env.production`

```bash
ENABLE_APP_CHECK=true
RECAPTCHA_V3_SITE_KEY=<your-production-recaptcha-key>
FIREBASE_PROJECT_ID=sierra-painting-prod
```

---

## Step 8: Deploy Test App to Staging

Build and deploy to verify everything works:

```bash
# Build Flutter web
flutter build web --release --dart-define=ENABLE_APP_CHECK=true

# Switch to staging
firebase use staging

# Deploy hosting
firebase deploy --only hosting

# Access at: https://sierra-painting-staging.web.app
```

---

## Troubleshooting

### "Permission denied" errors

**Solution**: Ensure your account (`juan_vallejo@uri.edu`) is the owner:
- Firebase Console → Project Settings → Users and permissions
- Should show "Owner" role

### "Project not found"

**Solution**: Verify project exists and is accessible:
```bash
firebase projects:list
```

### "Index required" errors in app

**Solution**: Wait for indexes to finish building:
- Check Firebase Console → Firestore → Indexes
- Status should be "Enabled" (not "Building")

### Rules warnings persist

**Solution**: Ensure you copied `firestore.rules.fixed` to `firestore.rules`:
```bash
diff firestore.rules firestore.rules.fixed
# Should show no differences
```

---

## Success Criteria

✅ **Staging environment fully functional**:
- App loads without errors
- Can create test user
- Can perform CRUD operations (invoices, estimates)
- No "index required" errors in console
- Telemetry data flowing to Firebase Console

✅ **Production environment ready**:
- Indexes enabled
- Rules deployed
- App Check configured
- Ready for canary deployment

---

## Next Steps After Setup

Once both projects are created and verified:

1. **Deploy telemetry test** (DEPLOYMENT_GAP_ANALYSIS.md - GAP #3)
2. **Configure alert policies** (Error budget, latency SLOs)
3. **Document deployment runbook** (`docs/ops/DEPLOYMENT_RUNBOOK.md`)
4. **Begin Sprint 1** (NEXT_STEPS.md - Invoice/Estimate foundations)

---

## Estimated Time

- **Project creation**: 10 minutes (both projects)
- **Service enablement**: 15 minutes (both projects)
- **Index deployment**: 30 minutes (includes build time)
- **Rules deployment & testing**: 10 minutes
- **Verification**: 15 minutes

**Total**: ~60 minutes

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
