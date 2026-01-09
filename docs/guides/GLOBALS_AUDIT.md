# Globals Audit Report

Generated: 2026-01-09
Branch: cpp-refactor (Phase 3)

## Summary

| Category | Count | Status |
|----------|-------|--------|
| JSON blobs migrated to EngineContext | 8 | ✅ Done |
| JSON blobs unused (declaration only) | 18 | 🔴 To deprecate |
| Active JSON blobs needing migration | 2 | 🟡 Pending |
| Deprecated getters | 33 | ✅ Done |

## JSON Globals Status

### Already Migrated to EngineContext

These have `resolveCtxOrLegacy` wrappers and fields in `EngineContext`:

| Global | EngineContext Field | Usage Count |
|--------|---------------------|-------------|
| `configJSON` | `configJson` | 13 |
| `colorsJSON` | `colorsJson` | 4 |
| `uiStringsJSON` | `uiStringsJson` | - |
| `animationsJSON` | `animationsJson` | - |
| `aiConfigJSON` | `aiConfigJson` | - |
| `aiActionsJSON` | `aiActionsJson` | - |
| `aiWorldstateJSON` | `aiWorldstateJson` | - |
| `ninePatchJSON` | `ninePatchJson` | - |

### Unused JSON Blobs (Declaration Only)

These globals exist but are never read/written outside their declaration:

| Global | Usages | Recommendation |
|--------|--------|----------------|
| `activityJSON` | 2 (decl only) | DEPRECATE |
| `environmentJSON` | 2 (decl only) | DEPRECATE |
| `floraJSON` | 2 (decl only) | DEPRECATE |
| `humanJSON` | 2 (decl only) | DEPRECATE |
| `levelsJSON` | 2 (decl only) | DEPRECATE |
| `levelCurvesJSON` | 2 (decl only) | DEPRECATE |
| `materialsJSON` | 2 (decl only) | DEPRECATE |
| `worldGenJSON` | 2 (decl only) | DEPRECATE |
| `muscleJSON` | 2 (decl only) | DEPRECATE |
| `timeJSON` | 2 (decl only) | DEPRECATE |
| `itemsJSON` | 2 (decl only) | DEPRECATE |
| `behaviorTreeConfigJSON` | 2 (decl only) | DEPRECATE |
| `namegenJSON` | 2 (decl only) | DEPRECATE |
| `professionJSON` | 2 (decl only) | DEPRECATE |
| `particleEffectsJSON` | 2 (decl only) | DEPRECATE |
| `combatActionToStateJSON` | 2 (decl only) | DEPRECATE |
| `combatAttackWoundsJSON` | 2 (decl only) | DEPRECATE |
| `combatAvailableActionsByStateJSON` | 2 (decl only) | DEPRECATE |
| `objectsJSON` | 2 (decl only) | DEPRECATE |

### Needs Further Investigation

| Global | Usages | Notes |
|--------|--------|-------|
| `thesaurusJSON` | 5 | Check if actively used |
| `spritesJSON` | 2 | May be loaded but accessed via other means |
| `cp437MappingsJSON` | 2 | May be loaded but accessed via other means |
| `miniJamCardsJSON` | 1 | Game-specific, check Lua usage |
| `miniJamEnemiesJSON` | 1 | Game-specific, check Lua usage |

## Non-JSON Globals Status

### Entity Management

| Global | Status | Recommendation |
|--------|--------|----------------|
| `enemies` | Active | Migrate to EngineContext |
| `clickedEntity` | Active | Migrate to EngineContext |
| `map` | Active | Keep (world data) |

### Render State

| Global | Status | Notes |
|--------|--------|-------|
| `gameWorldViewPort` | Active | Render target |
| `quadtreeWorld` | Active | Spatial partitioning |
| `quadtreeUI` | Active | Spatial partitioning |

### Already Deprecated (via ENGINECTX_DEPRECATED)

33 getter functions are already marked deprecated, including:
- `getGlobalUIScaleFactor()`
- `getDrawDebugInfo()`
- `getGlobalShaderUniforms()`
- etc.

## Action Plan

### Phase 3.4: Deprecate Unused JSON Blobs
1. Add `[[deprecated]]` to all 18 unused JSON declarations
2. Keep definitions for link compatibility
3. No migration needed (they're unused)

### Phase 3.5: Migrate Entity Management
1. Add `enemies` to EngineContext
2. Add `clickedEntity` to EngineContext
3. Add deprecated getters with migration warning

## Verification Commands

```bash
# Check usage of a specific global
grep -rn "globalName" src/ --include="*.cpp" --include="*.hpp"

# Count deprecated items
grep -n "ENGINECTX_DEPRECATED" src/core/globals.hpp | wc -l

# Verify no new globals added
git diff HEAD~10 -- src/core/globals.hpp | grep "^+extern"
```
