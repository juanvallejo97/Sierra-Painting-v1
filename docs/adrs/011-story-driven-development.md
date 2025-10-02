# ADR-011: Story-Driven Development

## Status
Accepted

## Date
2024-01-15

## Context
Traditional feature-based development often loses sight of user value and acceptance criteria. We need a methodology that:
- Keeps user stories as first-class citizens
- Makes acceptance criteria testable and traceable
- Enables iterative delivery with clear DoR/DoD (Definition of Ready/Done)
- Supports sprint-based planning and prioritization
- Integrates well with Firebase and Flutter ecosystem

The PRD provides detailed user stories with BDD-style acceptance criteria (Given/When/Then), Zod schemas, Firestore rules, telemetry events, and DoR/DoD checklists. We need a structure that makes these actionable.

## Decision
We adopt **Story-Driven Development** with the following structure:

### 1. Story Documentation Structure
```
docs/stories/
├── README.md                    # Index and workflow guide
├── epics/
│   ├── A-auth-rbac.md          # Epic A: Authentication & RBAC
│   ├── B-time-clock.md         # Epic B: Time Clock
│   ├── C-invoicing.md          # Epic C: Invoicing
│   ├── D-lead-schedule.md      # Epic D: Lead/Schedule
│   └── E-ops-obs.md            # Epic E: Operations/Observability
└── v1/                         # Sprint V1 stories
    ├── A1-signin-out.md        # Individual story details
    ├── A2-admin-roles.md
    ├── B1-clock-in.md
    └── ...
```

### 2. Story Template Format
Each story file includes:
- **User Story**: As a [role], I want [action], so that [benefit]
- **Priority**: P0 (must-have) through P2 (nice-to-have)
- **Sprint**: V1, V2, V3, or V4
- **Dependencies**: Other stories that must be completed first
- **Acceptance Criteria**: BDD-style (Given/When/Then)
- **Data Models**: Zod schemas and TypeScript types
- **Firestore Rules**: Security rules snippets
- **API Contracts**: Function signatures and validation
- **Telemetry**: Analytics events and audit log entries
- **Testing Strategy**: Unit, integration, and E2E tests
- **DoR Checklist**: Definition of Ready
- **DoD Checklist**: Definition of Done

### 3. Implementation Workflow
```
1. Pick story from backlog (e.g., B1-clock-in.md)
2. Review DoR checklist (dependencies, schemas defined, rules drafted)
3. Implement with TDD approach:
   - Write tests based on acceptance criteria
   - Implement minimal code to pass tests
   - Add telemetry and audit logging
4. Verify DoD checklist (tests pass, docs updated, deployed to staging)
5. Demo with actual user scenarios from the story
6. Move to Done
```

### 4. Traceability
- Git commits reference story IDs: `feat(B1): implement offline clock-in queue`
- PR descriptions link to story: `Implements: docs/stories/v1/B1-clock-in.md`
- Tests include story ID in descriptions: `describe('B1: Clock-in', ...)`
- Telemetry events use story conventions: `clock_in_offline` (from B1)

### 5. Sprint Planning
- Each sprint folder (v1/, v2/, etc.) contains only that sprint's stories
- SPRINT_PLAN.md in each folder lists priorities and cut lines
- Feature flags enable progressive rollout: `feature_b1_clock_in_enabled`

## Consequences

### Positive
- **User-Centric**: Every feature tied to clear user value
- **Testable**: Acceptance criteria translate directly to tests
- **Traceable**: Story IDs in commits, tests, telemetry
- **Onboarding**: New developers can read stories to understand features
- **Planning**: Clear priorities and dependencies for sprint planning
- **Quality**: DoD ensures consistent quality bar
- **Incremental**: Features can be built and tested independently

### Negative
- **Overhead**: More documentation to maintain
- **Discipline Required**: Team must consistently reference stories
- **Initial Setup**: Takes time to create story files
- **Risk of Staleness**: Stories must be updated if requirements change

## Alternatives Considered

### Traditional Issue Tracking (GitHub Issues)
- **Why Not**: Issues often lack sufficient detail, don't co-locate with code, hard to version control
- **Tradeoff**: GitHub Issues good for bugs/tasks but not comprehensive user stories

### JIRA/Linear
- **Why Not**: External tool, not version-controlled with code, context switching
- **Tradeoff**: Better for larger orgs but overkill for MVP stage

### Plain Markdown in /docs
- **Why Not**: Lacks structure, hard to navigate, no clear workflow
- **Tradeoff**: We are using Markdown but with strict structure

### Code Comments Only
- **Why Not**: No high-level view, scattered across codebase, hard to review before implementation
- **Tradeoff**: Comments still valuable for implementation notes

## References
- [Behavior-Driven Development (BDD)](https://en.wikipedia.org/wiki/Behavior-driven_development)
- [User Story Mapping](https://www.jpattonassociates.com/user-story-mapping/)
- [Definition of Done](https://www.scrum.org/resources/definition-of-done)
- Sierra Painting PRD (problem statement document)
