-- assets/scripts/descent/render.lua
--[[
================================================================================
DESCENT ENTITY RENDERING LAYER
================================================================================
Renders player, enemies, items, and features on map.
Handles visible vs explored distinction.

Features:
- Player rendering at current position
- Enemy rendering with visibility check
- Item rendering on ground
- Feature rendering (stairs, altars, shops)
- Fog of war (explored but not visible tiles)

Usage:
    local render = require("descent.render")
    render.init(state, fov)
    render.draw()
]]

local M = {}

-- Dependencies
local fov = require("descent.fov")
local Map = require("descent.map")

-- State reference
local state = nil

-- Configuration
local config = {
    tile_size = 16,

    colors = {
        visible = { 255, 255, 255, 255 },
        explored = { 100, 100, 100, 180 },
        unseen = { 0, 0, 0, 255 },

        player = { 0, 200, 255, 255 },
        enemy = { 255, 60, 60, 255 },
        enemy_explored = { 120, 40, 40, 100 },
        item = { 255, 220, 0, 255 },
        item_explored = { 120, 100, 0, 100 },

        stairs_down = { 200, 180, 100, 255 },
        stairs_up = { 100, 180, 200, 255 },
        shop = { 255, 200, 100, 255 },
        altar = { 180, 100, 255, 255 },

        floor = { 50, 50, 60, 255 },
        wall = { 80, 80, 100, 255 },
    },

    chars = {
        player = "@",
        floor = ".",
        wall = "#",
        stairs_down = ">",
        stairs_up = "<",
        shop = "$",
        altar = "_",
        item = "*",
    },
}

--------------------------------------------------------------------------------
-- Initialization
--------------------------------------------------------------------------------

--- Initialize render system
--- @param game_state table Game state reference
function M.init(game_state)
    state = game_state

    if not state or not state.map then
        return
    end

    if fov and fov.init then
        fov.init(state.map)

        if fov.set_dimensions then
            local w = state.map.width or state.map.w
            local h = state.map.height or state.map.h
            if w and h then
                fov.set_dimensions(w, h)
            end
        end

        if state.player and state.player.x and state.player.y and fov.compute then
            fov.compute(state.player.x, state.player.y)
        end
    end
end

--- Set a configuration value
--- @param key string Config key
--- @param value any Config value
function M.set_config(key, value)
    config[key] = value
end

--- Get configuration
--- @return table
function M.get_config()
    return config
end

--------------------------------------------------------------------------------
-- Visibility Helpers
--------------------------------------------------------------------------------

--- Check if a tile is visible
--- @param x number
--- @param y number
--- @return boolean
local function is_visible(x, y)
    return fov.is_visible(x, y)
end

--- Check if a tile is explored
--- @param x number
--- @param y number
--- @return boolean
local function is_explored(x, y)
    return fov.is_explored(x, y)
end

--- Get visibility state for rendering
--- @param x number
--- @param y number
--- @return string "visible" | "explored" | "unseen"
local function get_visibility(x, y)
    if is_visible(x, y) then
        return "visible"
    elseif is_explored(x, y) then
        return "explored"
    else
        return "unseen"
    end
end

--------------------------------------------------------------------------------
-- Entity Collection
--------------------------------------------------------------------------------

--- Collect all entities at a position
--- @param x number
--- @param y number
--- @return table Array of entities
function M.get_entities_at(x, y)
    if not state then return {} end

    local entities = {}
    local enemy_list = nil
    if state.enemies then
        if state.enemies.list then
            enemy_list = state.enemies.list
        elseif type(state.enemies) == "table" then
            enemy_list = state.enemies
        end
    end

    -- Player
    if state.player and state.player.x == x and state.player.y == y then
        table.insert(entities, {
            type = "player",
            entity = state.player,
            priority = 100,
        })
    end

    -- Enemies
    if enemy_list then
        for _, enemy in ipairs(enemy_list) do
            if enemy.x == x and enemy.y == y and enemy.hp > 0 then
                table.insert(entities, {
                    type = "enemy",
                    entity = enemy,
                    priority = 50,
                })
            end
        end
    end

    -- Ground items
    if state.ground_items then
        for _, item in ipairs(state.ground_items) do
            if item.x == x and item.y == y then
                table.insert(entities, {
                    type = "item",
                    entity = item,
                    priority = 10,
                })
            end
        end
    end

    -- Features
    if state.map and state.map.features then
        for _, feature in ipairs(state.map.features) do
            if feature.x == x and feature.y == y then
                table.insert(entities, {
                    type = feature.type,
                    entity = feature,
                    priority = 5,
                })
            end
        end
    end

    -- Sort by priority (highest first)
    table.sort(entities, function(a, b)
        return a.priority > b.priority
    end)

    return entities
end

--- Get top entity at position for rendering
--- @param x number
--- @param y number
--- @return table|nil
function M.get_top_entity_at(x, y)
    local entities = M.get_entities_at(x, y)
    return entities[1]
end

--------------------------------------------------------------------------------
-- Tile Rendering
--------------------------------------------------------------------------------

local function get_tile_value(x, y)
    if not state or not state.map then
        return nil
    end
    if state.map.get_tile then
        return state.map.get_tile(x, y)
    end
    if state.map.tiles then
        local row = state.map.tiles[y]
        if type(row) == "table" then
            return row[x]
        end
        local w = state.map.width or state.map.w
        if w then
            local index = (y - 1) * w + x
            return state.map.tiles[index]
        end
    end
    return nil
end

local function normalize_tile(tile)
    if type(tile) == "table" then
        return tile.type or tile.id or tile.kind
    end
    return tile
end

--- Get render info for a tile
--- @param x number
--- @param y number
--- @return table Render info with char, color, visible
function M.get_tile_render(x, y)
    local vis = get_visibility(x, y)

    if vis == "unseen" then
        return {
            char = " ",
            color = config.colors.unseen,
            visible = false,
            explored = false,
        }
    end

    local is_vis = (vis == "visible")

    -- Get map tile
    local tile_char = config.chars.floor
    local tile_color = config.colors.floor

    local tile = normalize_tile(get_tile_value(x, y))
    if tile == Map.TILE.WALL or tile == "wall" or tile == 1 then
        tile_char = config.chars.wall
        tile_color = config.colors.wall
    elseif tile == Map.TILE.STAIRS_DOWN or tile == "stairs_down" then
        tile_char = config.chars.stairs_down
        tile_color = config.colors.stairs_down
    elseif tile == Map.TILE.STAIRS_UP or tile == "stairs_up" then
        tile_char = config.chars.stairs_up
        tile_color = config.colors.stairs_up
    end

    -- Check for entities
    local top_entity = M.get_top_entity_at(x, y)

    if top_entity then
        local et = top_entity.type
        local ent = top_entity.entity

        if et == "player" and is_vis then
            return {
                char = config.chars.player,
                color = config.colors.player,
                visible = true,
                explored = true,
                entity = ent,
            }
        elseif et == "enemy" then
            if is_vis then
                return {
                    char = ent.char or "e",
                    color = config.colors.enemy,
                    visible = true,
                    explored = true,
                    entity = ent,
                }
            else
                -- Don't show enemies in explored-only tiles
                -- (enemies move, so showing last known position is misleading)
            end
        elseif et == "item" then
            return {
                char = config.chars.item,
                color = is_vis and config.colors.item or config.colors.item_explored,
                visible = is_vis,
                explored = true,
                entity = ent,
            }
        elseif et == "stairs_down" then
            return {
                char = config.chars.stairs_down,
                color = is_vis and config.colors.stairs_down
                    or { config.colors.stairs_down[1] * 0.5,
                         config.colors.stairs_down[2] * 0.5,
                         config.colors.stairs_down[3] * 0.5,
                         180 },
                visible = is_vis,
                explored = true,
                entity = ent,
            }
        elseif et == "stairs_up" then
            return {
                char = config.chars.stairs_up,
                color = is_vis and config.colors.stairs_up
                    or { config.colors.stairs_up[1] * 0.5,
                         config.colors.stairs_up[2] * 0.5,
                         config.colors.stairs_up[3] * 0.5,
                         180 },
                visible = is_vis,
                explored = true,
                entity = ent,
            }
        elseif et == "shop" then
            return {
                char = config.chars.shop,
                color = is_vis and config.colors.shop
                    or { config.colors.shop[1] * 0.5,
                         config.colors.shop[2] * 0.5,
                         config.colors.shop[3] * 0.5,
                         180 },
                visible = is_vis,
                explored = true,
                entity = ent,
            }
        elseif et == "altar" then
            return {
                char = config.chars.altar,
                color = is_vis and config.colors.altar
                    or { config.colors.altar[1] * 0.5,
                         config.colors.altar[2] * 0.5,
                         config.colors.altar[3] * 0.5,
                         180 },
                visible = is_vis,
                explored = true,
                entity = ent,
            }
        end
    end

    -- Return base tile
    if not is_vis then
        tile_color = {
            tile_color[1] * 0.5,
            tile_color[2] * 0.5,
            tile_color[3] * 0.5,
            180,
        }
    end

    return {
        char = tile_char,
        color = tile_color,
        visible = is_vis,
        explored = true,
    }
end

--------------------------------------------------------------------------------
-- Full Map Rendering
--------------------------------------------------------------------------------

--- Build render grid for entire map
--- @return table 2D array of render info
function M.build_render_grid()
    if not state or not state.map then
        return {}
    end

    local grid = {}
    local w = state.map.width or state.map.w or 0
    local h = state.map.height or state.map.h or 0

    for y = 1, h do
        grid[y] = {}
        for x = 1, w do
            grid[y][x] = M.get_tile_render(x, y)
        end
    end

    return grid
end

--- Draw the map (placeholder - actual rendering depends on engine)
--- @param offset_x number|nil Screen offset X
--- @param offset_y number|nil Screen offset Y
function M.draw(offset_x, offset_y)
    offset_x = offset_x or 0
    offset_y = offset_y or 0

    local grid = M.build_render_grid()

    if love and love.graphics then
        for y, row in ipairs(grid) do
            for x, tile in ipairs(row) do
                local sx = offset_x + (x - 1) * config.tile_size
                local sy = offset_y + (y - 1) * config.tile_size

                love.graphics.setColor(tile.color)
                love.graphics.print(tile.char, sx, sy)
            end
        end
    end

    return grid
end

--- Get text representation of map
--- @return string
function M.to_string()
    local grid = M.build_render_grid()
    local lines = {}

    for y, row in ipairs(grid) do
        local chars = {}
        for x, tile in ipairs(row) do
            table.insert(chars, tile.char)
        end
        table.insert(lines, table.concat(chars))
    end

    return table.concat(lines, "\n")
end

--------------------------------------------------------------------------------
-- Entity Lists
--------------------------------------------------------------------------------

--- Get all visible enemies
--- @return table Array of visible enemies
function M.get_visible_enemies()
    if not state or not state.enemies then return {} end

    local visible = {}
    local enemy_list = state.enemies.list or state.enemies
    for _, enemy in ipairs(enemy_list or {}) do
        if enemy.hp > 0 and is_visible(enemy.x, enemy.y) then
            table.insert(visible, enemy)
        end
    end
    return visible
end

--- Get all visible items
--- @return table Array of visible items
function M.get_visible_items()
    if not state or not state.ground_items then return {} end

    local visible = {}
    for _, item in ipairs(state.ground_items) do
        if is_visible(item.x, item.y) then
            table.insert(visible, item)
        end
    end
    return visible
end

--- Get player render position
--- @return number|nil, number|nil x, y in screen coords
function M.get_player_screen_pos(offset_x, offset_y)
    if not state or not state.player then return nil, nil end

    offset_x = offset_x or 0
    offset_y = offset_y or 0

    local sx = offset_x + (state.player.x - 1) * config.tile_size
    local sy = offset_y + (state.player.y - 1) * config.tile_size

    return sx, sy
end

return M
