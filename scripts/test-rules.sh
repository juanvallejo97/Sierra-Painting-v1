#!/bin/bash
# Script to run Firestore rules tests locally
# This script starts the Firebase emulator and runs the rules tests

set -e

echo "🔥 Starting Firebase Firestore Emulator..."

# Check if firebase-tools is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Installing locally..."
    npm install -g firebase-tools@13.23.1
fi

# Start emulator in background
firebase emulators:start --only firestore --project sierra-painting-test &
EMULATOR_PID=$!

# Function to cleanup emulator on exit
cleanup() {
    echo ""
    echo "🛑 Stopping Firebase emulator..."
    kill $EMULATOR_PID 2>/dev/null || true
    pkill -f "firebase.*emulator" 2>/dev/null || true
}

# Register cleanup function
trap cleanup EXIT INT TERM

# Wait for emulator to be ready
echo "⏳ Waiting for Firestore emulator to start..."
for i in {1..30}; do
    if curl -s http://localhost:8080 > /dev/null 2>&1; then
        echo "✅ Firestore emulator is ready!"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Firestore emulator failed to start within 30 seconds"
        exit 1
    fi
    sleep 1
done

# Run tests
echo ""
echo "🧪 Running Firestore rules tests..."
cd functions
npm run test:rules

echo ""
echo "✅ All tests completed!"
