# Secret Rotation Procedures

**Version:** 1.0
**Last Updated:** 2025-10-12
**Status:** ✅ **DOCUMENTED**
**Review Schedule:** Quarterly

---

## Overview

This document defines procedures for rotating secrets, keys, and credentials used in the Sierra Painting application. Regular rotation reduces the impact of compromised credentials and is required for compliance (SOC 2, PCI-DSS).

**Rotation Schedule:**
- **Scheduled:** Annually (minimum)
- **Triggered:** After security incident, employee departure, or suspected compromise

---

## Secrets Inventory

### 1. Firebase Service Account Keys

**Location:** `firebase-service-account-*.json`

**Used By:**
- CI/CD pipelines (GitHub Actions)
- Backend scripts (migrations, backfill)
- Development environment (emulator access)

**Rotation Frequency:** Annually or on employee departure

**Impact of Compromise:**
- Full Firebase project access
- Data breach (read/write all collections)
- Function deployment capability

**Severity:** **CRITICAL**

---

### 2. Firebase Web API Keys

**Location:**
- `lib/firebase_options.dart` (mobile)
- `web/index.html` (web)
- `.firebaserc` (project config)

**Used By:**
- Flutter app (client-side Firebase access)
- Web app (Firebase SDK initialization)

**Rotation Frequency:** Not typically rotated (public by design)

**Impact of Compromise:**
- None (API keys are public, protected by App Check + Security Rules)

**Severity:** **LOW** (if App Check + rules configured correctly)

---

### 3. reCAPTCHA Keys

**Location:**
- `RECAPTCHA_V3_SITE_KEY` in `assets/config/public.env` (public)
- reCAPTCHA secret key (Google Cloud Console, never committed)

**Used By:**
- App Check for web
- Bot protection

**Rotation Frequency:** Annually or if key is leaked

**Impact of Compromise:**
- Site key (public): None
- Secret key: Attackers can bypass App Check

**Severity:** **MEDIUM**

---

### 4. Encryption Master Key

**Location:**
- `ENCRYPTION_MASTER_KEY` environment variable
- Firebase Functions config or Secret Manager

**Used By:**
- Field-level encryption service (`functions/src/middleware/encryption.ts`)

**Rotation Frequency:** Annually

**Impact of Compromise:**
- All encrypted PII data can be decrypted
- Customer phone numbers, emails exposed

**Severity:** **CRITICAL**

---

### 5. Stripe API Keys

**Location:**
- Stripe Dashboard (secret key never committed)
- `STRIPE_PUBLISHABLE_KEY` in environment config (public)

**Used By:**
- Payment processing functions

**Rotation Frequency:** Annually or on employee departure

**Impact of Compromise:**
- Unauthorized charges
- Customer payment data access

**Severity:** **CRITICAL**

---

### 6. Third-Party Service Tokens

**Location:**
- Various (email services, SMS providers, etc.)

**Used By:**
- Notification services

**Rotation Frequency:** Annually

**Impact of Compromise:**
- Varies by service

**Severity:** **LOW to MEDIUM** (depends on service)

---

## Rotation Procedures

### Firebase Service Account Key

**When to Rotate:**
- Annually (scheduled)
- Employee with key access departs
- Key committed to version control (emergency)
- Suspected compromise

**Steps:**

1. **Generate New Key:**
   ```bash
   # Via Firebase Console
   # Project Settings → Service Accounts → Generate New Private Key

   # Or via gcloud CLI
   gcloud iam service-accounts keys create \
     new-key.json \
     --iam-account=firebase-adminsdk-xxxxx@sierra-painting-staging.iam.gserviceaccount.com
   ```

2. **Update GitHub Secrets:**
   ```bash
   # Repository Settings → Secrets and variables → Actions
   # Update: FIREBASE_SERVICE_ACCOUNT_STAGING
   # Paste contents of new-key.json
   ```

3. **Update Local Environment:**
   ```bash
   # Copy new key to project directory
   cp new-key.json firebase-service-account-staging.json

   # IMPORTANT: Ensure .gitignore includes this pattern
   echo "firebase-service-account-*.json" >> .gitignore
   ```

4. **Test New Key:**
   ```bash
   # Deploy a test function to verify key works
   firebase deploy --only functions:healthCheck --project sierra-painting-staging

   # Expected: Successful deployment
   ```

5. **Delete Old Key:**
   ```bash
   # Wait 24 hours to ensure no active usage
   # Via Firebase Console: Delete old key
   # Or via gcloud:
   gcloud iam service-accounts keys delete <KEY_ID> \
     --iam-account=firebase-adminsdk-xxxxx@sierra-painting-staging.iam.gserviceaccount.com
   ```

6. **Document Rotation:**
   ```bash
   # Update CHANGELOG.md or rotation log
   echo "$(date): Rotated Firebase service account key (reason: scheduled)" >> docs/security/rotation-log.txt
   ```

**Rollback Plan:**
- Keep old key for 24 hours in case new key fails
- If new key doesn't work, revert GitHub Secret to old key
- Investigate why new key failed before deleting old key

---

### reCAPTCHA Keys

**When to Rotate:**
- Key is publicly exposed in code repository
- Suspected bot abuse despite reCAPTCHA
- Annually (proactive)

**Steps:**

1. **Generate New Keys (Google Cloud Console):**
   - Navigate to: https://www.google.com/recaptcha/admin
   - Create new site for `sierrapainting.com`
   - Select reCAPTCHA v3
   - Copy site key and secret key

2. **Update Environment Config:**
   ```bash
   # Staging
   # Update assets/config/public.env
   RECAPTCHA_V3_SITE_KEY=new_site_key_here

   # Production
   RECAPTCHA_V3_SITE_KEY=new_prod_site_key_here
   ```

3. **Update Firebase Functions Config:**
   ```bash
   # Set secret key (never commit this)
   firebase functions:config:set \
     recaptcha.secret_key="new_secret_key_here" \
     --project sierra-painting-staging
   ```

4. **Deploy:**
   ```bash
   # Build web app with new site key
   flutter build web --release

   # Deploy hosting + functions
   firebase deploy --only hosting,functions --project sierra-painting-staging
   ```

5. **Test:**
   ```bash
   # Open app in browser
   # Check browser console for App Check token generation
   # Submit a form (e.g., login) to verify reCAPTCHA works
   ```

6. **Delete Old Keys:**
   - Return to https://www.google.com/recaptcha/admin
   - Delete old site configuration

**Rollback Plan:**
- Redeploy with old site key
- Revert `firebase functions:config:set`

---

### Encryption Master Key

**When to Rotate:**
- Annually (proactive)
- Employee with key access departs
- Key potentially compromised

**⚠️ WARNING:** This is the most complex rotation. Requires re-encrypting all PII data.

**Steps:**

1. **Generate New Master Key:**
   ```bash
   # Generate new 256-bit key
   openssl rand -hex 32

   # Output (example): a1b2c3d4e5f6...
   ```

2. **Deploy Re-Encryption Function:**
   ```typescript
   // functions/src/admin/rotateEncryptionKey.ts
   export const rotateEncryptionKey = onCall(
     {secrets: ['ENCRYPTION_MASTER_KEY', 'NEW_ENCRYPTION_MASTER_KEY']},
     async (request) => {
       // Admin-only
       if (request.auth?.token.role !== 'admin') {
         throw new HttpsError('permission-denied', 'Admin only');
       }

       const oldKey = process.env.ENCRYPTION_MASTER_KEY;
       const newKey = process.env.NEW_ENCRYPTION_MASTER_KEY;

       const collections = ['time_entries', 'customers'];

       for (const collectionName of collections) {
         const snapshot = await db.collection(collectionName)
           .where('_encrypted', '!=', null)
           .get();

         for (const doc of snapshot.docs) {
           const data = doc.data();

           // Decrypt with old key
           process.env.ENCRYPTION_MASTER_KEY = oldKey;
           const decrypted = await decryptFields(data, data._encrypted);

           // Re-encrypt with new key
           process.env.ENCRYPTION_MASTER_KEY = newKey;
           const reencrypted = await encryptFields(decrypted, data._encrypted);

           await doc.ref.update(reencrypted);
         }
       }

       return {success: true, documentsRotated: snapshot.size};
     }
   );
   ```

3. **Set New Key in Secret Manager:**
   ```bash
   # Add new key (temporary)
   echo -n "new_key_here" | gcloud secrets create new-encryption-master-key \
     --data-file=- \
     --project=sierra-painting-staging
   ```

4. **Run Re-Encryption:**
   ```bash
   # Via Firebase CLI
   firebase functions:call rotateEncryptionKey --project sierra-painting-staging --data '{}'

   # Monitor logs
   firebase functions:log --project sierra-painting-staging --only rotateEncryptionKey
   ```

5. **Update Primary Key:**
   ```bash
   # Replace old key with new key in Secret Manager
   echo -n "new_key_here" | gcloud secrets versions add encryption-master-key \
     --data-file=- \
     --project=sierra-painting-staging

   # Delete temporary new-encryption-master-key secret
   gcloud secrets delete new-encryption-master-key --project=sierra-painting-staging
   ```

6. **Deploy Functions with New Key:**
   ```bash
   firebase deploy --only functions --project sierra-painting-staging
   ```

7. **Verify:**
   ```bash
   # Test decryption of recently encrypted data
   # Query a customer record and verify phone number decrypts correctly
   ```

**Rollback Plan:**
- Keep old master key for 7 days
- If decryption fails, re-run rotation with old/new keys swapped
- Firestore data remains intact (re-encryption is non-destructive)

**Estimated Time:** 2-4 hours (depends on data volume)

---

### Stripe API Keys

**When to Rotate:**
- Annually
- Employee with key access departs
- Suspected compromise

**Steps:**

1. **Generate New Keys (Stripe Dashboard):**
   - Login to https://dashboard.stripe.com
   - Developers → API Keys
   - Create new restricted key (limit permissions to minimum needed)

2. **Update Firebase Functions Config:**
   ```bash
   firebase functions:config:set \
     stripe.secret_key="sk_test_new_key_here" \
     --project sierra-painting-staging

   firebase deploy --only functions --project sierra-painting-staging
   ```

3. **Update Client Config:**
   ```bash
   # Update assets/config/public.env
   STRIPE_PUBLISHABLE_KEY=pk_test_new_key_here
   ```

4. **Test Payment Flow:**
   - Create test payment
   - Verify charge appears in Stripe Dashboard
   - Refund test payment

5. **Delete Old Key:**
   - Stripe Dashboard → API Keys → Delete old key

**Rollback Plan:**
- Reactivate old key in Stripe Dashboard
- Redeploy functions with old key

---

## Emergency Rotation (Compromised Secret)

**Trigger Events:**
- Secret committed to public repository
- Employee laptop stolen
- Suspicious API usage detected
- Security audit finding

**Immediate Actions (within 1 hour):**

1. **Identify Scope:**
   ```bash
   # Check git history for exposed secrets
   git log --all --full-history --source --pickaxe-all -p -S "secret_value"

   # Check GitHub secret scanning alerts
   # Repository → Security → Secret scanning alerts
   ```

2. **Revoke Compromised Secret:**
   - Firebase: Delete service account key
   - Stripe: Deactivate API key
   - reCAPTCHA: Delete site configuration

3. **Generate New Secret:**
   - Follow rotation procedure for affected secret (see above)

4. **Deploy Immediately:**
   ```bash
   # Do NOT wait for rotation window
   firebase deploy --only functions --project sierra-painting-staging
   ```

5. **Monitor for Abuse:**
   ```bash
   # Check Firebase Usage dashboard
   # Check Stripe transaction logs
   # Review Cloud Functions logs for unusual activity
   ```

6. **Incident Report:**
   - Document in `docs/security/incidents/YYYY-MM-DD-secret-compromise.md`
   - Include: What was compromised, when discovered, actions taken, impact assessment

**Post-Incident (within 24 hours):**

1. **Root Cause Analysis:**
   - How was secret exposed?
   - What process failed?
   - How to prevent recurrence?

2. **Update Procedures:**
   - Add pre-commit hooks to detect secrets
   - Update .gitignore patterns
   - Employee training on secret handling

3. **Notify Stakeholders:**
   - If customer data potentially accessed: Legal/compliance notification required
   - If payment processing affected: PCI-DSS breach reporting

---

## Automation

### Pre-Commit Hook (Prevent Secret Commits)

**File:** `.husky/pre-commit`

```bash
#!/bin/sh
. "$(dirname "$0")/_/husky.sh"

# Detect secrets in staged files
secrets=$(git diff --cached --name-only | xargs grep -E '(sk_live_|firebase-adminsdk|BEGIN PRIVATE KEY)' || true)

if [ -n "$secrets" ]; then
  echo "❌ ERROR: Potential secret detected in staged files!"
  echo "$secrets"
  echo ""
  echo "Please remove secrets before committing."
  echo "Use environment variables or Secret Manager instead."
  exit 1
fi
```

---

### Rotation Reminder (Scheduled)

**GitHub Actions:** `.github/workflows/secret-rotation-reminder.yml`

```yaml
name: Secret Rotation Reminder

on:
  schedule:
    # Run on first day of each quarter (Jan 1, Apr 1, Jul 1, Oct 1)
    - cron: '0 9 1 1,4,7,10 *'

jobs:
  remind:
    runs-on: ubuntu-latest
    steps:
      - name: Create Issue
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.create({
              owner: context.repo.owner,
              repo: context.repo.repo,
              title: 'Quarterly Secret Rotation Due',
              body: 'Reminder: Rotate secrets according to docs/security/SECRET_ROTATION.md\n\n' +
                    '- [ ] Firebase service account keys\n' +
                    '- [ ] Encryption master key\n' +
                    '- [ ] Stripe API keys\n' +
                    '- [ ] reCAPTCHA keys (if needed)\n' +
                    '- [ ] Document rotation in rotation-log.txt',
              labels: ['security', 'reminder']
            })
```

---

## Compliance

### SOC 2 Requirements

**Control:** CC6.1 - Logical and Physical Access Controls

- **Requirement:** Secrets rotated at least annually
- **Evidence:** Rotation log (`docs/security/rotation-log.txt`)
- **Audit:** Annual review of rotation dates

---

### PCI-DSS Requirements

**Requirement 8.2.4:** Change user passwords at least every 90 days

- **Interpretation:** API keys rotated at least annually
- **Stripe keys:** Treat as passwords, rotate on schedule

---

## References

### Internal Documentation

- `docs/security/FIELD_ENCRYPTION.md` - Encryption master key usage
- `docs/security/WEB_SECURITY_HEADERS.md` - reCAPTCHA configuration
- `.gitignore` - Patterns to prevent secret commits

### External Resources

- [Firebase Service Account Management](https://firebase.google.com/docs/admin/setup#initialize-sdk)
- [Google Secret Manager](https://cloud.google.com/secret-manager/docs)
- [Stripe API Key Best Practices](https://stripe.com/docs/keys)
- [OWASP Secret Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

---

**Rotation Log:** `docs/security/rotation-log.txt`

```
2025-10-12: Initial documentation created
[Next rotation due: 2026-10-12]
```

---

**Approved By:**
- Engineering: TBD
- Security: TBD
- Compliance: TBD

**Next Review Date:** 2026-01-12 (Quarterly)
