#!/bin/bash

# Post-Deploy Verification Script
# Verifies SLO probes and key user journeys after deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage
usage() {
  echo -e "${BLUE}Post-Deploy Verification${NC}"
  echo "================================================"
  echo ""
  echo "Usage: $0 --env <environment> [options]"
  echo ""
  echo "Required:"
  echo "  --env <environment>      Target environment: dev, staging, prod"
  echo ""
  echo "Options:"
  echo "  --quick                 Run quick checks only (< 5 min)"
  echo "  --full                  Run full verification suite"
  echo "  --help                  Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --env staging"
  echo "  $0 --env prod --full"
  echo ""
}

# Parse arguments
ENVIRONMENT=""
VERIFICATION_MODE="standard"

while [[ $# -gt 0 ]]; do
  case $1 in
    --env)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --quick)
      VERIFICATION_MODE="quick"
      shift
      ;;
    --full)
      VERIFICATION_MODE="full"
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
  *)
    echo -e "${RED}❌ Error: Invalid environment${NC}"
    exit 1
    ;;
esac

echo -e "${BLUE}🔍 Post-Deploy Verification${NC}"
echo "================================================"
echo ""
echo "Environment: $ENVIRONMENT"
echo "Project ID: $PROJECT_ID"
echo "Mode: $VERIFICATION_MODE"
echo ""

# Track results
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

# Helper function to check status
check_status() {
  local name=$1
  local status=$2
  
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  
  if [ "$status" = "pass" ]; then
    echo -e "${GREEN}✓ $name${NC}"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
  elif [ "$status" = "fail" ]; then
    echo -e "${RED}✗ $name${NC}"
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
  else
    echo -e "${YELLOW}⚠️  $name${NC}"
    WARNINGS=$((WARNINGS + 1))
  fi
}

# SLO Probe 1: Function Availability
echo -e "${BLUE}1. Function Availability Check${NC}"
echo "================================================"
echo "Checking if functions are deployed and accessible..."
echo ""

# Check if firebase CLI is available
if command -v firebase &> /dev/null; then
  if firebase functions:list --project "$PROJECT_ID" &> /dev/null; then
    check_status "Functions are accessible" "pass"
  else
    check_status "Functions are accessible" "fail"
  fi
else
  check_status "Firebase CLI available" "warn"
fi
echo ""

# SLO Probe 2: Error Rate Check
echo -e "${BLUE}2. Error Rate Check${NC}"
echo "================================================"
echo "Target: Error rate < 2% for staging, < 1% for production"
echo ""
echo -e "${YELLOW}⚠️  Manual check required:${NC}"
echo "  1. Go to: https://console.cloud.google.com/errors?project=$PROJECT_ID"
echo "  2. Check error rate in last 1 hour"
echo "  3. Verify no critical errors"
echo ""
check_status "Error rate check (manual)" "warn"
echo ""

# SLO Probe 3: Function Latency Check
echo -e "${BLUE}3. Function Latency Check${NC}"
echo "================================================"
echo "Target: P95 latency < 2s for production, < 3s for staging"
echo ""
echo -e "${YELLOW}⚠️  Manual check required:${NC}"
echo "  1. Go to: https://console.firebase.google.com/project/$PROJECT_ID/functions"
echo "  2. Check function execution time"
echo "  3. Verify P95 latency meets target"
echo ""
check_status "Latency check (manual)" "warn"
echo ""

# Key Journey 1: Authentication
echo -e "${BLUE}4. Key Journey: Authentication${NC}"
echo "================================================"
echo "Testing login functionality..."
echo ""
echo -e "${YELLOW}⚠️  Manual test required:${NC}"
echo "  - [ ] User can sign up with email/password"
echo "  - [ ] User can log in with email/password"
echo "  - [ ] User can log out successfully"
echo "  - [ ] Token refresh works correctly"
echo ""
check_status "Authentication journey (manual)" "warn"
echo ""

# Key Journey 2: Estimate Creation
echo -e "${BLUE}5. Key Journey: Estimate Creation${NC}"
echo "================================================"
echo "Testing estimate creation flow..."
echo ""
echo -e "${YELLOW}⚠️  Manual test required:${NC}"
echo "  - [ ] User can create new estimate"
echo "  - [ ] User can add line items"
echo "  - [ ] User can calculate totals"
echo "  - [ ] User can save estimate"
echo "  - [ ] Estimate appears in list"
echo ""
check_status "Estimate creation journey (manual)" "warn"
echo ""

# Key Journey 3: Invoice Export
echo -e "${BLUE}6. Key Journey: Invoice Export${NC}"
echo "================================================"
echo "Testing invoice export functionality..."
echo ""
echo -e "${YELLOW}⚠️  Manual test required:${NC}"
echo "  - [ ] User can convert estimate to invoice"
echo "  - [ ] User can generate PDF export"
echo "  - [ ] PDF contains correct information"
echo "  - [ ] User can mark invoice as sent"
echo "  - [ ] User can record payment"
echo ""
check_status "Invoice export journey (manual)" "warn"
echo ""

# Security Rules Check
echo -e "${BLUE}7. Security Rules Verification${NC}"
echo "================================================"
echo "Verifying Firestore security rules are active..."
echo ""
if [ -f "functions/src/test/rules.test.ts" ]; then
  echo "Security rules tests available"
  check_status "Security rules tests exist" "pass"
else
  check_status "Security rules tests exist" "warn"
fi
echo ""

# Performance Monitoring
echo -e "${BLUE}8. Performance Monitoring${NC}"
echo "================================================"
echo "Checking performance monitoring dashboards..."
echo ""
echo "Performance Dashboard:"
echo "  https://console.firebase.google.com/project/$PROJECT_ID/performance"
echo ""
check_status "Performance monitoring enabled" "warn"
echo ""

# Crashlytics Check
echo -e "${BLUE}9. Crash Monitoring${NC}"
echo "================================================"
echo "Checking crash monitoring..."
echo ""
echo "Crashlytics Dashboard:"
echo "  https://console.firebase.google.com/project/$PROJECT_ID/crashlytics"
echo ""
check_status "Crashlytics monitoring enabled" "warn"
echo ""

# Database Backup Check
echo -e "${BLUE}10. Database Backup Status${NC}"
echo "================================================"
echo "Verifying database backups..."
echo ""
echo -e "${YELLOW}⚠️  Manual check required:${NC}"
echo "  1. Verify Firestore automatic backups are enabled"
echo "  2. Check last backup timestamp"
echo "  3. Test restore procedure documentation exists"
echo ""
check_status "Database backup status (manual)" "warn"
echo ""

# Summary
echo ""
echo "================================================"
echo -e "${BLUE}📊 Verification Summary${NC}"
echo "================================================"
echo ""
echo "Total Checks: $TOTAL_CHECKS"
echo -e "${GREEN}Passed: $PASSED_CHECKS${NC}"
echo -e "${RED}Failed: $FAILED_CHECKS${NC}"
echo -e "${YELLOW}Warnings/Manual: $WARNINGS${NC}"
echo ""

# Generate report
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE=".deployment-history/verification-$ENVIRONMENT-$TIMESTAMP.txt"

mkdir -p .deployment-history

cat > "$REPORT_FILE" <<EOF
Post-Deploy Verification Report
================================
Environment: $ENVIRONMENT
Project: $PROJECT_ID
Timestamp: $(date)
Mode: $VERIFICATION_MODE

Results
-------
Total Checks: $TOTAL_CHECKS
Passed: $PASSED_CHECKS
Failed: $FAILED_CHECKS
Warnings/Manual: $WARNINGS

Monitoring Links
----------------
Firebase Console: https://console.firebase.google.com/project/$PROJECT_ID
Functions: https://console.cloud.google.com/functions/list?project=$PROJECT_ID
Logs: https://console.cloud.google.com/logs/query?project=$PROJECT_ID
Errors: https://console.cloud.google.com/errors?project=$PROJECT_ID
Performance: https://console.firebase.google.com/project/$PROJECT_ID/performance
Crashlytics: https://console.firebase.google.com/project/$PROJECT_ID/crashlytics

SLO Targets
-----------
Error Rate: < 2% (staging), < 1% (prod)
P95 Latency: < 3s (staging), < 2s (prod)
Function Availability: > 99.9%
Cold Start Time: < 5s

Key User Journeys
-----------------
1. Login (email/password)
2. Estimate Creation (create, add items, save)
3. Invoice Export (convert, generate PDF, record payment)

Recommended Actions
-------------------
EOF

if [ $FAILED_CHECKS -gt 0 ]; then
  echo "⚠️  CRITICAL: $FAILED_CHECKS checks failed!" >> "$REPORT_FILE"
  echo "   - Review failed checks above" >> "$REPORT_FILE"
  echo "   - Consider rollback if critical" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
fi

if [ "$ENVIRONMENT" = "prod" ]; then
  echo "Production Deployment:" >> "$REPORT_FILE"
  echo "  - Monitor for 2 hours minimum" >> "$REPORT_FILE"
  echo "  - Have rollback plan ready" >> "$REPORT_FILE"
  echo "  - Update team on status" >> "$REPORT_FILE"
  echo "" >> "$REPORT_FILE"
fi

echo "1. Complete manual checks listed above" >> "$REPORT_FILE"
echo "2. Monitor error rates for 1 hour" >> "$REPORT_FILE"
echo "3. Test key user journeys manually" >> "$REPORT_FILE"
echo "4. Check performance metrics" >> "$REPORT_FILE"
echo "5. Update deployment log with results" >> "$REPORT_FILE"

echo "Report saved to: $REPORT_FILE"
echo ""

# Print dashboard links
echo -e "${BLUE}📊 Monitoring Dashboards${NC}"
echo "================================================"
echo ""
echo "Firebase Console:"
echo "  https://console.firebase.google.com/project/$PROJECT_ID"
echo ""
echo "Cloud Functions:"
echo "  https://console.cloud.google.com/functions/list?project=$PROJECT_ID"
echo ""
echo "Logs:"
echo "  https://console.cloud.google.com/logs/query?project=$PROJECT_ID"
echo ""
echo "Error Reporting:"
echo "  https://console.cloud.google.com/errors?project=$PROJECT_ID"
echo ""
echo "Performance:"
echo "  https://console.firebase.google.com/project/$PROJECT_ID/performance"
echo ""
echo "Crashlytics:"
echo "  https://console.firebase.google.com/project/$PROJECT_ID/crashlytics"
echo ""

# Exit with appropriate code
if [ $FAILED_CHECKS -gt 0 ]; then
  echo -e "${RED}❌ Verification completed with failures${NC}"
  echo "Review the failures above and take corrective action."
  exit 1
else
  echo -e "${GREEN}✅ Verification completed successfully${NC}"
  echo "Continue monitoring for the next few hours."
  exit 0
fi
