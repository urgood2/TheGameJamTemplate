#!/bin/bash
# Bootstrap development environment for Python automation scripts.
# Usage: ./scripts/bootstrap_dev.sh
#
# Creates/updates a Python venv and installs all dependencies.
# Idempotent: safe to run multiple times.

set -euo pipefail

# Resolve script directory (handles symlinks)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_DIR="${PROJECT_ROOT}/.venv"
REQUIREMENTS="${SCRIPT_DIR}/requirements.txt"

echo "[BOOTSTRAP] === Bootstrap Dev Environment ==="
echo "[BOOTSTRAP] Project root: $PROJECT_ROOT"
echo "[BOOTSTRAP] Venv location: $VENV_DIR"

# Check Python availability
if ! command -v python3 &> /dev/null; then
    echo "[BOOTSTRAP] ERROR: python3 not found"
    echo "[BOOTSTRAP]   Install: apt install python3 (Ubuntu) or brew install python3 (macOS)"
    exit 1
fi

PYTHON_VERSION=$(python3 --version 2>&1)
echo "[BOOTSTRAP] Python: $PYTHON_VERSION"

# Check for venv module
if ! python3 -c "import venv" 2>/dev/null; then
    echo "[BOOTSTRAP] ERROR: python3-venv not available"
    echo "[BOOTSTRAP]   Install: apt install python3-venv (Ubuntu)"
    exit 1
fi

# Create venv if not exists
if [ ! -d "$VENV_DIR" ]; then
    echo "[BOOTSTRAP] Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
    echo "[BOOTSTRAP] Venv created at $VENV_DIR"
else
    echo "[BOOTSTRAP] Venv already exists, updating..."
fi

# Activate venv
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"
echo "[BOOTSTRAP] Venv activated"

# Upgrade pip first
echo "[BOOTSTRAP] Upgrading pip..."
pip install --upgrade pip --quiet

# Install requirements
if [ -f "$REQUIREMENTS" ]; then
    echo "[BOOTSTRAP] Installing dependencies from requirements.txt..."
    pip install -r "$REQUIREMENTS" --quiet
    echo "[BOOTSTRAP] Dependencies installed"
else
    echo "[BOOTSTRAP] WARNING: requirements.txt not found at $REQUIREMENTS"
fi

# Sanity check - verify key packages
echo "[BOOTSTRAP] Verifying installation..."
SANITY_ERRORS=0

if ! python3 -c "import pytest" 2>/dev/null; then
    echo "[BOOTSTRAP]   WARNING: pytest not importable"
    SANITY_ERRORS=$((SANITY_ERRORS + 1))
fi

if ! python3 -c "import jsonschema" 2>/dev/null; then
    echo "[BOOTSTRAP]   WARNING: jsonschema not importable"
    SANITY_ERRORS=$((SANITY_ERRORS + 1))
fi

if ! python3 -c "import yaml" 2>/dev/null; then
    echo "[BOOTSTRAP]   WARNING: PyYAML not importable"
    SANITY_ERRORS=$((SANITY_ERRORS + 1))
fi

if [ $SANITY_ERRORS -eq 0 ]; then
    echo "[BOOTSTRAP] Sanity check: PASSED"
else
    echo "[BOOTSTRAP] Sanity check: $SANITY_ERRORS package(s) failed to import"
fi

echo "[BOOTSTRAP] === Complete ==="
echo "[BOOTSTRAP] To activate: source $VENV_DIR/bin/activate"
echo "[BOOTSTRAP] To run tests: pytest scripts/tests -q"
