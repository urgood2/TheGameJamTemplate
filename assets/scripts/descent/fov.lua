-- assets/scripts/descent/fov.lua
--[[
================================================================================
DESCENT FOV MODULE
================================================================================
Field of view (visibility) system using recursive shadowcasting.
Per spec: radius 8, circle shape, no corner peeking, explored persists.

Algorithm: Recursive Shadowcasting
- Divides circle into 8 octants
- Scans each octant in rows from center outward
- Tracks shadow angles to skip occluded tiles

Usage:
    local fov = require("descent.fov")
    fov.init(map)
    fov.compute(origin_x, origin_y)
    if fov.is_visible(x, y) then ... end
    if fov.is_explored(x, y) then ... end
]]

local M = {}

-- Dependencies
local spec = require("descent.spec")

-- Configuration from spec
local CONFIG = {
    radius = spec.fov.radius,                     -- 8
    shape = spec.fov.shape,                       -- "circle"
    diagonal_blocking = spec.fov.diagonal_blocking, -- "no_corner_peek"
    explored_persists = spec.fov.explored_persists, -- true
}

-- State
local state = {
    map = nil,              -- Map reference
    width = 0,
    height = 0,
    visible = {},           -- [y][x] = true/false for current FOV
    explored = {},          -- [y][x] = true/false for ever-seen tiles
    origin_x = 0,
    origin_y = 0,
}

-- Octant transformations for shadowcasting
-- Each octant: {xx, xy, yx, yy} - transforms row/col to map coords
local OCTANTS = {
    { 1,  0,  0,  1},   -- E-NE
    { 0,  1,  1,  0},   -- N-NE
    { 0, -1,  1,  0},   -- N-NW
    {-1,  0,  0,  1},   -- W-NW
    {-1,  0,  0, -1},   -- W-SW
    { 0, -1, -1,  0},   -- S-SW
    { 0,  1, -1,  0},   -- S-SE
    { 1,  0,  0, -1},   -- E-SE
}

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

--- Check if coordinates are in bounds
--- @param x number
--- @param y number
--- @return boolean
local function in_bounds(x, y)
    return x >= 1 and x <= state.width and y >= 1 and y <= state.height
end

--- Check if tile blocks vision
--- @param x number
--- @param y number
--- @return boolean
local function blocks_vision(x, y)
    if not in_bounds(x, y) then
        return true
    end
    
    if not state.map then
        return false
    end
    
    -- Check map for opaque tiles
    local tile = state.map.get_tile and state.map.get_tile(x, y)
    if not tile then
        return true
    end
    
    -- Check against spec opaque tile types
    for _, opaque_type in ipairs(spec.fov.opaque_tiles) do
        if tile == opaque_type or tile.type == opaque_type then
            return true
        end
    end
    
    return false
end

--- Calculate distance from origin
--- @param x number
--- @param y number
--- @return number
local function distance(x, y)
    local dx = x - state.origin_x
    local dy = y - state.origin_y
    return math.sqrt(dx * dx + dy * dy)
end

--- Set tile as visible
--- @param x number
--- @param y number
local function set_visible(x, y)
    if not in_bounds(x, y) then return end
    
    state.visible[y] = state.visible[y] or {}
    state.visible[y][x] = true
    
    -- Also mark as explored
    if CONFIG.explored_persists then
        state.explored[y] = state.explored[y] or {}
        state.explored[y][x] = true
    end
end

--------------------------------------------------------------------------------
-- Recursive Shadowcasting
--------------------------------------------------------------------------------

--- Cast light in one octant using recursive shadowcasting
--- @param octant table Octant transformation {xx, xy, yx, yy}
--- @param row number Current row (distance from origin)
--- @param start_slope number Start angle slope
--- @param end_slope number End angle slope
local function cast_light(octant, row, start_slope, end_slope)
    if start_slope < end_slope then
        return
    end
    
    local xx, xy, yx, yy = octant[1], octant[2], octant[3], octant[4]
    local next_start_slope = start_slope
    
    for i = row, CONFIG.radius do
        local blocked = false
        local dy = -i
        
        for dx = -i, 0 do
            -- Map octant coordinates to actual map coordinates
            local map_x = state.origin_x + dx * xx + dy * xy
            local map_y = state.origin_y + dx * yx + dy * yy
            
            -- Calculate slopes
            local left_slope = (dx - 0.5) / (dy + 0.5)
            local right_slope = (dx + 0.5) / (dy - 0.5)
            
            if start_slope < right_slope then
                -- Skip tiles before our start
                goto continue
            elseif end_slope > left_slope then
                -- We've passed our end
                break
            end
            
            -- Check if within radius (circle shape)
            if CONFIG.shape == "circle" then
                if dx * dx + dy * dy <= CONFIG.radius * CONFIG.radius then
                    set_visible(map_x, map_y)
                end
            else
                set_visible(map_x, map_y)
            end
            
            -- Handle blocking
            if blocked then
                if blocks_vision(map_x, map_y) then
                    next_start_slope = right_slope
                else
                    blocked = false
                    start_slope = next_start_slope
                end
            else
                if blocks_vision(map_x, map_y) and i < CONFIG.radius then
                    blocked = true
                    cast_light(octant, i + 1, start_slope, left_slope)
                    next_start_slope = right_slope
                end
            end
            
            ::continue::
        end
        
        if blocked then
            break
        end
    end
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Initialize FOV system with a map reference
--- @param map table Map with get_tile(x, y) function
function M.init(map)
    state.map = map
    
    if map then
        state.width = map.width or 50
        state.height = map.height or 50
    end
    
    -- Initialize visibility arrays
    state.visible = {}
    state.explored = {}
end

--- Set map dimensions (if not provided by map object)
--- @param width number
--- @param height number
function M.set_dimensions(width, height)
    state.width = width
    state.height = height
end

--- Compute FOV from a position
--- @param origin_x number Center X
--- @param origin_y number Center Y
function M.compute(origin_x, origin_y)
    state.origin_x = origin_x
    state.origin_y = origin_y
    
    -- Clear current visibility (but keep explored)
    state.visible = {}
    
    -- Origin is always visible
    set_visible(origin_x, origin_y)
    
    -- Cast light in all 8 octants
    for _, octant in ipairs(OCTANTS) do
        cast_light(octant, 1, 1.0, 0.0)
    end
end

--- Check if a tile is currently visible
--- @param x number
--- @param y number
--- @return boolean
function M.is_visible(x, y)
    if not in_bounds(x, y) then
        return false
    end
    return state.visible[y] and state.visible[y][x] or false
end

--- Check if a tile has been explored
--- @param x number
--- @param y number
--- @return boolean
function M.is_explored(x, y)
    if not in_bounds(x, y) then
        return false
    end
    return state.explored[y] and state.explored[y][x] or false
end

--- Get visibility state for a tile
--- @param x number
--- @param y number
--- @return string "visible", "explored", or "unknown"
function M.get_visibility(x, y)
    if M.is_visible(x, y) then
        return "visible"
    elseif M.is_explored(x, y) then
        return "explored"
    else
        return "unknown"
    end
end

--- Mark a tile as explored (for special cases)
--- @param x number
--- @param y number
function M.mark_explored(x, y)
    if not in_bounds(x, y) then return end
    state.explored[y] = state.explored[y] or {}
    state.explored[y][x] = true
end

--- Clear explored state for a floor (for floor transitions)
function M.clear_explored()
    state.explored = {}
end

--- Save explored state (for floor persistence)
--- @return table Explored state data
function M.save_explored()
    local data = {}
    for y, row in pairs(state.explored) do
        data[y] = {}
        for x, val in pairs(row) do
            if val then
                data[y][x] = true
            end
        end
    end
    return data
end

--- Load explored state
--- @param data table Saved explored data
function M.load_explored(data)
    state.explored = data or {}
end

--- Get current origin
--- @return number, number x, y
function M.get_origin()
    return state.origin_x, state.origin_y
end

--- Get FOV radius
--- @return number
function M.get_radius()
    return CONFIG.radius
end

--- Get all visible tiles (for rendering)
--- @return table Array of {x, y} pairs
function M.get_visible_tiles()
    local tiles = {}
    for y, row in pairs(state.visible) do
        for x, visible in pairs(row) do
            if visible then
                table.insert(tiles, {x = x, y = y})
            end
        end
    end
    return tiles
end

--- Get all explored tiles (for rendering)
--- @return table Array of {x, y} pairs
function M.get_explored_tiles()
    local tiles = {}
    for y, row in pairs(state.explored) do
        for x, explored in pairs(row) do
            if explored then
                table.insert(tiles, {x = x, y = y})
            end
        end
    end
    return tiles
end

return M
