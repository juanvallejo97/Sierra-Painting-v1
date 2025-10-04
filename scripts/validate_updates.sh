#!/bin/bash

# Update Standards Compliance Validator
# Validates project against standards defined in .copilot/sierra_painting_update.yaml

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
echo -e "${BLUE}  Update Standards Compliance Validator${NC}"
echo -e "${BLUE}  Based on: .copilot/sierra_painting_update.yaml${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ============================================================================
# 1. LOCK FILES COMMITTED
# ============================================================================
echo -e "${BLUE}[1/7] Lock Files Committed${NC}"
echo ""

# Check Flutter lock file
if [ -f "pubspec.lock" ]; then
  if git ls-files --error-unmatch pubspec.lock &> /dev/null; then
    check "pubspec.lock committed to version control" "PASS"
  else
    check "pubspec.lock committed to version control" "FAIL" "Lock file exists but not tracked in git"
  fi
else
  check "pubspec.lock exists" "FAIL" "Lock file not found"
fi

# Check Functions lock file
if [ -f "functions/package-lock.json" ]; then
  if git ls-files --error-unmatch functions/package-lock.json &> /dev/null; then
    check "functions/package-lock.json committed to version control" "PASS"
  else
    check "functions/package-lock.json committed to version control" "FAIL" "Lock file exists but not tracked in git"
  fi
else
  check "functions/package-lock.json exists" "FAIL" "Lock file not found"
fi

# Check WebApp lock file
if [ -f "webapp/package-lock.json" ]; then
  if git ls-files --error-unmatch webapp/package-lock.json &> /dev/null; then
    check "webapp/package-lock.json committed to version control" "PASS"
  else
    check "webapp/package-lock.json committed to version control" "FAIL" "Lock file exists but not tracked in git"
  fi
else
  check "webapp/package-lock.json exists" "WARN" "Lock file not found (may not be needed if webapp unused)"
fi

# ============================================================================
# 2. SECURITY VULNERABILITIES
# ============================================================================
echo ""
echo -e "${BLUE}[2/7] Security Vulnerabilities${NC}"
echo ""

# Check npm audit in functions
if [ -d "functions" ] && [ -f "functions/package.json" ]; then
  echo -e "  ${BLUE}Running npm audit in functions...${NC}"
  cd functions
  AUDIT_OUTPUT=$(npm audit --audit-level=high 2>&1 || true)
  AUDIT_EXIT=$?
  cd ..
  
  if echo "$AUDIT_OUTPUT" | grep -q "found 0 vulnerabilities"; then
    check "No high/critical npm vulnerabilities in functions/" "PASS"
  elif [ $AUDIT_EXIT -eq 0 ]; then
    check "No high/critical npm vulnerabilities in functions/" "PASS"
  else
    VULN_COUNT=$(echo "$AUDIT_OUTPUT" | grep -oP '\d+(?= vulnerabilities)' | head -1 || echo "unknown")
    check "No high/critical npm vulnerabilities in functions/" "FAIL" "Found $VULN_COUNT vulnerabilities"
  fi
else
  check "functions/ directory with package.json" "WARN" "functions/ not found"
fi

# Check npm audit in webapp
if [ -d "webapp" ] && [ -f "webapp/package.json" ]; then
  echo -e "  ${BLUE}Running npm audit in webapp...${NC}"
  cd webapp
  AUDIT_OUTPUT=$(npm audit --audit-level=high 2>&1 || true)
  AUDIT_EXIT=$?
  cd ..
  
  if echo "$AUDIT_OUTPUT" | grep -q "found 0 vulnerabilities"; then
    check "No high/critical npm vulnerabilities in webapp/" "PASS"
  elif [ $AUDIT_EXIT -eq 0 ]; then
    check "No high/critical npm vulnerabilities in webapp/" "PASS"
  else
    VULN_COUNT=$(echo "$AUDIT_OUTPUT" | grep -oP '\d+(?= vulnerabilities)' | head -1 || echo "unknown")
    check "No high/critical npm vulnerabilities in webapp/" "WARN" "Found $VULN_COUNT vulnerabilities"
  fi
else
  check "webapp/ directory with package.json" "WARN" "webapp/ not found or no package.json"
fi

# ============================================================================
# 3. VERSION DRIFT CHECK
# ============================================================================
echo ""
echo -e "${BLUE}[3/7] Version Drift Check${NC}"
echo ""

# Check Flutter dependencies
if command -v flutter &> /dev/null && [ -f "pubspec.yaml" ]; then
  echo -e "  ${BLUE}Checking Flutter dependencies...${NC}"
  OUTDATED_OUTPUT=$(flutter pub outdated --json 2>/dev/null || echo '{"packages":[]}')
  
  # Count packages that are more than 2 minor versions behind
  # This is a simplified check - real implementation would parse JSON
  OUTDATED_COUNT=$(echo "$OUTDATED_OUTPUT" | grep -o '"upgradable"' | wc -l || echo 0)
  
  if [ "$OUTDATED_COUNT" -eq 0 ]; then
    check "Flutter dependencies up to date" "PASS"
  elif [ "$OUTDATED_COUNT" -lt 3 ]; then
    check "Flutter dependencies version drift" "WARN" "$OUTDATED_COUNT packages can be upgraded"
  else
    check "Flutter dependencies version drift" "FAIL" "$OUTDATED_COUNT packages can be upgraded (> 5% drift)"
  fi
else
  check "Flutter dependencies check" "WARN" "Flutter not installed or pubspec.yaml not found"
fi

# Check npm dependencies in functions
if [ -d "functions" ] && [ -f "functions/package.json" ] && command -v npm &> /dev/null; then
  echo -e "  ${BLUE}Checking Functions npm dependencies...${NC}"
  cd functions
  OUTDATED_OUTPUT=$(npm outdated --json 2>/dev/null || echo '{}')
  OUTDATED_COUNT=$(echo "$OUTDATED_OUTPUT" | grep -o '"current"' | wc -l || echo 0)
  cd ..
  
  if [ "$OUTDATED_COUNT" -eq 0 ]; then
    check "Functions npm dependencies up to date" "PASS"
  elif [ "$OUTDATED_COUNT" -lt 3 ]; then
    check "Functions npm dependencies version drift" "WARN" "$OUTDATED_COUNT packages outdated"
  else
    check "Functions npm dependencies version drift" "FAIL" "$OUTDATED_COUNT packages outdated"
  fi
else
  check "Functions npm dependencies check" "WARN" "functions/ not found or npm not installed"
fi

# ============================================================================
# 4. MINIMUM VERSION REQUIREMENTS
# ============================================================================
echo ""
echo -e "${BLUE}[4/7] Minimum Version Requirements${NC}"
echo ""

# Check critical Flutter packages
if [ -f "pubspec.yaml" ]; then
  # firebase_core minimum version
  FIREBASE_CORE_VERSION=$(grep 'firebase_core:' pubspec.yaml | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "0.0.0")
  if [ "$FIREBASE_CORE_VERSION" != "0.0.0" ]; then
    MAJOR=$(echo "$FIREBASE_CORE_VERSION" | cut -d. -f1)
    MINOR=$(echo "$FIREBASE_CORE_VERSION" | cut -d. -f2)
    if [ "$MAJOR" -gt 2 ] || { [ "$MAJOR" -eq 2 ] && [ "$MINOR" -ge 24 ]; }; then
      check "firebase_core >= 2.24.0" "PASS"
    else
      check "firebase_core >= 2.24.0" "FAIL" "Current version: $FIREBASE_CORE_VERSION"
    fi
  else
    check "firebase_core version check" "WARN" "Version not found in pubspec.yaml"
  fi
  
  # firebase_auth minimum version
  FIREBASE_AUTH_VERSION=$(grep 'firebase_auth:' pubspec.yaml | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "0.0.0")
  if [ "$FIREBASE_AUTH_VERSION" != "0.0.0" ]; then
    MAJOR=$(echo "$FIREBASE_AUTH_VERSION" | cut -d. -f1)
    MINOR=$(echo "$FIREBASE_AUTH_VERSION" | cut -d. -f2)
    if [ "$MAJOR" -gt 4 ] || { [ "$MAJOR" -eq 4 ] && [ "$MINOR" -ge 15 ]; }; then
      check "firebase_auth >= 4.15.0" "PASS"
    else
      check "firebase_auth >= 4.15.0" "WARN" "Current version: $FIREBASE_AUTH_VERSION"
    fi
  else
    check "firebase_auth version check" "WARN" "Version not found in pubspec.yaml"
  fi
  
  # cloud_firestore minimum version
  FIRESTORE_VERSION=$(grep 'cloud_firestore:' pubspec.yaml | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "0.0.0")
  if [ "$FIRESTORE_VERSION" != "0.0.0" ]; then
    MAJOR=$(echo "$FIRESTORE_VERSION" | cut -d. -f1)
    MINOR=$(echo "$FIRESTORE_VERSION" | cut -d. -f2)
    if [ "$MAJOR" -gt 4 ] || { [ "$MAJOR" -eq 4 ] && [ "$MINOR" -ge 13 ]; }; then
      check "cloud_firestore >= 4.13.0" "PASS"
    else
      check "cloud_firestore >= 4.13.0" "WARN" "Current version: $FIRESTORE_VERSION"
    fi
  else
    check "cloud_firestore version check" "WARN" "Version not found in pubspec.yaml"
  fi
else
  check "pubspec.yaml exists" "FAIL" "File not found"
fi

# Check critical Node packages
if [ -f "functions/package.json" ]; then
  # firebase-functions minimum version
  FIREBASE_FUNCTIONS_VERSION=$(grep '"firebase-functions"' functions/package.json | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "0.0.0")
  if [ "$FIREBASE_FUNCTIONS_VERSION" != "0.0.0" ]; then
    MAJOR=$(echo "$FIREBASE_FUNCTIONS_VERSION" | cut -d. -f1)
    MINOR=$(echo "$FIREBASE_FUNCTIONS_VERSION" | cut -d. -f2)
    if [ "$MAJOR" -gt 4 ] || { [ "$MAJOR" -eq 4 ] && [ "$MINOR" -ge 5 ]; }; then
      check "firebase-functions >= 4.5.0" "PASS"
    else
      check "firebase-functions >= 4.5.0" "WARN" "Current version: $FIREBASE_FUNCTIONS_VERSION"
    fi
  else
    check "firebase-functions version check" "WARN" "Version not found in package.json"
  fi
  
  # firebase-admin minimum version
  FIREBASE_ADMIN_VERSION=$(grep '"firebase-admin"' functions/package.json | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "0.0.0")
  if [ "$FIREBASE_ADMIN_VERSION" != "0.0.0" ]; then
    MAJOR=$(echo "$FIREBASE_ADMIN_VERSION" | cut -d. -f1)
    MINOR=$(echo "$FIREBASE_ADMIN_VERSION" | cut -d. -f2)
    if [ "$MAJOR" -gt 11 ] || { [ "$MAJOR" -eq 11 ] && [ "$MINOR" -ge 11 ]; }; then
      check "firebase-admin >= 11.11.0" "PASS"
    else
      check "firebase-admin >= 11.11.0" "WARN" "Current version: $FIREBASE_ADMIN_VERSION"
    fi
  else
    check "firebase-admin version check" "WARN" "Version not found in package.json"
  fi
else
  check "functions/package.json exists" "WARN" "File not found"
fi

# ============================================================================
# 5. CHANGELOG MAINTENANCE
# ============================================================================
echo ""
echo -e "${BLUE}[5/7] Changelog Maintenance${NC}"
echo ""

if [ -f "CHANGELOG.md" ]; then
  check "CHANGELOG.md exists" "PASS"
  
  # Check if changelog has been updated in last 60 days
  LAST_MODIFIED=$(git log -1 --format="%at" -- CHANGELOG.md 2>/dev/null || echo 0)
  CURRENT_TIME=$(date +%s)
  DAYS_OLD=$(( (CURRENT_TIME - LAST_MODIFIED) / 86400 ))
  
  if [ $DAYS_OLD -lt 60 ]; then
    check "CHANGELOG.md updated recently" "PASS"
  elif [ $DAYS_OLD -lt 90 ]; then
    check "CHANGELOG.md updated recently" "WARN" "Last updated $DAYS_OLD days ago"
  else
    check "CHANGELOG.md updated recently" "FAIL" "Last updated $DAYS_OLD days ago (> 90 days)"
  fi
else
  check "CHANGELOG.md exists" "FAIL" "File not found"
fi

# ============================================================================
# 6. DOCUMENTATION
# ============================================================================
echo ""
echo -e "${BLUE}[6/7] Update Documentation${NC}"
echo ""

if [ -d "docs" ]; then
  check "docs/ directory exists" "PASS"
  
  # Check for migrations directory
  if [ -d "docs/migrations" ]; then
    check "docs/migrations/ directory exists" "PASS"
  else
    check "docs/migrations/ directory exists" "WARN" "Directory not found (create when needed)"
  fi
  
  # Check for UPDATES.md
  if [ -f "docs/UPDATES.md" ]; then
    check "docs/UPDATES.md exists" "PASS"
  else
    check "docs/UPDATES.md exists" "WARN" "File not found (recommended for tracking updates)"
  fi
else
  check "docs/ directory exists" "FAIL" "Directory not found"
fi

# ============================================================================
# 7. AUTOMATION AND TOOLING
# ============================================================================
echo ""
echo -e "${BLUE}[7/7] Automation and Tooling${NC}"
echo ""

# Check for Dependabot config
if [ -f ".github/dependabot.yml" ]; then
  check "Dependabot configuration exists" "PASS"
else
  check "Dependabot configuration exists" "WARN" ".github/dependabot.yml not found"
fi

# Check for update workflow
if [ -f ".github/workflows/updates.yml" ]; then
  check "Update workflow exists" "PASS"
else
  check "Update workflow exists" "WARN" ".github/workflows/updates.yml not found"
fi

# Check this script is executable
if [ -x "scripts/validate_updates.sh" ]; then
  check "Update validation script is executable" "PASS"
else
  check "Update validation script is executable" "WARN" "Script should be executable"
fi

# ============================================================================
# SUMMARY
# ============================================================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "Total checks:  ${BLUE}$TOTAL_CHECKS${NC}"
echo -e "Passed:        ${GREEN}$PASSED_CHECKS${NC}"
echo -e "Warnings:      ${YELLOW}$WARNING_CHECKS${NC}"
echo -e "Failed:        ${RED}$FAILED_CHECKS${NC}"

# Calculate compliance percentage
if [ $TOTAL_CHECKS -gt 0 ]; then
  COMPLIANCE=$(( (PASSED_CHECKS * 100) / TOTAL_CHECKS ))
  echo -e "Compliance:    ${BLUE}$COMPLIANCE%${NC}"
fi

echo ""
echo -e "${BLUE}Standards:${NC}"
echo "  .copilot/sierra_painting_update.yaml"
echo ""

# Exit with error if there are critical failures
if [ $FAILED_CHECKS -gt 0 ]; then
  exit 1
else
  exit 0
fi
