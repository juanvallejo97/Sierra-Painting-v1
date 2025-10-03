#!/bin/bash
# Measure app startup performance
# Usage: ./scripts/measure_startup.sh [device_id]

set -e

DEVICE_ID="${1:-}"
OUTPUT_FILE="build/startup_metrics.json"

echo "📊 Measuring App Startup Performance..."

# Ensure build directory exists
mkdir -p build

# Build the app in profile mode for performance testing
echo "Building app in profile mode..."
flutter build apk --profile

# Check if device is connected
if [ -z "$DEVICE_ID" ]; then
  echo "No device ID specified, using first available device..."
  DEVICE_ID=$(flutter devices --machine | jq -r '.[0].id')
fi

if [ -z "$DEVICE_ID" ] || [ "$DEVICE_ID" == "null" ]; then
  echo "❌ No device found. Please connect a device or emulator."
  exit 1
fi

echo "Using device: $DEVICE_ID"

# Install and launch the app
echo "Installing app..."
flutter install --profile -d "$DEVICE_ID"

# Get the app's package name from AndroidManifest.xml or use default
PACKAGE_NAME="com.sierrapainting.app"

echo "Clearing app data..."
adb -s "$DEVICE_ID" shell pm clear "$PACKAGE_NAME" 2>/dev/null || true

echo "Measuring cold start..."
# Start timing
START_TIME=$(date +%s%3N)

# Launch the app
adb -s "$DEVICE_ID" shell am start -W -n "$PACKAGE_NAME/.MainActivity" > /tmp/startup_output.txt 2>&1

# Parse timing from am start output
TOTAL_TIME=$(grep "TotalTime:" /tmp/startup_output.txt | awk '{print $2}')
WAIT_TIME=$(grep "WaitTime:" /tmp/startup_output.txt | awk '{print $2}')

# Calculate time to first frame (approximate)
FIRST_FRAME_TIME=$((WAIT_TIME))

echo ""
echo "📈 Startup Metrics:"
echo "  Total Time: ${TOTAL_TIME}ms"
echo "  Wait Time: ${WAIT_TIME}ms"
echo "  First Frame: ~${FIRST_FRAME_TIME}ms"

# Check against budgets
MAX_STARTUP_MS=2000
MAX_FIRST_FRAME_MS=500

# Create JSON output
cat > "$OUTPUT_FILE" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "device": "$DEVICE_ID",
  "metrics": {
    "cold_start_ms": $TOTAL_TIME,
    "first_frame_ms": $FIRST_FRAME_TIME,
    "wait_time_ms": $WAIT_TIME
  },
  "budgets": {
    "cold_start_max_ms": $MAX_STARTUP_MS,
    "first_frame_max_ms": $MAX_FIRST_FRAME_MS
  },
  "passed": $([ $TOTAL_TIME -le $MAX_STARTUP_MS ] && [ $FIRST_FRAME_TIME -le $MAX_FIRST_FRAME_MS ] && echo "true" || echo "false")
}
EOF

echo ""
echo "💾 Results saved to: $OUTPUT_FILE"

# Check against budgets
if [ $TOTAL_TIME -gt $MAX_STARTUP_MS ]; then
  echo "⚠️  Cold start time exceeds budget: ${TOTAL_TIME}ms > ${MAX_STARTUP_MS}ms"
  exit 1
fi

if [ $FIRST_FRAME_TIME -gt $MAX_FIRST_FRAME_MS ]; then
  echo "⚠️  First frame time exceeds budget: ${FIRST_FRAME_TIME}ms > ${MAX_FIRST_FRAME_MS}ms"
  exit 1
fi

echo "✅ All startup metrics within budget!"
