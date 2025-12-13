#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building Lua Cookbook PDF..."

pandoc cookbook.md \
  --metadata-file=metadata.yaml \
  --pdf-engine=xelatex \
  --toc \
  --resource-path=.:.. \
  -o output/lua-cookbook.pdf

echo "Done! Output: docs/lua-cookbook/output/lua-cookbook.pdf"
