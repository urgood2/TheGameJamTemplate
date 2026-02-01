-- assets/scripts/descent/movement.lua
--[[
================================================================================
DESCENT MOVEMENT MODULE
================================================================================
Movement validation with diagonal corner-cutting rules per spec.

Spec configuration:
- movement.eight_way = true (8-directional)
- movement.diagonal.allow = true
- movement.diagonal.corner_cutting = "block_if_either_cardinal_blocked"

This module validates whether a movement from (x, y) to (x + dx, y + dy)
is legal based on:
1. Target tile is walkable
2. For diagonal moves: adjacent cardinal tiles are checked

Usage:
    local movement = require("descent.movement")
    local valid, reason = movement.can_move(map, x, y, dx, dy)
================================================================================
]]

local M = {}

-- Dependencies
local spec = require("descent.spec")
local Map = nil  -- Lazy loaded

--------------------------------------------------------------------------------
-- Configuration from spec
--------------------------------------------------------------------------------

local function get_config()
    return {
        eight_way = spec.movement.eight_way ~= false,
        allow_diagonal = spec.movement.diagonal and spec.movement.diagonal.allow ~= false,
        corner_cutting = spec.movement.diagonal and spec.movement.diagonal.corner_cutting or "block_if_either_cardinal_blocked",
    }
end

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function is_diagonal(dx, dy)
    return dx ~= 0 and dy ~= 0
end

local function is_walkable(map, x, y)
    if not map then return false end
    
    -- Support Map module
    if not Map then
        Map = require("descent.map")
    end
    
    if type(Map.is_walkable) == "function" then
        return Map.is_walkable(map, x, y)
    end
    
    -- Fallback: check tile type
    local tile = nil
    if type(Map.get_tile) == "function" then
        tile = Map.get_tile(map, x, y)
    elseif type(map.get_tile) == "function" then
        tile = map.get_tile(x, y)
    elseif map.tiles then
        local w = map.w or map.width
        if w then
            local idx = (y - 1) * w + x
            tile = map.tiles[idx]
        end
    end
    
    if not tile then return false end
    
    -- Check against known walkable tiles
    if type(tile) == "number" then
        local FLOOR = Map.TILE and Map.TILE.FLOOR or 1
        local STAIRS_UP = Map.TILE and Map.TILE.STAIRS_UP or 3
        local STAIRS_DOWN = Map.TILE and Map.TILE.STAIRS_DOWN or 4
        return tile == FLOOR or tile == STAIRS_UP or tile == STAIRS_DOWN
    end
    
    -- String-based tiles
    if type(tile) == "string" then
        return tile ~= "wall" and tile ~= "#" and tile ~= "WALL"
    end
    
    return false
end

--------------------------------------------------------------------------------
-- Corner-Cutting Validation
--------------------------------------------------------------------------------

--- Check if diagonal movement is blocked by corner-cutting rules
--- @param map table Map data
--- @param x number Current x
--- @param y number Current y
--- @param dx number Delta x (-1, 0, or 1)
--- @param dy number Delta y (-1, 0, or 1)
--- @return boolean blocked, string|nil reason
local function check_corner_cutting(map, x, y, dx, dy)
    local config = get_config()
    
    if config.corner_cutting == "allow_all" then
        -- No corner-cutting restriction
        return false, nil
    end
    
    if config.corner_cutting == "block_if_both_cardinal_blocked" then
        -- Block only if BOTH adjacent cardinals are blocked
        local horiz_blocked = not is_walkable(map, x + dx, y)
        local vert_blocked = not is_walkable(map, x, y + dy)
        
        if horiz_blocked and vert_blocked then
            return true, "both_cardinals_blocked"
        end
        return false, nil
    end
    
    -- Default: "block_if_either_cardinal_blocked"
    local horiz_blocked = not is_walkable(map, x + dx, y)
    local vert_blocked = not is_walkable(map, x, y + dy)
    
    if horiz_blocked then
        return true, "horizontal_cardinal_blocked"
    end
    if vert_blocked then
        return true, "vertical_cardinal_blocked"
    end
    
    return false, nil
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Check if movement is valid
--- @param map table Map data
--- @param x number Current x
--- @param y number Current y
--- @param dx number Delta x
--- @param dy number Delta y
--- @return boolean valid, string|nil reason
function M.can_move(map, x, y, dx, dy)
    local config = get_config()
    
    -- Zero movement is always invalid
    if dx == 0 and dy == 0 then
        return false, "no_movement"
    end
    
    -- Check if diagonal movement is allowed
    if is_diagonal(dx, dy) then
        if not config.eight_way then
            return false, "diagonal_disabled_no_eight_way"
        end
        if not config.allow_diagonal then
            return false, "diagonal_disabled"
        end
    end
    
    local target_x = x + dx
    local target_y = y + dy
    
    -- Check target is walkable
    if not is_walkable(map, target_x, target_y) then
        return false, "target_not_walkable"
    end
    
    -- Check corner-cutting for diagonal moves
    if is_diagonal(dx, dy) then
        local blocked, reason = check_corner_cutting(map, x, y, dx, dy)
        if blocked then
            return false, reason
        end
    end
    
    return true, nil
end

--- Get valid movement directions from a position
--- @param map table Map data
--- @param x number Current x
--- @param y number Current y
--- @return table Array of { dx, dy } valid movements
function M.get_valid_moves(map, x, y)
    local config = get_config()
    local moves = {}
    
    -- Cardinal directions
    local cardinals = {
        { dx = 0, dy = -1 },  -- North
        { dx = 0, dy = 1 },   -- South
        { dx = -1, dy = 0 },  -- West
        { dx = 1, dy = 0 },   -- East
    }
    
    -- Diagonal directions
    local diagonals = {
        { dx = -1, dy = -1 }, -- NW
        { dx = 1, dy = -1 },  -- NE
        { dx = -1, dy = 1 },  -- SW
        { dx = 1, dy = 1 },   -- SE
    }
    
    -- Check cardinals
    for _, dir in ipairs(cardinals) do
        local valid = M.can_move(map, x, y, dir.dx, dir.dy)
        if valid then
            table.insert(moves, dir)
        end
    end
    
    -- Check diagonals if enabled
    if config.eight_way and config.allow_diagonal then
        for _, dir in ipairs(diagonals) do
            local valid = M.can_move(map, x, y, dir.dx, dir.dy)
            if valid then
                table.insert(moves, dir)
            end
        end
    end
    
    return moves
end

--- Check if movement is diagonal
--- @param dx number Delta x
--- @param dy number Delta y
--- @return boolean
function M.is_diagonal(dx, dy)
    return is_diagonal(dx, dy)
end

--- Get movement cost (for turn manager)
--- @param dx number Delta x
--- @param dy number Delta y
--- @return number Cost (1 for cardinal, spec.turn_cost.move for any)
function M.get_move_cost(dx, dy)
    -- Per spec, all moves cost the same
    return spec.turn_cost.move or 100
end

--- Get direction name
--- @param dx number Delta x
--- @param dy number Delta y
--- @return string Direction name
function M.get_direction_name(dx, dy)
    local dirs = {
        ["-1,-1"] = "northwest",
        ["0,-1"] = "north",
        ["1,-1"] = "northeast",
        ["-1,0"] = "west",
        ["0,0"] = "none",
        ["1,0"] = "east",
        ["-1,1"] = "southwest",
        ["0,1"] = "south",
        ["1,1"] = "southeast",
    }
    return dirs[dx .. "," .. dy] or "unknown"
end

return M
