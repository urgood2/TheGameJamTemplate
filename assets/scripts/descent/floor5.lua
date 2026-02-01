-- assets/scripts/descent/floor5.lua
--[[
================================================================================
DESCENT FLOOR 5 (BOSS FLOOR) MODULE
================================================================================
Boss floor rules and arena management.

Features:
- Floor 5 arena spawns per spec.boss
- Boss phases trigger at HP thresholds
- Win condition triggers victory screen
- Guard spawning per phase
- Error handling routes to error screen

Per PLAN.md H1:
- Floor 5 arena spawns per spec
- Boss phases trigger at spec thresholds
- Win condition triggers victory
- Runtime errors route to error screen

Usage:
    local floor5 = require("descent.floor5")
    floor5.init(game_state)
    floor5.update(game_state)
================================================================================
]]

local Floor5 = {}

-- Dependencies
local spec = require("descent.spec")
local Map = require("descent.map")
local Enemy = require("descent.enemy")

-- State
local _state = {
    initialized = false,
    boss = nil,
    guards = {},
    phase = 1,
    summon_cooldown = 0,
    victory = false,
}

-- Callbacks
local callbacks = {
    on_phase_change = nil,
    on_victory = nil,
    on_error = nil,
}

--------------------------------------------------------------------------------
-- Arena Generation
--------------------------------------------------------------------------------

local function create_arena()
    local arena_spec = spec.boss.arena
    local width = arena_spec.width
    local height = arena_spec.height
    
    local map = Map.new(width, height, { default_tile = Map.TILE.WALL })
    
    -- Carve out the arena (simple box)
    for y = 2, height - 1 do
        for x = 2, width - 1 do
            Map.set_tile(map, x, y, Map.TILE.FLOOR)
        end
    end
    
    -- Place stairs up at entrance
    local stairs_x = math.floor(width / 2)
    local stairs_y = height - 2
    Map.set_tile(map, stairs_x, stairs_y, Map.TILE.STAIRS_UP)
    
    return map, { x = stairs_x, y = stairs_y }
end

--------------------------------------------------------------------------------
-- Boss Creation
--------------------------------------------------------------------------------

local function create_boss()
    local boss_stats = spec.boss.stats
    
    -- Register boss template
    Enemy.register_type("boss", {
        hp = boss_stats.hp,
        damage = boss_stats.damage,
        evasion = 5,
        armor = 5,
        speed = boss_stats.speed,
        xp_value = 100,
        sight_radius = 15,  -- Always sees player in arena
    })
    
    local boss = Enemy.create({
        type = "boss",
        x = math.floor(spec.boss.arena.width / 2),
        y = 3,  -- Near top of arena
        hp = boss_stats.hp,
        hp_max = boss_stats.hp,
        damage = boss_stats.damage,
        speed = boss_stats.speed,
        is_boss = true,
    })
    
    boss.phase = 1
    boss.name = "The Guardian"
    
    return boss
end

local function create_guard(x, y)
    return Enemy.create({
        type = "goblin",  -- Use goblin as guard template
        x = x,
        y = y,
    })
end

--------------------------------------------------------------------------------
-- Phase Management
--------------------------------------------------------------------------------

local function get_current_phase(boss)
    if not boss or not boss.alive then
        return nil
    end
    
    local hp_pct = boss.hp / boss.hp_max
    local phases = spec.boss.phases
    
    -- Phases are ordered by hp_pct_min descending
    for i, phase in ipairs(phases) do
        if hp_pct > phase.hp_pct_min then
            return i
        end
    end
    
    return #phases
end

local function get_phase_spec(phase_num)
    return spec.boss.phases[phase_num]
end

local function update_phase(boss, game_state)
    local new_phase = get_current_phase(boss)
    
    if new_phase and new_phase ~= _state.phase then
        local old_phase = _state.phase
        _state.phase = new_phase
        
        local phase_spec = get_phase_spec(new_phase)
        
        -- Apply phase-specific modifiers
        if phase_spec.damage_multiplier then
            boss.damage = math.floor(spec.boss.stats.damage * phase_spec.damage_multiplier)
        end
        
        -- Notify
        if callbacks.on_phase_change then
            callbacks.on_phase_change(new_phase, old_phase, phase_spec)
        end
        
        return true
    end
    
    return false
end

--------------------------------------------------------------------------------
-- Guard Spawning
--------------------------------------------------------------------------------

local function find_spawn_position(map, guards, boss)
    -- Find valid spawn position (floor tile, not occupied)
    local attempts = 0
    local max_attempts = 50
    
    while attempts < max_attempts do
        attempts = attempts + 1
        
        local x = math.random(3, map.w - 2)
        local y = math.random(3, map.h - 2)
        
        -- Check walkable
        if not Map.is_walkable(map, x, y) then
            goto continue
        end
        
        -- Check not occupied by boss
        if boss and boss.x == x and boss.y == y then
            goto continue
        end
        
        -- Check not occupied by guards
        local occupied = false
        for _, guard in ipairs(guards) do
            if guard.alive and guard.x == x and guard.y == y then
                occupied = true
                break
            end
        end
        
        if not occupied then
            return x, y
        end
        
        ::continue::
    end
    
    return nil, nil
end

local function spawn_guards(game_state, count)
    local map = game_state.map
    
    for i = 1, count do
        local x, y = find_spawn_position(map, _state.guards, _state.boss)
        if x then
            local guard = create_guard(x, y)
            table.insert(_state.guards, guard)
            
            -- Add to game enemies
            if game_state.enemies then
                table.insert(game_state.enemies, guard)
            end
        end
    end
end

local function update_summons(game_state)
    local phase_spec = get_phase_spec(_state.phase)
    
    if not phase_spec or phase_spec.behavior ~= "summon_guards" then
        return
    end
    
    -- Check cooldown
    if _state.summon_cooldown > 0 then
        _state.summon_cooldown = _state.summon_cooldown - 1
        return
    end
    
    -- Count alive guards
    local alive_guards = 0
    for _, guard in ipairs(_state.guards) do
        if guard.alive then
            alive_guards = alive_guards + 1
        end
    end
    
    -- Spawn if under max
    local max_guards = spec.boss.guards
    if alive_guards < max_guards then
        local summon_count = phase_spec.summon_count or 1
        spawn_guards(game_state, summon_count)
        _state.summon_cooldown = phase_spec.summon_interval_turns or 5
    end
end

--------------------------------------------------------------------------------
-- Victory Condition
--------------------------------------------------------------------------------

local function check_victory()
    if not _state.boss then
        return false
    end
    
    if spec.boss.win_condition == "boss_hp_zero" then
        return not _state.boss.alive or _state.boss.hp <= 0
    end
    
    return false
end

local function trigger_victory(game_state)
    _state.victory = true
    
    if callbacks.on_victory then
        callbacks.on_victory(game_state)
    end
    
    -- Per spec: victory_screen_then_main_menu
    -- This should be handled by the caller
end

--------------------------------------------------------------------------------
-- Error Handling
--------------------------------------------------------------------------------

local function handle_error(err, game_state)
    if callbacks.on_error then
        callbacks.on_error(err, game_state)
    else
        -- Default: print error
        print("[Floor5] Error: " .. tostring(err))
    end
end

local function safe_call(fn, ...)
    local ok, result = pcall(fn, ...)
    if not ok then
        handle_error(result)
        return nil
    end
    return result
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

function Floor5.init(game_state)
    -- Wrap in error handler
    local ok, err = pcall(function()
        -- Create arena
        local map, player_start = create_arena()
        game_state.map = map
        
        -- Position player
        if game_state.player then
            game_state.player.x = player_start.x
            game_state.player.y = player_start.y
            Map.place(map, "player", player_start.x, player_start.y, game_state.player.id)
        end
        
        -- Create boss
        _state.boss = create_boss()
        Map.place(map, "enemy", _state.boss.x, _state.boss.y, _state.boss.id)
        
        -- Initialize state
        _state.guards = {}
        _state.phase = 1
        _state.summon_cooldown = 0
        _state.victory = false
        _state.initialized = true
        
        -- Add boss to enemies list
        game_state.enemies = game_state.enemies or {}
        table.insert(game_state.enemies, _state.boss)
        
        -- Spawn initial guards
        spawn_guards(game_state, spec.boss.guards)
        
        -- Disable exploration (arena is fully visible)
        if spec.boss.arena.exploration == false then
            game_state.full_visibility = true
        end
    end)
    
    if not ok then
        handle_error(err, game_state)
        return false
    end
    
    return true
end

function Floor5.update(game_state)
    if not _state.initialized then
        return
    end
    
    -- Check victory
    if check_victory() and not _state.victory then
        trigger_victory(game_state)
        return
    end
    
    -- Update phase based on boss HP
    if _state.boss and _state.boss.alive then
        update_phase(_state.boss, game_state)
        update_summons(game_state)
    end
end

function Floor5.get_boss()
    return _state.boss
end

function Floor5.get_guards()
    return _state.guards
end

function Floor5.get_phase()
    return _state.phase
end

function Floor5.is_victory()
    return _state.victory
end

function Floor5.is_initialized()
    return _state.initialized
end

function Floor5.on_phase_change(callback)
    callbacks.on_phase_change = callback
end

function Floor5.on_victory(callback)
    callbacks.on_victory = callback
end

function Floor5.on_error(callback)
    callbacks.on_error = callback
end

function Floor5.reset()
    _state = {
        initialized = false,
        boss = nil,
        guards = {},
        phase = 1,
        summon_cooldown = 0,
        victory = false,
    }
    callbacks.on_phase_change = nil
    callbacks.on_victory = nil
    callbacks.on_error = nil
end

function Floor5.get_state()
    return {
        initialized = _state.initialized,
        phase = _state.phase,
        boss_alive = _state.boss and _state.boss.alive,
        boss_hp = _state.boss and _state.boss.hp,
        boss_hp_max = _state.boss and _state.boss.hp_max,
        guard_count = #_state.guards,
        guards_alive = 0,  -- Calculated below
        victory = _state.victory,
    }
end

return Floor5
