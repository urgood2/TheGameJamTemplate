# Grid-Based Inventory System Migration PRD

**Document Version**: 1.0
**Target Consumer**: AI Agents (Claude)
**Status**: Ready for Implementation

---

## 1. Overview

### 1.1 Problem Statement

The legacy inventory system uses world-space board entities (`inventory_board_id`, `trigger_inventory_board_id`, `board_sets[n]`) which move with the camera and create rendering/collision complexity. Cards in this system are world-space entities that require coordinate transformation for UI interactions.

### 1.2 Solution

Replace with a screen-space grid-based inventory system using the existing `inventory_grid.lua` API. All inventory UI will render in screen-space, providing camera-independent positioning and simpler collision detection.

### 1.3 Success Criteria

1. **Functional Parity**: New system supports all legacy behaviors (drag-drop, tooltips, reordering)
2. **Improved UX**: Screen-space rendering, hotkey support (E for wand loadout), tab-based organization
3. **Code Quality**: Clean separation of concerns, typed grid positions, event-driven updates

---

## 2. Functional Requirements

### 2.1 Grid Position as Authoritative

**Requirement**: When a card is placed in a grid slot, its position data includes `(row, col)` coordinates stored in the grid's slot data.

**Grid API Contract** (from `core/inventory_grid.lua`):

```lua
-- CAPABILITIES (what must work):
-- • Slot assignment by index or (row, col)
-- • Query item at slot
-- • Clear slot
-- • Find slot containing item
-- • Transfer between slots atomically

-- SIGNATURES (reference implementation):
grid.getItemAtIndex(gridEntity, slotIndex)    -- By 1-based slot number
grid.getItemAt(gridEntity, row, col)          -- By 1-based row/col
grid.addItem(gridEntity, itemEntity, slotIndex?)  -- Returns success, slotIndex, action
grid.removeItem(gridEntity, slotIndex)        -- Returns removed item
grid.moveItem(gridEntity, fromSlot, toSlot)   -- Returns success
grid.swapItems(gridEntity, slot1, slot2)      -- Returns success
grid.findSlotContaining(gridEntity, itemEntity)  -- Returns slotIndex or nil
```

### 2.2 Legacy Behaviors to Preserve

| Behavior | Implementation |
|----------|----------------|
| Drag-and-drop reordering | Use existing `inventory_grid_init.lua` drag-drop handlers |
| Card tooltips on hover | Cards must have `go.state.hoverEnabled = true` and tooltip data in script table |

### 2.3 Slot Restrictions

**Current Requirement**: Any card can go in any slot (no slot-specific restrictions).

**Future-proofing**: The grid API supports per-slot filters via `slot.filter = function(itemEntity)`. This can be enabled later without API changes.

### 2.4 Screen-Space Rendering

**Requirement**: All inventory UI renders in screen-space using existing codebase patterns.

**Implementation Pattern** (from `player_inventory.lua`):
```lua
-- 1. Tag entity for screen-space collision
if ObjectAttachedToUITag and not registry:has(entity, ObjectAttachedToUITag) then
    registry:emplace(entity, ObjectAttachedToUITag)
end

-- 2. Set transform space
transform.set_space(entity, "screen")

-- 3. Render with DrawCommandSpace.Screen
command_buffer.queueDrawBatchedEntities(layers.ui, function(cmd)
    cmd.entities = entityList
end, z, layer.DrawCommandSpace.Screen)
```

---

## 3. Non-Functional Requirements

*(Functional requirements only per user request)*

---

## 4. Edge Cases

### 4.1 Inventory Full

**Scenario**: Player picks up a card when inventory has no empty slots.

**Required Behavior**:
1. Check `grid.findEmptySlot(gridEntity)` before adding
2. If `nil`, emit `"inventory_full"` signal
3. Display feedback to player (e.g., popup message)
4. Card remains in world or source location

**Verification**: Attempt to add card to full grid, confirm it fails gracefully with user feedback.

### 4.2 Invalid Drag Target

**Scenario**: Card dragged over a slot that can't accept it (when slot filters are enabled).

**Required Behavior**:
1. `grid.canSlotAccept(gridEntity, slotIndex, itemEntity)` returns `false`
2. Visual feedback: slot border turns red or shows invalid indicator
3. On drop: no transfer occurs, card returns to original position

**Verification**: Enable a test filter, drag incompatible card, confirm rejection with visual feedback.

### 4.3 Save/Load with Grid Positions

**Scenario**: Game saved with cards in grid slots, then loaded.

**Required Behavior**:
1. **Save**: Serialize card IDs (NOT entity IDs) with slot indices
2. **Load**: Recreate card entities, call `grid.addItem()` for each

**Save Schema**:
```lua
{
    inventory = {
        cards = {
            { id = "FIREBALL", slot = 1 },
            { id = "ICE_SHARD", slot = 3 },
            -- slot 2 empty (not in list)
        }
    },
    wands = {
        [1] = {
            trigger = "ON_HIT",  -- card ID or nil
            actions = { "LIGHTNING", nil, "MODIFIER_DAMAGE" }  -- slot-indexed
        }
    }
}
```

**Migration from Legacy**: If loading a legacy save without grid positions, place cards sequentially in first available slots.

**Verification**: Save game with cards in specific slots, reload, confirm exact slot positions restored.

---

## 5. System Architecture

### 5.1 File Organization

Based on codebase patterns, new files should follow this structure:

| File | Location | Purpose |
|------|----------|---------|
| `item_location_registry.lua` | `assets/scripts/core/` | Core utility for tracking item-to-grid mappings |
| `card_ui_policy.lua` | `assets/scripts/ui/` | UI-specific card setup (tags, space, z-order) |
| `grid_transfer.lua` | `assets/scripts/ui/` | UI module for cross-grid atomic transfers |
| `wand_grid_adapter.lua` | `assets/scripts/ui/` | UI bridge between grids and WandExecutor |
| `wand_loadout_ui.lua` | `assets/scripts/ui/` | UI panel for wand card management |

**Rationale**: 
- Core utilities that other systems depend on → `core/`
- UI-specific modules and panels → `ui/`
- The existing `inventory_grid.lua` is correctly in `core/` as it's a data structure without UI coupling

### 5.2 Module Dependencies

```
core/item_location_registry.lua
    ↓
ui/grid_transfer.lua ←── ui/wand_loadout_ui.lua
    ↓                         ↓
ui/card_ui_policy.lua    ui/wand_grid_adapter.lua
    ↓                         ↓
ui/player_inventory.lua  core/gameplay.lua (combat integration)
```

### 5.3 Event Flow

```
[User drags card]
    ↓
inventory_grid_init.handleItemDrop()
    ↓
grid.addItem() / grid.moveItem() / grid.swapItems()
    ↓
signal.emit("grid_item_added" | "grid_item_moved" | "grid_items_swapped")
    ↓
[Listeners update: location registry, wand adapter, UI feedback]
```

---

## 6. API Specifications

### 6.1 Item Location Registry

**Capabilities**:
- Track which grid contains each item (single source of truth)
- Prevent card duplication across grids
- Query item location

**Signatures**:
```lua
local registry = require("core.item_location_registry")

registry.register(itemEntity, gridEntity, slotIndex)
registry.unregister(itemEntity)
registry.getLocation(itemEntity)  -- Returns { grid, slot } or nil
registry.isInAnyGrid(itemEntity)  -- Returns boolean
registry.getItemsInGrid(gridEntity)  -- Returns { [slot] = item }
```

### 6.2 Cross-Grid Transfer

**Capabilities**:
- Atomic transfer with rollback on failure
- Validation before transfer
- Event emission on success

**Signatures**:
```lua
local transfer = require("ui.grid_transfer")

local success, error = transfer.transferItem({
    item = itemEntity,
    fromGrid = sourceGridEntity,  -- nil if coming from outside grid system
    fromSlot = sourceSlotIndex,   -- nil if coming from outside
    toGrid = targetGridEntity,
    toSlot = targetSlotIndex,     -- nil to auto-find empty slot
    onSuccess = function(item, toGrid, toSlot) end,
    onFail = function(item, reason) end,
})
```

### 6.3 Wand Grid Adapter

**Capabilities**:
- Replicate `collectCardPoolForBoardSet()` exactly (modifier stacks, always-cast)
- Sync loadout to WandExecutor before combat
- Dirty-flag optimization

**Signatures**:
```lua
local adapter = require("ui.wand_grid_adapter")

adapter.init(wandDefinitions)  -- Called once at game start
adapter.setTrigger(wandIndex, cardEntity)
adapter.setAction(wandIndex, slotIndex, cardEntity)
adapter.clearSlot(wandIndex, slotIndex)
adapter.markDirty(wandIndex)
adapter.syncToExecutor()  -- Called before combat
adapter.collectCardPool(wandIndex)  -- Returns ordered card array
adapter.getLoadout(wandIndex)  -- Returns { trigger, actions = {} }
```

---

## 7. Testing & Verification

### 7.1 Automated Tests

| Test | What to Verify |
|------|----------------|
| Grid slot assignment | `addItem()` places at correct slot, `getItemAt()` retrieves |
| Grid slot clearing | `removeItem()` clears slot, item no longer found |
| Item uniqueness | Adding same item to second slot removes from first |
| Transfer rollback | Transfer to locked slot fails, source unchanged |
| Adapter parity | `collectCardPool()` matches legacy `collectCardPoolForBoardSet()` output |

### 7.2 Manual Verification Checklist

For AI agents to verify after each phase:

**Phase 0 (Foundation)**:
- [ ] Create test grid, add item, query location registry → returns correct grid/slot
- [ ] Transfer item between two grids → source empty, target has item
- [ ] Transfer to locked slot → fails, source still has item

**Phase 1 (Adapter)**:
- [ ] Equip cards to wand via adapter
- [ ] Call `collectCardPool()` → compare output with legacy for same cards
- [ ] Modifier stacks appear BEFORE base card in pool

**Phase 2 (Inventory Grid)**:
- [ ] Open inventory → cards visible in screen-space
- [ ] Drag card to different slot → card moves
- [ ] Switch tabs → correct cards shown per tab
- [ ] Zoom camera → inventory position unchanged

**Phase 3 (Wand Loadout)**:
- [ ] Press E → wand loadout appears
- [ ] Drag card from inventory to wand slot → card transfers
- [ ] Drag card from wand to inventory → card returns
- [ ] Right-click card in inventory → equips to first empty wand slot
- [ ] Enter combat → spells fire with equipped cards

**Phase 4 (Feature Flag)**:
- [ ] Set `USE_GRID_INVENTORY = false` → legacy boards appear
- [ ] Set `USE_GRID_INVENTORY = true` → new grids appear
- [ ] Save with new system → load → all positions preserved

**Phase 5 (Cleanup)**:
- [ ] Search codebase for `inventory_board_id` → no references
- [ ] Drag over invalid slot → red highlight appears
- [ ] Reduce wand slots → overflow cards return to inventory

---

## 8. Implementation Notes for AI Agents

### 8.1 Critical Implementation Details

1. **Data Before Attach**: When creating card entities with scripts, assign all data BEFORE calling `attach_ecs()`:
   ```lua
   local script = CardScript {}
   script.cardData = cardDef  -- FIRST
   script:attach_ecs { create_new = false, existing_entity = entity }  -- LAST
   ```

2. **Screen-Space Collision**: Cards in inventory must have `ObjectAttachedToUITag` for the UI quadtree. This is automatic when using `transform.set_space(entity, "screen")`.

3. **Z-Order for Dragged Cards**: Dragged cards should render above other UI:
   ```lua
   local DRAG_Z = z_orders.ui_tooltips + 500
   ```

4. **Signal Cleanup**: Always use `signal_group` for handlers that need cleanup:
   ```lua
   local handlers = signal_group.new("wand_loadout")
   handlers:on("grid_item_added", myHandler)
   -- Later:
   handlers:cleanup()
   ```

### 8.2 Files to Read Before Implementation

Before starting each phase, read these files for context:

- **Phase 0**: `core/inventory_grid.lua`, `ui/inventory_grid_init.lua`
- **Phase 1**: `core/gameplay.lua` (search for `collectCardPoolForBoardSet`), `WandExecutor` usage
- **Phase 2**: `ui/player_inventory.lua` (existing implementation)
- **Phase 3**: `ui/player_inventory.lua`, `core/inventory_grid.lua`
- **Phase 4**: `core/save_manager.lua`, `core/save_migrations.lua`

### 8.3 Build Verification

After each code change:
```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -E "(error|Error|Lua)"
```

---

## 9. Glossary

| Term | Definition |
|------|------------|
| Grid Entity | The parent entity containing slot entities and grid data |
| Slot Entity | A child UI element representing one grid cell |
| Item Entity | A card entity placed in a slot |
| Loadout | The set of cards equipped to a specific wand |
| Screen-Space | UI that renders at fixed screen coordinates, ignoring camera |
| World-Space | Entities that move relative to the camera |

---

## 10. References

- Migration Plan: `docs/plans/grid-inventory-migration-plan.md`
- Grid API: `assets/scripts/core/inventory_grid.lua`
- UI DSL Reference: `docs/api/ui-dsl-reference.md`
- Reference Implementation Worktree: `/Users/joshuashin/Projects/TheGameJamTemplate/inventory-ui-nonoverlap-sizing`