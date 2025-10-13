#!/bin/bash
# Seed Test Data via Firestore REST API
# Uses Firebase CLI auth + curl to create documents

set -e

echo ""
echo "🌱 Seeding test data for staging..."
echo ""

PROJECT_ID="sierra-painting-staging"
TEST_USER_ID="d5P01AlLCoaEAN5ua3hJFzcIJu2"
TEST_COMPANY_ID="test-company-staging"
TEST_JOB_ID="test-job-staging"
ASSIGNMENT_ID="test-assignment-staging"

# Get access token from Firebase CLI
echo "🔑 Getting access token..."
ACCESS_TOKEN=$(gcloud auth print-access-token 2>/dev/null || firebase login:ci --no-localhost 2>&1 | grep -oP '(?<=token:\s).*')

if [ -z "$ACCESS_TOKEN" ]; then
  echo "❌ Error: Could not get access token"
  echo "Please run: gcloud auth login"
  exit 1
fi

echo "✅ Access token obtained"
echo ""

# 1. Create Job Document
echo "1️⃣ Creating job document..."

JOB_JSON='{
  "fields": {
    "companyId": {"stringValue": "'$TEST_COMPANY_ID'"},
    "name": {"stringValue": "Test Job Site - Staging"},
    "address": {"stringValue": "123 Test Street, Providence, RI"},
    "geofence": {
      "mapValue": {
        "fields": {
          "lat": {"doubleValue": 41.8825},
          "lng": {"doubleValue": -71.3945},
          "radiusM": {"integerValue": "150"}
        }
      }
    },
    "status": {"stringValue": "active"}
  }
}'

curl -X PATCH \
  "https://firestore.googleapis.com/v1/projects/$PROJECT_ID/databases/(default)/documents/jobs/$TEST_JOB_ID?updateMask.fieldPaths=companyId&updateMask.fieldPaths=name&updateMask.fieldPaths=address&updateMask.fieldPaths=geofence&updateMask.fieldPaths=status" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$JOB_JSON" \
  -s -o /dev/null -w "   Status: %{http_code}\n"

echo "   ✅ Job created: $TEST_JOB_ID"
echo ""

# 2. Create Assignment Document
echo "2️⃣ Creating assignment document..."

ASSIGNMENT_JSON='{
  "fields": {
    "userId": {"stringValue": "'$TEST_USER_ID'"},
    "companyId": {"stringValue": "'$TEST_COMPANY_ID'"},
    "jobId": {"stringValue": "'$TEST_JOB_ID'"},
    "active": {"booleanValue": true}
  }
}'

curl -X PATCH \
  "https://firestore.googleapis.com/v1/projects/$PROJECT_ID/databases/(default)/documents/assignments/$ASSIGNMENT_ID?updateMask.fieldPaths=userId&updateMask.fieldPaths=companyId&updateMask.fieldPaths=jobId&updateMask.fieldPaths=active" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$ASSIGNMENT_JSON" \
  -s -o /dev/null -w "   Status: %{http_code}\n"

echo "   ✅ Assignment created: $ASSIGNMENT_ID"
echo ""

echo "✨ Seed operation completed!"
echo ""
echo "📍 Next Steps:"
echo "   1. Refresh the browser (Ctrl+Shift+R)"
echo "   2. Try clock-in again"
echo "   3. Check console for 'Found 1 assignments' log"
echo ""
