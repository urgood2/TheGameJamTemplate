-- assets/scripts/serpent/snake_controller.lua
-- Runtime snake movement controller for Serpent mode.

local snake_controller = {}

local DEFAULT_ARENA = {
    MAX_SPEED = 180,
    SEGMENT_SPACING = 40,
    ARENA_WIDTH = 800,
    ARENA_HEIGHT = 600,
    ARENA_PADDING = 50,
}

local function resolve_arena(cfg)
    cfg = cfg or {}
    return {
        MAX_SPEED = cfg.MAX_SPEED or DEFAULT_ARENA.MAX_SPEED,
        SEGMENT_SPACING = cfg.SEGMENT_SPACING or DEFAULT_ARENA.SEGMENT_SPACING,
        ARENA_WIDTH = cfg.ARENA_WIDTH or DEFAULT_ARENA.ARENA_WIDTH,
        ARENA_HEIGHT = cfg.ARENA_HEIGHT or DEFAULT_ARENA.ARENA_HEIGHT,
        ARENA_PADDING = cfg.ARENA_PADDING or DEFAULT_ARENA.ARENA_PADDING,
    }
end

local function resolve_segments(snake_entities)
    if not snake_entities then
        return {}
    end
    if snake_entities.segments then
        return snake_entities.segments
    end
    if snake_entities.entities then
        return snake_entities.entities
    end
    return snake_entities
end

local function resolve_entity_id(entry)
    if type(entry) == "number" then
        return entry
    end
    if type(entry) == "table" then
        if entry.entity_id then return entry.entity_id end
        if entry.eid then return entry.eid end
        if entry.id then return entry.id end
        if entry.handle then
            return entry:handle()
        end
    end
    return nil
end

local function get_input_direction(input)
    if type(input) == "function" then
        return input()
    end
    if type(input) == "table" then
        if input.get_direction then
            return input.get_direction()
        end
        if input.dx or input.dy then
            return input.dx or 0, input.dy or 0
        end
    end

    if _G.IsKeyDown then
        local dx, dy = 0, 0
        if _G.IsKeyDown(_G.KEY_A) or _G.IsKeyDown(_G.KEY_LEFT) then dx = dx - 1 end
        if _G.IsKeyDown(_G.KEY_D) or _G.IsKeyDown(_G.KEY_RIGHT) then dx = dx + 1 end
        if _G.IsKeyDown(_G.KEY_W) or _G.IsKeyDown(_G.KEY_UP) then dy = dy - 1 end
        if _G.IsKeyDown(_G.KEY_S) or _G.IsKeyDown(_G.KEY_DOWN) then dy = dy + 1 end
        return dx, dy
    end

    return 0, 0
end

local function normalize(dx, dy)
    local mag = math.sqrt(dx * dx + dy * dy)
    if mag > 0 then
        return dx / mag, dy / mag
    end
    return 0, 0
end

local function clamp_position(pos, arena)
    local min_x = arena.ARENA_PADDING
    local min_y = arena.ARENA_PADDING
    local max_x = arena.ARENA_WIDTH - arena.ARENA_PADDING
    local max_y = arena.ARENA_HEIGHT - arena.ARENA_PADDING

    local clamped_x = math.max(min_x, math.min(max_x, pos.x))
    local clamped_y = math.max(min_y, math.min(max_y, pos.y))
    return clamped_x, clamped_y
end

--- Update snake movement.
--- @param dt number
--- @param snake_entities table[] Head-to-tail entity list or wrapper with .segments
--- @param input table|function|nil Optional input source (dx/dy or get_direction)
--- @param arena_cfg table|nil Movement/arena config
function snake_controller.update(dt, snake_entities, input, arena_cfg)
    local segments = resolve_segments(snake_entities)
    if #segments == 0 then
        return
    end

    local physics = _G.physics
    local PhysicsManager = _G.PhysicsManager
    if not physics or not PhysicsManager or not PhysicsManager.get_world then
        return
    end

    local world = PhysicsManager.get_world("world")
    if not world then
        return
    end

    local arena = resolve_arena(arena_cfg)
    local head_id = resolve_entity_id(segments[1])
    if not head_id then
        return
    end

    local dx, dy = get_input_direction(input)
    dx, dy = normalize(dx, dy)

    local vx = dx * arena.MAX_SPEED
    local vy = dy * arena.MAX_SPEED
    physics.SetVelocity(world, head_id, vx, vy)

    local head_pos = physics.GetPosition(world, head_id)
    if head_pos then
        local clamped_x, clamped_y = clamp_position(head_pos, arena)
        if clamped_x ~= head_pos.x or clamped_y ~= head_pos.y then
            physics.SetPosition(world, head_id, { x = clamped_x, y = clamped_y })
            physics.SetVelocity(world, head_id, 0, 0)
        end
    end

    local spacing = arena.SEGMENT_SPACING
    for i = 2, #segments do
        local prev_id = resolve_entity_id(segments[i - 1])
        local cur_id = resolve_entity_id(segments[i])
        if prev_id and cur_id then
            local prev_pos = physics.GetPosition(world, prev_id)
            local cur_pos = physics.GetPosition(world, cur_id)
            if prev_pos and cur_pos then
                local sx = prev_pos.x - cur_pos.x
                local sy = prev_pos.y - cur_pos.y
                local dist = math.sqrt(sx * sx + sy * sy)
                if dist > spacing and dist > 0 then
                    local nx = sx / dist
                    local ny = sy / dist
                    local new_x = prev_pos.x - nx * spacing
                    local new_y = prev_pos.y - ny * spacing
                    physics.SetPosition(world, cur_id, { x = new_x, y = new_y })
                    physics.SetVelocity(world, cur_id, 0, 0)
                end
            end
        end
    end
end

return snake_controller
