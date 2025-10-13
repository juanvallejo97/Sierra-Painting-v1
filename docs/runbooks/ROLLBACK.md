# Rollback Runbook

**Project:** Sierra Painting Staging
**Last Updated:** 2025-10-12
**Emergency Contact:** @valle

---

## Quick Reference

| Component | Rollback Time | Risk Level | Command |
|-----------|---------------|------------|---------|
| Hosting | 2-5 min | Low | `firebase hosting:rollback <version>` |
| Functions | 5-10 min | Medium | `gcloud functions deploy <name> --source gs://...` |
| Firestore Rules | 1-2 min | High | `firebase deploy --only firestore:rules` |
| Firestore Indexes | 5-15 min | Low | `firebase deploy --only firestore:indexes` |

---

## Prerequisites

- Firebase CLI authenticated: `firebase login`
- Correct project selected: `firebase use sierra-painting-staging`
- Git access to rollback commit

---

## Scenario 1: Rollback Hosting (Web App)

**When to Use:**
- Broken UI after deployment
- JavaScript errors preventing app load
- User reports of blank screens

**Rollback Steps:**

1. **List recent deployments:**
```bash
firebase hosting:channel:list --project sierra-painting-staging
```

2. **View deployment history:**
```bash
gcloud app versions list --project=sierra-painting-staging --service=default
```

3. **Rollback to previous version:**
```bash
# Find the version ID from step 1 (e.g., "abc123")
firebase hosting:rollback <version-id> --project sierra-painting-staging
```

**Verification:**
```bash
# Open staging URL in browser
start https://sierra-painting-staging.web.app

# Check for JavaScript errors in browser console (F12)
# Verify login flow works
```

**Expected Time:** 2-5 minutes
**Rollback Confirmation:** User can login and navigate to dashboard

---

## Scenario 2: Rollback Cloud Functions

**When to Use:**
- Function errors in Cloud Logging
- High error rates (>5%)
- Timeouts or cold start issues

**Rollback Steps:**

1. **Identify failing function:**
```bash
# View recent logs
firebase functions:log --project sierra-painting-staging --only <function-name>

# List deployed functions
gcloud functions list --project=sierra-painting-staging --region=us-east4
```

2. **Rollback single function:**
```bash
# Option A: Redeploy from previous commit
git checkout <previous-commit-sha>
npm --prefix functions run build
firebase deploy --only functions:<function-name> --project sierra-painting-staging
git checkout main
```

3. **Rollback all functions:**
```bash
# Checkout previous known-good commit
git log --oneline --decorate -10  # Find previous deployment commit
git checkout <commit-sha>

# Rebuild and redeploy
npm --prefix functions run build
firebase deploy --only functions --project sierra-painting-staging

# Return to main
git checkout main
```

**Verification:**
```bash
# Test callable function
firebase functions:shell --project sierra-painting-staging
> clockIn({jobId: "test", lat: 37.7793, lng: -122.4193, accuracy: 10, clientEventId: "test"})

# Check logs for errors
firebase functions:log --project sierra-painting-staging --lines 50
```

**Expected Time:** 5-10 minutes
**Rollback Confirmation:** Function executes without errors

---

## Scenario 3: Rollback Firestore Rules

**When to Use:**
- Users unable to read/write data
- Permission denied errors
- Overly permissive rules discovered

**Rollback Steps:**

1. **Check git history:**
```bash
git log --oneline --decorate -- firestore.rules
git diff HEAD~1 firestore.rules  # View changes
```

2. **Revert to previous rules:**
```bash
# Option A: Revert commit
git revert <commit-sha>

# Option B: Checkout previous version
git checkout <commit-sha> -- firestore.rules
```

3. **Deploy rolled-back rules:**
```bash
firebase deploy --only firestore:rules --project sierra-painting-staging
```

**Verification:**
```bash
# Test from client
# Login as test user
# Attempt to clock in
# Verify operation succeeds
```

**Expected Time:** 1-2 minutes
**Rollback Confirmation:** Users can read/write data successfully

**⚠️ CRITICAL:** Firestore rules changes are IMMEDIATE. Test thoroughly before deploying.

---

## Scenario 4: Rollback Firestore Indexes

**When to Use:**
- Query performance degraded
- "Index not found" errors
- Unused indexes consuming quota

**Rollback Steps:**

1. **Check deployed indexes:**
```bash
firebase firestore:indexes --project sierra-painting-staging
```

2. **Revert indexes file:**
```bash
git checkout <commit-sha> -- firestore.indexes.json
```

3. **Deploy previous indexes:**
```bash
firebase deploy --only firestore:indexes --project sierra-painting-staging
```

**Verification:**
```bash
# Query should complete without index errors
# Check Cloud Firestore console for index status
```

**Expected Time:** 5-15 minutes (index build time)
**Rollback Confirmation:** Queries execute without "index not found" errors

---

## Scenario 5: Rollback Database Restore (Emergency)

**When to Use:**
- Data corruption detected
- Accidental mass deletion
- Schema migration failure

**Prerequisites:**
- Backup file from `tools/backup_firestore.sh`
- Backup stored in `gs://sierra-painting-staging-backups/`

**Rollback Steps:**

1. **List available backups:**
```bash
gsutil ls gs://sierra-painting-staging-backups/
```

2. **Download backup:**
```bash
# Create restore directory
mkdir -p backups/restore

# Download backup (replace date with desired backup)
gsutil -m cp -r gs://sierra-painting-staging-backups/2025-10-11 backups/restore/
```

3. **Restore data:**
```bash
# Use restore script
bash tools/restore_firestore.sh backups/restore/2025-10-11
```

**⚠️ WARNING:** This will OVERWRITE current data. Confirm with team lead before executing.

**Expected Time:** 30-60 minutes (depends on data size)
**Rollback Confirmation:** Spot-check 10 random documents to verify restore

---

## Post-Rollback Checklist

- [ ] Verify rollback succeeded (run verification steps above)
- [ ] Update team in Slack/Discord
- [ ] Create incident postmortem issue
- [ ] Document root cause
- [ ] Update this runbook if gaps found
- [ ] Schedule fix deployment after root cause addressed

---

## Common Issues & Fixes

### Issue: `firebase hosting:rollback` fails with "version not found"

**Fix:**
```bash
# List all versions
firebase hosting:channel:list --project sierra-painting-staging

# Rollback manually via Firebase Console
# Console → Hosting → Rollback button
```

---

### Issue: Function rollback succeeds but errors persist

**Diagnosis:** Corrupted environment config

**Fix:**
```bash
# Re-check Firebase Functions config
firebase functions:config:get --project sierra-painting-staging

# Verify env variables match .env.staging
```

---

### Issue: Rules rollback causes different permissions issue

**Diagnosis:** Client app caching old rules

**Fix:**
```bash
# Force clients to refresh
# Users must refresh browser (Ctrl+Shift+R)
# Mobile users must restart app
```

---

## Emergency Contacts

- **On-Call Engineer:** @valle
- **Firebase Admin:** valle@sierrapainting.com
- **GCP Console:** https://console.cloud.google.com/home/dashboard?project=sierra-painting-staging
- **Firebase Console:** https://console.firebase.google.com/project/sierra-painting-staging

---

## Rollback Decision Matrix

| Severity | Impact | Action | Approval Required |
|----------|--------|--------|-------------------|
| **P0** | Site down | Rollback immediately | None (inform after) |
| **P1** | Major feature broken | Rollback within 15 min | Team lead |
| **P2** | Minor bug | Fix forward or rollback | Team consensus |
| **P3** | Cosmetic issue | Fix forward | None |

---

**Last Tested:** Never (needs restore drill)
**Next Review:** 2025-10-26
