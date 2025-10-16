# Database Hardening Deployment Runbook

**Purpose:** Step-by-step deployment guide for Sierra Painting database hardening implementation.

**Target Audience:** DevOps engineers, Platform engineers, Senior developers

**Estimated Time:** 2-3 hours (including testing and validation)

**Prerequisites:**
- Firebase CLI installed (`npm install -g firebase-tools`)
- Admin access to Firebase project
- Node.js 18+ installed
- Access to GitHub repository

---

## Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Phase 1: Deploy Composite Indexes](#phase-1-deploy-composite-indexes)
3. [Phase 2: Run Security Tests](#phase-2-run-security-tests)
4. [Phase 3: Deploy Monitoring Functions](#phase-3-deploy-monitoring-functions)
5. [Phase 4: Run Data Verification](#phase-4-run-data-verification)
6. [Phase 5: Deploy Security Rules (Optional)](#phase-5-deploy-security-rules-optional)
7. [Phase 6: Post-Deployment Validation](#phase-6-post-deployment-validation)
8. [Rollback Procedure](#rollback-procedure)

---

## Pre-Deployment Checklist

### 1. Environment Verification

```bash
# Check Firebase CLI version (should be >=12.0.0)
firebase --version

# Verify you're logged in
firebase login

# List available projects
firebase projects:list

# Set active project
firebase use <project-id>
```

### 2. Backup Current Configuration

```bash
# Export current Firestore indexes
firebase firestore:indexes > firestore.indexes.backup.json

# Export current security rules
cp firestore.rules firestore.rules.backup

# Create backup tag in git
git tag -a "pre-hardening-$(date +%Y%m%d)" -m "Pre-hardening backup"
git push origin --tags
```

### 3. Review Changes

```bash
# Review index changes
diff firestore.indexes.backup.json firestore.indexes.json

# Review security rules changes (if any)
diff firestore.rules.backup firestore.rules

# Review new Cloud Functions
ls functions/src/monitoring/
```

---

## Phase 1: Deploy Composite Indexes

**Duration:** 15-30 minutes (indexes build asynchronously)

**Risk Level:** LOW (indexes are additive, no data changes)

### Step 1.1: Deploy Indexes

```bash
# Deploy Firestore indexes
firebase deploy --only firestore:indexes

# Expected output:
# ✔ Deploy complete!
```

### Step 1.2: Monitor Index Build Status

```bash
# Check index build status
firebase firestore:indexes

# Wait until all indexes show "READY" status
# Build time depends on collection size:
# - Small (<10k docs): 2-5 minutes
# - Medium (10k-100k docs): 10-20 minutes
# - Large (>100k docs): 30+ minutes
```

**Index URLs** (check in Firebase Console):
- https://console.firebase.google.com/project/YOUR_PROJECT/firestore/indexes

### Step 1.3: Verify Indexes Are Active

```bash
# Run query benchmark tests (requires emulator)
npm run test:benchmarks

# Expected: All queries should complete successfully
# If queries fail, indexes may still be building
```

**✅ Phase 1 Complete:** All composite indexes are deployed and active.

---

## Phase 2: Run Security Tests

**Duration:** 10-15 minutes

**Risk Level:** NONE (tests only, no changes)

### Step 2.1: Start Firestore Emulator

```bash
# Terminal 1: Start emulator
firebase emulators:start --only firestore

# Keep this running for tests
```

### Step 2.2: Run Security Test Suite

```bash
# Terminal 2: Run all security tests
npm run test:rules

# Expected output:
# ✅ 20+ security isolation tests PASSED
# ✅ 15+ RBAC matrix tests PASSED
# ✅ 10+ field immutability tests PASSED
# ✅ 10+ array security tests PASSED

# Total: 50+ tests PASSED
```

### Step 2.3: Run Performance Benchmarks

```bash
# Run query performance tests
npm run test:perf

# Expected output:
# ✅ All queries meet <900ms cold target
# ✅ All queries meet <400ms warm target
```

**✅ Phase 2 Complete:** All security and performance tests passing.

---

## Phase 3: Deploy Monitoring Functions

**Duration:** 5-10 minutes

**Risk Level:** LOW (monitoring only, no data changes)

### Step 3.1: Build Cloud Functions

```bash
# Build TypeScript to JavaScript
npm --prefix functions run build

# Verify build succeeded
ls functions/lib/monitoring/

# Expected files:
# - query-monitor.js
# - security-audit.js
```

### Step 3.2: Deploy Monitoring Functions

```bash
# Deploy only monitoring functions
firebase deploy --only functions:queryMonitorScheduled,functions:queryMonitorManual

# Deploy audit logging triggers
firebase deploy --only functions:auditUserRoleChanges,functions:auditTimeEntryChanges,functions:auditInvoiceChanges

# Expected output:
# ✔ functions[queryMonitorScheduled(us-east4)] Successful create operation
# ✔ functions[queryMonitorManual(us-east4)] Successful create operation
# ✔ functions[auditUserRoleChanges(us-east4)] Successful create operation
# ✔ Deploy complete!
```

### Step 3.3: Configure Cloud Scheduler

```bash
# Query monitor runs every 5 minutes automatically via onSchedule
# No manual configuration needed

# Verify scheduler job created:
gcloud scheduler jobs list --project=YOUR_PROJECT_ID

# Expected output:
# ID: firebase-schedule-queryMonitorScheduled
# STATE: ENABLED
```

### Step 3.4: Test Manual Monitoring

```bash
# Trigger manual monitoring via HTTP
curl -X POST \
  https://us-east4-YOUR_PROJECT.cloudfunctions.net/queryMonitorManual \
  -H "Content-Type: application/json"

# Expected response:
# {
#   "success": true,
#   "companiesMonitored": N,
#   "summary": { "ok": X, "warn": Y, "error": Z }
# }
```

**✅ Phase 3 Complete:** Monitoring functions deployed and active.

---

## Phase 4: Run Data Verification

**Duration:** 5-10 minutes

**Risk Level:** NONE (read-only verification)

### Step 4.1: Run CompanyId Verification

```bash
# Verify all documents have valid companyId
npm run verify:companyId

# Expected output:
# ✅ All documents have valid companyId fields
# Total: X documents verified
# Valid: 100%
```

### Step 4.2: Handle Invalid Documents (if any)

If verification finds invalid documents:

```bash
# Run backfill in dry-run mode first
npm run backfill:companyId -- --dry-run

# Review proposed changes
# If acceptable, run actual backfill
npm run backfill:companyId

# Expected output:
# ✅ All documents successfully backfilled
```

### Step 4.3: Re-Verify After Backfill

```bash
# Verify again to confirm all issues resolved
npm run verify:companyId

# Must show: ✅ All documents have valid companyId fields
```

**✅ Phase 4 Complete:** All data verified and validated.

---

## Phase 5: Deploy Security Rules (Optional)

**Duration:** 2-5 minutes

**Risk Level:** MEDIUM (can break app if misconfigured)

**NOTE:** Only deploy rules if they were modified. Current rules are already well-hardened.

### Step 5.1: Test Rules with Emulator

```bash
# Start emulator
firebase emulators:start --only firestore

# Run security tests
npm run test:rules

# All tests must pass before deploying
```

### Step 5.2: Deploy Rules

```bash
# Deploy Firestore security rules
firebase deploy --only firestore:rules

# Expected output:
# ✔ firestore: deployed security rules
```

### Step 5.3: Verify Rules Deployed

```bash
# Check Firebase Console
# https://console.firebase.google.com/project/YOUR_PROJECT/firestore/rules

# Verify published date is current
```

**✅ Phase 5 Complete:** Security rules deployed (if modified).

---

## Phase 6: Post-Deployment Validation

**Duration:** 10-15 minutes

**Risk Level:** NONE (monitoring only)

### Step 6.1: Verify App Functionality

```bash
# Run Flutter app in production mode
flutter run --release -d chrome

# Test critical flows:
# 1. Login (admin, manager, worker)
# 2. Worker Schedule (Story B)
# 3. Admin Dashboard (Story D)
# 4. Job Location Picker (Story C)
# 5. Invoice creation
# 6. Time clock in/out
```

### Step 6.2: Monitor Query Performance

```bash
# Check Cloud Logging for query monitor logs
gcloud logging read "resource.type=cloud_function AND resource.labels.function_name=queryMonitorScheduled" \
  --project=YOUR_PROJECT_ID \
  --limit=50 \
  --format=json

# Look for:
# - No ERROR or CRITICAL severity logs
# - All queries meeting performance targets (<900ms cold, <400ms warm)
```

### Step 6.3: Check Audit Logs

```bash
# Verify audit logging is working
# Check Firestore collection: security_audit_log
firebase firestore:get security_audit_log --limit=10

# Verify events are being logged with proper structure
```

### Step 6.4: Run Performance Benchmarks in Production

```bash
# Manually trigger query monitor
curl -X POST \
  https://us-east4-YOUR_PROJECT.cloudfunctions.net/queryMonitorManual?companyId=<test-company-id>

# Review response for performance metrics
```

**✅ Phase 6 Complete:** Post-deployment validation successful.

---

## Rollback Procedure

**When to Rollback:**
- Deployment validation fails
- App functionality broken
- Query performance degraded
- Security rules blocking legitimate access

### Emergency Rollback Steps

#### 1. Rollback Firestore Indexes

```bash
# Restore backup indexes
cp firestore.indexes.backup.json firestore.indexes.json

# Deploy backup indexes
firebase deploy --only firestore:indexes

# Note: Old indexes will remain active during new index build
```

#### 2. Rollback Security Rules

```bash
# Restore backup rules
cp firestore.rules.backup firestore.rules

# Deploy backup rules
firebase deploy --only firestore:rules
```

#### 3. Rollback Cloud Functions

```bash
# Delete new monitoring functions
firebase functions:delete queryMonitorScheduled --region=us-east4
firebase functions:delete queryMonitorManual --region=us-east4
firebase functions:delete auditUserRoleChanges --region=us-east4
firebase functions:delete auditTimeEntryChanges --region=us-east4
firebase functions:delete auditInvoiceChanges --region=us-east4
```

#### 4. Rollback Data Changes (if applicable)

```bash
# If backfill was run, restore from backups
npm run rollback:migration -- --confirm

# This restores documents to pre-backfill state
```

#### 5. Verify Rollback Success

```bash
# Run validation tests
npm run test:rules

# Test app functionality
flutter run --release

# Monitor Cloud Logging for errors
```

**✅ Rollback Complete:** System restored to pre-deployment state.

---

## Deployment Checklist

Print this checklist and check off each step during deployment:

- [ ] Pre-deployment backup created (git tag, index backup)
- [ ] Firebase CLI logged in and project selected
- [ ] Phase 1: Firestore indexes deployed
- [ ] Phase 1: Indexes built and showing READY status
- [ ] Phase 2: All security tests passing (50+ tests)
- [ ] Phase 2: All performance benchmarks passing
- [ ] Phase 3: Monitoring functions deployed
- [ ] Phase 3: Cloud Scheduler configured
- [ ] Phase 3: Manual monitoring tested
- [ ] Phase 4: Data verification passed (100% valid)
- [ ] Phase 4: Backfill completed (if needed)
- [ ] Phase 5: Security rules deployed (if modified)
- [ ] Phase 6: App functionality verified
- [ ] Phase 6: Query performance monitored
- [ ] Phase 6: Audit logging verified
- [ ] Deployment documented in change log
- [ ] Team notified of deployment completion

---

## Troubleshooting

### Issue: Index Build Timeout

**Symptom:** Indexes stuck in "BUILDING" state for >1 hour

**Solution:**
1. Check Firebase Console for error messages
2. Verify Firestore collection size and index complexity
3. Contact Firebase support if build fails
4. Consider deploying indexes during off-peak hours

### Issue: Security Tests Failing

**Symptom:** Tests fail with "permission-denied" errors

**Solution:**
1. Verify emulator is running: `firebase emulators:start --only firestore`
2. Check `FIRESTORE_EMULATOR_HOST` environment variable
3. Clear emulator data: `firebase emulators:start --only firestore --clear`
4. Re-run tests

### Issue: Query Performance Degraded

**Symptom:** Queries exceeding performance targets

**Solution:**
1. Verify indexes are READY: `firebase firestore:indexes`
2. Check Cloud Logging for query execution plans
3. Run manual monitoring: `curl queryMonitorManual`
4. Analyze P95 latency trends over 24 hours

### Issue: App Functionality Broken

**Symptom:** Users cannot access features

**Solution:**
1. Check Cloud Logging for rule violations
2. Verify security rules didn't change unexpectedly
3. Test with different user roles (admin, manager, worker)
4. Rollback security rules if necessary

---

## Post-Deployment Monitoring

**Week 1:**
- Daily query performance checks via Cloud Logging
- Monitor security audit logs for anomalies
- Track P95 latency trends
- Validate no increase in error rates

**Week 2-4:**
- Weekly performance reviews
- Monthly security audit log analysis
- Quarterly index optimization review

---

## Support Contacts

- **Firebase Support:** https://firebase.google.com/support
- **GitHub Issues:** https://github.com/anthropics/claude-code/issues
- **Internal DevOps Team:** [Your contact info]
- **Database Administrator:** [Your contact info]

---

**Document Version:** 1.0
**Last Updated:** 2025-10-16
**Maintained By:** DevOps Team
**Review Cycle:** Quarterly
