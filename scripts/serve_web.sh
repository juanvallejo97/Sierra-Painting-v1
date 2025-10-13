#!/bin/bash
# Serve Flutter Web App
# Usage: ./scripts/serve_web.sh [port]
# Example: ./scripts/serve_web.sh 9000

PORT=${1:-9000}
BUILD=false
RELEASE=true

echo "=== Flutter Web Server ==="
echo ""

# Change to project root
cd "$(dirname "$0")/.."

# Build if requested or if build doesn't exist
BUILD_PATH="build/web"
if [ "$BUILD" = true ] || [ ! -d "$BUILD_PATH" ]; then
    echo "Building Flutter web app..."
    if [ "$RELEASE" = true ]; then
        flutter build web --release
    else
        flutter build web
    fi

    if [ $? -ne 0 ]; then
        echo "Build failed!"
        exit 1
    fi
    echo "Build complete!"
    echo ""
fi

# Find available port
ORIGINAL_PORT=$PORT
MAX_ATTEMPTS=10
PORT_FOUND=false

for i in $(seq 0 $((MAX_ATTEMPTS - 1))); do
    TEST_PORT=$((PORT + i))

    # Check if port is available (cross-platform)
    if ! lsof -Pi :$TEST_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
        PORT=$TEST_PORT
        PORT_FOUND=true
        break
    fi
done

if [ "$PORT_FOUND" = false ]; then
    echo "Could not find available port in range $ORIGINAL_PORT-$((ORIGINAL_PORT + MAX_ATTEMPTS - 1))"
    exit 1
fi

if [ $PORT -ne $ORIGINAL_PORT ]; then
    echo "Port $ORIGINAL_PORT in use, using port $PORT instead"
    echo ""
fi

# Serve the app
echo "Starting server on port $PORT..."
echo "App URL: http://localhost:$PORT"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

cd "$BUILD_PATH"

# Use npx http-server (cross-platform)
npx http-server -p $PORT -o --cors
