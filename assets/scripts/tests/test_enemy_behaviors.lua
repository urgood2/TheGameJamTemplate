package.path = package.path .. ";./?.lua;./assets/scripts/?.lua"

_G.log_debug = function() end
_G.log_error = function(...) print("[ERROR]", ...) end
_G.entt_null = -1
_G.GetFrameTime = function() return 0.016 end
_G.GetTime = function() return 0 end
_G.survivorEntity = 1

local mock_transforms = {}
local mock_entities = { valid = {} }
local entity_counter = 100

_G.Transform = {}
_G.component_cache = {
    get = function(e, ctype)
        if ctype == Transform then
            return mock_transforms[e]
        end
        return nil
    end
}

local entity_cache_mock = {
    valid = function(e)
        return mock_entities.valid[e] == true
    end
}

package.loaded["core.entity_cache"] = entity_cache_mock
package.loaded["core.component_cache"] = _G.component_cache

local timer_tags = {}
local timer_mock = {
    every = function(interval, fn, times, immediate, after, tag)
        if tag then timer_tags[tag] = fn end
        if immediate then fn() end
    end,
    every_opts = function(opts)
        if opts.tag then timer_tags[opts.tag] = opts.action end
        if opts.immediate then opts.action() end
    end,
    after = function(delay, fn, tag)
        if tag then timer_tags[tag] = fn end
    end,
    cancel = function(tag)
        timer_tags[tag] = nil
    end,
}
package.loaded["core.timer"] = timer_mock

local signals_emitted = {}
local signal_mock = {
    emit = function(event, ...)
        signals_emitted[#signals_emitted + 1] = { event = event, args = {...} }
    end,
    register = function() end,
}
package.loaded["external.hump.signal"] = signal_mock

local function create_mock_entity(x, y)
    entity_counter = entity_counter + 1
    local e = entity_counter
    mock_entities.valid[e] = true
    mock_transforms[e] = {
        actualX = x or 0,
        actualY = y or 0,
        visualX = x or 0,
        visualY = y or 0,
        actualW = 32,
        actualH = 32,
    }
    return e
end

local function reset_mocks()
    mock_transforms = {}
    mock_entities.valid = {}
    entity_counter = 100
    timer_tags = {}
    signals_emitted = {}
    
    mock_entities.valid[1] = true
    mock_transforms[1] = { actualX = 200, actualY = 200, actualW = 32, actualH = 32 }
end

local function test_wave_helpers_distance()
    reset_mocks()
    local WaveHelpers = require("combat.wave_helpers")
    package.loaded["combat.wave_helpers"] = nil
    WaveHelpers = require("combat.wave_helpers")
    
    local e = create_mock_entity(100, 100)
    mock_transforms[1] = { actualX = 200, actualY = 200, actualW = 32, actualH = 32 }
    
    local dist = WaveHelpers.distance_to_player(e)
    local expected = math.sqrt(100*100 + 100*100)
    assert(math.abs(dist - expected) < 0.01, "distance_to_player failed: got " .. dist .. ", expected " .. expected)
    
    assert(WaveHelpers.is_in_range(e, 200) == true, "is_in_range should be true within 200px")
    assert(WaveHelpers.is_in_range(e, 100) == false, "is_in_range should be false within 100px")
    
    print("  distance helpers: PASS")
end

local function test_wave_helpers_direction()
    reset_mocks()
    package.loaded["combat.wave_helpers"] = nil
    local WaveHelpers = require("combat.wave_helpers")
    
    local e = create_mock_entity(100, 100)
    mock_transforms[1] = { actualX = 200, actualY = 100, actualW = 32, actualH = 32 }
    
    local dir = WaveHelpers.direction_to_player(e)
    assert(dir ~= nil, "direction_to_player should return value")
    assert(math.abs(dir.x - 1.0) < 0.01, "direction x should be ~1.0, got " .. dir.x)
    assert(math.abs(dir.y) < 0.01, "direction y should be ~0, got " .. dir.y)
    
    local angle = WaveHelpers.angle_to_player(e)
    assert(math.abs(angle) < 0.01, "angle should be ~0 (pointing right), got " .. angle)
    
    print("  direction helpers: PASS")
end

local function test_wave_helpers_movement()
    reset_mocks()
    package.loaded["combat.wave_helpers"] = nil
    local WaveHelpers = require("combat.wave_helpers")
    
    local e = create_mock_entity(100, 100)
    local initial_x = mock_transforms[e].actualX
    
    WaveHelpers.move_toward_point(e, 200, 100, 100)
    assert(mock_transforms[e].actualX > initial_x, "move_toward_point should increase X")
    
    print("  movement helpers: PASS")
end

local function test_wave_helpers_projectiles()
    reset_mocks()
    package.loaded["combat.wave_helpers"] = nil
    local WaveHelpers = require("combat.wave_helpers")
    
    local e = create_mock_entity(100, 100)
    mock_transforms[1] = { actualX = 200, actualY = 100, actualW = 32, actualH = 32 }
    
    signals_emitted = {}
    WaveHelpers.fire_projectile(e, "test_preset", 25)
    
    assert(#signals_emitted == 1, "fire_projectile should emit signal")
    assert(signals_emitted[1].event == "spawn_enemy_projectile", "should emit spawn_enemy_projectile")
    
    signals_emitted = {}
    WaveHelpers.fire_projectile_spread(e, "test_preset", 10, 3, math.pi / 4)
    assert(#signals_emitted == 3, "fire_projectile_spread with count=3 should emit 3 signals")
    
    signals_emitted = {}
    WaveHelpers.fire_projectile_ring(e, "test_preset", 5, 8)
    assert(#signals_emitted == 8, "fire_projectile_ring with count=8 should emit 8 signals")
    
    print("  projectile helpers: PASS")
end

local function test_behaviors_registration()
    reset_mocks()
    package.loaded["core.behaviors"] = nil
    _G.__behaviors__ = nil
    local behaviors = require("core.behaviors")
    
    assert(behaviors.is_registered("chase"), "chase should be registered")
    assert(behaviors.is_registered("wander"), "wander should be registered")
    assert(behaviors.is_registered("flee"), "flee should be registered")
    assert(behaviors.is_registered("kite"), "kite should be registered")
    assert(behaviors.is_registered("dash"), "dash should be registered")
    assert(behaviors.is_registered("ranged_attack"), "ranged_attack should be registered")
    assert(behaviors.is_registered("orbit"), "orbit should be registered")
    assert(behaviors.is_registered("patrol"), "patrol should be registered")
    assert(behaviors.is_registered("strafe"), "strafe should be registered")
    assert(behaviors.is_registered("burst_fire"), "burst_fire should be registered")
    assert(behaviors.is_registered("ambush"), "ambush should be registered")
    assert(behaviors.is_registered("zigzag"), "zigzag should be registered")
    assert(behaviors.is_registered("teleport"), "teleport should be registered")
    
    local list = behaviors.list()
    assert(#list >= 13, "should have at least 13 behaviors, got " .. #list)
    
    print("  behavior registration: PASS")
end

local function test_behaviors_application()
    reset_mocks()
    package.loaded["core.behaviors"] = nil
    _G.__behaviors__ = nil
    local behaviors = require("core.behaviors")
    package.loaded["combat.wave_helpers"] = nil
    local WaveHelpers = require("combat.wave_helpers")
    
    local e = create_mock_entity(100, 100)
    mock_transforms[1] = { actualX = 200, actualY = 200, actualW = 32, actualH = 32 }
    
    local ctx = {
        speed = 60,
        hp = 30,
        max_hp = 30,
        damage = 5,
    }
    
    local behavior_list = { "chase" }
    behaviors.apply(e, ctx, WaveHelpers, behavior_list)
    
    local count = behaviors.count(e)
    assert(count == 1, "should have 1 active behavior, got " .. count)
    
    behaviors.cleanup(e)
    count = behaviors.count(e)
    assert(count == 0, "after cleanup should have 0 behaviors, got " .. count)
    
    print("  behavior application: PASS")
end

local function test_enemies_definitions()
    reset_mocks()
    local enemies = require("data.enemies")
    
    assert(enemies.goblin ~= nil, "goblin should be defined")
    assert(enemies.archer ~= nil, "archer should be defined")
    assert(enemies.dasher ~= nil, "dasher should be defined")
    assert(enemies.trapper ~= nil, "trapper should be defined")
    assert(enemies.summoner ~= nil, "summoner should be defined")
    assert(enemies.exploder ~= nil, "exploder should be defined")
    assert(enemies.wanderer ~= nil, "wanderer should be defined")
    
    assert(enemies.orbiter ~= nil, "orbiter should be defined")
    assert(enemies.sniper ~= nil, "sniper should be defined")
    assert(enemies.shotgunner ~= nil, "shotgunner should be defined")
    assert(enemies.bomber ~= nil, "bomber should be defined")
    assert(enemies.zigzagger ~= nil, "zigzagger should be defined")
    assert(enemies.teleporter_enemy ~= nil, "teleporter_enemy should be defined")
    assert(enemies.ambusher ~= nil, "ambusher should be defined")
    assert(enemies.strafer ~= nil, "strafer should be defined")
    assert(enemies.burst_shooter ~= nil, "burst_shooter should be defined")
    
    assert(enemies.archer.behaviors ~= nil, "archer should have behaviors")
    assert(#enemies.archer.behaviors >= 2, "archer should have at least 2 behaviors")
    
    local has_ranged = false
    for _, b in ipairs(enemies.archer.behaviors) do
        local name = type(b) == "string" and b or b[1]
        if name == "ranged_attack" then has_ranged = true end
    end
    assert(has_ranged, "archer should have ranged_attack behavior")
    
    print("  enemy definitions: PASS")
end

local function test_composite_behaviors()
    reset_mocks()
    package.loaded["core.behaviors"] = nil
    _G.__behaviors__ = nil
    local behaviors = require("core.behaviors")
    
    behaviors.register_composite("test_composite", {
        type = "sequence",
        loop = false,
        steps = {
            { "chase", duration = 1.0 },
            { "wander", duration = 1.0 },
        },
    })
    
    print("  composite behaviors: PASS")
end

local function main()
    print("Running enemy behavior tests...")
    print("")
    
    test_wave_helpers_distance()
    test_wave_helpers_direction()
    test_wave_helpers_movement()
    test_wave_helpers_projectiles()
    test_behaviors_registration()
    test_behaviors_application()
    test_enemies_definitions()
    test_composite_behaviors()
    
    print("")
    print("test_enemy_behaviors: ALL TESTS PASSED")
end

main()
