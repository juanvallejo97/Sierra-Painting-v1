# Emergency Rollback Procedure

**Purpose:** Quick reference guide for rolling back database hardening deployment in case of issues.

**When to Use:** App functionality broken, security rules blocking access, severe performance degradation, data integrity issues.

---

## Quick Rollback (5 minutes)

### 1. Assess Severity

**Critical Issues (immediate rollback):**
- App completely non-functional
- Users locked out of system
- Data loss or corruption detected
- Security breach suspected

**Non-Critical Issues (investigate first):**
- Minor performance degradation
- Single feature not working
- Isolated user reports

### 2. Execute Rollback

```bash
# Stop current deployment
firebase deploy:cancel

# Rollback indexes
cp firestore.indexes.backup.json firestore.indexes.json
firebase deploy --only firestore:indexes

# Rollback security rules (if modified)
cp firestore.rules.backup firestore.rules
firebase deploy --only firestore:rules

# Rollback Cloud Functions
firebase functions:delete queryMonitorScheduled --region=us-east4 --force
firebase functions:delete queryMonitorManual --region=us-east4 --force

# Rollback data changes (if backfill was run)
npm run rollback:migration -- --confirm
```

### 3. Verify System Restored

```bash
# Test app functionality
flutter run --release

# Run security tests
npm run test:rules

# Check Cloud Logging for errors
gcloud logging read "severity>=ERROR" --limit=50
```

---

## Detailed Rollback Steps

### Rollback Firestore Indexes

**Impact:** Old indexes will remain active during new index build (no downtime)

**Time:** 2-5 minutes

```bash
# Restore backup
cp firestore.indexes.backup.json firestore.indexes.json

# Deploy backup indexes
firebase deploy --only firestore:indexes

# Verify deployment
firebase firestore:indexes

# Wait for indexes to build (if any changes)
# Old indexes remain active until new ones are ready
```

### Rollback Security Rules

**Impact:** Immediate effect, may restore broken access patterns

**Time:** 1-2 minutes

```bash
# Restore backup
cp firestore.rules.backup firestore.rules

# Deploy backup rules
firebase deploy --only firestore:rules

# Verify in Firebase Console
# https://console.firebase.google.com/project/YOUR_PROJECT/firestore/rules
```

### Rollback Cloud Functions

**Impact:** Monitoring stops, audit logging stops

**Time:** 3-5 minutes

```bash
# Delete monitoring functions
firebase functions:delete queryMonitorScheduled --region=us-east4
firebase functions:delete queryMonitorManual --region=us-east4

# Delete audit logging triggers
firebase functions:delete auditUserRoleChanges --region=us-east4
firebase functions:delete auditTimeEntryChanges --region=us-east4
firebase functions:delete auditInvoiceChanges --region=us-east4

# Verify deletion
firebase functions:list
```

### Rollback Data Migration

**Impact:** Restores documents to pre-backfill state

**Time:** 5-15 minutes (depending on document count)

**Prerequisites:** Backfill must have been run with backup creation

```bash
# DRY-RUN: Preview rollback
npm run rollback:migration -- --dry-run

# Review output - verify changes are correct

# EXECUTE: Rollback all documents
npm run rollback:migration -- --confirm

# Verify success
npm run verify:companyId

# Should show 100% valid documents
```

### Rollback Specific Collection

If only one collection has issues:

```bash
# Rollback specific collection
npm run rollback:migration -- --collection=jobs --confirm

# Verify specific collection
npm run verify:companyId -- --collection=jobs
```

### Rollback Specific Document

If only one document has issues:

```bash
# Rollback specific document
npm run rollback:migration -- --collection=jobs --document=job-123 --confirm

# Verify in Firebase Console or with CLI
firebase firestore:get jobs/job-123
```

---

## Post-Rollback Validation

### 1. App Functionality Test

```bash
# Run app in production mode
flutter run --release -d chrome

# Test critical flows:
# - Login (admin, manager, worker)
# - Worker schedule
# - Admin dashboard
# - Time clock operations
# - Invoice creation
```

### 2. Security Rules Validation

```bash
# Start emulator
firebase emulators:start --only firestore

# Run security tests
npm run test:rules

# All tests should pass
```

### 3. Data Integrity Check

```bash
# Verify companyId consistency
npm run verify:companyId

# Check for orphaned documents
# Check for invalid references
```

### 4. Performance Check

```bash
# Monitor query latency
gcloud logging read "resource.type=cloud_function" --limit=50

# Look for slow queries or errors
```

---

## Troubleshooting Common Rollback Issues

### Issue: Index Rollback Fails

**Symptom:** `firebase deploy --only firestore:indexes` fails

**Solution:**
```bash
# Check Firebase Console for index state
# Manual delete from console if needed
# Re-deploy backup indexes

firebase firestore:indexes:delete <index-id>
firebase deploy --only firestore:indexes
```

### Issue: Data Rollback Fails

**Symptom:** `npm run rollback:migration` fails with errors

**Solution:**
```bash
# Check if backups exist
firebase firestore:get _backups/companyId_migration/documents --limit=1

# If backups missing, data cannot be rolled back
# Requires manual intervention

# Check rollback-failed.json for details
cat rollback-failed.json
```

### Issue: Functions Won't Delete

**Symptom:** `firebase functions:delete` times out

**Solution:**
```bash
# Use Firebase Console to delete manually
# https://console.firebase.google.com/project/YOUR_PROJECT/functions

# Or use gcloud CLI
gcloud functions delete queryMonitorScheduled --region=us-east4 --quiet
```

### Issue: App Still Broken After Rollback

**Symptom:** App not working even after rollback

**Solution:**
1. Check if all rollback steps completed successfully
2. Clear browser cache and reload
3. Check Cloud Logging for new errors
4. Verify no other deployments are in progress
5. Contact support if issue persists

---

## Recovery After Rollback

### 1. Root Cause Analysis

Document what went wrong:
- What failed?
- When did it fail?
- What was the impact?
- What logs/errors were seen?

### 2. Fix Issues

Based on root cause:
- Fix code bugs
- Adjust configuration
- Update security rules
- Optimize indexes

### 3. Re-Deploy with Fixes

Follow deployment runbook again:
- Test thoroughly in staging
- Run all validation tests
- Deploy during off-peak hours
- Monitor closely during deployment

---

## Rollback Decision Matrix

| Issue | Severity | Action | Rollback? |
|-------|----------|--------|-----------|
| All users locked out | CRITICAL | Immediate rollback | YES |
| Data loss detected | CRITICAL | Immediate rollback | YES |
| Security breach | CRITICAL | Immediate rollback | YES |
| Single feature broken | HIGH | Investigate first | MAYBE |
| Performance degraded 2x | HIGH | Investigate first | MAYBE |
| Minor UI glitch | MEDIUM | Fix forward | NO |
| Single user issue | LOW | Support ticket | NO |

---

## Communication Template

**Subject:** [URGENT] Database Hardening Rollback - Action Required

**Body:**
```
Team,

We have initiated a rollback of the database hardening deployment due to [ISSUE].

Status: [IN PROGRESS / COMPLETE]
Impact: [DESCRIBE USER IMPACT]
ETA: [TIME TO RESTORE]

Actions Taken:
- [LIST ROLLBACK STEPS]

Current Status:
- [SYSTEM STATE]

Next Steps:
- [WHAT'S HAPPENING NEXT]

For questions, contact: [CONTACT INFO]
```

---

## Rollback Checklist

Print and use during emergency rollback:

- [ ] Issue severity assessed
- [ ] Team notified of rollback
- [ ] Git tag created for current state
- [ ] Indexes rolled back
- [ ] Security rules rolled back (if needed)
- [ ] Cloud Functions deleted
- [ ] Data migration rolled back (if needed)
- [ ] App functionality verified
- [ ] Security tests passed
- [ ] Data integrity verified
- [ ] Performance checked
- [ ] Users notified of restoration
- [ ] Post-mortem scheduled
- [ ] Documentation updated

---

**Document Version:** 1.0
**Last Updated:** 2025-10-16
**Emergency Contact:** [Your contact info]
