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

**For Hosting:** use Firebase Hosting clone command to promote a previous version to live:

```bash
firebase hosting:clone --project $FIREBASE_PROJECT_ID --source "$FIREBASE_HOSTING_SITE:versions/<versionId>" --target "$FIREBASE_HOSTING_SITE:live"
```

You can find the version ID in Firebase Console → Hosting → Releases.

**For code:** revert the update PR commit (squash) and re-run workflows

## Troubleshooting

Check `update-reports` artifact for audits and outdated logs.
