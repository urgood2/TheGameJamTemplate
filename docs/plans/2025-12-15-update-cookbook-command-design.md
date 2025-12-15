# Update Cookbook Slash Command Design

**Date**: 2025-12-15
**Status**: Approved

## Overview

A slash command (`/update-cookbook`) that synchronizes `docs/lua-cookbook/cookbook.md` with the current codebase by auditing existing recipes and discovering new APIs to document.

## Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  1. AUDIT PHASE                                             │
│     • Scan existing recipes in cookbook.md                  │
│     • Verify file paths exist                               │
│     • Verify function signatures match codebase             │
│     • Verify API patterns still work                        │
│     • Mark outdated recipes for update                      │
├─────────────────────────────────────────────────────────────┤
│  2. DISCOVERY PHASE                                         │
│     • Scan assets/scripts/core/*.lua                        │
│     • Scan assets/scripts/data/*.lua                        │
│     • Scan src/systems/scripting/scripting_functions.cpp    │
│     • Check recent git commits for API changes              │
│     • Identify undocumented public APIs                     │
├─────────────────────────────────────────────────────────────┤
│  3. UPDATE PHASE                                            │
│     • Fix outdated recipes in-place                         │
│     • Append new recipes to appropriate chapters            │
│     • Update Task Index with new entries                    │
├─────────────────────────────────────────────────────────────┤
│  4. FINALIZE PHASE                                          │
│     • Run ./build.sh to regenerate PDF                      │
│     • Commit changes with summary message                   │
│     • Report what was updated/added                         │
└─────────────────────────────────────────────────────────────┘
```

## Phase 1: Audit Details

**Input**: Parse `cookbook.md` to extract all recipes

**For each recipe, verify**:

| Check | How | Action if Failed |
|-------|-----|------------------|
| File paths | `test -f <path>` for `Source:` references | Update path or mark recipe for removal |
| Function exists | `grep -r "function <name>"` in Lua, or search C++ bindings | Update signature or flag as deprecated |
| API pattern valid | Check that builder methods, module exports, and patterns still exist | Rewrite example code |

**Recipe detection pattern**:
```markdown
### Recipe Name
\label{recipe:recipe-id}

**When to use**: ...

```lua
-- code example
```

**Source**: `path/to/file.lua:123`
```

**Output**:
- List of valid recipes (no changes needed)
- List of recipes with fixable issues (auto-repair)
- List of recipes that need human attention (API removed entirely)

**Edge case**: If an API was completely removed with no replacement, comment out the recipe with `<!-- DEPRECATED: reason -->` rather than silently delete.

## Phase 2: Discovery Details

**Sources to scan** (in order):

| Source | What to extract |
|--------|-----------------|
| `assets/scripts/core/*.lua` | Exported functions, module tables, builder APIs |
| `assets/scripts/data/*.lua` | Data structure patterns (cards, jokers, projectiles, avatars) |
| `src/systems/scripting/scripting_functions.cpp` | All C++-bound Lua functions |
| `git log --since="<last_cookbook_update>"` | Recent commits touching API files |

**Detection heuristics**:

```lua
-- Public API indicators:
return ModuleName           -- Module export
_G.functionName = ...       -- Global function
function M.publicMethod()   -- Module method

-- Skip:
local function _private()   -- Underscore prefix = private
local helper = ...          -- Local-only helpers
```

**For C++ bindings**, extract from patterns like:
```cpp
lua.set_function("functionName", &Implementation);
lua.new_usertype<TypeName>("TypeName", ...);
```

**Cross-reference**: Build set of documented APIs from existing recipes, compare against discovered APIs, difference = undocumented APIs.

## Phase 3: Update Details

**Fixing outdated recipes**:
1. Read current implementation from codebase
2. Update code example to match current API
3. Update `Source:` reference with correct file path and line number
4. Preserve recipe's `\label{}` for existing cross-references

**Adding new recipes** - follow cookbook format:

```markdown
### <API Name>
\label{recipe:<api-kebab-case>}

**When to use**: <1-2 sentence description>

```lua
-- Example from actual codebase or minimal working example
```

**Source**: `path/to/file.lua:123`

**Gotcha**: <Common mistake, if identifiable>
```

**Chapter placement rules**:

| File location | Target chapter |
|---------------|----------------|
| `core/entity_builder.lua` | Chapter 4: Entity Creation |
| `core/physics_builder.lua` | Chapter 5: Physics |
| `core/shader_builder.lua` | Chapter 6: Rendering & Shaders |
| `core/draw.lua` | Chapter 6: Rendering & Shaders |
| `combat/*.lua` | Chapter 8: Combat & Projectiles |
| `data/*.lua` | Chapter 11: Data Definitions |
| C++ bindings | Chapter 13: Appendix A (Function Index) |

**Task Index**: For each new recipe, add entry to Chapter 2's task lookup table.

## Phase 4: Finalize Details

**Build PDF**:
```bash
cd docs/lua-cookbook && ./build.sh
```
- Verify exit code 0
- If build fails, report error and skip commit

**Commit**:
```bash
git add docs/lua-cookbook/cookbook.md docs/lua-cookbook/output/lua-cookbook.pdf
git commit -m "docs(cookbook): sync with codebase - <N> updated, <M> added"
```

**Report output**:
```
Cookbook sync complete

Audit Results:
  - 72 recipes validated
  - 3 recipes updated (path/signature fixes)
  - 0 recipes deprecated

Discovery Results:
  - 5 new APIs documented:
    - PhysicsBuilder.sensor() -> Chapter 5
    - draw.local_command() -> Chapter 6
    - timer.sequence() -> Chapter 3

PDF rebuilt: docs/lua-cookbook/output/lua-cookbook.pdf
Committed: abc1234
```

## Edge Cases

- **No changes needed**: Report "Cookbook is up to date" and exit
- **Build fails**: Report error, do not commit partial changes
- **API removed entirely**: Comment out recipe with `<!-- DEPRECATED -->`, don't delete
- **Ambiguous chapter placement**: Default to Appendix A (Function Index)
