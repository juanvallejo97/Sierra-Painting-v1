# Updates Execution Guide

## Purpose

How to run, validate, rollback, and troubleshoot dependency and security updates.

## Local validation

```bash
./scripts/validate_updates.sh
```

## CI validation

Workflow: **Updates Governance** → jobs: validate-updates, dependency-audit, version-check

## Rollback

**For Hosting:** redeploy previous version via Firebase Console → Hosting → Releases

**For code:** revert the update PR commit (squash) and re-run workflows

## Troubleshooting

Check `update-reports` artifact for audits and outdated logs.
