# Open Questions for MVP Finalization

**Purpose**: Questions requiring client/product decisions before production deployment.

**Status**: Review and provide answers by [DATE]

**Priority**: 🔴 High (blocks deployment) | 🟡 Medium (affects UX) | 🟢 Low (can defer)

---

## 🔴 UX & Policy

### Q1: Grace Radius for Poor GPS Accuracy

**Question**: Should we add a grace radius when GPS accuracy is poor?

**Context**: When GPS accuracy is >50m, the worker's reported location could be off by that amount. Should we add accuracy as a buffer to the geofence radius?

**Options**:
- **A)** Add full accuracy as buffer: `effectiveRadius = baseRadius + accuracy`
  - Pro: More forgiving when GPS signal is weak
  - Con: Worker could be 150m+ away and still clock in
- **B)** Add partial buffer: `effectiveRadius = baseRadius + (accuracy * 0.5)`
  - Pro: Balanced approach
  - Con: More complex to explain
- **C)** No buffer, enforce strict accuracy threshold (<50m required)
  - Pro: Most accurate, clearest policy
  - Con: May block legitimate clock-ins in urban canyons

**Current Implementation**: Option A (full buffer, already coded)

**Recommendation**: **Option A** — Favors worker experience, rarely abused in practice

**Your Decision**: [ ]

---

### Q2: Breaks & Travel Time

**Question**: How should breaks and travel time be handled?

**Context**: Workers may take lunch breaks, travel between job sites, or run errands.

**Options**:
- **A)** Not in MVP — workers clock out for breaks, clock in at next job
  - Pro: Simple, no new features
  - Con: Workers may forget to clock out/in
- **B)** Add "Break" button (pauses timer, doesn't require clock-out)
  - Pro: Convenient, accurate time tracking
  - Con: Needs new UI, validation, approval workflow
- **C)** Add break types: paid vs unpaid
  - Pro: Complete feature
  - Con: Significant scope increase

**Current Implementation**: Option A (not in MVP)

**Recommendation**: **Option A** for MVP, add breaks in Month 2 based on user feedback

**Your Decision**: [ ]

---

### Q3: Timesheet Export Format

**Question**: What format and columns should timesheet exports use?

**Context**: Admins need to export timesheets for payroll processing.

**Required Columns**:
- Worker name
- Job name
- Clock in date/time
- Clock out date/time
- Total hours

**Questions**:
- **Rounding**: Round to nearest 0.1h, 0.25h, or exact?
- **Overtime**: Include OT calculation (>8h/day or >40h/week)?
- **Breaks**: If breaks added, show as separate rows or subtract from total?
- **Format**: CSV, Excel, PDF, or multiple options?

**Current Implementation**: Not yet implemented

**Recommendation**:
- CSV format (universally compatible)
- Round to nearest 0.1h (6 minutes)
- No OT calculation in export (payroll system handles this)
- Breaks shown as separate rows if added

**Your Decision**: [ ]

---

### Q4: Invoice Line Item Format

**Question**: How should labor be itemized on invoices?

**Options**:
- **A)** Single line: "Labor — {jobName}: {hours}h @ ${rate}/hr"
  - Pro: Simple, clean
  - Con: No daily breakdown
- **B)** Per-day breakdown: "Labor — {date}: {hours}h @ ${rate}/hr"
  - Pro: More detail for customer
  - Con: Long invoice for multi-week jobs
- **C)** Per-worker breakdown: "Labor — {workerName}, {dates}: {hours}h"
  - Pro: Shows who worked
  - Con: May reveal hourly rates (privacy concern)

**Current Implementation**: Option A (single line item)

**Recommendation**: **Option A** for MVP — simplest, fewest privacy concerns

**Your Decision**: [ ]

---

### Q5: Location Data Retention

**Question**: How long should precise GPS coordinates be retained?

**Context**: Precise GPS (lat/lng) is sensitive data. We need a retention policy.

**Options**:
- **A)** 90 days precise, then delete (keep only coarse geohash)
  - Pro: Balances audit needs with privacy
  - Con: Cannot resolve disputes after 90 days
- **B)** 1 year precise, then delete
  - Pro: Longer dispute window
  - Con: Longer data retention
- **C)** Forever (until time entry deleted)
  - Pro: Complete audit trail
  - Con: Privacy concerns, GDPR issues

**Geohash Alternative**: After TTL, keep geohash (precision ~150m) for compliance

**Current Implementation**: No TTL (stores forever)

**Recommendation**: **Option A** — 90 days precise, then coarse geohash

**Your Decision**: [ ]

---

## 🟡 Operational

### Q6: Minimum App OS Support

**Question**: What's the minimum Android/iOS version to support?

**Context**: Older devices may have limited GPS accuracy or missing features.

**Options**:
- **A)** Android 8+ (2017), iOS 13+ (2019)
  - Pro: Covers 95%+ of devices
  - Con: No support for very old phones
- **B)** Android 6+ (2015), iOS 11+ (2017)
  - Pro: Covers 99%+ of devices
  - Con: More testing, may have GPS issues
- **C)** Latest 2 OS versions only
  - Pro: Modern features, easier testing
  - Con: Excludes workers with older phones

**Current Implementation**: Flutter defaults (Android 5+, iOS 11+)

**Recommendation**: **Option A** — Good balance

**Your Decision**: [ ]

---

### Q7: Offline Behavior Expectations

**Question**: How long can clock operations remain pending offline?

**Context**: Workers may have spotty network in rural areas.

**Options**:
- **A)** 24 hours — auto-discard after 1 day
  - Pro: Fresh data, prevents stale clock-ins
  - Con: Loses data if worker offline for weekend
- **B)** 7 days — auto-discard after 1 week
  - Pro: Accommodates extended offline periods
  - Con: Stale data (worker may forget context)
- **C)** No TTL — keep until synced
  - Pro: Never loses data
  - Con: Queue can grow unbounded

**Current Implementation**: No TTL (keeps forever until synced)

**Recommendation**: **Option B** — 7 days with warning UI

**Your Decision**: [ ]

---

### Q8: Staging Alert Recipients

**Question**: Who should receive alerts when staging issues occur?

**Context**: Need email list for monitoring alerts (function errors, SLO violations).

**Required Info**:
- Email addresses for alerts
- Severity levels (critical, warning, info)
- Escalation policy (if critical unresponded for 1h)

**Recommendation**: Set up PagerDuty or similar for production; email for staging

**Your Decision**: [ ]

---

### Q9: Support Playbook Owners

**Question**: Who creates/maintains support playbooks for common issues?

**Common Issues Needing Playbooks**:
- **"Stuck clock-in"**: Worker says they're clocked in but app shows not
- **"False geofence"**: Worker at job site but can't clock in
- **"Lost time"**: Worker clocked in but entry missing
- **"GPS not working"**: Permission issues, weak signal

**Options**:
- **A)** Engineering creates initial playbooks, support team maintains
- **B)** Support team creates based on real issues
- **C)** Collaborative doc (Notion/Confluence)

**Recommendation**: **Option A** — Engineers create templates, support refines

**Your Decision**: [ ]

---

## 🟢 Brand & Content

### Q10: Logo & Brand Assets

**Question**: What logo/brand assets should be used in staging demo?

**Required Assets**:
- Company logo (SVG or PNG, square)
- Primary brand color (hex code)
- Typography (Google Font name)

**Current Implementation**: Material 3 defaults (blue/purple)

**Recommendation**: Provide brand kit or use defaults for staging

**Your Assets**: [ ]

---

### Q11: Error Microcopy

**Question**: Exact wording for key error messages?

**Key Errors**:

**Permission Denied**:
- Current: "Location permission needed to clock in."
- Alternative: "Enable location to verify you're at the job site."

**Outside Geofence**:
- Current: "You are 215m from the job site. Move closer to clock in."
- Alternative: "You're not close enough to the job. Please move within {distance}m."

**GPS Accuracy Low**:
- Current: "GPS signal weak. Move to open area and try again."
- Alternative: "Weak GPS signal. Step outside for better accuracy."

**No Assignment**:
- Current: "No assignments for today. Contact your manager."
- Alternative: "You're not assigned to any jobs today. Check with your manager."

**Recommendation**: Current wording is clear and actionable

**Your Preference**: [ ]

---

## Response Template

Please copy and paste this template with your answers:

```
OPEN QUESTIONS RESPONSES
Date: [DATE]
Respondent: [NAME/ROLE]

Q1 (Grace Radius): Option [ A / B / C ]
Notes:

Q2 (Breaks & Travel): Option [ A / B / C ]
Notes:

Q3 (Timesheet Export):
  - Rounding: [ 0.1h / 0.25h / exact ]
  - Overtime: [ Include / Exclude ]
  - Format: [ CSV / Excel / PDF / Multiple ]
Notes:

Q4 (Invoice Line Item): Option [ A / B / C ]
Notes:

Q5 (Location Retention): Option [ A / B / C ]
Notes:

Q6 (Min OS Support): Option [ A / B / C ]
Notes:

Q7 (Offline TTL): Option [ A / B / C ]
Notes:

Q8 (Alert Recipients): [EMAIL LIST]
Escalation: [POLICY]

Q9 (Support Playbook): Option [ A / B / C ]
Owner: [NAME/TEAM]

Q10 (Brand Assets):
  - Logo: [FILE PATH / URL]
  - Color: [HEX CODE]
  - Font: [FONT NAME]

Q11 (Error Microcopy): [ Current / Alternative / Custom ]
Custom wording:

ADDITIONAL NOTES:
```

---

## Next Steps

1. **Client reviews questions** (target: within 3 business days)
2. **Engineering implements decisions** (1-2 days)
3. **Update documentation** with finalized policies
4. **Staging demo** with client approval
5. **Production deployment** (canary rollout)

---

## Conservative Defaults

If no response received by [DATE], we will proceed with these defaults:

| Question | Default |
|----------|---------|
| Q1 | Option A (full accuracy buffer) |
| Q2 | Option A (no breaks in MVP) |
| Q3 | CSV, 0.1h rounding, no OT |
| Q4 | Option A (single line item) |
| Q5 | Option A (90 days then geohash) |
| Q6 | Option A (Android 8+, iOS 13+) |
| Q7 | Option B (7 day TTL) |
| Q8 | engineering@example.com |
| Q9 | Option A (eng creates) |
| Q10 | Material 3 defaults |
| Q11 | Current wording |

These defaults prioritize:
- Worker experience over strict enforcement
- Privacy (shorter retention)
- Simplicity (fewer features)
- Standard Material Design

**Defaults can be changed post-MVP** based on real-world usage.
