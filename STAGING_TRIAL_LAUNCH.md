# 🚀 Staging Trial Launch - Client Onboarding Package
**Launch Date**: 2025-10-13
**Trial Duration**: 7 days
**Environment**: sierra-painting-staging

---

## Client Access Information

### 🌐 **Application URL**
**https://sierra-painting-staging.web.app**

### 👤 **Test Credentials**

**Admin User**:
- Email: [Provide via secure channel]
- UID: `yqLJSx5NH1YHKa9WxIOhCrqJcPp1`
- Role: Admin
- Access: Full system (review, approve, manage)

**Worker User**:
- Email: [Provide via secure channel]
- UID: `d5POlAllCoacEAN5uajhJfzcIJu2`
- Role: Worker
- Access: Clock in/out, view timesheet

### 🏢 **Company Configuration**
- Company ID: `test-company-staging`
- Name: Test Company - Staging

### 📍 **Test Job Site**
- Job ID: `test-job-staging`
- Name: Test Job - SF
- Address: Painted Ladies, San Francisco, CA
- Location: 37.7793, -122.4193
- Geofence: 150 meters
- Status: Active

---

## Quick Start Guide for Client

### For Workers (Clock-In Flow)

1. **Open the app**: Visit https://sierra-painting-staging.web.app
2. **Sign in** with worker credentials
3. **Check assignment**: Green card should show "Assigned to Job: Test Job - SF"
4. **Clock in**:
   - Press the green "Clock In" button
   - Grant location permission when prompted
   - Wait for confirmation (should appear in <5 seconds)
5. **Work your shift**: App tracks elapsed time
6. **Clock out**: Press orange "Clock Out" button when done

### For Admins (Review Flow)

1. **Sign in** with admin credentials
2. **Navigate to Admin Dashboard**
3. **Review time entries**: See all clock-ins/outs
4. **Check for exceptions**:
   - Red badges = geofence violations
   - Orange badges = other issues
5. **Approve/reject**: Use bulk actions or individual review

---

## Expected Behavior

### ✅ **Normal Flow**
- Clock-in completes in <5 seconds
- Green confirmation message appears
- Time entry shows in "Recent Entries"
- Elapsed time updates every minute
- Clock-out completes successfully

### ⚠️ **Expected Warnings**
- GPS accuracy warning if signal weak (>50m)
- Geofence warning if outside job radius
- Offline mode if no internet (queues for sync)

### 🚫 **What Should NOT Happen**
- Infinite loading spinners
- App crashes
- Location permission loops
- Duplicate time entries
- Lost clock-in data

---

## Support Information

### 🆘 **If Something Goes Wrong**

**Contact**: [Your support email/Slack]

**What to Share**:
1. Screenshot of the error message
2. Time the error occurred
3. What action triggered it
4. Device type (iPhone, Android, Web browser)

**Response Time**:
- Critical issues (app down): 15 minutes
- Degraded performance: 2 hours
- UX confusion: Next business day

### 📞 **Emergency Rollback**
If the app is unusable:
```bash
# Admin can rollback deployment
firebase hosting:rollback --project sierra-painting-staging
```

---

## Monitoring Dashboard

### Daily Health Checks (Internal Team - 5 min/day)

**Error Rate Check**:
```bash
firebase functions:log --project sierra-painting-staging | grep -i error | head -20
```
Target: <1% error rate

**App Check Status**:
```bash
firebase functions:log --project sierra-painting-staging | grep -i "app-check" | head -10
```
Target: 0 rejections

**Performance Check**:
```bash
firebase functions:log --project sierra-painting-staging | grep "execution took" | head -10
```
Target: P95 <2 seconds

**Crashlytics**:
Visit: https://console.firebase.google.com/project/sierra-painting-staging/crashlytics
Target: 0 fatal crashes

---

## Feedback Collection

### 📋 **Daily Check-In Questions** (Ask client end of day)

1. How many times did your team clock in today?
2. Did any clock-ins fail or error out?
3. Were there any confusing error messages?
4. Did the app feel slow at any point?
5. Any location/GPS issues?

### 📊 **Weekly Metrics** (Collect Friday)

| Metric | Target | Actual | Status |
|--------|--------|--------|--------|
| Total clock-ins | N/A | ___ | ✅/⚠️/🚫 |
| Success rate | >95% | ___% | ✅/⚠️/🚫 |
| Avg clock-in time | <5s | ___s | ✅/⚠️/🚫 |
| Fatal crashes | 0 | ___ | ✅/⚠️/🚫 |
| User satisfaction | ≥4/5 | ___/5 | ✅/⚠️/🚫 |

### 📝 **End-of-Trial Survey**

**Scale: 1-5 (1=Poor, 5=Excellent)**

1. How easy was it to clock in/out? __/5
2. How reliable was the location detection? __/5
3. How clear were the error messages? __/5
4. How fast was the app? __/5
5. Would you use this in production? Yes/No

**Open Feedback**:
- What did you like most?
- What was frustrating?
- What features are missing?
- Any bugs or glitches?

---

## Trial Success Criteria

### ✅ **GO for Production** (After 7 Days)
- ≥95% clock-in/out success rate
- Zero fatal crashes
- No P0 incidents (app down)
- Client satisfaction ≥4/5
- Performance P95 <2 seconds

### ⚠️ **CONDITIONAL GO**
- 90-94% success rate (need investigation)
- 1-2 P2 incidents (fixes deployed)
- Client satisfaction 3/5
- Performance 2-3 seconds

### 🚫 **NO-GO**
- <90% success rate
- Any unresolved P0 incident
- Fatal crashes affecting >5% users
- Client requests to stop trial
- Performance consistently >3 seconds

---

## Known Limitations (Staging)

1. **Geofence Radius**: Set to 150m for testing (may need adjustment)
2. **Auto Clock-Out**: Runs every 5 minutes (not real-time)
3. **Offline Mode**: Basic implementation (sync on reconnect)
4. **Admin Features**: Limited (no bulk editing yet)
5. **Notifications**: Not implemented in staging

---

## Technical Details (For Your Reference)

### Infrastructure
- **Hosting**: Firebase Hosting (CDN)
- **Backend**: Cloud Functions Gen2 (us-east4)
- **Database**: Firestore (multi-region)
- **Auth**: Firebase Authentication
- **Security**: App Check (ReCAPTCHA v3)

### Data Retention
- Time entries: Retained indefinitely
- Function logs: 30 days
- Crashlytics: 90 days
- Performance traces: 90 days

### Privacy
- Location data: Stored encrypted
- User emails: Hashed in logs
- GPS coordinates: Only at clock-in/out
- No continuous tracking

---

## Timeline

**Day 0 (Today)**: Launch + onboarding
**Days 1-6**: Daily monitoring + feedback collection
**Day 7 (Friday)**: Weekly review + go/no-go decision

**Post-Trial**:
- If GO: Plan production deployment
- If CONDITIONAL: Fix issues, extend trial
- If NO-GO: Major fixes, restart trial

---

## Quick Links

- **Staging App**: https://sierra-painting-staging.web.app
- **Firebase Console**: https://console.firebase.google.com/project/sierra-painting-staging
- **Firestore Data**: https://console.firebase.google.com/project/sierra-painting-staging/firestore
- **Function Logs**: https://console.firebase.google.com/project/sierra-painting-staging/functions/logs
- **Crashlytics**: https://console.firebase.google.com/project/sierra-painting-staging/crashlytics
- **Performance**: https://console.firebase.google.com/project/sierra-painting-staging/performance

---

## Rollback Procedures

### If Critical Issue Occurs

**Hosting Rollback** (2 minutes):
```bash
firebase hosting:rollback --project sierra-painting-staging
```

**Functions Rollback** (5 minutes):
```bash
git checkout <previous-commit>
cd functions && npm run build
firebase deploy --only functions --project sierra-painting-staging
git checkout main
```

**Firestore Rules Rollback** (1 minute):
```bash
git checkout <previous-commit> -- firestore.rules
firebase deploy --only firestore:rules --project sierra-painting-staging
git checkout main -- firestore.rules
```

---

## Contact Information

**Primary Contact**: [Your name/email]
**Escalation**: [Manager name/email]
**Emergency**: [Phone number]

**Business Hours**: [Your hours]
**Response Time**:
- P0 (app down): 15 min
- P1 (degraded): 2 hours
- P2 (minor): Next business day

---

**Trial Start**: 2025-10-13
**Trial End**: 2025-10-20
**Go/No-Go Decision**: 2025-10-20 EOD

---

🚀 **Ready to launch! Send this package to your client and begin monitoring.**
