# Shop UI Redesign

## Context

### Original Request
Create a shop UI for the shop phase that:
- Allows purchasing cards & equipment
- Displays items as actual entities layered on UI background
- Compact, well-designed, centered window
- Includes Buy, Sell, Reroll, Lock Shop buttons
- Uses Balatro-style slide-out interaction
- Links to existing gold currency
- Removes existing card areas in shop phase
- Button to proceed to action or planning phase

### Interview Summary
**Key Discussions**:
- **Interaction style**: Balatro-style slide-out on click - shows buy button + price, details via hover tooltip
- **Lock behavior**: Lock entire shop with one button (not individual items)
- **Sell mechanic**: 50% of purchase price
- **Layout**: Card game aesthetic, single row displays, bottom action bar
- **Equipment**: Separate section from cards, verify system works
- **Next phase**: Player chooses between "To Battle" and "To Planning"
- **Pool controls**: Developer-only in Lua files

**Research Findings**:
- ShopSystem exists with complete purchase/reroll logic but old UI was incomplete
- PlayerInventory (NOT CardInventoryPanel) has no sell functionality - must be added
- Equipment definitions exist but lack `cost` field for shop
- UI DSL supports all needed components
- Phase transitions use existing functions

### Metis Review
**Identified Gaps** (addressed):
- PlayerInventory (NOT CardInventoryPanel) needs sell functionality first (prerequisite task added)
- Equipment needs `cost` field in definitions
- Shop lock helper function needed in ShopSystem
- Cards without purchase history need base sell price logic
- Old shop board purchase logic was never completed (TODO in code)
- Need to handle shop state persistence when leaving/returning

---

## Data Model & Mapping (CRITICAL)

This section defines the ACTUAL source of truth based on `assets/scripts/core/gameplay.lua:9470-9570`.

### Gold (Currency)
- **Source of truth**: `globals.currency` (defined in `assets/scripts/core/globals.lua`)
- **NO `globals.player`**: The codebase uses a LOCAL `player` table inside functions, NOT `globals.player`
- **Read gold**: `globals.currency`
- **Write gold**: Update `globals.currency` (functions like `regenerateShopState()` create local player, modify, then write back)

### Player Object Pattern (IMPORTANT)
- **Shop logic does NOT use `globals.player` for currency**. Some debug panels (content_debug_panel.lua, combat_debug_panel.lua) and shop_pack_ui.lua reference `globals.player`, but the core shop/currency system uses a LOCAL player table pattern:
  ```lua
  -- Pattern used in regenerateShopState(), rerollActiveShop(), tryPurchaseShopCard()
  local player = {
      gold = globals.currency or 0,
      cards = (globals.shopState and globals.shopState.cards) or {}
  }
  -- After operation, write back:
  globals.currency = player.gold
  globals.shopState.cards = player.cards
  ```
- **ShopUI must follow this pattern**: Create local player, pass to ShopSystem functions, write back to globals

### Owned Cards
- **Source of truth**: `globals.shopState.cards` (array of card TABLE instances)
- **Card instance**: Table with fields from cardDef (NOT entity)
- **Inventory entities**: Spawned via `addPurchasedCardToInventory(cardInstance)` at line 9422
  - Creates entity via `createNewCard(cardId, x, y, state)` 
  - Entity has its OWN script table via `getScriptTableFromEntityID(eid)` (line 9429)
  - **PROBLEM**: Entity script table is NOT the same as the purchased cardInstance table

### Entity → Card Table Mapping (CRITICAL GAP TO RESOLVE)
**VERIFIED CURRENT STATE**: `addPurchasedCardToInventory()` does NOT link entity to `globals.shopState.cards` entry.
  - File: `assets/scripts/core/gameplay.lua:9422-9439`
  - Currently sets `script.selected = false` but does NOT set `_shopCardRef`
  
**PLANNED CHANGE (Task 0c)**: Modify `addPurchasedCardToInventory()` to store reference:
```lua
-- In addPurchasedCardToInventory, AFTER creating entity:
local eid = createNewCard(cardId, -500, -500, PLANNING_STATE)
local script = getScriptTableFromEntityID(eid)
if script then
    script.selected = false
    script._shopCardRef = cardInstance  -- ADD THIS: Link to purchased instance
end
```

**Sell eligibility rules**:
- **Only shop-purchased cards are sellable** (those with `_shopCardRef` set)
- **Non-shop cards** (starter deck, rewards, etc.) have no `_shopCardRef` and CANNOT be sold
- **Ownership source of truth**: `globals.shopState.cards` is the SAME table reference passed as `player.cards` in the local player pattern

**To sell** (implemented in PlayerInventory, NOT CardInventoryPanel):
1. Get entity: `local entity = ...` (from PlayerInventory slot click)
2. Get script: `local script = getScriptTableFromEntityID(entity)`
3. Check eligibility: `if not script._shopCardRef then showWarning("Cannot sell") return end`
4. Get card instance: `local cardInstance = script._shopCardRef`
5. Create local player table referencing `globals.shopState.cards`, call `ShopSystem.sellCard(cardInstance, player)`, write back to `globals.currency`

### Inventory UI Module (CRITICAL CLARIFICATION)
- **Actual runtime inventory**: `assets/scripts/ui/player_inventory.lua` (used by `addPurchasedCardToInventory()`)
- **NOT CardInventoryPanel**: CardInventoryPanel is a separate demo/test panel
- **Sell mode implementation**: Add to PlayerInventory.lua, NOT CardInventoryPanel
- **PlayerInventory API**:
  - `PlayerInventory.addCard(entity, category)` - add card
  - `PlayerInventory.removeCard(entity)` - remove card (documented at line 16)

### Owned Equipment (PLANNED - does not exist yet)
**VERIFIED CURRENT STATE**: `globals.shopState.equipment` does NOT exist in the codebase.
  
**PLANNED CHANGES**:
- **Source of truth**: `globals.shopState.equipment` (new array, added in Task 0b)
- **Initialization location (AUTHORITATIVE)**: `assets/scripts/core/globals.lua` in the `shopState` table definition
  - Add at the same place where `globals.shopState.cards` is initialized
  - Pattern: `globals.shopState = { cards = {}, equipment = {}, ... }`
  - This ensures the field always exists on fresh runs and mid-run (no nil access risk)
  - NOT initialized in "first shop entry" - that would create race conditions and nil access before first shop

**EQUIPMENT DATA MODEL (def vs instance - CRITICAL DISTINCTION)**:

| Concept | Description | Where Stored | Shape |
|---------|-------------|--------------|-------|
| **Equipment Definition (def)** | Static template from data file | `data/equipment.lua` table | `{ id, name, description, sprite, rarity, cost, stats, tags }` |
| **Equipment Offering** | Shop display item (ref to def + sold state) | `active_shop_instance.equipmentOfferings[i]` | `{ equipmentDef, cost, rarity, sold }` |
| **Equipment Instance** | Purchased/owned copy with purchase history | `globals.shopState.equipment[i]` | Deep copy of def + `{ purchasePrice }` |

**Data flow**:
1. **Shop generation**: `equipmentOfferings[i].equipmentDef` points to original def from `data/equipment.lua`
2. **Purchase**: `ShopSystem.createEquipmentInstance(def)` makes deep copy, adds `purchasePrice`, stores in `globals.shopState.equipment`
3. **Entity creation**: `createEquipmentEntity(def, ...)` creates visual entity - receives DEF (not instance) for sprite/name/stats
4. **`_shopEquipRef`**: Points to INSTANCE (not def) - used for potential future sell feature to get `purchasePrice`

**Example usage in ShopUI buy flow**:
```lua
-- In slide-out "Buy" button handler:
local offering = state.activeShop.equipmentOfferings[slotIndex]
local success, instance = ShopSystem.purchaseEquipment(shop, slotIndex, player)
if success then
    -- instance is the INSTANCE (deep copy + purchasePrice)
    -- offering.equipmentDef is the original DEF
    local eid = ShopUI.createEquipmentEntity(offering.equipmentDef, -500, -500, nil)
    local script = getScriptTableFromEntityID(eid)
    if script then
        script._shopEquipRef = instance  -- Store INSTANCE for purchasePrice access
    end
end
```

- **Equipment entity creation**: New helper function based on `assets/scripts/examples/inventory_grid_demo.lua:117-155`:
  ```lua
  -- NEW function to create in shop_ui.lua
  -- Uses GameObject.methods.* pattern (like ui_syntax_sugar.lua:418) NOT Node.methods.*
  -- AUTHORITATIVE: Accepts DEFINITION (not instance) - instance is only needed for _shopEquipRef linkage
  -- The def provides: sprite, name, description, stats for visual/tooltip display
  local function createEquipmentEntity(equipmentDef, x, y, slotIndex)
      local sprite = equipmentDef.sprite or "frame0012.png" -- fallback icon
      local entity = animation_system.createAnimatedObjectWithTransform(
          sprite, true, x or 0, y or 0, nil, true
      )
      if not entity or not registry:valid(entity) then return nil end
      
      animation_system.resizeAnimationObjectsInEntityToFit(entity, 60, 84)
      
      -- Screen-space for UI rendering
      transform.set_space(entity, "screen")
      
      -- NOTE: Do NOT add ObjectAttachedToUITag - it excludes entities from shader rendering pipeline!
      
      -- Set up GameObject for hover/click detection
      -- Uses GameObject.methods.* pattern from assets/scripts/ui/ui_syntax_sugar.lua:418, assets/scripts/examples/inventory_grid_demo.lua:146-151
      local go = component_cache.get(entity, GameObject)
      if go then
          -- Enable hover/collision detection
          go.state.hoverEnabled = true
          go.state.collisionEnabled = true
          go.state.dragEnabled = false  -- Not draggable in shop
          
          -- Wire up hover callbacks on GameObject (NOT Node)
          go.methods.onHover = function(reg, hoveredOn, hovered)
              -- Equipment tooltip: show name, description, and stats
              -- TooltipV2.show uses { name, description, info = { stats, tags } } format
              -- Reference: assets/scripts/ui/tooltip_v2.lua:823-824
              TooltipV2.show(entity, {
                  name = equipmentDef.name,
                  description = equipmentDef.description or "Equipment",
                  info = {
                      stats = equipmentDef.stats or {},  -- e.g., { damage = 5, armor = 3 }
                      tags = equipmentDef.tags or {}
                  }
              })
          end
          go.methods.onStopHover = function(reg, hoveredOff)
              TooltipV2.hide(entity)
          end
          -- Only wire onClick if slotIndex is provided (shop offerings)
          -- Inventory equipment entities pass nil for slotIndex → no shop buy panel on click
          if slotIndex then
              go.methods.onClick = function(reg, clickedEntity)
                  ShopUI.showBuyPanel(slotIndex, "equipment")
              end
          else
              -- Inventory equipment: click does nothing (equip system is out of scope)
              go.methods.onClick = function() end
          end
      end
      
      -- Store equipment ID for identification (NOT _shopEquipRef - that's set only on purchase)
      local script = getScriptTableFromEntityID(entity) or {}
      setScriptTableForEntityID(entity, script)
      script.equipmentId = equipmentDef.id
      -- NOTE: _shopEquipRef is NOT set here - it's set by the caller AFTER purchase
      -- to link the entity to the equipment INSTANCE (with purchasePrice)
      
      return entity
  end
  ```
  
  **Equipment Entity Click Behavior by Context** (CRITICAL):
  | Context | `slotIndex` param | onClick behavior |
  |---------|------------------|------------------|
  | Shop offering | Number (1-3) | Opens buy panel via `ShopUI.showBuyPanel(slotIndex, "equipment")` |
  | Inventory (purchased) | `nil` | No-op (equip system out of scope) |
  
  This prevents nil-slot bugs and avoids unintended shop UI coupling for inventory equipment.
  
  **IMPORTANT: `_shopEquipRef` is set by CALLER, not by entity factory**:
  - `createEquipmentEntity()` only sets `script.equipmentId` for identification
  - After purchase, the caller sets `script._shopEquipRef = instance` (the purchased instance with `purchasePrice`)
  - This separation allows the same factory to be used for:
    - Shop offering entities (no `_shopEquipRef` - not yet purchased)
    - Inventory entities (has `_shopEquipRef` pointing to purchased instance)
- **Click/Hover mechanism**: Equipment uses `GameObject.methods.onHover/onClick` (pattern from `ui_syntax_sugar.lua:418`), NOT `Node.methods.*`. Cards use `Node.methods.*` because `createNewCard()` sets that up, but equipment entities are created manually.
- **Minimum required components for PlayerInventory**: Entity must have valid Transform (for positioning) and be in screen space. `PlayerInventory.addCard()` calls `CardUIPolicy.setupForScreenSpace()` which handles additional setup.
- **Tooltip API for equipment**: Use `TooltipV2.show(anchorEntity, data)` and `TooltipV2.hide(anchorEntity)`
  - Reference: `assets/scripts/ui/tooltip_v2.lua:824` - `TooltipV2.show(anchorEntity, data)` function definition
  - Reference: `assets/scripts/ui/tooltip_v2.lua:896` - `TooltipV2.hide(anchorEntity)` function definition
  - **CRITICAL: Data format uses `name`/`description`, NOT `title`/`body`**:
    ```lua
    -- Correct format (from tooltip_v2.lua:823)
    data = { 
        name = "Equipment Name",
        description = "What it does",
        info = { 
            stats = { damage = 5 },  -- optional stats table
            tags = { "melee" }       -- optional tags array
        }
    }
    ```
- **Tooltip data source for equipment**: `equipmentDef.name`, `equipmentDef.description`, and stats fields from `assets/scripts/data/equipment.lua`
- **Inventory insertion**: Use `PlayerInventory.addCard(entity, "equipment")` - equipment category exists

### Shop State Persistence & Locking (CRITICAL)
- **Shop instance**: `active_shop_instance` (module-level variable in gameplay.lua)
- **Also stored**: `globals.shopState.instance = active_shop_instance`
- **Lock state sources** (see `assets/scripts/core/gameplay.lua:9672-9690`):
  - `globals.shopUIState.locked` - **UI state (single source of truth for "is shop locked")**
  - `shop.locks[]` - Per-slot lock status (used by ShopSystem internally)
  - `setShopLocked(locked)` - Existing helper that syncs `globals.shopUIState.locked` AND loops all offerings calling `ShopSystem.lock/unlockOffering`
  - `regenerateShopState()` calls `setShopLocked(false)` at end (line 9493)
- **NO new `shop.isLocked` or `active_shop_instance.isLocked`** - Use existing `globals.shopUIState.locked` only
- **Lock persistence approach**:
  - **CRITICAL**: Interest is applied INSIDE `regenerateShopState()` at line 9480, NOT before it.
  - **Interest when locked**: When re-entering shop with locked state, interest MUST STILL be applied.
  - Insert lock check AFTER interest application, BEFORE shop generation:
    ```lua
    -- In regenerateShopState() (lines 9470-9495):
    function regenerateShopState()
        ensureShopSystemInitialized()
        ShopSystem.initUI()

        local playerLevel = (globals.shopState and globals.shopState.playerLevel) or 1
        local player = {
            gold = globals.currency or 0,
            cards = (globals.shopState and globals.shopState.cards) or {}
        }

        -- Interest is ALWAYS applied (even when locked)
        local interestEarned = ShopSystem.applyInterest(player)
        globals.currency = player.gold

        -- NEW: Check lock state AFTER interest, BEFORE generating new shop
        if globals.shopUIState and globals.shopUIState.locked and active_shop_instance then
            -- Preserve locked shop offerings, interest already applied above
            globals.shopState.lastInterest = interestEarned
            -- Refresh UI state from preserved instance
            globals.shopUIState.rerollCost = active_shop_instance.rerollCost
            globals.shopUIState.rerollCount = active_shop_instance.rerollCount
            return -- Don't regenerate offerings
        end

        active_shop_instance = ShopSystem.generateShop(playerLevel, player.gold)
        -- ... rest unchanged
    end
    ```
  - Do NOT modify `setShopLocked(false)` call at END of regenerateShopState - it correctly resets when generating NEW offerings
  - When ShopUI "Lock Shop" button clicked, call existing `setShopLocked(true)` function (extended in Task 10 to handle equipment)

### Equipment Offerings (NEW - to be added)
- **Source of truth**: `active_shop_instance.equipmentOfferings` (new array)
- **Generated by**: `ShopSystem.generateEquipmentOfferings(playerLevel)` in Task 0
- **Called from**: `regenerateShopState()` (modified in Task 10)

### Reroll Behavior for Equipment
- **Current `rerollOfferings()`** only rerolls `shop.offerings` (cards)
- **Plan**: Extend `rerollOfferings()` to also reroll `shop.equipmentOfferings`
- **Equipment locking**: Equipment uses `shop.equipmentLocks[]` parallel array (same pattern as `shop.locks[]` for cards)
- **Lock button behavior**: When "Lock Shop" button is clicked:
  1. UI calls existing `setShopLocked(true)` in `gameplay.lua:9672`
  2. `setShopLocked()` MUST BE EXTENDED (Task 10) to also lock equipment offerings
  3. Extended version calls `ShopSystem.lockShop(active_shop_instance)` which locks both cards and equipment
- This is an EXTENSION to lock/reroll logic, not a change to existing card-only behavior

---

## Work Objectives

### Core Objective
Replace the incomplete shop phase UI with a polished, Balatro-inspired shop window that allows purchasing cards and equipment with full buy/sell/reroll/lock functionality.

### Concrete Deliverables
- `assets/scripts/ui/shop_ui.lua` - Main shop UI module
- Modified `assets/scripts/ui/player_inventory.lua` - Add sell functionality (NOT card_inventory_panel.lua)
- Modified `assets/scripts/core/shop_system.lua` - Add lockShop, sellCard, equipment support
- Modified `assets/scripts/data/equipment.lua` - Add cost fields
- Modified `assets/scripts/core/gameplay.lua` - Replace initShopPhase with new UI
- `assets/scripts/tests/shop_system_test.lua` - Unit tests

### Definition of Done
- [ ] Shop UI displays centered on screen during shop phase
- [ ] 5 card offerings shown in horizontal row
- [ ] Equipment section shown below cards (if equipment exists)
- [ ] Clicking card shows slide-out buy panel
- [ ] Hover shows card details tooltip
- [ ] Unaffordable items greyed with red price
- [ ] Reroll button works with escalating cost
- [ ] Lock Shop button preserves all offerings
- [ ] Sell button opens inventory panel
- [ ] Cards can be sold from inventory at 50% price
- [ ] Gold display animates on changes
- [ ] "To Battle" and "To Planning" buttons work with transitions
- [ ] Lua unit tests pass
- [ ] Old shop_board code removed

### Must Have
- Balatro-style slide-out (click card → buy panel slides out)
- Bottom action bar with all buttons
- Animated gold display
- Lock entire shop functionality
- Sell from inventory at 50% price (**CARDS ONLY** - equipment is NOT sellable in this scope)
- Phase choice buttons

### Sell Scope Decision (EXPLICIT)
**Sell applies to CARDS ONLY. Equipment is NOT sellable.**

Rationale:
- The original request mentioned "Sell mechanic: 50% of purchase price" - this was discussed in context of cards
- Equipment system is being verified as part of this work, not fully integrated
- Keeping equipment non-sellable simplifies implementation and reduces risk
- Future enhancement: Add equipment sell feature after shop is proven working

### Must NOT Have (Guardrails)
- NO in-game pool configuration UI
- NO individual item locks (only full shop lock)
- NO new card/equipment definitions (only add cost field)
- NO changes to card rendering pipeline
- NO modifications to phase transition logic (use existing functions)
- NO tooltip system changes (use existing hover system)

---

## Verification Strategy (MANDATORY)

### Test Decision
- **Infrastructure exists**: YES (Lua test framework available)
- **User wants tests**: YES (Lua unit tests)
- **Framework**: Lua assert-based tests

### Test Coverage
1. **ShopSystem.sellCard()** - Verify 50% price calculation, gold increase, card removal
2. **ShopSystem.lockShop()** - Verify all offerings locked
3. **Shop UI state** - Verify offerings display correctly
4. **Unaffordable detection** - Verify greyed state when player.gold < cost

### Manual Verification
- Run game, enter shop phase
- Verify UI appears centered
- Click cards, verify slide-out
- Test all buttons
- Complete purchase flow
- Complete sell flow

---

## Task Flow

```
Task 0a (ShopSystem sell/lock - NO equipment)
    ↓
Task 0c (Add _shopCardRef linkage in gameplay.lua) ← depends on Task 0a
    ↓
Task 1 (PlayerInventory sell) ← depends on Task 0a AND Task 0c
    ↓
Task 2 (Equipment costs + getShopPool/getByRarity)
    ↓
Task 0b (ShopSystem equipment support) ← depends on Task 2
    ↓
Task 3 (Shop UI core) ← depends on Tasks 0a, 0b, 1, 2
    ↓
Task 4 (Card display)
Task 5 (Equipment display) ← parallel with Task 4
    ↓
Task 6 (Slide-out buy panel) ← depends on Tasks 4,5
    ↓
Task 7 (Action bar buttons)
    ↓
Task 8 (Gold animation)
    ↓
Task 9 (Phase transitions)
    ↓
Task 10 (Integration - replace old code, remove old boards)
    ↓
Task 11 (Unit tests)
    ↓
Task 12 (Manual QA)
```

## Parallelization

| Group | Tasks | Reason |
|-------|-------|--------|
| A | 4, 5 | Card display and equipment display are independent |

| Task | Depends On | Reason |
|------|------------|--------|
| 0a | none | Foundation sell/lock (no equipment yet) |
| 0c | 0a | Linkage requires purchasePrice from 0a |
| 1 | 0a, 0c | Sell uses ShopSystem.sellCard() AND requires _shopCardRef linkage |
| 2 | none | Equipment data structure changes |
| 0b | 2 | Equipment functions require Equipment.getShopPool() from Task 2 |
| 3 | 0a, 0b, 1, 2 | Shop UI needs all supporting systems ready |
| 6 | 4, 5 | Slide-out needs items to click on |
| 10 | 0-9 | Integration requires all features (old board removal only) |
| 11 | 10 | Tests verify integrated system |
| 12 | 11 | QA after tests pass |

---

## TODOs

- [ ] 0a. Extend ShopSystem with sell/lock support (NO equipment yet)

  **What to do**:
  - Add `ShopSystem.getSellPrice(cardInstance)` function:
    ```lua
    function ShopSystem.getSellPrice(card)
        if card.purchasePrice then
            return math.floor(card.purchasePrice * 0.5)
        end
        -- Fallback: use rarity base cost
        local rarity = card.rarity or "common"
        -- Normalize rarity (handle "Rare" vs "rare", "Epic" maps to "legendary")
        rarity = string.lower(rarity)
        if rarity == "epic" then rarity = "legendary" end
        local rarityDef = ShopSystem.rarities[rarity]
        if rarityDef then
            return math.floor(rarityDef.baseCost * 0.5)
        end
        return 1 -- Absolute fallback
    end
    ```
  - Add `ShopSystem.sellCard(cardInstance, player)` function:
    ```lua
    function ShopSystem.sellCard(card, player)
        -- Find card in player.cards
        local found = false
        for i, c in ipairs(player.cards) do
            if c == card then
                table.remove(player.cards, i)
                found = true
                break
            end
        end
        if not found then return false, 0 end
        
        local sellPrice = ShopSystem.getSellPrice(card)
        player.gold = player.gold + sellPrice
        return true, sellPrice
    end
    ```
  - Add `ShopSystem.lockShop(shop)` function:
    ```lua
    function ShopSystem.lockShop(shop)
        -- Lock all card offerings
        for i = 1, #shop.offerings do
            shop.locks[i] = true
        end
        -- Lock all equipment offerings (if present)
        if shop.equipmentOfferings then
            shop.equipmentLocks = shop.equipmentLocks or {}
            for i = 1, #shop.equipmentOfferings do
                shop.equipmentLocks[i] = true
            end
        end
    end
    ```
    - NOTE: Do NOT add `shop.isLocked` - the existing `globals.shopUIState.locked` handles UI state
  - Add `ShopSystem.unlockShop(shop)` function (card-only version, equipment support in Task 0b):
    ```lua
    function ShopSystem.unlockShop(shop)
        for i = 1, #shop.offerings do
            shop.locks[i] = false
        end
    end
    ```
  - Modify `ShopSystem.purchaseCard()` to set `purchasePrice` on the card instance:
    - Location: `assets/scripts/core/shop_system.lua:348` - AFTER `local cardInstance = ShopSystem.createCardInstance(offering.cardDef)`
    - Add on line 349 (immediately after the createCardInstance call, BEFORE adding to player.cards):
    ```lua
    cardInstance.purchasePrice = offering.cost
    ```

  **Must NOT do**:
  - Do not add equipment functions yet (Task 0b handles that after Task 2)
  - Do not add UI code to ShopSystem (it's data-only)

  **Parallelizable**: NO (foundation for Task 1)

  **References**:
  - `assets/scripts/core/shop_system.lua:347-348` - createCardInstance call where purchasePrice should be added
  - `assets/scripts/core/shop_system.lua:525-546` - createCardInstance pattern
  - `assets/scripts/core/shop_system.lua:368-376` - lockOffering pattern to follow
  - `assets/scripts/core/shop_system.lua:73-98` - Rarity definitions (lowercase keys: common, uncommon, rare, legendary)

  **Acceptance Criteria**:
  - [ ] `ShopSystem.getSellPrice(card)` returns correct price (50% of purchasePrice or fallback)
  - [ ] `ShopSystem.sellCard(card, player)` returns true, price when successful
  - [ ] Player gold increases by sell price after sellCard
  - [ ] Card removed from player.cards after sellCard
  - [ ] `ShopSystem.lockShop(shop)` sets all `shop.locks[i]` to true for each card offering
  - [ ] `ShopSystem.unlockShop(shop)` sets all `shop.locks[i]` to false for each card offering
  - [ ] Cards purchased via purchaseCard have purchasePrice field set
  - [ ] Rarity normalization handles "Rare"→"rare" and "Epic"→"legendary"

  **Commit**: YES
  - Message: `feat(shop): add sell and lock shop functionality to ShopSystem`
  - Files: `assets/scripts/core/shop_system.lua`
  - Pre-commit: Manual review

---

- [ ] 0b. Add equipment support to ShopSystem (AFTER Task 2)

  **What to do** (requires `Equipment.getShopPool()` from Task 2):
  - Add `ShopSystem.purchaseEquipment(shop, slotIndex, player)` function:
    ```lua
    function ShopSystem.purchaseEquipment(shop, slotIndex, player)
        local offering = shop.equipmentOfferings[slotIndex]
        if not offering or offering.sold then return false, nil end
        if player.gold < offering.cost then return false, nil end
        
        player.gold = player.gold - offering.cost
        
        -- Store in player.equipment (array of equipment instances)
        if not player.equipment then player.equipment = {} end
        local instance = ShopSystem.createEquipmentInstance(offering.equipmentDef)
        instance.purchasePrice = offering.cost
        table.insert(player.equipment, instance)
        
        offering.sold = true
        return true, instance
    end
    ```
  - Add `ShopSystem.createEquipmentInstance(equipmentDef)` - deep copies equipment def
  - Initialize equipment state in globals:
    - **AUTHORITATIVE LOCATION**: Add `equipment = {}` to `globals.shopState` definition in `assets/scripts/core/globals.lua`
    - Find the existing `globals.shopState = { cards = ... }` definition and add `equipment = {}` alongside `cards`
    - This ensures the field always exists from game startup (no nil access risk, no race conditions)
  - Add `ShopSystem.generateEquipmentOfferings(playerLevel)` function:
    ```lua
    function ShopSystem.generateEquipmentOfferings(playerLevel)
        local Equipment = require("data.equipment")
        local pool = Equipment.getShopPool()  -- From Task 2
        local offerings = {}
        
        -- Generate 3 equipment offerings
        for i = 1, 3 do
            local rarity = ShopSystem.selectRarity(playerLevel)
            local items = pool[rarity] or pool.common or {}
            if #items > 0 then
                local equipDef = items[math.random(1, #items)]
                table.insert(offerings, {
                    equipmentDef = equipDef,
                    cost = equipDef.cost,
                    rarity = rarity,
                    sold = false
                })
            end
        end
        return offerings
    end
    ```
  - Add `ShopSystem.generateEquipmentOffering(playerLevel)` single-offering function
  - Extend `ShopSystem.rerollOfferings(shop, player)` to also reroll equipment:
    - After existing card reroll logic (around line 400), add:
    ```lua
    -- Reroll unlocked equipment offerings (if present)
    -- Equipment uses equipmentLocks[] parallel array (same pattern as shop.locks[] for cards)
    if shop.equipmentOfferings then
        shop.equipmentLocks = shop.equipmentLocks or {}
        for i, offering in ipairs(shop.equipmentOfferings) do
            if not shop.equipmentLocks[i] and not offering.sold then
                shop.equipmentOfferings[i] = ShopSystem.generateEquipmentOffering(shop.playerLevel)
            end
        end
    end
    ```
  - Update `ShopSystem.lockShop(shop)` to also handle equipmentLocks[]:
    ```lua
    -- Add to lockShop() after card locks:
    if shop.equipmentOfferings then
        shop.equipmentLocks = shop.equipmentLocks or {}
        for i = 1, #shop.equipmentOfferings do
            shop.equipmentLocks[i] = true
        end
    end
    ```
  - Update `ShopSystem.unlockShop(shop)` similarly for equipmentLocks[]

  **Must NOT do**:
  - Do not change existing CARD reroll logic (only extend for equipment)
  - Do not add UI code to ShopSystem (it's data-only)

  **Parallelizable**: NO (depends on Task 2 for Equipment.getShopPool)

  **References**:
  - `assets/scripts/core/shop_system.lua:525-546` - createCardInstance pattern for createEquipmentInstance
  - `assets/scripts/core/shop_system.lua:391-408` - rerollOfferings to extend
  - `assets/scripts/data/equipment.lua` - Equipment.getShopPool() added in Task 2

  **Acceptance Criteria**:
  - [ ] `ShopSystem.purchaseEquipment(shop, slotIndex, player)` deducts gold and adds to player.equipment
  - [ ] Equipment instance has purchasePrice field set
  - [ ] `ShopSystem.generateEquipmentOfferings(playerLevel)` returns array of equipment offerings
  - [ ] Reroll correctly skips locked equipment (uses `shop.equipmentLocks[i]`)
  - [ ] `ShopSystem.lockShop(shop)` locks both card and equipment offerings
  - [ ] `ShopSystem.unlockShop(shop)` unlocks both card and equipment offerings

  **Commit**: YES
  - Message: `feat(shop): add equipment purchase and offerings support`
  - Files: `assets/scripts/core/shop_system.lua`
  - Pre-commit: Manual review

---

- [ ] 0c. Add _shopCardRef linkage in addPurchasedCardToInventory()

  **What to do** (enables sell feature in Task 1):
  - Modify `addPurchasedCardToInventory()` in `assets/scripts/core/gameplay.lua:9422-9439`
  - Add `script._shopCardRef = cardInstance` after entity creation:
    ```lua
    local function addPurchasedCardToInventory(cardInstance)
        if not cardInstance then return end
        local cardId = cardInstance.id or cardInstance.card_id or cardInstance.cardID
        if not cardId then return end

        local eid = createNewCard(cardId, -500, -500, PLANNING_STATE)
        local script = getScriptTableFromEntityID(eid)
        if script then
            script.selected = false
            script._shopCardRef = cardInstance  -- NEW: Link to purchased instance for sell
        end

        local PlayerInventory = require("ui.player_inventory")
        local category = getInventoryCategoryForCard(eid)
        PlayerInventory.addCard(eid, category)
        return eid
    end
    ```

  **Why this is a separate task**:
  - Task 1 (sell feature) depends on this linkage to function
  - Must be completed BEFORE Task 1 can be validated
  - Keeps Task 10 focused on integration/cleanup only

  **Must NOT do**:
  - Do not add equipment support yet (Task 10 handles that)
  - Do not modify other parts of gameplay.lua

  **Parallelizable**: NO (depends on Task 0a for purchasePrice)

  **References**:
  - `assets/scripts/core/gameplay.lua:9422-9439` - addPurchasedCardToInventory() to modify

  **Acceptance Criteria**:
  - [ ] `addPurchasedCardToInventory()` sets `script._shopCardRef = cardInstance`
  - [ ] Purchased cards now have `_shopCardRef` linking entity to card instance
  - [ ] Task 1 sell feature can now identify sellable cards

  **Commit**: YES
  - Message: `feat(shop): add _shopCardRef linkage for sell feature`
  - Files: `assets/scripts/core/gameplay.lua`
  - Pre-commit: Manual review

---

- [ ] 1. Add sell functionality to PlayerInventory (CARDS ONLY)

  **Scope**: Sell applies to **CARDS ONLY**. Equipment is NOT sellable in this implementation.

  **What to do** (Target: `assets/scripts/ui/player_inventory.lua`, NOT CardInventoryPanel):
  - Add to state table: `sellMode = false`
  - Add "Sell" button to footer bar in createFooter() and store entity reference for updates:
    ```lua
    local sellBtnDef = dsl.strict.button(state.sellMode and "Exit Sell" or "Sell", {
        id = "sell_mode_btn",
        minWidth = UI(60),
        minHeight = UI(24),
        fontSize = UI(11),
        color = state.sellMode and "red" or "jade_green",
        onClick = function()
            PlayerInventory.setSellMode(not state.sellMode)
        end,
    })
    ```
  - After panel is created, retrieve button entity via `ui.box.GetUIEByID()` (pattern from player_inventory.lua:183):
    ```lua
    -- After panel creation, look up button entity by ID
    state.sellButtonEntity = ui.box.GetUIEByID(registry, state.panelEntity, "sell_mode_btn")
    ```
  - Add `PlayerInventory.setSellMode(enabled)` function:
    ```lua
    function PlayerInventory.setSellMode(enabled)
        state.sellMode = enabled
        -- Update the sell button's visual state directly
        -- Uses component_cache.get pattern from player_inventory.lua:187-196
        if state.sellButtonEntity and registry:valid(state.sellButtonEntity) then
            -- Update color via UIConfig (like player_inventory.lua:591-592)
            local uiCfg = component_cache.get(state.sellButtonEntity, UIConfig)
            if uiCfg and _G.util and _G.util.getColor then
                uiCfg.color = enabled and _G.util.getColor("red") or _G.util.getColor("jade_green")
            end
            -- Update text via UITextComponent or UIConfig.text (like player_inventory.lua:187-196)
            local uiText = component_cache.get(state.sellButtonEntity, UITextComponent)
            if uiText then
                uiText.text = enabled and "Exit Sell" or "Sell"
            else
                local textCfg = component_cache.get(state.sellButtonEntity, UIConfig)
                if textCfg and textCfg.text ~= nil then
                    textCfg.text = enabled and "Exit Sell" or "Sell"
                end
            end
        end
        signal.emit("inventory_sell_mode_changed", enabled)
    end
    ```
  - **UI Refresh Strategy**: Store reference to sell button ENTITY (not UI element) in `state.sellButtonEntity` during footer creation. Update color via `UIConfig` component and text via `UITextComponent` or `UIConfig.text` - this follows the existing pattern in `assets/scripts/ui/player_inventory.lua:187-196` and `assets/scripts/ui/player_inventory.lua:591-592`.
  - **Sell Eligibility Decision**: Only shop-purchased cards are sellable (those with `_shopCardRef`). Pre-existing/starter cards cannot be sold.
  
  **Sell Mode vs Existing Right-Click Behavior (AUTHORITATIVE)**:
  - **Current behavior**: PlayerInventory's `onSlotClick` checks `if button == 2` for right-click lock toggle (but this is broken - grid emits `1` not `2`)
  - **Sell mode interaction rules**:
    - **In sell mode**: Left-click sells (cards only). Right-click is **DISABLED** (does nothing, no lock toggle).
    - **Not in sell mode**: Left-click normal selection. Right-click lock toggle (after fixing `button == 2` → `button == rightButton`).
  - **Rationale**: Prevents accidental lock toggle while trying to sell, and avoids confusion about what clicking does.
  - **Implementation**: Check `state.sellMode` FIRST in onSlotClick. If true and left-click, execute sell. If true and right-click, return early (no-op).
  
  **Prerequisite fix included in Task 1**: Fix the broken `button == 2` check to `button == rightButton` (value 1) for non-sell-mode right-click handling.
  
  - Modify onSlotClick to handle sell mode:
    ```lua
    -- Mouse button values passed to onSlotClick callback:
    -- From assets/scripts/ui/inventory_grid_init.lua:453-463, the callback receives:
    --   leftButton = MouseButton.MOUSE_BUTTON_LEFT or 0 (value: 0)
    --   rightButton = MouseButton.MOUSE_BUTTON_RIGHT or 1 (value: 1)
    -- NOTE: existing player_inventory.lua:413 uses "button == 2" which is WRONG (likely dead code)
    -- The correct pattern is from card_inventory_panel.lua:200-202
    local leftButton = MouseButton and MouseButton.MOUSE_BUTTON_LEFT or 0
    local rightButton = MouseButton and MouseButton.MOUSE_BUTTON_RIGHT or 1
    
    -- SELL MODE: Handle clicks specially
    if state.sellMode then
        if button == rightButton then
            -- In sell mode, right-click is DISABLED (no lock toggle)
            return
        end
        -- Continue to left-click sell logic below
    end
    
    if state.sellMode and button == leftButton then -- left click (value 0)
        local entity = grid.getItemAtIndex(gridEntity, slotIndex)  -- NOTE: Use getItemAtIndex, NOT getItemAt
        if entity and registry:valid(entity) then
            local ShopSystem = require("core.shop_system")
            -- Get entity's script table
            local script = getScriptTableFromEntityID(entity)
            if not script or not script._shopCardRef then
                -- Non-shop card: show warning and reject sell
                log_warn("[PlayerInventory] No _shopCardRef - cannot sell (starter/pre-existing card)")
                -- Optionally: show UI feedback to player (e.g., shake animation, red flash)
                return
            end
            local cardInstance = script._shopCardRef
            
            -- Create local player object (following codebase pattern from gameplay.lua:9475)
            local player = {
                gold = globals.currency or 0,
                cards = (globals.shopState and globals.shopState.cards) or {}
            }
            
            -- Execute sell
            local success, price = ShopSystem.sellCard(cardInstance, player)
            if success then
                -- Write back to globals (following pattern from gameplay.lua:9551)
                globals.currency = player.gold
                globals.shopState.cards = player.cards
                
                -- Remove from PlayerInventory using its API
                PlayerInventory.removeCard(entity)
                
                -- Destroy the entity to prevent accumulating hidden entities
                -- NOTE: PlayerInventory.removeCard() only hides, doesn't destroy
                
                -- CRITICAL: Remove from global cards table BEFORE destroying
                -- cards table is defined at gameplay.lua:448 and iterated every frame (lines 2345-2387)
                -- Sold inventory cards are createNewCard() entities (via addPurchasedCardToInventory)
                cards[entity] = nil
                
                -- Unregister from itemRegistry to avoid dangling references
                if itemRegistry and itemRegistry.unregister then
                    itemRegistry.unregister(entity)
                end
                -- Then destroy the entity
                if registry:valid(entity) then
                    registry:destroy(entity)
                end
                
                -- Emit signals
                signal.emit("card_sold", entity, price)
                -- Also emit deck_changed so tag system re-evaluates
                signal.emit("deck_changed", { source = "card_sold" })
            end
        end
        return -- Don't process normal click
    end
    ```
  - Emit `card_sold` signal with (cardEntity, sellPrice)
  - Emit `deck_changed` signal to notify tag system (same pattern as purchase in gameplay.lua:9569-9571)

  **Must NOT do**:
  - Do not change grid drag-drop behavior
  - Do not modify card rendering
  - Do not add sell button to individual cards

  **Parallelizable**: NO (depends on Task 0a for ShopSystem.sellCard AND Task 0c for _shopCardRef linkage)

  **References**:
  - `assets/scripts/ui/player_inventory.lua:1-50` - Module structure and API documentation
  - `assets/scripts/ui/player_inventory.lua:414` - `grid.getItemAtIndex()` usage (correct API, NOT `grid.getItemAt`)
  - `assets/scripts/ui/player_inventory.lua:1387-1415` - `PlayerInventory.removeCard()` implementation (hides but doesn't destroy)
  - `assets/scripts/ui/player_inventory.lua:591-592` - Dynamic button color update pattern using `uiCfg.color = util.getColor(...)`
  - `assets/scripts/core/inventory_grid.lua:170-180` - Grid API: `getItemAtIndex(gridEntity, slotIndex)` vs `getItemAt(gridEntity, row, col)`
  - `assets/scripts/core/shop_system.lua` - ShopSystem.getSellPrice and ShopSystem.sellCard (added in Task 0a)
  - `assets/scripts/core/gameplay.lua:9475-9488` - Local player object pattern to follow
  - `assets/scripts/core/gameplay.lua:9551-9553` - Write-back to globals pattern
  - `assets/scripts/core/gameplay.lua:9569-9571` - `deck_changed` signal emission pattern after purchase
  - `assets/scripts/ui/wand_panel.lua:733-734` - Example of dynamic button color update
  - `assets/scripts/chugget_code_definitions.lua:6641-6649` - **MouseButton constants** (MOUSE_BUTTON_LEFT=0, MOUSE_BUTTON_RIGHT=1, etc.)

  **Acceptance Criteria**:
  - [ ] "Sell" button appears in PlayerInventory footer
  - [ ] Clicking button toggles state.sellMode
  - [ ] Button text changes to "Exit Sell" when active
  - [ ] Clicking card in sell mode calls ShopSystem.sellCard with local player
  - [ ] After sell: globals.currency increases by sellPrice
  - [ ] After sell: card removed from globals.shopState.cards
  - [ ] **Card removed from `cards` table**: `cards[entity] = nil` BEFORE destroy (prevents render-loop stale entries)
  - [ ] Card entity removed from inventory via PlayerInventory.removeCard()
  - [ ] Card entity unregistered from itemRegistry before destruction
  - [ ] Card entity destroyed via registry:destroy() after removal
  - [ ] `card_sold` signal emitted with (cardEntity, sellPrice)
  - [ ] `deck_changed` signal emitted with { source = "card_sold" }
  - [ ] Non-shop cards (no `_shopCardRef`) show warning and cannot be sold
  - [ ] **Click detection uses correct button values**: `leftButton = 0` from `assets/scripts/ui/inventory_grid_init.lua:453-463`
  - [ ] **In sell mode, right-click is disabled**: Right-clicking a card in sell mode does nothing (no lock toggle)
  - [ ] **Existing `button == 2` bug fixed**: Changed to `button == rightButton` (value 1) for non-sell-mode right-click lock toggle

  **Commit**: YES
  - Message: `feat(inventory): add card sell functionality`
  - Files: `assets/scripts/ui/player_inventory.lua`
  - Pre-commit: Manual review

---

- [ ] 2. Add cost field to equipment definitions

  **What to do**:
  - Add `cost` field to each equipment item in `data/equipment.lua`
  - Normalize existing rarity values to lowercase ShopSystem keys:
    - "Common" → "common", "Uncommon" → "uncommon", "Rare" → "rare"
    - "Epic" → "legendary" (ShopSystem doesn't have "epic", map to legendary)
    - "Legendary" → "legendary"
  - Cost mapping based on normalized rarity:
    - common = 5
    - uncommon = 8
    - rare = 12
    - legendary = 18
  - Add `rarity` field (lowercase) if missing, default to "common"
  - **NOTE: `Equipment.getByRarity(rarity)` already exists** at `assets/scripts/data/equipment.lua:426`
    - Verify it works with normalized lowercase rarity keys after the normalization step
    - If needed, adjust the existing function to handle the lowercase normalization
  - Create `Equipment.getShopPool()` that returns equipment suitable for shop (this is NEW):
    ```lua
    function Equipment.getShopPool()
        local pool = { common = {}, uncommon = {}, rare = {}, legendary = {} }
        for id, def in pairs(Equipment) do
            if type(def) == "table" and def.rarity and pool[def.rarity] then
                table.insert(pool[def.rarity], def)
            end
        end
        return pool
    end
    ```

  **Must NOT do**:
  - Do not change equipment stats (damage, armor, etc.)
  - Do not add new equipment items
  - Do not modify equipment proc/effect logic

  **Parallelizable**: YES (independent data change)

  **References**:
  - `assets/scripts/data/equipment.lua` - Equipment definitions to modify (examine existing rarity field values)
  - `assets/scripts/data/equipment.lua:426` - **Existing `Equipment.getByRarity(rarity)` function** (already implemented!)
  - `assets/scripts/core/shop_system.lua:73-98` - Rarity definitions (keys are lowercase: common, uncommon, rare, legendary)

  **Acceptance Criteria**:
  - [ ] All equipment items have `cost` field (number)
  - [ ] All equipment items have `rarity` field (lowercase: common/uncommon/rare/legendary)
  - [ ] No equipment has rarity="Epic" (converted to "legendary")
  - [ ] **Existing** `Equipment.getByRarity("rare")` returns list of rare equipment (verify it works with lowercase keys)
  - [ ] **NEW** `Equipment.getShopPool()` returns pool table with rarity keys

  **Commit**: YES
  - Message: `feat(equipment): add cost and rarity fields for shop integration`
  - Files: `assets/scripts/data/equipment.lua`
  - Pre-commit: Manual review

---

- [ ] 3. Create ShopUI module foundation

  **What to do**:
  - Create `assets/scripts/ui/shop_ui.lua` module
  - Define state structure:
    ```lua
    local state = {
      isOpen = false,
      panelEntity = nil,
      activeShop = nil,    -- Reference to active_shop_instance passed to ShopUI.open()
      cardSlots = {},      -- 5 card offering entities
      equipmentSlots = {}, -- 3 equipment offering entities
      selectedSlot = nil,  -- { index = number, kind = "card"|"equipment" } or nil
      slideOutEntity = nil,
      -- NOTE: Lock state is derived from globals.shopUIState.locked (single source of truth)
      -- Do NOT cache isLocked locally - always read from globals.shopUIState.locked
    }
    ```
  - Define `ShopUI.showBuyPanel(slotIndex, kind)` function:
    ```lua
    function ShopUI.showBuyPanel(slotIndex, kind)
        state.selectedSlot = { index = slotIndex, kind = kind }
        -- Animate slide-out panel (see Task 6 for implementation)
        ShopUI._animateSlideOut()
    end
    ```
  - Implement `ShopUI.open(shop)` - creates centered window
  - Implement `ShopUI.close()` - cleanup entities (see Lifecycle/Cleanup Strategy below)
  - Implement `ShopUI.refresh(shop)` - update display from shop data
  - **Register ShopUI with globals.ui hook** (see Refresh Integration Contract below)
  - Create main window using DSL:
    - Root container centered on screen
    - Dark background with gold border (card game aesthetic)
    - Header: "SHOP" title + gold display
    - Content area placeholder
    - Footer: action buttons placeholder

  **Refresh Integration Contract (CRITICAL)**:
  
  The existing `gameplay.lua` has a global hook mechanism for shop UI refresh:
  - `refreshShopUIFromInstance(shop)` at ~line 9460 calls `globals.ui.refreshShopUIFromInstance(shop)` if present.
  - **VERIFIED**: Only `tryPurchaseShopCard()` calls this hook. `rerollActiveShop()` and `setShopLocked()` do NOT.
  
  **ShopUI registers itself** for the purchase flow that DOES use the hook:
  
  ```lua
  -- In ShopUI.open(), AFTER creating the panel:
  function ShopUI.open(shop)
      -- ... create panel, cards, etc. ...
      
      -- Register refresh hook for flows that call refreshShopUIFromInstance (only tryPurchaseShopCard)
      -- Reference: gameplay.lua:9460 - refreshShopUIFromInstance calls this if present
      globals.ui = globals.ui or {}
      globals.ui.refreshShopUIFromInstance = function(shopInstance)
          if state.isOpen then
              ShopUI.refresh(shopInstance or state.activeShop)
          end
      end
  end
  
  -- In ShopUI.close(), AFTER cleanup:
  function ShopUI.close()
      -- ... cleanup entities ...
      
      -- Unregister refresh hook (optional but clean)
      if globals.ui then
          globals.ui.refreshShopUIFromInstance = nil
      end
  end
  ```
  
  **What triggers refresh** (VERIFIED vs actual code):
  - `tryPurchaseShopCard()` → calls `refreshShopUIFromInstance()` → ShopUI.refresh() ✓ WORKS
  - `rerollActiveShop()` → does NOT call `refreshShopUIFromInstance()` ✗ NEEDS MANUAL REFRESH
  - `setShopLocked()` → does NOT call `refreshShopUIFromInstance()` ✗ NEEDS MANUAL REFRESH
  
  **SOLUTION: Manual refresh after button actions** (since reroll/lock don't use the hook):
  ShopUI button handlers MUST call `ShopUI.refresh()` explicitly after calling `rerollActiveShop()` or `setShopLocked()`:
  
  ```lua
  -- In Task 7 (action bar buttons):
  
  -- Reroll button onClick:
  function onRerollClick()
      rerollActiveShop()  -- Does NOT call refreshShopUIFromInstance internally
      ShopUI.refresh(active_shop_instance)  -- EXPLICIT refresh required
  end
  
  -- Lock button onClick:
  function onLockClick()
      local newLockState = not (globals.shopUIState and globals.shopUIState.locked)
      setShopLocked(newLockState)  -- Does NOT call refreshShopUIFromInstance internally
      ShopUI.refresh(active_shop_instance)  -- EXPLICIT refresh required
  end
  ```
  
  The `globals.ui.refreshShopUIFromInstance` hook is STILL registered for legacy flows (like `tryPurchaseShopCard()`),
  but ShopUI's own buttons don't rely on it - they call refresh directly.
  
  **Reference**: `assets/scripts/core/gameplay.lua:9460` - `refreshShopUIFromInstance()` function

  **Lifecycle/Cleanup Strategy (CRITICAL)**:
  `createNewCard()` registers cards into a long-lived `cards` table (line 448, 2341-2342) and uses 
  `timer.run_every_render_frame` renderer that iterates all cards (lines 2345-2387). 
  This creates a risk of stale entries accumulating.

  **Two categories of cleanup**:
  1. **UI tree entities** (panel, slide-out): Use `ui.box.Remove(registry, entity)` - NOT `registry:destroy()`
  2. **Sprite/card entities** (card offerings, equipment): Use `cards[entity] = nil` then `registry:destroy(entity)`

  **ShopUI.close() MUST**:
  1. **Cancel pending timers**: `timer.kill_group("shop_ui")` to prevent stale callbacks
  2. Remove card entities from `cards` table: `cards[entity] = nil` for each card
  3. Destroy card entities via `registry:destroy(entity)`
  4. Destroy equipment entities via `registry:destroy(entity)`
  5. Clear state arrays: `state.cardSlots = {}`, `state.equipmentSlots = {}`
  6. Remove UI panel via `ui.box.Remove()` (NOT `registry:destroy()`) to properly clean up child UI tree

  ```lua
  function ShopUI.close()
      -- CRITICAL: Cancel any pending shop timers (prevents stale callbacks)
      timer.kill_group("shop_ui")
      
      -- Cleanup card offering entities (sprite entities, NOT UI boxes)
      for _, cardEntity in ipairs(state.cardSlots) do
          if cardEntity and registry:valid(cardEntity) then
              -- Remove from global cards table to prevent render-loop accumulation
              cards[cardEntity] = nil
              registry:destroy(cardEntity)
          end
      end
      state.cardSlots = {}
      
      -- Cleanup equipment offering entities (sprite entities)
      for _, equipEntity in ipairs(state.equipmentSlots) do
          if equipEntity and registry:valid(equipEntity) then
              registry:destroy(equipEntity)
          end
      end
      state.equipmentSlots = {}
      
      -- Cleanup slide-out panel (UI box) - use ui.box.Remove, NOT registry:destroy
      if state.slideOutEntity and registry:valid(state.slideOutEntity) then
          if ui and ui.box and ui.box.Remove then
              ui.box.Remove(registry, state.slideOutEntity)
          end
      end
      state.slideOutEntity = nil
      
      -- Cleanup main panel (UI box) - use ui.box.Remove per card_inventory_panel.lua:705-707
      if state.panelEntity and registry:valid(state.panelEntity) then
          if ui and ui.box and ui.box.Remove then
              ui.box.Remove(registry, state.panelEntity)
          end
      end
      state.panelEntity = nil
      
      state.isOpen = false
      state.selectedSlot = nil
  end
  ```
  
  - Reference: `assets/scripts/core/gameplay.lua:2341-2342` - cards table registration
  - Reference: `assets/scripts/core/gameplay.lua:2345-2387` - card render timer that iterates cards table

  **Draw Layer Decision (CRITICAL)**:
  
  **Engine Draw Order** (from C++ `src/core/game.cpp:2189-2247`):
  ```
  background -> sprites -> ui -> final
  ```
  This means `layers.ui` is drawn AFTER `layers.sprites`, so UI elements naturally overlay sprites.
  
  **Problem**: If shop background panel is on `layers.ui` and cards are on `layers.sprites`, 
  the background would cover the cards (wrong!).
  
  **Solution**: Use `ui.box.set_draw_layer(entity, "sprites")` to draw the shop panel on `layers.sprites`,
  BEFORE the card entities. Then use z-order within `layers.sprites` to control stacking.
  
  **ShopUI Draw Layer Strategy**:
  1. **Shop panel background**: Draw on `"sprites"` layer via `ui.box.set_draw_layer(panelEntity, "sprites")`
  2. **Card entities**: Also on `layers.sprites` (default for batched card rendering)
  3. **Tooltips/Slide-out**: Draw on `"ui"` layer (drawn after sprites, so always on top)
  
  **Z-order within sprites layer**:
  - Shop background panel: `z_orders.board` (value: 100) - below cards
  - Card offerings: `z_orders.card` (value: 1001) - above background
  - Price text: `z_orders.card + 1` (value: 1002)
  
  **Tooltips/Slide-out on UI layer**:
  - Slide-out buy panel: `z_orders.ui_tooltips` (value: 1100) - on `"ui"` layer, above everything
  - Tooltip via TooltipV2: Already uses `"ui"` layer (see tooltip_v2.lua:542-545)
  
  **Available z_orders constants** (from `assets/scripts/core/z_orders.lua`):
  - `background = 0`
  - `board = 100`
  - `card = 1001`
  - `top_card = 1002`
  - `ui_transition = 1000`
  - `ui_tooltips = 1100`
  
  **Example setup in ShopUI.open()**:
  ```lua
  -- Create shop panel using dsl.spawn()
  -- CORRECT SIGNATURE: dsl.spawn(pos, defNode, layerName, zIndex, opts)
  -- Reference: assets/scripts/ui/ui_syntax_sugar.lua:515+ for dsl.spawn signature
  -- Reference: assets/scripts/ui/player_inventory.lua, assets/scripts/ui/card_inventory_panel.lua for usage patterns
  state.panelEntity = dsl.spawn({ x = centerX, y = centerY }, shopPanelDef)
  
  -- CRITICAL: Draw panel on sprites layer so cards appear ABOVE it
  if ui and ui.box and ui.box.set_draw_layer then
      ui.box.set_draw_layer(state.panelEntity, "sprites")
  end
  
  -- Set z-order for panel background (below cards)
  layer_order_system.assignZIndexToEntity(state.panelEntity, z_orders.board)
  ```
  
  **Manual Verification Step** (add to Task 12 QA):
  - Open shop, verify: cards visible above dark background
  - Hover card, verify: tooltip appears above card
  - Click card, verify: slide-out panel appears above card
  - If background covers cards: check `ui.box.set_draw_layer()` is called correctly
  
  **State Tag / Render Visibility Contract**:
  ShopUI should rely on `default_state` being active (the engine keeps this active).
  Card entities are tagged with `SHOP_STATE` by `createNewCard(id, x, y, SHOP_STATE)`.
  The card render loop (gameplay.lua:2351-2353) checks `is_state_active(SHOP_STATE)` before rendering.
  
  **Visibility requirements**:
  | Element | Draw Layer | Z-Order | State Tag |
  |---------|------------|---------|-----------|
  | Panel background | "sprites" | z_orders.board (100) | default_state (via DSL) |
  | Card entities | "sprites" | z_orders.card (1001) | SHOP_STATE |
  | Equipment entities | "sprites" | z_orders.card (1001) | default_state (screen-space) |
  | Slide-out panel | "ui" | z_orders.ui_tooltips (1100) | default_state |
  | TooltipV2 | "ui" | z_orders.ui_tooltips (1100) | handled by TooltipV2 |
  
  **State-Tagging (AUTHORITATIVE - matches PlayerInventory proven pattern)**:
  - **Shop panel + slide-out**: MUST explicitly call `ui.box.AddStateTagToUIBox()`.
    - This matches the proven pattern in `assets/scripts/ui/player_inventory.lua` which explicitly adds state tags.
    - **STANDARD SIGNATURE**: Use `ui.box.AddStateTagToUIBox(registry, boxEntity, tagName)` (3-arg form with registry)
      - Reference: `assets/scripts/ui/player_inventory.lua` uses this 3-arg form
      - NOTE: `tooltip_v2.lua` uses 2-arg form `(boxId, state)` - this is a different binding or deprecated pattern
      - **For ShopUI, use the 3-arg form consistently** to match PlayerInventory's proven approach
    - Add immediately after panel creation:
      ```lua
      -- CORRECT SIGNATURE: dsl.spawn(pos, defNode, layerName, zIndex, opts)
      -- Reference: assets/scripts/ui/ui_syntax_sugar.lua:515+ for dsl.spawn definition
      state.panelEntity = dsl.spawn({ x = centerX, y = centerY }, shopPanelDef)
      ui.box.AddStateTagToUIBox(registry, state.panelEntity, "default_state")  -- 3-arg form
      
      -- Similarly for slide-out when created:
      state.slideOutEntity = dsl.spawn({ x = slideX, y = slideY }, slideOutDef)
      ui.box.AddStateTagToUIBox(registry, state.slideOutEntity, "default_state")
      ```
  - **Card entities**: Get `SHOP_STATE` from `createNewCard(id, x, y, SHOP_STATE)`, which is activated during shop phase.
  - Reference: `assets/scripts/ui/player_inventory.lua` - proven pattern for panel state-tagging
  
  - Reference: `src/core/game.cpp:2189-2247` - C++ layer draw order (background -> sprites -> ui -> final)
  - Reference: `assets/scripts/core/gameplay.lua:2401-2406` - batched card rendering on layers.sprites
  - Reference: `assets/scripts/core/gameplay.lua:2351-2353` - state check: `if not is_state_active(SHOP_STATE)` bailout
  - Reference: `assets/scripts/core/z_orders.lua` - z_orders constant definitions
  - Reference: `assets/scripts/ui/player_inventory.lua:1127-1129` - example of `ui.box.set_draw_layer(entity, "sprites")`

  **Must NOT do**:
  - Do not implement card rendering yet (Task 4)
  - Do not implement button logic yet (Task 7)
  - Do not remove old code yet (Task 10)

  **Parallelizable**: NO (depends on 0a, 0b, 1, 2 being ready)

  **References**:
  - `assets/scripts/ui/card_inventory_panel.lua:481-508` - createPanelDefinition pattern
  - `assets/scripts/ui/card_inventory_panel.lua:636-673` - open() pattern
  - `assets/scripts/ui/ui_syntax_sugar.lua:89-102` - DSL reference (dsl.strict.root, dsl.strict.vbox, etc.) and color resolution
  - `assets/scripts/color/palette.lua` - Color token source (registered via util.getColor)
  - `assets/scripts/chugget_code_definitions.lua:12946` - `util.getColor(name)` binding definition (returns Color usertype from C++)

  **Acceptance Criteria**:
  - [ ] `ShopUI.open(shop)` creates centered window
  - [ ] Window has dark background with gold accents
  - [ ] Header shows "SHOP" title
  - [ ] `ShopUI.close()` removes all entities AND cleans up `cards` table references
  - [ ] `ShopUI.close()` destroys card entities via `registry:destroy()` and sets `cards[entity] = nil`
  - [ ] `ShopUI.close()` destroys equipment entities and clears `state.equipmentSlots`
  - [ ] `ShopUI.isOpen()` returns correct state
  - [ ] Opening/closing shop multiple times does not accumulate stale entries (memory leak test)
  - [ ] **Shop panel visible**: Panel renders correctly (if invisible, follow Troubleshooting steps in State-Tagging Decision section)
  - [ ] **Refresh hook registered**: `globals.ui.refreshShopUIFromInstance` is set in `ShopUI.open()` and cleared in `ShopUI.close()`
  - [ ] **Reroll updates display**: After clicking Reroll, card offerings refresh without closing/reopening shop
  
  **Memory Leak Verification Procedure** (objective test):
  ```lua
  -- Run this in console to verify no stale card accumulation
  local function countCards()
      local count = 0
      for _ in pairs(cards) do count = count + 1 end
      return count
  end
  
  -- Step 1: Note baseline card count (may include inventory cards)
  local baseline = countCards()
  print("Baseline cards:", baseline)
  
  -- Step 2: Open/close shop 5 times
  -- NOTE: Task 10 introduces a 1.4s delayed open via timer.after_opts
  -- For this test, call ShopUI.open() DIRECTLY to avoid timing issues
  for i = 1, 5 do
      local ShopUI = require("ui.shop_ui")
      ShopUI.open(active_shop_instance)  -- Direct call, no delay
      -- Immediately close
      ShopUI.close()
  end
  
  -- Step 3: Verify count is back to baseline (not baseline + 25 offerings)
  local afterCount = countCards()
  print("After 5 open/close cycles:", afterCount)
  assert(afterCount == baseline, 
      string.format("LEAK: Expected %d cards, found %d (leaked %d)", 
          baseline, afterCount, afterCount - baseline))
  print("Memory leak test PASSED")
  ```

  **Commit**: YES
  - Message: `feat(shop-ui): create ShopUI module foundation`
  - Files: `assets/scripts/ui/shop_ui.lua`
  - Pre-commit: Manual review

---

- [ ] 4. Implement card offerings display

  **What to do**:
  - Create 5 card entities from shop.offerings
  - Position in horizontal row within shop window
  - Use existing card rendering pattern (AnimationQueueComponent + shader_pipeline)
  - Implement hover detection for tooltips
  - Implement greyed-out state for unaffordable cards:
    - **Approach**: Use `animation_system.setFGColorForAllAnimationObjects(entity, tintColor)` to apply grey tint
    - Reference pattern: `assets/scripts/ui/message_queue_ui.lua:306-307` shows conditional tinting
    - Reference pattern: `assets/scripts/ui/showcase/showcase_registry.lua:341` shows tinting with util.getColor
    - For unaffordable: `animation_system.setFGColorForAllAnimationObjects(cardEntity, Col(128, 128, 128, 255))` (grey)
    - For affordable: `animation_system.setFGColorForAllAnimationObjects(cardEntity, Col(255, 255, 255, 255))` (white/normal)
    - Price text in red color via separate draw command
  - Implement click detection for slide-out trigger
  - Show rarity border color (use ShopSystem.rarities[].color)
  - Show price tag below each card

  **Must NOT do**:
  - Do not implement slide-out panel yet (Task 6)
  - Do not implement purchase logic in this task

  **Parallelizable**: YES (with Task 5)

  **References**:
  - `assets/scripts/ui/card_inventory_panel.lua:830-891` - createDummyCard pattern
  - `assets/scripts/ui/shop_pack_ui.lua:377-474` - drawCards pattern
  - `assets/scripts/core/shop_system.lua:268-321` - shop.offerings structure
  
  **Card Entity Creation for Shop Offerings** (CRITICAL):
  - **Use `createNewCard()` from gameplay.lua** (NOT animation_system directly) - this is the existing card factory that sets up all required components
  - `createNewCard(cardId, x, y, state)` at `assets/scripts/core/gameplay.lua:2266+`:
    - Creates entity via `animation_system.createAnimatedObjectWithTransform`
    - **CORRECTED**: The `x, y` parameters ARE used when provided (lines 2965-2972):
      ```lua
      -- In createNewCard(), after entity creation:
      if x and y then
          local t = component_cache.get(card, Transform)
          if t then
              t.actualX = x
              t.actualY = y
          end
      end
      ```
    - Attaches Node script with cardID, category, etc.
    - Gets `GameObject` component (confusingly named `nodeComp`) and wires callbacks
    - Sets up `nodeComp.methods.onHover`, `onStopHover`, `onClick`, `onRightClick`
    - Applies shader pipeline and state tags
  - **For shop UI**: 
    1. Call `createNewCard(offering.cardDef.id, screenX, screenY, SHOP_STATE)` - position is set by factory
    2. Set screen space after creation:
       ```lua
       local cardEntity = createNewCard(offering.cardDef.id, screenX, screenY, SHOP_STATE)
       transform.set_space(cardEntity, "screen")
       ```
    3. If repositioning later is needed, modify Transform directly:
       ```lua
       local t = component_cache.get(cardEntity, Transform)
       if t then
           t.actualX = newX
           t.actualY = newY
       end
       ```
  - Reference: `assets/scripts/core/gameplay.lua:2965-2972` - where createNewCard uses x,y params
  - **DO NOT add ObjectAttachedToUITag** - it excludes entities from shader rendering pipeline
  
  **Click/Hover Wiring via createNewCard** (CRITICAL - uses GameObject, NOT Node):
  - `createNewCard()` gets `local nodeComp = component_cache.get(card, GameObject)` at line 2662
  - **NOTE**: The variable is _named_ `nodeComp` but it's the `GameObject` component, NOT `Node`!
  - `createNewCard()` sets `dragEnabled=true` and `rightClickEnabled=true` (lines 2668-2669)
  - `onRightClick` triggers `transferCardViaRightClick()` (line 2826-2828) - MUST BE DISABLED for shop
  - `nodeComp.methods.onHover` calls `TooltipV2.showCard()` (lines 2830-2856)
  - `nodeComp.methods.onStopHover` calls `TooltipV2.hide()` (lines 2881-2898)
  - `nodeComp.methods.onClick` is available for buy panel trigger (line 2821)
  - **Shop-specific override**: After createNewCard, DISABLE drag/right-click and replace onClick:
    ```lua
    local cardEntity = createNewCard(offering.cardDef.id, 0, 0, SHOP_STATE)
    local t = component_cache.get(cardEntity, Transform)
    if t then
        t.actualX = screenX
        t.actualY = screenY
    end
    transform.set_space(cardEntity, "screen")
    
    -- CRITICAL: Use GameObject component (NOT Node) - the variable in createNewCard is misleadingly named "nodeComp"
    local goComp = component_cache.get(cardEntity, GameObject)
    if goComp then
        -- CRITICAL: DISABLE drag and right-click for shop offerings
        -- Without this, cards can be dragged around and right-click triggers transferCardViaRightClick!
        goComp.state.dragEnabled = false
        goComp.state.rightClickEnabled = false
        
        -- Override onClick for shop behavior
        goComp.methods.onClick = function(registry, clickedEntity)
            ShopUI.showBuyPanel(slotIndex, "card")
        end
        
        -- Override onRightClick to do nothing (defensive, since rightClickEnabled=false)
        goComp.methods.onRightClick = function() end
        
        -- Override onDrag to do nothing (defensive, since dragEnabled=false)
        goComp.methods.onDrag = function() end
        
        -- CRITICAL: Override onHover to prevent `card_ui_state.hovered_card` assignment!
        -- The default onHover from createNewCard() sets card_ui_state.hovered_card, which
        -- is polled by updateRightClickTransfer() independently of rightClickEnabled flag.
        -- We must override to ONLY show tooltip without setting hovered_card.
        -- Reference: gameplay.lua:2830-2856 - default onHover sets card_ui_state
        -- Reference: gameplay.lua:1847-1877 - updateRightClickTransfer uses card_ui_state.hovered_card
        goComp.methods.onHover = function(reg, hoveredOn, hovered)
            -- Show tooltip directly - DO NOT touch card_ui_state.hovered_card
            -- TooltipV2.showCard signature: showCard(anchorEntity, cardDef, opts)
            -- Reference: tooltip_v2.lua - cardDef must be a table with .id, .name, .description etc.
            -- Use offering.cardDef which was captured in this closure during card creation
            TooltipV2.showCard(cardEntity, offering.cardDef)
        end
        goComp.methods.onStopHover = function(reg, hoveredOff)
            TooltipV2.hide(cardEntity)
        end
    end
    ```
  
  **CRITICAL: TooltipV2.showCard Signature**:
  - Signature: `TooltipV2.showCard(anchorEntity, cardDef, opts)` 
  - `cardDef` must be a table with `.id`, `.name`, `.description` etc. - NOT an entity ID!
  - Reference: `assets/scripts/ui/tooltip_v2.lua` - function definition
  - For shop cards: use `offering.cardDef` (captured in closure during card creation loop)
  
  **Preventing Right-Click Transfer (CRITICAL - Global Loop Bypass)**:
  The problem: `updateRightClickTransfer()` at `gameplay.lua:1847-1877` polls `card_ui_state.hovered_card`
  and triggers `transferCardViaRightClick()` when right/ctrl/alt/cmd+click is detected. This bypasses
  the `goComp.state.rightClickEnabled` flag entirely!
  
  The `createNewCard()` default `onHover` handler (lines 2830-2856) sets `card_ui_state.hovered_card = card`.
  If we don't override this, shop-offering cards will be transferred when right-clicked.
  
  **Solution**: Override `onHover` and `onStopHover` on shop cards to call `TooltipV2.showCard/hide` directly
  WITHOUT setting `card_ui_state.hovered_card`. This prevents the global polling loop from seeing the card.
  
  **References**:
  - `assets/scripts/core/gameplay.lua:1847-1877` - `updateRightClickTransfer()` polls `card_ui_state.hovered_card`
  - `assets/scripts/core/gameplay.lua:2830-2856` - default onHover sets `card_ui_state.hovered_card = card`
  - `assets/scripts/core/gameplay.lua:local card_ui_state` - module-local state, not accessible from shop_ui.lua
  - Reference: `assets/scripts/core/gameplay.lua:2266-2898` - full createNewCard factory
  - Reference: `assets/scripts/core/gameplay.lua:2662` - where `nodeComp = component_cache.get(card, GameObject)` (confirms it's GameObject)
  - Reference: `assets/scripts/core/gameplay.lua:2668-2669` - dragEnabled and rightClickEnabled are set to true by default

  **Acceptance Criteria**:
  - [ ] 5 cards displayed in horizontal row
  - [ ] Cards show correct sprites from cardDef
  - [ ] Cards positioned via `createNewCard(id, screenX, screenY, SHOP_STATE)` - factory uses x,y params (line 2965-2972)
  - [ ] Cards set to screen space via `transform.set_space(cardEntity, "screen")`
  - [ ] Rarity border colors applied
  - [ ] Price shown below each card
  - [ ] Unaffordable cards are greyed with red price
  - [ ] Hover shows tooltip with card details
  - [ ] Click triggers selectedSlot update
  - [ ] **Drag is DISABLED** on shop cards (`goComp.state.dragEnabled = false`)
  - [ ] **Right-click is DISABLED** on shop cards (`goComp.state.rightClickEnabled = false`)
  - [ ] Cards cannot be dragged around the shop (verify by attempting drag)
  - [ ] Right-clicking cards does NOT trigger transferCardViaRightClick
  - [ ] **onHover overridden** to call `TooltipV2.showCard()` directly WITHOUT setting `card_ui_state.hovered_card`
  - [ ] **Right-click transfer loop bypass** prevented: right-click/ctrl-click/alt-click/cmd-click on shop cards does nothing (test: hover shop card, right-click, verify no transfer occurs and no inventory opens)

  **Commit**: YES
  - Message: `feat(shop-ui): implement card offerings display`
  - Files: `assets/scripts/ui/shop_ui.lua`
  - Pre-commit: Manual review

---

- [ ] 5. Implement equipment offerings display

  **What to do**:
  - Create equipment row below card row
  - Read equipment offerings from `active_shop_instance.equipmentOfferings` (generated by Task 0b)
  - Display exactly 3 equipment items (fixed count matching Task 0b's `generateEquipmentOfferings`)
  - Use equipment sprites (if available) or placeholder
  - Same hover/click/grey-out behavior as cards
  - Show equipment stats in tooltip

  **Must NOT do**:
  - Do not create new equipment rendering system
  - Do not implement equipment equip logic (shop only)

  **Parallelizable**: YES (with Task 4)

  **References**:
  - `assets/scripts/data/equipment.lua` - Equipment definitions and sprites
  - `assets/scripts/ui/shop_ui.lua` - Card display pattern from Task 4
  - `assets/scripts/examples/inventory_grid_demo.lua:117-155` - Entity creation pattern for screen-space items
  - `active_shop_instance.equipmentOfferings` - Source of equipment offerings (created by Task 0b)

  **Acceptance Criteria**:
  - [ ] Equipment row visible below cards
  - [ ] Exactly 3 equipment items displayed (fixed count)
  - [ ] Equipment items show name and price
  - [ ] Hover shows equipment stats
  - [ ] Grey-out for unaffordable items
  - [ ] Click triggers selectedSlot update

  **Commit**: YES
  - Message: `feat(shop-ui): implement equipment offerings display`
  - Files: `assets/scripts/ui/shop_ui.lua`
  - Pre-commit: Manual review

---

- [ ] 6. Implement Balatro-style slide-out buy panel

  **What to do**:
  - When card/equipment clicked, animate panel sliding out from behind
  - Panel contents:
    - Item name (small text)
    - Price with gold icon
    - "BUY" button (enabled if affordable)
    - "CANCEL" or click-away to dismiss
  - Animation: Use `timer.tween_fields()` or `timer.tween_scalar()` for smooth slide
  - Position panel to right of clicked item
  - Buy button behavior differs for cards vs equipment. Use local player pattern:
    ```lua
    -- Create local player (following gameplay.lua:9475 pattern)
    local player = {
        gold = globals.currency or 0,
        cards = (globals.shopState and globals.shopState.cards) or {},
        equipment = (globals.shopState and globals.shopState.equipment) or {}
    }
    
    -- NOTE: selectedSlot.kind is "card" or "equipment" (NOT .isEquipment boolean)
    local isEquipment = (state.selectedSlot.kind == "equipment")
    local success, instance
    if isEquipment then
        success, instance = ShopSystem.purchaseEquipment(state.activeShop, state.selectedSlot.index, player)
    else
        success, instance = ShopSystem.purchaseCard(state.activeShop, state.selectedSlot.index, player)
    end
    
    if success then
        -- Write back to globals (following gameplay.lua:9551 pattern)
        globals.currency = player.gold
        globals.shopState.cards = player.cards
        globals.shopState.equipment = player.equipment
        
        -- CRITICAL: addPurchasedCardToInventory is a LOCAL function in gameplay.lua
        -- ShopUI CANNOT call it directly. Instead, duplicate the logic inline:
        if isEquipment then
            -- Create equipment entity and add to inventory
            -- NOTE: Pass DEFINITION (from offering) for visual/tooltip, not instance
            -- instance is only used for _shopEquipRef linkage (stores purchasePrice)
            local offering = state.activeShop.equipmentOfferings[state.selectedSlot.index]
            local eid = ShopUI.createEquipmentEntity(offering.equipmentDef, -500, -500, nil)
            if eid then
                local script = getScriptTableFromEntityID(eid)
                if script then
                    script._shopEquipRef = instance  -- Future-proofing: link for potential sell feature (NOT used in this scope)
                end
                local PlayerInventory = require("ui.player_inventory")
                PlayerInventory.addCard(eid, "equipment")
            end
        else
            -- Create card entity and add to inventory (replicates addPurchasedCardToInventory logic)
            local cardId = instance.id or instance.card_id or instance.cardID
            if cardId then
                local eid = createNewCard(cardId, -500, -500, PLANNING_STATE)
                local script = getScriptTableFromEntityID(eid)
                if script then
                    script.selected = false
                    script._shopCardRef = instance  -- Link for sell feature (Task 0c adds this too)
                end
                local PlayerInventory = require("ui.player_inventory")
                local category = getInventoryCategoryForCard(eid)
                PlayerInventory.addCard(eid, category)
            end
        end
    end
    ```
  **AUTHORITATIVE PURCHASE PATH DECISION** (resolves duplication concern):
  
  After the redesign, there are TWO purchase paths that set `_shopCardRef`:
  1. **ShopUI purchase** (Task 6): ShopUI calls `ShopSystem.purchaseCard()`, then inlines inventory insertion with `_shopCardRef` linkage
  2. **Legacy `tryPurchaseShopCard()`** (Task 0c): Calls `addPurchasedCardToInventory()` which also sets `_shopCardRef`
  
  **AUTHORITATIVE ANSWER**: Both paths are valid and correctly set `_shopCardRef`. They are NOT redundant:
  - **ShopUI path** is used when buying from the new ShopUI (the primary flow after this work)
  - **Legacy path** remains for any code that still calls `tryPurchaseShopCard()` directly (e.g., debug/test scripts, ShopPackUI)
  
  **Why we don't export `addPurchasedCardToInventory()`**:
  - It's a local function in gameplay.lua (line 9422) - changing its scope affects many systems
  - ShopUI's inline version is identical and self-contained
  - Both paths end up with the same result: card entity with `_shopCardRef` in PlayerInventory
  
  **Equipment has only ONE path** (ShopUI), since equipment purchasing is new.
  - On purchase:
    - Play sound effect (playSoundEffect("effects", "shop-buy"))
    - Mark offering as sold (already done by purchaseCard/purchaseEquipment)
    - Refresh display to show sold state
    - Update gold display via ShopUI.refreshGold()
    - Close slide-out

  **Must NOT do**:
  - Do not show full card details (that's tooltip's job)
  - Do not allow purchasing if unaffordable (button disabled)

  **Parallelizable**: NO (depends on Tasks 4, 5)

  **References**:
  - `assets/scripts/core/gameplay.lua:1981-1998` - Timer tween pattern (uses `timer.tween_fields` for gold interest animation)
  - `assets/scripts/core/shop_system.lua:333-363` - ShopSystem.purchaseCard for cards
  - `assets/scripts/core/shop_system.lua` - ShopSystem.purchaseEquipment for equipment (added in Task 0)
  - `assets/scripts/ui/shop_pack_ui.lua:119-162` - Purchase flow pattern
  - `assets/scripts/core/timer.lua:258-262` - `timer.tween_opts()` API for animation
  - `assets/scripts/core/timer.lua:389-410` - `timer.tween_scalar()` API for single-value tweens
  - `assets/scripts/core/timer.lua:439-480` - `timer.tween_fields()` API for object property tweens

  **Acceptance Criteria**:
  - [ ] Clicking item shows slide-out panel
  - [ ] Panel animates smoothly from item position (using `timer.tween_fields` or `timer.tween_scalar`)
  - [ ] Panel shows price and Buy button
  - [ ] Buy button disabled when `globals.currency < offering.cost`
  - [ ] Clicking Buy on card calls ShopSystem.purchaseCard with local player
  - [ ] Clicking Buy on equipment calls ShopSystem.purchaseEquipment with local player
  - [ ] Purchase deducts gold: `globals.currency` decreased
  - [ ] Purchase adds card to `globals.shopState.cards` or equipment to `globals.shopState.equipment`
  - [ ] Card entity created via `createNewCard()`, positioned, and added to PlayerInventory
  - [ ] Card entity has `script._shopCardRef` set for sell feature
  - [ ] Equipment entity created via `ShopUI.createEquipmentEntity()` and added to PlayerInventory
  - [ ] Equipment entity has `script._shopEquipRef` set (future-proofing only; equipment is NOT sellable in this scope)
  - [ ] Item marked as sold and display refreshed
  - [ ] Clicking away dismisses panel
  - [ ] `state.selectedSlot.kind` (NOT `.isEquipment`) is used to distinguish card/equipment

  **Commit**: YES
  - Message: `feat(shop-ui): implement Balatro-style buy slide-out`
  - Files: `assets/scripts/ui/shop_ui.lua`
  - Pre-commit: Manual review

---

- [ ] 7. Implement action bar buttons

  **What to do**:
  - Create bottom bar with horizontal layout
  - Left side: Gold display (icon + `globals.currency` amount)
  - Right side buttons:
    - "Reroll" (cost displayed) - calls `rerollActiveShop()` (existing function in gameplay.lua:9498)
    - "Lock Shop" toggle - calls `setShopLocked(true/false)` (existing function in gameplay.lua:9672)
    - "Sell" - calls `PlayerInventory.open()` then `PlayerInventory.setSellMode(true)`
    - "To Planning" - placeholder (implemented in Task 9)
    - "To Battle" - placeholder (implemented in Task 9)
  - Reroll button:
    - Shows cost from `globals.shopUIState.rerollCost`
    - Disabled if `globals.currency < globals.shopUIState.rerollCost`
    - Calls `rerollActiveShop()` which handles gold deduction and writes back
    - **MUST call `ShopUI.refresh()` after rerollActiveShop()** (reroll does NOT use globals.ui hook)
  - Lock button:
    - Read state from `globals.shopUIState.locked`
    - Toggle text (Lock/Unlock)
    - Call `setShopLocked(not globals.shopUIState.locked)` - existing helper handles all lock logic
    - **MUST call `ShopUI.refresh()` after setShopLocked()** (lock does NOT use globals.ui hook)
  - Sell button:
    - Opens PlayerInventory (the actual inventory used by gameplay)
    - Sets it to sell mode

  **Must NOT do**:
  - Do not implement phase transitions yet (Task 9)
  - Do not implement gold animation yet (Task 8)
  - Do not reimplement lock logic - use existing `setShopLocked()`

  **Parallelizable**: NO (sequential after core UI)

  **References**:
  - `assets/scripts/ui/card_inventory_panel.lua:447-479` - Footer bar pattern
  - `assets/scripts/core/gameplay.lua:9498-9520` - rerollActiveShop() function to call
  - `assets/scripts/core/gameplay.lua:9672-9690` - setShopLocked() function to call
  - `assets/scripts/core/globals.lua:60` - globals.shopUIState (rerollCost, rerollCount, locked)
  - `assets/scripts/ui/player_inventory.lua` - PlayerInventory.open() and setSellMode()

  **Acceptance Criteria**:
  - [ ] Bottom bar visible with all buttons
  - [ ] Gold amount shows `globals.currency` correctly
  - [ ] Reroll shows cost from `globals.shopUIState.rerollCost` and works via `rerollActiveShop()`
  - [ ] **Reroll button calls `ShopUI.refresh()` AFTER `rerollActiveShop()`** (manual refresh required)
  - [ ] Lock toggles `globals.shopUIState.locked` via existing `setShopLocked()`
  - [ ] **Lock button calls `ShopUI.refresh()` AFTER `setShopLocked()`** (manual refresh required)
  - [ ] Sell opens PlayerInventory in sell mode
  - [ ] After reroll: card offerings visually update without closing/reopening shop

  **Commit**: YES
  - Message: `feat(shop-ui): implement action bar with reroll, lock, sell buttons`
  - Files: `assets/scripts/ui/shop_ui.lua`
  - Pre-commit: Manual review

---

- [ ] 8. Implement gold display animation

  **What to do**:
  - Create animated gold counter component
  - On gold change:
    - Tween from old value to new value
    - Scale pulse effect on completion
    - Color flash (green for gain, red for spend)
  - On shop open:
    - Show interest earned animation
    - "+Xg Interest" floating text that fades
  - Use existing timer system for animations

  **Must NOT do**:
  - Do not modify global gold display (this is shop-specific)
  - Do not change currency_display.lua

  **Parallelizable**: NO (after action bar)

  **References**:
  - `assets/scripts/core/gameplay.lua:1960-2061` - transitionGoldInterest pattern
  - `assets/scripts/ui/currency_display.lua` - Existing gold display reference
  - `assets/scripts/core/timer.lua` - Timer/tween system

  **Acceptance Criteria**:
  - [ ] Gold counter shows current amount (`globals.currency` value displayed correctly)
  - [ ] Spending gold shows decrease animation (counter tweens from old → new value)
  - [ ] Gaining gold shows increase animation (counter tweens from old → new value)
  - [ ] Interest shown on shop open ("+Xg Interest" text appears and fades)
  - [ ] **Animation timing is bounded**: Tween completes within 0.5 seconds (no infinite/stuck animations)
  - [ ] **Pulse effect fires once**: Scale pulse plays exactly once per gold change (not continuously)
  - [ ] **No lingering timers after close**: `ShopUI.close()` cancels gold animation timers via `timer.kill_group("shop_ui")`
  - [ ] **Observable verification**: After buying a 5g item, counter shows 5 less within 0.5s and pulse is visible

  **Commit**: YES
  - Message: `feat(shop-ui): implement animated gold display`
  - Files: `assets/scripts/ui/shop_ui.lua`
  - Pre-commit: Manual review

---

- [ ] 9. Implement phase transition buttons

  **What to do**:
  - "To Planning" button:
    - **CRITICAL: Kill shop timers FIRST** to cancel pending ShopUI.open() if clicked before shop fully opens
    - `timer.kill_group("shop_ui")` - cancels delayed open timer
    - Then calls ShopUI.close() (safe even if not yet open - checks state.isOpen)
    - Then calls startPlanningPhase()
    - Uses existing transition effects
  - "To Battle" button:
    - **CRITICAL: Kill shop timers FIRST** (same as above)
    - `timer.kill_group("shop_ui")`
    - Then calls ShopUI.close()
    - Then calls startActionPhase()
    - Uses existing transition effects
  - Add confirmation if player has unspent gold (optional warning)
  - Emit `shop_phase_complete` signal
  
  **Timer Cancellation Implementation** (CRITICAL for delayed open):
  If player clicks "To Planning" or "To Battle" before the 1.4s delay elapses (before ShopUI.open() fires),
  the pending timer must be cancelled. The button handlers MUST call `timer.kill_group("shop_ui")` BEFORE
  calling ShopUI.close() or starting the new phase. ShopUI.close() also kills the group (defensive),
  but the button click may happen before ShopUI is even open.
  
  ```lua
  -- Example button onClick for "To Planning":
  function onToPlanningClick()
      -- CRITICAL: Cancel pending open timer if shop hasn't opened yet
      timer.kill_group("shop_ui")
      
      -- Close shop if open (safe to call even if not open)
      local ShopUI = require("ui.shop_ui")
      if ShopUI.isOpen() then
          ShopUI.close()
      end
      
      -- Emit signal and transition
      signal.emit("shop_phase_complete")
      startPlanningPhase()
  end
  ```

  **Must NOT do**:
  - Do not modify transition effects
  - Do not change phase state machine logic

  **Parallelizable**: NO (after action bar)

  **References**:
  - `assets/scripts/core/gameplay.lua:8352-8416` - startShopPhase for transition pattern
  - `assets/scripts/core/gameplay.lua` - startPlanningPhase, startActionPhase functions

  **Acceptance Criteria**:
  - [ ] "To Planning" closes shop and starts planning phase
  - [ ] "To Battle" closes shop and starts action phase
  - [ ] Transitions use existing visual effects
  - [ ] `shop_phase_complete` signal emitted
  - [ ] **Button handlers call `timer.kill_group("shop_ui")` BEFORE ShopUI.close()**
  - [ ] **Clicking "To Planning" immediately after entering shop (before 1.4s) does NOT cause delayed ShopUI.open() to fire later**

  **Commit**: YES
  - Message: `feat(shop-ui): implement phase transition buttons`
  - Files: `assets/scripts/ui/shop_ui.lua`
  - Pre-commit: Manual review

---

- [ ] 10. Integration - replace old shop code

  **Understanding the lifecycle** (CRITICAL):
  - `initShopPhase()` (line 9698) is called ONCE at game startup from `main.lua:909` - it sets up persistent shop state
  - `startShopPhase()` (line 8352) is called EACH TIME player enters shop phase - this is where UI should open
  - The old code creates boards in `initShopPhase()` which is WRONG - boards should be created in `startShopPhase()`

  **What to do**:
  - Modify `startShopPhase()` (line 8352-8416):
    - Keep existing: state clearing, physics deactivation, SHOP_STATE activation
    - Keep existing: shader/music transitions via `oily_water_bg.apply_phase("shop")`
    - Keep existing: interest calculation and `transitionGoldInterest()` animation
    - **Note**: `transitionGoldInterest()` does NOT have a callback - it spawns a timed animation Node. 
      Use a timer delay to open ShopUI after animation completes:
      ```lua
      -- Inside startShopPhase, after transitionGoldInterest() call
      -- transitionGoldInterest runs for ~1.35s (see gameplay.lua:1960-2061)
      timer.after_opts({
          delay = 1.4, -- Slightly after interest animation duration (1.35s)
          action = function()
              local ShopUI = require("ui.shop_ui")
              ShopUI.open(active_shop_instance)
          end,
          tag = "open_shop_ui",
          group = "shop_ui"
      })
      ```
    - Add equipment offerings generation to `regenerateShopState()`:
      ```lua
      -- In regenerateShopState(), after generating card offerings:
      active_shop_instance.equipmentOfferings = ShopSystem.generateEquipmentOfferings(playerLevel)
      ```
    - Add shop lock persistence check to `regenerateShopState()` AFTER interest application:
      ```lua
      -- In regenerateShopState() at ~line 9481, AFTER interest is applied:
      -- Interest is ALWAYS applied (lines 9480-9481 unchanged)
      local interestEarned = ShopSystem.applyInterest(player)
      globals.currency = player.gold
      
      -- NEW: Insert lock check here
      if globals.shopUIState and globals.shopUIState.locked and active_shop_instance then
          -- Preserve locked shop offerings, interest already applied
          globals.shopState.lastInterest = interestEarned
          globals.shopUIState.rerollCost = active_shop_instance.rerollCost
          globals.shopUIState.rerollCount = active_shop_instance.rerollCount
          return -- Don't regenerate offerings
      end
      
      -- Rest unchanged: active_shop_instance = ShopSystem.generateShop(...)
      ```
  - Modify `initShopPhase()` (line 9698-9778):
    - REMOVE all shop_board and shop_buy_board creation code
    - REMOVE board-related state tags and text entities
    - KEEP `ShopPackUI.init()` call (currently at line ~9696) - this is separate feature
    - This function should now only contain: `ShopPackUI.init()`
  - Remove all obsolete shop board variables and code:
    - `shop_board_id` (line 1370)
    - `shop_buy_board_id` (line 1371)
    - Board assignments: `shop_board_id = shopBoardID` (line 9702)
    - Board assignments: `shop_buy_board_id = buyBoardID` (line 9734)
    - All board creation code in `initShopPhase()` (lines 9698-9778) except `ShopPackUI.init()`
  - Update any signals that referenced old boards (search for `shop_board`)
  - Extend `setShopLocked(locked)` (line 9672) to also lock/unlock equipment:
    ```lua
    -- In setShopLocked(locked), AFTER the existing card lock loop:
    -- Add equipment lock support (uses new ShopSystem.lockShop/unlockShop)
    if active_shop_instance then
        if locked then
            ShopSystem.lockShop(active_shop_instance)  -- Locks both cards and equipment
        else
            ShopSystem.unlockShop(active_shop_instance)  -- Unlocks both cards and equipment
        end
    end
    ```
    NOTE: This replaces the existing per-slot lock loop with the new ShopSystem helper that handles both cards and equipment.
  - **NOTE**: `_shopCardRef` linkage in `addPurchasedCardToInventory()` was done in Task 0c
  - Add similar function `addPurchasedEquipmentToInventory(equipInstance, equipDef)` following same pattern:
    ```lua
    -- NOTE: Takes BOTH instance (for _shopEquipRef/purchasePrice) and def (for visual/sprite)
    local function addPurchasedEquipmentToInventory(equipInstance, equipDef)
        if not equipInstance or not equipDef then return end
        
        -- Create equipment entity using DEF (for sprite/name/stats display)
        local ShopUI = require("ui.shop_ui")
        local eid = ShopUI.createEquipmentEntity(equipDef, -500, -500, nil)
        if not eid then return end
        
        local script = getScriptTableFromEntityID(eid)
        if script then
            script._shopEquipRef = equipInstance  -- Store INSTANCE (has purchasePrice) for future sell
        end
        
        local PlayerInventory = require("ui.player_inventory")
        PlayerInventory.addCard(eid, "equipment")
        return eid
    end
    ```

  **Must NOT do**:
  - Do not remove ShopPackUI (it's separate feature)
  - Do not change wave system integration
  - Do not call ShopUI.open() from initShopPhase() (it runs at startup!)

  **Parallelizable**: NO (requires all features complete)

  **References**:
  - `assets/scripts/core/gameplay.lua:8352-8416` - startShopPhase (where to ADD ShopUI.open call)
  - `assets/scripts/core/gameplay.lua:9698-9778` - initShopPhase (where to REMOVE old board code)
  - `assets/scripts/core/gameplay.lua:1370` - shop_board_id variable to remove
  - `assets/scripts/core/main.lua:909` - where initShopPhase is called (at startup, NOT per-phase)
  - `assets/scripts/core/gameplay.lua:9470-9493` - regenerateShopState() where active_shop_instance is created

  **Acceptance Criteria**:
  - [ ] Old shop_board and shop_buy_board code removed from initShopPhase()
  - [ ] `ShopPackUI.init()` still called in initShopPhase() (preserved)
  - [ ] shop_board_id variable removed
  - [ ] ShopUI.open() called from startShopPhase() AFTER interest animation (1.4s delay)
  - [ ] `addPurchasedCardToInventory()` sets `script._shopCardRef = cardInstance`
  - [ ] `regenerateShopState()` includes lock persistence check using `globals.shopUIState.locked`
  - [ ] `regenerateShopState()` generates equipment offerings
  - [ ] Game starts without errors (initShopPhase only calls ShopPackUI.init)
  - [ ] Entering shop phase opens ShopUI correctly
  - [ ] Interest animation still plays before shop opens
  - [ ] Phase transitions work correctly (action → shop → planning/action)
  - [ ] `setShopLocked()` extended to call `ShopSystem.lockShop/unlockShop` (handles equipment)
  - [ ] Interest still applies when re-entering locked shop (verified by: `globals.currency` increases)
  - [ ] Locked shop offerings unchanged on re-entry (verified by: same cards in same slots)
  - [ ] No console errors during shop phase
  - [ ] **Timer cancellation**: No ShopUI opens after leaving shop if delay timer is pending (test: enter shop phase, immediately leave before 1.4s elapses, verify no stale ShopUI.open() fires later)
  
  **Lock Persistence Verification Script** (run in console during manual QA):
  ```lua
  -- PRECONDITION: Ensure player has >= 10 gold so interest > 0
  -- Interest formula: 1g per 10g held, capped at 5g (shop_system.lua:491-504)
  -- If gold < 10, interest will be 0 and gold check will fail spuriously
  
  -- Step 1: Enter shop, ensure sufficient gold, note initial state
  if globals.currency < 10 then
      globals.currency = 10  -- Ensure interest is earned
      print("Set gold to 10 for test precondition")
  end
  local gold1 = globals.currency
  local offer1 = active_shop_instance.offerings[1].cardDef.id
  
  -- Step 2: Lock shop
  setShopLocked(true)
  
  -- Step 3: Leave shop (To Planning/Battle)
  -- Step 4: Re-enter shop
  
  -- Step 5: Verify
  local gold2 = globals.currency
  local offer2 = active_shop_instance.offerings[1].cardDef.id
  local expectedInterest = math.min(5, math.floor(gold1 / 10))  -- Interest formula
  
  -- Use lastInterest field if available (more reliable than gold comparison)
  local actualInterest = globals.shopState.lastInterest or (gold2 - gold1)
  
  -- Interest check: either gold increased OR lastInterest recorded correctly
  if gold1 >= 10 then
      assert(gold2 >= gold1 + expectedInterest, 
          string.format("Interest not applied: expected +%d, got %d->%d", expectedInterest, gold1, gold2))
  else
      print("Warning: gold < 10, interest may be 0 (this is expected)")
  end
  
  -- Offerings unchanged check
  assert(offer1 == offer2, "Offerings changed despite lock")
  print(string.format("Lock persistence OK: gold %d -> %d (+%d interest), offering unchanged: %s", 
      gold1, gold2, gold2 - gold1, offer1))
  ```

  **Commit**: YES
  - Message: `refactor(gameplay): integrate ShopUI, remove old shop boards`
  - Files: `assets/scripts/core/gameplay.lua`
  - Pre-commit: Manual review

---

- [ ] 11. Write Lua unit tests

  **What to do**:
  - Create `assets/scripts/tests/shop_system_test.lua`
  - Follow existing test pattern from `assets/scripts/tests/test_timer_dual_signature.lua`:
    - Set up package.path for module resolution
    - Mock dependencies (util.getColor, etc.)
    - Use test_runner for assertions
  - Test file structure (using actual test_runner.lua API from `assets/scripts/tests/test_runner.lua`):
    ```lua
    --[[
    ================================================================================
    TEST: ShopSystem Sell/Lock Functions
    ================================================================================
    Run with: lua assets/scripts/tests/shop_system_test.lua
    NOTE: This test uses os.exit() on completion - run from CLI, NOT in-game console
    ]]

    --------------------------------------------------------------------------------
    -- Setup: Adjust package path (like test_timer_dual_signature.lua:19-20)
    --------------------------------------------------------------------------------
    package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"
    
    --------------------------------------------------------------------------------
    -- CRITICAL: Mock ui.ui_defs BEFORE requiring shop_system
    -- shop_system.lua requires "ui.ui_defs" at module load, which needs UI builder globals
    -- that don't exist in CLI. We stub the module path to prevent the require chain.
    --------------------------------------------------------------------------------
    
    -- Stub ui.ui_defs to prevent loading engine-only UI builders
    -- (UIElementTemplateNodeBuilder, UIConfigBuilder, UITypeEnum are not available in CLI)
    package.loaded["ui.ui_defs"] = {
        -- Minimal stub - shop_system only uses ui_defs for ShopSystem.initUI()
        -- Our tests don't call initUI(), so an empty stub is sufficient
    }
    
    -- Load engine mocks for other globals
    -- NOTE: engine_mock.lua may need extension if tests start failing
    require("tests.mocks.engine_mock")  -- Sets up _G.ui, _G.registry, etc.
    
    -- Additional mocks specific to shop_system (may not be in engine_mock)
    _G.log_debug = _G.log_debug or function() end
    _G.log_error = _G.log_error or function(...) print("[ERROR]", ...) end
    _G.util = _G.util or { getColor = function(c) return c end }
    
    -- Clear cached module to get fresh instance
    package.loaded["core.shop_system"] = nil
    
    local ShopSystem = require("core.shop_system")
    local t = require("tests.test_runner")
    
    --------------------------------------------------------------------------------
    -- Tests (using expect().to_be() API from test_runner.lua)
    --------------------------------------------------------------------------------
    
    t.describe("ShopSystem.getSellPrice", function()
        t.it("returns 50% of purchasePrice when present", function()
            local card = { purchasePrice = 10, rarity = "common" }
            local price = ShopSystem.getSellPrice(card)
            t.expect(price).to_be(5)
        end)
        
        t.it("falls back to rarity baseCost when no purchasePrice", function()
            local card = { rarity = "rare" } -- rare baseCost = 8
            local price = ShopSystem.getSellPrice(card)
            t.expect(price).to_be(4) -- 50% of 8
        end)
    end)
    
    -- ... more test blocks ...
    
    -- Run tests and exit (CLI-only, NOT for in-game console)
    local success = t.run()
    os.exit(success and 0 or 1)
    ```
  - Test cases:
    1. `test_getSellPrice_with_purchasePrice` - Use 50% of purchasePrice
    2. `test_getSellPrice_without_purchasePrice` - Fallback to rarity baseCost
    3. `test_getSellPrice_rarity_normalization` - "Rare" → "rare", "Epic" → "legendary"
    4. `test_sellCard_success` - Verify gold increase and card removal
    5. `test_sellCard_not_owned` - Returns false when card not in player.cards
    6. `test_lockShop` - Verify all `shop.locks[i] = true` for each offering (NO `shop.isLocked`)
    7. `test_unlockShop` - Verify all `shop.locks[i] = false` for each offering

  **Must NOT do**:
  - Do not test UI rendering (manual only)
  - Do not require actual game state (mock player object)

  **Parallelizable**: NO (after integration)

  **References**:
  - `assets/scripts/tests/test_timer_dual_signature.lua` - Test pattern to follow
  - `assets/scripts/tests/mocks/engine_mock.lua:162` - Mock util.getColor pattern
  - `assets/scripts/core/shop_system.lua:73-98` - Rarity definitions for test assertions

  **Acceptance Criteria**:
  - [ ] All 7 test cases written using test_runner framework (uses `t.expect(...).to_be(...)` API)
  - [ ] Tests can be run via `lua assets/scripts/tests/shop_system_test.lua` from repo root
  - [ ] Package path configured correctly (see test_timer_dual_signature.lua:19-20)
  - [ ] **`ui.ui_defs` stubbed via `package.loaded["ui.ui_defs"] = {}`** to avoid UI builder globals
  - [ ] Uses `t.run()` (NOT `t.run_tests()`) per actual test_runner.lua API
  - [ ] Test file ends with `os.exit()` (CLI-only, NOT safe for in-game console)
  - [ ] All tests pass (7/7)
  - [ ] Output shows test results in standard format
  - [ ] **VERIFIED BY RUNNING**: Execute `lua assets/scripts/tests/shop_system_test.lua` from repo root and confirm exit code 0

  **Commit**: YES
  - Message: `test(shop): add unit tests for shop system sell and lock functions`
  - Files: `assets/scripts/tests/shop_system_test.lua`
  - Pre-commit: Run tests

---

- [ ] 12. Manual QA verification

  **What to do**:
  - Run game and navigate to shop phase
  - Verify checklist:
    - [ ] Shop UI appears centered
    - [ ] Cards display correctly with rarity borders
    - [ ] Equipment displays in separate row
    - [ ] Hover shows tooltips
    - [ ] Click shows slide-out buy panel
    - [ ] Buy button works
    - [ ] Unaffordable items greyed
    - [ ] Reroll button works
    - [ ] Lock shop button works
    - [ ] Sell opens inventory
    - [ ] Can sell cards from inventory
    - [ ] Gold animates on changes
    - [ ] "To Planning" works
    - [ ] "To Battle" works
    - [ ] No console errors
    - [ ] **Right-click transfer bypass prevented** (CRITICAL - see verification script below)
  - Document any issues found
  
  **Right-Click Transfer Smoke Test** (CRITICAL integration test):
  ```lua
  -- Run this in console while in shop phase
  -- Tests that shop offerings do NOT trigger updateRightClickTransfer()
  
  -- Step 1: Hover over a shop card
  print("Step 1: Hover over any shop card offering")
  print("Step 2: Right-click, ctrl+click, alt+click, and cmd+click the hovered card")
  print("Step 3: Verify each input produces NO action:")
  print("  - No inventory panel opens")
  print("  - No card transfer occurs")
  print("  - No error in console")
  print("  - Tooltip may hide (that's OK)")
  print("")
  print("If any transfer/inventory action occurs, the onHover override is missing or incorrect.")
  print("Check Task 4's goComp.methods.onHover override - it must NOT set card_ui_state.hovered_card")
  ```
  
  **Panel Visibility Troubleshooting** (if shop panel is invisible):
  1. Verify `ui.box.set_draw_layer(panelEntity, "sprites")` is called in ShopUI.open()
  2. Verify z-order: `layer_order_system.assignZIndexToEntity(panelEntity, z_orders.board)`
  3. If still invisible, add explicit state tag: `ui.box.AddStateTagToUIBox(panelEntity, "default_state")`
  4. Check `default_state` is active: run `print(is_state_active(default_state))` in console

  **Must NOT do**:
  - Do not fix issues in this task (create follow-up tasks)

  **Parallelizable**: NO (final task)

  **References**:
  - All previous tasks
  - Game build/run commands

  **Acceptance Criteria**:
  - [ ] All checklist items verified
  - [ ] No blocking bugs found
  - [ ] Performance acceptable (no lag)
  - [ ] **Right-click transfer smoke test PASSED**: Right-click/ctrl-click/alt-click/cmd-click on shop offerings produces no action
  - [ ] **Panel visibility verified**: Shop panel renders above nothing, cards render above panel

  **Commit**: NO (verification only)

---

## Commit Strategy

| After Task | Message | Files | Verification |
|------------|---------|-------|--------------|
| 0a | `feat(shop): add sell and lock shop functionality` | shop_system.lua | Code review |
| 0c | `feat(shop): add _shopCardRef linkage for sell feature` | gameplay.lua | Code review |
| 1 | `feat(inventory): add card sell functionality` | player_inventory.lua | Code review |
| 2 | `feat(equipment): add cost and rarity fields` | equipment.lua | Code review |
| 0b | `feat(shop): add equipment purchase and offerings support` | shop_system.lua | Code review |
| 3 | `feat(shop-ui): create ShopUI module foundation` | shop_ui.lua | Code review |
| 4 | `feat(shop-ui): implement card offerings display` | shop_ui.lua | Code review |
| 5 | `feat(shop-ui): implement equipment offerings display` | shop_ui.lua | Code review |
| 6 | `feat(shop-ui): implement Balatro-style buy slide-out` | shop_ui.lua | Code review |
| 7 | `feat(shop-ui): implement action bar buttons` | shop_ui.lua | Code review |
| 8 | `feat(shop-ui): implement animated gold display` | shop_ui.lua | Code review |
| 9 | `feat(shop-ui): implement phase transition buttons` | shop_ui.lua | Code review |
| 10 | `refactor(gameplay): integrate ShopUI, remove old boards` | gameplay.lua | Manual test |
| 11 | `test(shop): add unit tests` | shop_system_test.lua | Run tests |

---

## Success Criteria

### Verification Commands
```bash
# Build and run game
./build/raylib-cpp-cmake-template

# Run unit tests from CLI (NOT in-game console - test uses os.exit())
lua assets/scripts/tests/shop_system_test.lua
# Expected: All tests pass, exit code 0
```

### Final Checklist
- [ ] All "Must Have" features implemented
- [ ] All "Must NOT Have" guardrails respected
- [ ] All unit tests pass
- [ ] Manual QA checklist complete
- [ ] No console errors during shop phase
- [ ] Performance acceptable
