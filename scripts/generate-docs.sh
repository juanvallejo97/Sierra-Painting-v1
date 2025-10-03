#!/bin/bash

# Generate API Documentation Script
# Generates Dart documentation using dart doc

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Generating API Documentation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Step 1: Ensure dependencies are installed
echo -e "${YELLOW}[1/3] Installing dependencies...${NC}"
flutter pub get
echo -e "${GREEN}✅ Dependencies installed${NC}"
echo ""

# Step 2: Generate documentation
echo -e "${YELLOW}[2/3] Generating documentation...${NC}"
dart doc --output docs/api
echo -e "${GREEN}✅ Documentation generated${NC}"
echo ""

# Step 3: Create index redirect if docs/api exists
if [ -d "docs/api" ]; then
  echo -e "${YELLOW}[3/3] Creating documentation index...${NC}"
  
  # Create a simple README for the docs/api directory
  cat > docs/api/README.md << 'EOF'
# Sierra Painting API Documentation

This directory contains the auto-generated API documentation for the Sierra Painting Flutter application.

## Viewing Documentation

Open `index.html` in your web browser to view the documentation.

## Regenerating Documentation

To regenerate the documentation, run:

```bash
./scripts/generate-docs.sh
```

Or manually:

```bash
dart doc --output docs/api
```

## Documentation Coverage

The documentation includes:
- Core services and providers
- Feature modules (auth, timeclock, estimates, invoices, payments, admin)
- Shared widgets and utilities
- Design tokens and theme

## Contributing

When adding new public APIs, please include comprehensive documentation comments following the Dart style guide.
EOF

  echo -e "${GREEN}✅ Documentation index created${NC}"
else
  echo -e "${YELLOW}⚠️  Documentation directory not found${NC}"
fi
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✅ Documentation generation complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}📚 Documentation available at: docs/api/index.html${NC}"
