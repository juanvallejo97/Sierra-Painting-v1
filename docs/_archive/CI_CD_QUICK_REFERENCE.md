# CI/CD Quick Reference Guide

## Overview

This guide provides quick references for common CI/CD tasks and workflows in the Sierra Painting v1 project.

## Workflows Overview

| Workflow | Trigger | Purpose | Duration |
|----------|---------|---------|----------|
| `ci.yml` | PR, Push to main | Full CI pipeline (Flutter, Functions, Rules, Build) | ~8-10 min |
| `staging.yml` | Push to main | Auto-deploy to staging | ~12-15 min |
| `production.yml` | Version tag (v*) | Deploy to production | ~15-20 min |
| `nightly.yml` | Daily at 2 AM UTC | Maintenance checks | ~10-15 min |
| `code_quality.yml` | PR, Push | Code quality checks | ~3-5 min |
| `firestore_rules.yml` | PR, Push | Rules validation | ~2-3 min |
| `smoke_tests.yml` | PR, Push | Smoke tests | ~3-5 min |

## Common Tasks

### Running CI Checks Locally

```bash
# Run all quality checks
make analyze

# Run tests with coverage
make test

# Run Firestore rules tests
make rules-test

# Run Functions tests
make functions-test

# Check web bundle size
make build-web-budget

# Generate size report
make size-report

# Audit dependencies
make audit

# Format code
make format
```

### Triggering Workflows

**Automatic Triggers:**
```bash
# Trigger CI pipeline
git push origin feature-branch

# Trigger staging deployment
git push origin main

# Trigger production deployment
git tag v1.2.0
git push origin v1.2.0
```

**Manual Triggers:**
- Go to Actions tab in GitHub
- Select workflow (e.g., "Nightly Maintenance")
- Click "Run workflow"

### Checking Workflow Status

**GitHub UI:**
1. Go to repository on GitHub
2. Click "Actions" tab
3. View running/completed workflows

**GitHub CLI:**
```bash
# List recent workflow runs
gh run list

# View specific run
gh run view RUN_ID

# Watch run in real-time
gh run watch
```

## CI Pipeline Jobs

### 1. Analyze
- **Purpose**: Static code analysis
- **Targets**: Flutter, Functions, WebApp
- **Duration**: ~2-3 min
- **Caching**: Flutter pub, Node modules

### 2. Test
- **Purpose**: Unit and integration tests
- **Targets**: Flutter, Functions
- **Duration**: ~3-5 min
- **Artifacts**: Coverage reports

### 3. Rules Test
- **Purpose**: Firestore security rules validation
- **Duration**: ~2-3 min
- **Emulators**: Firestore

### 4. Functions Test
- **Purpose**: Cloud Functions integration tests
- **Duration**: ~3-5 min
- **Emulators**: Auth, Firestore, Functions, Storage

### 5. Build
- **Purpose**: Build all platform targets
- **Targets**: Android, iOS (lint only), Web
- **Duration**: ~5-7 min (parallel)
- **Artifacts**: APK, Web bundle

### 6. Web Budget
- **Purpose**: Validate web bundle size
- **Budget**: 10 MB
- **Duration**: ~1 min

### 7. Size Report
- **Purpose**: Track size changes
- **When**: PRs only
- **Artifacts**: Size comparison report

## Caching

### What's Cached

| Cache Type | Key | Size | TTL |
|------------|-----|------|-----|
| Flutter pub | `pub-$OS-$pubspec.lock` | ~200MB | 7 days |
| Gradle | `gradle-$OS-$gradle-files` | ~500MB | 7 days |
| Node modules | `npm-$package-lock` | ~300MB | 7 days |

### Cache Management

**Clear cache:**
- Delete cache from GitHub Actions UI
- Or change cache key in workflow

**Verify cache hits:**
- Check workflow logs for "Cache restored" messages

## Artifacts

### Generated Artifacts

| Artifact | Workflow | Retention | Size |
|----------|----------|-----------|------|
| `coverage-flutter` | CI | 14 days | ~5MB |
| `build-android` | CI | 14 days | ~30MB |
| `build-web` | CI | 14 days | ~10MB |
| `size-report` | CI (PRs) | 14 days | ~1KB |
| `failure-triage-*` | CI (failures) | 14 days | ~5MB |
| `smoke-results-*` | Staging/Prod | 14 days | ~1KB |
| `release-builds-*` | Production | 90 days | ~50MB |
| `audit-*` | Nightly | 14 days | ~100KB |

### Downloading Artifacts

**GitHub UI:**
1. Go to workflow run
2. Scroll to "Artifacts" section
3. Click artifact to download

**GitHub CLI:**
```bash
# List artifacts
gh run view RUN_ID --log

# Download artifact
gh run download RUN_ID -n artifact-name
```

## Failure Diagnostics

### When Jobs Fail

1. **Check Logs**: Click on failed job to view logs
2. **Download Artifacts**: Download failure-triage artifact
3. **Review Diagnostics**: See `failure-triage-*/README.md`

### Failure Triage Contents

- System information
- Flutter/Node versions
- Build logs
- Test results
- Coverage data
- Size comparisons

### Common Failures

| Error | Cause | Solution |
|-------|-------|----------|
| "APK size exceeds budget" | Bundle too large | Review dependencies |
| "Tests failed" | Test failures | Check test-results.xml |
| "Cache miss" | Cache expired | Normal, will rebuild |
| "Emulator timeout" | Resource constraints | Retry workflow |

## Branch Protection

### Required Status Checks

Before merging to `main`:
- ✅ Analyze Code (flutter)
- ✅ Analyze Code (functions)
- ✅ Analyze Code (webapp)
- ✅ Run Tests (flutter)
- ✅ Run Tests (functions)
- ✅ Firestore Rules Tests
- ✅ Functions Integration Tests
- ✅ Build Apps (android)
- ✅ Build Apps (web)
- ✅ Web Bundle Size Budget

### Merge Strategies

✅ **Allowed:**
- Squash and merge (recommended)
- Rebase and merge

❌ **Not Allowed:**
- Merge commits

## Deployment

### Staging Deployment

**Trigger:**
```bash
git push origin main
```

**Process:**
1. All CI checks pass
2. Auto-deploy to staging
3. Smoke tests run
4. Monitoring links provided

**Duration:** ~12-15 minutes

### Production Deployment

**Trigger:**
```bash
git tag v1.2.0
git push origin v1.2.0
```

**Process:**
1. All CI checks pass
2. Builds created (APK, AAB)
3. Manual approval required
4. Deploy to production
5. GitHub release created
6. SBOM included

**Duration:** ~15-20 minutes (+ approval time)

### Canary Deployment

**Manual Process:**
```bash
# Deploy canary (10% traffic)
./scripts/deploy_canary.sh --project sierra-painting-prod --tag v1.2.0

# Monitor for 30-60 minutes
# Check metrics, logs, errors

# Promote to 100% if successful
./scripts/promote_canary.sh --project sierra-painting-prod

# Or rollback if issues
./scripts/rollback/rollback-functions.sh --project sierra-painting-prod
```

See [Canary Deployment Guide](ops/CANARY_DEPLOYMENT.md) for details.

## Nightly Jobs

### What Runs Nightly

1. **Documentation Link Check**
   - Validates all markdown links
   - Reports broken links

2. **Dependency Audit**
   - npm audit for all projects
   - Security vulnerability scanning

3. **Flutter Package Audit**
   - Check for outdated packages
   - Report available updates

4. **License Check**
   - Verify license compliance
   - Generate license reports

### Viewing Nightly Results

1. Go to Actions tab
2. Filter by "Nightly Maintenance"
3. View latest run
4. Download audit artifacts

## Best Practices

### Before Committing

```bash
# Format code
make format

# Run local checks
make analyze
make test
```

### Creating PRs

1. Ensure branch is up to date with main
2. Run local tests
3. Push changes
4. Create PR with descriptive title
5. Wait for CI to pass
6. Address any failures
7. Request review

### Debugging CI Failures

1. **Check logs** in GitHub Actions UI
2. **Download failure-triage** artifact
3. **Run locally** using Makefile targets
4. **Ask for help** with full error details

### Monitoring Deployments

**After Staging:**
- Check Firebase Console
- Review Cloud Logs
- Test critical flows
- Monitor for 15 minutes

**After Production:**
- Monitor for 2 hours
- Check error rates
- Review crashlytics
- Test in production app

## Monitoring Links

### Staging
- [Firebase Console](https://console.firebase.google.com/project/sierra-painting-staging)
- [Cloud Logs](https://console.cloud.google.com/logs/query?project=sierra-painting-staging)

### Production
- [Firebase Console](https://console.firebase.google.com/project/sierra-painting-prod)
- [Cloud Logs](https://console.cloud.google.com/logs/query?project=sierra-painting-prod)
- [Crashlytics](https://console.firebase.google.com/project/sierra-painting-prod/crashlytics)

## Troubleshooting

### Workflow Not Triggering

**Check:**
- Branch name matches trigger pattern
- File paths match path filters
- Workflow file syntax is valid

### Cache Not Working

**Possible causes:**
- Cache key changed (e.g., lock file updated)
- Cache expired (7 day TTL)
- First run (no cache yet)

**Solution:**
- Normal behavior, will rebuild and cache

### Job Timeout

**Default timeouts:**
- Most jobs: 60 minutes
- Smoke tests: 10 minutes

**Solution:**
- Check for infinite loops
- Review resource usage
- Retry if transient

### Artifact Upload Failed

**Possible causes:**
- File doesn't exist
- Path is incorrect
- File too large (>2GB limit)

**Solution:**
- Check file path
- Verify file generated
- Split large artifacts

## Getting Help

### Resources

- [CI/CD Implementation](ops/CI_CD_IMPLEMENTATION.md)
- [CI/CD Enhancements](CI_CD_ENHANCEMENTS.md)
- [Branch Protection](BRANCH_PROTECTION.md)
- [Testing Guide](Testing.md)

### Support

1. Check documentation
2. Review workflow logs
3. Download failure diagnostics
4. Ask team for help
5. Create GitHub issue

---

**Last Updated**: 2024
**Maintained By**: DevOps Team
