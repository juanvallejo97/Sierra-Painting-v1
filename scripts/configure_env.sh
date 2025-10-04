#!/bin/bash

# Environment Configuration Script
# Configures .env file from .env.example template

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage
usage() {
  echo -e "${BLUE}Environment Configuration Script${NC}"
  echo "================================================"
  echo ""
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  --env <environment>    Target environment: development, staging, production"
  echo "  --project-id <id>      Firebase project ID"
  echo "  --interactive          Interactive mode (prompts for values)"
  echo "  --force                Force overwrite existing .env file"
  echo "  --help                 Show this help message"
  echo ""
  echo "Description:"
  echo "  This script creates a .env file from .env.example and configures"
  echo "  it with your Firebase project settings."
  echo ""
  echo "Examples:"
  echo "  $0 --interactive"
  echo "  $0 --env staging --project-id sierra-painting-staging"
  echo ""
}

# Parse arguments
ENVIRONMENT=""
PROJECT_ID=""
INTERACTIVE=false
FORCE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --env)
      ENVIRONMENT="$2"
      shift 2
      ;;
    --project-id)
      PROJECT_ID="$2"
      shift 2
      ;;
    --interactive)
      INTERACTIVE=true
      shift
      ;;
    --force)
      FORCE=true
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
echo -e "${BLUE}  Sierra Painting - Environment Configuration${NC}"
echo -e "${BLUE}================================================${NC}"
echo ""

# Check if .env.example exists
if [ ! -f ".env.example" ]; then
  echo -e "${RED}✗ .env.example file not found${NC}"
  echo -e "${YELLOW}  This file should exist in the repository root${NC}"
  exit 1
fi

# Check if .env already exists
if [ -f ".env" ] && [ "$FORCE" = false ]; then
  echo -e "${YELLOW}⚠ .env file already exists${NC}"
  read -p "Do you want to overwrite it? (y/n): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Configuration cancelled${NC}"
    exit 0
  fi
fi

# Interactive mode
if [ "$INTERACTIVE" = true ]; then
  echo -e "${YELLOW}Interactive Configuration Mode${NC}"
  echo ""
  
  # Prompt for environment
  if [ -z "$ENVIRONMENT" ]; then
    echo -e "${BLUE}Select environment:${NC}"
    echo "  1) development (uses Firebase emulators)"
    echo "  2) staging"
    echo "  3) production"
    read -p "Enter choice (1-3): " env_choice
    case $env_choice in
      1) ENVIRONMENT="development" ;;
      2) ENVIRONMENT="staging" ;;
      3) ENVIRONMENT="production" ;;
      *) 
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
    esac
  fi
  
  # Prompt for project ID (skip for development)
  if [ "$ENVIRONMENT" != "development" ] && [ -z "$PROJECT_ID" ]; then
    echo ""
    echo -e "${BLUE}Enter Firebase Project ID:${NC}"
    echo -e "${YELLOW}  (Find in Firebase Console > Project Settings)${NC}"
    read -p "Project ID: " PROJECT_ID
    
    if [ -z "$PROJECT_ID" ]; then
      echo -e "${RED}✗ Project ID is required${NC}"
      exit 1
    fi
  fi
fi

# Set default environment
if [ -z "$ENVIRONMENT" ]; then
  ENVIRONMENT="development"
  echo -e "${YELLOW}Using default environment: development${NC}"
fi

echo ""
echo -e "${YELLOW}Creating .env file...${NC}"

# Copy .env.example to .env
cp .env.example .env

# Configure environment
echo -e "${GREEN}✓ .env file created from template${NC}"
echo ""
echo -e "${YELLOW}Configuring environment: $ENVIRONMENT${NC}"

# Update ENVIRONMENT variable
sed -i "s/^ENVIRONMENT=.*/ENVIRONMENT=$ENVIRONMENT/" .env

# Configure based on environment
case $ENVIRONMENT in
  development)
    echo -e "${GREEN}✓ Configured for development (emulators)${NC}"
    sed -i "s/^USE_EMULATORS=.*/USE_EMULATORS=true/" .env
    sed -i "s/^FIREBASE_PROJECT_ID=.*/FIREBASE_PROJECT_ID=demo-project/" .env
    ;;
    
  staging)
    echo -e "${GREEN}✓ Configured for staging${NC}"
    sed -i "s/^USE_EMULATORS=.*/USE_EMULATORS=false/" .env
    if [ -n "$PROJECT_ID" ]; then
      sed -i "s/^FIREBASE_PROJECT_ID=.*/FIREBASE_PROJECT_ID=$PROJECT_ID/" .env
      sed -i "s/^FIREBASE_AUTH_DOMAIN=.*/FIREBASE_AUTH_DOMAIN=$PROJECT_ID.firebaseapp.com/" .env
      sed -i "s/^FIREBASE_STORAGE_BUCKET=.*/FIREBASE_STORAGE_BUCKET=$PROJECT_ID.appspot.com/" .env
    else
      echo -e "${YELLOW}⚠ Project ID not provided, using placeholder${NC}"
      sed -i "s/^FIREBASE_PROJECT_ID=.*/FIREBASE_PROJECT_ID=sierra-painting-staging/" .env
    fi
    ;;
    
  production)
    echo -e "${GREEN}✓ Configured for production${NC}"
    sed -i "s/^USE_EMULATORS=.*/USE_EMULATORS=false/" .env
    if [ -n "$PROJECT_ID" ]; then
      sed -i "s/^FIREBASE_PROJECT_ID=.*/FIREBASE_PROJECT_ID=$PROJECT_ID/" .env
      sed -i "s/^FIREBASE_AUTH_DOMAIN=.*/FIREBASE_AUTH_DOMAIN=$PROJECT_ID.firebaseapp.com/" .env
      sed -i "s/^FIREBASE_STORAGE_BUCKET=.*/FIREBASE_STORAGE_BUCKET=$PROJECT_ID.appspot.com/" .env
    else
      echo -e "${YELLOW}⚠ Project ID not provided, using placeholder${NC}"
      sed -i "s/^FIREBASE_PROJECT_ID=.*/FIREBASE_PROJECT_ID=sierra-painting-prod/" .env
    fi
    
    # Enable production-specific settings
    sed -i "s/^# DEBUG_LOGGING_ENABLED=.*/DEBUG_LOGGING_ENABLED=false/" .env
    sed -i "s/^# LOG_LEVEL=.*/LOG_LEVEL=info/" .env
    ;;
esac

echo ""
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}  Configuration completed successfully!${NC}"
echo -e "${GREEN}================================================${NC}"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo -e "  1. Update Firebase credentials in .env file:"
echo -e "     ${BLUE}FIREBASE_API_KEY${NC}"
echo -e "     ${BLUE}FIREBASE_APP_ID${NC}"
echo -e "     ${BLUE}FIREBASE_MESSAGING_SENDER_ID${NC}"
echo -e ""
echo -e "  2. Get these values from:"
echo -e "     ${BLUE}Firebase Console > Project Settings > Your apps${NC}"
echo -e ""
echo -e "  3. Never commit .env file with real credentials!"
echo -e ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Configure Firebase:"
echo -e "     ${BLUE}firebase login${NC}"
echo -e "     ${BLUE}firebase use --add${NC}"
echo -e "     ${BLUE}flutterfire configure${NC}"
echo -e ""
echo -e "  2. Verify configuration:"
echo -e "     ${BLUE}./scripts/verify_config.sh${NC}"
echo -e ""
