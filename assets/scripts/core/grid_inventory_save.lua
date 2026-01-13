--[[
================================================================================
GRID INVENTORY SAVE/LOAD
================================================================================

Handles serialization of grid-based inventory systems:
- Player inventory grids (triggers, actions, modifiers)
- Wand loadout grids (trigger slot + action slots)

Registers with SaveManager using the collector pattern.

SAVE SCHEMA (v2):
-----------------
{
    "grid_inventory": {
        "version": 1,
        "player_inventory": {
            "triggers": [ { "slot": 1, "card_id": "FIREBALL", "stack_count": 1 }, ... ],
            "actions": [ ... ],
            "modifiers": [ ... ]
        },
        "wand_loadouts": [
            {
                "wand_index": 1,
                "trigger": { "card_id": "EVERY_2_SEC" },
                "actions": [ { "slot": 1, "card_id": "SPARK" }, { "slot": 3, "card_id": "SHIELD" } ]
            }
        ]
    }
}

NOTES:
------
- Card IDs are saved, not entity IDs (entities are recreated on load)
- Stack counts preserved for stackable grids
- Slot indices are 1-based and sparse (empty slots omitted)
- Legacy saves without grid_inventory key are handled gracefully

================================================================================
]]

local GridInventorySave = {}

local SaveManager = require("core.save_manager")
local grid = require("core.inventory_grid")
local signal = require("external.hump.signal")

-- Schema version for grid inventory data
local GRID_SAVE_VERSION = 1

-- References to grid systems (set during init)
local _playerInventoryRef = nil
local _wandLoadoutRef = nil
local _wandAdapterRef = nil

-- Card recreation function (set by gameplay.lua or card factory)
local _cardRecreatorFn = nil

--------------------------------------------------------------------------------
-- Utility: Extract card_id from entity
--------------------------------------------------------------------------------

local function getCardIdFromEntity(entity)
    if not entity then return nil end
    if not registry or not registry:valid(entity) then return nil end

    local script = getScriptTableFromEntityID(entity)
    if not script then return nil end

    -- Try multiple fields that might contain the card ID
    return script.card_id
        or script.cardID
        or script.id
        or (script.cardData and script.cardData.id)
end

local function getStackCountFromSlot(gridEntity, slotIndex)
    if not gridEntity then return 1 end
    local count = grid.getStackCount(gridEntity, slotIndex)
    return count > 0 and count or 1
end

--------------------------------------------------------------------------------
-- Collect: Serialize Player Inventory
--------------------------------------------------------------------------------

local function collectPlayerInventory()
    if not _playerInventoryRef then
        log_debug("[GridInventorySave] No player inventory reference, skipping collection")
        return nil
    end

    local PlayerInventory = _playerInventoryRef

    -- Get grid entities for each tab
    local grids = {
        triggers = PlayerInventory.getGridForTab and PlayerInventory.getGridForTab("triggers"),
        actions = PlayerInventory.getGridForTab and PlayerInventory.getGridForTab("actions"),
        modifiers = PlayerInventory.getGridForTab and PlayerInventory.getGridForTab("modifiers"),
    }

    local result = {}

    for tabName, gridEntity in pairs(grids) do
        if gridEntity and registry:valid(gridEntity) then
            local items = grid.getAllItems(gridEntity)
            local tabData = {}

            for slotIndex, itemEntity in pairs(items) do
                local cardId = getCardIdFromEntity(itemEntity)
                if cardId then
                    table.insert(tabData, {
                        slot = slotIndex,
                        card_id = cardId,
                        stack_count = getStackCountFromSlot(gridEntity, slotIndex),
                    })
                end
            end

            -- Sort by slot index for deterministic output
            table.sort(tabData, function(a, b) return a.slot < b.slot end)
            result[tabName] = tabData

            log_debug(string.format("[GridInventorySave] Collected %d cards from %s", #tabData, tabName))
        end
    end

    return result
end

--------------------------------------------------------------------------------
-- Collect: Serialize Wand Loadouts
--------------------------------------------------------------------------------

local function collectWandLoadouts()
    -- Try wand adapter first (preferred source)
    local wandAdapter = _wandAdapterRef
    if not wandAdapter then
        -- Fallback: try to require it
        local ok, adapter = pcall(require, "ui.wand_grid_adapter")
        if ok then
            wandAdapter = adapter
        end
    end

    if not wandAdapter then
        log_debug("[GridInventorySave] No wand adapter reference, skipping wand loadout collection")
        return nil
    end

    local result = {}
    local wandCount = wandAdapter.getWandCount and wandAdapter.getWandCount() or 0

    for wandIndex = 1, math.max(wandCount, 1) do
        local loadout = wandAdapter.getLoadout(wandIndex)
        if loadout then
            local wandData = {
                wand_index = wandIndex,
            }

            -- Save trigger if present
            if loadout.trigger then
                local triggerId = getCardIdFromEntity(loadout.trigger)
                if triggerId then
                    wandData.trigger = { card_id = triggerId }
                end
            end

            -- Save action cards
            local actions = {}
            for slotIndex, actionEntity in pairs(loadout.actions or {}) do
                local cardId = getCardIdFromEntity(actionEntity)
                if cardId then
                    table.insert(actions, {
                        slot = slotIndex,
                        card_id = cardId,
                    })
                end
            end

            -- Sort by slot for deterministic output
            table.sort(actions, function(a, b) return a.slot < b.slot end)

            if #actions > 0 then
                wandData.actions = actions
            end

            -- Only save if there's content
            if wandData.trigger or (wandData.actions and #wandData.actions > 0) then
                table.insert(result, wandData)
                log_debug(string.format("[GridInventorySave] Collected wand %d: trigger=%s, actions=%d",
                    wandIndex,
                    wandData.trigger and wandData.trigger.card_id or "none",
                    wandData.actions and #wandData.actions or 0))
            end
        end
    end

    return #result > 0 and result or nil
end

--------------------------------------------------------------------------------
-- Distribute: Restore Player Inventory
--------------------------------------------------------------------------------

local function distributePlayerInventory(inventoryData)
    if not inventoryData then return end
    if not _playerInventoryRef then
        log_warn("[GridInventorySave] Cannot restore player inventory: no reference set")
        return
    end
    if not _cardRecreatorFn then
        log_warn("[GridInventorySave] Cannot restore player inventory: no card recreator function")
        return
    end

    local PlayerInventory = _playerInventoryRef

    for tabName, tabData in pairs(inventoryData) do
        if type(tabData) == "table" then
            local gridEntity = PlayerInventory.getGridForTab and PlayerInventory.getGridForTab(tabName)

            if gridEntity and registry:valid(gridEntity) then
                local restoredCount = 0

                for _, cardSave in ipairs(tabData) do
                    local cardId = cardSave.card_id
                    local slotIndex = cardSave.slot

                    if cardId and slotIndex then
                        -- Recreate card entity from ID
                        local cardEntity = _cardRecreatorFn(cardId, tabName)

                        if cardEntity then
                            -- Add to specific slot
                            local success = grid.addItem(gridEntity, cardEntity, slotIndex)
                            if success then
                                restoredCount = restoredCount + 1

                                -- Restore stack count if > 1
                                if cardSave.stack_count and cardSave.stack_count > 1 then
                                    for _ = 2, cardSave.stack_count do
                                        grid.addToStack(gridEntity, slotIndex, 1)
                                    end
                                end
                            else
                                -- Slot might be occupied or invalid, try any empty slot
                                success = grid.addItem(gridEntity, cardEntity, nil)
                                if success then
                                    restoredCount = restoredCount + 1
                                    log_debug(string.format("[GridInventorySave] Card %s placed in alternate slot (original %d unavailable)", cardId, slotIndex))
                                else
                                    log_warn(string.format("[GridInventorySave] Failed to restore card %s to any slot", cardId))
                                end
                            end
                        else
                            log_warn(string.format("[GridInventorySave] Failed to recreate card: %s", cardId))
                        end
                    end
                end

                log_debug(string.format("[GridInventorySave] Restored %d cards to %s", restoredCount, tabName))
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Distribute: Restore Wand Loadouts
--------------------------------------------------------------------------------

local function distributeWandLoadouts(loadoutsData)
    if not loadoutsData then return end
    if not _cardRecreatorFn then
        log_warn("[GridInventorySave] Cannot restore wand loadouts: no card recreator function")
        return
    end

    -- Get wand adapter and loadout UI
    local wandAdapter = _wandAdapterRef
    if not wandAdapter then
        local ok, adapter = pcall(require, "ui.wand_grid_adapter")
        if ok then wandAdapter = adapter end
    end

    local WandLoadoutUI = _wandLoadoutRef
    if not WandLoadoutUI then
        local ok, ui = pcall(require, "ui.wand_loadout_ui")
        if ok then WandLoadoutUI = ui end
    end

    if not wandAdapter then
        log_warn("[GridInventorySave] Cannot restore wand loadouts: no wand adapter")
        return
    end

    for _, wandSave in ipairs(loadoutsData) do
        local wandIndex = wandSave.wand_index or 1

        -- Restore trigger
        if wandSave.trigger and wandSave.trigger.card_id then
            local cardEntity = _cardRecreatorFn(wandSave.trigger.card_id, "trigger")
            if cardEntity then
                -- If WandLoadoutUI is available, add to its grid
                if WandLoadoutUI and WandLoadoutUI.getTriggerGrid then
                    local triggerGrid = WandLoadoutUI.getTriggerGrid()
                    if triggerGrid then
                        grid.addItem(triggerGrid, cardEntity, 1)
                    end
                end
                -- Also update adapter directly
                wandAdapter.setTrigger(wandIndex, cardEntity)
                log_debug(string.format("[GridInventorySave] Restored trigger %s for wand %d",
                    wandSave.trigger.card_id, wandIndex))
            end
        end

        -- Restore action cards
        if wandSave.actions then
            local actionGrid = WandLoadoutUI and WandLoadoutUI.getActionGrid and WandLoadoutUI.getActionGrid()

            for _, actionSave in ipairs(wandSave.actions) do
                local cardId = actionSave.card_id
                local slotIndex = actionSave.slot

                if cardId and slotIndex then
                    local cardEntity = _cardRecreatorFn(cardId, "action")
                    if cardEntity then
                        -- Add to grid if available
                        if actionGrid then
                            local success = grid.addItem(actionGrid, cardEntity, slotIndex)
                            if not success then
                                -- Try any empty slot
                                grid.addItem(actionGrid, cardEntity, nil)
                            end
                        end
                        -- Update adapter
                        wandAdapter.setAction(wandIndex, slotIndex, cardEntity)
                        log_debug(string.format("[GridInventorySave] Restored action %s to slot %d for wand %d",
                            cardId, slotIndex, wandIndex))
                    end
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- SaveManager Collector Implementation
--------------------------------------------------------------------------------

local function collect()
    local data = {
        version = GRID_SAVE_VERSION,
    }

    -- Collect player inventory
    local playerInv = collectPlayerInventory()
    if playerInv then
        data.player_inventory = playerInv
    end

    -- Collect wand loadouts
    local wandLoadouts = collectWandLoadouts()
    if wandLoadouts then
        data.wand_loadouts = wandLoadouts
    end

    log_debug("[GridInventorySave] Collection complete")
    return data
end

local function distribute(data)
    if not data then
        log_debug("[GridInventorySave] No grid inventory data to restore (legacy save or fresh start)")
        -- Emit signal with nil to indicate legacy mode - cards will be placed sequentially
        signal.emit("grid_inventory_restored", nil)
        return
    end

    local version = data.version or 1
    log_debug(string.format("[GridInventorySave] Distributing grid inventory data (version %d)", version))

    -- Check for legacy save (migrated but no actual position data)
    local hasPlayerData = data.player_inventory and next(data.player_inventory) ~= nil
    local hasWandData = data.wand_loadouts and #data.wand_loadouts > 0

    if not hasPlayerData and not hasWandData then
        log_debug("[GridInventorySave] Legacy save detected: no grid position data, cards will be placed sequentially")
        signal.emit("grid_inventory_restored", { legacy_mode = true })
        return
    end

    -- Restore player inventory
    if data.player_inventory then
        distributePlayerInventory(data.player_inventory)
    end

    -- Restore wand loadouts
    if data.wand_loadouts then
        distributeWandLoadouts(data.wand_loadouts)
    end

    -- Emit signal for systems that need to know inventory was restored
    signal.emit("grid_inventory_restored", data)
end

--------------------------------------------------------------------------------
-- Public API: Reference Setup
--------------------------------------------------------------------------------

--- Set reference to player inventory module.
-- @param playerInventoryModule The PlayerInventory module
function GridInventorySave.setPlayerInventoryRef(playerInventoryModule)
    _playerInventoryRef = playerInventoryModule
    log_debug("[GridInventorySave] Player inventory reference set")
end

--- Set reference to wand loadout UI module.
-- @param wandLoadoutModule The WandLoadoutUI module
function GridInventorySave.setWandLoadoutRef(wandLoadoutModule)
    _wandLoadoutRef = wandLoadoutModule
    log_debug("[GridInventorySave] Wand loadout reference set")
end

--- Set reference to wand grid adapter module.
-- @param wandAdapterModule The WandGridAdapter module
function GridInventorySave.setWandAdapterRef(wandAdapterModule)
    _wandAdapterRef = wandAdapterModule
    log_debug("[GridInventorySave] Wand adapter reference set")
end

--- Set the card recreator function for loading cards from IDs.
-- @param fn Function with signature: fn(cardId, category) -> cardEntity
function GridInventorySave.setCardRecreator(fn)
    _cardRecreatorFn = fn
    log_debug("[GridInventorySave] Card recreator function set")
end

--------------------------------------------------------------------------------
-- Public API: Manual Save/Load
--------------------------------------------------------------------------------

--- Manually trigger a save of grid inventory data.
function GridInventorySave.save()
    SaveManager.save()
end

--- Get current grid inventory data without saving.
-- @return table Grid inventory data
function GridInventorySave.getCurrentData()
    return collect()
end

--- Check if grid inventory data exists in save.
-- @return boolean
function GridInventorySave.hasSavedData()
    local cached = SaveManager.peek("grid_inventory")
    return cached ~= nil
end

--------------------------------------------------------------------------------
-- Module Registration
--------------------------------------------------------------------------------

-- Register with SaveManager
SaveManager.register("grid_inventory", {
    collect = collect,
    distribute = distribute,
})

log_debug("[GridInventorySave] Registered with SaveManager")

return GridInventorySave
