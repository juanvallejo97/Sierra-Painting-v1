# Scripts Directory

This directory contains helper scripts for CI/CD, testing, and deployment operations.

## Directory Structure

```
scripts/
├── ci/                          # CI/CD helper scripts
│   ├── firebase-login.sh        # Validate Firebase authentication
│   └── failure-triage.sh        # Collect diagnostics on CI failures
├── smoke/                       # Smoke testing scripts
│   └── run.sh                   # Emulator smoke test suite
├── remote-config/               # Remote Config management
│   └── manage-flags.sh          # Feature flag management
├── rollback/                    # Rollback procedures
│   └── rollback-functions.sh    # Function rollback helper
├── deploy/                      # Deployment scripts
│   ├── deploy.sh                # Main deployment script
│   ├── pre-deploy-checks.sh    # Pre-deployment validation
│   └── verify.sh                # Post-deployment verification
├── setup_env.sh                 # Environment setup and dependency verification
├── configure_env.sh             # Configure .env file from template
├── verify_config.sh             # Verify environment configuration
├── quality.sh                   # Code quality checks
├── generate-docs.sh             # Generate API documentation
├── deploy_canary.sh             # Deploy with canary strategy
├── promote_canary.sh            # Promote canary to production
└── build-and-deploy.sh          # Legacy web app build script
```

## Scripts Overview

### Environment Setup Scripts

#### `setup_env.sh`

**Purpose:** Verify and install required dependencies for the Sierra Painting project

**Usage:**
```bash
# Full setup
./scripts/setup_env.sh

# Skip specific checks
./scripts/setup_env.sh --skip-flutter
./scripts/setup_env.sh --skip-firebase
./scripts/setup_env.sh --skip-node
```

**What it does:**
1. Verifies Flutter SDK (>=3.10.0)
2. Verifies Node.js (>=18.x)
3. Verifies/installs Firebase CLI (>=12.0.0)
4. Installs FlutterFire CLI
5. Installs Flutter dependencies
6. Installs Cloud Functions dependencies

**When to use:**
- Initial project setup for new developers
- After cloning the repository
- When setting up a new development machine

---

#### `configure_env.sh`

**Purpose:** Configure .env file from .env.example template

**Usage:**
```bash
# Interactive mode (recommended for first-time setup)
./scripts/configure_env.sh --interactive

# Non-interactive with arguments
./scripts/configure_env.sh --env development
./scripts/configure_env.sh --env staging --project-id sierra-painting-staging
./scripts/configure_env.sh --env production --project-id sierra-painting-prod --force
```

**Options:**
- `--env <environment>` - Target environment: development, staging, production
- `--project-id <id>` - Firebase project ID
- `--interactive` - Prompts for configuration values
- `--force` - Overwrite existing .env file without confirmation

**When to use:**
- After running setup_env.sh
- When switching between environments
- When setting up a new Firebase project

---

#### `verify_config.sh`

**Purpose:** Verify that environment and Firebase configuration is correct

**Usage:**
```bash
# Standard verification
./scripts/verify_config.sh

# Verbose output
./scripts/verify_config.sh --verbose

# Skip specific checks
./scripts/verify_config.sh --skip-firebase
./scripts/verify_config.sh --skip-flutter
```

**Verifies:**
1. .env file exists with required variables
2. Flutter configuration and dependencies
3. Firebase CLI and project configuration
4. Firebase options file (lib/firebase_options.dart)
5. Cloud Functions dependencies
6. Firestore and Storage rules

**Exit codes:**
- 0: All checks passed or warnings only
- 1: One or more errors found

**When to use:**
- After running configure_env.sh
- Before deploying
- In CI/CD pipelines
- When troubleshooting configuration issues

---

### Code Quality Scripts

#### `quality.sh`

**Purpose:** Run comprehensive code quality checks including formatting, linting, and analysis

**Usage:**
```bash
# Run all quality checks
./scripts/quality.sh

# Apply auto-fixes before checking
./scripts/quality.sh --fix

# Run with fatal-infos (fail on info-level issues)
./scripts/quality.sh --fatal-infos
```

**Checks performed:**
1. Dart auto-fixes (optional, with `--fix`)
2. Dart format verification
3. Dart analysis with strict linting rules

**When to use:**
- Before committing code
- During CI/CD workflows
- Before creating pull requests

---

#### `ci/failure-triage.sh`

**Purpose:** Collect comprehensive diagnostic information when CI jobs fail

**Usage:**
```bash
# Collect failure diagnostics in default location
./scripts/ci/failure-triage.sh

# Collect diagnostics in custom location
./scripts/ci/failure-triage.sh build/my-diagnostics
```

**Collected Information:**
- System and environment details
- Flutter/Dart versions and doctor output
- Node.js and npm versions
- Build logs
- Test results
- Code coverage data
- APK/web bundle sizes
- Size diffs vs previous builds

**When to use:**
- Automatically in CI on job failure
- Manually when debugging local issues
- Before reporting CI/CD issues

**Artifacts Generated:**
- `system-info.txt` - System configuration
- `flutter-doctor.txt` - Flutter environment
- `*.log` - Build and test logs
- `size-diff.txt` - Bundle size changes
- `README.md` - Summary report

---
- Regular code health audits

---

#### `generate-docs.sh`

**Purpose:** Generate API documentation using dart doc

**Usage:**
```bash
./scripts/generate-docs.sh
```

**Output:** Documentation is generated in `docs/api/`

**When to use:**
- After adding new public APIs
- Before releases
- To update project documentation

---

### CI/CD Scripts

#### `ci/firebase-login.sh`

**Purpose:** Validates Firebase authentication and project access before deployment

**Usage:**
```bash
./scripts/ci/firebase-login.sh
```

**When to use:**
- Automatically called during CI/CD workflows
- Manual validation before deployments
- Troubleshooting authentication issues

**Checks:**
- Firebase CLI installation
- firebase.json and .firebaserc presence
- Functions directory and build status
- Project configuration

---

### Smoke Testing Scripts

#### `smoke/run.sh`

**Purpose:** Runs smoke tests against Firebase emulators

**Usage:**
```bash
# Start emulators first
firebase emulators:start &

# Run smoke tests
./scripts/smoke/run.sh
```

**Current Status:** Placeholder implementation

**TODO:** Implement actual tests for:
- Auth (user creation, sign-in, token refresh)
- Clock In/Out (GPS tracking, activity logs)
- Estimates (creation, line items, PDF generation)
- Invoices (conversion, payment tracking, audit logs)
- Offline Sync (queue management, sync processing)
- Security Rules (RBAC, org isolation)
- Cloud Functions (function calls, response times)

**When to use:**
- Automatically runs in CI/CD staging workflow
- Manual testing before major deployments
- Local development validation

---

### Remote Config Management

#### `remote-config/manage-flags.sh`

**Purpose:** Manage Firebase Remote Config feature flags

**Usage:**
```bash
# List all flags
./scripts/remote-config/manage-flags.sh list

# Get specific flag value
./scripts/remote-config/manage-flags.sh get feature_b1_clock_in_enabled

# Enable a feature
./scripts/remote-config/manage-flags.sh enable feature_b1_clock_in_enabled --project production

# Disable a feature (emergency rollback)
./scripts/remote-config/manage-flags.sh disable feature_b1_clock_in_enabled --project production

# Export config (backup)
./scripts/remote-config/manage-flags.sh export --project production

# Import config (restore)
./scripts/remote-config/manage-flags.sh import config.json --project staging
```

**When to use:**
- Emergency feature flag rollback
- Progressive feature rollout
- A/B testing configuration
- Backup before major changes

**Note:** Some operations are placeholders and require manual Firebase Console steps.

---

### Rollback Scripts

#### `rollback/rollback-functions.sh`

**Purpose:** Emergency rollback helper for Cloud Functions

**Usage:**
```bash
# List function versions
./scripts/rollback/rollback-functions.sh --list --project sierra-painting-prod

# Rollback all functions (dry run)
./scripts/rollback/rollback-functions.sh --project sierra-painting-prod --dry-run

# Rollback specific function
./scripts/rollback/rollback-functions.sh --function clockIn --project sierra-painting-prod

# Full rollback (with confirmation)
./scripts/rollback/rollback-functions.sh --project sierra-painting-prod
```

**When to use:**
- High error rates after deployment
- Critical bugs in production
- Security issues detected
- Need to revert to previous version

**Important:** 
- Requires git tag/commit identification
- Manual deployment step required
- Always test in staging first

---

### Canary Deployment Scripts

#### `deploy_canary.sh`

**Purpose:** Deploy Cloud Functions with 10% traffic split for canary testing

**Usage:**
```bash
# Deploy canary with 10% traffic
./scripts/deploy_canary.sh --project sierra-painting-prod --tag v1.2.0

# Deploy specific function only
./scripts/deploy_canary.sh --project sierra-painting-prod --function clockIn

# Dry run (preview without executing)
./scripts/deploy_canary.sh --project sierra-painting-prod --dry-run
```

**When to use:**
- Initial deployment of new features
- Testing changes with small user subset
- Progressive rollout strategy

**Features:**
- Builds and deploys Cloud Functions
- Configures 10% traffic split (Gen 2/Cloud Run)
- Records deployment metadata
- Provides monitoring links

---

#### `promote_canary.sh`

**Purpose:** Progressively promote canary deployment (10% → 50% → 100%)

**Usage:**
```bash
# Promote to 50%
./scripts/promote_canary.sh --project sierra-painting-prod --stage 50

# Promote to 100% (full rollout)
./scripts/promote_canary.sh --project sierra-painting-prod --stage 100

# Promote specific function only
./scripts/promote_canary.sh --project sierra-painting-prod --stage 50 --function clockIn

# Skip smoke tests (not recommended)
./scripts/promote_canary.sh --project sierra-painting-prod --stage 50 --skip-checks
```

**When to use:**
- After monitoring canary deployment (6-24 hours)
- When metrics show healthy status
- Progressive rollout to larger audience

**Gates (checks before proceeding):**
- ✅ Smoke tests pass
- ✅ Error rate < 2%
- ✅ P95 latency < 1s
- ✅ No critical errors

---

#### `rollback.sh`

**Purpose:** One-command rollback to restore previous Cloud Functions revision

**Usage:**
```bash
# Quick rollback via traffic split (< 5 min)
./scripts/rollback.sh --project sierra-painting-prod

# Rollback specific function only
./scripts/rollback.sh --project sierra-painting-prod --function clockIn

# Rollback via redeploy from git tag (~10 min)
./scripts/rollback.sh --project sierra-painting-prod --method redeploy --version v1.1.0

# Dry run
./scripts/rollback.sh --project sierra-painting-prod --dry-run
```

**When to use:**
- High error rates detected
- Critical bugs in production
- Performance degradation
- Emergency situations

**Rollback Methods:**
- **traffic** - Route 100% traffic to PREVIOUS revision (fast, < 5 min)
- **redeploy** - Redeploy from previous git tag (slower, ~10 min)

---

### Legacy Scripts

#### `build-and-deploy.sh`

**Purpose:** Build and deploy Next.js web app (legacy)

**Usage:**
```bash
# Build only
./scripts/build-and-deploy.sh

# Build and deploy
./scripts/build-and-deploy.sh --deploy
```

**Status:** Legacy script, may be deprecated

---

## Development Guidelines

### Adding New Scripts

1. **Choose appropriate directory:**
   - `ci/` - CI/CD automation
   - `smoke/` - Testing scripts
   - `remote-config/` - Configuration management
   - `rollback/` - Emergency procedures

2. **Script template:**
```bash
#!/bin/bash

# Script Description
# Brief explanation of what this script does

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Usage function
usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  --help    Show this help message"
  exit 0
}

# Main logic
echo -e "${GREEN}Script starting...${NC}"

# ... your code here ...

echo -e "${GREEN}✅ Script completed successfully${NC}"
```

3. **Make executable:**
```bash
chmod +x scripts/path/to/script.sh
```

4. **Test locally:**
```bash
./scripts/path/to/script.sh
```

5. **Document in this README**

---

## Common Patterns

### Error Handling

```bash
set -e  # Exit on error

# Or check specific commands
if ! command -v firebase &> /dev/null; then
  echo "Firebase CLI not found"
  exit 1
fi
```

### User Confirmation

```bash
read -p "Are you sure? (y/N): " confirm
if [ "$confirm" != "y" ]; then
  echo "Cancelled"
  exit 0
fi
```

### Project Selection

```bash
PROJECT=${1:-$(cat .firebaserc | grep default | cut -d'"' -f4)}
```

### Colored Output

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Success!${NC}"
echo -e "${RED}Error!${NC}"
echo -e "${YELLOW}Warning!${NC}"
```

---

## Testing Scripts

### Unit Testing (Optional)

Use [bats](https://github.com/bats-core/bats-core) for bash script testing:

```bash
# Install bats
npm install -g bats

# Create test file: scripts/ci/firebase-login.bats
@test "firebase-login.sh exists and is executable" {
  [ -x scripts/ci/firebase-login.sh ]
}

# Run tests
bats scripts/ci/*.bats
```

### Manual Testing Checklist

Before committing new scripts:

- [ ] Script runs without errors
- [ ] Help/usage message is clear
- [ ] Error cases are handled
- [ ] Required tools are checked
- [ ] Outputs are informative
- [ ] Script is idempotent (safe to run multiple times)
- [ ] Dry-run mode available (for destructive operations)

---

## Related Documentation

- [CI/CD Workflows](../.github/workflows/) - GitHub Actions workflows
- [Deployment Checklist](../docs/deployment_checklist.md) - Pre/post deployment tasks
- [Rollback Procedures](../docs/ui/ROLLBACK_PROCEDURES.md) - Emergency rollback steps
- [Developer Workflow](../docs/DEVELOPER_WORKFLOW.md) - Development best practices

---

## Troubleshooting

### Script Permission Denied

```bash
chmod +x scripts/path/to/script.sh
```

### Firebase CLI Not Found

```bash
npm install -g firebase-tools@13.23.1
```

### Script Fails in CI

- Check CI environment variables
- Verify secrets are configured
- Test locally with same Node/Flutter versions
- Check script exit codes

---

**Last Updated:** 2024  
**Maintainer:** DevOps Team
