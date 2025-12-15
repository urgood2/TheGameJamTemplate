-- assets/scripts/combat/enemy_factory.lua
-- Creates enemies from definitions and wires up callbacks

local signal = require("external.hump.signal")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local timer = require("core.timer")

local WaveHelpers = require("combat.wave_helpers")
local enemies = require("data.enemies")
local elite_modifiers = require("data.elite_modifiers")

local EnemyFactory = {}

--============================================
-- ENEMY CREATION
--============================================

function EnemyFactory.spawn(enemy_type, position, modifiers)
    modifiers = modifiers or {}

    local def = enemies[enemy_type]
    if not def then
        log_warn("Unknown enemy type: " .. tostring(enemy_type))
        return nil, nil
    end

    -- Create entity with sprite
    local e = animation_system.createAnimatedObjectWithTransform(
        def.sprite or "enemy_default",
        true
    )

    if not e or not entity_cache.valid(e) then
        log_warn("Failed to create enemy entity for: " .. enemy_type)
        return nil, nil
    end

    -- Build context from definition
    local ctx = {
        type = enemy_type,
        hp = def.hp,
        max_hp = def.hp,
        speed = def.speed,
        damage = def.damage or 0,
        size = def.size or { 32, 32 },

        entity = e,
        is_elite = #modifiers > 0,
        modifiers = modifiers,
        invulnerable = false,

        -- Copy callbacks (can be wrapped by modifiers)
        on_death = def.on_death,
        on_hit = def.on_hit,
        on_hit_player = def.on_hit_player,
        on_contact_player = def.on_contact_player,
    }

    -- Copy any extra fields from definition
    for k, v in pairs(def) do
        if ctx[k] == nil and type(v) ~= "function" then
            ctx[k] = v
        end
    end

    -- Apply elite modifiers
    for _, mod_name in ipairs(modifiers) do
        local mod = elite_modifiers[mod_name]
        if mod then
            if mod.hp_mult then ctx.hp = ctx.hp * mod.hp_mult; ctx.max_hp = ctx.hp end
            if mod.speed_mult then ctx.speed = ctx.speed * mod.speed_mult end
            if mod.damage_mult then ctx.damage = ctx.damage * mod.damage_mult end
            if mod.size_mult then
                ctx.size = { ctx.size[1] * mod.size_mult, ctx.size[2] * mod.size_mult }
            end
            if mod.damage_reduction then ctx.damage_reduction = mod.damage_reduction end
            if mod.on_apply then mod.on_apply(e, ctx, WaveHelpers) end
        end
    end

    -- Store context
    WaveHelpers.set_enemy_ctx(e, ctx)

    -- Set position
    local transform = component_cache.get(e, Transform)
    if transform then
        transform.actualX = position.x
        transform.actualY = position.y
        transform.actualW = ctx.size[1]
        transform.actualH = ctx.size[2]
    end

    -- Resize animation
    animation_system.resizeAnimationObjectsInEntityToFit(e, ctx.size[1], ctx.size[2])

    -- Setup collision callbacks
    EnemyFactory.setup_collision(e, ctx)

    -- Setup signal listeners for this enemy
    EnemyFactory.setup_signals(e, ctx)

    -- Apply elite visual if needed
    if ctx.is_elite then
        WaveHelpers.set_shader(e, "elite_glow")
    end

    -- Run on_spawn
    if def.on_spawn then
        def.on_spawn(e, ctx, WaveHelpers)
    end

    -- Emit spawned event
    signal.emit("enemy_spawned", e, ctx)

    return e, ctx
end

--============================================
-- COLLISION SETUP
--============================================

function EnemyFactory.setup_collision(e, ctx)
    local gameObj = registry:get(e, GameObject)
    if not gameObj then return end

    gameObj.state.collisionEnabled = true

    gameObj.methods.onCollision = function(other_entity)
        if other_entity ~= survivorEntity then return end
        if not entity_cache.valid(e) then return end

        -- Call on_contact_player if defined
        if ctx.on_contact_player then
            ctx.on_contact_player(e, ctx, WaveHelpers)
        end

        -- Deal contact damage
        if ctx.damage and ctx.damage > 0 then
            WaveHelpers.deal_damage_to_player(ctx.damage)

            if ctx.on_hit_player then
                ctx.on_hit_player(e, ctx, { damage = ctx.damage, target = survivorEntity }, WaveHelpers)
            end
        end
    end
end

--============================================
-- SIGNAL SETUP
--============================================

function EnemyFactory.setup_signals(e, ctx)
    -- Listen for damage to this enemy
    local damage_handler = function(target, hit_info)
        if target ~= e then return end
        if not entity_cache.valid(e) then return end
        if ctx.invulnerable then return end

        -- Apply damage reduction if any
        local damage = hit_info.damage
        if ctx.damage_reduction then
            damage = damage * (1 - ctx.damage_reduction)
        end

        -- Update HP
        ctx.hp = ctx.hp - damage

        -- Call on_hit callback
        if ctx.on_hit then
            ctx.on_hit(e, ctx, hit_info, WaveHelpers)
        end

        -- Check for death
        if ctx.hp <= 0 then
            EnemyFactory.kill(e, ctx, hit_info)
        end
    end

    -- Register with unique key so we can unregister later
    signal.register("on_entity_damaged", damage_handler)
    ctx._damage_handler = damage_handler
end

--============================================
-- ENEMY DEATH
--============================================

function EnemyFactory.kill(e, ctx, hit_info)
    if not entity_cache.valid(e) then return end

    local death_info = {
        killer = hit_info and hit_info.source or nil,
        damage_type = hit_info and hit_info.damage_type or "unknown",
        overkill = math.abs(ctx.hp),
    }

    -- Call on_death callback
    if ctx.on_death then
        ctx.on_death(e, ctx, death_info, WaveHelpers)
    end

    -- Cleanup timers tagged with this entity
    timer.cancel("enemy_" .. e)
    timer.cancel("enemy_" .. e .. "_dash")
    timer.cancel("enemy_" .. e .. "_trap")
    timer.cancel("enemy_" .. e .. "_summon")
    timer.cancel("elite_" .. e .. "_summon")
    timer.cancel("elite_" .. e .. "_enrage")
    timer.cancel("elite_" .. e .. "_shield")
    timer.cancel("elite_" .. e .. "_regen")
    timer.cancel("elite_" .. e .. "_teleport")

    -- Unregister signal handler
    if ctx._damage_handler then
        signal.remove("on_entity_damaged", ctx._damage_handler)
    end

    -- Emit death signal
    signal.emit("enemy_killed", e, ctx)

    -- Destroy entity
    if entity_cache.valid(e) then
        registry:destroy(e)
    end
end

return EnemyFactory
