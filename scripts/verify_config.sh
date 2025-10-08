#!/bin/bash

# Configuration Verification Script
# Verifies Firebase and environment configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage
usage() {
  echo -e "${BLUE}Configuration Verification Script${NC}"
  echo "================================================"
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --skip-firebase        Skip Firebase verification"
  echo "  --skip-flutter         Skip Flutter verification"
  echo "  --verbose              Show detailed output"
  echo "  --help                 Show this help message"
  echo ""
  echo "Description:"
  echo "  This script verifies that your environment is properly configured:"
  echo "  - .env file exists and is valid"
  echo "  - Firebase project is configured"
  echo "  - Flutter dependencies are installed"
  echo "  - Firebase options file exists"
  echo ""
}

# Parse arguments
SKIP_FIREBASE=false
SKIP_FLUTTER=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-firebase)
      SKIP_FIREBASE=true
      shift
      ;;
    --skip-flutter)
      SKIP_FLUTTER=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      usage
      exit 1
      ;;
  esac
done

echo -e "${BLUE}================================================${NC}"
echo -e "${BLUE}  Sierra Painting - Configuration Verification${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Track verification status
ERRORS=0
WARNINGS=0

# Verify .env file
echo -e "${YELLOW}Checking .env file...${NC}"
if [ -f ".env" ]; then
  echo -e "${GREEN}✓ .env file exists${NC}"
  
  # Check required variables
  REQUIRED_VARS=("ENVIRONMENT" "FIREBASE_PROJECT_ID")
  for var in "${REQUIRED_VARS[@]}"; do
    if grep -q "^${var}=" .env; then
      VALUE=$(grep "^${var}=" .env | cut -d '=' -f 2)
      if [ -z "$VALUE" ] || [ "$VALUE" = "your-project-id" ]; then
        echo -e "${YELLOW}⚠ $var is not configured${NC}"
        WARNINGS=$((WARNINGS+1))
      else
        if [ "$VERBOSE" = true ]; then
          echo -e "${GREEN}  ✓ $var is set${NC}"
        fi
      fi
    else
      echo -e "${RED}✗ $var is missing${NC}"
      ERRORS=$((ERRORS+1))
    fi
  done
else
  echo -e "${RED}✗ .env file not found${NC}"
  echo -e "${YELLOW}  Run: ./scripts/configure_env.sh${NC}"
  ERRORS=$((ERRORS+1))
fi
echo ""

# Verify Flutter configuration
if [ "$SKIP_FLUTTER" = false ]; then
  echo -e "${YELLOW}Checking Flutter configuration...${NC}"
  
  # Check pubspec.yaml
  if [ -f "pubspec.yaml" ]; then
    echo -e "${GREEN}✓ pubspec.yaml exists${NC}"
  else
    echo -e "${RED}✗ pubspec.yaml not found${NC}"
    ERRORS=$((ERRORS+1))
  fi
  
  # Check if dependencies are installed
  if [ -f "pubspec.lock" ]; then
    echo -e "${GREEN}✓ Flutter dependencies are installed${NC}"
  else
    echo -e "${YELLOW}⚠ Flutter dependencies not installed${NC}"
    echo -e "${YELLOW}  Run: flutter pub get${NC}"
    WARNINGS=$((WARNINGS+1))
  fi
  
  # Check Flutter SDK
  if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -n 1 | awk '{print $2}')
    echo -e "${GREEN}✓ Flutter SDK available: $FLUTTER_VERSION${NC}"
  else
    echo -e "${RED}✗ Flutter SDK not found${NC}"
    ERRORS=$((ERRORS+1))
  fi
  echo ""
fi

# Verify Firebase configuration
if [ "$SKIP_FIREBASE" = false ]; then
  echo -e "${YELLOW}Checking Firebase configuration...${NC}"
  
  # Check Firebase CLI
  if command -v firebase &> /dev/null; then
    FIREBASE_VERSION=$(firebase --version)
    echo -e "${GREEN}✓ Firebase CLI available: $FIREBASE_VERSION${NC}"
  else
    echo -e "${RED}✗ Firebase CLI not found${NC}"
  echo -e "${YELLOW}  Install: npm install -g firebase-tools@13.23.1${NC}"
    ERRORS=$((ERRORS+1))
  fi
  
  # Check .firebaserc
  if [ -f ".firebaserc" ]; then
    echo -e "${GREEN}✓ .firebaserc exists${NC}"
    
    if [ "$VERBOSE" = true ]; then
      echo -e "${BLUE}  Firebase project configuration:${NC}"
      grep -o '"default":"[^"]*"' .firebaserc 2>/dev/null || echo "  Not configured"
    fi
  else
    echo -e "${YELLOW}⚠ .firebaserc not found${NC}"
    echo -e "${YELLOW}  Note: Use --project flag explicitly in all firebase commands${NC}"
    WARNINGS=$((WARNINGS+1))
  fi
  
  # Check firebase.json
  if [ -f "firebase.json" ]; then
    echo -e "${GREEN}✓ firebase.json exists${NC}"
  else
    echo -e "${RED}✗ firebase.json not found${NC}"
    ERRORS=$((ERRORS+1))
  fi
  
  # Check Firebase options file
  if [ -f "lib/firebase_options.dart" ]; then
    echo -e "${GREEN}✓ Firebase options file exists${NC}"
  else
    echo -e "${YELLOW}⚠ Firebase options file not found${NC}"
    echo -e "${YELLOW}  Run: flutterfire configure${NC}"
    WARNINGS=$((WARNINGS+1))
  fi
  
  # Check FlutterFire CLI
  if dart pub global list | grep -q "flutterfire_cli"; then
    echo -e "${GREEN}✓ FlutterFire CLI available${NC}"
  else
    echo -e "${YELLOW}⚠ FlutterFire CLI not found${NC}"
    echo -e "${YELLOW}  Install: dart pub global activate flutterfire_cli${NC}"
    WARNINGS=$((WARNINGS+1))
  fi
  echo ""
fi

# Verify Cloud Functions
echo -e "${YELLOW}Checking Cloud Functions...${NC}"
if [ -d "functions" ]; then
  echo -e "${GREEN}✓ functions directory exists${NC}"
  
  if [ -f "functions/package.json" ]; then
    echo -e "${GREEN}✓ functions/package.json exists${NC}"
  else
    echo -e "${RED}✗ functions/package.json not found${NC}"
    ERRORS=$((ERRORS+1))
  fi
  
  if [ -d "functions/node_modules" ]; then
    echo -e "${GREEN}✓ Cloud Functions dependencies installed${NC}"
  else
    echo -e "${YELLOW}⚠ Cloud Functions dependencies not installed${NC}"
    echo -e "${YELLOW}  Run: cd functions && npm ci${NC}"
    WARNINGS=$((WARNINGS+1))
  fi
else
  echo -e "${YELLOW}⚠ functions directory not found${NC}"
  WARNINGS=$((WARNINGS+1))
fi
echo ""

# Verify Firestore rules
echo -e "${YELLOW}Checking Firestore configuration...${NC}"
if [ -f "firestore.rules" ]; then
  echo -e "${GREEN}✓ firestore.rules exists${NC}"
else
  echo -e "${RED}✗ firestore.rules not found${NC}"
  ERRORS=$((ERRORS+1))
fi

if [ -f "firestore.indexes.json" ]; then
  echo -e "${GREEN}✓ firestore.indexes.json exists${NC}"
else
  echo -e "${YELLOW}⚠ firestore.indexes.json not found${NC}"
  WARNINGS=$((WARNINGS+1))
fi
echo ""

# Verify Storage rules
echo -e "${YELLOW}Checking Storage configuration...${NC}"
if [ -f "storage.rules" ]; then
  echo -e "${GREEN}✓ storage.rules exists${NC}"
else
  echo -e "${RED}✗ storage.rules not found${NC}"
  ERRORS=$((ERRORS+1))
fi
echo ""

# Summary
echo -e "${BLUE}================================================${NC}"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
  echo -e "${GREEN}  All checks passed! ✓${NC}"
  echo -e "${GREEN}================================================${NC}"
  echo ""
  echo -e "${YELLOW}Ready to build and deploy!${NC}"
  echo ""
  echo -e "${YELLOW}Next steps:${NC}"
  echo -e "  1. Start development:"
  echo -e "     ${BLUE}firebase emulators:start${NC} (in one terminal)"
  echo -e "     ${BLUE}flutter run${NC} (in another terminal)"
  echo -e ""
  echo -e "  2. Run tests:"
  echo -e "     ${BLUE}flutter test${NC}"
  echo -e "     ${BLUE}cd functions && npm test${NC}"
  echo -e ""
  echo -e "  3. Deploy to staging:"
  echo -e "     ${BLUE}./scripts/deploy/deploy.sh --env staging${NC}"
  echo -e ""
  exit 0
elif [ $ERRORS -eq 0 ]; then
  echo -e "${YELLOW}  Verification completed with warnings${NC}"
  echo -e "${BLUE}================================================${NC}"
  echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
  echo ""
  echo -e "${YELLOW}Please address the warnings above.${NC}"
  echo ""
  exit 0
else
  echo -e "${RED}  Verification failed${NC}"
  echo -e "${BLUE}================================================${NC}"
  echo -e "${RED}Errors: $ERRORS${NC}"
  echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
  echo ""
  echo -e "${RED}Please fix the errors above before proceeding.${NC}"
  echo ""
  exit 1
fi
