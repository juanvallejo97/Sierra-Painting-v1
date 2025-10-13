#!/bin/bash
###############################################################################
# Firestore Rules Test Runner (Linux/macOS)
#
# PURPOSE:
# Runs Firestore security rules tests with emulators.
#
# USAGE:
# ./tools/rules/test_rules.sh
#
# WHAT IT DOES:
# 1. Starts Firestore emulator in background
# 2. Waits for emulator to be ready
# 3. Runs rules matrix tests
# 4. Runs timekeeping rules tests
# 5. Stops emulator
# 6. Reports results
#
# ACCEPTANCE:
# - All rules tests pass
# - 100% coverage of security rules
###############################################################################

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo ""
echo "========================================="
echo "🔒 Firestore Rules Tests"
echo "========================================="
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Firebase CLI not found${NC}"
    echo "Install with: npm install -g firebase-tools"
    exit 1
fi

# Step 1: Start Firestore Emulator
echo -e "${YELLOW}🔥 Step 1: Starting Firestore emulator...${NC}"

# Kill any existing emulator processes
pkill -f "firebase.*emulators" || true
sleep 2

# Start emulator in background
firebase emulators:start --only firestore > emulator.log 2>&1 &
EMULATOR_PID=$!

echo "Emulator PID: $EMULATOR_PID"

# Wait for emulator to be ready
echo -e "${YELLOW}⏳ Waiting for emulator to start...${NC}"
RETRY_COUNT=0
MAX_RETRIES=30

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8080 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Emulator ready${NC}"
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "  Attempt $RETRY_COUNT/$MAX_RETRIES..."
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}❌ Emulator failed to start${NC}"
    echo "Check emulator.log for details"
    kill $EMULATOR_PID 2>/dev/null || true
    exit 1
fi

echo ""

# Step 2: Run Rules Tests
echo -e "${YELLOW}🧪 Step 2: Running rules tests...${NC}"
echo ""

cd functions

# Run all rules tests
npm test -- --testPathPattern="rules.*test\.ts" --runInBand

TEST_EXIT_CODE=$?

cd ..

echo ""

# Step 3: Stop Emulator
echo -e "${YELLOW}🛑 Step 3: Stopping emulator...${NC}"
kill $EMULATOR_PID 2>/dev/null || true
sleep 2

# Cleanup
rm -f emulator.log

# Step 4: Report Results
echo ""
echo "========================================="
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ All Rules Tests PASSED${NC}"
else
    echo -e "${RED}❌ Some Rules Tests FAILED${NC}"
    echo ""
    echo "Check test output above for details"
fi
echo "========================================="
echo ""

exit $TEST_EXIT_CODE
