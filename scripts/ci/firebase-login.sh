#!/bin/bash

# Firebase Login Guard Check Script
# Validates Firebase authentication and project access before deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔐 Firebase Authentication Guard Check${NC}"
echo "================================================"

# Check if running in CI environment
if [ -z "$CI" ]; then
  echo -e "${YELLOW}⚠️  Warning: Not running in CI environment${NC}"
fi

# Verify Google Cloud credentials are set
if [ -z "$GOOGLE_APPLICATION_CREDENTIALS" ] && [ -z "$GCLOUD_SERVICE_KEY" ]; then
  echo -e "${GREEN}✓ Using Workload Identity Federation (OIDC)${NC}"
  echo "No GOOGLE_APPLICATION_CREDENTIALS found - this is expected with OIDC"
else
  echo -e "${RED}❌ Error: GOOGLE_APPLICATION_CREDENTIALS or GCLOUD_SERVICE_KEY detected!${NC}"
  echo ""
  echo "POLICY VIOLATION: Long-lived service account keys are prohibited."
  echo "This repository uses Workload Identity Federation (OIDC) for authentication."
  echo ""
  echo "Please remove any JSON key-based authentication and use:"
  echo "  - workload_identity_provider in google-github-actions/auth@v2"
  echo "  - service_account parameter instead of credentials_json"
  echo ""
  echo "See: docs/ops/gcp-workload-identity-setup.md"
  exit 1
fi

# Check Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
  echo -e "${RED}❌ Error: Firebase CLI not found${NC}"
  echo "Install with: npm install -g firebase-tools@13.23.1"
  exit 1
fi

echo -e "${GREEN}✓ Firebase CLI installed${NC}"

# Get Firebase CLI version
FIREBASE_VERSION=$(firebase --version)
echo "Firebase CLI version: $FIREBASE_VERSION"

# Verify firebase.json exists
if [ ! -f "firebase.json" ]; then
  echo -e "${RED}❌ Error: firebase.json not found${NC}"
  echo "Run this script from the project root."
  exit 1
fi

echo -e "${GREEN}✓ firebase.json found${NC}"

# Verify .firebaserc exists
if [ ! -f ".firebaserc" ]; then
  echo -e "${RED}❌ Error: .firebaserc not found${NC}"
  echo "Firebase project configuration missing."
  exit 1
fi

echo -e "${GREEN}✓ .firebaserc found${NC}"

# List configured projects
echo ""
echo "Configured Firebase projects:"
firebase projects:list 2>/dev/null || echo -e "${YELLOW}⚠️  Could not list projects (auth may be in progress)${NC}"

# Check functions directory
if [ ! -d "functions" ]; then
  echo -e "${YELLOW}⚠️  Warning: functions directory not found${NC}"
else
  echo -e "${GREEN}✓ functions directory exists${NC}"
  
  # Check if functions are built
  if [ ! -d "functions/lib" ]; then
    echo -e "${YELLOW}⚠️  Warning: functions/lib not found - build may be required${NC}"
  else
    echo -e "${GREEN}✓ functions/lib exists (built)${NC}"
  fi
fi

# Validation summary
echo ""
echo "================================================"
echo -e "${GREEN}✅ All guard checks passed${NC}"
echo "Ready for Firebase deployment"
echo "================================================"

exit 0
