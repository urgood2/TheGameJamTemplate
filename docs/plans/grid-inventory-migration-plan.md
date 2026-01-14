# Grid-Based Inventory System Migration Plan

**Created**: 2026-01-13
**Status**: Planning
**Oracle Reviewed**: Yes

---

## Reference Implementation

> **IMPORTANT**: The reference implementation for the grid inventory system is located in the **`inventory-ui-nonoverlap-sizing`** worktree.
> 
> ```bash
> # To access the reference:
> cd /Users/joshuashin/Projects/TheGameJamTemplate/inventory-ui-nonoverlap-sizing
> ```
> 
> Use this worktree as the source of truth for:
> - Grid API usage patterns
> - Drag-drop implementation
> - Card rendering in screen-space
> - UI DSL inventory grid configuration

---

## Executive Summary

Replace the legacy world-space board inventory system with a modern screen-space grid-based system:

| Old System | New System |
|------------|------------|
| `inventory_board_id` (world-space) | `PlayerInventory` grid (screen-space) |
| `trigger_inventory_board_id` (world-space) | `PlayerInventory` "triggers" tab |
| `board_sets[n].action_board_id` | `WandLoadoutUI` action grid |
| `board_sets[n].trigger_board_id` | `WandLoadoutUI` trigger slot |

---

## Oracle Review Summary

Oracle identified these **critical additions**:

| Issue | Risk Level | Resolution |
|-------|------------|------------|
| Cross-grid transfer not supported | **HIGH** | Add `grid_transfer.lua` module |
| Modifier stack preservation | **HIGH** | Adapter must replicate `collectCardPoolForBoardSet()` exactly |
| Item location registry needed | **MEDIUM** | Prevent card duplication across grids |
| State tags ownership unclear | **MEDIUM** | Define explicit policy |
| Render space inconsistencies | **MEDIUM** | Keep all UI cards screen-space, DrawCommandSpace.Screen |
| Missing wand events | **LOW** | Add `wand_loadout_changed` signal |

---

## Target Architecture

```
+-------------------------------------------------------------+
|                     WAND LOADOUT UI (E to toggle)           |
|  +-------------+  +---------------------------------------+ |
|  | TRIGGER SLOT|  |      ACTION CARD SLOTS (N slots)      | |
|  |  (1 slot)   |  |  [Card][Card][Card][Card][Card]...    | |
|  +-------------+  +---------------------------------------+ |
|                                                             |
|  [Wand 1] [Wand 2] [Wand 3] ... (wand selector tabs)       |
+-------------------------------------------------------------+

+-------------------------------------------------------------+
|                   PLAYER INVENTORY GRID                      |
|  [Equipment] [Cards]  <- Tabs                               |
|  +----+----+----+----+                                      |
|  |    |    |    |    |                                      |
|  +----+----+----+----+  <- Grid slots                       |
|  |    |    |    |    |                                      |
|  +----+----+----+----+                                      |
+-------------------------------------------------------------+
```

---

## Implementation Phases

### Phase 0: Foundation Safety (2 hours)
**Goal**: Establish contracts and safety mechanisms before building.

| ID | Task | File(s) | Complexity | Details | Verification |
|----|------|---------|------------|---------|--------------|
| P0.1 | Create item location registry | `core/item_location_registry.lua` (new) | M | Single source of truth: `itemLocation[eid] = { grid, slot }`. Functions: `registerItem()`, `unregisterItem()`, `getLocation()`, `isInAnyGrid()` | Unit test: add item, query location, remove item |
| P0.2 | Define card space policy | `ui/card_ui_policy.lua` (new) | S | Constants: `UI_CARD_Z_BASE`, `UI_CARD_Z_DRAGGING`. Functions: `applyUICardSetup(eid)` - sets ObjectAttachedToUITag, transform space, state tags | Cards render correctly at different zoom levels |
| P0.3 | Create cross-grid transfer module | `ui/grid_transfer.lua` (new) | L | Atomic transfers with rollback. `transferItem({ item, fromGrid, fromSlot, toGrid, toSlot, onSuccess, onFail })`. Uses location registry | Transfer succeeds/fails atomically, no duplicates |

**Phase 0 Completion Criteria**:
- [ ] Location registry tracks all grid items
- [ ] Transfer between two test grids works with rollback on failure
- [ ] UI card policy applied consistently

---

### Phase 1: WandGridAdapter (3 hours)
**Goal**: Bridge grids to WandExecutor without modifying combat code.

| ID | Task | File(s) | Complexity | Details | Verification |
|----|------|---------|------------|---------|--------------|
| P1.1 | Create WandGridAdapter | `ui/wand_grid_adapter.lua` (new) | L | **Must replicate legacy behavior exactly**: `collectCardPoolFromGrids(wandIndex)` returns ordered card array with modifier stacks before base cards. `buildTriggerDefFromGrid(wandIndex)` extracts trigger params. `injectAlwaysCastCards(cardPool, wandDef)` | Compare output with `collectCardPoolForBoardSet()` for same cards |
| P1.2 | Add loadout model | `ui/wand_grid_adapter.lua` | M | Data structure: `loadout[wandIndex] = { trigger = eid, actions = { [slot] = eid }, wandDef = ref }`. Grids are views over this model | Model stays in sync with grid changes |
| P1.3 | Add sync functions | `ui/wand_grid_adapter.lua` | M | `markWandDirty(wandIndex)`, `syncAllWandsToExecutor()` with dirty-flag optimization. Called before combat | WandExecutor.loadWand receives correct data |

**Critical Implementation Detail for P1.1**:
```lua
-- MUST match legacy collectCardPoolForBoardSet() semantics:
function WandGridAdapter.collectCardPoolFromGrids(wandIndex)
    local loadout = loadoutModel[wandIndex]
    local cardPool = {}
    
    -- 1. Inject always_cast_cards (virtual cards)
    if loadout.wandDef.always_cast_cards then
        for _, cardId in ipairs(loadout.wandDef.always_cast_cards) do
            table.insert(cardPool, { id = cardId, isAlwaysCast = true })
        end
    end
    
    -- 2. Process action slots IN ORDER (slot 1, 2, 3...)
    for slotIndex = 1, loadout.wandDef.total_card_slots do
        local cardEid = loadout.actions[slotIndex]
        if cardEid and registry:valid(cardEid) then
            local script = getScriptTableFromEntityID(cardEid)
            
            -- 3. Include modifier stack BEFORE base card
            if script.cardStack and #script.cardStack > 0 then
                for _, stackedCard in ipairs(script.cardStack) do
                    table.insert(cardPool, stackedCard)
                end
            end
            
            -- 4. Add the base card
            table.insert(cardPool, script)
        end
    end
    
    return cardPool
end
```

**Phase 1 Completion Criteria**:
- [ ] Adapter produces identical cardPool to legacy system
- [ ] Trigger definition extraction works for all trigger types
- [ ] Sync to WandExecutor succeeds

---

### Phase 2: Player Inventory Grid (4 hours)
**Goal**: Screen-space inventory replacing legacy inventory boards.

| ID | Task | File(s) | Complexity | Details | Verification |
|----|------|---------|------------|---------|--------------|
| P2.1 | Configure inventory tabs | `ui/player_inventory.lua` | S | 2 tabs: Equipment (future), Cards (all card types). Use existing PlayerInventory module | Tabs switch correctly |
| P2.2 | Integrate card entities | `ui/player_inventory.lua` | M | `addCard(cardEid, tabId)` applies `card_ui_policy.applyUICardSetup()`, registers in location registry, converts to screen-space | Cards appear with correct shaders |
| P2.3 | Connect to planning lifecycle | `core/gameplay.lua` | S | `enterPlanningPhase()` -> `PlayerInventory.open()`. `exitPlanningPhase()` -> `PlayerInventory.close()` | Inventory visible only in planning |
| P2.4 | Migrate card spawning | `core/gameplay.lua` | M | Replace `addCardToBoard(card, inventory_board_id)` with `PlayerInventory.addCard(card, "cards")` | New cards appear in inventory grid |

**Phase 2 Completion Criteria**:
- [ ] Cards spawn into inventory grid
- [ ] Drag within inventory works
- [ ] Tab switching works
- [ ] Inventory opens/closes with phase transitions

---

### Phase 3: Wand Loadout Overlay (8-10 hours)
**Goal**: Toggleable overlay for equipping cards to wands.

| ID | Task | File(s) | Complexity | Details | Verification |
|----|------|---------|------------|---------|--------------|
| P3.1 | Create WandLoadoutUI | `ui/wand_loadout_ui.lua` (new) | L | Fixed overlay panel. Per-wand: trigger grid (1 slot), action grid (N slots from wandDef). Wand selector tabs. `init(wandDefs)`, `toggle()`, `switchWand(index)`, `isVisible()`, `destroy()` | Overlay appears at correct position |
| P3.2 | Add E key hotkey | `core/gameplay.lua` | S | In planning input handler: toggle wand loadout | E key toggles overlay |
| P3.3 | Setup slot filters | `ui/wand_loadout_ui.lua` | M | Trigger slot: `filter = function(item) return script.category == "trigger" end`. Action slots: `filter = function(item) return script.category == "action" or script.category == "modifier" end` | Only valid cards can be dropped |
| P3.4 | Enable cross-grid drag-drop | `ui/wand_loadout_ui.lua` | L | Use `grid_transfer.transferItem()` for inventory<->loadout. On drop: validate with filter, transfer atomically, mark wand dirty | Cards transfer between grids |
| P3.5 | Implement quick-equip | `ui/player_inventory.lua` | M | Right-click card -> `WandGridAdapter.quickEquip(card)`. Finds first empty slot in active wand. Error feedback if full | Right-click equips card |
| P3.6 | Connect to WandExecutor | `ui/wand_grid_adapter.lua` | M | In `beginActionPhaseFromPlanning()`: call `WandGridAdapter.syncAllWandsToExecutor()` | Combat spells work correctly |
| P3.7 | Add wand events | `ui/wand_loadout_ui.lua` | S | Emit `wand_loadout_changed`, `wand_trigger_changed`, `wand_actions_changed` on grid changes | External systems can react |

**Wand Loadout UI Structure**:
```
+--------------------------------------------------------+
|  [Wand 1] [Wand 2] [Wand 3]  <- Wand selector tabs     |
+--------------------------------------------------------+
|  +---------+  +-----+-----+-----+-----+-----+          |
|  | TRIGGER |  |  1  |  2  |  3  |  4  |  5  |          |
|  |  SLOT   |  |     |     |     |     |     |          |
|  +---------+  +-----+-----+-----+-----+-----+          |
|                    ACTION SLOTS                         |
+--------------------------------------------------------+
```

**Phase 3 Completion Criteria**:
- [ ] E key toggles wand loadout overlay
- [ ] Wand tabs switch between wands
- [ ] Drag card from inventory -> wand slot works
- [ ] Drag card from wand -> inventory works
- [ ] Right-click quick-equip works
- [ ] Combat spells fire correctly with equipped cards

---

### Phase 4: Feature Flag & Deprecation (3 hours)
**Goal**: Safe rollback capability, parallel legacy/new systems.

| ID | Task | File(s) | Complexity | Details | Verification |
|----|------|---------|------------|---------|--------------|
| P4.1 | Add feature flag | `core/gameplay.lua` | S | `USE_GRID_INVENTORY = true`. Gate all legacy vs new code | Flag toggles systems |
| P4.2 | Gate legacy board creation | `core/gameplay.lua` | M | Wrap `createNewBoard()` calls in `if not USE_GRID_INVENTORY` | Legacy boards not created when flag true |
| P4.3 | Gate legacy transfers | `core/gameplay.lua` | S | Wrap `transferCardViaRightClick()`, `addCardToBoard()` calls | No legacy transfer code runs |
| P4.4 | Implement save/load | `core/save_manager.lua` | M | Save: card IDs + slot positions per grid. Load: recreate cards, add to grids. **Do NOT serialize entity IDs** | Save/load preserves loadout |

**Save Schema**:
```lua
{
    inventory = {
        cards = { "CARD_ID_1", "CARD_ID_2", ... }  -- ordered by slot
    },
    wands = {
        [1] = {
            trigger = "TRIGGER_CARD_ID" or nil,
            actions = { "ACTION_1", nil, "ACTION_3", ... }  -- slot-indexed, nil = empty
        },
        ...
    }
}
```

**Phase 4 Completion Criteria**:
- [ ] `USE_GRID_INVENTORY = false` -> game uses legacy boards
- [ ] `USE_GRID_INVENTORY = true` -> game uses new grids
- [ ] Save game -> quit -> load -> loadout preserved

---

### Phase 5: Cleanup & Polish (3 hours)
**Goal**: Remove legacy code, finalize UX.

| ID | Task | File(s) | Complexity | Details | Verification |
|----|------|---------|------------|---------|--------------|
| P5.1 | Remove legacy code | `core/gameplay.lua` | M | Delete: `boards = {}`, `board_sets`, `inventory_board_id`, `trigger_inventory_board_id`, `createNewBoard()`, `addCardToBoard()`, `removeCardFromBoard()` | No references to removed code |
| P5.2 | Add drop target feedback | `ui/wand_loadout_ui.lua` | S | Green highlight = valid drop, red = invalid | Visual feedback on drag |
| P5.3 | Handle wand capacity overflow | `ui/wand_loadout_ui.lua` | M | If wand slots reduced -> auto-move overflow to inventory. If inventory full -> mark invalid, block combat | No orphaned cards |
| P5.4 | Update documentation | `CLAUDE.md`, docs | S | Remove board references, document grid APIs | Docs accurate |

**Phase 5 Completion Criteria**:
- [ ] No runtime errors referencing legacy code
- [ ] UI feels polished with visual feedback
- [ ] Edge cases handled (overflow, full inventory)

---

## Complete File Manifest

### New Files to Create

| File | Phase | Purpose |
|------|-------|---------|
| `core/item_location_registry.lua` | P0 | Track which grid contains each item |
| `ui/card_ui_policy.lua` | P0 | Standardize UI card setup |
| `ui/grid_transfer.lua` | P0 | Atomic cross-grid transfers |
| `ui/wand_grid_adapter.lua` | P1 | Bridge grids to WandExecutor |
| `ui/wand_loadout_ui.lua` | P3 | Wand loadout overlay panel |

### Files to Modify

| File | Phases | Changes |
|------|--------|---------|
| `core/gameplay.lua` | P2, P3, P4, P5 | Lifecycle hooks, feature flag, legacy removal |
| `ui/player_inventory.lua` | P2, P3 | Real card integration, quick-equip |
| `ui/inventory_grid_init.lua` | P3 | Cross-grid drop handling |
| `core/save_manager.lua` | P4 | Grid serialization |
| `CLAUDE.md` | P5 | Documentation updates |

---

## Dependency Graph

```
P0.1 (registry) --+---> P0.3 (transfer) ---> P3.4 (cross-grid drag)
                  |                               |
P0.2 (policy) ----+---> P2.2 (card integration)   |
                  |                               |
                  +---> P1.1 (adapter) ---> P1.2 ---> P1.3 ---> P3.6 (sync)
                                                        |
P2.1 ---> P2.2 ---> P2.3 ---> P2.4                     |
                                                        |
P3.1 ---> P3.2                                         |
    +---> P3.3 ---> P3.4 ---> P3.5 ---> P3.6 ---> P3.7 |
                                          |            |
                               P4.1 <-----+------------+
                                 |
                    +------------+------------+-----------+
                    v            v            v           v
                  P4.2         P4.3         P4.4       P5.1
                    +------------+------------+           |
                                 v                        v
                               P5.2 ---> P5.3 ---> P5.4
```

---

## Risk Mitigation Matrix

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| WandExecutor breaks | Medium | HIGH | Feature flag (P4.1), adapter parity testing |
| Card duplication in grids | High | HIGH | Location registry (P0.1), atomic transfers (P0.3) |
| Render/z-order bugs | Medium | Medium | Card UI policy (P0.2), consistent DrawCommandSpace.Screen |
| Modifier stacks lost | Medium | HIGH | Adapter explicitly handles cardStack (P1.1) |
| Save corruption | Low | HIGH | Save card IDs not entity IDs (P4.4) |
| Cross-grid drag fails | High | Medium | Rollback mechanism in transfer (P0.3) |

---

## Time Estimates

| Phase | Tasks | Estimated Hours | Notes |
|-------|-------|-----------------|-------|
| 0 | 3 | 2 | Foundation - critical for safety |
| 1 | 3 | 3 | Adapter must match legacy exactly |
| 2 | 4 | 4 | Straightforward, existing code |
| 3 | 7 | 8-10 | Largest phase, most complexity |
| 4 | 4 | 3 | Feature flag is safety net |
| 5 | 4 | 3 | Cleanup after verification |
| **Total** | **25** | **23-25** | Oracle estimate: 1-2 days realistic |

---

## Verification Checklist (End-to-End)

Before declaring complete, verify ALL of these:

- [ ] **Basic Inventory**: Cards appear, drag within grid, tabs work
- [ ] **Wand Loadout**: E key toggles, wand tabs work, slots filter correctly
- [ ] **Cross-Grid Transfer**: Inventory -> Wand works, Wand -> Inventory works
- [ ] **Quick Equip**: Right-click on card equips to active wand
- [ ] **Combat**: Spells fire correctly with equipped cards
- [ ] **Modifier Stacks**: Stacked modifiers apply in correct order
- [ ] **Always-Cast**: Wand always-cast cards included in spell
- [ ] **Save/Load**: Loadout persists across save/load
- [ ] **Rollback**: Feature flag false -> legacy system works
- [ ] **Camera Zoom**: UI cards stay fixed at different zoom levels
- [ ] **Overflow**: Reducing wand slots handles excess cards gracefully

---

## Rollback Strategy

If critical issues arise after deployment:

1. Set `USE_GRID_INVENTORY = false` in `gameplay.lua`
2. Restart game - legacy board system activates
3. No data migration needed (save format includes both)

---

## Notes

- This plan was reviewed by Oracle agent for architectural soundness
- Cross-grid transfer (P0.3) is the highest-risk new code
- Test combat thoroughly after P3.6 before proceeding to cleanup
