#!/bin/bash

# Deploy to Environment Script
# Unified deployment script supporting dev, staging, and production

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage
usage() {
  echo -e "${BLUE}Deploy to Environment${NC}"
  echo "================================================"
  echo ""
  echo "Usage: $0 --env <environment> [options]"
  echo ""
  echo "Required:"
  echo "  --env <environment>      Target environment: dev, staging, prod"
  echo ""
  echo "Options:"
  echo "  --skip-checks           Skip pre-deploy checks (not recommended)"
  echo "  --functions-only        Deploy only Cloud Functions"
  echo "  --rules-only           Deploy only Firestore/Storage rules"
  echo "  --hosting-only         Deploy only hosting"
  echo "  --dry-run              Show what would be deployed"
  echo "  --help                 Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --env staging"
  echo "  $0 --env prod --functions-only"
  echo "  $0 --env dev --skip-checks"
  echo ""
}

# Parse arguments
ENVIRONMENT=""
SKIP_CHECKS=false
DEPLOY_TARGET="all"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --env)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --skip-checks)
      SKIP_CHECKS=true
      shift
      ;;
    --functions-only)
      DEPLOY_TARGET="functions"
      shift
      ;;
    --rules-only)
      DEPLOY_TARGET="rules"
      shift
      ;;
    --hosting-only)
      DEPLOY_TARGET="hosting"
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo -e "${RED}❌ Unknown option: $1${NC}"
      usage
      exit 1
      ;;
  esac
done

# Validate environment
if [ -z "$ENVIRONMENT" ]; then
  echo -e "${RED}❌ Error: Environment is required${NC}"
  usage
  exit 1
fi

if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
  echo -e "${RED}❌ Error: Invalid environment. Must be dev, staging, or prod${NC}"
  exit 1
fi

# Map environment to Firebase project
case $ENVIRONMENT in
  dev)
    PROJECT_ID="sierra-painting-dev"
    ;;
  staging)
    PROJECT_ID="sierra-painting-staging"
    ;;
  prod)
    PROJECT_ID="sierra-painting-prod"
    ;;
esac

echo -e "${BLUE}🚀 Deploying to $ENVIRONMENT${NC}"
echo "================================================"
echo ""
echo "Environment: $ENVIRONMENT"
echo "Project ID: $PROJECT_ID"
echo "Deploy Target: $DEPLOY_TARGET"
echo "Skip Checks: $SKIP_CHECKS"
echo "Dry Run: $DRY_RUN"
echo ""

# Run pre-deploy checks
if [ "$SKIP_CHECKS" = false ]; then
  echo -e "${BLUE}Running Pre-Deploy Checks${NC}"
  echo "================================================"
  if bash scripts/deploy/pre-deploy-checks.sh "$ENVIRONMENT"; then
    echo -e "${GREEN}✓ Pre-deploy checks passed${NC}"
  else
    echo -e "${RED}✗ Pre-deploy checks failed${NC}"
    exit 1
  fi
  echo ""
fi

# Note: Using explicit --project flag instead of firebase use
echo -e "${BLUE}Using Firebase Project${NC}"
echo "================================================"
echo "Project ID: $PROJECT_ID (via --project flag)"
echo ""

# Build deploy command
DEPLOY_CMD="firebase deploy"

case $DEPLOY_TARGET in
  functions)
    DEPLOY_CMD="$DEPLOY_CMD --only functions"
    ;;
  rules)
    DEPLOY_CMD="$DEPLOY_CMD --only firestore:rules,storage:rules,firestore:indexes"
    ;;
  hosting)
    DEPLOY_CMD="$DEPLOY_CMD --only hosting"
    ;;
  all)
    DEPLOY_CMD="$DEPLOY_CMD --only functions,firestore:rules,storage:rules,firestore:indexes,hosting"
    ;;
esac

DEPLOY_CMD="$DEPLOY_CMD --project $PROJECT_ID --non-interactive"

# Execute deployment
echo -e "${BLUE}Deploying${NC}"
echo "================================================"
echo "Command: $DEPLOY_CMD"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo -e "${YELLOW}[DRY RUN]${NC} Deployment skipped"
else
  eval "$DEPLOY_CMD"
fi

echo ""
echo "================================================"
echo -e "${GREEN}✅ Deployment Complete${NC}"
echo "================================================"
echo ""
echo "Environment: $ENVIRONMENT"
echo "Project: $PROJECT_ID"
echo ""
echo "📊 Monitoring Links:"
echo "  Firebase Console: https://console.firebase.google.com/project/$PROJECT_ID"
echo "  Functions: https://console.cloud.google.com/functions/list?project=$PROJECT_ID"
echo "  Logs: https://console.cloud.google.com/logs/query?project=$PROJECT_ID"
echo "  Errors: https://console.cloud.google.com/errors?project=$PROJECT_ID"
echo ""
echo "📋 Next Steps:"
echo "  1. Monitor deployment for errors"
echo "  2. Run smoke tests: scripts/smoke/run.sh"
echo "  3. Verify key user journeys"
echo "  4. Check performance metrics"
echo ""

if [ "$ENVIRONMENT" = "prod" ]; then
  echo -e "${YELLOW}⚠️  PRODUCTION DEPLOYMENT${NC}"
  echo "  - Monitor closely for next 2 hours"
  echo "  - Have rollback plan ready: scripts/rollback.sh"
  echo "  - Update team on deployment status"
  echo ""
fi
