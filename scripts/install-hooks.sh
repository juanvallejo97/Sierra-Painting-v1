#!/bin/bash
# Install pre-commit hooks for Sierra Painting
# Run this script after cloning the repository

set -e

echo "🔧 Installing pre-commit hooks..."

# Copy pre-commit hook
HOOK_SOURCE="scripts/git-hooks/pre-commit"
HOOK_TARGET=".git/hooks/pre-commit"

if [ ! -f "$HOOK_SOURCE" ]; then
    echo "❌ Pre-commit hook source not found at $HOOK_SOURCE"
    exit 1
fi

# Create .git/hooks directory if it doesn't exist
mkdir -p .git/hooks

# Copy hook
cp "$HOOK_SOURCE" "$HOOK_TARGET"
chmod +x "$HOOK_TARGET"

echo "✅ Pre-commit hook installed successfully!"
echo ""
echo "The hook will:"
echo "  • Check Dart formatting (dart format)"
echo "  • Run Flutter analyzer (flutter analyze)"
echo "  • Run ESLint on Cloud Functions (npm run lint)"
echo ""
echo "To bypass the hook (not recommended):"
echo "  git commit --no-verify"
