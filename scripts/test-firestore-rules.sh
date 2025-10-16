#!/bin/bash
# Test Firestore Security Rules
# Purpose: Run comprehensive security rules tests with emulator
# Usage: ./test-firestore-rules.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TESTS_DIR="$PROJECT_ROOT/tests/rules"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Firestore Security Rules Tests${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}✗ Node.js not found${NC}"
    echo "Please install Node.js: https://nodejs.org/"
    exit 1
fi

# Install dependencies if needed
if [ ! -d "$TESTS_DIR/node_modules" ]; then
    echo -e "${YELLOW}Installing test dependencies...${NC}"
    cd "$TESTS_DIR"
    npm install
    echo -e "${GREEN}✓ Dependencies installed${NC}"
    echo ""
fi

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}✗ Firebase CLI not found${NC}"
    echo "Please install: npm install -g firebase-tools"
    exit 1
fi

echo -e "${YELLOW}Starting Firestore emulator and running tests...${NC}"
echo ""

# Change to project root
cd "$PROJECT_ROOT"

# Run tests with emulator
firebase emulators:exec \
  --only firestore \
  --project=sierra-painting-test \
  "cd tests/rules && npm test"

RESULT=$?

echo ""
if [ $RESULT -eq 0 ]; then
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  ✓ All Security Tests Passed!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Security verification complete:"
    echo "  ✓ Multi-tenant isolation verified"
    echo "  ✓ RBAC permissions validated"
    echo "  ✓ Field immutability enforced"
    echo "  ✓ Query security confirmed"
    echo ""
    echo "Safe to proceed with deployment!"
else
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}  ✗ Security Tests Failed${NC}"
    echo -e "${RED}========================================${NC}"
    echo ""
    echo "Security issues detected. DO NOT DEPLOY until fixed."
    echo ""
    echo "Review the test output above for details."
    exit 1
fi
