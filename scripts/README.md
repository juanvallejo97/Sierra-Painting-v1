# Scripts Directory

This directory contains helper scripts for CI/CD, testing, and deployment operations.

## Directory Structure

```
scripts/
├── ci/                          # CI/CD helper scripts
│   └── firebase-login.sh        # Validate Firebase authentication
├── smoke/                       # Smoke testing scripts
│   └── run.sh                   # Emulator smoke test suite
├── remote-config/               # Remote Config management
│   └── manage-flags.sh          # Feature flag management
├── rollback/                    # Rollback procedures
│   └── rollback-functions.sh    # Function rollback helper
├── quality.sh                   # Code quality checks
├── generate-docs.sh             # Generate API documentation
└── build-and-deploy.sh          # Legacy web app build script
```

## Scripts Overview

### Code Quality Scripts

#### `quality.sh`

**Purpose:** Run comprehensive code quality checks including linting, analysis, and dead code detection

**Usage:**
```bash
# Run all quality checks
./scripts/quality.sh

# Apply auto-fixes before checking
./scripts/quality.sh --fix

# Run with fatal-infos (fail on info-level issues)
./scripts/quality.sh --fatal-infos

# Skip metrics checks
./scripts/quality.sh --no-metrics

# Skip unused code detection
./scripts/quality.sh --no-unused
```

**Checks performed:**
1. Dart auto-fixes (optional, with `--fix`)
2. Dart analysis with strict linting rules
3. dart_code_metrics analysis (complexity, maintainability)
4. Unused code detection

**When to use:**
- Before committing code
- During CI/CD workflows
- Before creating pull requests
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
npm install -g firebase-tools
```

### Script Fails in CI

- Check CI environment variables
- Verify secrets are configured
- Test locally with same Node/Flutter versions
- Check script exit codes

---

**Last Updated:** 2024  
**Maintainer:** DevOps Team
