#!/bin/bash
# Quick smoke test runner for local development
# Runs both mobile and backend smoke tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}🧪 Running Local Smoke Tests${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

MOBILE_STATUS=0
BACKEND_STATUS=0

# Run mobile smoke tests
echo -e "${YELLOW}▶ Running Mobile Smoke Tests...${NC}"
echo ""
if flutter test integration_test/app_smoke_test.dart; then
  echo ""
  echo -e "${GREEN}✅ Mobile smoke tests passed${NC}"
  MOBILE_STATUS=0
else
  echo ""
  echo -e "${RED}❌ Mobile smoke tests failed${NC}"
  MOBILE_STATUS=1
fi

echo ""
echo -e "${BLUE}================================================${NC}"
echo ""

# Run backend smoke tests
echo -e "${YELLOW}▶ Running Backend Smoke Tests...${NC}"
echo ""
cd functions
if npm test -- test/smoke/; then
  echo ""
  echo -e "${GREEN}✅ Backend smoke tests passed${NC}"
  BACKEND_STATUS=0
else
  echo ""
  echo -e "${RED}❌ Backend smoke tests failed${NC}"
  BACKEND_STATUS=1
fi
cd ..

echo ""
echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}📊 Smoke Test Summary${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

if [ $MOBILE_STATUS -eq 0 ] && [ $BACKEND_STATUS -eq 0 ]; then
  echo -e "${GREEN}✅ All smoke tests passed!${NC}"
  echo -e "${GREEN}Safe to proceed with deployment${NC}"
  exit 0
else
  echo -e "${RED}❌ Smoke tests failed!${NC}"
  [ $MOBILE_STATUS -ne 0 ] && echo -e "${RED}  - Mobile tests failed${NC}"
  [ $BACKEND_STATUS -ne 0 ] && echo -e "${RED}  - Backend tests failed${NC}"
  echo ""
  echo -e "${YELLOW}Fix the issues before deploying${NC}"
  exit 1
fi
