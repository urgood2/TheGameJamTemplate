--[[
================================================================================
WAND GRID ADAPTER - Bridge between Grid Inventory and WandExecutor
================================================================================

Adapts the new grid-based inventory system to the WandExecutor interface.
Replicates the behavior of collectCardPoolForBoardSet() for card pool building.

QUICK REFERENCE:
---------------
local adapter = require("ui.wand_grid_adapter")

-- Initialize with wand definitions (call once at game start)
adapter.init(wandDefinitions)  -- array of wand def tables

-- Set trigger card for a wand
adapter.setTrigger(wandIndex, cardEntity)

-- Set action card in a specific slot
adapter.setAction(wandIndex, slotIndex, cardEntity)

-- Clear a specific slot (nil removes it)
adapter.clearSlot(wandIndex, slotIndex)

-- Get current loadout for a wand
local loadout = adapter.getLoadout(wandIndex)
-- Returns: { trigger = entity|nil, actions = { [slotIndex] = entity } }

-- Collect card pool for combat (matches legacy collectCardPoolForBoardSet)
local pool = adapter.collectCardPool(wandIndex)
-- Returns: ordered array with modifiers BEFORE base cards, plus always-cast

-- Dirty flag management (optimization for sync)
adapter.markDirty(wandIndex)        -- Force dirty (auto-set on changes)
adapter.isDirty(wandIndex)          -- Check if needs sync
adapter.anyDirty()                  -- Check if any wand needs sync

-- Sync to executor (call before entering combat)
local syncedCount = adapter.syncToExecutor()

DATA FLOW:
---------
Grid UI → WandGridAdapter → WandExecutor.loadWand()

The adapter maintains a shadow copy of grid contents to build card pools
without needing to query grid entities. When a grid fires transfer events,
the adapter updates its internal state.

CARD POOL ORDER (Critical for Combat):
--------------------------------------
For each action card in slot order (left to right):
  1. Push all modifier cards from cardScript.cardStack (if any)
  2. Push the base card itself
After all action cards:
  3. Append always-cast cards from wandDef.always_cast_cards

This ordering matches the legacy collectCardPoolForBoardSet() exactly.

================================================================================
]]

local adapter = {}

-- Internal state: tracks cards assigned to each wand
-- Structure: { [wandIndex] = { wandDef = {...}, trigger = entity|nil, actions = { [slot] = entity }, dirty = bool } }
local _wandSlots = {}

-- Wand definitions provided during init
local _wandDefinitions = {}

-- Virtual card counter for always-cast cards
local _virtualCardCounter = 0

-- Cached card pool for WandEngine (lazy access to avoid circular require)
local _cachedWandEngine = nil
local function getWandEngine()
    if not _cachedWandEngine then
        -- Try to access WandEngine global (set up by combat system)
        _cachedWandEngine = _G.WandEngine
    end
    return _cachedWandEngine
end

-- Entity validation helper
local function isValidEntity(eid)
    if not eid then return false end
    if entity_cache and entity_cache.valid then
        return entity_cache.valid(eid)
    end
    -- Fallback: check registry
    return registry and registry:valid(eid)
end

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

--- Initialize the adapter with wand definitions.
-- Call once at game start with the array of wand definitions.
-- @param wandDefinitions Array of wand definition tables (e.g., from WandEngine.wand_defs)
-- @return boolean Success
function adapter.init(wandDefinitions)
    if not wandDefinitions then
        log_warn("[WandGridAdapter] init() called with nil wandDefinitions")
        return false
    end

    _wandDefinitions = wandDefinitions
    _wandSlots = {}

    -- Pre-create slots for each wand
    for index, wandDef in ipairs(wandDefinitions) do
        _wandSlots[index] = {
            wandDef = wandDef,
            trigger = nil,
            actions = {},
            dirty = true,  -- Start dirty to force initial sync
        }
    end

    -- Reset virtual card counter
    _virtualCardCounter = 0

    log_debug(string.format("[WandGridAdapter] Initialized with %d wand definitions", #wandDefinitions))
    return true
end

--------------------------------------------------------------------------------
-- Trigger Management
--------------------------------------------------------------------------------

--- Set the trigger card for a wand.
-- @param wandIndex 1-based wand index
-- @param cardEntity Entity ID of trigger card (or nil to clear)
-- @return boolean Success
function adapter.setTrigger(wandIndex, cardEntity)
    if not wandIndex or wandIndex < 1 then
        log_warn("[WandGridAdapter] setTrigger: invalid wandIndex")
        return false
    end

    -- Auto-expand slots if needed (defensive)
    if not _wandSlots[wandIndex] then
        if _wandDefinitions[wandIndex] then
            _wandSlots[wandIndex] = {
                wandDef = _wandDefinitions[wandIndex],
                trigger = nil,
                actions = {},
                dirty = true,
            }
        else
            log_warn(string.format("[WandGridAdapter] setTrigger: no wand definition for index %d", wandIndex))
            return false
        end
    end

    local previousTrigger = _wandSlots[wandIndex].trigger
    _wandSlots[wandIndex].trigger = cardEntity
    _wandSlots[wandIndex].dirty = true  -- Mark dirty on change

    if cardEntity then
        log_debug(string.format("[WandGridAdapter] Set trigger for wand %d: entity %s (was %s)",
            wandIndex, tostring(cardEntity), tostring(previousTrigger)))
    else
        log_debug(string.format("[WandGridAdapter] Cleared trigger for wand %d (was %s)",
            wandIndex, tostring(previousTrigger)))
    end

    return true
end

--------------------------------------------------------------------------------
-- Action Card Management
--------------------------------------------------------------------------------

--- Set an action card in a specific slot.
-- @param wandIndex 1-based wand index
-- @param slotIndex 1-based slot index within the wand's action grid
-- @param cardEntity Entity ID of action card (or nil to clear)
-- @return boolean Success
function adapter.setAction(wandIndex, slotIndex, cardEntity)
    if not wandIndex or wandIndex < 1 then
        log_warn("[WandGridAdapter] setAction: invalid wandIndex")
        return false
    end
    if not slotIndex or slotIndex < 1 then
        log_warn("[WandGridAdapter] setAction: invalid slotIndex")
        return false
    end

    -- Auto-expand slots if needed
    if not _wandSlots[wandIndex] then
        if _wandDefinitions[wandIndex] then
            _wandSlots[wandIndex] = {
                wandDef = _wandDefinitions[wandIndex],
                trigger = nil,
                actions = {},
                dirty = true,
            }
        else
            log_warn(string.format("[WandGridAdapter] setAction: no wand definition for index %d", wandIndex))
            return false
        end
    end

    local previousCard = _wandSlots[wandIndex].actions[slotIndex]
    _wandSlots[wandIndex].actions[slotIndex] = cardEntity
    _wandSlots[wandIndex].dirty = true  -- Mark dirty on change

    if cardEntity then
        log_debug(string.format("[WandGridAdapter] Set action for wand %d slot %d: entity %s (was %s)",
            wandIndex, slotIndex, tostring(cardEntity), tostring(previousCard)))
    else
        log_debug(string.format("[WandGridAdapter] Cleared action for wand %d slot %d (was %s)",
            wandIndex, slotIndex, tostring(previousCard)))
    end

    return true
end

--- Clear a specific slot (trigger or action).
-- @param wandIndex 1-based wand index
-- @param slotIndex Slot index (nil = trigger slot, 1+ = action slot)
-- @return boolean Success
function adapter.clearSlot(wandIndex, slotIndex)
    if not wandIndex or wandIndex < 1 then
        log_warn("[WandGridAdapter] clearSlot: invalid wandIndex")
        return false
    end

    if not _wandSlots[wandIndex] then
        return false  -- Nothing to clear
    end

    if not slotIndex then
        -- Clear trigger
        _wandSlots[wandIndex].trigger = nil
        log_debug(string.format("[WandGridAdapter] Cleared trigger slot for wand %d", wandIndex))
    else
        -- Clear action slot
        _wandSlots[wandIndex].actions[slotIndex] = nil
        log_debug(string.format("[WandGridAdapter] Cleared action slot %d for wand %d", slotIndex, wandIndex))
    end

    _wandSlots[wandIndex].dirty = true  -- Mark dirty on change
    return true
end

--------------------------------------------------------------------------------
-- Loadout Queries
--------------------------------------------------------------------------------

--- Get the current loadout for a wand.
-- @param wandIndex 1-based wand index
-- @return table { trigger = entity|nil, actions = { [slot] = entity } } or nil if invalid
function adapter.getLoadout(wandIndex)
    if not wandIndex or wandIndex < 1 then
        return nil
    end

    local slotData = _wandSlots[wandIndex]
    if not slotData then
        -- Return empty loadout if wand exists in definitions but has no cards
        if _wandDefinitions[wandIndex] then
            return {
                trigger = nil,
                actions = {},
            }
        end
        return nil
    end

    -- Return a copy to prevent external modification
    local result = {
        trigger = slotData.trigger,
        actions = {},
    }

    for slot, entity in pairs(slotData.actions) do
        result.actions[slot] = entity
    end

    return result
end

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

--- Get the wand definition for a given index.
-- @param wandIndex 1-based wand index
-- @return table|nil Wand definition or nil
function adapter.getWandDef(wandIndex)
    if not wandIndex or wandIndex < 1 then
        return nil
    end
    return _wandDefinitions[wandIndex]
end

--- Get the total number of configured wands.
-- @return number Count of wand definitions
function adapter.getWandCount()
    return #_wandDefinitions
end

--- Check if a wand has any cards assigned.
-- @param wandIndex 1-based wand index
-- @return boolean True if wand has trigger or any action cards
function adapter.hasCards(wandIndex)
    if not wandIndex or not _wandSlots[wandIndex] then
        return false
    end

    local slotData = _wandSlots[wandIndex]

    -- Check trigger
    if slotData.trigger then
        return true
    end

    -- Check actions
    for _, _ in pairs(slotData.actions) do
        return true
    end

    return false
end

--- Count action cards in a wand.
-- @param wandIndex 1-based wand index
-- @return number Count of action cards
function adapter.getActionCount(wandIndex)
    if not wandIndex or not _wandSlots[wandIndex] then
        return 0
    end

    local count = 0
    for _, _ in pairs(_wandSlots[wandIndex].actions) do
        count = count + 1
    end
    return count
end

--- Clear all cards from a specific wand.
-- @param wandIndex 1-based wand index
-- @return boolean Success
function adapter.clearWand(wandIndex)
    if not wandIndex or wandIndex < 1 then
        return false
    end

    if _wandSlots[wandIndex] then
        _wandSlots[wandIndex].trigger = nil
        _wandSlots[wandIndex].actions = {}
        _wandSlots[wandIndex].dirty = true  -- Mark dirty on change
        log_debug(string.format("[WandGridAdapter] Cleared all cards from wand %d", wandIndex))
        return true
    end

    return false
end

--- Clear all wands (reset adapter state).
function adapter.clearAll()
    for index in pairs(_wandSlots) do
        _wandSlots[index].trigger = nil
        _wandSlots[index].actions = {}
        _wandSlots[index].dirty = true  -- Mark dirty on change
    end
    log_debug("[WandGridAdapter] Cleared all wands")
end

--------------------------------------------------------------------------------
-- Card Pool Building (Parity with collectCardPoolForBoardSet)
--------------------------------------------------------------------------------

--- Create a virtual card from a template definition.
-- Used for always-cast cards that don't have physical entities.
-- @param template Card definition template from WandEngine.card_defs
-- @return table|nil Virtual card with handle() method, or nil
local function makeVirtualCardFromTemplate(template)
    if not template then return nil end

    _virtualCardCounter = _virtualCardCounter + 1

    -- Deep copy the template (use util if available, else simple clone)
    local card = {}
    for k, v in pairs(template) do
        if type(v) == "table" then
            card[k] = {}
            for kk, vv in pairs(v) do
                card[kk] = vv
            end
        else
            card[k] = v
        end
    end

    card.card_id = template.id or template.card_id
    card.type = template.type
    card._virtual_handle = "virtual_card_" .. tostring(_virtualCardCounter)
    card.handle = function(self) return self._virtual_handle end

    return card
end

--- Push a card and its modifier stack into the pool.
-- CRITICAL: Modifier stacks appear BEFORE the base card.
-- @param pool Array to push cards into
-- @param cardScript The base card script table
-- @param modStats Table tracking modifier validation stats
local function pushCardWithModifiers(pool, cardScript, modStats)
    if not cardScript then return end

    local stackLen = cardScript.cardStack and #cardScript.cardStack or 0

    log_debug(string.format("[WandGridAdapter] card=%s stack=%s len=%d",
        cardScript.card_id or "?",
        cardScript.cardStack and "exists" or "nil",
        stackLen))

    -- MODIFIERS FIRST: Insert modifier cards before base card
    if cardScript.cardStack and #cardScript.cardStack > 0 then
        for _, modEid in ipairs(cardScript.cardStack) do
            modStats.total = modStats.total + 1
            if modEid and isValidEntity(modEid) then
                local modScript = getScriptTableFromEntityID(modEid)
                if modScript then
                    modStats.valid = modStats.valid + 1
                    table.insert(pool, modScript)
                else
                    modStats.noScript = modStats.noScript + 1
                end
            else
                modStats.invalid = modStats.invalid + 1
                log_warn(string.format("[WandGridAdapter] INVALID mod entity: %s (on card %s)",
                    tostring(modEid), cardScript.card_id or "?"))
            end
        end
    end

    -- BASE CARD: Insert after modifiers
    table.insert(pool, cardScript)
end

--- Collect the card pool for a wand, matching legacy collectCardPoolForBoardSet behavior.
-- @param wandIndex 1-based wand index
-- @return table|nil Ordered array of card scripts (modifiers before base cards), or nil if invalid
function adapter.collectCardPool(wandIndex)
    if not wandIndex or wandIndex < 1 then
        return nil
    end

    local slotData = _wandSlots[wandIndex]
    if not slotData then
        log_debug(string.format("[WandGridAdapter] collectCardPool: no slot data for wand %d", wandIndex))
        return nil
    end

    -- Check if we have any action cards
    local hasActions = false
    for _, _ in pairs(slotData.actions) do
        hasActions = true
        break
    end
    if not hasActions then
        log_debug(string.format("[WandGridAdapter] collectCardPool: wand %d has no action cards", wandIndex))
        return nil
    end

    local pool = {}
    local modStats = { total = 0, valid = 0, invalid = 0, noScript = 0 }

    -- Sort action cards by slot index (equivalent to legacy's X-position sorting)
    -- In the grid system, slot 1 = leftmost, slot N = rightmost
    local sortedSlots = {}
    for slotIndex, cardEntity in pairs(slotData.actions) do
        if cardEntity and isValidEntity(cardEntity) then
            table.insert(sortedSlots, { slot = slotIndex, entity = cardEntity })
        end
    end
    table.sort(sortedSlots, function(a, b) return a.slot < b.slot end)

    -- Build pool: push each card with its modifiers
    for _, entry in ipairs(sortedSlots) do
        local cardScript = getScriptTableFromEntityID(entry.entity)
        pushCardWithModifiers(pool, cardScript, modStats)
    end

    -- Append always-cast cards from wand definition
    local wandDef = slotData.wandDef
    if wandDef and wandDef.always_cast_cards then
        local WandEngine = getWandEngine()
        if WandEngine and WandEngine.card_defs then
            for _, alwaysId in ipairs(wandDef.always_cast_cards) do
                local template = WandEngine.card_defs[alwaysId]
                local virtualCard = makeVirtualCardFromTemplate(template)
                if virtualCard then
                    table.insert(pool, virtualCard)
                    log_debug(string.format("[WandGridAdapter] Added always-cast card: %s", alwaysId))
                else
                    log_warn(string.format("[WandGridAdapter] Failed to create always-cast card: %s", alwaysId))
                end
            end
        else
            log_warn("[WandGridAdapter] WandEngine.card_defs not available for always-cast cards")
        end
    end

    -- Log modifier stats if any modifiers were processed
    if modStats.total > 0 then
        log_debug(string.format("[WandGridAdapter] modCards: total=%d valid=%d invalid=%d noScript=%d",
            modStats.total, modStats.valid, modStats.invalid, modStats.noScript))
    end

    log_debug(string.format("[WandGridAdapter] collectCardPool wand %d: %d cards in pool",
        wandIndex, #pool))

    return pool
end

--------------------------------------------------------------------------------
-- Dirty Flag Management
--------------------------------------------------------------------------------

--- Mark a wand as dirty (needs resync before combat).
-- @param wandIndex 1-based wand index
-- @return boolean Success
function adapter.markDirty(wandIndex)
    if not wandIndex or wandIndex < 1 then
        return false
    end

    if _wandSlots[wandIndex] then
        _wandSlots[wandIndex].dirty = true
        log_debug(string.format("[WandGridAdapter] Marked wand %d as dirty", wandIndex))
        return true
    end

    return false
end

--- Check if a wand is marked dirty.
-- @param wandIndex 1-based wand index
-- @return boolean True if dirty
function adapter.isDirty(wandIndex)
    if not wandIndex or not _wandSlots[wandIndex] then
        return false
    end
    return _wandSlots[wandIndex].dirty == true
end

--- Clear dirty flag for a wand.
-- @param wandIndex 1-based wand index
function adapter.clearDirty(wandIndex)
    if wandIndex and _wandSlots[wandIndex] then
        _wandSlots[wandIndex].dirty = false
    end
end

--- Check if any wand is dirty.
-- @return boolean True if any wand needs sync
function adapter.anyDirty()
    for _, slotData in pairs(_wandSlots) do
        if slotData.dirty then
            return true
        end
    end
    return false
end

--------------------------------------------------------------------------------
-- Executor Sync (Called Before Combat)
--------------------------------------------------------------------------------

--- Sync all dirty wands to the WandExecutor.
-- Call this before entering combat to ensure the executor has the latest loadout.
-- @param WandExecutor Optional WandExecutor reference (uses _G.WandExecutor if nil)
-- @return number Count of wands synced
function adapter.syncToExecutor(WandExecutor)
    WandExecutor = WandExecutor or _G.WandExecutor
    if not WandExecutor then
        log_warn("[WandGridAdapter] syncToExecutor: WandExecutor not available")
        return 0
    end

    local syncCount = 0

    for wandIndex, slotData in pairs(_wandSlots) do
        if slotData.dirty then
            local cardPool = adapter.collectCardPool(wandIndex)
            local wandDef = slotData.wandDef

            -- Build trigger definition from trigger card if present
            local triggerDef = nil
            if slotData.trigger and isValidEntity(slotData.trigger) then
                local triggerScript = getScriptTableFromEntityID(slotData.trigger)
                if triggerScript then
                    local WandEngine = getWandEngine()
                    local triggerId = triggerScript.card_id or triggerScript.cardID

                    -- Find matching trigger template
                    if WandEngine and WandEngine.trigger_card_defs and triggerId then
                        for _, template in pairs(WandEngine.trigger_card_defs) do
                            if template.id == triggerId then
                                -- Deep copy template
                                triggerDef = {}
                                for k, v in pairs(template) do
                                    triggerDef[k] = v
                                end
                                break
                            end
                        end
                    end

                    -- Fallback: create minimal trigger def
                    if not triggerDef then
                        triggerDef = { id = triggerId, type = "trigger" }
                    end

                    -- Copy dynamic properties from card instance
                    if triggerDef.id == "every_N_seconds" then
                        triggerDef.interval = triggerDef.interval or triggerScript.interval or 1.0
                    elseif triggerDef.id == "on_distance_traveled" then
                        triggerDef.distance = triggerDef.distance or triggerScript.distance
                    end
                end
            end

            -- Only load if we have valid data
            if wandDef and cardPool and #cardPool > 0 and triggerDef then
                -- Use util.deep_copy if available
                local wandDefCopy = {}
                for k, v in pairs(wandDef) do
                    if type(v) == "table" then
                        wandDefCopy[k] = {}
                        for kk, vv in pairs(v) do
                            wandDefCopy[k][kk] = vv
                        end
                    else
                        wandDefCopy[k] = v
                    end
                end

                WandExecutor.loadWand(wandDefCopy, cardPool, triggerDef)
                syncCount = syncCount + 1

                log_debug(string.format("[WandGridAdapter] Synced wand %d (%s) to executor: %d cards, trigger=%s",
                    wandIndex, wandDef.id or "?", #cardPool, triggerDef.id or "?"))
            else
                local reasons = {}
                if not wandDef then table.insert(reasons, "missing wandDef") end
                if not cardPool or #cardPool == 0 then table.insert(reasons, "no action cards") end
                if not triggerDef then table.insert(reasons, "no trigger") end

                log_debug(string.format("[WandGridAdapter] Skipped wand %d sync: %s",
                    wandIndex, table.concat(reasons, ", ")))
            end

            -- Clear dirty flag after sync attempt
            slotData.dirty = false
        end
    end

    log_debug(string.format("[WandGridAdapter] syncToExecutor complete: %d wands synced", syncCount))
    return syncCount
end

--------------------------------------------------------------------------------
-- Debug
--------------------------------------------------------------------------------

--- Debug: Print current adapter state.
function adapter.debugPrint()
    print("=== Wand Grid Adapter State ===")
    print("Wand definitions: " .. #_wandDefinitions)

    for wandIndex, slotData in pairs(_wandSlots) do
        local wandId = slotData.wandDef and slotData.wandDef.id or "?"
        local triggerStr = slotData.trigger and tostring(slotData.trigger) or "empty"
        local actionCount = 0
        for _ in pairs(slotData.actions) do actionCount = actionCount + 1 end

        print(string.format("  Wand %d (%s): trigger=%s, actions=%d",
            wandIndex, wandId, triggerStr, actionCount))

        if actionCount > 0 then
            for slot, entity in pairs(slotData.actions) do
                print(string.format("    Slot %d: %s", slot, tostring(entity)))
            end
        end
    end
    print("================================")
end

log_debug("[WandGridAdapter] Module loaded")

return adapter
