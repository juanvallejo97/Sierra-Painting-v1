#!/bin/bash

# Deploy Cloud Functions with Canary Traffic Split (10%)
# Deploys a new revision with 10% traffic for canary testing

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
  echo -e "${BLUE}Deploy Cloud Functions with Canary Traffic (10%)${NC}"
  echo "================================================"
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --project <project-id>   Firebase project ID (required)"
  echo "  --function <name>        Deploy specific function only (optional)"
  echo "  --tag <tag>              Git tag/version for deployment tracking (optional)"
  echo "  --dry-run               Show what would be done without executing"
  echo "  --help                   Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --project sierra-painting-prod --tag v1.2.0"
  echo "  $0 --project sierra-painting-prod --function clockIn"
  echo "  $0 --project sierra-painting-staging --dry-run"
  echo ""
}

# Check required tools
check_requirements() {
  local missing_tools=()
  
  if ! command -v firebase &> /dev/null; then
    missing_tools+=("firebase-tools")
  fi
  
  if ! command -v gcloud &> /dev/null; then
    missing_tools+=("gcloud")
  fi
  
  if [ ${#missing_tools[@]} -gt 0 ]; then
    echo -e "${RED}❌ Error: Missing required tools${NC}"
    echo ""
    for tool in "${missing_tools[@]}"; do
      echo "  - $tool"
    done
    echo ""
    echo "Install instructions:"
  echo "  firebase-tools: npm install -g firebase-tools@13.23.1"
    echo "  gcloud: https://cloud.google.com/sdk/docs/install"
    exit 1
  fi
}

# Build functions
build_functions() {
  local dry_run=$1
  
  echo -e "${BLUE}📦 Building Cloud Functions${NC}"
  echo "================================================"
  echo ""
  
  if [ "$dry_run" = "true" ]; then
    echo -e "${YELLOW}[DRY RUN]${NC} Would build functions"
    return 0
  fi
  
  cd functions
  echo "Installing dependencies..."
  npm ci
  echo ""
  echo "Building TypeScript..."
  npm run build
  cd ..
  
  echo -e "${GREEN}✅ Build completed${NC}"
  echo ""
}

# Deploy functions with Firebase
deploy_functions_firebase() {
  local project=$1
  local function=$2
  local dry_run=$3
  
  echo -e "${BLUE}🚀 Deploying Functions to Firebase${NC}"
  echo "================================================"
  echo ""
  
  if [ "$dry_run" = "true" ]; then
    echo -e "${YELLOW}[DRY RUN]${NC} Would deploy functions to $project"
    if [ -n "$function" ]; then
      echo "  Target: functions:$function"
    else
      echo "  Target: all functions"
    fi
    return 0
  fi
  
  local target="functions"
  if [ -n "$function" ]; then
    target="functions:$function"
  fi
  
  echo "Deploying to project: $project"
  echo "Target: $target"
  echo ""
  
  firebase deploy --only "$target" --project "$project" --non-interactive
  
  echo ""
  echo -e "${GREEN}✅ Firebase deployment completed${NC}"
  echo ""
}

# Configure traffic split for Cloud Run (Gen 2 functions)
configure_traffic_split() {
  local project=$1
  local function=$2
  local dry_run=$3
  
  echo -e "${BLUE}⚖️  Configuring Traffic Split (10% Canary)${NC}"
  echo "================================================"
  echo ""
  
  if [ "$dry_run" = "true" ]; then
    echo -e "${YELLOW}[DRY RUN]${NC} Would configure traffic split:"
    echo "  Project: $project"
    echo "  Function: $function (if specified)"
    echo "  Traffic: LATEST=10, PREVIOUS=90"
    echo ""
    echo "Note: Traffic splitting requires Cloud Functions Gen 2 (Cloud Run)"
    return 0
  fi
  
  # Get list of Cloud Run services (Gen 2 functions)
  echo "Fetching Cloud Run services..."
  local services
  services=$(gcloud run services list --project="$project" --platform=managed --format="value(metadata.name)" 2>/dev/null || true)
  
  if [ -z "$services" ]; then
    echo -e "${YELLOW}⚠️  No Cloud Run services found${NC}"
    echo "Note: Traffic splitting only works with Gen 2 functions (Cloud Run)"
    echo ""
    echo "Alternative: Use Firebase Remote Config for gradual rollout"
    echo "  See: scripts/remote-config/manage-flags.sh"
    return 0
  fi
  
  echo "Found services:"
  echo "$services" | while read -r svc; do echo "  - $svc"; done
  echo ""
  
  # Apply traffic split
  if [ -n "$function" ]; then
    # Split traffic for specific function
    if echo "$services" | grep -q "^$function\$"; then
      echo "Configuring traffic for: $function"
      gcloud run services update-traffic "$function" \
        --to-revisions=LATEST=10 \
        --project="$project" \
        --platform=managed \
  --region=us-east4
    --region=us-east4
      echo -e "${GREEN}✅ Traffic split configured for $function${NC}"
    else
      echo -e "${YELLOW}⚠️  Service '$function' not found in Cloud Run${NC}"
    fi
  else
    # Split traffic for all services
    echo "$services" | while IFS= read -r svc; do
      if [ -n "$svc" ]; then
        echo "Configuring traffic for: $svc"
        gcloud run services update-traffic "$svc" \
          --to-revisions=LATEST=10 \
          --project="$project" \
          --platform=managed \
          --region=us-east4 2>/dev/null || {
            --region=us-east4 2>/dev/null || {
            echo -e "${YELLOW}⚠️  Could not update traffic for $svc${NC}"
          }
      fi
    done
    echo -e "${GREEN}✅ Traffic split configured for all services${NC}"
  fi
  
  echo ""
}

# Record deployment metadata
record_deployment() {
  local project=$1
  local tag=$2
  local function=$3
  local dry_run=$4
  
  echo -e "${BLUE}📝 Recording Deployment Metadata${NC}"
  echo "================================================"
  echo ""
  
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local deploy_id="canary-${timestamp}"
  
  if [ "$dry_run" = "true" ]; then
    echo -e "${YELLOW}[DRY RUN]${NC} Would record deployment:"
    echo "  Project: $project"
    echo "  Tag: ${tag:-'untagged'}"
    echo "  Function: ${function:-'all'}"
    echo "  Timestamp: $timestamp"
    echo "  Deploy ID: $deploy_id"
    return 0
  fi
  
  # Create deployment record file
  mkdir -p .deployment-history
  local record_file=".deployment-history/${deploy_id}.json"
  
  cat > "$record_file" <<EOF
{
  "deploymentId": "$deploy_id",
  "timestamp": "$timestamp",
  "project": "$project",
  "tag": "${tag:-null}",
  "function": "${function:-all}",
  "stage": "canary",
  "trafficPercentage": 10,
  "gitCommit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
  "deployedBy": "${USER:-unknown}"
}
EOF
  
  echo "Deployment record saved: $record_file"
  echo ""
  echo -e "${GREEN}✅ Deployment metadata recorded${NC}"
  echo ""
}

# Main deployment flow
main() {
  local project=""
  local function=""
  local tag=""
  local dry_run="false"
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --project)
        project="$2"
        shift 2
        ;;
      --function)
        function="$2"
        shift 2
        ;;
      --tag)
        tag="$2"
        shift 2
        ;;
      --dry-run)
        dry_run="true"
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
  
  # Validate required arguments
  if [ -z "$project" ]; then
    echo -e "${RED}❌ Error: --project is required${NC}"
    usage
    exit 1
  fi
  
  echo -e "${BLUE}🎯 Canary Deployment (10% Traffic)${NC}"
  echo "================================================"
  echo ""
  echo "Project: $project"
  [ -n "$function" ] && echo "Function: $function"
  [ -n "$tag" ] && echo "Version: $tag"
  echo ""
  
  # Check requirements
  check_requirements
  
  # Build functions
  build_functions "$dry_run"
  
  # Deploy to Firebase
  deploy_functions_firebase "$project" "$function" "$dry_run"
  
  # Configure traffic split (Cloud Run Gen 2 only)
  configure_traffic_split "$project" "$function" "$dry_run"
  
  # Record deployment
  record_deployment "$project" "$tag" "$function" "$dry_run"
  
  echo "================================================"
  echo -e "${GREEN}✅ Canary Deployment Complete${NC}"
  echo "================================================"
  echo ""
  echo "Next steps:"
  echo "  1. Monitor metrics in Firebase Console"
  echo "  2. Run smoke tests: scripts/smoke/run.sh"
  echo "  3. Check error rates and latency"
  echo "  4. Promote to 50%: scripts/promote_canary.sh --project $project --stage 50"
  echo "  5. Or rollback: scripts/rollback.sh --project $project"
  echo ""
  echo "Monitoring links:"
  echo "  Firebase Console: https://console.firebase.google.com/project/$project"
  echo "  Cloud Functions: https://console.cloud.google.com/functions/list?project=$project"
  echo "  Cloud Run: https://console.cloud.google.com/run?project=$project"
  echo ""
}

# Execute main
main "$@"
