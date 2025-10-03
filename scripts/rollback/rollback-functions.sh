#!/bin/bash

# Cloud Functions Rollback Script
# Rolls back Firebase Cloud Functions to a previous version

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
  echo -e "${BLUE}Firebase Cloud Functions Rollback${NC}"
  echo "================================================"
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --project <project-id>   Firebase project ID (required)"
  echo "  --version <version>      Version to rollback to (optional)"
  echo "  --list                   List available versions"
  echo "  --function <name>        Rollback specific function only"
  echo "  --dry-run               Show what would be done without executing"
  echo "  --help                   Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --list --project sierra-painting-prod"
  echo "  $0 --project sierra-painting-prod --version 2"
  echo "  $0 --project sierra-painting-prod --function clockIn --version 1"
  echo "  $0 --project sierra-painting-staging --dry-run"
  echo ""
}

# Check Firebase CLI
check_firebase_cli() {
  if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Error: Firebase CLI not found${NC}"
    echo "Install with: npm install -g firebase-tools"
    exit 1
  fi
}

# Check gcloud CLI
check_gcloud_cli() {
  if ! command -v gcloud &> /dev/null; then
    echo -e "${YELLOW}⚠️  Warning: gcloud CLI not found${NC}"
    echo "Some features require gcloud CLI"
    echo "Install from: https://cloud.google.com/sdk/docs/install"
    return 1
  fi
  return 0
}

# List function versions
list_versions() {
  local project=$1
  
  echo -e "${BLUE}📋 Cloud Functions Versions${NC}"
  echo "================================================"
  echo ""
  
  if check_gcloud_cli; then
    echo "Listing functions in project: $project"
    gcloud functions list --project=$project --format="table(name,status,runtime,updateTime)" || {
      echo -e "${YELLOW}⚠️  Could not list functions${NC}"
    }
    echo ""
    echo "To see version history of a specific function:"
    echo "  gcloud functions describe FUNCTION_NAME --project=$project --gen2"
  else
    echo -e "${YELLOW}⚠️  Install gcloud CLI to list function versions${NC}"
    echo ""
    echo "Alternative: Use Firebase Console"
    echo "  https://console.cloud.google.com/functions/list?project=$project"
  fi
}

# Rollback specific function
rollback_function() {
  local project=$1
  local function_name=$2
  local version=$3
  local dry_run=$4
  
  echo -e "${BLUE}🔄 Rolling back function: $function_name${NC}"
  echo "================================================"
  echo ""
  
  if [ "$dry_run" = "true" ]; then
    echo -e "${YELLOW}[DRY RUN]${NC} Would rollback $function_name to version $version"
    echo ""
    echo "Steps that would be executed:"
    echo "  1. Get source code from git tag/commit for version $version"
    echo "  2. Build functions with that version"
    echo "  3. Deploy specific function: firebase deploy --only functions:$function_name"
    echo ""
    return 0
  fi
  
  echo -e "${RED}❌ Manual rollback required${NC}"
  echo ""
  echo "Rollback steps:"
  echo "  1. Identify the git tag/commit for the working version"
  echo "  2. Checkout that version: git checkout <tag>"
  echo "  3. Build functions: cd functions && npm run build"
  echo "  4. Deploy: firebase deploy --only functions:$function_name --project $project"
  echo ""
  echo "Quick rollback using git:"
  echo "  # Find the tag"
  echo "  git tag -l"
  echo "  "
  echo "  # Checkout tag"
  echo "  git checkout v1.x.x"
  echo "  "
  echo "  # Deploy"
  echo "  cd functions && npm ci && npm run build"
  echo "  firebase deploy --only functions:$function_name --project $project"
  echo ""
}

# Rollback all functions
rollback_all() {
  local project=$1
  local version=$2
  local dry_run=$3
  
  echo -e "${BLUE}🔄 Rolling back all functions${NC}"
  echo "================================================"
  echo ""
  
  if [ "$dry_run" = "true" ]; then
    echo -e "${YELLOW}[DRY RUN]${NC} Would rollback all functions to version $version"
    echo ""
    echo "Steps that would be executed:"
    echo "  1. Get source code from git tag for version $version"
    echo "  2. Build functions with that version"
    echo "  3. Deploy all functions: firebase deploy --only functions"
    echo ""
    return 0
  fi
  
  echo -e "${YELLOW}⚠️  Warning: This will rollback ALL functions${NC}"
  read -p "Continue? (y/N): " confirm
  
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Rollback cancelled"
    exit 0
  fi
  
  echo -e "${RED}❌ Manual rollback required${NC}"
  echo ""
  echo "Rollback steps:"
  echo "  1. Identify the git tag for the working version"
  echo "     git tag -l"
  echo ""
  echo "  2. Checkout that version"
  echo "     git checkout <tag>"
  echo ""
  echo "  3. Build and deploy"
  echo "     cd functions"
  echo "     npm ci"
  echo "     npm run build"
  echo "     cd .."
  echo "     firebase deploy --only functions --project $project"
  echo ""
  echo "  4. Verify deployment"
  echo "     - Check Cloud Functions logs"
  echo "     - Test critical flows"
  echo "     - Monitor error rates"
  echo ""
  echo "Emergency: Use Remote Config to disable features"
  echo "  scripts/remote-config/manage-flags.sh disable FEATURE_FLAG --project $project"
  echo ""
}

# Main script
check_firebase_cli

# Parse arguments
PROJECT=""
VERSION=""
FUNCTION=""
DRY_RUN="false"
LIST_MODE="false"

while [[ $# -gt 0 ]]; do
  case $1 in
    --project)
      PROJECT="$2"
      shift 2
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --function)
      FUNCTION="$2"
      shift 2
      ;;
    --list)
      LIST_MODE="true"
      shift
      ;;
    --dry-run)
      DRY_RUN="true"
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo -e "${RED}❌ Error: Unknown option: $1${NC}"
      usage
      exit 1
      ;;
  esac
done

# Validate project
if [ -z "$PROJECT" ]; then
  echo -e "${RED}❌ Error: --project is required${NC}"
  usage
  exit 1
fi

# Execute command
if [ "$LIST_MODE" = "true" ]; then
  list_versions "$PROJECT"
elif [ -n "$FUNCTION" ]; then
  rollback_function "$PROJECT" "$FUNCTION" "$VERSION" "$DRY_RUN"
else
  rollback_all "$PROJECT" "$VERSION" "$DRY_RUN"
fi

echo ""
echo "================================================"
echo -e "${BLUE}📚 Additional Resources${NC}"
echo "================================================"
echo ""
echo "Rollback documentation:"
echo "  docs/rollout-rollback.md"
echo "  docs/ui/ROLLBACK_PROCEDURES.md"
echo ""
echo "Monitoring:"
echo "  Cloud Functions Logs: https://console.cloud.google.com/logs/query?project=$PROJECT"
echo "  Error Reporting: https://console.cloud.google.com/errors?project=$PROJECT"
echo "  Crashlytics: https://console.firebase.google.com/project/$PROJECT/crashlytics"
echo ""
