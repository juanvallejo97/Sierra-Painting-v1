# Canary Deployment Guide

## Overview

Canary deployments allow you to test changes with a small subset of users before rolling out to all users. This document describes the canary deployment process for Sierra Painting v1.

## What is a Canary Deployment?

A canary deployment is a release strategy where:
1. New version is deployed to a small percentage of traffic (e.g., 10%)
2. Metrics are monitored closely
3. If successful, traffic is gradually increased
4. If issues are detected, traffic is immediately rolled back

## When to Use Canary Deployments

- First time deploying a new feature
- Changes to critical user flows
- Database schema changes
- External API integration changes
- Performance optimizations
- Security updates

## Canary Deployment Process

### 1. Deploy Canary (10% traffic)

```bash
# Using the canary script
./scripts/deploy_canary.sh --project sierra-painting-prod --tag v1.2.0

# Or deploy specific function only
./scripts/deploy_canary.sh --project sierra-painting-prod --function clockIn
```

### 2. Monitor Metrics (30-60 minutes)

Monitor the following metrics in [Cloud Console](https://console.cloud.google.com):

**Required Checks:**
- Error rate < 1%
- P95 latency < 2s
- No critical errors in logs
- User-reported issues: 0

**Monitoring Links:**
- [Cloud Functions Metrics](https://console.cloud.google.com/functions)
- [Error Reporting](https://console.cloud.google.com/errors)
- [Cloud Logging](https://console.cloud.google.com/logs)
- [Crashlytics](https://console.firebase.google.com)

**What to Watch:**
```bash
# Check error rate
gcloud logging read "severity>=ERROR AND resource.type=cloud_function" --limit 50 --format json

# Check function invocations
gcloud functions describe FUNCTION_NAME --format="get(httpsTrigger.url)"
```

### 3. Promote or Rollback

#### Option A: Promote to 100% (Success)

```bash
# Promote canary to all traffic
./scripts/promote_canary.sh --project sierra-painting-prod

# This will:
# - Set canary to 100% traffic
# - Update production tag
# - Record deployment metadata
```

#### Option B: Rollback (Issues Detected)

```bash
# Immediately rollback to previous version
./scripts/rollback/rollback-functions.sh --project sierra-painting-prod

# This will:
# - Route all traffic to previous version
# - Keep canary for debugging
# - Create incident report
```

## Canary Checklist

### Pre-Deployment
- [ ] Code reviewed and approved
- [ ] All tests passing
- [ ] VERIFICATION_CHECKLIST.md completed
- [ ] Feature flags configured (if applicable)
- [ ] Rollback plan documented
- [ ] Team notified of canary deployment

### During Canary (first 30 minutes)
- [ ] Monitor error rate every 5 minutes
- [ ] Check Cloud Logging for errors
- [ ] Monitor P95 latency
- [ ] Watch for user reports
- [ ] Check function cold starts
- [ ] Verify critical user flows work

### Post-Promotion (if successful)
- [ ] Monitor for 2 hours
- [ ] Update deployment docs
- [ ] Notify team of success
- [ ] Archive canary version
- [ ] Update CHANGELOG

### Post-Rollback (if issues found)
- [ ] Document issues found
- [ ] Create incident report
- [ ] Create bug fixes
- [ ] Plan next deployment
- [ ] Notify stakeholders

## Automated Canary with GitHub Actions

The production workflow supports canary deployments through manual triggers:

```yaml
# In .github/workflows/production.yml
deploy_functions_production:
  environment:
    name: production
    # Manual approval required
```

### Manual Promotion Flow

1. **Tag Release**: `git tag v1.2.0 && git push origin v1.2.0`
2. **GitHub Actions**: Automatically builds and tests
3. **Manual Approval**: Approve deployment in GitHub UI
4. **Canary Deploy**: Deployed to 10% traffic automatically
5. **Monitor**: Watch metrics for 30-60 minutes
6. **Promote**: Run `./scripts/promote_canary.sh` to promote to 100%

## Traffic Splitting Configuration

For Cloud Functions (Gen 2), traffic splitting is managed via Cloud Run revisions:

```bash
# Set traffic split manually
gcloud run services update-traffic FUNCTION_NAME \
  --to-revisions=REVISION_NEW=10,REVISION_OLD=90 \
  --region=us-central1 \
  --project=sierra-painting-prod
```

## Monitoring During Canary

### Key Metrics Dashboard

Create a dashboard with:
- Error rate (target: < 1%)
- Latency P50, P95, P99 (target: < 2s)
- Invocation count
- Cold start duration (target: < 5s)
- Memory usage
- Execution time

### Alerting Rules

Set up alerts for:
- Error rate > 2% (critical)
- P95 latency > 3s (warning)
- Cold starts > 10s (warning)
- 5xx errors (critical)

## Rollback Criteria

Immediately rollback if:
- Error rate > 5%
- P95 latency > 5s
- Critical errors in logs
- Data corruption detected
- User-reported issues > 3
- Security vulnerability discovered

## Best Practices

1. **Small Changes**: Deploy small, incremental changes
2. **Feature Flags**: Use feature flags for easy rollback
3. **Monitoring**: Always monitor during canary period
4. **Communication**: Keep team informed
5. **Documentation**: Document any issues found
6. **Automation**: Automate rollback where possible
7. **Testing**: Test in staging first
8. **Gradual Rollout**: Use 10% → 25% → 50% → 100%

## Example Deployment Timeline

```
00:00 - Deploy canary (10% traffic)
00:05 - First metrics check
00:10 - Second metrics check
00:15 - Third metrics check
00:30 - Decision point: promote or rollback
00:35 - If promoting: 25% traffic
00:45 - 50% traffic
01:00 - 100% traffic (full promotion)
01:00 - 03:00 - Extended monitoring
```

## Troubleshooting

### Canary Shows Higher Error Rate

1. Check logs for specific errors
2. Compare with previous version metrics
3. Verify configuration differences
4. Check for resource constraints
5. Review recent code changes

### Cannot Promote Canary

1. Verify authentication
2. Check service exists
3. Verify revision names
4. Check IAM permissions
5. Review Cloud Run documentation

## Related Documentation

- [Rollback Procedures](docs/ui/ROLLBACK_PROCEDURES.md)
- [Production Deployment](docs/ops/CI_CD_IMPLEMENTATION.md)
- [Monitoring Guide](docs/MONITORING.md)
- [Deployment Checklist](VERIFICATION_CHECKLIST.md)

---

**Last Updated**: 2024  
**Maintained By**: DevOps Team
