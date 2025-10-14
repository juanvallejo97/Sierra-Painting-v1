# Operations Runbooks

## Overview

This directory contains domain-specific operational runbooks for Sierra Painting. Runbooks provide step-by-step procedures for common operational tasks, troubleshooting, and incident response.

## Planned Runbooks

### Payments Domain

- **Payment Processing Issues**: How to investigate and resolve payment failures
- **Stripe Integration**: Troubleshooting Stripe webhook and API issues
- **Manual Payment Handling**: Procedures for manual payment entry and reconciliation

### Scheduling Domain

- **Time Entry Issues**: Resolving clock-in/out problems
- **GPS Tracking**: Troubleshooting location tracking failures
- **Offline Sync**: Handling offline queue sync failures

### Invoice Domain

- **Invoice Generation**: Troubleshooting PDF generation issues
- **Invoice Status**: Resolving invoice status inconsistencies
- **Quote to Invoice**: Handling quote conversion issues

### General Operations

- **Function Deployment**: Safe deployment procedures
- **Rollback Procedures**: How to roll back problematic deployments
- **Firestore Maintenance**: Database cleanup and maintenance tasks
- **Performance Optimization**: Investigating and resolving performance issues

## Runbook Template

Each runbook should follow this structure:

```markdown
# Runbook: [Operation Name]

## Overview
Brief description of the issue or operation

## Symptoms
- Symptom 1
- Symptom 2
- Symptom 3

## Prerequisites
- Access level required
- Tools needed
- Knowledge required

## Investigation Steps
1. Step 1
2. Step 2
3. Step 3

## Resolution Steps
1. Step 1
2. Step 2
3. Step 3

## Prevention
How to prevent this issue in the future

## Related Links
- Link to relevant documentation
- Link to monitoring dashboards
- Link to related runbooks
```

## Contributing

To add a new runbook:

1. Create a new file: `[domain]-[operation].md`
2. Follow the template structure
3. Include real examples and commands
4. Test the procedures
5. Update this README with a link

## Emergency Contacts

For critical production issues:

- **On-call Engineer**: [Contact info]
- **Technical Lead**: [Contact info]
- **Product Owner**: [Contact info]

## See Also

- [Feature Flags Guide](../feature-flags.md) - Runtime configuration
- [Observability Guide](../observability.md) - Logging and tracing
