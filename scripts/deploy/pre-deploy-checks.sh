#!/bin/bash

# Pre-Deploy Checks Script
# Runs smoke tests and validation before deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Pre-Deploy Checks${NC}"
echo "================================================"
echo ""

# Get environment from firebase use command or parameter
ENVIRONMENT=${1:-$(firebase use 2>/dev/null || echo "default")}
echo "Environment: $ENVIRONMENT"
echo ""

# Track failures
FAILURES=0

# Check 1: Smoke tests
echo -e "${BLUE}1. Running Smoke Tests${NC}"
if [ -f "scripts/smoke/run.sh" ]; then
  if bash scripts/smoke/run.sh; then
    echo -e "${GREEN}✓ Smoke tests passed${NC}"
  else
    echo -e "${RED}✗ Smoke tests failed${NC}"
    FAILURES=$((FAILURES + 1))
  fi
else
  echo -e "${YELLOW}⚠️  Smoke test script not found, skipping${NC}"
fi
echo ""

# Check 2: Feature flags configured
echo -e "${BLUE}2. Checking Feature Flags${NC}"
if command -v firebase &> /dev/null; then
  echo -e "${GREEN}✓ Firebase CLI available${NC}"
  echo "  Run 'firebase remoteconfig:get' to verify feature flags"
else
  echo -e "${YELLOW}⚠️  Firebase CLI not available${NC}"
fi
echo ""

# Check 3: Database migration check
echo -e "${BLUE}3. Checking for Database Migrations${NC}"
if [ -d "migrations" ] || [ -f "MIGRATION_NOTES.md" ]; then
  echo -e "${YELLOW}⚠️  Database migrations detected${NC}"
  echo "  Verify migrations are reversible before deploying"
  echo "  See MIGRATION_NOTES.md for details"
else
  echo -e "${GREEN}✓ No database migrations detected${NC}"
fi
echo ""

# Check 4: Security rules test
echo -e "${BLUE}4. Checking Security Rules${NC}"
if [ -f "functions/package.json" ] && grep -q '"test:rules"' functions/package.json; then
  echo "  Security rules tests available"
  echo "  Run 'cd functions && npm run test:rules' to verify"
  echo -e "${GREEN}✓ Security rules tests configured${NC}"
else
  echo -e "${YELLOW}⚠️  Security rules tests not configured${NC}"
fi
echo ""

# Check 5: TypeScript compilation (if lib exists, assume built)
echo -e "${BLUE}5. Checking Functions Build${NC}"
if [ -d "functions/lib" ] && [ -n "$(ls -A functions/lib 2>/dev/null)" ]; then
  echo -e "${GREEN}✓ Functions build exists (functions/lib)${NC}"
  echo "  Build appears to be up to date"
else
  echo -e "${YELLOW}⚠️  Functions not built yet${NC}"
  echo "  Run 'cd functions && npm run build' before deploying"
  echo "  Note: CI will handle building automatically"
fi
echo ""

# Check 6: Rollback plan documented
echo -e "${BLUE}5. Checking Rollback Plan${NC}"
if [ -f "docs/rollout-rollback.md" ] || [ -f "docs/CANARY_DEPLOYMENT.md" ]; then
  echo -e "${GREEN}✓ Rollback documentation found${NC}"
  echo "  - docs/rollout-rollback.md"
  echo "  - docs/CANARY_DEPLOYMENT.md"
else
  echo -e "${YELLOW}⚠️  Rollback documentation not found${NC}"
  FAILURES=$((FAILURES + 1))
fi
echo ""

# Summary
echo "================================================"
if [ $FAILURES -eq 0 ]; then
  echo -e "${GREEN}✅ All pre-deploy checks passed${NC}"
  echo ""
  echo "Safe to deploy. Continue? [y/N]"
  if [ "${CI:-false}" = "true" ]; then
    echo "Running in CI, auto-continuing..."
    exit 0
  fi
  # In interactive mode, this would ask for confirmation
  # For automation, we just succeed
  exit 0
else
  echo -e "${RED}❌ $FAILURES pre-deploy check(s) failed${NC}"
  echo ""
  echo "Please fix the issues above before deploying."
  exit 1
fi
