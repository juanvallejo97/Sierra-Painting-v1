# Deployment History

This directory contains deployment metadata records for audit and tracking purposes.

## Purpose

- Track canary deployments (10% traffic)
- Record promotions (50%, 100%)
- Log rollback events
- Maintain deployment timeline
- Support post-mortem analysis

## File Format

Each deployment/promotion/rollback creates a JSON file:

### Canary Deployment
```json
{
  "deploymentId": "canary-2024-01-15T10:30:00Z",
  "timestamp": "2024-01-15T10:30:00Z",
  "project": "sierra-painting-prod",
  "tag": "v1.2.0",
  "function": "all",
  "stage": "canary",
  "trafficPercentage": 10,
  "gitCommit": "abc123def456",
  "deployedBy": "engineer"
}
```

### Promotion
```json
{
  "promotionId": "promote-50-2024-01-15T16:00:00Z",
  "timestamp": "2024-01-15T16:00:00Z",
  "project": "sierra-painting-prod",
  "stage": "50",
  "function": "all",
  "gitCommit": "abc123def456",
  "promotedBy": "engineer"
}
```

### Rollback
```json
{
  "rollbackId": "rollback-2024-01-15T18:00:00Z",
  "timestamp": "2024-01-15T18:00:00Z",
  "project": "sierra-painting-prod",
  "method": "traffic",
  "function": "all",
  "version": null,
  "gitCommit": "abc123def456",
  "rolledBackBy": "engineer"
}
```

## Usage

These records are:
- Automatically created by deployment scripts
- Uploaded as CI/CD workflow artifacts
- Tracked in git for audit purposes
- Used for post-deployment analysis

## Querying

```bash
# List all deployments
ls -lt .deployment-history/

# View specific deployment
cat .deployment-history/canary-2024-01-15T10:30:00Z.json

# Find recent deployments
find .deployment-history/ -name "canary-*.json" -mtime -7

# Count deployments by type
ls .deployment-history/ | grep -c "canary-"
ls .deployment-history/ | grep -c "promote-"
ls .deployment-history/ | grep -c "rollback-"
```

## Retention

- Deployment records are kept indefinitely in git
- Workflow artifacts are retained for 90 days
- Consider archiving old records annually

## Related Documentation

- [CANARY_DEPLOYMENT.md](../docs/CANARY_DEPLOYMENT.md)
- [ANDROID_STAGED_ROLLOUT.md](../docs/ANDROID_STAGED_ROLLOUT.md)
- [rollout-rollback.md](../docs/rollout-rollback.md)
