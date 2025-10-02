# User Stories

## Overview
This directory contains user stories organized by Epic and Sprint. Each story follows a BDD (Behavior-Driven Development) format with clear acceptance criteria, data models, and implementation guidance.

## Epic Structure

### Epic A: Authentication & RBAC
Core security foundation - sign-in, roles, sessions, and App Check
- **Stories**: A1-A5
- **Priority**: P0 (blocking)
- **Sprint**: V1

### Epic B: Time Clock
Clock-in/out with offline support and GPS tracking
- **Stories**: B1-B7
- **Priority**: P0 (core feature)
- **Sprint**: V1-V3

### Epic C: Invoicing
Quotes, invoices, and payment processing
- **Stories**: C1-C6
- **Priority**: P0-P2
- **Sprint**: V2-V4

### Epic D: Lead Management & Scheduling
Lead capture and job scheduling
- **Stories**: D1-D5
- **Priority**: P0-P2
- **Sprint**: V3-V4

### Epic E: Operations & Observability
CI/CD, testing, telemetry, and monitoring
- **Stories**: E1-E5
- **Priority**: P0-P2
- **Sprint**: V1-V4

## Sprint Organization

```
docs/stories/
├── README.md                  # This file
├── epics/                     # Epic overview documents
│   ├── A-auth-rbac.md
│   ├── B-time-clock.md
│   ├── C-invoicing.md
│   ├── D-lead-schedule.md
│   └── E-ops-obs.md
├── v1/                        # Sprint 1 (MVP must-haves)
│   ├── SPRINT_PLAN.md
│   ├── A1-signin-out.md
│   ├── A2-admin-roles.md
│   ├── A5-app-check.md
│   ├── B1-clock-in.md
│   ├── B2-clock-out.md
│   ├── B3-jobs-today.md
│   ├── B4-location-permission.md
│   ├── E1-ci-cd.md
│   ├── E2-rules-tests.md
│   └── E3-telemetry-audit.md
├── v2/                        # Sprint 2 (invoicing)
│   ├── SPRINT_PLAN.md
│   ├── C1-create-quote.md
│   ├── C2-quote-to-invoice.md
│   ├── C3-mark-paid.md
│   ├── B5-auto-clockout.md
│   └── B7-my-timesheet.md
├── v3/                        # Sprint 3 (leads)
│   ├── SPRINT_PLAN.md
│   ├── D1-public-lead-form.md
│   ├── D2-review-lead.md
│   └── D3-schedule-lite.md
└── v4/                        # Sprint 4 (polish)
    ├── SPRINT_PLAN.md
    ├── C5-stripe-checkout.md
    ├── C6-refund-void.md
    ├── E4-kpi-tiles.md
    └── E5-cost-alerts.md
```

## Story Template

Each story follows this structure:

```markdown
# [ID]: [Title]

**Epic**: [A-E] | **Priority**: [P0-P2] | **Sprint**: [V1-V4] | **Est**: [S/M/L]

## User Story
As a [role], I WANT [action], SO THAT [benefit].

## Dependencies
- Story X: [why needed]
- Story Y: [why needed]

## Acceptance Criteria (BDD)
### Success Scenario
GIVEN [context]
WHEN [action]
THEN [expected outcome]

### Edge Cases
- Invalid input: [behavior]
- Offline: [behavior]
- Permissions denied: [behavior]

### Accessibility
- Requirement 1
- Requirement 2

### Performance
- Target: P95 < X seconds
- Metric: [what to measure]

## Data Models

### Zod Schema
```typescript
const Schema = z.object({...});
```

### Firestore Structure
```
collection/doc/structure
```

### Indexes Required
```
(field1 asc, field2 desc)
```

## Security

### Firestore Rules
```javascript
match /collection/{id} {
  allow read: if ...;
  allow write: if ...;
}
```

### Validation
- Client-side: Zod schema
- Server-side: Cloud Function validation

## API Contracts

### Cloud Function
```typescript
export const functionName = functions.https.onCall(async (data, context) => {
  // Implementation
});
```

## Telemetry

### Analytics Events
- `event_name`: When X happens
- `event_error`: When X fails

### Audit Log Entries
- Action: `ACTION_NAME`
- Entity: [what changed]
- Actor: [who did it]

## Testing Strategy

### Unit Tests
- Test 1: [what to verify]
- Test 2: [what to verify]

### Integration Tests
- Test 1: [end-to-end flow]
- Test 2: [error scenarios]

### E2E Tests
- User flow: [actual user journey]

## Definition of Ready (DoR)
- [ ] Dependencies completed
- [ ] Schemas defined
- [ ] Rules drafted
- [ ] UI mockups (if applicable)
- [ ] Performance targets agreed

## Definition of Done (DoD)
- [ ] Code implemented
- [ ] Tests pass (unit + integration)
- [ ] Rules deployed to staging
- [ ] Telemetry events wired
- [ ] Audit logging working
- [ ] Documentation updated
- [ ] Deployed to staging
- [ ] Demo'd with real user scenario
- [ ] Performance targets met

## Notes
[Implementation notes, gotchas, references]
```

## Workflow

### 1. Sprint Planning
1. Review backlog in priority order
2. Check dependencies
3. Verify DoR for each story
4. Assign stories to sprint
5. Create sprint plan with cut line

### 2. Development
1. Pick story from sprint backlog
2. Review acceptance criteria
3. Write tests first (TDD)
4. Implement minimal code
5. Add telemetry/audit
6. Update documentation

### 3. Review & Demo
1. Verify DoD checklist
2. Deploy to staging
3. Demo with actual user flow from story
4. Get feedback
5. Mark as Done

### 4. Sprint Retrospective
1. Review what went well
2. Identify blockers
3. Update estimates
4. Plan next sprint

## Conventions

### Story IDs
- Format: `[Epic][Number]` (e.g., A1, B2, C3)
- Epic letter matches feature area
- Numbers increase within epic

### Git Commits
```bash
feat(B1): implement offline clock-in queue
fix(C3): prevent duplicate mark-paid operations
docs(stories): add B7 timesheet story
test(A1): add sign-in integration tests
```

### Branch Names
```bash
feature/B1-clock-in-offline
fix/C3-mark-paid-idempotency
docs/B7-timesheet-story
```

### PR Descriptions
```markdown
## Story
Implements: docs/stories/v1/B1-clock-in.md

## Changes
- Added offline queue for clock-in
- Implemented idempotency with clientId
- Added GPS permission handling

## DoD Checklist
- [x] Code implemented
- [x] Tests pass
- [x] Rules deployed
- [x] Telemetry wired
- [x] Deployed to staging
```

## References
- [ADR-011: Story-Driven Development](../adrs/011-story-driven-development.md)
- [Behavior-Driven Development](https://en.wikipedia.org/wiki/Behavior-driven_development)
- Sierra Painting PRD (comprehensive requirements document)
