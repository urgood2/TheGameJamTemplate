--[[
================================================================================
TEST: API Wrappers (Particle Helpers + API Aliases)
================================================================================
Comprehensive test suite for:
1. particle_helpers module - dual-signature wrappers
2. api_aliases module - snake_case global aliases

Run with: lua assets/scripts/tests/test_api_wrappers.lua
================================================================================
]]

--------------------------------------------------------------------------------
-- Setup: Adjust package path and mock globals
--------------------------------------------------------------------------------

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Mock logging functions
_G.log_debug = function() end
_G.log_error = function(...) print("[ERROR]", ...) end
_G.log_warn = function(...) print("[WARN]", ...) end

-- Clear cached modules
package.loaded["core.particle_helpers"] = nil
package.loaded["core.api_aliases"] = nil
_G.__PARTICLE_HELPERS__ = nil
_G.__API_ALIASES__ = nil

local t = require("tests.test_runner")

--------------------------------------------------------------------------------
-- Mock Particle Functions
--------------------------------------------------------------------------------

local particle_calls = {}

local function reset_particle_calls()
    particle_calls = {
        burst = {},
        swirl = {},
        swirl_ring = {},
    }
end

-- Mock spawnCircularBurstParticles
_G.spawnCircularBurstParticles = function(x, y, count, duration, startColor, endColor, easing, space)
    table.insert(particle_calls.burst, {
        x = x, y = y,
        count = count,
        duration = duration,
        startColor = startColor,
        endColor = endColor,
        easing = easing,
        space = space,
    })
end

-- Mock makeSwirlEmitter
_G.makeSwirlEmitter = function(x, y, radius, colorSet, emitDuration, totalLifetime)
    local call = {
        x = x, y = y,
        radius = radius,
        colorSet = colorSet,
        emitDuration = emitDuration,
        totalLifetime = totalLifetime,
    }
    table.insert(particle_calls.swirl, call)
    return { type = "swirl_emitter", params = call }
end

-- Mock makeSwirlEmitterWithRing
_G.makeSwirlEmitterWithRing = function(x, y, radius, colorSet, emitDuration, totalLifetime)
    local call = {
        x = x, y = y,
        radius = radius,
        colorSet = colorSet,
        emitDuration = emitDuration,
        totalLifetime = totalLifetime,
    }
    table.insert(particle_calls.swirl_ring, call)
    return { type = "swirl_ring_emitter", params = call }
end

--------------------------------------------------------------------------------
-- Mock Engine Globals (for api_aliases)
--------------------------------------------------------------------------------

local alias_calls = {}

local function reset_alias_calls()
    alias_calls = {}
end

local function make_mock(name)
    return function(...)
        alias_calls[name] = alias_calls[name] or {}
        table.insert(alias_calls[name], {...})
        return "result_" .. name
    end
end

-- Install mock engine globals
_G.getEntityByAlias = make_mock("getEntityByAlias")
_G.setEntityAlias = make_mock("setEntityAlias")
_G.playSoundEffect = make_mock("playSoundEffect")
_G.playMusic = make_mock("playMusic")
_G.playPlaylist = make_mock("playPlaylist")
_G.stopAllMusic = make_mock("stopAllMusic")
_G.clearPlaylist = make_mock("clearPlaylist")
_G.resetSoundSystem = make_mock("resetSoundSystem")
_G.setSoundPitch = make_mock("setSoundPitch")
_G.toggleLowPassFilter = make_mock("toggleLowPassFilter")
_G.toggleDelayEffect = make_mock("toggleDelayEffect")
_G.setLowPassTarget = make_mock("setLowPassTarget")
_G.setLowPassSpeed = make_mock("setLowPassSpeed")
_G.pauseGame = make_mock("pauseGame")
_G.unpauseGame = make_mock("unpauseGame")
_G.isKeyPressed = make_mock("isKeyPressed")
_G.propagateStateEffectsToUIBox = make_mock("propagateStateEffectsToUIBox")

--------------------------------------------------------------------------------
-- Load Modules Under Test
--------------------------------------------------------------------------------

local particles = require("core.particle_helpers")
local aliases = require("core.api_aliases")

t.describe("particle_helpers.burst", function()
    
    t.it("accepts positional arguments", function()
        reset_particle_calls()
        local RED = { r = 255, g = 0, b = 0 }
        local BLUE = { r = 0, g = 0, b = 255 }
        
        particles.burst(100, 200, 15, 2.0, RED, BLUE, "linear", "world")
        
        t.expect(#particle_calls.burst).to_be(1)
        local call = particle_calls.burst[1]
        t.expect(call.x).to_be(100)
        t.expect(call.y).to_be(200)
        t.expect(call.count).to_be(15)
        t.expect(call.duration).to_be(2.0)
        t.expect(call.easing).to_be("linear")
        t.expect(call.space).to_be("world")
    end)
    
    t.it("accepts options table", function()
        reset_particle_calls()
        local RED = { r = 255, g = 0, b = 0 }
        local BLUE = { r = 0, g = 0, b = 255 }
        
        particles.burst({
            x = 50, y = 75,
            count = 20,
            duration = 1.5,
            startColor = RED,
            endColor = BLUE,
            easing = "expo",
            space = "screen"
        })
        
        t.expect(#particle_calls.burst).to_be(1)
        local call = particle_calls.burst[1]
        t.expect(call.x).to_be(50)
        t.expect(call.y).to_be(75)
        t.expect(call.count).to_be(20)
        t.expect(call.duration).to_be(1.5)
        t.expect(call.easing).to_be("expo")
        t.expect(call.space).to_be("screen")
    end)
    
    t.it("uses default values for missing options", function()
        reset_particle_calls()
        particles.burst({ x = 10, y = 20 })
        
        t.expect(#particle_calls.burst).to_be(1)
        local call = particle_calls.burst[1]
        t.expect(call.count).to_be(10)
        t.expect(call.duration).to_be(1.0)
        t.expect(call.easing).to_be("cubic")
        t.expect(call.space).to_be("screen")
    end)
    
    t.it("uses defaults for missing positional args", function()
        reset_particle_calls()
        particles.burst(5, 10)
        
        t.expect(#particle_calls.burst).to_be(1)
        local call = particle_calls.burst[1]
        t.expect(call.x).to_be(5)
        t.expect(call.y).to_be(10)
        t.expect(call.count).to_be(10)
        t.expect(call.duration).to_be(1.0)
    end)
end)

t.describe("particle_helpers.swirl", function()
    
    t.it("accepts positional arguments", function()
        reset_particle_calls()
        local colors = {{ r = 255 }, { r = 0 }}
        
        local emitter = particles.swirl(100, 200, 75, colors, 2.0, 3.0)
        
        t.expect(#particle_calls.swirl).to_be(1)
        t.expect(emitter).to_be_truthy()
        t.expect(emitter.type).to_be("swirl_emitter")
        
        local call = particle_calls.swirl[1]
        t.expect(call.x).to_be(100)
        t.expect(call.y).to_be(200)
        t.expect(call.radius).to_be(75)
        t.expect(call.emitDuration).to_be(2.0)
        t.expect(call.totalLifetime).to_be(3.0)
    end)
    
    t.it("accepts options table", function()
        reset_particle_calls()
        local colors = {{ r = 255 }, { r = 128 }}
        
        local emitter = particles.swirl({
            x = 50, y = 60,
            radius = 100,
            colors = colors,
            emitDuration = 1.5,
            totalLifetime = 2.5
        })
        
        t.expect(#particle_calls.swirl).to_be(1)
        t.expect(emitter).to_be_truthy()
        
        local call = particle_calls.swirl[1]
        t.expect(call.x).to_be(50)
        t.expect(call.y).to_be(60)
        t.expect(call.radius).to_be(100)
        t.expect(call.emitDuration).to_be(1.5)
        t.expect(call.totalLifetime).to_be(2.5)
    end)
    
    t.it("uses default values for missing options", function()
        reset_particle_calls()
        local emitter = particles.swirl({ x = 0, y = 0 })
        
        t.expect(#particle_calls.swirl).to_be(1)
        local call = particle_calls.swirl[1]
        t.expect(call.radius).to_be(50)
        t.expect(call.emitDuration).to_be(1.0)
        t.expect(call.totalLifetime).to_be(2.0)
    end)
    
    t.it("returns emitter object", function()
        reset_particle_calls()
        local emitter = particles.swirl(0, 0, 50, nil, 1.0, 2.0)
        
        t.expect(emitter).to_be_truthy()
        t.expect(type(emitter)).to_be("table")
    end)
end)

t.describe("particle_helpers.swirl_with_ring", function()
    
    t.it("accepts positional arguments", function()
        reset_particle_calls()
        local colors = {{ r = 0, g = 255, b = 255 }}
        
        local emitter = particles.swirl_with_ring(80, 90, 60, colors, 1.0, 2.0)
        
        t.expect(#particle_calls.swirl_ring).to_be(1)
        t.expect(emitter).to_be_truthy()
        t.expect(emitter.type).to_be("swirl_ring_emitter")
        
        local call = particle_calls.swirl_ring[1]
        t.expect(call.x).to_be(80)
        t.expect(call.y).to_be(90)
        t.expect(call.radius).to_be(60)
    end)
    
    t.it("accepts options table", function()
        reset_particle_calls()
        local emitter = particles.swirl_with_ring({
            x = 120, y = 130,
            radius = 80,
            emitDuration = 0.5,
            totalLifetime = 1.5
        })
        
        t.expect(#particle_calls.swirl_ring).to_be(1)
        t.expect(emitter).to_be_truthy()
        
        local call = particle_calls.swirl_ring[1]
        t.expect(call.x).to_be(120)
        t.expect(call.y).to_be(130)
        t.expect(call.radius).to_be(80)
    end)
end)

t.describe("api_aliases installation", function()
    
    t.it("installs get_entity_by_alias alias", function()
        t.expect(_G.get_entity_by_alias).to_be_truthy()
        t.expect(_G.get_entity_by_alias).to_be(_G.getEntityByAlias)
    end)
    
    t.it("installs set_entity_alias alias", function()
        t.expect(_G.set_entity_alias).to_be_truthy()
        t.expect(_G.set_entity_alias).to_be(_G.setEntityAlias)
    end)
    
    t.it("installs play_sound_effect alias", function()
        t.expect(_G.play_sound_effect).to_be_truthy()
        t.expect(_G.play_sound_effect).to_be(_G.playSoundEffect)
    end)
    
    t.it("installs pause_game alias", function()
        t.expect(_G.pause_game).to_be_truthy()
        t.expect(_G.pause_game).to_be(_G.pauseGame)
    end)
    
    t.it("installs unpause_game alias", function()
        t.expect(_G.unpause_game).to_be_truthy()
        t.expect(_G.unpause_game).to_be(_G.unpauseGame)
    end)
    
    t.it("installs is_key_pressed alias", function()
        t.expect(_G.is_key_pressed).to_be_truthy()
        t.expect(_G.is_key_pressed).to_be(_G.isKeyPressed)
    end)
end)

t.describe("api_aliases functionality", function()
    
    t.it("snake_case alias calls original function", function()
        reset_alias_calls()
        local result = get_entity_by_alias("player")
        
        t.expect(result).to_be("result_getEntityByAlias")
        t.expect(alias_calls.getEntityByAlias).to_be_truthy()
        t.expect(#alias_calls.getEntityByAlias).to_be(1)
        t.expect(alias_calls.getEntityByAlias[1][1]).to_be("player")
    end)
    
    t.it("play_sound_effect calls playSoundEffect with args", function()
        reset_alias_calls()
        play_sound_effect("fx", "explosion", 1.2)
        
        t.expect(alias_calls.playSoundEffect).to_be_truthy()
        t.expect(#alias_calls.playSoundEffect).to_be(1)
        local args = alias_calls.playSoundEffect[1]
        t.expect(args[1]).to_be("fx")
        t.expect(args[2]).to_be("explosion")
        t.expect(args[3]).to_be(1.2)
    end)
    
    t.it("pause_game calls pauseGame", function()
        reset_alias_calls()
        pause_game()
        
        t.expect(alias_calls.pauseGame).to_be_truthy()
        t.expect(#alias_calls.pauseGame).to_be(1)
    end)
    
    t.it("get_installed returns alias mapping", function()
        local installed = aliases.get_installed()
        
        t.expect(installed.get_entity_by_alias).to_be("getEntityByAlias")
        t.expect(installed.play_sound_effect).to_be("playSoundEffect")
        t.expect(installed.pause_game).to_be("pauseGame")
    end)
end)

t.describe("api_aliases coexistence", function()
    
    t.it("both camelCase and snake_case work simultaneously", function()
        reset_alias_calls()
        getEntityByAlias("test1")
        get_entity_by_alias("test2")
        
        t.expect(alias_calls.getEntityByAlias).to_be_truthy()
        t.expect(#alias_calls.getEntityByAlias).to_be(2)
    end)
    
    t.it("original camelCase still accessible", function()
        t.expect(_G.getEntityByAlias).to_be_truthy()
        t.expect(_G.playSoundEffect).to_be_truthy()
        t.expect(_G.pauseGame).to_be_truthy()
    end)
end)

t.describe("particle_helpers.DEFAULTS", function()
    
    t.it("exposes burst defaults", function()
        t.expect(particles.DEFAULTS.burst).to_be_truthy()
        t.expect(particles.DEFAULTS.burst.count).to_be(10)
        t.expect(particles.DEFAULTS.burst.duration).to_be(1.0)
        t.expect(particles.DEFAULTS.burst.easing).to_be("cubic")
        t.expect(particles.DEFAULTS.burst.space).to_be("screen")
    end)
    
    t.it("exposes swirl defaults", function()
        t.expect(particles.DEFAULTS.swirl).to_be_truthy()
        t.expect(particles.DEFAULTS.swirl.radius).to_be(50)
        t.expect(particles.DEFAULTS.swirl.emitDuration).to_be(1.0)
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

local success = t.run()
os.exit(success and 0 or 1)
