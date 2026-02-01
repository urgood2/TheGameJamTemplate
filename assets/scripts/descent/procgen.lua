-- assets/scripts/descent/procgen.lua
--[[
================================================================================
DESCENT PROCEDURAL GENERATION
================================================================================
Floor generation for Descent roguelike mode.

Requirements per PLAN.md D2b:
- Generate floors to spec sizes (15x15, 20x20, 25x25)
- Walkable start/stairs (floors 1-4)
- Reachable start->stairs (BFS validation)
- Quotas enforced (enemies, shop, altar, miniboss, boss)
- No overlaps (stairs not under entity/item)
- Fallback after MAX_ATTEMPTS with log
- Deterministic snapshot hash per §5.3

Usage:
    local procgen = require("descent.procgen")
    local floor_data = procgen.generate(floor_num, seed)
================================================================================
]]

local Procgen = {}

-- Dependencies
local Map = require("descent.map")
local spec = require("descent.spec")
local rng = require("descent.rng")
local pathfinding = require("descent.pathfinding")

-- Constants
local MAX_ATTEMPTS = spec.floors.max_gen_attempts or 50
local ROOM_MIN_SIZE = 3
local ROOM_MAX_SIZE = 7
local MAX_ROOMS = 12

--------------------------------------------------------------------------------
-- Room Generation (BSP-lite)
--------------------------------------------------------------------------------

local function create_room(x, y, w, h)
    return {
        x1 = x,
        y1 = y,
        x2 = x + w - 1,
        y2 = y + h - 1,
        cx = math.floor(x + w / 2),
        cy = math.floor(y + h / 2),
        w = w,
        h = h,
    }
end

local function rooms_overlap(r1, r2, padding)
    padding = padding or 1
    return not (r1.x2 + padding < r2.x1 or r2.x2 + padding < r1.x1 or
                r1.y2 + padding < r2.y1 or r2.y2 + padding < r1.y1)
end

local function carve_room(map, room)
    for y = room.y1, room.y2 do
        for x = room.x1, room.x2 do
            Map.set_tile(map, x, y, Map.TILE.FLOOR)
        end
    end
end

local function carve_corridor_h(map, x1, x2, y)
    local start_x = math.min(x1, x2)
    local end_x = math.max(x1, x2)
    for x = start_x, end_x do
        if Map.in_bounds(map, x, y) then
            Map.set_tile(map, x, y, Map.TILE.FLOOR)
        end
    end
end

local function carve_corridor_v(map, y1, y2, x)
    local start_y = math.min(y1, y2)
    local end_y = math.max(y1, y2)
    for y = start_y, end_y do
        if Map.in_bounds(map, x, y) then
            Map.set_tile(map, x, y, Map.TILE.FLOOR)
        end
    end
end

local function connect_rooms(map, r1, r2)
    -- L-shaped corridor
    if rng.chance(0.5) then
        -- Horizontal first
        carve_corridor_h(map, r1.cx, r2.cx, r1.cy)
        carve_corridor_v(map, r1.cy, r2.cy, r2.cx)
    else
        -- Vertical first
        carve_corridor_v(map, r1.cy, r2.cy, r1.cx)
        carve_corridor_h(map, r1.cx, r2.cx, r2.cy)
    end
end

local function generate_rooms(map)
    local rooms = {}
    local attempts = 0
    local max_room_attempts = 100

    while #rooms < MAX_ROOMS and attempts < max_room_attempts do
        attempts = attempts + 1

        local w = rng.random_int(ROOM_MIN_SIZE, ROOM_MAX_SIZE)
        local h = rng.random_int(ROOM_MIN_SIZE, ROOM_MAX_SIZE)
        local x = rng.random_int(2, map.w - w - 1)
        local y = rng.random_int(2, map.h - h - 1)

        local new_room = create_room(x, y, w, h)
        local overlaps = false

        for _, room in ipairs(rooms) do
            if rooms_overlap(new_room, room, 2) then
                overlaps = true
                break
            end
        end

        if not overlaps then
            carve_room(map, new_room)

            if #rooms > 0 then
                connect_rooms(map, rooms[#rooms], new_room)
            end

            table.insert(rooms, new_room)
        end
    end

    return rooms
end

--------------------------------------------------------------------------------
-- Placement Helpers
--------------------------------------------------------------------------------

local function get_floor_tiles(map)
    local tiles = {}
    for y = 1, map.h do
        for x = 1, map.w do
            if Map.get_tile(map, x, y) == Map.TILE.FLOOR then
                table.insert(tiles, { x = x, y = y })
            end
        end
    end
    return tiles
end

local function is_valid_placement(map, x, y, placements)
    -- Must be floor
    if Map.get_tile(map, x, y) ~= Map.TILE.FLOOR then
        return false
    end
    -- Must not overlap with existing placements
    for _, p in ipairs(placements) do
        if p.x == x and p.y == y then
            return false
        end
    end
    return true
end

local function find_valid_position(map, placements, preferred_tiles)
    local tiles = preferred_tiles or get_floor_tiles(map)
    rng.shuffle(tiles)

    for _, tile in ipairs(tiles) do
        if is_valid_placement(map, tile.x, tile.y, placements) then
            return tile.x, tile.y
        end
    end
    return nil, nil
end

--------------------------------------------------------------------------------
-- Validation
--------------------------------------------------------------------------------

local function validate_reachable(map, start_x, start_y, goal_x, goal_y)
    local path = pathfinding.find_path(map, start_x, start_y, goal_x, goal_y)
    return path ~= nil
end

local function validate_floor(map, placements, floor_num, floor_spec)
    -- Check start position is walkable
    local start = placements.player_start
    if not start then
        return false, "No player start position"
    end
    if Map.get_tile(map, start.x, start.y) ~= Map.TILE.FLOOR then
        return false, "Player start is not walkable"
    end

    -- Check stairs reachability (floors 1-4 need stairs down)
    if floor_spec.stairs_down then
        local stairs = placements.stairs_down
        if not stairs then
            return false, "No stairs down position"
        end
        if not validate_reachable(map, start.x, start.y, stairs.x, stairs.y) then
            return false, "Stairs down not reachable from start"
        end
    end

    -- Check stairs up reachability (floors 2-5)
    if floor_spec.stairs_up then
        local stairs = placements.stairs_up
        if not stairs then
            return false, "No stairs up position"
        end
        if not validate_reachable(map, start.x, start.y, stairs.x, stairs.y) then
            return false, "Stairs up not reachable from start"
        end
    end

    return true, nil
end

--------------------------------------------------------------------------------
-- Main Generation
--------------------------------------------------------------------------------

function Procgen.generate(floor_num, seed)
    local floor_spec = spec.floors.floors[floor_num]
    if not floor_spec then
        error("[Procgen] Unknown floor: " .. tostring(floor_num))
    end

    -- Initialize RNG if seed provided
    if seed then
        rng.init(seed)
    end

    local attempt = 0
    local last_error = nil

    while attempt < MAX_ATTEMPTS do
        attempt = attempt + 1

        -- Create map
        local map = Map.new_for_floor(floor_num)
        local placements = {}
        local all_placements = {}

        -- Generate rooms and corridors
        local rooms = generate_rooms(map)

        if #rooms < 2 then
            last_error = "Not enough rooms generated"
            goto continue
        end

        -- Place player start (first room center)
        local start_room = rooms[1]
        placements.player_start = { x = start_room.cx, y = start_room.cy }
        table.insert(all_placements, placements.player_start)

        -- Place stairs down (last room, floors 1-4)
        if floor_spec.stairs_down then
            local stairs_room = rooms[#rooms]
            local sx, sy = stairs_room.cx, stairs_room.cy
            Map.set_tile(map, sx, sy, Map.TILE.STAIRS_DOWN)
            placements.stairs_down = { x = sx, y = sy }
            table.insert(all_placements, placements.stairs_down)
        end

        -- Place stairs up (floors 2-5)
        if floor_spec.stairs_up then
            local stairs_room = rooms[math.max(1, #rooms - 1)]
            local sx, sy = find_valid_position(map, all_placements,
                {{ x = stairs_room.cx, y = stairs_room.cy }})
            if sx then
                Map.set_tile(map, sx, sy, Map.TILE.STAIRS_UP)
                placements.stairs_up = { x = sx, y = sy }
                table.insert(all_placements, placements.stairs_up)
            end
        end

        -- Validate floor
        local valid, err = validate_floor(map, placements, floor_num, floor_spec)
        if not valid then
            last_error = err
            goto continue
        end

        -- Place enemies
        placements.enemies = {}
        local enemy_count = rng.random_int(floor_spec.enemies_min, floor_spec.enemies_max)
        for i = 1, enemy_count do
            local ex, ey = find_valid_position(map, all_placements)
            if ex then
                table.insert(placements.enemies, { x = ex, y = ey, id = i })
                table.insert(all_placements, { x = ex, y = ey })
            end
        end

        -- Place shop if floor has one
        if floor_spec.shop then
            local sx, sy = find_valid_position(map, all_placements)
            if sx then
                placements.shop = { x = sx, y = sy }
                table.insert(all_placements, placements.shop)
            end
        end

        -- Place altar if floor has one
        if floor_spec.altar then
            local ax, ay = find_valid_position(map, all_placements)
            if ax then
                placements.altar = { x = ax, y = ay }
                table.insert(all_placements, placements.altar)
            end
        end

        -- Place miniboss if floor has one
        if floor_spec.miniboss then
            local mx, my = find_valid_position(map, all_placements)
            if mx then
                placements.miniboss = { x = mx, y = my }
                table.insert(all_placements, placements.miniboss)
            end
        end

        -- Place boss if floor has one
        if floor_spec.boss then
            local bx, by = find_valid_position(map, all_placements)
            if bx then
                placements.boss = { x = bx, y = by }
                table.insert(all_placements, placements.boss)
            end
        end

        -- Success!
        local floor_data = {
            floor_num = floor_num,
            map = map,
            rooms = rooms,
            placements = placements,
            seed = rng.get_seed(),
            attempts = attempt,
            hash = Procgen.compute_hash(map, placements),
        }

        return floor_data, nil

        ::continue::
    end

    -- Fallback: generate simple arena layout
    local warning = string.format(
        "[Procgen] Floor %d failed after %d attempts (last error: %s), using fallback",
        floor_num, MAX_ATTEMPTS, last_error or "unknown"
    )
    if log_warn then
        log_warn(warning)
    else
        print(warning)
    end

    return Procgen.generate_fallback(floor_num), warning
end

--------------------------------------------------------------------------------
-- Fallback Layout
--------------------------------------------------------------------------------

function Procgen.generate_fallback(floor_num)
    local floor_spec = spec.floors.floors[floor_num]
    local map = Map.new_for_floor(floor_num)

    -- Simple box layout: walls around edge, floor in center
    for y = 2, map.h - 1 do
        for x = 2, map.w - 1 do
            Map.set_tile(map, x, y, Map.TILE.FLOOR)
        end
    end

    local placements = {}
    local cx = math.floor(map.w / 2)
    local cy = math.floor(map.h / 2)

    -- Player start at center
    placements.player_start = { x = cx, y = cy }

    -- Stairs in corners
    if floor_spec.stairs_down then
        local sx, sy = map.w - 2, map.h - 2
        Map.set_tile(map, sx, sy, Map.TILE.STAIRS_DOWN)
        placements.stairs_down = { x = sx, y = sy }
    end

    if floor_spec.stairs_up then
        local sx, sy = 2, 2
        Map.set_tile(map, sx, sy, Map.TILE.STAIRS_UP)
        placements.stairs_up = { x = sx, y = sy }
    end

    -- Minimal enemies
    placements.enemies = {}
    for i = 1, floor_spec.enemies_min do
        local ex = rng.random_int(3, map.w - 3)
        local ey = rng.random_int(3, map.h - 3)
        table.insert(placements.enemies, { x = ex, y = ey, id = i })
    end

    return {
        floor_num = floor_num,
        map = map,
        rooms = {},
        placements = placements,
        seed = rng.get_seed(),
        attempts = MAX_ATTEMPTS,
        fallback = true,
        hash = Procgen.compute_hash(map, placements),
    }
end

--------------------------------------------------------------------------------
-- Snapshot Hash (per §5.3)
--------------------------------------------------------------------------------

function Procgen.compute_hash(map, placements)
    -- Simple hash of map tiles and placement positions
    local parts = {}

    -- Map dimensions
    table.insert(parts, string.format("%dx%d", map.w, map.h))

    -- Count floor tiles
    local floor_count = 0
    for i = 1, #map.tiles do
        if map.tiles[i] == Map.TILE.FLOOR then
            floor_count = floor_count + 1
        end
    end
    table.insert(parts, string.format("f%d", floor_count))

    -- Key positions
    if placements.player_start then
        table.insert(parts, string.format("p%d,%d",
            placements.player_start.x, placements.player_start.y))
    end
    if placements.stairs_down then
        table.insert(parts, string.format("sd%d,%d",
            placements.stairs_down.x, placements.stairs_down.y))
    end
    if placements.stairs_up then
        table.insert(parts, string.format("su%d,%d",
            placements.stairs_up.x, placements.stairs_up.y))
    end

    -- Enemy count
    if placements.enemies then
        table.insert(parts, string.format("e%d", #placements.enemies))
    end

    local str = table.concat(parts, "_")

    -- Simple hash (djb2)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + string.byte(str, i)) % 2147483647
    end

    return string.format("%08x", hash)
end

--------------------------------------------------------------------------------
-- Utilities
--------------------------------------------------------------------------------

function Procgen.get_max_attempts()
    return MAX_ATTEMPTS
end

function Procgen.is_walkable(map, x, y)
    local tile = Map.get_tile(map, x, y)
    return tile == Map.TILE.FLOOR or
           tile == Map.TILE.STAIRS_UP or
           tile == Map.TILE.STAIRS_DOWN
end

return Procgen
