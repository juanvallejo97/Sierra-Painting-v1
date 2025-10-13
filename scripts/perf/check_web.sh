#!/bin/bash
# Web Performance Check Script
# Uses Lighthouse to measure web app performance

set -e

# Configuration
URL="${1:-https://sierra-painting-staging.web.app}"
PROJECT="${FIREBASE_PROJECT:-sierra-painting-staging}"
OUTPUT_DIR="perf_reports"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Web Performance Check${NC}"
echo "URL: ${URL}"
echo "Output: ${OUTPUT_DIR}/lighthouse-$(date +%Y%m%d-%H%M%S).html"
echo ""

# Check if lighthouse is installed
if ! command -v lighthouse &> /dev/null; then
    echo -e "${YELLOW}Installing Lighthouse...${NC}"
    npm install -g lighthouse
fi

# Create output directory
mkdir -p ${OUTPUT_DIR}

# Run Lighthouse
echo -e "${GREEN}Running Lighthouse audit...${NC}"
REPORT_FILE="${OUTPUT_DIR}/lighthouse-$(date +%Y%m%d-%H%M%S)"

lighthouse ${URL} \
    --output html \
    --output json \
    --output-path ${REPORT_FILE} \
    --chrome-flags="--headless --no-sandbox" \
    --preset=desktop \
    --quiet

echo ""
echo -e "${GREEN}Lighthouse audit complete!${NC}"

# Parse JSON results
JSON_FILE="${REPORT_FILE}.report.json"

if [ -f "${JSON_FILE}" ]; then
    echo ""
    echo "=== Performance Metrics ==="
    
    # Extract metrics using jq (if available)
    if command -v jq &> /dev/null; then
        PERF_SCORE=$(jq -r '.categories.performance.score * 100' ${JSON_FILE})
        FCP=$(jq -r '.audits."first-contentful-paint".displayValue' ${JSON_FILE})
        LCP=$(jq -r '.audits."largest-contentful-paint".displayValue' ${JSON_FILE})
        TTI=$(jq -r '.audits."interactive".displayValue' ${JSON_FILE})
        TBT=$(jq -r '.audits."total-blocking-time".displayValue' ${JSON_FILE})
        CLS=$(jq -r '.audits."cumulative-layout-shift".displayValue' ${JSON_FILE})
        
        echo "Performance Score: ${PERF_SCORE}"
        echo "First Contentful Paint: ${FCP}"
        echo "Largest Contentful Paint: ${LCP}"
        echo "Time to Interactive: ${TTI}"
        echo "Total Blocking Time: ${TBT}"
        echo "Cumulative Layout Shift: ${CLS}"
        
        # Check budgets
        echo ""
        echo "=== Budget Status ==="
        
        # Convert score to integer for comparison
        PERF_SCORE_INT=$(printf "%.0f" ${PERF_SCORE})
        
        if [ ${PERF_SCORE_INT} -ge 90 ]; then
            echo -e "Performance Score: ${GREEN}✓ PASS${NC} (${PERF_SCORE} >= 90)"
        else
            echo -e "Performance Score: ${RED}✗ FAIL${NC} (${PERF_SCORE} < 90)"
        fi
        
    else
        echo -e "${YELLOW}jq not installed - install for detailed metrics${NC}"
        echo "Raw JSON report: ${JSON_FILE}"
    fi
fi

echo ""
echo "HTML Report: ${REPORT_FILE}.report.html"
echo ""
echo "To view report:"
echo "  open ${REPORT_FILE}.report.html"
echo ""
echo "To append to perf_budgets.md:"
echo "  echo '## Baseline Captured $(date)' >> docs/perf_budgets.md"
echo "  echo 'Performance Score: ${PERF_SCORE}' >> docs/perf_budgets.md"
echo "  echo 'FCP: ${FCP}, LCP: ${LCP}, TTI: ${TTI}' >> docs/perf_budgets.md"

