--[[
================================================================================
PLAYER INVENTORY BRIDGE
================================================================================

Handles drag-drop between PlayerInventory (screen-space) and Planning Boards 
(world-space). This is the "glue" that makes cards transferable between the 
two coordinate systems.

RESPONSIBILITIES:
----------------
1. Setup planning boards as drop targets for inventory cards
2. Handle drops from boards onto inventory
3. Coordinate with CardSpaceConverter for coordinate transforms
4. Emit signals for external systems

USAGE:
------
local Bridge = require("ui.player_inventory_bridge")

-- Call during planning phase initialization:
Bridge.setupBoardDropTargets(board_sets)

-- Call when inventory grid receives a drop:
Bridge.handleDropOnInventory(gridEntity, slotIndex, droppedEntity)

================================================================================
]]

local Bridge = {}

local CardSpaceConverter = require("ui.card_space_converter")
local grid = require("core.inventory_grid")
local signal = require("external.hump.signal")
local component_cache = require("core.component_cache")

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------

local registeredBoards = {}  -- { [boardId] = { acceptedCategories = {...} } }

--------------------------------------------------------------------------------
-- Board Drop Target Setup
--------------------------------------------------------------------------------

--- Setup a planning board to accept drops from inventory
--- @param boardEntity number The board entity ID
--- @param boardId number The board's ID (same as entity usually)
--- @param acceptedCategories table List of accepted card categories (e.g., {"trigger"})
function Bridge.setupBoardAsDropTarget(boardEntity, boardId, acceptedCategories)
    if not registry:valid(boardEntity) then
        log_warn("[Bridge] setupBoardAsDropTarget: invalid board entity")
        return
    end
    
    local go = component_cache.get(boardEntity, GameObject)
    if not go then
        log_warn("[Bridge] setupBoardAsDropTarget: board has no GameObject")
        return
    end
    
    -- Enable as drop target
    go.state.collisionEnabled = true
    go.state.triggerOnReleaseEnabled = true
    
    -- Store configuration
    registeredBoards[boardId] = {
        entity = boardEntity,
        acceptedCategories = acceptedCategories,
    }
    
    -- Set up onRelease handler
    go.methods.onRelease = function(reg, releasedOn, droppedEntity)
        Bridge.handleDropOnBoard(boardId, droppedEntity)
    end
    
    log_debug("[Bridge] Registered board " .. tostring(boardId) .. " as drop target for: " .. table.concat(acceptedCategories, ", "))
end

--- Setup all planning boards as drop targets
--- @param board_sets table Array of board sets from gameplay.lua
function Bridge.setupBoardDropTargets(board_sets)
    if not board_sets then
        log_warn("[Bridge] setupBoardDropTargets: no board_sets provided")
        return
    end
    
    for _, boardSet in ipairs(board_sets) do
        -- Trigger board accepts only triggers
        if boardSet.trigger_board_id then
            Bridge.setupBoardAsDropTarget(
                boardSet.trigger_board_id,
                boardSet.trigger_board_id,
                { "trigger" }
            )
        end
        
        -- Action board accepts actions and modifiers
        if boardSet.action_board_id then
            Bridge.setupBoardAsDropTarget(
                boardSet.action_board_id,
                boardSet.action_board_id,
                { "action", "modifier" }
            )
        end
    end
    
    log_debug("[Bridge] Setup drop targets for " .. #board_sets .. " board sets")
end

--------------------------------------------------------------------------------
-- Drop Handlers
--------------------------------------------------------------------------------

--- Handle a drop on a planning board (from inventory)
--- @param boardId number The board that received the drop
--- @param droppedEntity number The dropped card entity
function Bridge.handleDropOnBoard(boardId, droppedEntity)
    if not registry:valid(droppedEntity) then
        log_debug("[Bridge] handleDropOnBoard: invalid dropped entity")
        return
    end
    
    local boardConfig = registeredBoards[boardId]
    if not boardConfig then
        log_debug("[Bridge] handleDropOnBoard: board not registered")
        return
    end
    
    -- Get card data
    local script = getScriptTableFromEntityID(droppedEntity)
    if not script then
        log_debug("[Bridge] handleDropOnBoard: dropped entity has no script")
        return
    end
    
    -- Check if card category is accepted
    local category = script.category
    local accepted = false
    for _, cat in ipairs(boardConfig.acceptedCategories) do
        if cat == category then
            accepted = true
            break
        end
    end
    
    if not accepted then
        log_debug("[Bridge] handleDropOnBoard: rejected category " .. tostring(category))
        -- TODO: Snap card back to original position
        return
    end
    
    -- Check if card came from inventory (screen-space)
    if CardSpaceConverter.isScreenSpace(droppedEntity) then
        -- Card is from inventory - need to convert
        log_debug("[Bridge] Moving card from inventory to board " .. tostring(boardId))
        
        -- 1. Remove from inventory grid
        local PlayerInventory = require("ui.player_inventory")
        PlayerInventory.removeCard(droppedEntity)
        
        -- 2. Convert to world-space
        CardSpaceConverter.toWorldSpace(droppedEntity)
        
        -- 3. Add to board (uses existing gameplay.lua function)
        if addCardToBoard then
            addCardToBoard(droppedEntity, boardId)
        end
        
        -- 4. Emit event
        signal.emit("card_equipped_to_board", droppedEntity, boardId)
    else
        -- Card is already world-space (moving between boards)
        log_debug("[Bridge] Moving card between boards")
        -- Existing board-to-board logic in gameplay.lua handles this
    end
end

--- Handle a drop on inventory grid (from board)
--- @param gridEntity number The inventory grid entity
--- @param slotIndex number The slot that received the drop
--- @param droppedEntity number The dropped card entity
function Bridge.handleDropOnInventory(gridEntity, slotIndex, droppedEntity)
    if not registry:valid(droppedEntity) then
        log_debug("[Bridge] handleDropOnInventory: invalid dropped entity")
        return
    end
    
    -- Check if this card came from a planning board (world-space)
    if CardSpaceConverter.isWorldSpace(droppedEntity) then
        log_debug("[Bridge] Moving card from board to inventory")
        
        -- 1. Find which board it came from and remove it
        if findBoardContainingCard and removeCardFromBoard then
            local sourceBoard = findBoardContainingCard(droppedEntity)
            if sourceBoard then
                removeCardFromBoard(droppedEntity, sourceBoard)
            end
        end
        
        -- 2. Convert to screen-space
        CardSpaceConverter.toScreenSpace(droppedEntity)
        
        -- 3. Add to inventory grid
        local success = grid.addItem(gridEntity, droppedEntity, slotIndex)
        
        if success then
            -- 4. Center on slot
            local InventoryGridInit = require("ui.inventory_grid_init")
            local slotEntity = grid.getSlotEntity(gridEntity, slotIndex)
            if slotEntity then
                InventoryGridInit.centerItemOnSlot(droppedEntity, slotEntity)
            end
            
            -- 5. Emit event
            signal.emit("card_returned_to_inventory", droppedEntity)
            
            log_debug("[Bridge] Card moved from board to inventory slot " .. slotIndex)
        end
    else
        -- Card is already screen-space (moving within inventory)
        -- Standard grid handling applies (already handled by inventory_grid_init.lua)
    end
end

--------------------------------------------------------------------------------
-- Query Functions
--------------------------------------------------------------------------------

--- Check if a board is registered as a drop target
--- @param boardId number The board ID to check
--- @return boolean
function Bridge.isBoardRegistered(boardId)
    return registeredBoards[boardId] ~= nil
end

--- Get accepted categories for a board
--- @param boardId number The board ID
--- @return table|nil List of accepted categories or nil if not registered
function Bridge.getAcceptedCategories(boardId)
    local config = registeredBoards[boardId]
    return config and config.acceptedCategories
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function Bridge.cleanup()
    registeredBoards = {}
    log_debug("[Bridge] Cleanup complete")
end

--------------------------------------------------------------------------------
-- Module Init
--------------------------------------------------------------------------------

log_debug("[PlayerInventoryBridge] Module loaded")

return Bridge
