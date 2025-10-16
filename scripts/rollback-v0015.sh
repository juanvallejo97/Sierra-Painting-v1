#!/bin/bash
# Rollback Script for v0.0.15
# Purpose: Emergency rollback for staging/production deployment
# Usage: ./rollback-v0015.sh [--staging|--production] [--dry-run]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_ROOT/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Default values
ENVIRONMENT="staging"
DRY_RUN=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --staging)
      ENVIRONMENT="staging"
      shift
      ;;
    --production)
      ENVIRONMENT="production"
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--staging|--production] [--dry-run]"
      exit 1
      ;;
  esac
done

# Set Firebase project based on environment
if [ "$ENVIRONMENT" = "production" ]; then
  FIREBASE_PROJECT="sierra-painting"
else
  FIREBASE_PROJECT="sierra-painting-staging"
fi

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  ROLLBACK v0.0.15 - $ENVIRONMENT${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo -e "${GREEN}[DRY RUN MODE - No changes will be made]${NC}"
  echo ""
fi

# Function to execute or simulate command
run_cmd() {
  local cmd="$1"
  local description="$2"

  echo -e "${YELLOW}► $description${NC}"
  echo "  Command: $cmd"

  if [ "$DRY_RUN" = false ]; then
    if eval "$cmd"; then
      echo -e "${GREEN}  ✓ Success${NC}"
    else
      echo -e "${RED}  ✗ Failed${NC}"
      return 1
    fi
  else
    echo -e "${GREEN}  ✓ Would execute (dry run)${NC}"
  fi
  echo ""
}

# Create backup directory if needed
mkdir -p "$BACKUP_DIR"

echo -e "${YELLOW}Step 1: Activate Panic Flags${NC}"
echo "==============================="
run_cmd "firebase remoteconfig:set global_panic true --project=$FIREBASE_PROJECT" \
        "Set global_panic flag"
run_cmd "firebase remoteconfig:set panic_disable_new_ui true --project=$FIREBASE_PROJECT" \
        "Set panic_disable_new_ui flag"
run_cmd "firebase remoteconfig:set telemetry_enabled false --project=$FIREBASE_PROJECT" \
        "Disable telemetry"

echo -e "${YELLOW}Step 2: Backup Current Remote Config${NC}"
echo "======================================="
BACKUP_FILE="$BACKUP_DIR/remoteconfig-rollback-$TIMESTAMP.json"
run_cmd "firebase remoteconfig:get --project=$FIREBASE_PROJECT -o '$BACKUP_FILE'" \
        "Backup Remote Config to $BACKUP_FILE"

echo -e "${YELLOW}Step 3: Rollback Remote Config${NC}"
echo "================================="
# Check if we have a previous backup to restore
PREVIOUS_BACKUP=$(ls -t "$BACKUP_DIR"/remoteconfig-v0014-*.json 2>/dev/null | head -1)
if [ -n "$PREVIOUS_BACKUP" ]; then
  run_cmd "firebase deploy --only remoteconfig --project=$FIREBASE_PROJECT" \
          "Restore previous Remote Config from $PREVIOUS_BACKUP"
else
  echo -e "${YELLOW}  No previous backup found, keeping panic flags active${NC}"
fi

echo -e "${YELLOW}Step 4: Rollback Hosting${NC}"
echo "========================="
if [ "$ENVIRONMENT" = "production" ]; then
  # Production: Clone previous live version
  run_cmd "firebase hosting:clone $FIREBASE_PROJECT:live rollback-$TIMESTAMP --project=$FIREBASE_PROJECT" \
          "Clone previous live version to rollback"
else
  # Staging: Deploy previous channel
  run_cmd "firebase hosting:channel:deploy rollback-v0014 --expires 7d --project=$FIREBASE_PROJECT" \
          "Create rollback channel from previous version"
fi

echo -e "${YELLOW}Step 5: Verify Rollback${NC}"
echo "========================"
run_cmd "firebase remoteconfig:get --project=$FIREBASE_PROJECT" \
        "Verify Remote Config state"
run_cmd "firebase hosting:sites:list --project=$FIREBASE_PROJECT" \
        "Verify hosting sites"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ROLLBACK COMPLETE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Summary:"
echo "  Environment: $ENVIRONMENT"
echo "  Project: $FIREBASE_PROJECT"
echo "  Backup saved: $BACKUP_FILE"
echo "  Timestamp: $TIMESTAMP"
echo ""

if [ "$DRY_RUN" = false ]; then
  echo -e "${YELLOW}Post-Rollback Actions:${NC}"
  echo "  1. Monitor Crashlytics for errors"
  echo "  2. Check user reports"
  echo "  3. Document rollback reason in: rollback-incident-$TIMESTAMP.md"
  echo "  4. Create postmortem issue"
  echo ""

  # Create incident template
  cat > "$PROJECT_ROOT/rollback-incident-$TIMESTAMP.md" << EOF
# Rollback Incident - v0.0.15

**Date**: $(date)
**Environment**: $ENVIRONMENT
**Executed By**: $USER
**Duration**: [FILL]

## Reason for Rollback
[Describe what went wrong]

## Impact
- **Users Affected**: [FILL]
- **Duration**: [FILL]
- **Data Loss**: [YES/NO]
- **Revenue Impact**: [FILL]

## Timeline
- **Issue Detected**: [TIME]
- **Rollback Started**: $TIMESTAMP
- **Rollback Completed**: $(date +%H:%M:%S)
- **Service Restored**: [TIME]

## Root Cause
[Technical explanation of the failure]

## Resolution
[How the rollback fixed the issue]

## Prevention
[Action items to prevent recurrence]
- [ ] Action 1
- [ ] Action 2
- [ ] Action 3

## Related Issues
- GitHub Issue: #[ISSUE_NUMBER]
- Slack Thread: [LINK]
EOF

  echo -e "${GREEN}Created incident report template: rollback-incident-$TIMESTAMP.md${NC}"
else
  echo -e "${GREEN}Dry run complete. No changes were made.${NC}"
fi

echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Investigate root cause"
echo "  2. Fix identified issues"
echo "  3. Test fixes thoroughly"
echo "  4. Re-deploy when confident"
echo ""
