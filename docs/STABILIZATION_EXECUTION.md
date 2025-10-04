# Stabilization Standards Execution Guide

This document explains how the standards defined in `.copilot/stabilize_sierra_painting.yaml` are executed and enforced in the Sierra Painting v1 project.

## Overview

The `stabilize_sierra_painting.yaml` configuration file defines comprehensive standards for:
- CI/CD workflow reliability and consistency
- Dependency management and version pinning
- Build reproducibility and caching
- Testing infrastructure stability
- Deployment safety and rollback procedures
- Monitoring, alerting, and SLO tracking
- Incident response and disaster recovery
- Quality gates for code, security, and performance

## Execution Mechanisms

### 1. Automated Validation

The stabilization standards are enforced through automated validation:

#### Stabilization Compliance Workflow
- **File:** `.github/workflows/stabilization.yml`
- **Triggers:** Pull requests, pushes to main, weekly schedule
- **Purpose:** Validates compliance with all stabilization standards

**What it checks:**
- ✓ Required CI/CD workflows exist
- ✓ GitHub Actions use pinned versions
- ✓ Dependency lock files are committed
- ✓ Critical packages are properly declared
- ✓ Caching strategies are implemented
- ✓ Test infrastructure is in place
- ✓ Deployment scripts exist and are executable
- ✓ Security and quality gates are configured

#### Running Locally

You can run the validation script locally:

```bash
./scripts/validate_stabilization.sh
```

This will check your local repository against all stabilization standards and provide a detailed compliance report.

### 2. CI/CD Workflows

The following workflows implement the stabilization requirements:

#### Core Workflows

| Workflow | File | Purpose |
|----------|------|---------|
| CI Pipeline | `.github/workflows/ci.yml` | Main CI pipeline with all checks |
| Code Quality | `.github/workflows/code_quality.yml` | Linting and formatting |
| Smoke Tests | `.github/workflows/smoke_tests.yml` | Fast health checks |
| Staging Deploy | `.github/workflows/staging.yml` | Auto-deploy to staging |
| Production Deploy | `.github/workflows/production.yml` | Manual production deploy |
| Security Scan | `.github/workflows/security.yml` | Security checks |
| Firestore Rules | `.github/workflows/firestore_rules.yml` | Rules validation |

#### Workflow Standards Enforced

All workflows follow these standards from the stabilization config:

**Action Version Pinning:**
- `actions/checkout@v4`
- `actions/cache@v4`
- `actions/upload-artifact@v4`
- `subosito/flutter-action@v2`
- `actions/setup-node@v4`
- `actions/setup-java@v4`

**Timeout Policies:**
- Code quality jobs: 10 minutes
- Test jobs: 15 minutes
- Smoke tests: 10 minutes
- Build jobs: 20 minutes
- Deployment jobs: 30 minutes

**Caching Strategy:**
- Flutter pub cache: `~/.pub-cache`
- Gradle cache: `~/.gradle/caches` and `~/.gradle/wrapper`
- NPM cache: `~/.npm`

### 3. Dependency Management

#### Dart/Flutter Dependencies

**Policy:** Pin exact versions for production dependencies in `pubspec.yaml`

**Critical packages tracked:**
- `firebase_core: 4.1.1`
- `firebase_auth: 6.1.0`
- `firebase_storage: 13.0.2`
- `cloud_firestore: 6.0.2`
- `cloud_functions: 6.0.2`
- `flutter_riverpod: 3.0.1`
- `go_router: 16.2.4`

**Lock file management:**
- `pubspec.lock` is committed to the repository
- Updates via `flutter pub upgrade` only
- All changes reviewed in PRs

#### Node.js Dependencies

**Policy:** Use `package-lock.json` for deterministic builds

**Runtime version:** `>=18 <21` (Node.js 18.x and 20.x)

**Commands:**
- Install: `npm ci --prefer-offline --no-audit`
- Update: Only during maintenance windows

**Security:**
- Run `npm audit` after every package-lock.json change
- Dependabot auto-merges security patches

### 4. Testing Infrastructure

All test categories are validated:

**Test Locations:**
- `test/` - Unit and widget tests
- `integration_test/` - End-to-end tests
- `firestore-tests/` - Security rules tests
- `functions/test/` - Cloud Functions tests

**Smoke Tests:**
- Location: `integration_test/app_boot_smoke_test.dart`
- Purpose: Fast health checks to block bad releases
- Runtime target: < 2 minutes
- Frequency: Every PR, before deployment

### 5. Deployment Scripts

The following deployment scripts implement rollback and canary deployment procedures:

#### Deployment Scripts

| Script | Purpose | Target Time |
|--------|---------|-------------|
| `scripts/deploy_canary.sh` | Deploy with 10% traffic | < 5 minutes |
| `scripts/promote_canary.sh` | Promote canary (50%, 100%) | < 5 minutes |
| `scripts/rollback.sh` | Instant rollback | < 60 seconds |

**Usage Examples:**

```bash
# Deploy canary (10% traffic)
./scripts/deploy_canary.sh --project sierra-painting-prod --tag v1.2.0

# Promote to 50%
./scripts/promote_canary.sh --project sierra-painting-prod --stage 50

# Rollback if issues detected
./scripts/rollback.sh --project sierra-painting-prod
```

### 6. Quality Gates

#### Pre-Merge Gates

All PRs must pass:
- ✓ All CI/CD checks (no manual bypass)
- ✓ Code review approval
- ✓ No high/critical security vulnerabilities
- ✓ Stabilization compliance check

#### Post-Merge Gates

After merging to main:
- ✓ Automatic deployment to staging
- ✓ Smoke tests in staging
- ✓ 15-minute error rate monitoring

#### Production Gates

Before production deployment:
- ✓ Staging validated
- ✓ Version tag created
- ✓ Manual approval required
- ✓ Smoke tests passed

### 7. Monitoring and Metrics

#### Success Metrics Tracked

**CI Reliability:**
- CI success rate target: ≥ 99%
- Average build time: < 8 minutes
- Cache hit rate: ≥ 85%

**Dependency Stability:**
- Resolution failures: 0
- Security vulnerabilities: 0 high/critical
- Version drift: < 5% monthly

**Deployment Safety:**
- Failed deployments: < 1%
- Rollback time: < 60 seconds
- Post-deployment error rate: < 0.5% increase

## Compliance Reporting

### Weekly Reports

The stabilization workflow runs weekly (Mondays at 9 AM UTC) and generates compliance reports:

1. **Automated validation** runs all checks
2. **Report uploaded** as workflow artifact (30-day retention)
3. **Summary generated** in workflow UI
4. **PR comments** on pull requests with compliance status

### Manual Validation

To check compliance at any time:

```bash
# Run full validation
./scripts/validate_stabilization.sh

# View specific sections
./scripts/validate_stabilization.sh | grep "CI/CD"
./scripts/validate_stabilization.sh | grep "Dependency"
```

## Continuous Improvement

### Metrics Review

**Frequency:** Weekly

**Tracked metrics:**
- CI/CD success rate
- Build time trends
- Deployment frequency
- MTTR (Mean Time To Recovery)
- Test coverage

### Retrospectives

**Post-incident:** Within 48 hours of incident resolution
**Monthly:** Review stability metrics and process improvements

## Configuration Updates

The stabilization configuration is a living document:

1. **Review frequency:** Quarterly or after major incidents
2. **Update approval:** Engineering lead required
3. **Change process:**
   - Update `.copilot/stabilize_sierra_painting.yaml`
   - Update validation script if needed
   - Document changes in this guide
   - Review and merge

## Troubleshooting

### Compliance Check Failures

If the stabilization check fails:

1. **Review the report:**
   ```bash
   ./scripts/validate_stabilization.sh
   ```

2. **Address failures:**
   - Missing workflows: Create or restore required workflow files
   - Version mismatches: Update action versions to pinned versions
   - Missing files: Add required configuration files

3. **Re-run validation:**
   ```bash
   ./scripts/validate_stabilization.sh
   ```

### Common Issues

**Issue:** Action version warnings
**Solution:** Update workflow files to use pinned versions from stabilization config

**Issue:** Missing lock files
**Solution:** Commit `pubspec.lock` and `package-lock.json` to repository

**Issue:** Test directory warnings
**Solution:** Ensure all test directories exist and contain tests

## References

- **Stabilization Config:** `.copilot/stabilize_sierra_painting.yaml`
- **Validation Script:** `scripts/validate_stabilization.sh`
- **Compliance Workflow:** `.github/workflows/stabilization.yml`
- **Governance Framework:** `.copilot/README.md`

## Support

For questions or issues:
1. Review the stabilization configuration
2. Check workflow logs and artifacts
3. Run local validation script
4. Consult with engineering team

---

**Last Updated:** 2024
**Version:** 1.0
**Owner:** Engineering Team
