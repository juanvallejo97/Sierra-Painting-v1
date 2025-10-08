#!/bin/bash

# Environment Setup Script
# Sets up the development environment for Sierra Painting
# This script installs dependencies and configures Firebase

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage
usage() {
  echo -e "${BLUE}Environment Setup Script${NC}"
  echo "================================================"
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --skip-flutter         Skip Flutter SDK check"
  echo "  --skip-firebase        Skip Firebase CLI check"
  echo "  --skip-node            Skip Node.js check"
  echo "  --help                 Show this help message"
  echo ""
  echo "Description:"
  echo "  This script verifies and installs required dependencies:"
  echo "  - Flutter SDK (>=3.10.0)"
  echo "  - Firebase CLI (>=12.0.0)"
  echo "  - Node.js (>=18.x)"
  echo "  - FlutterFire CLI"
  echo ""
}

# Parse arguments
SKIP_FLUTTER=false
SKIP_FIREBASE=false
SKIP_NODE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --skip-flutter)
      SKIP_FLUTTER=true
      shift
      ;;
    --skip-firebase)
      SKIP_FIREBASE=true
      shift
      ;;
    --skip-node)
      SKIP_NODE=true
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
echo -e "${BLUE}  Sierra Painting - Environment Setup${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check Flutter SDK
if [ "$SKIP_FLUTTER" = false ]; then
  echo -e "${YELLOW}Checking Flutter SDK...${NC}"
  if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -n 1 | awk '{print $2}')
    echo -e "${GREEN}✓ Flutter SDK found: $FLUTTER_VERSION${NC}"
    
    # Check Flutter version (>=3.10.0)
    REQUIRED_VERSION="3.10.0"
    if [ "$(printf '%s\n' "$REQUIRED_VERSION" "$FLUTTER_VERSION" | sort -V | head -n1)" = "$REQUIRED_VERSION" ]; then
      echo -e "${GREEN}✓ Flutter version is sufficient (>=$REQUIRED_VERSION)${NC}"
    else
      echo -e "${YELLOW}⚠ Flutter version $FLUTTER_VERSION is below recommended $REQUIRED_VERSION${NC}"
      echo -e "${YELLOW}  Consider upgrading with: flutter upgrade${NC}"
    fi
  else
    echo -e "${RED}✗ Flutter SDK not found${NC}"
    echo -e "${YELLOW}  Install from: https://flutter.dev/docs/get-started/install${NC}"
    exit 1
  fi
  echo ""
fi

# Check Node.js
if [ "$SKIP_NODE" = false ]; then
  echo -e "${YELLOW}Checking Node.js...${NC}"
  if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version | sed 's/v//')
    echo -e "${GREEN}✓ Node.js found: $NODE_VERSION${NC}"
    
    # Check Node version (>=18.x)
    NODE_MAJOR=$(echo $NODE_VERSION | cut -d. -f1)
    if [ "$NODE_MAJOR" -ge 18 ]; then
      echo -e "${GREEN}✓ Node.js version is sufficient (>=18.x)${NC}"
    else
      echo -e "${YELLOW}⚠ Node.js version $NODE_VERSION is below recommended 18.x${NC}"
      echo -e "${YELLOW}  Consider upgrading from: https://nodejs.org/${NC}"
    fi
  else
    echo -e "${RED}✗ Node.js not found${NC}"
    echo -e "${YELLOW}  Install from: https://nodejs.org/${NC}"
    exit 1
  fi
  echo ""
fi

# Check Firebase CLI
if [ "$SKIP_FIREBASE" = false ]; then
  echo -e "${YELLOW}Checking Firebase CLI...${NC}"
  if command -v firebase &> /dev/null; then
    FIREBASE_VERSION=$(firebase --version)
    echo -e "${GREEN}✓ Firebase CLI found: $FIREBASE_VERSION${NC}"
  else
    echo -e "${YELLOW}⚠ Firebase CLI not found${NC}"
    echo -e "${YELLOW}  Installing Firebase CLI...${NC}"
  npm install -g firebase-tools@13.23.1
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}✓ Firebase CLI installed successfully${NC}"
    else
      echo -e "${RED}✗ Failed to install Firebase CLI${NC}"
      exit 1
    fi
  fi
  echo ""
fi

# Check FlutterFire CLI
echo -e "${YELLOW}Checking FlutterFire CLI...${NC}"
if dart pub global list | grep -q "flutterfire_cli"; then
  echo -e "${GREEN}✓ FlutterFire CLI found${NC}"
else
  echo -e "${YELLOW}⚠ FlutterFire CLI not found${NC}"
  echo -e "${YELLOW}  Installing FlutterFire CLI...${NC}"
  dart pub global activate flutterfire_cli
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ FlutterFire CLI installed successfully${NC}"
  else
    echo -e "${RED}✗ Failed to install FlutterFire CLI${NC}"
    exit 1
  fi
fi
echo ""

# Install Flutter dependencies
echo -e "${YELLOW}Installing Flutter dependencies...${NC}"
flutter pub get
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✓ Flutter dependencies installed${NC}"
else
  echo -e "${RED}✗ Failed to install Flutter dependencies${NC}"
  exit 1
fi
echo ""

# Install Cloud Functions dependencies
if [ -d "functions" ]; then
  echo -e "${YELLOW}Installing Cloud Functions dependencies...${NC}"
  cd functions
  npm ci
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Cloud Functions dependencies installed${NC}"
  else
    echo -e "${RED}✗ Failed to install Cloud Functions dependencies${NC}"
    cd ..
    exit 1
  fi
  cd ..
  echo ""
fi

# Check Git
echo -e "${YELLOW}Checking Git...${NC}"
if command -v git &> /dev/null; then
  GIT_VERSION=$(git --version | awk '{print $3}')
  echo -e "${GREEN}✓ Git found: $GIT_VERSION${NC}"
else
  echo -e "${RED}✗ Git not found${NC}"
  echo -e "${YELLOW}  Install from: https://git-scm.com/${NC}"
  exit 1
fi
echo ""

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Environment setup completed successfully!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Configure your .env file:"
echo -e "     ${BLUE}./scripts/configure_env.sh${NC}"
echo -e ""
echo -e "  2. Set up Firebase:"
echo -e "     ${BLUE}firebase login${NC}"
echo -e "     ${BLUE}flutterfire configure${NC}"
echo -e "     Note: Use --project flag explicitly in all firebase commands"
echo -e ""
echo -e "  3. Verify configuration:"
echo -e "     ${BLUE}./scripts/verify_config.sh${NC}"
echo -e ""
