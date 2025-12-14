#!/bin/bash
set -e

cd "$(dirname "$0")"

# Create output directory if needed
mkdir -p output

echo "Building Lua Cookbook PDF..."

# Find xelatex - prefer TinyTeX if installed, fall back to system
if [[ -x "$HOME/Library/TinyTeX/bin/universal-darwin/xelatex" ]]; then
    XELATEX="$HOME/Library/TinyTeX/bin/universal-darwin/xelatex"
elif command -v xelatex &> /dev/null; then
    XELATEX="xelatex"
else
    echo "ERROR: xelatex not found. Install TinyTeX or MacTeX."
    echo "  TinyTeX: curl -sL https://yihui.org/tinytex/install-bin-unix.sh | sh"
    echo "  MacTeX:  brew install --cask mactex-no-gui"
    exit 1
fi

echo "Using: $XELATEX"

pandoc cookbook.md \
  --metadata-file=metadata.yaml \
  --pdf-engine="$XELATEX" \
  --toc \
  --resource-path=.:.. \
  -o output/lua-cookbook.pdf

echo "Done! Output: docs/lua-cookbook/output/lua-cookbook.pdf"
