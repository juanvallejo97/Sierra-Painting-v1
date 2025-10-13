#!/bin/bash
# Cloud Functions Performance Check Script
# Analyzes function execution times from Cloud Logging

set -e

# Configuration
PROJECT="${FIREBASE_PROJECT:-sierra-painting-staging}"
REGION="${FUNCTION_REGION:-us-east4}"
HOURS_AGO="${1:-24}"  # Default: last 24 hours

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Cloud Functions Performance Check${NC}"
echo "Project: ${PROJECT}"
echo "Region: ${REGION}"
echo "Time Range: Last ${HOURS_AGO} hours"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}Error: gcloud CLI not found${NC}"
    exit 1
fi

# Functions to check
FUNCTIONS=(
    "clockIn"
    "clockOut"
    "setUserRole"
)

echo "=== Function Execution Times (p50, p95, p99) ==="
echo ""

for func in "${FUNCTIONS[@]}"; do
    echo -e "${YELLOW}${func}${NC}"
    
    # Query Cloud Logging for execution times
    # Note: This is a simplified version - full implementation needs Log Analytics
    gcloud logging read "resource.type=cloud_function
        resource.labels.function_name=${func}
        timestamp>=\"$(date -u -d "${HOURS_AGO} hours ago" +%Y-%m-%dT%H:%M:%SZ)\"
        jsonPayload.executionTimeNanos>0" \
        --project=${PROJECT} \
        --limit=1000 \
        --format="value(jsonPayload.executionTimeNanos)" \
        2>/dev/null | \
        awk '{print $1/1000000000}' | \
        sort -n | \
        awk '
        BEGIN {
            count=0
        }
        {
            values[count++]=$1
            sum+=$1
        }
        END {
            if (count==0) {
                print "  No data"
            } else {
                # Calculate percentiles
                p50_idx = int(count * 0.50)
                p95_idx = int(count * 0.95)
                p99_idx = int(count * 0.99)
                avg = sum/count
                
                printf "  Requests: %d\n", count
                printf "  Average: %.3fs\n", avg
                printf "  p50: %.3fs\n", values[p50_idx]
                printf "  p95: %.3fs\n", values[p95_idx]
                printf "  p99: %.3fs\n", values[p99_idx]
                
                # Check budgets (p95 < 1.5s for clockIn/clockOut)
                if (values[p95_idx] > 1.5) {
                    printf "  Status: ✗ FAIL (p95 > 1.5s)\n"
                } else {
                    printf "  Status: ✓ PASS (p95 < 1.5s)\n"
                }
            }
        }'
    
    echo ""
done

echo "=== Cold Start Analysis ==="
echo ""

for func in "${FUNCTIONS[@]}"; do
    echo -e "${YELLOW}${func}${NC}"
    
    # Query for cold starts (first execution after idle period)
    COLD_STARTS=$(gcloud logging read "resource.type=cloud_function
        resource.labels.function_name=${func}
        timestamp>=\"$(date -u -d "${HOURS_AGO} hours ago" +%Y-%m-%dT%H:%M:%SZ)\"
        jsonPayload.coldStart=true" \
        --project=${PROJECT} \
        --limit=100 \
        --format="value(timestamp)" \
        2>/dev/null | wc -l)
    
    echo "  Cold starts: ${COLD_STARTS}"
    
    if [ ${COLD_STARTS} -gt 10 ]; then
        echo -e "  Status: ${YELLOW}⚠ Consider min instances${NC}"
    else
        echo -e "  Status: ${GREEN}✓ OK${NC}"
    fi
    
    echo ""
done

echo "=== Memory Usage ==="
echo ""

for func in "${FUNCTIONS[@]}"; do
    echo -e "${YELLOW}${func}${NC}"
    
    # Get configured memory
    MEMORY=$(gcloud functions describe ${func} \
        --region=${REGION} \
        --project=${PROJECT} \
        --format="value(availableMemoryMb)" \
        2>/dev/null || echo "N/A")
    
    echo "  Allocated: ${MEMORY} MB"
    
    # Note: Actual memory usage requires Cloud Monitoring API
    echo "  Usage: (requires Cloud Monitoring API)"
    
    echo ""
done

echo "=== Recommendations ==="
echo ""
echo "1. If p95 > budget: Optimize function code (reduce dependencies, cache data)"
echo "2. If cold starts > 10/hour: Set minInstances: 1 for critical functions"
echo "3. If memory usage > 80%: Increase availableMemoryMb"
echo ""
echo "To append to perf_budgets.md:"
echo "  bash scripts/perf/check_functions.sh >> baseline_functions.txt"
echo "  # Manually copy relevant metrics to docs/perf_budgets.md"

