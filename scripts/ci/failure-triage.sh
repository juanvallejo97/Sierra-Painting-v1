#!/bin/bash

# Failure Triage Script
# Collects logs, performance data, and diagnostics when CI jobs fail

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

OUTPUT_DIR="${1:-build/failure-triage}"

echo -e "${YELLOW}=== CI Failure Triage ===${NC}"
echo "Collecting diagnostic information..."

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Collect system information
echo -e "${GREEN}Collecting system information...${NC}"
cat > "$OUTPUT_DIR/system-info.txt" << EOF
Date: $(date)
OS: $(uname -a)
CPU: $(nproc) cores
Memory: $(free -h 2>/dev/null || echo "N/A")
Disk: $(df -h . | tail -1)
EOF

# Collect Flutter/Dart information if available
if command -v flutter &> /dev/null; then
    echo -e "${GREEN}Collecting Flutter information...${NC}"
    flutter --version > "$OUTPUT_DIR/flutter-version.txt" 2>&1 || true
    flutter doctor -v > "$OUTPUT_DIR/flutter-doctor.txt" 2>&1 || true
fi

# Collect Node.js information if available
if command -v node &> /dev/null; then
    echo -e "${GREEN}Collecting Node.js information...${NC}"
    node --version > "$OUTPUT_DIR/node-version.txt" 2>&1 || true
    npm --version > "$OUTPUT_DIR/npm-version.txt" 2>&1 || true
fi

# Collect build logs
echo -e "${GREEN}Collecting build logs...${NC}"
if [ -d "build" ]; then
    find build -name "*.log" -type f -exec cp {} "$OUTPUT_DIR/" \; 2>/dev/null || true
fi

# Collect test results
echo -e "${GREEN}Collecting test results...${NC}"
if [ -f "test-results.xml" ]; then
    cp test-results.xml "$OUTPUT_DIR/" 2>/dev/null || true
fi

# Collect coverage data
if [ -d "coverage" ]; then
    echo -e "${GREEN}Collecting coverage data...${NC}"
    cp -r coverage "$OUTPUT_DIR/" 2>/dev/null || true
fi

# Generate Flutter build profile (for performance analysis)
if [ -f "build/app/outputs/flutter-apk/app-debug.apk" ]; then
    echo -e "${GREEN}Analyzing APK size...${NC}"
    APK_SIZE=$(stat -c%s build/app/outputs/flutter-apk/app-debug.apk 2>/dev/null || stat -f%z build/app/outputs/flutter-apk/app-debug.apk)
    echo "APK Size: $APK_SIZE bytes" > "$OUTPUT_DIR/apk-size.txt"
fi

# Generate web bundle analysis
if [ -d "build/web" ]; then
    echo -e "${GREEN}Analyzing web bundle...${NC}"
    du -ah build/web > "$OUTPUT_DIR/web-bundle-breakdown.txt" 2>/dev/null || true
    TOTAL_SIZE=$(du -sb build/web | cut -f1)
    echo "Total Web Size: $TOTAL_SIZE bytes" >> "$OUTPUT_DIR/web-bundle-breakdown.txt"
fi

# Collect environment variables (sanitized)
echo -e "${GREEN}Collecting environment...${NC}"
env | grep -E '^(FLUTTER|DART|JAVA|NODE|PATH|CI|GITHUB)' | sort > "$OUTPUT_DIR/environment.txt" 2>/dev/null || true

# Generate size diff if previous build exists
if [ -f "build/previous-apk-size.txt" ] && [ -f "$OUTPUT_DIR/apk-size.txt" ]; then
    echo -e "${GREEN}Generating size diff...${NC}"
    PREV_SIZE=$(cat build/previous-apk-size.txt)
    CURR_SIZE=$(grep "APK Size:" "$OUTPUT_DIR/apk-size.txt" | cut -d' ' -f3)
    DIFF=$((CURR_SIZE - PREV_SIZE))
    
    cat > "$OUTPUT_DIR/size-diff.txt" << EOF
Previous APK: $PREV_SIZE bytes
Current APK: $CURR_SIZE bytes
Difference: $DIFF bytes
EOF
fi

# Create summary
echo -e "${GREEN}Creating summary...${NC}"
cat > "$OUTPUT_DIR/README.md" << 'EOF'
# CI Failure Triage Report

This directory contains diagnostic information collected when the CI pipeline failed.

## Contents

- `system-info.txt` - System and environment information
- `flutter-version.txt` - Flutter SDK version
- `flutter-doctor.txt` - Flutter doctor output
- `node-version.txt` - Node.js version
- `npm-version.txt` - npm version
- `*.log` - Build logs
- `test-results.xml` - Test execution results
- `coverage/` - Code coverage data
- `apk-size.txt` - Android APK size
- `web-bundle-breakdown.txt` - Web bundle size breakdown
- `size-diff.txt` - Size comparison with previous build
- `environment.txt` - Environment variables

## How to Use

1. Review the logs to identify the failure point
2. Check system-info.txt for resource constraints
3. Review size-diff.txt for unexpected growth
4. Examine test-results.xml for test failures
5. Use coverage data to identify untested code paths

## Next Steps

- If size increased unexpectedly, investigate new dependencies
- If tests failed, check test-results.xml for details
- If build failed, review build logs
- If resource constrained, consider increasing CI resources

EOF

echo -e "${GREEN}✅ Failure triage complete${NC}"
echo "Results saved to: $OUTPUT_DIR"
echo ""
echo "To upload as artifact, add this to your workflow:"
echo ""
echo "  - name: Upload failure diagnostics"
echo "    if: failure()"
echo "    uses: actions/upload-artifact@v4"
echo "    with:"
echo "      name: failure-triage"
echo "      path: $OUTPUT_DIR"
echo "      retention-days: 14"
