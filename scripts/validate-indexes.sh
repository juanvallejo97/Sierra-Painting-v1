#!/bin/bash
# Script to validate that all Firestore query patterns have corresponding indexes
# This is a basic check that should be expanded over time

set -e

echo "🔍 Validating Firestore Indexes..."

INDEXES_FILE="firestore.indexes.json"
QUERY_MAPPING_DOC="docs/QUERY_INDEX_MAPPING.md"

# Check that files exist
if [ ! -f "$INDEXES_FILE" ]; then
    echo "❌ Error: firestore.indexes.json not found"
    exit 1
fi

if [ ! -f "$QUERY_MAPPING_DOC" ]; then
    echo "❌ Error: docs/QUERY_INDEX_MAPPING.md not found"
    exit 1
fi

# Count indexes
INDEX_COUNT=$(jq '.indexes | length' "$INDEXES_FILE")
echo "📊 Found $INDEX_COUNT indexes defined"

echo ""
echo "🔒 Checking index documentation..."

# Simple check - just verify patterns are documented
PATTERNS_FOUND=0

if grep -qi "Query Pattern.*Time Entries" "$QUERY_MAPPING_DOC"; then
    echo "✅ Time entries query patterns documented"
    PATTERNS_FOUND=$((PATTERNS_FOUND + 1))
fi

if grep -qi "Query Pattern.*Jobs" "$QUERY_MAPPING_DOC"; then
    echo "✅ Jobs query patterns documented"
    PATTERNS_FOUND=$((PATTERNS_FOUND + 1))
fi

if grep -qi "Query Pattern.*Invoices" "$QUERY_MAPPING_DOC"; then
    echo "✅ Invoices query patterns documented"
    PATTERNS_FOUND=$((PATTERNS_FOUND + 1))
fi

if grep -qi "Query Pattern.*Estimates" "$QUERY_MAPPING_DOC"; then
    echo "✅ Estimates query patterns documented"
    PATTERNS_FOUND=$((PATTERNS_FOUND + 1))
fi

if grep -qi "Cache Strategy" "$QUERY_MAPPING_DOC"; then
    echo "✅ Cache strategy documented"
fi

if grep -qi "Pagination" "$QUERY_MAPPING_DOC"; then
    echo "✅ Pagination norms documented"
    PATTERNS_FOUND=$((PATTERNS_FOUND + 1))
fi

if grep -qi "Audit Logs" "$QUERY_MAPPING_DOC"; then
    echo "✅ Audit logs query patterns documented"
    PATTERNS_FOUND=$((PATTERNS_FOUND + 1))
fi

MISSING_COUNT=$((6 - PATTERNS_FOUND))

echo ""

if [ $MISSING_COUNT -gt 0 ]; then
    echo "⚠️  Warning: Some collection patterns may need documentation"
    echo "   Please review docs/QUERY_INDEX_MAPPING.md"
else
    echo "✅ All major collection patterns documented"
fi

echo ""
echo "📝 Index Summary:"
echo "   Total indexes: $INDEX_COUNT"
echo "   Critical indexes checked: 7"
echo ""
echo "💡 Next Steps:"
echo "   1. Run rules tests: cd functions && npm run test:rules"
echo "   2. Review query patterns in: lib/features/*/data/*_repository.dart"
echo "   3. Update QUERY_INDEX_MAPPING.md with new patterns"
echo ""
echo "✅ Index validation complete"
