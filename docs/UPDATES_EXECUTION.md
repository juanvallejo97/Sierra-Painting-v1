# Update Standards Execution Guide

This document explains how the standards defined in `.copilot/sierra_painting_update.yaml` are executed and enforced in the Sierra Painting v1 project.

## Overview

The `sierra_painting_update.yaml` configuration file defines comprehensive standards for:
- Dependency update strategy and cadence
- Security vulnerability remediation
- Breaking change management
- Version compatibility testing
- Documentation of changes and migrations

## Execution Mechanisms

### 1. Automated Validation

The update standards are enforced through automated validation:

#### Update Compliance Workflow
- **File:** `.github/workflows/updates.yml`
- **Triggers:** Pull requests, pushes to main, workflow dispatch, weekly schedule
- **Purpose:** Validates compliance with all update management standards

**What it checks:**
- ✓ Lock files are committed (pubspec.lock, package-lock.json)
- ✓ No high/critical security vulnerabilities
- ✓ Version drift within acceptable range (< 5%)
- ✓ Critical packages meet minimum version requirements
- ✓ Changelog has been maintained
- ✓ Update documentation exists
- ✓ Automation tools are configured

#### Running Locally

You can run the validation script locally:

```bash
./scripts/validate_updates.sh
```

Or use the Makefile target:

```bash
make validate-updates
```

This will check your local repository against all update standards and provide a detailed compliance report.

### 2. Update Cadence

The configuration defines a structured update schedule:

#### Monthly Reviews (First Monday)
1. Run `flutter pub outdated` to identify available updates
2. Run `npm audit` in functions/ and webapp/
3. Review Dependabot alerts
4. Update patch versions (x.y.Z)
5. Update minor versions if no breaking changes (x.Y.z)

**Commands:**
```bash
# Check Flutter packages
flutter pub outdated

# Check Functions packages
cd functions && npm outdated

# Check for security issues
cd functions && npm audit
cd webapp && npm audit
```

#### Quarterly Reviews
1. Review gradle dependencies in android/
2. Evaluate major version updates
3. Update Flutter SDK if new stable version available
4. Review and clean up deprecated APIs

**Commands:**
```bash
# Check Flutter version
flutter --version
flutter upgrade --verify-only

# Check gradle versions in android/build.gradle
cat android/build.gradle | grep -E "gradle|kotlin|compileSdk|targetSdk"
```

#### Annual Reviews
1. Plan major version updates (X.y.z)
2. Architecture review for dependency strategy
3. Evaluate new alternatives to current dependencies

### 3. Security Vulnerability Response

#### Critical Vulnerabilities (< 24 hours)
1. Automated alert via Dependabot/GitHub Security
2. Assess impact and exploitability
3. Create emergency update branch
4. Apply patch and run smoke tests
5. Fast-track to production
6. Document in CHANGELOG

**Commands:**
```bash
# Create emergency fix branch
git checkout -b hotfix/critical-security-patch

# Apply fix (example: update vulnerable package)
cd functions
npm update vulnerable-package --save
npm audit

# Run tests
npm test

# Deploy
firebase deploy --only functions
```

#### High Vulnerabilities (< 7 days)
1. Review vulnerability details
2. Plan update in next sprint
3. Test thoroughly in staging
4. Deploy during maintenance window

#### Medium/Low Vulnerabilities (< 30 days)
1. Include in monthly update cycle
2. Batch with other updates
3. Standard deployment process

### 4. Breaking Change Management

When a dependency has breaking changes:

#### Detection
```bash
# Review changelogs
flutter pub outdated --mode=all
cd functions && npm outdated

# Check for BREAKING CHANGE markers in git history
git log --all --grep="BREAKING CHANGE" --oneline
```

#### Assessment
1. Identify affected code paths
2. Estimate refactoring effort
3. Evaluate benefits vs. cost
4. Consider alternatives

#### Migration Process
1. Create migration ADR (Architecture Decision Record)
2. Document breaking changes in `docs/migrations/`
3. Allocate dedicated sprint
4. Create feature branch
5. Update incrementally with tests
6. Deploy to staging for extended testing
7. Gradual rollout to production

**Example migration document structure:**
```markdown
# Migration-2024-12-15-firebase-functions-v5.md

## Summary
Upgrade from firebase-functions v4.x to v5.x

## Breaking Changes
- Node.js 18 required (was 16)
- onCall functions now use async/await
- Request context parameter changed

## Migration Steps
1. Update package.json: "firebase-functions": "^5.0.0"
2. Update Node.js version in package.json engines
3. Refactor onCall functions to use new API
4. Update tests

## Rollback Plan
Revert commit and redeploy previous version

## Testing
- All unit tests pass
- Integration tests with emulator
- Staging deployment verification
```

### 5. Testing Requirements

#### Pre-Update Checklist
- [ ] All existing tests pass
- [ ] No pending security vulnerabilities
- [ ] Staging environment healthy
- [ ] Rollback plan documented

#### Post-Update Testing
**Automated:**
```bash
# Run all tests
flutter test
cd functions && npm test
cd firestore-tests && npm test

# Run smoke tests
flutter test integration_test/app_boot_smoke_test.dart
```

**Manual Verification:**
1. Test authentication flows
2. Verify Stripe payment processing
3. Check Firebase Performance metrics
4. Review error rates in Cloud Logging
5. Validate on physical devices (iOS/Android)

#### Monitoring Period
- **Staging:** 48 hours minimum
- **Production:** 7 days enhanced monitoring

### 6. Rollback Procedures

If an update causes issues:

#### Immediate Rollback (Traffic Routing)
```bash
# Rollback Cloud Functions
./scripts/rollback.sh --project sierra-painting-prod

# Or manually
gcloud run services update-traffic FUNCTION_NAME \
  --to-revisions=PREVIOUS_REVISION=100 \
  --project sierra-painting-prod
```

#### Code Rollback
```bash
# Revert the update commit
git revert <commit-hash>
git push origin main

# Redeploy
firebase deploy --only functions
```

#### Dependency Rollback
```bash
# Restore previous versions
git checkout HEAD~1 -- pubspec.yaml pubspec.lock
flutter pub get

# Or for Node packages
git checkout HEAD~1 -- functions/package.json functions/package-lock.json
cd functions && npm ci
```

### 7. Documentation Requirements

#### Update Records
Maintain `docs/UPDATES.md` with:
- Date of update
- Packages updated (from → to versions)
- Reason for update (security, feature, bug fix)
- Breaking changes
- Link to migration guide (if applicable)

**Example entry:**
```markdown
## 2024-12-15: Security Updates

### Flutter Packages
- firebase_core: 2.20.0 → 2.24.0 (security patch)
- firebase_auth: 4.12.0 → 4.15.0 (security patch)

### Node Packages
- firebase-functions: 4.5.0 → 4.6.0 (bug fixes)

**Reason:** CVE-2024-XXXXX in firebase_auth
**Breaking Changes:** None
**Testing:** All tests pass, staging validated
**Deployed:** 2024-12-15 10:00 UTC
```

#### Migration Guides
For breaking changes, create migration guides in `docs/migrations/`:
- Format: `Migration-YYYY-MM-DD-description.md`
- Include before/after code examples
- List all breaking changes
- Provide rollback instructions

### 8. Compliance Checks

The validation script checks:

| Check | Severity | What it validates |
|-------|----------|-------------------|
| Lock files committed | CRITICAL | pubspec.lock, package-lock.json in git |
| No critical vulnerabilities | CRITICAL | npm audit and Dependabot clean |
| Version drift acceptable | HIGH | < 5% packages behind |
| Minimum versions met | HIGH | Core packages meet minimums |
| Changelog updated | MEDIUM | Updated in last 60 days |
| Update script exists | MEDIUM | validate_updates.sh is executable |

### 9. Tools and Automation

#### Dependabot Configuration
Create or update `.github/dependabot.yml`:
```yaml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/functions"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    
  - package-ecosystem: "npm"
    directory: "/webapp"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    
  - package-ecosystem: "pub"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
```

#### GitHub Actions Workflow
The `.github/workflows/updates.yml` workflow runs automatically:
- On pull requests
- On pushes to main
- Weekly on Mondays at 10 AM UTC
- On manual trigger

**To trigger manually:**
1. Go to Actions tab in GitHub
2. Select "Update Standards Compliance Check"
3. Click "Run workflow"

### 10. Best Practices

#### DO ✅
- Update dependencies regularly (monthly)
- Test thoroughly in staging
- Document all updates in CHANGELOG
- Monitor closely after updates
- Keep lock files committed
- Use exact versions for production dependencies
- Respond quickly to security vulnerabilities

#### DON'T ❌
- Update all dependencies at once
- Skip testing after updates
- Use `npm update` (causes version drift)
- Ignore security advisories
- Deploy updates on Fridays
- Update without reading changelogs
- Mix feature work with dependency updates

## Troubleshooting

### Issue: "Lock file conflicts"
**Solution:**
```bash
# Regenerate lock files
flutter pub get
cd functions && npm ci
git add pubspec.lock functions/package-lock.json
git commit -m "Update lock files"
```

### Issue: "Dependency conflict after update"
**Solution:**
```bash
# Check dependency tree
flutter pub deps
cd functions && npm ls

# Use overrides if needed
# In pubspec.yaml:
dependency_overrides:
  package_name: ^x.y.z
```

### Issue: "Tests fail after update"
**Solution:**
1. Identify which update caused the failure
2. Review changelog for that package
3. Update test code to match new API
4. If unfixable, rollback that specific package
5. Document compatibility issue

### Issue: "Version drift warnings"
**Solution:**
```bash
# Review outdated packages
flutter pub outdated
cd functions && npm outdated

# Plan update sprint
# Prioritize: security > stability > features
# Update in batches, test between updates
```

## Related Documentation

- `.copilot/sierra_painting_update.yaml` - Complete update standards
- `docs/DEPLOYMENT.md` - Deployment procedures
- `.copilot/stabilize_sierra_painting.yaml` - Stability standards
- `CHANGELOG.md` - Update history
- `docs/migrations/` - Migration guides directory

## Support

For questions or issues:
1. Check this documentation
2. Review the standards file: `.copilot/sierra_painting_update.yaml`
3. Run validation script: `make validate-updates`
4. Contact engineering team via Slack #engineering
