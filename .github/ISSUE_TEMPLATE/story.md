---
name: User Story
about: Describe a user-facing feature or capability
title: '[STORY] '
labels: 'story'
assignees: ''
---

## User Story
As a **[role]**, I want **[capability]**, so that **[benefit]**.

## Acceptance Criteria (BDD)
<!-- Use Given-When-Then format -->

**Given** [precondition/context]  
**When** [action/trigger]  
**Then** [expected outcome]

- [ ] AC 1: [Specific, testable criteria]
- [ ] AC 2: [Specific, testable criteria]
- [ ] AC 3: [Specific, testable criteria]

## Data Contracts
<!-- Firestore collections, document schemas, function payloads -->

**Collections/Documents:**
- Collection: `[collectionName]`
  - Fields: `field1` (type), `field2` (type), ...
  - Indexes: [...if needed]

**Cloud Function Payloads:**
```typescript
// Input
{
  field1: string,
  field2: number,
}

// Output
{
  result: string,
}
```

## Security Rules Checklist
- [ ] Client cannot write protected fields (e.g., `invoice.paid`, `invoice.paidAt`)
- [ ] Role-based checks (admin/crew/user) enforced
- [ ] Organization scoping enforced (users can only access their org data)
- [ ] App Check enforced for callable functions (if applicable)

## Tests Required
- [ ] Unit tests for domain logic
- [ ] Widget tests for UI components
- [ ] Integration tests for user flows
- [ ] Rules tests (emulator) for security rules
- [ ] Function tests for Cloud Functions

## Telemetry & Analytics
<!-- Event names, screen tracking, performance traces -->

**Analytics Events:**
- Event: `[event_name]`
  - Parameters: `param1`, `param2`, ...

**Performance Traces:**
- Trace: `[trace_name]`
  - Start: [where]
  - End: [where]

**Crash Reporting:**
- Error scenarios to log: [...]

## UI/UX Notes
<!-- Accessibility, responsiveness, loading states, error states -->

- [ ] WCAG 2.2 AA compliance (48x48 touch targets, semantic labels)
- [ ] Loading state (skeleton/spinner)
- [ ] Error state (user-friendly message, retry button)
- [ ] Empty state (helpful guidance)
- [ ] Offline support (Pending Sync badge if writes)

## Definition of Ready (DoR)
- [ ] Acceptance criteria are clear and testable
- [ ] Data contracts are defined
- [ ] Security implications reviewed
- [ ] Dependencies identified

## Definition of Done (DoD)
- [ ] Code complete and reviewed
- [ ] Tests written and passing
- [ ] Security rules updated and tested
- [ ] Telemetry implemented
- [ ] Documentation updated
- [ ] Deployed to staging and validated
