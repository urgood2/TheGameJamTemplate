-- assets/scripts/descent/snapshot.lua
--[[
================================================================================
DESCENT SNAPSHOT HASH MODULE
================================================================================
Canonical snapshot hashing for determinism verification.

Hash Format (per §5.3):
1. Version (1 byte)
2. Seed (4 bytes)
3. Floor (1 byte)
4. Width/Height (2 bytes each)
5. Tiles (row-major, 1 byte per tile type)
6. Entity count (2 bytes) + sorted entity data
7. Item count (2 bytes) + sorted item data

Uses FNV-1a 32-bit hash for deterministic output.

Usage:
    local snapshot = require("descent.snapshot")
    local hash = snapshot.compute_hash(game_state)
================================================================================
]]

local M = {}

-- FNV-1a constants
local FNV_PRIME = 16777619
local FNV_OFFSET = 2166136261
local UINT32_MAX = 4294967295

-- Snapshot format version
local SNAPSHOT_VERSION = 1

--------------------------------------------------------------------------------
-- FNV-1a Hash Implementation
--------------------------------------------------------------------------------

--- Initialize FNV-1a hash
--- @return number Initial hash value
local function fnv_init()
    return FNV_OFFSET
end

--- Update hash with a single byte
--- @param hash number Current hash
--- @param byte number Byte to hash (0-255)
--- @return number Updated hash
local function fnv_byte(hash, byte)
    hash = hash ~ byte  -- XOR
    hash = (hash * FNV_PRIME) % (UINT32_MAX + 1)
    return hash
end

--- Update hash with multiple bytes
--- @param hash number Current hash
--- @param bytes table Array of bytes
--- @return number Updated hash
local function fnv_bytes(hash, bytes)
    for _, b in ipairs(bytes) do
        hash = fnv_byte(hash, b)
    end
    return hash
end

--- Update hash with a string
--- @param hash number Current hash
--- @param str string String to hash
--- @return number Updated hash
local function fnv_string(hash, str)
    for i = 1, #str do
        hash = fnv_byte(hash, str:byte(i))
    end
    return hash
end

--- Update hash with an integer (big-endian)
--- @param hash number Current hash
--- @param value number Integer value
--- @param bytes number Number of bytes (1, 2, or 4)
--- @return number Updated hash
local function fnv_int(hash, value, bytes)
    value = math.floor(value) % (2 ^ (bytes * 8))
    
    if bytes == 4 then
        hash = fnv_byte(hash, math.floor(value / 16777216) % 256)
        hash = fnv_byte(hash, math.floor(value / 65536) % 256)
        hash = fnv_byte(hash, math.floor(value / 256) % 256)
        hash = fnv_byte(hash, value % 256)
    elseif bytes == 2 then
        hash = fnv_byte(hash, math.floor(value / 256) % 256)
        hash = fnv_byte(hash, value % 256)
    elseif bytes == 1 then
        hash = fnv_byte(hash, value % 256)
    end
    
    return hash
end

--------------------------------------------------------------------------------
-- Tile Type Encoding
--------------------------------------------------------------------------------

local TILE_CODES = {
    floor = 0,
    wall = 1,
    door = 2,
    stairs_up = 3,
    stairs_down = 4,
    shop = 5,
    altar = 6,
    water = 7,
    lava = 8,
    unknown = 255,
}

--- Encode tile type to byte
--- @param tile any Tile value (string or table)
--- @return number Byte code
local function encode_tile(tile)
    if type(tile) == "string" then
        return TILE_CODES[tile] or TILE_CODES.unknown
    elseif type(tile) == "table" then
        return TILE_CODES[tile.type] or TILE_CODES.unknown
    end
    return TILE_CODES.unknown
end

--------------------------------------------------------------------------------
-- Entity/Item Serialization
--------------------------------------------------------------------------------

--- Serialize entity to canonical string
--- @param entity table Entity data
--- @return string Canonical representation
local function serialize_entity(entity)
    -- Format: "type:id:x:y:hp"
    local t = entity.type or entity.template_id or "?"
    local id = entity.id or entity.instance_id or 0
    local x = entity.x or 0
    local y = entity.y or 0
    local hp = entity.hp or 0
    
    return string.format("%s:%d:%d:%d:%d", t, id, x, y, hp)
end

--- Serialize item to canonical string
--- @param item table Item data
--- @return string Canonical representation
local function serialize_item(item)
    -- Format: "template:id:x:y:qty"
    local t = item.template_id or item.type or "?"
    local id = item.instance_id or item.id or 0
    local x = item.x or 0
    local y = item.y or 0
    local qty = item.quantity or 1
    
    return string.format("%s:%d:%d:%d:%d", t, id, x, y, qty)
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Create a snapshot from game state
--- @param state table Game state with map, entities, items, seed, floor
--- @return table Snapshot data
function M.create_snapshot(state)
    local snapshot = {
        version = SNAPSHOT_VERSION,
        seed = state.seed or 0,
        floor = state.floor or 1,
        width = state.width or (state.map and state.map.width) or 0,
        height = state.height or (state.map and state.map.height) or 0,
        tiles = {},
        entities = {},
        items = {},
    }
    
    -- Extract tiles
    if state.tiles then
        snapshot.tiles = state.tiles
    elseif state.map and state.map.tiles then
        snapshot.tiles = state.map.tiles
    elseif state.map and state.map.get_tile then
        for y = 1, snapshot.height do
            snapshot.tiles[y] = {}
            for x = 1, snapshot.width do
                snapshot.tiles[y][x] = state.map.get_tile(x, y)
            end
        end
    end
    
    -- Extract entities (sorted by ID for determinism)
    if state.entities then
        for _, e in pairs(state.entities) do
            table.insert(snapshot.entities, e)
        end
    elseif state.enemy_module and state.enemy_module.get_all then
        for _, e in ipairs(state.enemy_module.get_all()) do
            table.insert(snapshot.entities, e)
        end
    end
    table.sort(snapshot.entities, function(a, b)
        return (a.id or 0) < (b.id or 0)
    end)
    
    -- Extract items (sorted by ID for determinism)
    if state.items then
        for _, i in pairs(state.items) do
            table.insert(snapshot.items, i)
        end
    end
    table.sort(snapshot.items, function(a, b)
        return (a.instance_id or a.id or 0) < (b.instance_id or b.id or 0)
    end)
    
    return snapshot
end

--- Compute FNV-1a hash of a snapshot
--- @param snapshot table Snapshot data (or game state)
--- @return number 32-bit hash value
function M.compute_hash(snapshot)
    -- If given game state, create snapshot first
    if not snapshot.version then
        snapshot = M.create_snapshot(snapshot)
    end
    
    local hash = fnv_init()
    
    -- 1. Version
    hash = fnv_int(hash, snapshot.version, 1)
    
    -- 2. Seed
    hash = fnv_int(hash, snapshot.seed, 4)
    
    -- 3. Floor
    hash = fnv_int(hash, snapshot.floor, 1)
    
    -- 4. Dimensions
    hash = fnv_int(hash, snapshot.width, 2)
    hash = fnv_int(hash, snapshot.height, 2)
    
    -- 5. Tiles (row-major)
    for y = 1, snapshot.height do
        local row = snapshot.tiles[y] or {}
        for x = 1, snapshot.width do
            local tile = row[x]
            hash = fnv_byte(hash, encode_tile(tile))
        end
    end
    
    -- 6. Entities
    hash = fnv_int(hash, #snapshot.entities, 2)
    for _, entity in ipairs(snapshot.entities) do
        hash = fnv_string(hash, serialize_entity(entity))
    end
    
    -- 7. Items
    hash = fnv_int(hash, #snapshot.items, 2)
    for _, item in ipairs(snapshot.items) do
        hash = fnv_string(hash, serialize_item(item))
    end
    
    return hash
end

--- Convert hash to hexadecimal string
--- @param hash number Hash value
--- @return string Hex string
function M.hash_to_hex(hash)
    return string.format("%08x", hash)
end

--- Compare two snapshots
--- @param snap1 table First snapshot
--- @param snap2 table Second snapshot
--- @return boolean True if hashes match
function M.compare(snap1, snap2)
    return M.compute_hash(snap1) == M.compute_hash(snap2)
end

--- Get snapshot summary for debugging
--- @param snapshot table Snapshot data
--- @return string Summary text
function M.get_summary(snapshot)
    if not snapshot.version then
        snapshot = M.create_snapshot(snapshot)
    end
    
    local hash = M.compute_hash(snapshot)
    return string.format(
        "Snapshot v%d: seed=%d floor=%d size=%dx%d entities=%d items=%d hash=%s",
        snapshot.version,
        snapshot.seed,
        snapshot.floor,
        snapshot.width,
        snapshot.height,
        #snapshot.entities,
        #snapshot.items,
        M.hash_to_hex(hash)
    )
end

--- Validate snapshot format
--- @param snapshot table Snapshot to validate
--- @return boolean, string Valid flag and error message
function M.validate(snapshot)
    if not snapshot then
        return false, "Snapshot is nil"
    end
    
    if not snapshot.version or snapshot.version ~= SNAPSHOT_VERSION then
        return false, "Invalid version"
    end
    
    if type(snapshot.seed) ~= "number" then
        return false, "Seed must be a number"
    end
    
    if type(snapshot.floor) ~= "number" or snapshot.floor < 1 then
        return false, "Floor must be a positive number"
    end
    
    if type(snapshot.width) ~= "number" or snapshot.width < 1 then
        return false, "Width must be a positive number"
    end
    
    if type(snapshot.height) ~= "number" or snapshot.height < 1 then
        return false, "Height must be a positive number"
    end
    
    if type(snapshot.tiles) ~= "table" then
        return false, "Tiles must be a table"
    end
    
    return true, nil
end

return M
