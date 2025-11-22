#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Configuring tests..."
cmake -B "${ROOT_DIR}/build" -DENABLE_UNIT_TESTS=ON >/dev/null

echo "Building unit_tests target..."
cmake --build "${ROOT_DIR}/build" --target unit_tests

echo "Running unit tests..."
"${ROOT_DIR}/build/unit_tests" --gtest_color=yes
