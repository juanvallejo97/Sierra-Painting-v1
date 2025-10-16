#!/bin/bash
# Setup Staging Firebase Configuration
# Purpose: Generate Firebase configuration for staging environment
# Usage: ./setup-staging-firebase.sh

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Setup Staging Firebase Configuration${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Check if flutterfire CLI is installed
if ! command -v flutterfire &> /dev/null; then
    echo -e "${RED}✗ flutterfire CLI not found${NC}"
    echo ""
    echo "Installing flutterfire CLI..."
    dart pub global activate flutterfire_cli
    echo -e "${GREEN}✓ flutterfire CLI installed${NC}"
    echo ""
fi

# Check if firebase CLI is logged in
echo "Checking Firebase authentication..."
if ! firebase projects:list &> /dev/null; then
    echo -e "${RED}✗ Not logged in to Firebase${NC}"
    echo ""
    echo "Please run: firebase login"
    exit 1
fi
echo -e "${GREEN}✓ Firebase authenticated${NC}"
echo ""

# List available projects
echo -e "${YELLOW}Available Firebase projects:${NC}"
firebase projects:list
echo ""

# Check if staging project exists
echo "Checking for staging project..."
if firebase projects:list | grep -q "sierra-painting-staging"; then
    echo -e "${GREEN}✓ Staging project exists: sierra-painting-staging${NC}"
    STAGING_EXISTS=true
else
    echo -e "${YELLOW}⚠ Staging project not found${NC}"
    STAGING_EXISTS=false
fi
echo ""

# Create staging project if it doesn't exist
if [ "$STAGING_EXISTS" = false ]; then
    echo -e "${YELLOW}Do you want to create the staging project? (y/n)${NC}"
    read -r CREATE_PROJECT

    if [ "$CREATE_PROJECT" = "y" ]; then
        echo "Creating staging project..."
        firebase projects:create sierra-painting-staging \
          --display-name="Sierra Painting (Staging)"
        echo -e "${GREEN}✓ Staging project created${NC}"
    else
        echo -e "${RED}✗ Cannot proceed without staging project${NC}"
        echo ""
        echo "Please create the project manually:"
        echo "  1. Go to https://console.firebase.google.com"
        echo "  2. Click 'Add project'"
        echo "  3. Name: Sierra Painting (Staging)"
        echo "  4. Project ID: sierra-painting-staging"
        exit 1
    fi
    echo ""
fi

# Generate Firebase configuration for staging
echo -e "${YELLOW}Generating staging Firebase configuration...${NC}"
flutterfire configure \
  --project=sierra-painting-staging \
  --out=lib/firebase_options_staging.dart \
  --platforms=web,android,ios \
  --yes

echo -e "${GREEN}✓ Staging configuration generated${NC}"
echo ""

# Update .firebaserc to include staging
echo -e "${YELLOW}Updating .firebaserc...${NC}"
cat > .firebaserc << EOF
{
  "projects": {
    "default": "sierra-painting",
    "staging": "sierra-painting-staging",
    "production": "sierra-painting"
  },
  "targets": {},
  "etags": {}
}
EOF
echo -e "${GREEN}✓ .firebaserc updated${NC}"
echo ""

# Create staging .env file
echo -e "${YELLOW}Creating staging environment file...${NC}"
cat > .env.staging << EOF
# Staging Environment Configuration
# Generated: $(date)

# Firebase
FIREBASE_PROJECT_ID=sierra-painting-staging

# App Check
ENABLE_APP_CHECK=true
RECAPTCHA_V3_SITE_KEY=[REPLACE_WITH_STAGING_KEY]

# Feature Flags (Remote Config)
# All flags default to OFF in staging - enable via Firebase Console

# API (if applicable)
API_BASE_URL=https://api-staging.sierra-painting.com

# Debug
ENABLE_VERBOSE_LOGGING=true
ENABLE_DEBUG_FEATURES=true
EOF
echo -e "${GREEN}✓ .env.staging created${NC}"
echo ""

# Add to .gitignore if not already there
if ! grep -q ".env.staging" .gitignore 2>/dev/null; then
    echo ".env.staging" >> .gitignore
    echo -e "${GREEN}✓ Added .env.staging to .gitignore${NC}"
fi

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Configure Firebase services in the staging project:"
echo "   → Go to https://console.firebase.google.com/project/sierra-painting-staging"
echo "   → Enable Authentication (Email/Password)"
echo "   → Enable Firestore Database"
echo "   → Enable Cloud Functions"
echo "   → Enable Cloud Storage"
echo "   → Enable Remote Config"
echo "   → Enable App Check (Web: ReCAPTCHA v3)"
echo ""
echo "2. Update .env.staging with your staging ReCAPTCHA key"
echo ""
echo "3. Deploy Firestore rules and indexes:"
echo "   firebase deploy --only firestore:rules,firestore:indexes --project=staging"
echo ""
echo "4. Configure Remote Config with default values:"
echo "   firebase deploy --only remoteconfig --project=staging"
echo ""
echo "5. Test the staging environment:"
echo "   flutter run --dart-define=FLAVOR=staging -d chrome"
echo ""
echo "6. Build for staging:"
echo "   flutter build web --dart-define=FLAVOR=staging"
echo ""
