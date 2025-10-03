#!/bin/bash

# Quality Check Script
# Runs dart format, analyzer, and standard checks

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage function
usage() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  --help           Show this help message"
  echo "  --fix            Apply auto-fixes before analyzing"
  echo "  --fatal-infos    Treat infos as errors"
  exit 0
}

# Parse arguments
APPLY_FIX=false
FATAL_INFOS=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --help)
      usage
      ;;
    --fix)
      APPLY_FIX=true
      shift
      ;;
    --fatal-infos)
      FATAL_INFOS="--fatal-infos"
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      usage
      ;;
  esac
done

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Sierra Painting - Quality Check${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Apply dart fix if requested
if [ "$APPLY_FIX" = true ]; then
  echo -e "${YELLOW}[1/3] Applying automatic fixes...${NC}"
  dart fix --apply
  echo -e "${GREEN}✅ Auto-fixes applied${NC}"
  echo ""
else
  echo -e "${YELLOW}[1/3] Skipping auto-fixes (use --fix to enable)${NC}"
  echo ""
fi

# Step 2: Run dart format check
echo -e "${YELLOW}[2/3] Running format check...${NC}"
if dart format --output=none --set-exit-if-changed .; then
  echo -e "${GREEN}✅ Code is properly formatted${NC}"
else
  echo -e "${RED}❌ Format check failed - run 'dart format .' to fix${NC}"
  exit 1
fi
echo ""

# Step 3: Run dart analyze
echo -e "${YELLOW}[3/3] Running dart analyze...${NC}"
if dart analyze $FATAL_INFOS; then
  echo -e "${GREEN}✅ No analysis issues found${NC}"
else
  echo -e "${RED}❌ Analysis failed - fix issues above${NC}"
  exit 1
fi
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ Quality checks completed!${NC}"
echo -e "${GREEN}========================================${NC}"

