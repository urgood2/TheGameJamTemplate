# Lua API Cookbook PDF — Design Document

**Date:** 2025-12-14
**Status:** Approved

## Overview

Create a comprehensive, readable PDF documentation for the Lua portion of the codebase. Organized as a cookbook with task-oriented recipes optimized for fast lookup and minimal page-flipping.

## Design Decisions

| Decision | Choice |
|----------|--------|
| Style | Cookbook (task-oriented recipes) |
| Scope | Full codebase (~165 Lua files, ~80k lines) |
| Structure | Hybrid: Task Index + System Chapters |
| Generation | Markdown → PDF via Pandoc |
| Density | Comfortable/Readable |
| Code Quality | Traced to working source, validated against codebase |
| Estimated Pages | ~76 |

## Document Structure

### Front Matter (3-4 pages)
- Title page with version/date
- Quick Start — 1-page "your first entity in 60 seconds"
- Task Index — 2-page lookup table by task → page number

### Main Chapters

1. **Core Foundations** (~8-10 pages)
   - Require a module, imports bundle
   - Entity validation (ensure_entity, entity_cache)
   - Component access (component_cache.get)
   - Timer system (after, every, sequence, opts variants)
   - Signal events (emit, register)
   - Global state access
   - Safe script table helpers

2. **Entity Creation** (~8 pages)
   - EntityBuilder.create() full options
   - EntityBuilder.simple() quick creation
   - Interactive entities (hover, click, drag)
   - Node/monobehavior script table pattern
   - Data assignment before attach_ecs()
   - Animation resizing
   - Shadows and state tags

3. **Physics** (~8 pages)
   - PhysicsManager.get_world()
   - PhysicsBuilder fluent API
   - Circle/rectangle colliders
   - Collision tags and masks
   - Bullet mode, sync modes
   - Friction, restitution, density
   - Sensors

4. **Rendering & Shaders** (~10 pages)
   - ShaderBuilder fluent API
   - Stacking multiple shaders
   - Shader uniforms
   - Shader families (3d_skew_*, liquid_*)
   - draw.textPro() and command buffer
   - Local commands for shader pipeline
   - Render presets
   - Z-ordering

5. **UI System** (~10 pages)
   - DSL basics (dsl.root, vbox, hbox)
   - Text elements
   - Animated sprites in UI
   - Grid layouts
   - Spawning UI
   - Hover tooltips and click handlers
   - Dynamic text
   - Text effects (juicy, magical, elemental)

6. **Combat & Projectiles** (~8 pages)
   - Spawning from presets
   - Movement types (straight, homing, arc)
   - Collision behaviors (explode, pierce, bounce)
   - Damage application
   - AoE/explosions
   - Loot drops

7. **Wand & Cards** (~10 pages)
   - Card definition structure
   - Joker with calculate()
   - Card behavior registry
   - Joker event triggers
   - Tag synergy thresholds
   - Wand executor flow
   - Modifiers and triggers

8. **AI System** (~6 pages)
   - Entity types
   - Actions
   - Blackboard initialization
   - Goal selectors
   - State machine flow

9. **Data Definitions** (~4 pages)
   - cards.lua structure
   - jokers.lua structure
   - projectiles.lua structure
   - avatars.lua structure
   - Content validator

10. **Utilities & External** (~4 pages)
    - hump/signal reference
    - knife utilities
    - forma (procedural generation)
    - Common util functions

### Back Matter
- Alphabetical Function Index
- Common Patterns Cheat Sheet (1 page)

## Recipe Format

Each recipe follows a consistent template:

```
┌─────────────────────────────────────────────────────────────┐
│ RECIPE: [Task-oriented title starting with verb]            │
├─────────────────────────────────────────────────────────────┤
│ WHEN TO USE                                                 │
│ [1 sentence context - when you'd reach for this]            │
├─────────────────────────────────────────────────────────────┤
│ QUICK PATTERN                                               │
│ [Copy-paste code block, syntax highlighted]                 │
│ — from [source file:line] (adapted)                         │
├─────────────────────────────────────────────────────────────┤
│ PARAMETERS (if non-obvious)                                 │
│ • param: description                                        │
├─────────────────────────────────────────────────────────────┤
│ GOTCHAS (if any)                                            │
│ • Common mistake or trap to avoid                           │
├─────────────────────────────────────────────────────────────┤
│ SEE ALSO: [Cross-references with page numbers]              │
└─────────────────────────────────────────────────────────────┘
```

## Code Quality Guarantee

Every code snippet will be:

1. **Traced to working source** — Extracted from current codebase or validated against actual API signatures
2. **Marked with provenance** — Citation under each snippet (file:line or "matches API in X")
3. **Cross-checked against CLAUDE.md** — Aligns with documented patterns and gotchas
4. **Excludes legacy code** — No deprecated patterns, commented-out code, or test-only examples

## Technical Implementation

### File Structure

```
docs/lua-cookbook/
├── cookbook.md              # Single concatenated markdown
├── metadata.yaml            # Pandoc metadata
├── template.latex           # Custom LaTeX template
├── syntax-theme.theme       # Code highlighting
├── build.sh                 # One-command generation
└── output/
    └── lua-cookbook.pdf
```

### metadata.yaml

```yaml
title: "Lua API Cookbook"
subtitle: "TheGameJamTemplate Quick Reference"
author: "Auto-generated from codebase"
date: \today
documentclass: report
geometry: margin=1in
fontsize: 11pt
mainfont: "Helvetica Neue"
monofont: "JetBrains Mono"
linkcolor: blue
toc: true
toc-depth: 2
```

### build.sh

```bash
#!/bin/bash
pandoc cookbook.md \
  --metadata-file=metadata.yaml \
  --template=template.latex \
  --pdf-engine=xelatex \
  --toc \
  --highlight-style=syntax-theme.theme \
  -o output/lua-cookbook.pdf
```

### Dependencies

```bash
brew install pandoc
brew install --cask mactex  # or basictex
```

## Implementation Phases

### Phase 1: Setup & Extraction
- Create directory structure
- Set up Pandoc metadata and template
- Extract API signatures from codebase
- Build master recipe list per chapter

### Phase 2: Write Chapters
- Front matter
- Chapters 1-10 in order
- Back matter (function index, cheat sheet)
- Fill in Task Index with final page numbers

### Phase 3: Validation
- Grep-check snippets against codebase
- Cross-reference with CLAUDE.md
- Generate PDF and review formatting

## Maintenance Strategy

- Markdown source in git alongside code
- Update recipes when APIs change
- Date-stamp PDF version in footer

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
