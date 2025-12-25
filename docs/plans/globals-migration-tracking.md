# Globals Migration Tracking

**Total extern declarations:** 107
**Already in EngineContext:** 45+
**Remaining to migrate:** ~62

> **Note:** Many globals already have deprecated accessor functions pointing to EngineContext.
> The goal is to update call sites to use EngineContext directly, then remove the legacy extern.

---

## Phase 1: Already Migrated (Use EngineContext)

These fields exist in both `globals::` and `EngineContext`. Call sites should be updated to use `ctx->` instead:

| Global | EngineContext Field | Status |
|--------|---------------------|--------|
| `registry` | `ctx->registry` | ⚠️ Update callers |
| `physicsManager` | `ctx->physicsManager` | ⚠️ Update callers |
| `inputState` | `ctx->inputState` | ⚠️ Update callers |
| `currentGameState` | `ctx->currentGameState` | ⚠️ Update callers |
| `isGamePaused` | `ctx->isGamePaused` | ⚠️ Update callers |
| `useImGUI` | `ctx->useImGUI` | ⚠️ Update callers |
| `drawDebugInfo` | `ctx->drawDebugInfo` | ⚠️ Update callers |
| `drawPhysicsDebug` | `ctx->drawPhysicsDebug` | ⚠️ Update callers |
| `releaseMode` | `ctx->releaseMode` | ⚠️ Update callers |
| `screenWipe` | `ctx->screenWipe` | ⚠️ Update callers |
| `under_overlay` | `ctx->underOverlay` | ⚠️ Update callers |
| `vibration` | `ctx->vibration` | ⚠️ Update callers |
| `finalRenderScale` | `ctx->finalRenderScale` | ⚠️ Update callers |
| `finalLetterboxOffsetX` | `ctx->finalLetterboxOffsetX` | ⚠️ Update callers |
| `finalLetterboxOffsetY` | `ctx->finalLetterboxOffsetY` | ⚠️ Update callers |
| `globalUIScaleFactor` | `ctx->globalUIScaleFactor` | ⚠️ Update callers |
| `uiPadding` | `ctx->uiPadding` | ⚠️ Update callers |
| `settings` | `ctx->settings` | ⚠️ Update callers |
| `cameraDamping` | `ctx->cameraDamping` | ⚠️ Update callers |
| `cameraStiffness` | `ctx->cameraStiffness` | ⚠️ Update callers |
| `cameraVelocity` | `ctx->cameraVelocity` | ⚠️ Update callers |
| `nextCameraTarget` | `ctx->nextCameraTarget` | ⚠️ Update callers |
| `worldWidth` | `ctx->worldWidth` | ⚠️ Update callers |
| `worldHeight` | `ctx->worldHeight` | ⚠️ Update callers |
| `globalShaderUniforms` | `ctx->shaderUniforms` | ⚠️ Update callers |
| `globalVisibilityMap` | `ctx->visibilityMap` | ⚠️ Update callers |
| `useLineOfSight` | `ctx->useLineOfSight` | ⚠️ Update callers |
| `G_TIMER_REAL` | `ctx->timerReal` | ⚠️ Update callers |
| `G_TIMER_TOTAL` | `ctx->timerTotal` | ⚠️ Update callers |
| `G_FRAMES_MOVE` | `ctx->framesMove` | ⚠️ Update callers |
| `cursor` | `ctx->cursor` | ⚠️ Update callers |
| `overlayMenu` | `ctx->overlayMenu` | ⚠️ Update callers |
| `gameWorldContainerEntity` | `ctx->gameWorldContainerEntity` | ⚠️ Update callers |
| `textureAtlasMap` | `ctx->textureAtlas` | ⚠️ Update callers |
| `animationsMap` | `ctx->animations` | ⚠️ Update callers |
| `spriteDrawFrames` | `ctx->spriteFrames` | ⚠️ Update callers |
| `colors` | `ctx->colors` | ⚠️ Update callers |
| `globalUIInstanceMap` | `ctx->globalUIInstances` | ⚠️ Update callers |
| `buttonCallbacks` | `ctx->buttonCallbacks` | ⚠️ Update callers |
| `configJSON` | `ctx->configJson` | ⚠️ Update callers |
| `colorsJSON` | `ctx->colorsJson` | ⚠️ Update callers |
| `uiStringsJSON` | `ctx->uiStringsJson` | ⚠️ Update callers |
| `animationsJSON` | `ctx->animationsJson` | ⚠️ Update callers |
| `aiConfigJSON` | `ctx->aiConfigJson` | ⚠️ Update callers |
| `aiActionsJSON` | `ctx->aiActionsJson` | ⚠️ Update callers |
| `aiWorldstateJSON` | `ctx->aiWorldstateJson` | ⚠️ Update callers |
| `ninePatchJSON` | `ctx->ninePatchJson` | ⚠️ Update callers |

---

## Phase 2: Easy Migrations (Simple Values)

Single values with few usages. Add to EngineContext, update call sites.

### Constants (Move to EngineConfig or constexpr)
| Global | Migration Target | Difficulty |
|--------|------------------|------------|
| `VIRTUAL_WIDTH` (1280) | `constexpr` in header | Easy |
| `VIRTUAL_HEIGHT` (800) | `constexpr` in header | Easy |
| `FONT_SIZE` | `ctx->settings.fontSize` | Easy |
| `UI_PROGRESS_BAR_INSET_PIXELS` | `constexpr` in header | Easy |
| `MAX_ACTIONS` (64) | Already `constexpr` | ✅ Done |

### Screen/Viewport
| Global | Migration Target | Difficulty |
|--------|------------------|------------|
| `screenWidth` | `ctx->screenWidth` | Easy |
| `screenHeight` | `ctx->screenHeight` | Easy |
| `gameWorldViewportWidth` | `ctx->gameWorldViewportWidth` | Easy |
| `gameWorldViewportHeight` | `ctx->gameWorldViewportHeight` | Easy |
| `gameWorldViewPort` | `ctx->gameWorldViewPort` | Medium |

### Debug/Dev Flags
| Global | Migration Target | Difficulty |
|--------|------------------|------------|
| `debugRenderWindowShowing` | `ctx->debugRenderWindowShowing` | Easy |
| `showObserverWindow` | `ctx->showObserverWindow` | Easy |
| `reduced_motion` | `ctx->settings.reducedMotion` | Easy |

### Mouse/Input State
| Global | Migration Target | Difficulty |
|--------|------------------|------------|
| `isMouseDragStarted` | `ctx->inputState->dragStarted` | Easy |
| `mouseDragStartedCoords` | `ctx->inputState->dragStart` | Easy |
| `mouseDragEndedCoords` | `ctx->inputState->dragEnd` | Easy |
| `clickedEntity` | `ctx->clickedEntity` | Easy |

### Loading State
| Global | Migration Target | Difficulty |
|--------|------------------|------------|
| `worldGenCurrentStep` | `ctx->loadingState.currentStep` | Easy |
| `loadingStages` | `ctx->loadingState.stages` | Easy |
| `loadingStateIndex` | `ctx->loadingState.index` | Easy |

### Animation/Effects
| Global | Migration Target | Difficulty |
|--------|------------------|------------|
| `shakeDuration` | `ctx->cameraShake.duration` | Easy |
| `shakeAmount` | `ctx->cameraShake.amount` | Easy |
| `decreaseFactor` | `ctx->cameraShake.decreaseFactor` | Easy |
| `guiClippingRotation` | `ctx->guiClippingRotation` | Easy |
| `BASE_SHADOW_EXAGGERATION` | Already in ctx | ✅ Done |
| `FIXED_TEXT_SHADOW_OFFSET` | `ctx->fixedTextShadowOffset` | Easy |

### Misc Simple
| Global | Migration Target | Difficulty |
|--------|------------------|------------|
| `G_ROOM` | `ctx->roomEntity` | Easy |
| `G_COLLISION_BUFFER` | `ctx->collisionBuffer` | Easy |
| `G_TILESIZE` | `ctx->tileSize` | Easy |
| `shouldRefreshAlerts` | `ctx->shouldRefreshAlerts` | Easy |
| `noModCursorStack` | `ctx->noModCursorStack` | Easy |
| `language` | `ctx->settings.language` | Easy |
| `startText` | `ctx->startText` | Easy |
| `currentLogDisplayIndex` | `ctx->logDisplayIndex` | Easy |
| `updateScrollPositionToHidePreviousText` | `ctx->updateScrollPosition` | Easy |
| `REFRESH_FRAME_MASTER_CACHE` | `ctx->refreshFrameMasterCache` | Easy |
| `titleTexture` | `ctx->titleTexture` | Easy |

---

## Phase 3: Medium Migrations (Structures/Caches)

Larger structures or those with multiple access patterns.

### Fonts
| Global | Migration Target | Notes |
|--------|------------------|-------|
| `font` | `ctx->fonts.main` | Need FontData struct in ctx |
| `smallerFont` | `ctx->fonts.small` | |
| `translationFont` | `ctx->fonts.translation` | |
| `uiFont12` | `ctx->fonts.imguiFont` | ImGui specific |

### UI Colors
| Global | Migration Target | Notes |
|--------|------------------|-------|
| `uiBackgroundDark` | `ctx->uiColors.backgroundDark` | Create UiColors struct |
| `uiTextLight` | `ctx->uiColors.textLight` | |
| `uiOutlineLight` | `ctx->uiColors.outlineLight` | |
| `uiTextInactive` | `ctx->uiColors.textInactive` | |
| `uiHover` | `ctx->uiColors.hover` | |
| `uiInventoryOccupied` | `ctx->uiColors.inventoryOccupied` | |
| `uiInventoryEmpty` | `ctx->uiColors.inventoryEmpty` | |

### Render Layers
| Global | Migration Target | Notes |
|--------|------------------|-------|
| `backgroundLayer` | `ctx->layers.background` | Keep Layer struct |
| `gameLayer` | `ctx->layers.game` | |
| `uiLayer` | `ctx->layers.ui` | |

### Transform Caches
| Global | Migration Target | Notes |
|--------|------------------|-------|
| `g_springCache` | `ctx->transforms.springCache` | Large, performance-critical |
| `getMasterCacheEntityToParentCompMap` | `ctx->transforms.masterCache` | Large |

### Dialogue/Flow State
| Global | Migration Target | Notes |
|--------|------------------|-------|
| `awaitingInputForForcedBranchingDialogue` | `ctx->dialogue.awaitingInput` | |
| `viableForcedBranchingChoicesByID` | `ctx->dialogue.viableChoices` | |

### Maps/Lookups
| Global | Migration Target | Notes |
|--------|------------------|-------|
| `spriteNumberToCP437_char_and_UTF16` | `ctx->cp437.spriteToChar` | |
| `CP437_charToSpriteNumber` | `ctx->cp437.charToSprite` | |
| `environmentTilesMap` | `ctx->environmentTiles` | |
| `ninePatchDataMap` | `ctx->ninePatchData` | |

### JSON Files (Bulk)
| Global | Migration Target | Notes |
|--------|------------------|-------|
| `activityJSON` | Lazy-load or ctx | Consider AssetManager |
| `environmentJSON` | Lazy-load or ctx | |
| `floraJSON` | Lazy-load or ctx | |
| `humanJSON` | Lazy-load or ctx | |
| `levelsJSON` | Lazy-load or ctx | |
| `materialsJSON` | Lazy-load or ctx | |
| `worldGenJSON` | Lazy-load or ctx | |
| `muscleJSON` | Lazy-load or ctx | |
| `timeJSON` | Lazy-load or ctx | |
| `behaviorTreeConfigJSON` | Lazy-load or ctx | |
| `levelCurvesJSON` | Lazy-load or ctx | |
| `namegenJSON` | Lazy-load or ctx | |
| `professionJSON` | Lazy-load or ctx | |
| `particleEffectsJSON` | Lazy-load or ctx | |
| `itemsJSON` | Lazy-load or ctx | |
| `combatActionToStateJSON` | Lazy-load or ctx | |
| `combatAttackWoundsJSON` | Lazy-load or ctx | |
| `combatAvailableActionsByStateJSON` | Lazy-load or ctx | |
| `objectsJSON` | Lazy-load or ctx | |
| `spritesJSON` | Lazy-load or ctx | |
| `cp437MappingsJSON` | Lazy-load or ctx | |
| `thesaurusJSON` | Lazy-load or ctx | |
| `miniJamCardsJSON` | Lazy-load or ctx | |
| `miniJamEnemiesJSON` | Lazy-load or ctx | |
| `data` | Lazy-load or ctx | |
| `saveRecord` | Lazy-load or ctx | |

---

## Phase 4: Hard Migrations (Architectural)

Require design changes or touch many systems.

### Collision/Spatial
| Global | Challenge | Strategy |
|--------|-----------|----------|
| `getBoxWorld` / `getBoxUI` | Function pointers | Create CollisionContext |
| `worldBounds` / `uiBounds` | Used by quadtrees | Part of CollisionContext |
| `quadtreeWorld` / `quadtreeUI` | Complex type | SpatialIndex class in ctx |

### Entity Collections
| Global | Challenge | Strategy |
|--------|-----------|----------|
| `enemies` | Modified throughout combat | Combat module should own |
| `map` | 2D grid, widely accessed | LevelData struct in ctx |
| `pathfindingMatrix` | AI-specific, large | AI module should own |

### Game Logic State
| Global | Challenge | Strategy |
|--------|-----------|----------|
| `globalFlagsFromJSON` | Script-accessible | GameState struct in ctx |
| `globalVariablesMapFromJSON` | Script-accessible | GameState struct in ctx |

### Lua State
| Global | Challenge | Strategy |
|--------|-----------|----------|
| `lua` (sol::state) | Already in ctx but extern too | Remove extern after migration |

---

## Migration Strategy

### Priority Order:
1. **uiPadding** (Task 5.2) - Small, clear ownership, good learning example
2. **Screen dimensions** - Simple values, widely used
3. **Debug flags** - Easy wins
4. **Loading state** - Self-contained subsystem
5. **Camera shake** - Small struct, few usages
6. **Fonts/Colors** - Create wrapper structs
7. **Layers** - Already mostly encapsulated
8. **Transform caches** - Performance critical, careful testing
9. **Collision/Spatial** - Create dedicated context
10. **JSON files** - Consider AssetManager pattern

### Per-Global Migration Checklist:
- [ ] Add field to EngineContext
- [ ] Add deprecated accessor in globals:: namespace
- [ ] Find all call sites: `grep -rn "globals::fieldName\|fieldName" src/`
- [ ] Update call sites to use ctx->
- [ ] Remove deprecated accessor
- [ ] Remove extern declaration
- [ ] Update Lua bindings if exposed

---

## Progress Tracking

| Phase | Total | Done | Remaining |
|-------|-------|------|-----------|
| 1. Already Migrated | 45 | 0 | 45 (update callers) |
| 2. Easy | 30 | 2 | 28 |
| 3. Medium | 40 | 0 | 40 |
| 4. Hard | 10 | 0 | 10 |
| **Total** | **125** | **2** | **123** |

> Note: Total exceeds 107 because some complex globals decompose into multiple ctx fields.

---

## Next Actions

1. **Task 5.2:** Migrate `uiPadding` as proof-of-concept
2. Create helper script to find global usages
3. Batch-migrate screen dimensions (4 globals at once)
4. Create subsystem structs (CameraShake, LoadingState, etc.)
