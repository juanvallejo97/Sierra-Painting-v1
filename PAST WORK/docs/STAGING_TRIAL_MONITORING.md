# Staging Trial Monitoring Plan (7-Day Window)

**Purpose**: Ensure production-readiness during staging client trial
**Duration**: 7 days from first client invite
**Owner**: Engineering team
**Escalation**: Immediate for P0 issues (app crashes, data loss)

---

## **Daily Health Checks** (5 minutes)

### **1. Functions Error Rate** (Target: <1%)
```bash
# Check last 24 hours of errors
firebase functions:log --project sierra-painting-staging --limit 100 \
  | grep -E "(error|Error|ERROR)" \
  | head -20
```

**Red Flags**:
- `clockIn` or `clockOut` errors >5% of calls
- `permission-denied` errors (Firestore rules issue)
- `unauthenticated` errors (App Check misconfiguration)
- Timeout errors >10%

### **2. App Check Rejections** (Target: 0)
```bash
# Check for App Check denials
firebase functions:log --project sierra-painting-staging --limit 100 \
  | grep -i "app-check"
```

**Action If >0**: Register debug tokens for affected devices immediately.

### **3. Crashlytics Fatal Errors** (Target: 0)
Visit: [Firebase Console → Crashlytics](https://console.firebase.google.com/project/sierra-painting-staging/crashlytics)

**Red Flags**:
- Any crash affecting >1% of users
- Crashes in clock-in flow
- Location service crashes

### **4. Performance Degradation** (Target: P95 <2s)
```bash
# Check function latency
firebase functions:log --project sierra-painting-staging --limit 50 \
  | grep "execution took"
```

**Red Flags**:
- `clockIn` execution >3s
- `clockOut` execution >3s
- Firestore query timeout errors

---

## **Weekly Review** (30 minutes, Friday)

### **Metrics to Capture**

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Total clock-ins | N/A | ___ | ✅/⚠️/🚫 |
| Total clock-outs | N/A | ___ | ✅/⚠️/🚫 |
| Success rate | >95% | ___% | ✅/⚠️/🚫 |
| P95 latency (clockIn) | <2s | ___s | ✅/⚠️/🚫 |
| P95 latency (clockOut) | <2s | ___s | ✅/⚠️/🚫 |
| Fatal crashes | 0 | ___ | ✅/⚠️/🚫 |
| Support tickets | <3/week | ___ | ✅/⚠️/🚫 |

### **User Feedback Collection**

**Questions to ask client**:
1. Did any clock-ins fail? (screenshot if possible)
2. Were there any "GPS not found" errors?
3. Did the app feel slow or unresponsive?
4. Any confusing error messages?
5. Did offline mode work as expected?

### **Code Quality Snapshot**
```bash
# Run analyzer + tests
flutter analyze | tail -5
flutter test | tail -10
cd functions && npm test | tail -10
```

---

## **Incident Response**

### **P0: App Down / Data Loss**
**Symptoms**: >50% of clock-in attempts failing, Crashlytics showing fatal errors

**Response**:
1. Check functions logs for root cause
2. Rollback if needed: `firebase hosting:channel:deploy --only hosting previous`
3. Notify client within 15 minutes
4. Post-mortem within 24 hours

### **P1: Degraded Performance**
**Symptoms**: Clock-in taking >5s, users complaining of slowness

**Response**:
1. Check Firestore query performance (indexes)
2. Check functions cold start rate
3. Optimize queries if needed
4. Deploy hotfix within 48 hours

### **P2: UX Confusion**
**Symptoms**: Users asking "how do I clock in?", unclear error messages

**Response**:
1. Document exact user flow that caused confusion
2. Update error messages for clarity
3. Add contextual help/tooltips
4. Deploy improvement in next release

---

## **Rollback Procedure**

### **Hosting Rollback** (2 minutes)
```bash
# List recent deploys
firebase hosting:channel:list --project sierra-painting-staging

# Rollback to previous version
firebase hosting:rollback --project sierra-painting-staging
```

### **Functions Rollback** (5 minutes)
```bash
# Redeploy previous version from Git
git checkout <previous-commit-sha>
cd functions && npm run build
firebase deploy --only functions --project sierra-painting-staging
git checkout main
```

### **Firestore Rules Rollback** (1 minute)
```bash
# Revert rules file
git checkout <previous-commit-sha> -- firestore.rules
firebase deploy --only firestore:rules --project sierra-painting-staging
git checkout main -- firestore.rules
```

---

## **Success Criteria** (End of Trial)

**✅ GO for Production** if:
- ≥95% success rate for clock-in/out
- Zero fatal crashes
- No P0 incidents
- Client feedback positive (≥4/5 satisfaction)
- Performance within SLA (P95 <2s)

**⚠️ CONDITIONAL GO** if:
- 90-94% success rate (investigate failures)
- 1-2 P2 incidents (fixes deployed)
- Client feedback neutral (3/5)
- Performance borderline (P95 2-3s)

**🚫 NO-GO** if:
- <90% success rate
- Any P0 incident without resolution
- Fatal crashes affecting >5% users
- Client requests to pause/stop
- Performance consistently >3s

---

## **Artifacts to Collect**

Create `artifacts/staging-trial/` directory with:

1. **logs/**: Daily function logs snapshots
2. **metrics/**: Weekly metric summaries
3. **feedback/**: Client feedback notes
4. **incidents/**: Any incident reports + resolutions
5. **screenshots/**: UI evidence of issues (if any)

### **End-of-Trial Report Template**
```markdown
# Staging Trial Report

**Duration**: [dates]
**Total Clock-Ins**: X
**Success Rate**: Y%
**Incidents**: Z

## Highlights
- [Key wins]

## Issues Identified
- [Issue 1 + resolution]
- [Issue 2 + status]

## Client Feedback
- [Quote 1]
- [Quote 2]

## Recommendation
[GO / CONDITIONAL GO / NO-GO] for production deployment

Rationale: [2-3 sentences]
```

---

## **Tools & Links**

- **Staging Console**: https://console.firebase.google.com/project/sierra-painting-staging
- **Hosting URL**: https://sierra-painting-staging.web.app
- **Functions Logs**: `firebase functions:log --project sierra-painting-staging`
- **Firestore Console**: https://console.firebase.google.com/project/sierra-painting-staging/firestore
- **Performance Monitoring**: https://console.firebase.google.com/project/sierra-painting-staging/performance

---

**Last Updated**: 2025-10-13
**Next Review**: [Set date for first daily check]
