#!/bin/bash
# Pre-Deployment Backup Script
# Purpose: Backup current state before v0.0.15 deployment
# Usage: ./pre-deploy-backup.sh [--staging|--production]

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_ROOT/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Default environment
ENVIRONMENT="staging"

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
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--staging|--production]"
      exit 1
      ;;
  esac
done

# Set Firebase project
if [ "$ENVIRONMENT" = "production" ]; then
  FIREBASE_PROJECT="sierra-painting"
else
  FIREBASE_PROJECT="sierra-painting-staging"
fi

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  PRE-DEPLOYMENT BACKUP - $ENVIRONMENT${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Create version-specific backup folder
BACKUP_FOLDER="$BACKUP_DIR/v0.0.14-$TIMESTAMP"
mkdir -p "$BACKUP_FOLDER"

echo -e "${YELLOW}Backup Directory:${NC} $BACKUP_FOLDER"
echo ""

# 1. Backup Remote Config
echo -e "${YELLOW}► Backing up Remote Config...${NC}"
firebase remoteconfig:get \
  --project="$FIREBASE_PROJECT" \
  -o "$BACKUP_FOLDER/remoteconfig-v0014-$TIMESTAMP.json"
echo -e "${GREEN}  ✓ Saved to remoteconfig-v0014-$TIMESTAMP.json${NC}"
echo ""

# 2. Backup Firestore Rules
echo -e "${YELLOW}► Backing up Firestore Rules...${NC}"
cp "$PROJECT_ROOT/firestore.rules" "$BACKUP_FOLDER/firestore.rules"
echo -e "${GREEN}  ✓ Saved to firestore.rules${NC}"
echo ""

# 3. Backup Firestore Indexes
echo -e "${YELLOW}► Backing up Firestore Indexes...${NC}"
cp "$PROJECT_ROOT/firestore.indexes.json" "$BACKUP_FOLDER/firestore.indexes.json"
echo -e "${GREEN}  ✓ Saved to firestore.indexes.json${NC}"
echo ""

# 4. Get current Git state
echo -e "${YELLOW}► Recording Git state...${NC}"
git rev-parse HEAD > "$BACKUP_FOLDER/git-commit.txt"
git status > "$BACKUP_FOLDER/git-status.txt"
git diff > "$BACKUP_FOLDER/git-diff.txt" 2>/dev/null || true
echo -e "${GREEN}  ✓ Git state recorded${NC}"
echo ""

# 5. List current deployments
echo -e "${YELLOW}► Recording deployment state...${NC}"
firebase hosting:sites:list --project="$FIREBASE_PROJECT" \
  > "$BACKUP_FOLDER/hosting-sites.txt" 2>&1 || true
echo -e "${GREEN}  ✓ Deployment state recorded${NC}"
echo ""

# 6. Create backup manifest
cat > "$BACKUP_FOLDER/MANIFEST.md" << EOF
# Deployment Backup Manifest

**Date**: $(date)
**Environment**: $ENVIRONMENT
**Project**: $FIREBASE_PROJECT
**Git Commit**: $(git rev-parse HEAD)
**Git Branch**: $(git branch --show-current)

## Files Backed Up

1. **Remote Config**: remoteconfig-v0014-$TIMESTAMP.json
2. **Firestore Rules**: firestore.rules
3. **Firestore Indexes**: firestore.indexes.json
4. **Git State**: git-commit.txt, git-status.txt, git-diff.txt
5. **Hosting State**: hosting-sites.txt

## Restoration Instructions

To restore from this backup:

\`\`\`bash
# 1. Checkout the git commit
git checkout $(git rev-parse HEAD)

# 2. Restore Remote Config
firebase deploy --only remoteconfig \\
  --project=$FIREBASE_PROJECT

# 3. Restore Firestore Rules & Indexes
firebase deploy --only firestore:rules,firestore:indexes \\
  --project=$FIREBASE_PROJECT

# 4. Or use the rollback script
./scripts/rollback-v0015.sh --$ENVIRONMENT
\`\`\`

## Post-Backup Actions

- [ ] Verify backup files are readable
- [ ] Tag current version in Git
- [ ] Proceed with v0.0.15 deployment
- [ ] Keep backup for 90 days minimum

## Notes

[Add any special considerations or context]
EOF

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  BACKUP COMPLETE${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Backup Location: $BACKUP_FOLDER"
echo ""
echo "Files backed up:"
ls -lh "$BACKUP_FOLDER"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Review backup files"
echo "  2. Tag current version: git tag v0.0.14-pre-deploy"
echo "  3. Proceed with deployment"
echo ""
