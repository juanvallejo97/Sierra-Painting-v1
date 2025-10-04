#!/bin/bash

# DEPRECATION NOTICE: This script builds the Next.js webapp
# The webapp/ directory is deprecated. See webapp/DEPRECATION_NOTICE.md
# This script will be removed once webapp/ is fully deprecated.
#
# Build and deploy script for Sierra Painting web app
# This script builds the Next.js app and copies it to the Firebase hosting directory

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Sierra Painting - Web App Build & Deploy${NC}"
echo "================================================"

# Check if we're in the right directory
if [ ! -f "firebase.json" ]; then
  echo -e "${RED}❌ Error: firebase.json not found. Run this script from the project root.${NC}"
  exit 1
fi

# Step 1: Build Next.js app
echo -e "\n${YELLOW}📦 Step 1: Building Next.js app...${NC}"
cd webapp
npm run build

if [ $? -ne 0 ]; then
  echo -e "${RED}❌ Next.js build failed${NC}"
  exit 1
fi

cd ..
echo -e "${GREEN}✓ Next.js build successful${NC}"

# Step 2: Prepare hosting directory
echo -e "\n${YELLOW}📁 Step 2: Preparing hosting directory...${NC}"

# Create build/web directory if it doesn't exist
mkdir -p build/web

# Create web subdirectory for Next.js app
mkdir -p build/web/web

echo -e "${GREEN}✓ Hosting directory prepared${NC}"

# Step 3: Copy Next.js build to hosting directory
echo -e "\n${YELLOW}📋 Step 3: Copying Next.js build...${NC}"

# Copy standalone build
if [ -d "webapp/.next/standalone" ]; then
  echo "  → Copying standalone build..."
  cp -r webapp/.next/standalone/* build/web/web/
fi

# Copy static files
if [ -d "webapp/.next/static" ]; then
  echo "  → Copying static files..."
  mkdir -p build/web/web/.next
  cp -r webapp/.next/static build/web/web/.next/
fi

# Copy public files
if [ -d "webapp/public" ]; then
  echo "  → Copying public files..."
  cp -r webapp/public/* build/web/web/ 2>/dev/null || true
fi

# Create a simple index.html if it doesn't exist (for Flutter web)
if [ ! -f "build/web/index.html" ]; then
  echo "  → Creating placeholder index.html for root..."
  cat > build/web/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Sierra Painting</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      margin: 0;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
    }
    .container {
      text-align: center;
      padding: 2rem;
    }
    h1 {
      font-size: 3rem;
      margin-bottom: 1rem;
    }
    p {
      font-size: 1.2rem;
      margin-bottom: 2rem;
    }
    .button {
      display: inline-block;
      padding: 1rem 2rem;
      background: white;
      color: #667eea;
      text-decoration: none;
      border-radius: 8px;
      font-weight: 600;
      transition: transform 0.2s;
    }
    .button:hover {
      transform: scale(1.05);
    }
  </style>
</head>
<body>
  <div class="container">
    <h1>🎨 Sierra Painting</h1>
    <p>Professional painting services for your home and business</p>
    <a href="/web" class="button">Open Web App →</a>
  </div>
</body>
</html>
EOF
fi

echo -e "${GREEN}✓ Next.js build copied successfully${NC}"

# Step 4: Build info
echo -e "\n${YELLOW}📊 Build Information:${NC}"
echo "  Next.js build: $(du -sh webapp/.next 2>/dev/null | cut -f1 || echo 'N/A')"
echo "  Hosting directory: $(du -sh build/web 2>/dev/null | cut -f1 || echo 'N/A')"

# Step 5: Optional - Deploy to Firebase
if [ "$1" == "--deploy" ]; then
  echo -e "\n${YELLOW}🚀 Step 5: Deploying to Firebase...${NC}"
  
  # Check if Firebase CLI is installed
  if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Firebase CLI not found. Install with: npm install -g firebase-tools${NC}"
    exit 1
  fi
  
  # Deploy
  firebase deploy --only hosting
  
  if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✅ Deployment successful!${NC}"
  else
    echo -e "\n${RED}❌ Deployment failed${NC}"
    exit 1
  fi
else
  echo -e "\n${GREEN}✅ Build complete!${NC}"
  echo -e "${YELLOW}💡 To deploy, run: ./scripts/build-and-deploy.sh --deploy${NC}"
  echo -e "${YELLOW}💡 Or manually: firebase deploy --only hosting${NC}"
fi

echo -e "\n${GREEN}================================================${NC}"
echo -e "${GREEN}✨ All done!${NC}"
