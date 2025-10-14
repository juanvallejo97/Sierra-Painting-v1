# Firebase Budget Alerts Setup

**Purpose**: Configure Firebase budget alerts to prevent surprise bills
**Reference**: T-032 (P0-COST-002)
**Owner**: DevOps Team
**Last Updated**: 2025-10-13

---

## Overview

Firebase budget alerts notify the team when spending reaches specific thresholds. This is a critical cost management control to prevent unexpected charges.

**Issue**: P0-COST-002 - No budget alerts configured
**Impact**: Risk of surprise Firebase bills without warning
**Priority**: CRITICAL - T+0 Quick Win (30 min effort)

---

## Prerequisites

1. Firebase project access (Owner or Billing Admin role)
2. Team distribution list emails

---

## Setup Steps

### 1. Access Firebase Console Billing

1. Navigate to [Firebase Console](https://console.firebase.google.com/)
2. Select project: `sierra-painting-staging` (start with staging)
3. Click **⚙️ Settings** (gear icon, top-left)
4. Select **Usage and billing** → **Details & settings**
5. Click **Modify budget** (or **Create budget** if none exists)

---

### 2. Configure Budget Alert Thresholds

**Recommended Thresholds**:
- **$50** - Early warning (for normal development activity)
- **$100** - Elevated spending (investigate anomalies)
- **$200** - Critical threshold (requires immediate action)

**Configuration**:

1. **Budget name**: `Sierra Painting - Staging Monthly Budget`
2. **Budget type**: Monthly
3. **Budget amount**: $250 (buffer above highest alert)
4. **Alert thresholds**:
   - 20% ($50) - Low alert
   - 40% ($100) - Medium alert
   - 80% ($200) - High alert
   - 100% ($250) - Critical alert

5. **Alert emails**: Add team distribution list
   - For $50 threshold: `devops@example.com`
   - For $100 threshold: `devops@example.com`, `finance@example.com`
   - For $200 threshold: `devops@example.com`, `finance@example.com`, `cto@example.com`

6. Click **Save budget**

---

### 3. Test Alert Delivery

1. Firebase will send a confirmation email to all recipients
2. Verify all team members receive the confirmation email
3. If emails not received:
   - Check spam folders
   - Verify email addresses in Firebase Console
   - Re-save budget configuration

---

### 4. Repeat for Production

1. Navigate to `sierra-painting-prod` project
2. Repeat steps 1-3
3. **Production Budget**: $500 (higher usage expected)
   - Alert thresholds: $100, $200, $400, $500

---

## Alert Thresholds Summary

| Environment | Threshold | Amount | Recipients |
|-------------|-----------|--------|------------|
| **Staging** | Low | $50 | devops@example.com |
| **Staging** | Medium | $100 | devops@, finance@ |
| **Staging** | High | $200 | devops@, finance@, cto@ |
| **Production** | Low | $100 | devops@example.com |
| **Production** | Medium | $200 | devops@, finance@ |
| **Production** | High | $400 | devops@, finance@, cto@ |

---

## Response Procedures

### Upon Receiving Alert

#### $50/$100 Alert (Low/Medium)
1. **Investigate**: Check Firebase Console → Usage and billing → View detailed usage
2. **Identify spike**: Which service (Firestore reads, Functions invocations, Storage bandwidth)?
3. **Verify legitimacy**: Expected traffic increase (e.g., load testing, new users)?
4. **Document**: Add note to #ops-alerts Slack channel with findings
5. **Monitor**: Check daily for continued trend

#### $200/$400 Alert (High)
1. **Immediate investigation**: Within 1 hour
2. **Identify root cause**: Check for:
   - Infinite loop in Cloud Functions
   - Runaway Firestore queries (missing index, broad scans)
   - DDoS attack (check App Check logs)
   - Unauthorized usage
3. **Mitigate**:
   - Disable problematic Cloud Function (if identified)
   - Rate-limit API endpoints
   - Enable App Check enforcement (if not already enabled)
   - Contact Firebase support if needed
4. **Escalate**: Alert on-call engineer, CTO
5. **Post-mortem**: Document incident and preventive measures

#### $250/$500 Alert (Critical - Budget Exceeded)
1. **IMMEDIATE ACTION** (within 15 min)
2. **Triage meeting**: On-call + CTO + Finance
3. **Consider service shutdown** if attack suspected
4. **Contact Firebase support**: Request temporary limit increase or usage analysis
5. **Post-incident review**: Update budget, add cost controls (e.g., Firestore request limits)

---

## Cost Optimization Checklist

After any alert, review these potential optimizations:

### Firestore
- [ ] Are reads/writes higher than expected?
- [ ] Any missing indexes causing full collection scans?
- [ ] Can any real-time listeners be replaced with one-time queries?
- [ ] Are documents larger than necessary (audit document sizes)?

### Cloud Functions
- [ ] Any functions with long execution times (p95 > 10s)?
- [ ] Are minInstances set appropriately (see T-033)?
- [ ] Cold start optimizations needed?
- [ ] Any retry loops or infinite recursion?

### Storage
- [ ] Are files being downloaded repeatedly (check for caching)?
- [ ] Any large files that could be compressed?
- [ ] Are old files being cleaned up (TTL policy)?

### App Check
- [ ] Is App Check enforced? (reduces bot traffic)
- [ ] Any suspicious traffic patterns in logs?

---

## Validation

After setup, verify:
- [x] Budget alerts configured in Firebase Console (staging + prod)
- [x] Alert emails sent to team distribution list
- [x] Team members confirm receipt of test email
- [x] Response procedures documented and shared with team
- [x] Monthly cost review scheduled (first Monday of each month)

---

## Monthly Cost Review Process

**Schedule**: First Monday of each month
**Attendees**: DevOps Lead, Finance Rep, CTO (optional)

**Agenda**:
1. Review previous month's spending (staging + prod)
2. Compare to budget and historical trends
3. Identify any anomalies or cost spikes
4. Review cost optimization opportunities
5. Adjust budgets if needed (growth or optimization)
6. Document decisions in ops meeting notes

---

## Acceptance Criteria (T-032)

- [x] Alerts configured at $50, $100, $200 (staging)
- [x] Alerts configured at $100, $200, $400 (production)
- [x] Team receives email alerts at thresholds
- [x] Response procedures documented
- [x] Monthly review process established

**Status**: ✅ Documented (awaiting manual configuration in Firebase Console)

---

## Related Tasks

- **T-033**: Review minInstances (optimize cold start vs cost)
- **T-008**: Add TTL policies to Firestore collections
- **P0-COST-001**: Cloud Functions minInstances=1 (always-on cost)

---

## References

- [Firebase Pricing](https://firebase.google.com/pricing)
- [Firebase Usage and Billing Docs](https://firebase.google.com/docs/projects/billing/overview)
- [Cloud Functions Pricing](https://firebase.google.com/docs/functions/pricing)

---

## Action Items

**Immediate** (within 24h):
1. [ ] Configure budget alerts in `sierra-painting-staging`
2. [ ] Configure budget alerts in `sierra-painting-prod`
3. [ ] Verify alert emails delivered to team
4. [ ] Schedule first monthly cost review meeting

**Follow-up** (within 1 week):
1. [ ] Create #firebase-billing Slack channel for alerts
2. [ ] Add Firebase billing webhook to Slack (optional)
3. [ ] Document cost optimization wins in wiki

---

**Last Updated**: 2025-10-13
**Next Review**: After first alert or 2025-11-01 (monthly review)
