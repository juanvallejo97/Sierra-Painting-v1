#!/bin/bash
# Security Headers Verification Script
# Usage: ./tools/headers_check.sh [URL]

URL="${1:-http://localhost:5000}"

echo "Checking security headers for: $URL"
echo "========================================"

# Fetch headers
HEADERS=$(curl -s -I "$URL" 2>/dev/null || echo "ERROR: Could not fetch headers")

# Check for required headers
check_header() {
  local header_name="$1"
  if echo "$HEADERS" | grep -qi "^$header_name:"; then
    echo "✓ $header_name: PRESENT"
    echo "$HEADERS" | grep -i "^$header_name:" | head -1
  else
    echo "✗ $header_name: MISSING"
    return 1
  fi
  echo ""
}

PASSED=0
FAILED=0

echo ""
echo "Required Security Headers:"
echo "--------------------------"

check_header "Content-Security-Policy" && ((PASSED++)) || ((FAILED++))
check_header "Strict-Transport-Security" && ((PASSED++)) || ((FAILED++))
check_header "X-Frame-Options" && ((PASSED++)) || ((FAILED++))
check_header "X-Content-Type-Options" && ((PASSED++)) || ((FAILED++))

echo "========================================"
echo "Results: $PASSED passed, $FAILED failed"
echo "========================================"

if [ $FAILED -gt 0 ]; then
  exit 1
fi

exit 0
