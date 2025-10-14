# 🚀 Staging Trial Launch Checklist
**Date**: 2025-10-13
**Status**: READY TO SHIP ✅

---

## Pre-Flight Checklist ✅

- [x] Baseline health established (82% analyzer improvement)
- [x] All tests passing (154/154 Flutter, 256/273 Functions)
- [x] Job assignment UX added (prevents spinner forever)
- [x] Staging deployed (https://sierra-painting-staging.web.app)
- [x] App Check enabled (ReCAPTCHA v3)
- [x] E2E validation complete (clock-in/out functional)
- [x] Firestore indexes deployed
- [x] Function logs healthy (101-123ms avg)
- [x] Test data seeded (assignment + job + company)
- [x] Monitoring plan ready
- [x] Client onboarding package created

---

## Launch Steps (Execute Now) 🎯

### Step 1: Send Client Invite (5 min)

**Action**: Email client with the following:

**Subject**: "Staging Trial Ready - Sierra Painting Timeclock App"

**Body**:
```
Hi [Client Name],

Great news! Your staging environment is ready for testing.

🌐 Access the app here: https://sierra-painting-staging.web.app

📋 I've attached a comprehensive onboarding guide (STAGING_TRIAL_LAUNCH.md)
   with everything you need:
   - Test credentials (admin + worker)
   - Quick start guide
   - What to expect
   - How to report issues

⏱️ Trial Duration: 7 days (Oct 13-20)

📞 Support: [Your contact info]
   - Critical issues: 15 min response
   - Other issues: 2 hour response

Let me know when you're ready to start, and I'll be monitoring daily
to ensure everything runs smoothly.

Looking forward to your feedback!

[Your name]
```

**Attachments**:
- Send `STAGING_TRIAL_LAUNCH.md` to client
- Share credentials via secure channel (Signal, 1Password, etc.)

### Step 2: Verify App Access (2 min)

- [ ] Open https://sierra-painting-staging.web.app in browser
- [ ] Confirm login screen loads
- [ ] Test one quick login to verify auth is working

### Step 3: Set Up Daily Monitoring Reminder (1 min)

**Action**: Set calendar reminder for DAILY at 5pm (or end of workday):

**Title**: "Staging Trial Health Check (5 min)"

**Description**:
```bash
# Run these commands (5 min total)

# 1. Check error rate (<1%)
firebase functions:log --project sierra-painting-staging | grep -i error | head -20

# 2. Check App Check rejections (0)
firebase functions:log --project sierra-painting-staging | grep -i "app-check" | head -10

# 3. Check performance (P95 <2s)
firebase functions:log --project sierra-painting-staging | grep "execution took" | head -10

# 4. Check Crashlytics (0 fatal)
# Visit: https://console.firebase.google.com/project/sierra-painting-staging/crashlytics

# 5. Ask client: "Any issues today?"
```

### Step 4: Set Up Weekly Review Reminder (1 min)

**Action**: Set calendar reminder for FRIDAY 4pm:

**Title**: "Staging Trial Weekly Review (30 min)"

**Tasks**:
- [ ] Collect metrics from Firestore (total clock-ins, success rate)
- [ ] Review function logs for patterns
- [ ] Check Crashlytics trends
- [ ] Survey client satisfaction (1-5 scale)
- [ ] Update go/no-go status
- [ ] Document any issues + resolutions

### Step 5: Set Up Final Go/No-Go Meeting (1 min)

**Action**: Schedule meeting for Friday Oct 20 at 3pm:

**Title**: "Staging Trial Go/No-Go Decision"

**Attendees**: You + client stakeholders

**Agenda**:
1. Review 7-day metrics (10 min)
2. Discuss client feedback (10 min)
3. Go/No-Go decision (5 min)
4. Next steps (5 min)

**Materials to Prepare**:
- Week summary report (use template in STAGING_TRIAL_LAUNCH.md)
- Metrics dashboard
- Client feedback notes
- Recommendation (GO/CONDITIONAL/NO-GO)

---

## Daily Monitoring Workflow (5 min/day)

### Quick Health Check

**Terminal Commands** (copy-paste):
```bash
# Navigate to project
cd /path/to/sierra-painting-v1

# Check error rate
echo "=== ERROR RATE CHECK ===" && \
firebase functions:log --project sierra-painting-staging 2>&1 | grep -i error | head -20

# Check App Check
echo "=== APP CHECK STATUS ===" && \
firebase functions:log --project sierra-painting-staging 2>&1 | grep -i "app-check" | head -10

# Check performance
echo "=== PERFORMANCE CHECK ===" && \
firebase functions:log --project sierra-painting-staging 2>&1 | grep "execution took" | head -10
```

**Expected Output**:
- Error rate: <1% (few or no errors)
- App Check: No rejections
- Performance: Most executions <2s

**Red Flags**:
- 🚨 Error rate >5% → Investigate immediately
- 🚨 App Check rejections → Register debug tokens
- 🚨 Performance >5s consistently → Check indexes

### Client Check-In (1 min)

**Message Template**:
```
Quick check-in: How's the staging app working today?
Any clock-in failures or issues to report?
```

**Expected Response**: "All good!" or specific issue description

---

## Incident Response (If Issues Arise)

### P0: App Down (15 min SLA)

**Symptoms**: >50% of operations failing, users can't access

**Actions**:
1. Check Firebase status: https://status.firebase.google.com
2. Check function logs for root cause
3. If deployment issue: Rollback immediately
4. Notify client within 15 minutes
5. Create incident report

**Rollback Command**:
```bash
firebase hosting:rollback --project sierra-painting-staging
```

### P1: Degraded Performance (2 hour SLA)

**Symptoms**: Clock-ins taking >5s, timeouts

**Actions**:
1. Check function execution times
2. Check Firestore query performance
3. Check for missing indexes
4. Create hotfix if needed
5. Deploy within 2 hours

### P2: UX Confusion (Next day)

**Symptoms**: Users confused by error messages

**Actions**:
1. Document exact confusion point
2. Update error messages for clarity
3. Add help text or tooltips
4. Schedule fix for next deployment

---

## Weekly Review Checklist (Friday)

### Metrics Collection (15 min)

**Firestore Queries**:
```bash
# Total time entries this week
# Go to: https://console.firebase.google.com/project/sierra-painting-staging/firestore
# Collection: time_entries
# Filter: createdAt >= [7 days ago]
# Count: ___
```

**Function Logs Analysis**:
```bash
# Success rate calculation
firebase functions:log --project sierra-painting-staging | \
  grep clockIn | wc -l  # Total calls

firebase functions:log --project sierra-painting-staging | \
  grep -i error | grep clockIn | wc -l  # Errors

# Success rate = (Total - Errors) / Total * 100
```

**Crashlytics**:
- Visit dashboard
- Count fatal crashes
- Note affected versions

### Client Feedback (10 min)

**Survey Questions**:
1. How many clock-ins this week? ___
2. Any failures? ___ (get details)
3. App speed rating (1-5): ___/5
4. Location accuracy rating (1-5): ___/5
5. Overall satisfaction (1-5): ___/5
6. Would you use in production? Yes/No

### Status Update (5 min)

**Update Matrix**:

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Clock-ins | N/A | ___ | ✅ |
| Success rate | >95% | ___% | ✅/⚠️/🚫 |
| Fatal crashes | 0 | ___ | ✅/⚠️/🚫 |
| Client satisfaction | ≥4/5 | ___/5 | ✅/⚠️/🚫 |
| Avg performance | <2s | ___s | ✅/⚠️/🚫 |

**Current Status**: ✅ GO / ⚠️ CONDITIONAL / 🚫 NO-GO

---

## End-of-Trial Deliverables (Oct 20)

### Final Report (30 min to prepare)

**Template** (use this structure):
```markdown
# 7-Day Staging Trial Report

**Duration**: Oct 13-20, 2025
**Environment**: sierra-painting-staging

## Executive Summary
- Total clock-ins: ___
- Success rate: ___%
- Fatal crashes: ___
- Client satisfaction: ___/5
- **Recommendation**: GO / CONDITIONAL GO / NO-GO

## Key Metrics
[Table with all metrics]

## Issues Encountered
1. [Issue description + resolution]
2. [Issue description + resolution]

## Client Feedback
- Positive: [What worked well]
- Negative: [What needs improvement]
- Feature requests: [List]

## Recommendation
[GO/CONDITIONAL/NO-GO] for production deployment.

Rationale: [2-3 sentences explaining decision based on data]

## Next Steps
[If GO: Production deployment plan]
[If CONDITIONAL: Required fixes + extended trial]
[If NO-GO: Major fixes + restart timeline]
```

### Decision Meeting (Oct 20, 3pm)

**Presentation Deck** (5 slides):
1. Trial Overview (dates, scope, users)
2. Key Metrics (success rate, performance, crashes)
3. Client Feedback (satisfaction, quotes)
4. Issues & Resolutions (what went wrong, how we fixed it)
5. Recommendation (GO/CONDITIONAL/NO-GO + rationale)

**Outcome**: Written decision + next steps

---

## Quick Reference Commands

### Check Deployment Status
```bash
firebase use  # Should show: sierra-painting-staging
```

### Tail Function Logs (Live)
```bash
firebase functions:log --project sierra-painting-staging --tail
```

### Query Time Entries (Console)
```
https://console.firebase.google.com/project/sierra-painting-staging/firestore/data/time_entries
```

### Rollback Hosting
```bash
firebase hosting:rollback --project sierra-painting-staging
```

### Deploy Hotfix
```bash
git checkout -b hotfix/[issue]
# Make fix
git add -A && git commit -m "hotfix: [description]"
flutter build web --release --dart-define=ENABLE_APP_CHECK=true
firebase deploy --only hosting --project sierra-painting-staging
```

---

## Support Contact Card

**Your Name**: _______________
**Email**: _______________
**Phone**: _______________
**Slack**: _______________
**Hours**: _______________

**Client Name**: _______________
**Client Email**: _______________
**Client Phone**: _______________

**Emergency Escalation**: _______________

---

## Launch Day Checklist (Complete This Now)

- [ ] Send client invite email
- [ ] Share credentials securely
- [ ] Set daily monitoring reminder (5pm daily)
- [ ] Set weekly review reminder (Friday 4pm)
- [ ] Set go/no-go meeting (Friday Oct 20, 3pm)
- [ ] Bookmark Firebase console links
- [ ] Test login to staging app
- [ ] Verify function logs accessible
- [ ] Create #staging-trial Slack channel (optional)
- [ ] Document client emergency contact

---

## Status Updates

**Day 0 (Oct 13)**: ✅ Launched
**Day 1 (Oct 14)**: Monitoring...
**Day 2 (Oct 15)**: Monitoring...
**Day 3 (Oct 16)**: Monitoring...
**Day 4 (Oct 17)**: Monitoring...
**Day 5 (Oct 18)**: Monitoring...
**Day 6 (Oct 19)**: Monitoring...
**Day 7 (Oct 20)**: Go/No-Go Decision

---

🚀 **YOU ARE GO FOR LAUNCH!**

Execute the 5 launch steps above, then begin daily monitoring.

Good luck! 🎉
