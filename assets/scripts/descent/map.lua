local Map = {}

Map.TILE = {
  FLOOR = "floor",
  WALL = "wall",
  STAIRS_UP = "stairs_up",
  STAIRS_DOWN = "stairs_down",
}

local cached_spec = nil
local function get_spec()
  if not cached_spec then
    cached_spec = require("descent.spec")
  end
  return cached_spec
end

function Map.new(width, height, opts)
  opts = opts or {}
  local default_tile = opts.default_tile or Map.TILE.WALL
  local tiles = {}
  local count = width * height
  for i = 1, count do
    tiles[i] = default_tile
  end
  local map = {
    w = width,
    h = height,
    width = width,
    height = height,
    tiles = tiles,
    default_tile = default_tile,
    occupants = {},
  }
  map.get_tile = function(x, y)
    return Map.get_tile(map, x, y)
  end
  map.set_tile = function(x, y, value)
    return Map.set_tile(map, x, y, value)
  end
  map.is_walkable = function(x, y)
    return Map.is_walkable(map, x, y)
  end
  return map
end

function Map.new_for_floor(floor, spec)
  local resolved_spec = spec or get_spec()
  local floors = resolved_spec and resolved_spec.floors and resolved_spec.floors.floors
  local floor_spec = floors and floors[floor]
  assert(floor_spec, "Unknown floor: " .. tostring(floor))
  return Map.new(floor_spec.width, floor_spec.height, { default_tile = Map.TILE.WALL })
end

function Map.in_bounds(map, x, y)
  if not map or type(x) ~= "number" or type(y) ~= "number" then
    return false
  end
  return x >= 1 and x <= map.w and y >= 1 and y <= map.h
end

function Map.to_index(map, x, y)
  if not Map.in_bounds(map, x, y) then
    return nil
  end
  return (y - 1) * map.w + x
end

function Map.from_index(map, index)
  if not map or type(index) ~= "number" then
    return nil
  end
  if index < 1 or index > (map.w * map.h) then
    return nil
  end
  local y = math.floor((index - 1) / map.w) + 1
  local x = index - (y - 1) * map.w
  return x, y
end

function Map.get_tile(map, x, y)
  local index = Map.to_index(map, x, y)
  if not index then
    return nil
  end
  return map.tiles[index]
end

function Map.is_walkable(map, x, y)
  local tile = Map.get_tile(map, x, y)
  return tile == Map.TILE.FLOOR
    or tile == Map.TILE.STAIRS_UP
    or tile == Map.TILE.STAIRS_DOWN
end

function Map.is_walkable(map, x, y)
  local tile = Map.get_tile(map, x, y)
  return tile ~= nil and tile ~= Map.TILE.WALL
end

function Map.set_tile(map, x, y, value)
  local index = Map.to_index(map, x, y)
  if not index then
    return false
  end
  map.tiles[index] = value
  return true
end

function Map.grid_to_world(map, x, y, tile_size, origin_x, origin_y)
  if not Map.in_bounds(map, x, y) then
    return nil
  end
  local size = tile_size or 1
  local ox = origin_x or 0
  local oy = origin_y or 0
  local wx = ox + (x - 1) * size + (size / 2)
  local wy = oy + (y - 1) * size + (size / 2)
  return wx, wy
end

function Map.world_to_grid(map, wx, wy, tile_size, origin_x, origin_y)
  if not map or type(wx) ~= "number" or type(wy) ~= "number" then
    return nil
  end
  local size = tile_size or 1
  local ox = origin_x or 0
  local oy = origin_y or 0
  local gx = math.floor((wx - ox) / size) + 1
  local gy = math.floor((wy - oy) / size) + 1
  if not Map.in_bounds(map, gx, gy) then
    return nil
  end
  return gx, gy
end

function Map.is_occupied(map, x, y)
  local index = Map.to_index(map, x, y)
  if not index then
    return nil
  end
  return map.occupants[index] ~= nil
end

function Map.get_occupant(map, x, y)
  local index = Map.to_index(map, x, y)
  if not index then
    return nil
  end
  return map.occupants[index]
end

function Map.can_place(map, x, y)
  local index = Map.to_index(map, x, y)
  if not index then
    return false
  end
  return map.occupants[index] == nil
end

function Map.place(map, kind, x, y, id)
  local index = Map.to_index(map, x, y)
  if not index then
    return false
  end
  if map.occupants[index] ~= nil then
    return false
  end
  map.occupants[index] = { kind = kind, id = id }
  return true
end

function Map.remove(map, x, y, kind, id)
  local index = Map.to_index(map, x, y)
  if not index then
    return false
  end
  local occ = map.occupants[index]
  if not occ then
    return false
  end
  if kind and occ.kind ~= kind then
    return false
  end
  if id and occ.id ~= id then
    return false
  end
  map.occupants[index] = nil
  return true
end

return Map
