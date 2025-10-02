# Architecture Decision Records (ADRs)

## Overview
This directory contains Architecture Decision Records (ADRs) documenting key architectural decisions made during the development of Sierra Painting.

## Format
We follow the format popularized by Michael Nygard:
- **Title**: Short descriptive title
- **Status**: Proposed | Accepted | Deprecated | Superseded
- **Context**: The issue we're seeing that motivates the decision
- **Decision**: The change we're proposing and/or doing
- **Consequences**: What becomes easier or harder as a result

## Index

### Infrastructure & Operations
- [ADR-001: Firebase as Backend Platform](./001-firebase-backend.md)
- [ADR-002: Deny-by-Default Security Model](./002-deny-by-default-security.md)
- [ADR-003: Offline-First Architecture](./003-offline-first.md)
- [ADR-004: App Check for API Protection](./004-app-check.md)

### Data & Storage
- [ADR-005: Firestore Data Model](./005-firestore-data-model.md)
- [ADR-006: Idempotency Strategy](./006-idempotency-strategy.md)
- [ADR-007: Audit Logging Approach](./007-audit-logging.md)

### Application Architecture
- [ADR-008: Feature-Based Code Organization](./008-feature-based-organization.md)
- [ADR-009: Zod for Runtime Validation](./009-zod-validation.md)
- [ADR-010: Role-Based Access Control](./010-rbac.md)

### Developer Experience
- [ADR-011: Story-Driven Development](./011-story-driven-development.md)
- [ADR-012: Sprint-Based Feature Flags](./012-sprint-based-flags.md)
- [ADR-013: Telemetry and Observability](./013-telemetry-observability.md)

## Creating a New ADR
```bash
# Copy the template
cp docs/adrs/000-template.md docs/adrs/XXX-your-title.md

# Fill in the sections
# Submit as part of your PR
```
