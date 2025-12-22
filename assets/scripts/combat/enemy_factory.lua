--[[
================================================================================
ENEMY FACTORY - Enemy Creation with Combat System Integration
================================================================================
Creates enemy entities from definitions in data/enemies.lua and integrates
them with the combat system (stats, weapons, health UI).

PUBLIC API:
    EnemyFactory.spawn(enemy_type, position, modifiers)
        enemy_type: string  -- Key from data/enemies.lua (e.g., "goblin")
        position: {x, y}    -- Spawn coordinates
        modifiers: string[] -- Optional elite modifiers from data/elite_modifiers.lua
        Returns: entity, ctx

    EnemyFactory.kill(e, ctx)
        e: entity           -- Enemy entity to kill
        ctx: table          -- Context returned from spawn()
        Triggers on_death callback and cleanup

USAGE:
    local EnemyFactory = require("combat.enemy_factory")

    -- Spawn basic enemy
    local enemy, ctx = EnemyFactory.spawn("goblin", { x = 100, y = 200 })

    -- Spawn elite enemy with modifiers
    local elite, ctx = EnemyFactory.spawn("goblin", { x = 100, y = 200 }, { "armored", "fast" })

    -- Kill enemy (triggers on_death, cleanup, signals)
    EnemyFactory.kill(enemy, ctx)

INTEGRATION:
    - Adds entity to ACTION_STATE
    - Creates combat actor with stats
    - Registers in enemyHealthUiState for HP bars
    - Sets up physics body with "enemy" tag
    - Registers steering for movement
    - Calls on_spawn from enemy definition

Dependencies: data/enemies.lua, data/elite_modifiers.lua, combat/wave_helpers.lua
]]

local signal = require("external.hump.signal")
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")
local timer = require("core.timer")
local Node = require("monobehavior.behavior_script_v2")
local PhysicsBuilder = require("core.physics_builder")
local C = require("core.constants")
local CombatSystem = require("combat.combat_system")
local behaviors = require("core.behaviors")

local WaveHelpers = require("combat.wave_helpers")
local enemies = require("data.enemies")
local elite_modifiers = require("data.elite_modifiers")

---@class EnemyContext
---@field type string Enemy type from data/enemies.lua
---@field hp number Current health
---@field max_hp number Maximum health
---@field speed number Movement speed
---@field damage number Contact damage
---@field size {[1]: number, [2]: number} Width, height
---@field entity number Entity ID
---@field is_elite boolean Has elite modifiers
---@field modifiers string[] Applied modifier names
---@field invulnerable boolean Damage immunity flag
---@field on_death fun(e: number, ctx: EnemyContext, helpers: table)? Death callback
---@field on_hit fun(e: number, ctx: EnemyContext, damage: number, helpers: table)? Hit callback
---@field on_contact_player fun(e: number, ctx: EnemyContext, helpers: table)? Player contact callback

local EnemyFactory = {}

-- Basic monster weapon (same as gameplay.lua)
local basic_monster_weapon = {
    id = 'basic_monster_weapon',
    slot = 'sword1',
    mods = {
        { stat = 'weapon_min', base = 6 },
        { stat = 'weapon_max', base = 10 },
    },
}

--============================================
-- ENEMY CREATION
--============================================

---@param enemy_type string Key from data/enemies.lua
---@param position {x: number, y: number} Spawn position
---@param modifiers string[]? Elite modifier names from data/elite_modifiers.lua
---@return number? entity Entity ID (nil on failure)
---@return EnemyContext? ctx Enemy context (nil on failure)
function EnemyFactory.spawn(enemy_type, position, modifiers)
    modifiers = modifiers or {}

    local def = enemies[enemy_type]
    if not def then
        print("[EnemyFactory] Unknown enemy type: " .. tostring(enemy_type))
        return nil, nil
    end

    -- Create entity with sprite
    local e = animation_system.createAnimatedObjectWithTransform(
        def.sprite or "enemy_default",
        true
    )

    if not e or not entity_cache.valid(e) then
        print("[EnemyFactory] Failed to create enemy entity for: " .. enemy_type)
        return nil, nil
    end

    -- Add state tag so enemy updates/renders during action phase
    add_state_tag(e, ACTION_STATE)
    remove_default_state_tag(e)

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

    -- Store context in WaveHelpers for wave system tracking
    WaveHelpers.set_enemy_ctx(e, ctx)

    -- Set position
    local transform = component_cache.get(e, Transform)
    if transform then
        transform.actualX = position.x
        transform.actualY = position.y
        transform.actualW = ctx.size[1]
        transform.actualH = ctx.size[2]
        -- Snap visual to actual (prevents interpolation from spawn point)
        transform.visualX = transform.actualX
        transform.visualY = transform.actualY
    end

    -- Resize animation
    animation_system.resizeAnimationObjectsInEntityToFit(e, ctx.size[1], ctx.size[2])

    -- Give physics body using PhysicsBuilder (replaces 20+ lines of manual setup)
    -- Use circle shape to prevent corner wedging (rectangles can get stuck in corners)
    -- Use friction(0) to prevent wall sticking (steering pushes into walls; friction prevents sliding)
    local physicsSuccess = PhysicsBuilder.for_entity(e)
        :circle()
        :tag(C.CollisionTags.ENEMY)
        :sensor(false)
        :density(1.0)
        :friction(0)
        :inflate(-4)
        :collideWith({ C.CollisionTags.PLAYER, C.CollisionTags.ENEMY, C.CollisionTags.PROJECTILE })
        :apply()

    if not physicsSuccess then
        print("[EnemyFactory] WARNING: Physics setup failed for enemy!")
    end

    -- Add shader pipeline for proper rendering
    if shader_pipeline and shader_pipeline.ShaderPipelineComponent then
        registry:emplace(e, shader_pipeline.ShaderPipelineComponent)
    end

    -- Make steerable for physics-based movement (matches gameplay.lua pattern)
    if steering and steering.make_steerable then
        steering.make_steerable(registry, e, 3000.0, 30000.0, math.pi * 2.0, 2.0)
    end

    --============================================
    -- COMBAT SYSTEM INTEGRATION (matches gameplay.lua:8708-8739)
    --============================================

    -- Create combat actor
    local combatActor = nil
    local combatCtx = rawget(_G, "combat_context")

    -- DEBUG: Check combat system availability
    print("[EnemyFactory] combat_context:", combatCtx and "EXISTS" or "NIL")
    print("[EnemyFactory] CombatSystem.Game:", CombatSystem and CombatSystem.Game and "EXISTS" or "NIL")

    if combatCtx and combatCtx._make_actor and CombatSystem and CombatSystem.Game then
        combatActor = combatCtx._make_actor(
            enemy_type,
            combatCtx.stat_defs,
            CombatSystem.Game.Content.attach_attribute_derivations
        )
        combatActor.side = 2  -- Enemy side

        -- Set up stats from definition
        combatActor.stats:add_base('health', ctx.hp)
        combatActor.stats:add_base('offensive_ability', 10)
        combatActor.stats:add_base('defensive_ability', 10)
        combatActor.stats:add_base('armor', 0)
        combatActor.stats:add_base('armor_absorption_bonus_pct', 0)
        combatActor.stats:add_base('fire_resist_pct', 0)
        combatActor.stats:add_base('dodge_chance_pct', 0)
        combatActor.stats:recompute()

        -- Equip basic weapon
        if CombatSystem.Game.ItemSystem and CombatSystem.Game.ItemSystem.equip then
            CombatSystem.Game.ItemSystem.equip(combatCtx, combatActor, basic_monster_weapon)
        end
        print("[EnemyFactory] Created combatActor for", enemy_type)
    else
        print("[EnemyFactory] WARNING: Could not create combatActor! Missing:",
            not combatCtx and "combat_context" or "",
            not (combatCtx and combatCtx._make_actor) and "_make_actor" or "",
            not CombatSystem and "CombatSystem" or "",
            not (CombatSystem and CombatSystem.Game) and "CombatSystem.Game" or "")
    end

    -- Create Node script with combatTable (matches gameplay.lua:8735-8739)
    local enemyScriptNode = Node {}
    enemyScriptNode.combatTable = combatActor
    enemyScriptNode.waveCtx = ctx  -- Store wave context for custom behaviors
    enemyScriptNode:attach_ecs { create_new = false, existing_entity = e }

    -- Register combat actor mappings (CRITICAL for projectile damage)
    if combatActor then
        if _G.combatActorToEntity then
            _G.combatActorToEntity[combatActor] = e
        end
    end

    -- Register in enemyHealthUiState (CRITICAL: required for isEnemyEntity() to work)
    if _G.enemyHealthUiState then
        _G.enemyHealthUiState[e] = {
            actor = combatActor,
            visibleUntil = 0,
        }
    end

    --============================================
    -- STEERING UPDATE (matches gameplay.lua:8770-8790)
    --============================================

    -- Physics step update for steering-based movement
    local steeringTimerTag = "wave_enemy_steering_" .. tostring(e)
    timer.every_physics_step(function()
        if not entity_cache.valid(e) then return false end  -- Cancel timer
        if isLevelUpModalActive and isLevelUpModalActive() then return end

        local playerLocation = { x = 0, y = 0 }
        local playerT = survivorEntity and component_cache.get(survivorEntity, Transform)
        if playerT then
            playerLocation.x = playerT.actualX + playerT.actualW / 2
            playerLocation.y = playerT.actualY + playerT.actualH / 2
        end

        -- Seek player with steering (matches gameplay.lua pattern)
        if steering and steering.seek_point then
            steering.seek_point(registry, e, playerLocation, 1.0, 0.5)
            steering.wander(registry, e, 300.0, 300.0, 150.0, 3)
        end
    end, steeringTimerTag)

    ctx._steering_timer_tag = steeringTimerTag

    -- Apply elite visual if needed
    if ctx.is_elite then
        WaveHelpers.set_shader(e, "elite_glow")
    end

    -- Run on_spawn callback from definition (legacy support)
    if def.on_spawn then
        def.on_spawn(e, ctx, WaveHelpers)
    end

    -- Apply declarative behaviors (new system)
    if def.behaviors then
        behaviors.apply(e, ctx, WaveHelpers, def.behaviors)
    end

    -- Emit spawned event
    signal.emit("enemy_spawned", e, ctx)

    return e, ctx
end

--============================================
-- ENEMY DEATH (called by wave director on enemy_killed signal)
--============================================

---@param e number Enemy entity ID
---@param ctx EnemyContext? Enemy context from spawn()
function EnemyFactory.kill(e, ctx)
    if not entity_cache.valid(e) then return end

    -- Call on_death callback
    if ctx and ctx.on_death then
        ctx.on_death(e, ctx, {}, WaveHelpers)
    end

    -- Cancel steering timer
    if ctx and ctx._steering_timer_tag then
        timer.cancel(ctx._steering_timer_tag)
    end

    -- Cleanup declarative behaviors (auto-tracked timers)
    behaviors.cleanup(e)

    -- Cleanup legacy timers tagged with this entity (for backwards compatibility)
    timer.cancel("enemy_" .. e)
    timer.cancel("enemy_" .. e .. "_dash")
    timer.cancel("enemy_" .. e .. "_trap")
    timer.cancel("enemy_" .. e .. "_summon")
    timer.cancel("elite_" .. e .. "_summon")
    timer.cancel("elite_" .. e .. "_enrage")
    timer.cancel("elite_" .. e .. "_shield")
    timer.cancel("elite_" .. e .. "_regen")
    timer.cancel("elite_" .. e .. "_teleport")

    -- Remove from enemyHealthUiState
    if _G.enemyHealthUiState then
        _G.enemyHealthUiState[e] = nil
    end

    -- Remove from combatActorToEntity
    if ctx and ctx.combatActor and _G.combatActorToEntity then
        _G.combatActorToEntity[ctx.combatActor] = nil
    end

    -- Emit death signal for wave director
    signal.emit("enemy_killed", e, ctx)

    -- Destroy entity
    if entity_cache.valid(e) then
        registry:destroy(e)
    end
end

return EnemyFactory
