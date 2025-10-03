#!/bin/bash

# Rollback Cloud Functions Deployment
# Restores previous revision by routing 100% traffic to PREVIOUS revision

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
  echo -e "${BLUE}Rollback Cloud Functions Deployment${NC}"
  echo "================================================"
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --project <project-id>   Firebase project ID (required)"
  echo "  --function <name>        Rollback specific function only (optional)"
  echo "  --method <method>        Rollback method: traffic|redeploy (default: traffic)"
  echo "  --version <tag>          Git tag to rollback to (for redeploy method)"
  echo "  --dry-run               Show what would be done without executing"
  echo "  --help                   Show this help message"
  echo ""
  echo "Rollback Methods:"
  echo "  traffic    - Route 100% traffic to PREVIOUS revision (fast, < 5 min)"
  echo "  redeploy   - Redeploy from previous git tag (slower, ~10 min)"
  echo ""
  echo "Examples:"
  echo "  $0 --project sierra-painting-prod"
  echo "  $0 --project sierra-painting-prod --function clockIn"
  echo "  $0 --project sierra-painting-prod --method redeploy --version v1.1.0"
  echo ""
}

# Check required tools
check_requirements() {
  local method=$1
  local missing_tools=()
  
  if ! command -v gcloud &> /dev/null; then
    missing_tools+=("gcloud")
  fi
  
  if [ "$method" = "redeploy" ]; then
    if ! command -v firebase &> /dev/null; then
      missing_tools+=("firebase-tools")
    fi
  fi
  
  if [ ${#missing_tools[@]} -gt 0 ]; then
    echo -e "${RED}❌ Error: Missing required tools${NC}"
    echo ""
    for tool in "${missing_tools[@]}"; do
      echo "  - $tool"
    done
    echo ""
    echo "Install instructions:"
    echo "  gcloud: https://cloud.google.com/sdk/docs/install"
    echo "  firebase-tools: npm install -g firebase-tools"
    exit 1
  fi
}

# Rollback via traffic split (fastest)
rollback_via_traffic() {
  local project=$1
  local function=$2
  local dry_run=$3
  
  echo -e "${BLUE}⚖️  Rolling Back via Traffic Split${NC}"
  echo "================================================"
  echo ""
  echo "Method: Route 100% traffic to PREVIOUS revision"
  echo "Expected time: < 5 minutes"
  echo ""
  
  if [ "$dry_run" = "true" ]; then
    echo -e "${YELLOW}[DRY RUN]${NC} Would rollback traffic:"
    echo "  Project: $project"
    echo "  Function: ${function:-all}"
    echo "  Traffic: PREVIOUS=100"
    return 0
  fi
  
  # Confirmation prompt
  echo -e "${YELLOW}⚠️  WARNING: This will route 100% traffic to the PREVIOUS revision${NC}"
  read -p "Continue with rollback? (y/N): " confirm
  
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Rollback cancelled"
    exit 0
  fi
  
  # Get list of Cloud Run services (Gen 2 functions)
  echo ""
  echo "Fetching Cloud Run services..."
  local services
  services=$(gcloud run services list --project="$project" --platform=managed --format="value(metadata.name)" 2>/dev/null || true)
  
  if [ -z "$services" ]; then
    echo -e "${YELLOW}⚠️  No Cloud Run services found${NC}"
    echo ""
    echo "Note: Traffic rollback only works with Gen 2 functions (Cloud Run)"
    echo ""
    echo "Alternative rollback methods:"
    echo "  1. Use --method redeploy with a previous version tag"
    echo "  2. Use Firebase Remote Config to disable features"
    echo "  3. See: scripts/rollback/rollback-functions.sh"
    return 1
  fi
  
  echo "Found services:"
  echo "$services" | while read -r svc; do echo "  - $svc"; done
  echo ""
  
  # Apply traffic rollback
  if [ -n "$function" ]; then
    # Rollback specific function
    if echo "$services" | grep -q "^$function\$"; then
      echo "Rolling back: $function"
      gcloud run services update-traffic "$function" \
        --to-revisions=PREVIOUS=100 \
        --project="$project" \
        --platform=managed \
        --region=us-central1
      echo -e "${GREEN}✅ Rolled back: $function${NC}"
    else
      echo -e "${YELLOW}⚠️  Service '$function' not found in Cloud Run${NC}"
      return 1
    fi
  else
    # Rollback all services
    local failed=()
    echo "$services" | while IFS= read -r svc; do
      if [ -n "$svc" ]; then
        echo "Rolling back: $svc"
        if gcloud run services update-traffic "$svc" \
          --to-revisions=PREVIOUS=100 \
          --project="$project" \
          --platform=managed \
          --region=us-central1 2>/dev/null; then
          echo -e "${GREEN}✅ Rolled back: $svc${NC}"
        else
          echo -e "${YELLOW}⚠️  Could not rollback: $svc${NC}"
          failed+=("$svc")
        fi
      fi
    done
    
    if [ ${#failed[@]} -gt 0 ]; then
      echo ""
      echo -e "${YELLOW}⚠️  Some services failed to rollback:${NC}"
      for svc in "${failed[@]}"; do
        echo "  - $svc"
      done
    fi
  fi
  
  echo ""
  echo -e "${GREEN}✅ Traffic rollback complete${NC}"
  echo ""
}

# Rollback via redeploy (from git tag)
rollback_via_redeploy() {
  local project=$1
  local function=$2
  local version=$3
  local dry_run=$4
  
  echo -e "${BLUE}🔄 Rolling Back via Redeploy${NC}"
  echo "================================================"
  echo ""
  echo "Method: Redeploy from git tag"
  echo "Expected time: ~10 minutes"
  echo ""
  
  if [ -z "$version" ]; then
    echo -e "${RED}❌ Error: --version is required for redeploy method${NC}"
    echo ""
    echo "Available tags:"
    git tag -l | tail -10
    exit 1
  fi
  
  if [ "$dry_run" = "true" ]; then
    echo -e "${YELLOW}[DRY RUN]${NC} Would redeploy from version: $version"
    echo "  Project: $project"
    echo "  Function: ${function:-all}"
    return 0
  fi
  
  # Confirmation
  echo -e "${YELLOW}⚠️  WARNING: This will redeploy from tag $version${NC}"
  read -p "Continue with rollback? (y/N): " confirm
  
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Rollback cancelled"
    exit 0
  fi
  
  echo ""
  
  # Check if tag exists
  if ! git rev-parse "$version" >/dev/null 2>&1; then
    echo -e "${RED}❌ Error: Tag '$version' not found${NC}"
    echo ""
    echo "Available tags:"
    git tag -l | tail -10
    exit 1
  fi
  
  # Stash current changes
  echo "Stashing current changes..."
  git stash push -u -m "Rollback stash $(date +%Y%m%d-%H%M%S)"
  
  # Checkout tag
  echo "Checking out tag: $version"
  git checkout "$version"
  
  # Build functions
  echo ""
  echo "Building functions..."
  cd functions
  npm ci
  npm run build
  cd ..
  
  # Deploy
  echo ""
  echo "Deploying to Firebase..."
  local target="functions"
  if [ -n "$function" ]; then
    target="functions:$function"
  fi
  
  firebase deploy --only "$target" --project "$project" --non-interactive
  
  # Return to previous branch
  echo ""
  echo "Returning to previous state..."
  git checkout -
  
  echo ""
  echo -e "${GREEN}✅ Redeploy rollback complete${NC}"
  echo ""
}

# Record rollback
record_rollback() {
  local project=$1
  local method=$2
  local function=$3
  local version=$4
  local dry_run=$5
  
  echo -e "${BLUE}📝 Recording Rollback${NC}"
  echo "================================================"
  echo ""
  
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local rollback_id="rollback-${timestamp}"
  
  if [ "$dry_run" = "true" ]; then
    echo -e "${YELLOW}[DRY RUN]${NC} Would record rollback"
    return 0
  fi
  
  # Create rollback record file
  mkdir -p .deployment-history
  local record_file=".deployment-history/${rollback_id}.json"
  
  cat > "$record_file" <<EOF
{
  "rollbackId": "$rollback_id",
  "timestamp": "$timestamp",
  "project": "$project",
  "method": "$method",
  "function": "${function:-all}",
  "version": "${version:-null}",
  "gitCommit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
  "rolledBackBy": "${USER:-unknown}"
}
EOF
  
  echo "Rollback record saved: $record_file"
  echo ""
  echo -e "${GREEN}✅ Rollback recorded${NC}"
  echo ""
}

# Main rollback flow
main() {
  local project=""
  local function=""
  local method="traffic"
  local version=""
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
      --method)
        method="$2"
        shift 2
        ;;
      --version)
        version="$2"
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
  
  # Validate method
  if [ "$method" != "traffic" ] && [ "$method" != "redeploy" ]; then
    echo -e "${RED}❌ Error: --method must be 'traffic' or 'redeploy'${NC}"
    usage
    exit 1
  fi
  
  echo -e "${RED}🚨 ROLLBACK INITIATED${NC}"
  echo "================================================"
  echo ""
  echo "Project: $project"
  echo "Method: $method"
  [ -n "$function" ] && echo "Function: $function"
  [ -n "$version" ] && echo "Version: $version"
  echo ""
  
  # Check requirements
  check_requirements "$method"
  
  # Execute rollback based on method
  if [ "$method" = "traffic" ]; then
    rollback_via_traffic "$project" "$function" "$dry_run"
  elif [ "$method" = "redeploy" ]; then
    rollback_via_redeploy "$project" "$function" "$version" "$dry_run"
  fi
  
  # Record rollback
  record_rollback "$project" "$method" "$function" "$version" "$dry_run"
  
  echo "================================================"
  echo -e "${GREEN}✅ Rollback Complete${NC}"
  echo "================================================"
  echo ""
  echo "Post-rollback actions:"
  echo "  1. Verify rollback in Firebase Console"
  echo "  2. Run smoke tests: scripts/smoke/run.sh"
  echo "  3. Monitor error rates and latency"
  echo "  4. Investigate root cause of the issue"
  echo "  5. Prepare fix for next deployment"
  echo ""
  echo "Monitoring links:"
  echo "  Firebase Console: https://console.firebase.google.com/project/$project"
  echo "  Cloud Functions: https://console.cloud.google.com/functions/list?project=$project"
  echo "  Cloud Run: https://console.cloud.google.com/run?project=$project"
  echo "  Error Reporting: https://console.cloud.google.com/errors?project=$project"
  echo ""
}

# Execute main
main "$@"
