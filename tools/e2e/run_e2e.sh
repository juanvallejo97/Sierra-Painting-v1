#!/bin/bash
###############################################################################
# E2E Test Runner (Linux/macOS)
#
# PURPOSE:
# Automates the complete E2E demo test flow with Firebase emulators.
#
# USAGE:
# ./tools/e2e/run_e2e.sh
#
# WHAT IT DOES:
# 1. Builds Cloud Functions (TypeScript → JavaScript)
# 2. Starts Firebase emulators in background
# 3. Waits for emulators to be ready
# 4. Runs E2E integration test
# 5. Stops emulators
# 6. Reports results
#
# REQUIREMENTS:
# - Node.js and npm installed
# - Firebase CLI installed (npm install -g firebase-tools)
# - Flutter SDK installed
# - Firebase emulators configured (firebase.json)
#
# ACCEPTANCE CRITERIA:
# - One command runs full demo path in <8 minutes
# - Emulators start/stop automatically
# - Clear pass/fail reporting
###############################################################################

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo ""
echo "========================================="
echo "🧪 E2E Demo Test Runner"
echo "========================================="
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Firebase CLI not found${NC}"
    echo "Install with: npm install -g firebase-tools"
    exit 1
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter not found${NC}"
    echo "Install Flutter: https://flutter.dev/docs/get-started/install"
    exit 1
fi

# Step 1: Build Cloud Functions
echo -e "${YELLOW}📦 Step 1: Building Cloud Functions...${NC}"
npm --prefix functions run build

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Functions build failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Functions built${NC}"
echo ""

# Step 2: Start Firebase Emulators
echo -e "${YELLOW}🔥 Step 2: Starting Firebase emulators...${NC}"

# Kill any existing emulator processes
pkill -f "firebase.*emulators" || true
sleep 2

# Start emulators in background
firebase emulators:start --only firestore,functions,auth > emulator.log 2>&1 &
EMULATOR_PID=$!

echo "Emulator PID: $EMULATOR_PID"

# Wait for emulators to be ready (check UI endpoint)
echo -e "${YELLOW}⏳ Waiting for emulators to start...${NC}"
RETRY_COUNT=0
MAX_RETRIES=30

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -s http://localhost:8080 > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Emulators ready${NC}"
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "  Attempt $RETRY_COUNT/$MAX_RETRIES..."
    sleep 2
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo -e "${RED}❌ Emulators failed to start${NC}"
    echo "Check emulator.log for details"
    kill $EMULATOR_PID 2>/dev/null || true
    exit 1
fi

echo ""

# Step 3: Run E2E Test
echo -e "${YELLOW}🧪 Step 3: Running E2E test...${NC}"
echo ""

START_TIME=$(date +%s)

# Run the integration test
flutter test integration_test/e2e_demo_test.dart \
    --dart-define=USE_EMULATORS=true \
    --dart-define=FLUTTER_TEST=true \
    --concurrency=1

TEST_EXIT_CODE=$?

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""

# Step 4: Stop Emulators
echo -e "${YELLOW}🛑 Step 4: Stopping emulators...${NC}"
kill $EMULATOR_PID 2>/dev/null || true
sleep 2

# Cleanup
rm -f emulator.log

# Step 5: Report Results
echo ""
echo "========================================="
if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ E2E Test PASSED${NC}"
    echo "Duration: ${DURATION}s"
    echo "Acceptance: <480s (8 min)"

    if [ $DURATION -lt 480 ]; then
        echo -e "${GREEN}✓ Within SLO${NC}"
    else
        echo -e "${YELLOW}⚠ Exceeded SLO${NC}"
    fi
else
    echo -e "${RED}❌ E2E Test FAILED${NC}"
    echo "Duration: ${DURATION}s"
    echo ""
    echo "Check test output above for details"
fi
echo "========================================="
echo ""

exit $TEST_EXIT_CODE
