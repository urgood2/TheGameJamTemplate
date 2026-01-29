#!/bin/bash
#
# verify-doc-apis.sh - Static analysis verification of documentation API references
#
# USAGE:
#   ./scripts/verify-doc-apis.sh <markdown-file>
#   ./scripts/verify-doc-apis.sh docs/api/entity-builder.md
#   ./scripts/verify-doc-apis.sh --all  # Verify all docs/api/*.md files
#
# DESCRIPTION:
#   Extracts Lua API function calls from markdown code blocks and compares
#   them against the actual bindings in chugget_code_definitions.lua.
#   Reports OK for verified functions, MISMATCH for missing ones.
#
# EXIT CODES:
#   0 - All functions verified
#   1 - One or more mismatches found
#   2 - Invalid arguments or file not found
#
# Part of documentation-foundation plan (Task 2 of 15)
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BINDINGS_FILE="$PROJECT_ROOT/assets/scripts/chugget_code_definitions.lua"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Check for bindings file
if [[ ! -f "$BINDINGS_FILE" ]]; then
    echo -e "${RED}ERROR: Bindings file not found: $BINDINGS_FILE${NC}" >&2
    exit 2
fi

# Extract all known APIs from bindings file
# This captures:
#   - Global functions: function functionName(...)
#   - Class methods: function ClassName:methodName(...)
#   - Class names from @class annotations
extract_known_apis() {
    # Global functions
    grep -E '^function [a-zA-Z_][a-zA-Z0-9_]*\(' "$BINDINGS_FILE" 2>/dev/null | \
        sed 's/function //' | sed 's/(.*//' | sort -u

    # Class methods (ClassName:method)
    grep -E '^function [A-Z][a-zA-Z0-9_]*:' "$BINDINGS_FILE" 2>/dev/null | \
        sed 's/function //' | sed 's/(.*//' | sort -u

    # Class names from @class annotations
    grep -E '^---@class [a-zA-Z_]' "$BINDINGS_FILE" 2>/dev/null | \
        sed 's/---@class //' | sed 's/ .*//' | sort -u
}

# Extract API calls from markdown code blocks
# Captures patterns like:
#   - entity:method()
#   - Module.function()
#   - globalFunction()
extract_doc_apis() {
    local markdown_file="$1"
    
    # Extract content between ```lua and ``` code blocks
    # Then find function call patterns
    
    # Method calls: object:method(
    awk '/^```lua$/,/^```$/' "$markdown_file" | \
        grep -v '^```' | \
        grep -oE '[a-zA-Z_][a-zA-Z0-9_]*:[a-zA-Z_][a-zA-Z0-9_]*\(' | \
        sed 's/($//' | sort -u

    # Namespace function calls: module.function(
    awk '/^```lua$/,/^```$/' "$markdown_file" | \
        grep -v '^```' | \
        grep -oE '[a-zA-Z_][a-zA-Z0-9_]*\.[a-zA-Z_][a-zA-Z0-9_]*\(' | \
        sed 's/($//' | \
        grep -vE '^(math|string|table|io|os|debug|coroutine)\.' | \
        sort -u
        
    # Global function calls (standalone)
    awk '/^```lua$/,/^```$/' "$markdown_file" | \
        grep -v '^```' | \
        grep -oE '\b[a-zA-Z_][a-zA-Z0-9_]*\(' | \
        sed 's/($//' | \
        grep -vE '^(if|for|while|function|return|local|then|do|end|else|elseif|and|or|not|nil|true|false|require|print|pairs|ipairs|tostring|tonumber|type|assert|error|pcall|xpcall|select|unpack|setmetatable|getmetatable|rawget|rawset|next|math|string|table|io|os|debug|coroutine)$' | \
        sort -u
}

verify_markdown_file() {
    local markdown_file="$1"
    local ok_count=0
    local mismatch_count=0
    local skipped_count=0
    
    if [[ ! -f "$markdown_file" ]]; then
        echo -e "${RED}ERROR: File not found: $markdown_file${NC}" >&2
        return 2
    fi
    
    echo "=========================================="
    echo "Verifying: $markdown_file"
    echo "=========================================="
    
    # Create temp files for comparison
    local known_apis_file
    local doc_apis_file
    known_apis_file=$(mktemp)
    doc_apis_file=$(mktemp)
    
    extract_known_apis > "$known_apis_file"
    extract_doc_apis "$markdown_file" > "$doc_apis_file"
    
    # Check if any APIs were found in the doc
    local total_doc_apis
    total_doc_apis=$(wc -l < "$doc_apis_file" | tr -d ' ')
    
    if [[ "$total_doc_apis" -eq 0 ]]; then
        echo -e "${YELLOW}INFO: No Lua API calls found in code blocks${NC}"
        rm -f "$known_apis_file" "$doc_apis_file"
        return 0
    fi
    
    echo ""
    echo "Found $total_doc_apis API references in code blocks:"
    echo ""
    
    # Check each documented API against known bindings
    while IFS= read -r api; do
        # Skip empty lines
        [[ -z "$api" ]] && continue
        
        # Skip common Lua patterns that aren't our APIs
        if [[ "$api" =~ ^(self|_G|config|opts|options|args|params|data|result|ret|val|value|key|item|idx|index|count|size|width|height|x|y|z|w|r|g|b|a|dt|delta|time|duration|delay|callback|handler|listener|event|name|id|text|label|title|message)$ ]]; then
            ((skipped_count++))
            continue
        fi
        
        # Check if it's a known API (exact match or prefix match for methods)
        local found=false
        
        # Direct match
        if grep -qxF "$api" "$known_apis_file" 2>/dev/null; then
            found=true
        fi
        
        # Check for class method pattern (e.g., "entity:AddCollider" might be "Entity:AddCollider")
        if [[ "$found" == "false" && "$api" == *":"* ]]; then
            local method_part="${api#*:}"
            if grep -qE ":${method_part}$" "$known_apis_file" 2>/dev/null; then
                found=true
            fi
        fi
        
        # Check for namespace pattern (e.g., "physics.AddCollider" or "layer.PushCommand")
        if [[ "$found" == "false" && "$api" == *"."* ]]; then
            local func_part="${api##*.}"
            # Check if the namespace is a known class
            local namespace="${api%.*}"
            if grep -qxF "$namespace" "$known_apis_file" 2>/dev/null; then
                found=true
            elif grep -qE "^${func_part}$" "$known_apis_file" 2>/dev/null; then
                found=true
            fi
        fi
        
        # Check for standalone function
        if [[ "$found" == "false" ]]; then
            local base_func="${api##*.}"
            base_func="${base_func%%:*}"
            if grep -qxF "$base_func" "$known_apis_file" 2>/dev/null; then
                found=true
            fi
        fi
        
        if [[ "$found" == "true" ]]; then
            echo -e "${GREEN}OK${NC}: $api"
            ((ok_count++))
        else
            echo -e "${RED}MISMATCH${NC}: $api - not found in bindings"
            ((mismatch_count++))
        fi
    done < "$doc_apis_file"
    
    # Cleanup
    rm -f "$known_apis_file" "$doc_apis_file"
    
    # Summary
    echo ""
    echo "=========================================="
    echo "Summary for: $markdown_file"
    echo "=========================================="
    echo -e "  ${GREEN}OK${NC}:       $ok_count"
    echo -e "  ${RED}MISMATCH${NC}: $mismatch_count"
    echo -e "  ${YELLOW}SKIPPED${NC}:  $skipped_count (common patterns)"
    echo ""
    
    if [[ "$mismatch_count" -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Main
main() {
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <markdown-file> | --all"
        echo ""
        echo "Examples:"
        echo "  $0 docs/api/entity-builder.md"
        echo "  $0 --all"
        exit 2
    fi
    
    local exit_code=0
    
    if [[ "$1" == "--all" ]]; then
        echo "Verifying all API documentation files..."
        echo ""
        for file in "$PROJECT_ROOT"/docs/api/*.md; do
            if ! verify_markdown_file "$file"; then
                exit_code=1
            fi
        done
    else
        if ! verify_markdown_file "$1"; then
            exit_code=1
        fi
    fi
    
    exit $exit_code
}

main "$@"
