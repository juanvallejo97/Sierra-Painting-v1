# T-002: Credential Rotation Guide

**Priority**: P0 - CRITICAL (Security Blocker)
**Estimated Time**: 2-4 hours
**Prerequisites**: Admin access to Firebase, GitHub, Stripe, etc.
**Status**: ⏳ Awaiting security audit

---

## Overview

Exposed credentials in version control, logs, or documentation pose a critical security risk. This guide provides a systematic approach to:
1. Identify exposed credentials
2. Rotate all sensitive keys/tokens
3. Prevent future exposure
4. Monitor for unauthorized access

---

## Phase 1: Credential Audit (30 min)

### Step 1: Search for Exposed Credentials

Run these searches in the repository:

```bash
# Search for common credential patterns
git log --all --full-history --source --patch -- '*.env*'
git log --all --full-history --source --patch | grep -i 'password\|secret\|key\|token\|api'

# Search for Firebase credentials
grep -r "AIza" --include="*.dart" --include="*.ts" --include="*.js" .
grep -r "GOOGLE_APPLICATION_CREDENTIALS" .

# Search for hardcoded secrets
grep -r -E '(password|secret|token|api_?key)\s*=\s*["\'][^"\']{8,}' .

# Search for Stripe keys
grep -r "sk_live_" .
grep -r "pk_live_" .

# Search for database URLs
grep -r "postgres://\|mysql://\|mongodb://" .
```

### Step 2: Check Git History for Leaked Secrets

```bash
# Use git-secrets or gitleaks
npm install -g gitleaks
gitleaks detect --source . --verbose

# Or use GitHub Secret Scanning (if enabled)
# Check: https://github.com/your-org/sierra-painting-v1/security/secret-scanning
```

### Step 3: Review Common Leak Locations

**High Risk**:
- [ ] `.env` files committed to git
- [ ] `firebase_options.dart` (should only have public keys)
- [ ] `web/index.html` (API keys visible)
- [ ] `functions/.env` or `functions/src/config/*.ts`
- [ ] GitHub Actions secrets in workflow files
- [ ] Documentation with example configs
- [ ] Backup files (`.env.backup`, `.env.old`)

**Medium Risk**:
- [ ] Error logs with sensitive data
- [ ] Debug print statements
- [ ] Comments with API keys
- [ ] Test fixtures with real credentials

---

## Phase 2: Rotation Plan (60 min)

### 1. Firebase Credentials

#### Firebase Web API Key (Public, but should be restricted)
**Location**: `lib/firebase_options.dart`, `web/index.html`

**Risk**: Low (public key, but should have API restrictions)

**Action**:
1. Firebase Console → Project Settings → General → Web apps
2. Click **Settings** on your web app
3. Note the API key (starts with `AIza`)
4. Click on API key to open Google Cloud Console
5. Restrict API key:
   - **Application restrictions**: HTTP referrers
   - Add: `sierra-painting-staging.web.app/*`, `sierra-painting-prod.web.app/*`
   - **API restrictions**: Select specific APIs
   - Enable only: Firebase Authentication, Firestore, Functions, Storage

**No rotation needed** if:
- Key is not exposed in git history
- Key has proper restrictions

#### Firebase Service Account (Private)
**Location**: CI/CD secrets, local `.env`

**Risk**: CRITICAL (full admin access)

**Action**:
1. Firebase Console → Project Settings → Service Accounts
2. Click **Generate New Private Key**
3. Save as `service-account-new.json` (DON'T commit)
4. Update CI/CD secrets:
   ```bash
   # GitHub Actions
   gh secret set FIREBASE_SERVICE_ACCOUNT < service-account-new.json

   # Or manually in GitHub: Settings → Secrets → Actions
   ```
5. Test deployment with new key
6. Delete old service account:
   - Firebase Console → Service Accounts
   - Find old key → **Delete**

### 2. GitHub Secrets

**Check current secrets**:
```bash
# List repository secrets (requires GitHub CLI with admin access)
gh secret list --repo your-org/sierra-painting-v1
```

**Common secrets to rotate**:
- [ ] `FIREBASE_SERVICE_ACCOUNT` (see above)
- [ ] `FIREBASE_TOKEN` (CLI token)
- [ ] `STRIPE_SECRET_KEY` (if used)
- [ ] `ENCRYPTION_KEY` (for Hive storage)

**Action**:
```bash
# Generate new Firebase token
firebase login:ci

# Copy the token, then update GitHub secret
gh secret set FIREBASE_TOKEN

# Paste the new token when prompted
```

### 3. Stripe Credentials (If Applicable)

**Location**: `functions/.env`, GitHub secrets

**Risk**: CRITICAL (payment access)

**Action**:
1. Stripe Dashboard: https://dashboard.stripe.com/test/apikeys
2. **Publishable key** (starts with `pk_`):
   - Roll key: Click **Roll** button
   - Update in code: `functions/.env`, client config

3. **Secret key** (starts with `sk_`):
   - Roll key: Click **Roll** button
   - Update GitHub secret:
     ```bash
     gh secret set STRIPE_SECRET_KEY
     ```
   - Update `.env` files (NOT committed to git)

4. **Webhook secret** (starts with `whsec_`):
   - Stripe Dashboard → Webhooks → Your webhook
   - Click **Roll secret**
   - Update GitHub secret:
     ```bash
     gh secret set STRIPE_WEBHOOK_SECRET
     ```

### 4. Database Credentials (If Applicable)

**Note**: This project uses Firestore (credentials handled by Firebase SDK)

**If using external database**:
- [ ] PostgreSQL/MySQL passwords
- [ ] Connection strings
- [ ] Admin credentials

**Action**:
1. Database admin panel → Change password
2. Update `.env` files
3. Update GitHub secrets
4. Restart services

### 5. Third-Party API Keys

**Check for**:
- Google Maps API key
- SendGrid/Mailgun API keys
- Twilio credentials
- Analytics platforms
- Monitoring services

**Action**:
1. Provider dashboard → Generate new key
2. Update `.env` files
3. Update GitHub secrets
4. Test integration
5. Delete old key

---

## Phase 3: Update Configuration (30 min)

### Step 1: Update Environment Files

**DO NOT commit these files**:
```bash
# Local development
.env
.env.local

# Staging
.env.staging

# Production
.env.production

# Functions
functions/.env
functions/.env.staging
functions/.env.production
```

**Template** (`.env.example`):
```bash
# Firebase (use actual values, DO NOT commit)
FIREBASE_API_KEY=your-api-key
FIREBASE_PROJECT_ID=your-project-id

# Stripe (DO NOT commit)
STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...

# App Check
RECAPTCHA_V3_SITE_KEY=6Lf...
ENABLE_APP_CHECK=true

# DO NOT COMMIT ACTUAL VALUES
# Use GitHub Secrets or environment variables
```

### Step 2: Update GitHub Secrets

```bash
# Set all required secrets
gh secret set FIREBASE_SERVICE_ACCOUNT < service-account.json
gh secret set FIREBASE_TOKEN
gh secret set STRIPE_SECRET_KEY
gh secret set STRIPE_WEBHOOK_SECRET
gh secret set ENCRYPTION_KEY
```

### Step 3: Update CI/CD Workflows

Verify secrets are referenced correctly:

```yaml
# .github/workflows/deploy.yml
env:
  FIREBASE_SERVICE_ACCOUNT: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
  STRIPE_SECRET_KEY: ${{ secrets.STRIPE_SECRET_KEY }}
```

---

## Phase 4: Prevent Future Exposure (30 min)

### Step 1: Add `.gitignore` Rules

Verify these entries exist in `.gitignore`:

```gitignore
# Environment files
.env
.env.*
!.env.example

# Service accounts
service-account*.json
*-key.json

# Secrets
secrets/
.secrets/

# Backup files
*.backup
*.old
*.bak

# IDE files
.vscode/settings.json
.idea/workspace.xml
```

### Step 2: Install Pre-commit Hooks

```bash
# Install git-secrets
npm install -g git-secrets

# Setup hooks
cd /path/to/sierra-painting-v1
git secrets --install
git secrets --register-aws  # Detects AWS keys
git secrets --add 'sk_live_[a-zA-Z0-9]+'  # Stripe live keys
git secrets --add 'AIza[a-zA-Z0-9_-]{35}'  # Firebase keys
```

### Step 3: Enable GitHub Secret Scanning

1. GitHub Repository → **Settings** → **Security** → **Code security and analysis**
2. Enable **Secret scanning**
3. Enable **Push protection** (blocks commits with secrets)

**If using GitHub Enterprise**:
1. Enable **Secret scanning alerts**
2. Configure notifications
3. Review and resolve alerts

### Step 4: Implement Secret Management

**Option A: Use GitHub Secrets (Current)**
- ✅ Simple, built-in
- ❌ Manual rotation

**Option B: Use Secret Manager (Recommended)**
```bash
# Google Cloud Secret Manager
gcloud secrets create stripe-secret-key --data-file=-

# Access in Cloud Functions
const {SecretManagerServiceClient} = require('@google-cloud/secret-manager');
const client = new SecretManagerServiceClient();
const [version] = await client.accessSecretVersion({
  name: 'projects/PROJECT_ID/secrets/stripe-secret-key/versions/latest'
});
const secretValue = version.payload.data.toString();
```

**Option C: Use Environment Variables**
```bash
# Hosting (Firebase)
firebase functions:config:set stripe.secret="sk_test_..."

# Access in functions
const stripeSecret = functions.config().stripe.secret;
```

---

## Phase 5: Monitoring & Verification (30 min)

### Step 1: Test New Credentials

**Staging**:
```bash
# Deploy with new credentials
firebase deploy --project sierra-painting-staging

# Test critical flows
npm run smoke:staging
```

**Production**:
```bash
# Deploy to production
firebase deploy --project sierra-painting-prod

# Monitor for errors
firebase functions:log --project sierra-painting-prod
```

### Step 2: Verify Old Credentials are Revoked

**Firebase**:
1. Try to authenticate with old service account → Should fail
2. Check Firebase Console → Service Accounts → Old key should be deleted

**Stripe**:
1. Try API call with old key → Should return 401
2. Check Stripe Dashboard → Old keys should show "Rolled"

**GitHub**:
1. Old CI/CD runs should fail (if they reference old secrets)

### Step 3: Monitor for Unauthorized Access

**Firebase**:
- Console → Usage → Check for unusual spikes
- Cloud Functions logs → Look for auth errors

**Stripe**:
- Dashboard → Logs → Filter by 401 errors
- Look for API calls with old keys

**GitHub**:
- Settings → Actions → Check workflow runs
- Look for authentication failures

### Step 4: Set Up Alerts

**Firebase**:
```bash
# Enable billing alerts
gcloud projects add-iam-policy-binding sierra-painting-prod \
  --member="serviceAccount:your-service-account@project.iam.gserviceaccount.com" \
  --role="roles/billing.viewer"
```

**Stripe**:
- Dashboard → Developers → Webhooks → Set up failure alerts

**GitHub**:
- Repository → Settings → Notifications → Enable secret scanning alerts

---

## Phase 6: Documentation & Handoff (15 min)

### Step 1: Document New Credentials

**Create secure documentation**:
```markdown
# Credential Inventory (INTERNAL ONLY)

Last Updated: 2025-10-13

## Firebase
- Service Account: Stored in GitHub Secrets (`FIREBASE_SERVICE_ACCOUNT`)
- API Key: Restricted to staging/prod domains
- Web Client ID: Public (in firebase_options.dart)

## Stripe
- Publishable Key: `pk_test_...` (Staging)
- Secret Key: Stored in GitHub Secrets (`STRIPE_SECRET_KEY`)
- Webhook Secret: Stored in GitHub Secrets (`STRIPE_WEBHOOK_SECRET`)

## GitHub
- Firebase Token: Stored in GitHub Secrets (`FIREBASE_TOKEN`)
- Expires: Never (should rotate annually)

## Rotation Schedule
- Firebase Service Account: Annually (next: 2026-10-13)
- Stripe Keys: Annually or upon suspicion of compromise
- GitHub Token: Annually (next: 2026-10-13)
```

### Step 2: Update Team

**Slack Announcement** (Draft):
```
🔐 Security Update: Credential Rotation Complete

We've completed a comprehensive credential rotation:
✅ Firebase service accounts rotated
✅ Stripe API keys rotated (if applicable)
✅ GitHub secrets updated
✅ Old credentials revoked

Action Required:
- If you have local .env files, request new credentials from DevOps
- Do NOT commit .env files to git
- Report any authentication errors immediately

Questions? Contact: security@yourcompany.com
```

### Step 3: Schedule Next Rotation

Add to calendar:
- **Quarterly review**: Check for exposed credentials
- **Annual rotation**: Rotate all long-lived credentials
- **Immediate rotation**: Upon detection of compromise

---

## Rollback Plan

If new credentials cause issues:

### Quick Rollback (10 min)
1. Re-enable old credentials temporarily:
   - Firebase: Generate new key from old service account (if not deleted)
   - Stripe: Un-roll keys (if within 24 hours)
   - GitHub: Revert secret changes

2. Investigate issue:
   - Check logs for authentication errors
   - Verify credentials are correctly configured
   - Test locally with new credentials

3. Fix and retry:
   - Update configuration
   - Re-deploy
   - Re-test

---

## Checklist

### Pre-Rotation
- [ ] Audit codebase for exposed credentials
- [ ] Run gitleaks/git-secrets scan
- [ ] Identify all credentials to rotate
- [ ] Notify team of planned rotation
- [ ] Backup current configuration

### During Rotation
- [ ] Rotate Firebase service account
- [ ] Rotate Firebase CLI token
- [ ] Rotate Stripe keys (if applicable)
- [ ] Rotate third-party API keys
- [ ] Update GitHub secrets
- [ ] Update .env files (DO NOT commit)

### Post-Rotation
- [ ] Test staging deployment
- [ ] Test production deployment
- [ ] Verify old credentials are revoked
- [ ] Monitor for errors (24 hours)
- [ ] Update documentation
- [ ] Schedule next rotation

### Prevention
- [ ] Add comprehensive .gitignore rules
- [ ] Install git-secrets pre-commit hooks
- [ ] Enable GitHub secret scanning
- [ ] Set up alerts for credential exposure
- [ ] Train team on secret management

---

## Emergency Response

**If credentials are exposed publicly**:

1. **Immediate** (within 1 hour):
   - Revoke compromised credentials
   - Generate new credentials
   - Update production immediately
   - Monitor for unauthorized access

2. **Short-term** (within 24 hours):
   - Audit all access logs
   - Identify any unauthorized access
   - Change all related credentials
   - Report to security team

3. **Long-term** (within 1 week):
   - Conduct post-mortem
   - Implement additional safeguards
   - Update team training
   - Review incident response plan

---

## References

- **Firebase Service Accounts**: https://firebase.google.com/docs/admin/setup
- **GitHub Secrets**: https://docs.github.com/en/actions/security-guides/encrypted-secrets
- **Stripe Key Rotation**: https://stripe.com/docs/keys#roll-keys
- **git-secrets**: https://github.com/awslabs/git-secrets
- **gitleaks**: https://github.com/gitleaks/gitleaks

---

**Status**: ⏳ Ready for implementation
**Owner**: Security Team
**Due Date**: Within 72 hours (CRITICAL priority)
**Estimated Cost**: $0 (no service interruption expected)
