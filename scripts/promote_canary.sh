#!/bin/bash

# Promote Canary Deployment (10% → 50% → 100%)
# Progressively increases traffic to the new revision after validation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
  echo -e "${BLUE}Promote Canary Deployment${NC}"
  echo "================================================"
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --project <project-id>   Firebase project ID (required)"
  echo "  --stage <percentage>     Target traffic percentage: 50 or 100 (required)"
  echo "  --function <name>        Promote specific function only (optional)"
  echo "  --skip-checks            Skip smoke test validation (not recommended)"
  echo "  --dry-run               Show what would be done without executing"
  echo "  --help                   Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --project sierra-painting-prod --stage 50"
  echo "  $0 --project sierra-painting-prod --stage 100"
  echo "  $0 --project sierra-painting-prod --stage 50 --function clockIn"
  echo ""
}

# Check required tools
check_requirements() {
  local missing_tools=()
  
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
    echo "  gcloud: https://cloud.google.com/sdk/docs/install"
    exit 1
  fi
}

# Run smoke tests
run_smoke_tests() {
  local project=$1
  local skip_checks=$2
  local dry_run=$3
  
  if [ "$skip_checks" = "true" ]; then
    echo -e "${YELLOW}⚠️  Skipping smoke tests (--skip-checks)${NC}"
    echo ""
    return 0
  fi
  
  echo -e "${BLUE}🧪 Running Smoke Tests${NC}"
  echo "================================================"
  echo ""
  
  if [ "$dry_run" = "true" ]; then
    echo -e "${YELLOW}[DRY RUN]${NC} Would run smoke tests"
    return 0
  fi
  
  # Check if smoke test script exists
  if [ ! -f "scripts/smoke/run.sh" ]; then
    echo -e "${YELLOW}⚠️  Smoke test script not found${NC}"
    echo "Continuing without smoke tests..."
    return 0
  fi
  
  # Run smoke tests
  if bash scripts/smoke/run.sh; then
    echo -e "${GREEN}✅ Smoke tests passed${NC}"
    echo ""
  else
    echo -e "${RED}❌ Smoke tests failed${NC}"
    echo ""
    echo "Promotion cancelled. Fix issues before promoting."
    exit 1
  fi
}

# Check metrics/health
check_health_metrics() {
  local project=$1
  local dry_run=$2
  
  echo -e "${BLUE}📊 Checking Health Metrics${NC}"
  echo "================================================"
  echo ""
  
  if [ "$dry_run" = "true" ]; then
    echo -e "${YELLOW}[DRY RUN]${NC} Would check health metrics"
    return 0
  fi
  
  echo "Metrics to monitor:"
  echo "  ✓ Error rate < 2%"
  echo "  ✓ P95 latency < 1s"
  echo "  ✓ No critical errors"
  echo ""
  
  echo -e "${YELLOW}⚠️  Manual metric verification required${NC}"
  echo ""
  echo "Check the following dashboards:"
  echo "  - Firebase Console: https://console.firebase.google.com/project/$project/functions"
  echo "  - Cloud Monitoring: https://console.cloud.google.com/monitoring?project=$project"
  echo "  - Error Reporting: https://console.cloud.google.com/errors?project=$project"
  echo ""
  
  # Prompt for confirmation
  read -p "Have you verified metrics are healthy? (y/N): " confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Promotion cancelled"
    exit 0
  fi
  
  echo -e "${GREEN}✅ Health check confirmed${NC}"
  echo ""
}

# Update traffic split
update_traffic_split() {
  local project=$1
  local function=$2
  local stage=$3
  local dry_run=$4
  
  echo -e "${BLUE}⚖️  Updating Traffic Split to ${stage}%${NC}"
  echo "================================================"
  echo ""
  
  if [ "$dry_run" = "true" ]; then
    echo -e "${YELLOW}[DRY RUN]${NC} Would update traffic split:"
    echo "  Project: $project"
    echo "  Function: ${function:-all}"
    echo "  Traffic: LATEST=${stage}%"
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
    # Update traffic for specific function
    if echo "$services" | grep -q "^$function\$"; then
      echo "Updating traffic for: $function"
      gcloud run services update-traffic "$function" \
        --to-revisions=LATEST="$stage" \
        --project="$project" \
        --platform=managed \
  --region=us-east4
    --region=us-east4
      echo -e "${GREEN}✅ Traffic updated for $function: ${stage}%${NC}"
    else
      echo -e "${YELLOW}⚠️  Service '$function' not found in Cloud Run${NC}"
    fi
  else
    # Update traffic for all services
    echo "$services" | while IFS= read -r svc; do
      if [ -n "$svc" ]; then
        echo "Updating traffic for: $svc"
        gcloud run services update-traffic "$svc" \
          --to-revisions=LATEST="$stage" \
          --project="$project" \
          --platform=managed \
          --region=us-east4 2>/dev/null || {
            --region=us-east4 2>/dev/null || {
            echo -e "${YELLOW}⚠️  Could not update traffic for $svc${NC}"
          }
      fi
    done
    echo -e "${GREEN}✅ Traffic updated for all services: ${stage}%${NC}"
  fi
  
  echo ""
}

# Record promotion
record_promotion() {
  local project=$1
  local stage=$2
  local function=$3
  local dry_run=$4
  
  echo -e "${BLUE}📝 Recording Promotion${NC}"
  echo "================================================"
  echo ""
  
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local promotion_id="promote-${stage}-${timestamp}"
  
  if [ "$dry_run" = "true" ]; then
    echo -e "${YELLOW}[DRY RUN]${NC} Would record promotion:"
    echo "  Project: $project"
    echo "  Stage: ${stage}%"
    echo "  Function: ${function:-all}"
    echo "  Timestamp: $timestamp"
    return 0
  fi
  
  # Create promotion record file
  mkdir -p .deployment-history
  local record_file=".deployment-history/${promotion_id}.json"
  
  cat > "$record_file" <<EOF
{
  "promotionId": "$promotion_id",
  "timestamp": "$timestamp",
  "project": "$project",
  "stage": "$stage",
  "function": "${function:-all}",
  "gitCommit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
  "promotedBy": "${USER:-unknown}"
}
EOF
  
  echo "Promotion record saved: $record_file"
  echo ""
  echo -e "${GREEN}✅ Promotion recorded${NC}"
  echo ""
}

# Main promotion flow
main() {
  local project=""
  local stage=""
  local function=""
  local skip_checks="false"
  local dry_run="false"
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --project)
        project="$2"
        shift 2
        ;;
      --stage)
        stage="$2"
        shift 2
        ;;
      --function)
        function="$2"
        shift 2
        ;;
      --skip-checks)
        skip_checks="true"
        shift
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
  
  if [ -z "$stage" ]; then
    echo -e "${RED}❌ Error: --stage is required${NC}"
    usage
    exit 1
  fi
  
  # Validate stage value
  if [ "$stage" != "50" ] && [ "$stage" != "100" ]; then
    echo -e "${RED}❌ Error: --stage must be 50 or 100${NC}"
    usage
    exit 1
  fi
  
  echo -e "${BLUE}🎯 Promoting Canary to ${stage}%${NC}"
  echo "================================================"
  echo ""
  echo "Project: $project"
  echo "Target: ${stage}% traffic"
  [ -n "$function" ] && echo "Function: $function"
  echo ""
  
  # Check requirements
  check_requirements
  
  # Run smoke tests (unless skipped)
  run_smoke_tests "$project" "$skip_checks" "$dry_run"
  
  # Check health metrics
  check_health_metrics "$project" "$dry_run"
  
  # Update traffic split
  update_traffic_split "$project" "$function" "$stage" "$dry_run"
  
  # Record promotion
  record_promotion "$project" "$stage" "$function" "$dry_run"
  
  echo "================================================"
  echo -e "${GREEN}✅ Promotion Complete${NC}"
  echo "================================================"
  echo ""
  
  if [ "$stage" = "50" ]; then
    echo "Next steps:"
    echo "  1. Monitor metrics for 6-24 hours"
    echo "  2. Check error rates and user feedback"
    echo "  3. Promote to 100%: scripts/promote_canary.sh --project $project --stage 100"
    echo "  4. Or rollback: scripts/rollback.sh --project $project"
  else
    echo "Deployment complete! Current traffic: 100%"
    echo ""
    echo "Post-deployment tasks:"
    echo "  1. Continue monitoring for 24-48 hours"
    echo "  2. Update documentation"
    echo "  3. Notify team of successful rollout"
  fi
  
  echo ""
  echo "Monitoring links:"
  echo "  Firebase Console: https://console.firebase.google.com/project/$project"
  echo "  Cloud Functions: https://console.cloud.google.com/functions/list?project=$project"
  echo "  Cloud Run: https://console.cloud.google.com/run?project=$project"
  echo ""
}

# Execute main
main "$@"
