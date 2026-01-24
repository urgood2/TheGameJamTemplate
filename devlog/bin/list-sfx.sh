#!/usr/bin/env bash
# List available SFX files by category
# Usage: ./devlog/bin/list-sfx.sh [category] [search]
#
# Examples:
#   ./devlog/bin/list-sfx.sh                    # List all categories
#   ./devlog/bin/list-sfx.sh Transitions        # List Transitions folder
#   ./devlog/bin/list-sfx.sh search whoosh      # Search for "whoosh" in filenames

SFX_DIR="/Users/joshuashin/Projects/TexturePackerRepo/assets/Motion Fx"

if [[ ! -d "$SFX_DIR" ]]; then
    echo "SFX directory not found: $SFX_DIR"
    exit 1
fi

if [[ "$1" == "search" ]] && [[ -n "$2" ]]; then
    # Search mode
    echo "Searching for: $2"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    find "$SFX_DIR" -type f -iname "*$2*" \( -name "*.wav" -o -name "*.mp3" -o -name "*.ogg" \) | \
        sed "s|$SFX_DIR/||" | sort
elif [[ $# -ge 1 ]]; then
    # List specific category
    CATEGORY="$1"
    if [[ -d "$SFX_DIR/$CATEGORY" ]]; then
        echo "=== $CATEGORY ==="
        find "$SFX_DIR/$CATEGORY" -type f \( -name "*.wav" -o -name "*.mp3" -o -name "*.ogg" \) | \
            sed "s|$SFX_DIR/||" | sort
    else
        echo "Category not found: $CATEGORY"
        echo ""
        echo "Available categories:"
        for dir in "$SFX_DIR"/*/; do
            [[ -d "$dir" ]] && echo "  - $(basename "$dir")"
        done
    fi
else
    # List all categories with counts
    echo "SFX Library: Motion Fx"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Top-level categories
    for dir in "$SFX_DIR"/*/; do
        if [[ -d "$dir" ]]; then
            category=$(basename "$dir")
            count=$(find "$dir" -type f \( -name "*.wav" -o -name "*.mp3" -o -name "*.ogg" \) 2>/dev/null | wc -l | tr -d ' ')
            printf "  %-25s %3d files\n" "$category" "$count"

            # Show subcategories
            for subdir in "$dir"/*/; do
                if [[ -d "$subdir" ]]; then
                    subcat=$(basename "$subdir")
                    subcount=$(find "$subdir" -type f \( -name "*.wav" -o -name "*.mp3" -o -name "*.ogg" \) 2>/dev/null | wc -l | tr -d ' ')
                    printf "    └─ %-21s %3d files\n" "$subcat" "$subcount"
                fi
            done
        fi
    done

    echo ""
    echo "Usage:"
    echo "  $0 <category>        List files in category"
    echo "  $0 search <term>     Search filenames"
    echo ""
    echo "Examples:"
    echo "  $0 Transitions/Whoosh"
    echo "  $0 'User Interface - UI/Pop Ups'"
    echo "  $0 search pop"
fi
