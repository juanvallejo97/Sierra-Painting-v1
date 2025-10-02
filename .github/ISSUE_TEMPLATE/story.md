---
name: User Story
about: Feature request or user story for new functionality
title: "[STORY] "
labels: "story, needs-triage"
assignees: ""
---

## User Story
**As a** [role]  
**I want** [capability]  
**So that** [benefit/value]

## Acceptance Criteria (BDD)
<!-- Use Given-When-Then format; add multiple scenarios if needed -->

**Given** [precondition/context]  
**When** [action/trigger]  
**Then** [expected outcome]

- [ ] AC 1: [Specific, testable criteria]
- [ ] AC 2: [Specific, testable criteria]
- [ ] AC 3: [Specific, testable criteria]

## Epic
<!-- Link to related epic (e.g., Auth/RBAC, Time Clock, Invoicing/Payments, Lead/Schedule, Ops/Observability) -->
Epic: 

## Priority
- [ ] P0 — Critical (blocking production)
- [ ] P1 — High (important for MVP)
- [ ] P2 — Medium (nice to have)

## Sprint Target
- [ ] V1 (Weeks 1–4)
- [ ] V2 (Weeks 5–8)
- [ ] V3 (Weeks 9–12)
- [ ] V4 (Weeks 13–16)

## Data Contracts
<!-- Firestore collections, document schemas, function payloads -->

**Collections/Documents**
- Collection: `[collectionName]`
  - Fields: `field1` (type), `field2` (type), …
  - Indexes: `[index on fieldX, fieldY]` (if needed)

**Cloud Function Payloads**
```ts
// Input
{
  field1: string;
  field2: number;
}

// Output
{
  result: string;
}
