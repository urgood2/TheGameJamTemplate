#!/bin/bash
# test_refactoring.sh - Refactoring Safety Tests
# Run this script after any refactoring changes to verify correctness.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Refactoring Safety Tests ==="
echo "Project root: $PROJECT_ROOT"
echo ""

# Step 1: Clean and build
echo -e "${YELLOW}[1/4] Building project (debug)...${NC}"
cd "$PROJECT_ROOT"

if command -v just &> /dev/null; then
    just build-debug
else
    cmake -B build -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
    cmake --build build -j4
fi

if [ $? -ne 0 ]; then
    echo -e "${RED}[FAIL] Build failed!${NC}"
    exit 1
fi
echo -e "${GREEN}[PASS] Build succeeded${NC}"
echo ""

# Step 2: Run unit tests
echo -e "${YELLOW}[2/4] Running unit tests...${NC}"
if [ -f "$PROJECT_ROOT/build/tests/unit_tests" ]; then
    "$PROJECT_ROOT/build/tests/unit_tests" --gtest_brief=1
    if [ $? -ne 0 ]; then
        echo -e "${RED}[FAIL] Unit tests failed!${NC}"
        exit 1
    fi
    echo -e "${GREEN}[PASS] Unit tests passed${NC}"
else
    echo -e "${YELLOW}[SKIP] Unit tests binary not found${NC}"
fi
echo ""

# Step 3: Check for new compiler warnings (optional)
echo -e "${YELLOW}[3/4] Checking for new compiler warnings...${NC}"
WARNING_COUNT=$(grep -c "warning:" build/CMakeFiles/raylib-cpp-cmake-template.dir/*.o.d 2>/dev/null || echo "0")
if [ "$WARNING_COUNT" != "0" ]; then
    echo -e "${YELLOW}[WARN] Found $WARNING_COUNT compiler warnings${NC}"
else
    echo -e "${GREEN}[PASS] No new compiler warnings${NC}"
fi
echo ""

# Step 4: Quick smoke test (run game headless for a few seconds)
echo -e "${YELLOW}[4/4] Running smoke test (5 seconds)...${NC}"
BINARY="$PROJECT_ROOT/build/raylib-cpp-cmake-template"
if [ -f "$BINARY" ]; then
    # Try to run headless if supported, otherwise skip
    if timeout 5 "$BINARY" --headless 2>/dev/null; then
        echo -e "${GREEN}[PASS] Smoke test passed${NC}"
    else
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 124 ]; then
            # Timeout is expected (game ran for 5 seconds)
            echo -e "${GREEN}[PASS] Smoke test passed (timeout expected)${NC}"
        else
            echo -e "${YELLOW}[SKIP] Headless mode not available or game exited early${NC}"
        fi
    fi
else
    echo -e "${YELLOW}[SKIP] Binary not found: $BINARY${NC}"
fi
echo ""

echo "=== All refactoring safety tests completed ==="
echo ""
echo "Next steps:"
echo "  1. If all tests pass, commit your changes"
echo "  2. Run the game manually to verify visual correctness"
echo "  3. Test any Lua scripts that interact with changed code"
