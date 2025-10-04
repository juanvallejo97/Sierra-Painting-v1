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
- [ADR-0001: Tech Stack](./0001-tech-stack.md)
- [ADR-0002: Offline-First Architecture](./0002-offline-first-architecture.md)

### Data & Storage
- [ADR-006: Idempotency Strategy](./006-idempotency-strategy.md)

### Application Architecture
- [ADR-0003: Manual Payments Primary](./0003-manual-payments-primary.md)
- [ADR-0004: Riverpod State Management](./0004-riverpod-state-management.md)
- [ADR-0005: GoRouter Navigation](./0005-gorouter-navigation.md)

### Developer Experience
- [ADR-011: Story-Driven Development](./011-story-driven-development.md)
- [ADR-012: Sprint-Based Feature Flags](./012-sprint-based-flags.md)

## Creating a New ADR
```bash
# Copy the template
cp docs/adrs/000-template.md docs/adrs/XXX-your-title.md

# Fill in the sections
# Submit as part of your PR
```
