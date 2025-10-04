#!/bin/bash

# Stabilization Compliance Validator
# Validates project against standards defined in .copilot/stabilize_sierra_painting.yaml

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Results storage
RESULTS=()

# Function to run a check
check() {
  local name="$1"
  local status="$2"
  local message="$3"
  
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  
  if [ "$status" = "PASS" ]; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    echo -e "${GREEN}✓${NC} $name"
    RESULTS+=("PASS: $name")
  elif [ "$status" = "FAIL" ]; then
    FAILED_CHECKS=$((FAILED_CHECKS + 1))
    echo -e "${RED}✗${NC} $name"
    if [ -n "$message" ]; then
      echo -e "  ${RED}→${NC} $message"
    fi
    RESULTS+=("FAIL: $name - $message")
  elif [ "$status" = "WARN" ]; then
    WARNING_CHECKS=$((WARNING_CHECKS + 1))
    echo -e "${YELLOW}⚠${NC} $name"
    if [ -n "$message" ]; then
      echo -e "  ${YELLOW}→${NC} $message"
    fi
    RESULTS+=("WARN: $name - $message")
  fi
}

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Stabilization Compliance Validator${NC}"
echo -e "${BLUE}  Based on: .copilot/stabilize_sierra_painting.yaml${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ============================================================================
# 1. CI/CD WORKFLOW STANDARDS
# ============================================================================
echo -e "${BLUE}[1/8] CI/CD Workflow Standards${NC}"
echo ""

# Check required workflows exist
required_workflows=(
  ".github/workflows/ci.yml"
  ".github/workflows/code_quality.yml"
  ".github/workflows/smoke_tests.yml"
  ".github/workflows/staging.yml"
  ".github/workflows/production.yml"
)

for workflow in "${required_workflows[@]}"; do
  if [ -f "$workflow" ]; then
    check "Required workflow exists: $workflow" "PASS"
  else
    check "Required workflow exists: $workflow" "FAIL" "Workflow file not found"
  fi
done

# Check action versions are pinned
echo ""
echo -e "${BLUE}[2/8] Action Version Pinning${NC}"
echo ""

pinned_actions=(
  "actions/checkout@v4"
  "actions/cache@v4"
  "actions/upload-artifact@v4"
  "actions/download-artifact@v4"
  "subosito/flutter-action@v2"
  "actions/setup-node@v4"
  "actions/setup-java@v4"
)

for action in "${pinned_actions[@]}"; do
  action_name="${action%@*}"
  expected_version="${action#*@}"
  
  # Search in all workflow files
  found=false
  has_correct_version=false
  has_incorrect_version=false
  
  for workflow in .github/workflows/*.yml; do
    if [ -f "$workflow" ]; then
      # Check if action is used with correct version
      if grep -q "uses: $action" "$workflow" || grep -q "- uses: $action" "$workflow"; then
        found=true
        has_correct_version=true
      fi
      # Check if action is used with wrong version
      if grep -q "uses: $action_name@" "$workflow" && ! grep -q "uses: $action" "$workflow"; then
        if grep -q "- uses: $action_name@" "$workflow" && ! grep -q "- uses: $action" "$workflow"; then
          has_incorrect_version=true
        fi
      fi
    fi
  done
  
  if $has_correct_version; then
    check "Action version pinned: $action" "PASS"
  elif $found || $has_incorrect_version; then
    check "Action version pinned: $action" "WARN" "Action used but version may differ from $expected_version"
  else
    check "Action version pinned: $action" "WARN" "Action not found in workflows"
  fi
done

# ============================================================================
# 2. DEPENDENCY MANAGEMENT
# ============================================================================
echo ""
echo -e "${BLUE}[3/8] Dependency Management${NC}"
echo ""

# Check pubspec.lock exists
if [ -f "pubspec.lock" ]; then
  check "pubspec.lock committed" "PASS"
else
  check "pubspec.lock committed" "FAIL" "pubspec.lock should be committed for deterministic builds"
fi

# Check package-lock.json in functions/
if [ -f "functions/package-lock.json" ]; then
  check "functions/package-lock.json committed" "PASS"
else
  check "functions/package-lock.json committed" "FAIL" "package-lock.json should be committed"
fi

# Check for Firebase package versions in pubspec.yaml
if [ -f "pubspec.yaml" ]; then
  critical_packages=(
    "firebase_core"
    "firebase_auth"
    "firebase_storage"
    "cloud_firestore"
    "cloud_functions"
  )
  
  for package in "${critical_packages[@]}"; do
    if grep -q "^  $package:" pubspec.yaml; then
      check "Critical package declared: $package" "PASS"
    else
      check "Critical package declared: $package" "WARN" "Package not found in pubspec.yaml"
    fi
  done
fi

# Check Node.js version in functions/package.json
if [ -f "functions/package.json" ]; then
  if grep -q '"node".*">=18' functions/package.json; then
    check "Node.js runtime pinned (>=18 <21)" "PASS"
  else
    check "Node.js runtime pinned (>=18 <21)" "WARN" "Node.js version constraint should be >=18 <21"
  fi
fi

# ============================================================================
# 3. BUILD STABILITY
# ============================================================================
echo ""
echo -e "${BLUE}[4/8] Build Stability${NC}"
echo ""

# Check for caching in workflows
cache_found=false
for workflow in .github/workflows/ci.yml .github/workflows/flutter_ci.yml; do
  if [ -f "$workflow" ]; then
    if grep -q "actions/cache@v" "$workflow"; then
      cache_found=true
      break
    fi
  fi
done

if $cache_found; then
  check "Caching strategy implemented" "PASS"
else
  check "Caching strategy implemented" "WARN" "No cache actions found in CI workflows"
fi

# Check for Flutter stable channel
flutter_stable=false
for workflow in .github/workflows/*.yml; do
  if [ -f "$workflow" ]; then
    if grep -q "channel.*stable" "$workflow" || grep -q "flutter-version.*stable" "$workflow"; then
      flutter_stable=true
      break
    fi
  fi
done

if $flutter_stable; then
  check "Flutter stable channel specified" "PASS"
else
  check "Flutter stable channel specified" "WARN" "Flutter channel should be set to stable"
fi

# ============================================================================
# 4. TESTING INFRASTRUCTURE
# ============================================================================
echo ""
echo -e "${BLUE}[5/8] Testing Infrastructure${NC}"
echo ""

# Check test directories exist
test_locations=(
  "test"
  "integration_test"
  "firestore-tests"
  "functions/test"
)

for location in "${test_locations[@]}"; do
  if [ -d "$location" ]; then
    check "Test directory exists: $location" "PASS"
  else
    check "Test directory exists: $location" "WARN" "Directory not found: $location"
  fi
done

# Check smoke test exists
if [ -f "integration_test/app_boot_smoke_test.dart" ]; then
  check "Smoke test exists" "PASS"
else
  check "Smoke test exists" "WARN" "integration_test/app_boot_smoke_test.dart not found"
fi

# ============================================================================
# 5. DEPLOYMENT STABILITY
# ============================================================================
echo ""
echo -e "${BLUE}[6/8] Deployment Stability${NC}"
echo ""

# Check deployment scripts exist
deployment_scripts=(
  "scripts/deploy_canary.sh"
  "scripts/promote_canary.sh"
  "scripts/rollback.sh"
)

for script in "${deployment_scripts[@]}"; do
  if [ -f "$script" ] && [ -x "$script" ]; then
    check "Deployment script exists and executable: $script" "PASS"
  elif [ -f "$script" ]; then
    check "Deployment script exists and executable: $script" "WARN" "Script exists but not executable"
  else
    check "Deployment script exists and executable: $script" "FAIL" "Script not found"
  fi
done

# Check for staging and production workflows
if [ -f ".github/workflows/staging.yml" ]; then
  check "Staging deployment workflow exists" "PASS"
else
  check "Staging deployment workflow exists" "FAIL" "Missing staging.yml workflow"
fi

if [ -f ".github/workflows/production.yml" ]; then
  check "Production deployment workflow exists" "PASS"
else
  check "Production deployment workflow exists" "FAIL" "Missing production.yml workflow"
fi

# ============================================================================
# 6. TIMEOUT POLICIES
# ============================================================================
echo ""
echo -e "${BLUE}[7/8] Timeout Policies${NC}"
echo ""

# Check for timeout configurations in workflows
timeout_found=false
for workflow in .github/workflows/*.yml; do
  if [ -f "$workflow" ]; then
    if grep -q "timeout-minutes:" "$workflow"; then
      timeout_found=true
      break
    fi
  fi
done

if $timeout_found; then
  check "Job timeouts configured" "PASS"
else
  check "Job timeouts configured" "WARN" "Consider adding timeout-minutes to workflow jobs"
fi

# ============================================================================
# 7. SECURITY AND QUALITY GATES
# ============================================================================
echo ""
echo -e "${BLUE}[8/8] Security and Quality Gates${NC}"
echo ""

# Check for security workflow
if [ -f ".github/workflows/security.yml" ] || [ -f ".github/workflows/secrets_check.yml" ]; then
  check "Security scanning workflow exists" "PASS"
else
  check "Security scanning workflow exists" "WARN" "No security workflow found"
fi

# Check for analysis_options.yaml
if [ -f "analysis_options.yaml" ]; then
  check "Dart analysis options configured" "PASS"
else
  check "Dart analysis options configured" "FAIL" "analysis_options.yaml not found"
fi

# Check for Firestore rules and tests
if [ -f "firestore.rules" ]; then
  check "Firestore security rules exist" "PASS"
else
  check "Firestore security rules exist" "FAIL" "firestore.rules not found"
fi

if [ -f ".github/workflows/firestore_rules.yml" ]; then
  check "Firestore rules testing workflow exists" "PASS"
else
  check "Firestore rules testing workflow exists" "WARN" "No firestore_rules workflow found"
fi

# Check for Firebase configuration
if [ -f "firebase.json" ]; then
  check "Firebase configuration exists" "PASS"
else
  check "Firebase configuration exists" "FAIL" "firebase.json not found"
fi

# ============================================================================
# SUMMARY
# ============================================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Total checks:   $TOTAL_CHECKS"
echo -e "${GREEN}Passed:${NC}         $PASSED_CHECKS"
echo -e "${YELLOW}Warnings:${NC}       $WARNING_CHECKS"
echo -e "${RED}Failed:${NC}         $FAILED_CHECKS"
echo ""

# Calculate compliance percentage
if [ $TOTAL_CHECKS -gt 0 ]; then
  compliance=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
  echo -e "Compliance:     ${compliance}%"
  echo ""
  
  if [ $compliance -ge 90 ]; then
    echo -e "${GREEN}✓ Excellent compliance with stabilization standards${NC}"
  elif [ $compliance -ge 75 ]; then
    echo -e "${YELLOW}⚠ Good compliance, but some improvements needed${NC}"
  elif [ $compliance -ge 50 ]; then
    echo -e "${YELLOW}⚠ Moderate compliance, several improvements needed${NC}"
  else
    echo -e "${RED}✗ Low compliance, significant improvements required${NC}"
  fi
fi

echo ""
echo -e "${BLUE}For detailed requirements, see:${NC}"
echo "  .copilot/stabilize_sierra_painting.yaml"
echo ""

# Exit with error if there are critical failures
if [ $FAILED_CHECKS -gt 0 ]; then
  exit 1
else
  exit 0
fi
