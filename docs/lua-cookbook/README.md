# Lua API Cookbook

A comprehensive, recipe-based guide to the game engine's Lua API.

## What's Inside

The cookbook contains **75 recipes** organized into **14 chapters**:

1. **Quick Start** - 30-second entity creation walkthrough
2. **Task Index** - Task-based lookup table (45+ common tasks)
3. **Core Foundations** - Entity validation, components, script tables, timers, signals
4. **Entity Creation** - Sprites, physics, interactivity, script data
5. **Physics** - Physics worlds, collision masks, bullet mode, sync modes
6. **Rendering & Shaders** - Shader builder, draw commands, shader presets
7. **UI System** - DSL-based layouts, tooltips, grids
8. **Combat & Projectiles** - Spawning, movement, collision, damage, callbacks
9. **Wand & Cards** - Card definitions, jokers, tag synergies, execution pipeline
10. **AI System** - GOAP actions, entity types, blackboard, goal selectors
11. **Data Definitions** - Cards, jokers, projectiles, avatars, content validation
12. **Utilities & External Libraries** - Lume, Knife, Forma, easing, logging
13. **Appendix A: Function Index** - API reference by module
14. **Appendix B: Common Patterns Cheat Sheet** - Quick reference cards

**Total:** 6,586 lines of documentation, examples, and best practices.

## Building the PDF

### Prerequisites

Install pandoc and a LaTeX distribution:

```bash
# Install pandoc
brew install pandoc

# Option A: TinyTeX (recommended, ~100MB, no sudo)
curl -sL "https://yihui.org/tinytex/install-bin-unix.sh" | sh
~/Library/TinyTeX/bin/universal-darwin/tlmgr install fancyhdr awesomebox listings fontawesome5

# Option B: MacTeX (full install, ~5GB, requires sudo)
brew install --cask mactex-no-gui
```

### Build Command

```bash
# From project root
just docs-cookbook

# Or directly
cd docs/lua-cookbook
./build.sh
```

The PDF will be generated at `docs/lua-cookbook/output/lua-cookbook.pdf`.

### Build Script

The build script uses pandoc with:
- **Syntax highlighting** for Lua code blocks
- **LaTeX template** with custom geometry (A4, 1.25in margins)
- **Table of Contents** with page references
- **Headers/footers** with chapter names and page numbers
- **Hyperlinked cross-references** between recipes

## Using the Cookbook

The cookbook is designed for quick lookup:

1. **Task-based search**: Check the Task Index (Chapter 2) for "I want to..."
2. **Topic-based search**: Browse chapter headings
3. **PDF navigation**: Use bookmarks in the PDF reader sidebar
4. **Cross-references**: Click page numbers in tables to jump to recipes

Each recipe follows a consistent structure:
- **When to use** - Scenario description
- **Code example** - Working implementation
- **Source reference** - Exact file location in codebase
- **Gotchas** - Common mistakes to avoid

## Maintenance

To update the cookbook:

1. Edit `cookbook.md` in plain markdown
2. Add recipes with `\label{recipe:your-recipe-id}` for cross-referencing
3. Reference recipes with `\pageref{recipe:your-recipe-id}` in tables
4. Run `./build.sh` to regenerate the PDF
5. Verify all cross-references resolve (pandoc will warn about undefined labels)

### Validation

Check for broken references:

```bash
# Extract all pageref references
grep -o "\\pageref{[^}]*}" cookbook.md | sort | uniq > /tmp/pagerefs.txt

# Extract all defined labels
grep -o "\\label{[^}]*}" cookbook.md | sort | uniq > /tmp/labels.txt

# Find missing labels
comm -23 /tmp/pagerefs.txt /tmp/labels.txt
```

All references should resolve (empty output = success).

## File Structure

```
docs/lua-cookbook/
├── README.md          # This file
├── cookbook.md        # Source documentation (markdown + LaTeX)
├── metadata.yaml      # Pandoc metadata (title, author, date)
├── build.sh           # PDF generation script
└── output/
    └── lua-cookbook.pdf   # Generated PDF (gitignored)
```

## Contributing

When adding new recipes:

1. Follow the existing recipe format (heading, label, "When to use", code, source reference)
2. Add to the appropriate chapter or create a new one
3. Update the Task Index with a task-based entry
4. Include file/line references to actual implementation
5. Add "Gotcha" sections for common mistakes
6. Test the recipe in-engine before documenting

The cookbook is version-controlled and should stay in sync with the actual codebase. If the API changes, update the cookbook in the same PR.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
