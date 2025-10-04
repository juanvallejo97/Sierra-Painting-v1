# Migration Guides

This directory contains migration guides for breaking changes in dependency updates.

## Purpose

When updating dependencies that introduce breaking changes, create a migration guide here to:
- Document all breaking changes
- Provide step-by-step migration instructions
- Include code examples (before/after)
- Specify rollback procedures
- Track migration progress

## Naming Convention

Use the following format for migration guide filenames:

```
Migration-YYYY-MM-DD-brief-description.md
```

Examples:
- `Migration-2024-01-15-firebase-functions-v5.md`
- `Migration-2024-02-20-flutter-3-16-upgrade.md`
- `Migration-2024-03-10-riverpod-v3-migration.md`

## Migration Guide Template

When creating a new migration guide, use this template:

```markdown
# Migration: [Package Name] [Old Version] → [New Version]

**Date:** YYYY-MM-DD  
**Status:** [Planned / In Progress / Completed]  
**Owner:** [Developer Name]

## Summary

Brief description of what's being updated and why.

## Motivation

Why this update is necessary (security, features, EOL, etc.)

## Breaking Changes

List all breaking changes from the upstream changelog:
1. Breaking change 1
2. Breaking change 2
3. ...

## Impact Assessment

### Affected Areas
- List code areas affected
- Estimate effort required
- Identify risks

### Dependencies
- Other packages that need updating
- Potential conflicts

## Migration Steps

### 1. Preparation
- [ ] Back up current state
- [ ] Create feature branch
- [ ] Review upstream documentation
- [ ] Plan testing strategy

### 2. Code Changes

#### Before
\`\`\`dart
// Old code example
\`\`\`

#### After
\`\`\`dart
// New code example with explanation
\`\`\`

### 3. Testing
- [ ] Update unit tests
- [ ] Update integration tests
- [ ] Test in local environment
- [ ] Deploy to staging
- [ ] Smoke test critical paths

### 4. Deployment
- [ ] Deploy to staging
- [ ] Monitor for 48 hours
- [ ] Deploy to production
- [ ] Monitor for 7 days

## Rollback Plan

If issues occur:
1. Specific rollback steps
2. Commands to run
3. Expected recovery time

```bash
# Example rollback commands
git revert <commit-hash>
git push origin main
firebase deploy --only functions
```

## Verification

How to verify the migration was successful:
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] ...

## Known Issues

Document any known issues and workarounds.

## References

- Upstream changelog: [link]
- Related issues: [links]
- ADR (if applicable): [link]

## Timeline

| Date | Milestone | Status |
|------|-----------|--------|
| YYYY-MM-DD | Planning | Complete |
| YYYY-MM-DD | Development | In Progress |
| YYYY-MM-DD | Testing | Pending |
| YYYY-MM-DD | Staging | Pending |
| YYYY-MM-DD | Production | Pending |

## Notes

Any additional notes, lessons learned, or tips for future migrations.
```

## Current Migrations

No migration guides exist yet. This directory will be populated as breaking changes are encountered.

## Related Documentation

- [Update Standards](../.copilot/sierra_painting_update.yaml)
- [Update Execution Guide](../UPDATES_EXECUTION.md)
- [Update History](../UPDATES.md)
- [Deployment Guide](../DEPLOYMENT.md)
