--[[
================================================================================
STATUS INDICATOR SYSTEM
================================================================================
Renders visual feedback for status effects and marks on entities.

Features:
- Floating icon sprites above entities
- Condensed status bar when 3+ statuses active
- Shader effects on entities
- Looping particle emitters
- Stack count display on marks

Usage:
    local StatusIndicatorSystem = require("systems.status_indicator_system")
    StatusIndicatorSystem.show(entity, "electrocute", 3.0)  -- Show for 3 seconds
    StatusIndicatorSystem.hide(entity, "electrocute")       -- Manual hide
    StatusIndicatorSystem.update(dt)                        -- Call in game loop
]]

local timer = require("core.timer")
local signal = require("external.hump.signal")
local z_orders = require("core.z_orders")
local StatusEffects = require("data.status_effects")

local StatusIndicatorSystem = {
    -- { [entity_id] = { [status_id] = indicator_data } }
    active_indicators = {},

    -- Track applied shaders per entity per status
    -- { [entity_id] = { [status_id] = shader_name } }
    applied_shaders = {},

    -- Config
    MAX_FLOATING_ICONS = 2,
    ICON_BOB_SPEED = 2.0,
    ICON_BOB_AMPLITUDE = 3.0,
    BAR_ICON_SIZE = 12,
    BAR_SPACING = 2,
    BAR_OFFSET_Y = -24,
}

--- Internal: Create indicator data for a status
local function createIndicatorData(entity, status_id, duration, stacks)
    local def = StatusEffects.get(status_id)
    if not def then return nil end

    local data = {
        status_id = status_id,
        entity = entity,
        stacks = stacks or 1,
        start_time = os.clock(),
        duration = duration,
        expires_at = duration and (os.clock() + duration) or nil,
        bob_phase = math.random() * math.pi * 2,

        -- Visual entities (created lazily)
        icon_entity = nil,
        particle_timer_tag = nil,
    }

    return data
end

--- Show a status indicator on an entity
--- @param entity number Entity ID
--- @param status_id string Status effect ID
--- @param duration number|nil Duration in seconds (nil = permanent until hide)
--- @param stacks number|nil Stack count (default 1)
function StatusIndicatorSystem.show(entity, status_id, duration, stacks)
    if not entity or entity == entt_null then return end

    local def = StatusEffects.get(status_id)
    if not def then
        print("[StatusIndicator] Unknown status:", status_id)
        return
    end

    -- Initialize entity's indicator table
    if not StatusIndicatorSystem.active_indicators[entity] then
        StatusIndicatorSystem.active_indicators[entity] = {}
    end

    local indicators = StatusIndicatorSystem.active_indicators[entity]

    -- Update existing or create new
    if indicators[status_id] then
        -- Update stacks and duration
        local data = indicators[status_id]
        data.stacks = stacks or data.stacks
        if duration then
            data.expires_at = os.clock() + duration
            data.duration = duration
        end
    else
        -- Create new indicator
        indicators[status_id] = createIndicatorData(entity, status_id, duration, stacks)

        -- Apply shader if defined
        if def.shader then
            StatusIndicatorSystem.applyShader(entity, status_id, def, stacks or 1)
        end

        -- Start particles if defined
        if def.particles then
            StatusIndicatorSystem.startParticles(entity, status_id, def)
        end
    end

    -- Update display mode (floating vs bar)
    StatusIndicatorSystem.updateDisplayMode(entity)
end

--- Hide a status indicator
--- @param entity number Entity ID
--- @param status_id string Status effect ID
function StatusIndicatorSystem.hide(entity, status_id)
    if not StatusIndicatorSystem.active_indicators[entity] then return end

    local indicators = StatusIndicatorSystem.active_indicators[entity]
    local data = indicators[status_id]

    if data then
        -- Cleanup icon entity
        if data.icon_entity and registry:valid(data.icon_entity) then
            registry:destroy(data.icon_entity)
        end

        -- Stop particles
        if data.particle_timer_tag then
            timer.cancel(data.particle_timer_tag)
        end

        -- Remove shader
        local def = StatusEffects.get(status_id)
        if def and def.shader then
            StatusIndicatorSystem.removeShader(entity, status_id)
        end

        indicators[status_id] = nil
    end

    -- Update display mode
    StatusIndicatorSystem.updateDisplayMode(entity)

    -- Cleanup empty entity entry
    if next(indicators) == nil then
        StatusIndicatorSystem.active_indicators[entity] = nil
    end
end

--- Hide all indicators for an entity
--- @param entity number Entity ID
function StatusIndicatorSystem.hideAll(entity)
    if not StatusIndicatorSystem.active_indicators[entity] then return end

    for status_id, _ in pairs(StatusIndicatorSystem.active_indicators[entity]) do
        StatusIndicatorSystem.hide(entity, status_id)
    end

    -- Cleanup shader tracking
    StatusIndicatorSystem.applied_shaders[entity] = nil
end

--- Update stack count for an indicator
--- @param entity number Entity ID
--- @param status_id string Status effect ID
--- @param stacks number New stack count
function StatusIndicatorSystem.setStacks(entity, status_id, stacks)
    if not StatusIndicatorSystem.active_indicators[entity] then return end

    local data = StatusIndicatorSystem.active_indicators[entity][status_id]
    if data then
        data.stacks = stacks
        local def = StatusEffects.get(status_id)
        if def and def.shader_uniforms_per_stack then
            StatusIndicatorSystem.updateShaderForStacks(entity, status_id, def, stacks)
        end
    end
end

--- Get current stacks for a status on entity
--- @param entity number Entity ID
--- @param status_id string Status effect ID
--- @return number Stack count (0 if not present)
function StatusIndicatorSystem.getStacks(entity, status_id)
    if not StatusIndicatorSystem.active_indicators[entity] then return 0 end
    local data = StatusIndicatorSystem.active_indicators[entity][status_id]
    return data and data.stacks or 0
end

--- Check if entity has a specific status
--- @param entity number Entity ID
--- @param status_id string Status effect ID
--- @return boolean
function StatusIndicatorSystem.hasStatus(entity, status_id)
    if not StatusIndicatorSystem.active_indicators[entity] then return false end
    return StatusIndicatorSystem.active_indicators[entity][status_id] ~= nil
end

--- Get all active statuses on entity
--- @param entity number Entity ID
--- @return table Array of status IDs
function StatusIndicatorSystem.getStatuses(entity)
    local result = {}
    if StatusIndicatorSystem.active_indicators[entity] then
        for status_id, _ in pairs(StatusIndicatorSystem.active_indicators[entity]) do
            table.insert(result, status_id)
        end
    end
    return result
end

--- Calculate icon position above entity
--- @param transform table Entity's Transform component
--- @param indicator_data table Indicator data with bob_phase
--- @param icon_index number Which icon (0-indexed) for horizontal offset
--- @param total_icons number Total icons being rendered
--- @return number, number x, y position
local function calculateIconPosition(transform, indicator_data, icon_index, total_icons)
    local def = StatusEffects.get(indicator_data.status_id)
    local icon_offset = def and def.icon_offset or { x = 0, y = 0 }

    -- Entity center
    local cx = transform.actualX + (transform.actualW or 0) * 0.5
    local cy = transform.actualY

    -- Base offset above entity
    local base_y = cy + StatusIndicatorSystem.BAR_OFFSET_Y + (icon_offset.y or 0)

    -- Bob animation
    local bob = math.sin(indicator_data.bob_phase) * StatusIndicatorSystem.ICON_BOB_AMPLITUDE

    -- Horizontal spread for multiple icons (16px spacing, centered)
    local spacing = 16
    local total_width = (total_icons - 1) * spacing
    local start_x = cx - total_width * 0.5
    local x = start_x + icon_index * spacing + (icon_offset.x or 0)

    return x, base_y + bob
end

--- Get color for status type (fallback when no sprite)
--- @param status_id string Status effect ID
--- @return table Color
function StatusIndicatorSystem.getStatusColor(status_id)
    local color_map = {
        electrocute = "CYAN",
        static_charge = "CYAN",
        static_shield = "BLUE",
        burning = "RED",
        frozen = "ICE",
        exposed = "YELLOW",
        heat_buildup = "ORANGE",
        oil_slick = "PURPLE",
    }
    local color_name = color_map[status_id] or "WHITE"
    return util.getColor(color_name)
end

--- Update display mode based on status count
--- @param entity number Entity ID
function StatusIndicatorSystem.updateDisplayMode(entity)
    if not StatusIndicatorSystem.active_indicators[entity] then return end

    local indicators = StatusIndicatorSystem.active_indicators[entity]
    local count = 0
    for _ in pairs(indicators) do count = count + 1 end

    if count <= StatusIndicatorSystem.MAX_FLOATING_ICONS then
        StatusIndicatorSystem.showFloatingIcons(entity, indicators)
    else
        StatusIndicatorSystem.showStatusBar(entity, indicators)
    end
end

--- Show floating icons (1-2 statuses)
function StatusIndicatorSystem.showFloatingIcons(entity, indicators)
    local transform = component_cache.get(entity, Transform)
    if not transform then return end

    -- Count and collect indicators
    local indicator_list = {}
    for status_id, data in pairs(indicators) do
        table.insert(indicator_list, data)
    end
    local total = #indicator_list

    -- Render each icon
    for i, data in ipairs(indicator_list) do
        local def = StatusEffects.get(data.status_id)
        if not def then goto continue end

        local x, y = calculateIconPosition(transform, data, i - 1, total)
        local icon_size = 16

        -- Try to render sprite, fallback to colored circle
        local sprite_id = def.icon
        if sprite_id and sprites and sprites[sprite_id] then
            command_buffer.queueDrawSprite(layers.sprites, function(c)
                c.sprite = sprite_id
                c.x = x - icon_size * 0.5
                c.y = y - icon_size * 0.5
                c.w = icon_size
                c.h = icon_size
            end, z_orders.status_icons, layer.DrawCommandSpace.World)
        else
            -- Fallback: colored circle based on status type
            local color = StatusIndicatorSystem.getStatusColor(data.status_id)
            command_buffer.queueDrawCircleFilled(layers.sprites, function(c)
                c.x = x
                c.y = y
                c.radius = icon_size * 0.4
                c.color = color
            end, z_orders.status_icons, layer.DrawCommandSpace.World)
        end

        -- Stack count (if applicable)
        if def.show_stacks and data.stacks > 1 then
            command_buffer.queueDrawText(layers.sprites, function(c)
                c.text = tostring(data.stacks)
                c.x = x + 6
                c.y = y + 4
                c.fontSize = 10
                c.color = util.getColor("WHITE")
            end, z_orders.status_icons + 1, layer.DrawCommandSpace.World)
        end

        ::continue::
    end
end

--- Show condensed status bar (3+ statuses)
function StatusIndicatorSystem.showStatusBar(entity, indicators)
    local transform = component_cache.get(entity, Transform)
    if not transform then return end

    -- Entity center
    local cx = transform.actualX + (transform.actualW or 0) * 0.5
    local cy = transform.actualY + StatusIndicatorSystem.BAR_OFFSET_Y

    -- Collect indicators
    local indicator_list = {}
    for status_id, data in pairs(indicators) do
        table.insert(indicator_list, data)
    end
    local total = #indicator_list

    -- Calculate bar dimensions
    local icon_size = StatusIndicatorSystem.BAR_ICON_SIZE
    local spacing = StatusIndicatorSystem.BAR_SPACING
    local total_width = total * icon_size + (total - 1) * spacing
    local start_x = cx - total_width * 0.5

    -- Render each mini icon
    for i, data in ipairs(indicator_list) do
        local def = StatusEffects.get(data.status_id)
        if not def then goto continue end

        local x = start_x + (i - 1) * (icon_size + spacing) + icon_size * 0.5
        local y = cy

        -- Try sprite, fallback to mini colored circle
        local sprite_id = def.icon
        if sprite_id and sprites and sprites[sprite_id] then
            command_buffer.queueDrawSprite(layers.sprites, function(c)
                c.sprite = sprite_id
                c.x = x - icon_size * 0.5
                c.y = y - icon_size * 0.5
                c.w = icon_size
                c.h = icon_size
            end, z_orders.status_icons, layer.DrawCommandSpace.World)
        else
            local color = StatusIndicatorSystem.getStatusColor(data.status_id)
            command_buffer.queueDrawCircleFilled(layers.sprites, function(c)
                c.x = x
                c.y = y
                c.radius = icon_size * 0.35
                c.color = color
            end, z_orders.status_icons, layer.DrawCommandSpace.World)
        end

        ::continue::
    end
end

--- Apply shader effect to entity
function StatusIndicatorSystem.applyShader(entity, status_id, def, stacks)
    if not def.shader then return end

    local ShaderBuilder = require("core.shader_builder")

    -- Determine uniforms (stack-based or default)
    local uniforms = def.shader_uniforms or {}
    if def.shader_uniforms_per_stack and stacks then
        local idx = math.min(stacks, #def.shader_uniforms_per_stack)
        uniforms = def.shader_uniforms_per_stack[idx]
    end

    -- Apply shader
    ShaderBuilder.for_entity(entity)
        :add(def.shader, uniforms)
        :apply()

    -- Track for removal
    if not StatusIndicatorSystem.applied_shaders[entity] then
        StatusIndicatorSystem.applied_shaders[entity] = {}
    end
    StatusIndicatorSystem.applied_shaders[entity][status_id] = def.shader
end

--- Remove shader effect from entity
function StatusIndicatorSystem.removeShader(entity, status_id)
    if not StatusIndicatorSystem.applied_shaders[entity] then return end

    local shader_name = StatusIndicatorSystem.applied_shaders[entity][status_id]
    if not shader_name then return end

    local ShaderBuilder = require("core.shader_builder")

    -- Remove the specific shader
    ShaderBuilder.for_entity(entity)
        :remove(shader_name)
        :apply()

    StatusIndicatorSystem.applied_shaders[entity][status_id] = nil

    -- Cleanup empty entity entry
    if next(StatusIndicatorSystem.applied_shaders[entity]) == nil then
        StatusIndicatorSystem.applied_shaders[entity] = nil
    end
end

--- Update shader uniforms based on stacks
function StatusIndicatorSystem.updateShaderForStacks(entity, status_id, def, stacks)
    if not def.shader_uniforms_per_stack then return end

    local idx = math.min(stacks, #def.shader_uniforms_per_stack)
    local uniforms = def.shader_uniforms_per_stack[idx]

    local ShaderBuilder = require("core.shader_builder")
    ShaderBuilder.for_entity(entity)
        :update(def.shader, uniforms)
        :apply()
end

--- Start particle emitter for status
function StatusIndicatorSystem.startParticles(entity, status_id, def)
    if not def.particles then return end

    local tag = string.format("status_particles_%d_%s", entity, status_id)
    local rate = def.particle_rate or 0.1

    timer.every(rate, function()
        if not StatusIndicatorSystem.hasStatus(entity, status_id) then
            return false  -- Stop timer
        end

        local transform = component_cache.get(entity, Transform)
        if not transform then return end

        local cx = transform.actualX + (transform.actualW or 0) * 0.5
        local cy = transform.actualY + (transform.actualH or 0) * 0.5

        local particleDef = def.particles()
        if particleDef and particleDef.burst then
            if def.particle_orbit then
                -- Spawn in orbit pattern
                local angle = os.clock() * 3 + math.random() * 0.5
                local radius = 20
                particleDef:burst(1):at(cx + math.cos(angle) * radius, cy + math.sin(angle) * radius)
            else
                particleDef:burst(1):at(cx, cy)
            end
        end
    end, -1, false, nil, tag)

    -- Store tag for cleanup
    local data = StatusIndicatorSystem.active_indicators[entity][status_id]
    if data then
        data.particle_timer_tag = tag
    end
end

--- Main update function - call in game loop
--- @param dt number Delta time
function StatusIndicatorSystem.update(dt)
    local now = os.clock()
    local to_remove = {}

    for entity, indicators in pairs(StatusIndicatorSystem.active_indicators) do
        -- Check if entity still exists
        if not registry:valid(entity) then
            table.insert(to_remove, { entity = entity })
        else
            for status_id, data in pairs(indicators) do
                -- Check expiration
                if data.expires_at and now >= data.expires_at then
                    table.insert(to_remove, { entity = entity, status_id = status_id })
                else
                    -- Update bob animation
                    data.bob_phase = data.bob_phase + dt * StatusIndicatorSystem.ICON_BOB_SPEED
                end
            end
        end
    end

    -- Process removals
    for _, removal in ipairs(to_remove) do
        if removal.status_id then
            StatusIndicatorSystem.hide(removal.entity, removal.status_id)
        else
            StatusIndicatorSystem.hideAll(removal.entity)
        end
    end

    -- Render indicators for all entities
    for entity, indicators in pairs(StatusIndicatorSystem.active_indicators) do
        if registry:valid(entity) then
            local count = 0
            for _ in pairs(indicators) do count = count + 1 end

            if count <= StatusIndicatorSystem.MAX_FLOATING_ICONS then
                StatusIndicatorSystem.showFloatingIcons(entity, indicators)
            else
                StatusIndicatorSystem.showStatusBar(entity, indicators)
            end
        end
    end
end

--- Cleanup all indicators (call on scene unload)
function StatusIndicatorSystem.cleanup()
    for entity, _ in pairs(StatusIndicatorSystem.active_indicators) do
        StatusIndicatorSystem.hideAll(entity)
    end
    StatusIndicatorSystem.active_indicators = {}
end

-- Register for entity destruction events
signal.register("entity_destroyed", function(entity)
    StatusIndicatorSystem.hideAll(entity)
end)

return StatusIndicatorSystem
