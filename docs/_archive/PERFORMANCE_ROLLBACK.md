# Performance Rollback Procedures

> **Purpose**: Emergency rollback procedures for performance-related issues
>
> **Last Updated**: 2024
>
> **Status**: Active

---

## Overview

This document provides step-by-step rollback procedures when performance optimizations cause issues in production.

---

## When to Rollback

### Critical Triggers (Immediate Rollback)

- **Error Rate Spike**: > 5% increase in errors
- **Latency Spike**: P95 > 2x baseline
- **Crash Rate**: > 1% of sessions
- **User Reports**: Multiple complaints within 1 hour
- **Budget Violations**: Critical budgets exceeded by >50%

### Warning Triggers (Monitor Closely)

- **Minor Error Increase**: 1-5% error rate increase
- **Moderate Latency**: P95 increased by 50-100%
- **Increased Resource Usage**: Memory/CPU 50% above normal
- **Isolated Issues**: Single user segment affected

---

## Rollback Methods

### Method 1: Feature Flag Toggle (Fastest)

**Time to Rollback**: < 5 minutes  
**Impact**: Instant for clients, requires app restart

#### Steps:

1. **Access Firebase Console**
   ```
   https://console.firebase.google.com
   → Project → Remote Config
   ```

2. **Update Flag**
   - Find the relevant feature flag
   - Set to `false` (disabled)
   - Click "Publish changes"

3. **Verify**
   - Check real-user metrics in Firebase Performance
   - Monitor error rates in Crashlytics
   - Wait 5-10 minutes for changes to propagate

**Example Flags:**
```
enable_performance_monitoring: false
enable_new_caching: false
enable_isolate_compute: false
```

#### Affected Areas:
- Performance monitoring
- Caching strategies
- Compute-intensive operations
- New optimization features

---

### Method 2: App Version Rollback (Moderate)

**Time to Rollback**: 1-4 hours  
**Impact**: Requires user to update or wait for Play Store rollout

#### Steps:

1. **Play Store Console**
   ```
   https://play.google.com/console
   → Your App → Release → Production
   ```

2. **Halt Current Rollout**
   - Click "Halt rollout" on active release
   - Confirm action

3. **Rollback to Previous Version**
   - Select previous stable version
   - Click "Resume rollout" or "Create new release"
   - Set rollout to 100% (or staged: 10% → 50% → 100%)

4. **Monitor**
   - Watch Play Store console for crash reports
   - Check Firebase Performance metrics
   - Monitor user reviews

**Timeline:**
- Halt: Immediate
- Rollback initiated: 15 minutes
- 50% users updated: 2-6 hours
- 90% users updated: 24-48 hours

---

### Method 3: Cloud Functions Rollback (Fast)

**Time to Rollback**: < 10 minutes  
**Impact**: Immediate for all API calls

#### Steps:

1. **List Deployed Versions**
   ```bash
   firebase functions:log --only clockIn
   gcloud functions list --project=sierra-painting
   ```

2. **Identify Previous Version**
   ```bash
   # Check Git history
   git log --oneline functions/src/
   
   # Find stable commit
   git show <commit-hash>:functions/src/index.ts
   ```

3. **Rollback Code**
   ```bash
   # Option A: Git revert (recommended)
   git revert <bad-commit-hash>
   git push origin main
   
   # Option B: Deploy previous version
   git checkout <previous-commit-hash> -- functions/
   firebase deploy --only functions
   ```

4. **Verify Deployment**
   ```bash
   # Check logs
   firebase functions:log --only clockIn --lines 50
   
   # Test function
   curl -X POST https://us-central1-sierra-painting.cloudfunctions.net/clockIn \
     -H "Content-Type: application/json" \
     -d '{"test": true}'
   ```

**What Gets Rolled Back:**
- Function logic changes
- Performance optimizations
- minInstances configuration
- Memory/timeout settings

---

### Method 4: Firestore Rules Rollback (Fast)

**Time to Rollback**: < 5 minutes  
**Impact**: Immediate for all database operations

#### Steps:

1. **Access Firebase Console**
   ```
   Firebase Console → Firestore → Rules
   ```

2. **View History**
   - Click "History" tab
   - Find last known good version
   - Note timestamp

3. **Rollback**
   - Click on previous version
   - Click "Restore"
   - Confirm

4. **Alternative: CLI**
   ```bash
   # Deploy previous rules from git
   git checkout <previous-commit> -- firestore.rules
   firebase deploy --only firestore:rules
   ```

5. **Verify**
   - Test read/write operations
   - Check error logs
   - Monitor denied requests

---

## Communication Template

### Internal Alert (Slack/Email)

```
🚨 ROLLBACK IN PROGRESS

Issue: [Brief description]
Severity: [Critical/High/Medium]
Affected: [Mobile app/Backend/Both]
Method: [Feature flag/App version/Functions/Rules]
ETA: [Time to complete]

Actions:
1. [Step 1]
2. [Step 2]
3. [Step 3]

Status: IN PROGRESS
Lead: @engineer-name
Incident: #INC-XXXX
```

### User Communication (Status Page)

```
⚠️ Service Disruption

We're experiencing performance issues affecting [feature].
Our team is actively working on a fix.

Status: Investigating → Identified → Implementing → Monitoring
ETA: [Time]
Last Updated: [Timestamp]

Updates will be posted here as we work to resolve this.
```

---

## Post-Rollback Actions

### Immediate (< 1 hour)

- [ ] Verify metrics returned to baseline
- [ ] Check error rates normalized
- [ ] Monitor user reports
- [ ] Update status page
- [ ] Notify team of completion

### Short-term (24 hours)

- [ ] Write incident report
- [ ] Identify root cause
- [ ] Create fix plan
- [ ] Update tests to catch issue
- [ ] Schedule postmortem meeting

### Long-term (1 week)

- [ ] Implement fixes
- [ ] Add monitoring/alerts
- [ ] Update documentation
- [ ] Share learnings with team
- [ ] Plan re-deployment

---

## Incident Report Template

```markdown
# Incident Report: [Brief Title]

## Summary
- **Date**: [YYYY-MM-DD]
- **Duration**: [Start] to [End] ([Duration])
- **Severity**: [Critical/High/Medium/Low]
- **Affected**: [Number of users / % of traffic]

## Timeline
- **HH:MM** - Issue detected
- **HH:MM** - Incident declared
- **HH:MM** - Rollback initiated
- **HH:MM** - Service restored
- **HH:MM** - Incident closed

## Root Cause
[Detailed explanation of what went wrong]

## Impact
- **Users Affected**: [Number/percentage]
- **Services**: [List affected services]
- **Revenue**: [If applicable]

## Resolution
[How the issue was resolved]

## Rollback Performed
- **Method**: [Feature flag/App version/Functions/Rules]
- **Time to Rollback**: [Duration]
- **Verification**: [How we confirmed it worked]

## Prevention
- [ ] [Action item 1]
- [ ] [Action item 2]
- [ ] [Action item 3]

## Learnings
- [Key learning 1]
- [Key learning 2]
- [Key learning 3]

## Action Items
| Item | Owner | Due Date | Status |
|------|-------|----------|--------|
| Fix root cause | @engineer | YYYY-MM-DD | Open |
| Add monitoring | @engineer | YYYY-MM-DD | Open |
| Update docs | @engineer | YYYY-MM-DD | Open |
```

---

## Rollback Checklist

### Pre-Rollback
- [ ] Identify issue and severity
- [ ] Notify team (Slack/email)
- [ ] Choose rollback method
- [ ] Prepare rollback commands
- [ ] Document current state

### During Rollback
- [ ] Execute rollback procedure
- [ ] Monitor metrics in real-time
- [ ] Update status page
- [ ] Communicate progress
- [ ] Take screenshots/logs

### Post-Rollback
- [ ] Verify service restored
- [ ] Check metrics normalized
- [ ] Update status page
- [ ] Notify team of completion
- [ ] Start incident report

### Follow-up
- [ ] Complete incident report
- [ ] Schedule postmortem
- [ ] Create fix tasks
- [ ] Update runbooks
- [ ] Test rollback procedure

---

## Emergency Contacts

| Role | Contact | Availability |
|------|---------|--------------|
| On-call Engineer | [Slack/Phone] | 24/7 |
| Engineering Lead | [Slack/Phone] | Business hours |
| Product Manager | [Slack/Email] | Business hours |
| DevOps | [Slack/Phone] | 24/7 |

---

## Monitoring Dashboards

### Firebase Performance
```
https://console.firebase.google.com/project/[PROJECT]/performance
```

### Cloud Monitoring
```
https://console.cloud.google.com/monitoring/dashboards?project=[PROJECT]
```

### Error Tracking
```
https://console.firebase.google.com/project/[PROJECT]/crashlytics
```

---

## Related Documentation

- [Performance Budgets](./PERFORMANCE_BUDGETS.md)
- [Deployment Checklist](./deployment_checklist.md)
- [Rollout & Rollback Guide](./rollout-rollback.md)
- [Backend Performance](./BACKEND_PERFORMANCE.md)

---

## Quick Commands

**Check current metrics:**
```bash
# Firebase Performance
firebase performance:list --project sierra-painting

# Cloud Functions logs
firebase functions:log --lines 100

# Git history
git log --oneline -10
```

**Rollback via git:**
```bash
# Revert last commit
git revert HEAD
git push origin main

# Deploy previous version
git checkout <commit> -- functions/
firebase deploy --only functions
```

**Update feature flag:**
```bash
# Via Firebase CLI (if configured)
firebase remoteconfig:get
firebase remoteconfig:set --data '{"enable_feature": false}'
```
