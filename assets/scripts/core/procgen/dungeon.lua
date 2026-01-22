-- assets/scripts/core/procgen/dungeon.lua
-- High-level dungeon generation using BSP room placement and corridors
--
-- Usage:
--   local DungeonBuilder = require("core.procgen.dungeon")
--   local result = DungeonBuilder.new(100, 80, {
--     roomMinSize = 8,
--     roomMaxSize = 20,
--     maxRooms = 12,
--     corridorWidth = 2,
--     seed = 12345
--   })
--     :generateRooms()
--     :connectRooms()
--     :addDoors()
--     :populate({
--       enemies = { min = 2, max = 5 },
--       treasures = { min = 1, max = 3 }
--     })
--     :build()
--
-- result.grid       - Final Grid with tile values (0=floor, 1=wall)
-- result.graph      - Room connectivity Graph
-- result.rooms      - Array of room rectangles {x, y, w, h, id}
-- result.spawnPoints - { enemies = {...}, treasures = {...} }

local DungeonBuilder = {}
DungeonBuilder.__index = DungeonBuilder

local vendor = require("core.procgen.vendor")
local Grid = vendor.Grid
local GraphBuilder = require("core.procgen.graph_builder")
local coords = require("core.procgen.coords")

-- Default options
local DEFAULT_OPTS = {
    roomMinSize = 6,
    roomMaxSize = 15,
    maxRooms = 10,
    corridorWidth = 1,
    wallValue = 1,
    floorValue = 0,
    padding = 1,  -- Minimum space between rooms
}

--- Create a new DungeonBuilder
-- @param w number Dungeon width
-- @param h number Dungeon height
-- @param opts table? Options: roomMinSize, roomMaxSize, maxRooms, corridorWidth, seed
-- @return DungeonBuilder
function DungeonBuilder.new(w, h, opts)
    local self = setmetatable({}, DungeonBuilder)
    self._w = w
    self._h = h
    self._opts = {}

    -- Merge defaults with provided options
    for k, v in pairs(DEFAULT_OPTS) do
        self._opts[k] = v
    end
    if opts then
        for k, v in pairs(opts) do
            self._opts[k] = v
        end
    end

    -- Apply seed if provided
    if self._opts.seed then
        math.randomseed(self._opts.seed)
    end

    -- Initialize grid with walls
    self._grid = Grid(w, h, self._opts.wallValue)
    self._rooms = {}
    self._graphBuilder = GraphBuilder.new()
    self._graph = nil
    self._doors = {}
    self._spawnPoints = {
        enemies = {},
        treasures = {}
    }

    return self
end

--- Check if two rectangles overlap (with padding)
local function roomsOverlap(a, b, padding)
    padding = padding or 1
    return not (
        a.x + a.w + padding <= b.x or
        b.x + b.w + padding <= a.x or
        a.y + a.h + padding <= b.y or
        b.y + b.h + padding <= a.y
    )
end

--- Get center of a room
local function roomCenter(room)
    return math.floor(room.x + room.w / 2), math.floor(room.y + room.h / 2)
end

--- Carve a room into the grid
function DungeonBuilder:_carveRoom(room)
    local floor = self._opts.floorValue
    for x = room.x, room.x + room.w - 1 do
        for y = room.y, room.y + room.h - 1 do
            if x >= 1 and x <= self._w and y >= 1 and y <= self._h then
                self._grid:set(x, y, floor)
            end
        end
    end
end

--- Carve a horizontal corridor
function DungeonBuilder:_carveHCorridor(x1, x2, y)
    local floor = self._opts.floorValue
    local width = self._opts.corridorWidth
    local minX = math.min(x1, x2)
    local maxX = math.max(x1, x2)

    for x = minX, maxX do
        for dy = 0, width - 1 do
            local cy = y + dy
            if x >= 1 and x <= self._w and cy >= 1 and cy <= self._h then
                self._grid:set(x, cy, floor)
            end
        end
    end
end

--- Carve a vertical corridor
function DungeonBuilder:_carveVCorridor(y1, y2, x)
    local floor = self._opts.floorValue
    local width = self._opts.corridorWidth
    local minY = math.min(y1, y2)
    local maxY = math.max(y1, y2)

    for y = minY, maxY do
        for dx = 0, width - 1 do
            local cx = x + dx
            if cx >= 1 and cx <= self._w and y >= 1 and y <= self._h then
                self._grid:set(cx, y, floor)
            end
        end
    end
end

--- Generate rooms using random placement with overlap rejection
-- @return DungeonBuilder self for chaining
function DungeonBuilder:generateRooms()
    local minSize = self._opts.roomMinSize
    local maxSize = self._opts.roomMaxSize
    local maxRooms = self._opts.maxRooms
    local padding = self._opts.padding
    local maxAttempts = maxRooms * 10  -- Prevent infinite loops

    local attempts = 0
    while #self._rooms < maxRooms and attempts < maxAttempts do
        attempts = attempts + 1

        -- Generate random room
        local w = math.random(minSize, maxSize)
        local h = math.random(minSize, maxSize)
        local x = math.random(2, self._w - w - 1)
        local y = math.random(2, self._h - h - 1)

        local newRoom = {
            x = x,
            y = y,
            w = w,
            h = h,
            id = "room_" .. (#self._rooms + 1)
        }

        -- Check for overlap with existing rooms
        local overlaps = false
        for _, room in ipairs(self._rooms) do
            if roomsOverlap(newRoom, room, padding) then
                overlaps = true
                break
            end
        end

        if not overlaps then
            -- Carve room into grid
            self:_carveRoom(newRoom)

            -- Add room to list and graph
            table.insert(self._rooms, newRoom)
            local cx, cy = roomCenter(newRoom)
            self._graphBuilder:node(newRoom.id, {
                x = cx,
                y = cy,
                room = newRoom
            })
        end
    end

    return self
end

--- Connect rooms with corridors (minimum spanning tree approach)
-- @return DungeonBuilder self for chaining
function DungeonBuilder:connectRooms()
    if #self._rooms < 2 then
        self._graph = self._graphBuilder:build()
        return self
    end

    -- Simple approach: connect each room to the next (linear chain)
    -- This ensures all rooms are reachable
    for i = 1, #self._rooms - 1 do
        local roomA = self._rooms[i]
        local roomB = self._rooms[i + 1]

        local ax, ay = roomCenter(roomA)
        local bx, by = roomCenter(roomB)

        -- L-shaped corridor: horizontal then vertical, or vice versa
        if math.random() < 0.5 then
            self:_carveHCorridor(ax, bx, ay)
            self:_carveVCorridor(ay, by, bx)
        else
            self:_carveVCorridor(ay, by, ax)
            self:_carveHCorridor(ax, bx, by)
        end

        -- Add edge to graph
        self._graphBuilder:edge(roomA.id, roomB.id)
    end

    -- Optionally add some extra connections for more interesting layouts
    if #self._rooms > 3 then
        local extraConnections = math.random(0, math.floor(#self._rooms / 3))
        for _ = 1, extraConnections do
            local i = math.random(1, #self._rooms)
            local j = math.random(1, #self._rooms)
            if i ~= j then
                local roomA = self._rooms[i]
                local roomB = self._rooms[j]
                local ax, ay = roomCenter(roomA)
                local bx, by = roomCenter(roomB)

                if math.random() < 0.5 then
                    self:_carveHCorridor(ax, bx, ay)
                    self:_carveVCorridor(ay, by, bx)
                else
                    self:_carveVCorridor(ay, by, ax)
                    self:_carveHCorridor(ax, bx, by)
                end

                self._graphBuilder:edge(roomA.id, roomB.id)
            end
        end
    end

    self._graph = self._graphBuilder:build()
    return self
end

--- Add doors at corridor-room transitions
-- TODO: Implement actual door detection at room boundaries
-- For now, this is a placeholder that enables the fluent API
-- Future implementation could detect floor cells where corridors meet room edges
-- @return DungeonBuilder self for chaining
function DungeonBuilder:addDoors()
    self._doors = {}
    -- Placeholder: Door placement not yet implemented
    return self
end

--- Populate rooms with spawn points
-- @param config table Configuration: {enemies = {min, max}, treasures = {min, max}}
-- @return DungeonBuilder self for chaining
function DungeonBuilder:populate(config)
    config = config or {}

    -- Helper to get random floor position in a room
    local function getRandomFloorInRoom(room)
        -- Calculate valid interior bounds (avoiding edges)
        -- Use math.max to handle small rooms where w-2 or h-2 would be invalid
        local minGx = room.x + 1
        local maxGx = math.max(minGx, room.x + room.w - 2)
        local minGy = room.y + 1
        local maxGy = math.max(minGy, room.y + room.h - 2)

        local attempts = 0
        local maxAttempts = 50
        while attempts < maxAttempts do
            attempts = attempts + 1
            local gx = math.random(minGx, maxGx)
            local gy = math.random(minGy, maxGy)
            if self._grid:get(gx, gy) == self._opts.floorValue then
                return gx, gy
            end
        end
        -- Fallback to room center
        return roomCenter(room)
    end

    -- Spawn enemies
    if config.enemies then
        local min = config.enemies.min or 0
        local max = config.enemies.max or 0
        for _, room in ipairs(self._rooms) do
            local count = math.random(min, max)
            for _ = 1, count do
                local gx, gy = getRandomFloorInRoom(room)
                local wx, wy = coords.gridToWorld(gx, gy)
                table.insert(self._spawnPoints.enemies, {
                    gx = gx,
                    gy = gy,
                    wx = wx,
                    wy = wy,
                    roomId = room.id
                })
            end
        end
    end

    -- Spawn treasures
    if config.treasures then
        local min = config.treasures.min or 0
        local max = config.treasures.max or 0
        for _, room in ipairs(self._rooms) do
            local count = math.random(min, max)
            for _ = 1, count do
                local gx, gy = getRandomFloorInRoom(room)
                local wx, wy = coords.gridToWorld(gx, gy)
                table.insert(self._spawnPoints.treasures, {
                    gx = gx,
                    gy = gy,
                    wx = wx,
                    wy = wy,
                    roomId = room.id
                })
            end
        end
    end

    return self
end

--- Build and return the final dungeon result
-- @return table {grid, graph, rooms, spawnPoints}
function DungeonBuilder:build()
    return {
        grid = self._grid,
        graph = self._graph or self._graphBuilder:build(),
        rooms = self._rooms,
        spawnPoints = self._spawnPoints,
        doors = self._doors
    }
end

--- Reset the builder for reuse
-- @return DungeonBuilder self for chaining
function DungeonBuilder:reset()
    if self._opts.seed then
        math.randomseed(self._opts.seed)
    end
    self._grid = Grid(self._w, self._h, self._opts.wallValue)
    self._rooms = {}
    self._graphBuilder = GraphBuilder.new()
    self._graph = nil
    self._doors = {}
    self._spawnPoints = {enemies = {}, treasures = {}}
    return self
end

return DungeonBuilder
