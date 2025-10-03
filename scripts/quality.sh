#!/bin/bash

# Quality Check Script
# Runs dart fix, analyzer, and dead code detection

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
  echo "  --no-metrics     Skip dart_code_metrics checks"
  echo "  --no-unused      Skip unused code detection"
  echo "  --fatal-infos    Treat infos as errors"
  exit 0
}

# Parse arguments
APPLY_FIX=false
SKIP_METRICS=false
SKIP_UNUSED=false
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
    --no-metrics)
      SKIP_METRICS=true
      shift
      ;;
    --no-unused)
      SKIP_UNUSED=true
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
  echo -e "${YELLOW}[1/4] Applying automatic fixes...${NC}"
  dart fix --apply
  echo -e "${GREEN}✅ Auto-fixes applied${NC}"
  echo ""
else
  echo -e "${YELLOW}[1/4] Skipping auto-fixes (use --fix to enable)${NC}"
  echo ""
fi

# Step 2: Run dart analyze
echo -e "${YELLOW}[2/4] Running dart analyze...${NC}"
if dart analyze $FATAL_INFOS; then
  echo -e "${GREEN}✅ No analysis issues found${NC}"
else
  echo -e "${RED}❌ Analysis failed - fix issues above${NC}"
  exit 1
fi
echo ""

# Step 3: Run dart_code_metrics checks (if not skipped)
if [ "$SKIP_METRICS" = false ]; then
  echo -e "${YELLOW}[3/4] Running dart_code_metrics...${NC}"
  
  # Check if dart_code_metrics is available
  if ! command -v dart_code_metrics &> /dev/null && ! dart pub global list | grep -q dart_code_metrics; then
    echo -e "${YELLOW}⚠️  dart_code_metrics not found. Installing...${NC}"
    dart pub global activate dart_code_metrics
  fi
  
  # Run metrics check
  if dart run dart_code_metrics:metrics analyze lib --fatal-style --fatal-performance --fatal-warnings 2>/dev/null || \
     dart pub global run dart_code_metrics:metrics analyze lib --fatal-style --fatal-performance --fatal-warnings 2>/dev/null; then
    echo -e "${GREEN}✅ Metrics checks passed${NC}"
  else
    echo -e "${RED}❌ Metrics checks failed${NC}"
    exit 1
  fi
else
  echo -e "${YELLOW}[3/4] Skipping metrics checks${NC}"
fi
echo ""

# Step 4: Check for unused code (if not skipped)
if [ "$SKIP_UNUSED" = false ]; then
  echo -e "${YELLOW}[4/4] Checking for unused code...${NC}"
  
  # Check if dart_code_metrics is available
  if ! command -v dart_code_metrics &> /dev/null && ! dart pub global list | grep -q dart_code_metrics; then
    echo -e "${YELLOW}⚠️  dart_code_metrics not found. Installing...${NC}"
    dart pub global activate dart_code_metrics
  fi
  
  # Run unused code check
  echo -e "${BLUE}Scanning for unused code...${NC}"
  if dart run dart_code_metrics:metrics check-unused-code lib 2>/dev/null || \
     dart pub global run dart_code_metrics:metrics check-unused-code lib 2>/dev/null; then
    echo -e "${GREEN}✅ No unused code detected${NC}"
  else
    echo -e "${YELLOW}⚠️  Unused code detected - review report above${NC}"
    # Don't fail the build for unused code, just warn
  fi
else
  echo -e "${YELLOW}[4/4] Skipping unused code detection${NC}"
fi
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ Quality checks completed!${NC}"
echo -e "${GREEN}========================================${NC}"
