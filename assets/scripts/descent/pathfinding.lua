-- assets/scripts/descent/pathfinding.lua
--[[
================================================================================
DESCENT PATHFINDING
================================================================================
Deterministic pathfinding for Descent mode.

Key requirements (per PLAN.md):
- BFS/A* returns stable path for same map + endpoints
- Neighbor order is explicit and tested (NESW then diagonals)
- Unreachable returns nil (callers handle without crash)
- Deterministic: same input always produces same output

Neighbor Order (clockwise from North):
  N(0,-1), E(1,0), S(0,1), W(-1,0), NE(1,-1), SE(1,1), SW(-1,1), NW(-1,-1)

This order is CANONICAL and TESTED - do not change without updating tests.

Usage:
    local pf = require("descent.pathfinding")
    local path = pf.find_path(map, start_x, start_y, goal_x, goal_y)
    if path then
        -- path is array of {x=, y=} from start to goal (inclusive)
    end
================================================================================
]]

local Pathfinding = {}

-- Canonical neighbor order (NESW then diagonals, clockwise)
-- This order MUST remain stable for determinism
local NEIGHBOR_ORDER = {
    { dx = 0, dy = -1 },  -- North
    { dx = 1, dy = 0 },   -- East
    { dx = 0, dy = 1 },   -- South
    { dx = -1, dy = 0 },  -- West
    { dx = 1, dy = -1 },  -- Northeast
    { dx = 1, dy = 1 },   -- Southeast
    { dx = -1, dy = 1 },  -- Southwest
    { dx = -1, dy = -1 }, -- Northwest
}

-- 4-way neighbors (cardinals only)
local NEIGHBOR_ORDER_4 = {
    { dx = 0, dy = -1 },  -- North
    { dx = 1, dy = 0 },   -- East
    { dx = 0, dy = 1 },   -- South
    { dx = -1, dy = 0 },  -- West
}

--------------------------------------------------------------------------------
-- Utility Functions
--------------------------------------------------------------------------------

--- Create a coordinate key for hash maps
--- @param x number X coordinate
--- @param y number Y coordinate
--- @return string Unique key
local function coord_key(x, y)
    return x .. "," .. y
end

--- Manhattan distance heuristic
--- @param x1 number Start X
--- @param y1 number Start Y
--- @param x2 number Goal X
--- @param y2 number Goal Y
--- @return number Manhattan distance
local function manhattan(x1, y1, x2, y2)
    return math.abs(x2 - x1) + math.abs(y2 - y1)
end

--- Chebyshev distance (for 8-way movement)
--- @param x1 number Start X
--- @param y1 number Start Y
--- @param x2 number Goal X
--- @param y2 number Goal Y
--- @return number Chebyshev distance
local function chebyshev(x1, y1, x2, y2)
    return math.max(math.abs(x2 - x1), math.abs(y2 - y1))
end

--- Reconstruct path from came_from map
--- @param came_from table Map of coord_key -> {x, y}
--- @param start_key string Start key
--- @param goal_key string Goal key
--- @return table Array of {x, y} from start to goal
local function reconstruct_path(came_from, start_key, goal_key)
    local path = {}
    local current_key = goal_key
    
    while current_key do
        local parts = {}
        for part in current_key:gmatch("[^,]+") do
            table.insert(parts, tonumber(part))
        end
        table.insert(path, 1, { x = parts[1], y = parts[2] })
        
        if current_key == start_key then
            break
        end
        current_key = came_from[current_key]
    end
    
    return path
end

--------------------------------------------------------------------------------
-- Simple Priority Queue (min-heap for A*)
--------------------------------------------------------------------------------

local function PriorityQueue()
    local pq = { _data = {} }
    
    function pq:push(item, priority)
        table.insert(self._data, { item = item, priority = priority })
        -- Bubble up
        local i = #self._data
        while i > 1 do
            local parent = math.floor(i / 2)
            if self._data[parent].priority <= self._data[i].priority then
                break
            end
            self._data[parent], self._data[i] = self._data[i], self._data[parent]
            i = parent
        end
    end
    
    function pq:pop()
        if #self._data == 0 then return nil end
        local result = self._data[1].item
        self._data[1] = self._data[#self._data]
        table.remove(self._data)
        -- Bubble down
        local i = 1
        while true do
            local smallest = i
            local left = 2 * i
            local right = 2 * i + 1
            if left <= #self._data and self._data[left].priority < self._data[smallest].priority then
                smallest = left
            end
            if right <= #self._data and self._data[right].priority < self._data[smallest].priority then
                smallest = right
            end
            if smallest == i then break end
            self._data[i], self._data[smallest] = self._data[smallest], self._data[i]
            i = smallest
        end
        return result
    end
    
    function pq:empty()
        return #self._data == 0
    end
    
    return pq
end

--------------------------------------------------------------------------------
-- Map Interface Helpers
--------------------------------------------------------------------------------

--- Check if a tile is walkable
--- @param map table Map with is_walkable(x, y) or get_tile(x, y)
--- @param x number X coordinate
--- @param y number Y coordinate
--- @return boolean Walkable status
local function is_walkable(map, x, y)
    if map.is_walkable then
        return map.is_walkable(x, y)
    elseif map.get_tile then
        local tile = map.get_tile(x, y)
        return tile and tile.walkable
    elseif map.tiles then
        local tile = map.tiles[y] and map.tiles[y][x]
        return tile and tile ~= "wall" and tile ~= "#"
    end
    return false
end

--- Get valid neighbors for a position
--- @param map table Map interface
--- @param x number Current X
--- @param y number Current Y
--- @param allow_diagonal boolean Allow diagonal movement
--- @return table Array of {x, y, dx, dy}
local function get_neighbors(map, x, y, allow_diagonal)
    local neighbors = {}
    local order = allow_diagonal and NEIGHBOR_ORDER or NEIGHBOR_ORDER_4
    
    for _, dir in ipairs(order) do
        local nx, ny = x + dir.dx, y + dir.dy
        if is_walkable(map, nx, ny) then
            -- For diagonals, check corner-cutting rules
            if dir.dx ~= 0 and dir.dy ~= 0 then
                -- Block diagonal if either cardinal is blocked
                local cardinal_x_ok = is_walkable(map, x + dir.dx, y)
                local cardinal_y_ok = is_walkable(map, x, y + dir.dy)
                if cardinal_x_ok and cardinal_y_ok then
                    table.insert(neighbors, { x = nx, y = ny, dx = dir.dx, dy = dir.dy })
                end
            else
                table.insert(neighbors, { x = nx, y = ny, dx = dir.dx, dy = dir.dy })
            end
        end
    end
    
    return neighbors
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Get the canonical neighbor order (for testing)
--- @return table Array of {dx, dy} in canonical order
function Pathfinding.get_neighbor_order()
    local copy = {}
    for _, n in ipairs(NEIGHBOR_ORDER) do
        table.insert(copy, { dx = n.dx, dy = n.dy })
    end
    return copy
end

--- Find path using A* algorithm
--- @param map table Map with is_walkable(x,y) or tiles array
--- @param start_x number Start X
--- @param start_y number Start Y
--- @param goal_x number Goal X
--- @param goal_y number Goal Y
--- @param opts table|nil Options { allow_diagonal = true }
--- @return table|nil Path array or nil if unreachable
function Pathfinding.find_path(map, start_x, start_y, goal_x, goal_y, opts)
    opts = opts or {}
    local allow_diagonal = opts.allow_diagonal ~= false  -- Default true
    
    -- Early exit if start or goal is unwalkable
    if not is_walkable(map, start_x, start_y) then
        return nil
    end
    if not is_walkable(map, goal_x, goal_y) then
        return nil
    end
    
    -- Early exit if start equals goal
    if start_x == goal_x and start_y == goal_y then
        return {{ x = start_x, y = start_y }}
    end
    
    local start_key = coord_key(start_x, start_y)
    local goal_key = coord_key(goal_x, goal_y)
    
    local open_set = PriorityQueue()
    local came_from = {}
    local g_score = { [start_key] = 0 }
    local in_open = { [start_key] = true }
    
    local heuristic = allow_diagonal and chebyshev or manhattan
    open_set:push({ x = start_x, y = start_y }, heuristic(start_x, start_y, goal_x, goal_y))
    
    while not open_set:empty() do
        local current = open_set:pop()
        local current_key = coord_key(current.x, current.y)
        in_open[current_key] = nil
        
        if current_key == goal_key then
            return reconstruct_path(came_from, start_key, goal_key)
        end
        
        local neighbors = get_neighbors(map, current.x, current.y, allow_diagonal)
        
        for _, neighbor in ipairs(neighbors) do
            local neighbor_key = coord_key(neighbor.x, neighbor.y)
            -- Cost: 1 for cardinal, sqrt(2) approx 1.4 for diagonal
            local move_cost = (neighbor.dx ~= 0 and neighbor.dy ~= 0) and 1.4 or 1
            local tentative_g = g_score[current_key] + move_cost
            
            if not g_score[neighbor_key] or tentative_g < g_score[neighbor_key] then
                came_from[neighbor_key] = current_key
                g_score[neighbor_key] = tentative_g
                local f_score = tentative_g + heuristic(neighbor.x, neighbor.y, goal_x, goal_y)
                
                if not in_open[neighbor_key] then
                    open_set:push({ x = neighbor.x, y = neighbor.y }, f_score)
                    in_open[neighbor_key] = true
                end
            end
        end
    end
    
    -- No path found
    return nil
end

--- Find path using BFS (simpler, unweighted)
--- @param map table Map interface
--- @param start_x number Start X
--- @param start_y number Start Y
--- @param goal_x number Goal X
--- @param goal_y number Goal Y
--- @param opts table|nil Options
--- @return table|nil Path array or nil
function Pathfinding.find_path_bfs(map, start_x, start_y, goal_x, goal_y, opts)
    opts = opts or {}
    local allow_diagonal = opts.allow_diagonal ~= false
    
    if not is_walkable(map, start_x, start_y) or not is_walkable(map, goal_x, goal_y) then
        return nil
    end
    
    if start_x == goal_x and start_y == goal_y then
        return {{ x = start_x, y = start_y }}
    end
    
    local start_key = coord_key(start_x, start_y)
    local goal_key = coord_key(goal_x, goal_y)
    
    local queue = {{ x = start_x, y = start_y }}
    local visited = { [start_key] = true }
    local came_from = {}
    
    while #queue > 0 do
        local current = table.remove(queue, 1)
        local current_key = coord_key(current.x, current.y)
        
        if current_key == goal_key then
            return reconstruct_path(came_from, start_key, goal_key)
        end
        
        local neighbors = get_neighbors(map, current.x, current.y, allow_diagonal)
        
        for _, neighbor in ipairs(neighbors) do
            local neighbor_key = coord_key(neighbor.x, neighbor.y)
            if not visited[neighbor_key] then
                visited[neighbor_key] = true
                came_from[neighbor_key] = current_key
                table.insert(queue, { x = neighbor.x, y = neighbor.y })
            end
        end
    end
    
    return nil
end

--- Check if a path exists (faster than find_path for just checking)
--- @param map table Map interface
--- @param start_x number Start X
--- @param start_y number Start Y
--- @param goal_x number Goal X
--- @param goal_y number Goal Y
--- @return boolean True if path exists
function Pathfinding.has_path(map, start_x, start_y, goal_x, goal_y)
    return Pathfinding.find_path_bfs(map, start_x, start_y, goal_x, goal_y) ~= nil
end

--- Get path length (number of steps)
--- @param path table Path array from find_path
--- @return number Number of steps (0 if nil/empty)
function Pathfinding.path_length(path)
    if not path then return 0 end
    return math.max(0, #path - 1)  -- -1 because start doesn't count as a step
end

--- Get next step from a path
--- @param path table Path array
--- @return table|nil Next position {x, y} or nil
function Pathfinding.next_step(path)
    if path and #path >= 2 then
        return path[2]  -- [1] is current position
    end
    return nil
end

return Pathfinding
