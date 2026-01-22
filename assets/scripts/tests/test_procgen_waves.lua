--[[
================================================================================
TEST: Procedural Generation DSL - Waves
================================================================================
Tests for the procgen waves system for enemy spawn definitions.

TDD Approach:
- RED: Tests fail before implementation
- GREEN: Implement, tests pass

Run with: lua assets/scripts/tests/test_procgen_waves.lua
]]

--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Clear cached module
package.loaded["core.procgen"] = nil
_G.procgen = nil

local t = require("tests.test_runner")

--------------------------------------------------------------------------------
-- Tests: waves API existence
--------------------------------------------------------------------------------

t.describe("procgen.waves - API", function()

    t.it("has waves function", function()
        local procgen = require("core.procgen")
        t.expect(type(procgen.waves)).to_be("function")
    end)

    t.it("has scaled function for dynamic waves", function()
        local procgen = require("core.procgen")
        t.expect(type(procgen.scaled)).to_be("function")
    end)

    t.it("has curve function for scaling values", function()
        local procgen = require("core.procgen")
        t.expect(type(procgen.curve)).to_be("function")
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Basic wave definition
--------------------------------------------------------------------------------

t.describe("procgen.waves - Basic definition", function()

    t.it("creates a waves object from definition", function()
        local procgen = require("core.procgen")

        local waves = procgen.waves {
            {
                enemies = { "slime", "slime" },
                spawn_delay = 1.0
            }
        }

        t.expect(waves).to_be_truthy()
        t.expect(type(waves.get_wave)).to_be("function")
        t.expect(type(waves.count)).to_be("function")
    end)

    t.it("can get wave count", function()
        local procgen = require("core.procgen")

        local waves = procgen.waves {
            { enemies = { "slime" } },
            { enemies = { "archer" } },
            { enemies = { "knight" } }
        }

        t.expect(waves:count()).to_be(3)
    end)

    t.it("can get specific wave", function()
        local procgen = require("core.procgen")

        local waves = procgen.waves {
            { enemies = { "slime", "slime" }, spawn_delay = 1.0 },
            { enemies = { "archer" }, spawn_delay = 0.5 }
        }

        local wave1 = waves:get_wave(1)
        t.expect(wave1).to_be_truthy()
        t.expect(#wave1.enemies).to_be(2)
        t.expect(wave1.enemies[1]).to_be("slime")
        t.expect(wave1.spawn_delay).to_be(1.0)

        local wave2 = waves:get_wave(2)
        t.expect(#wave2.enemies).to_be(1)
        t.expect(wave2.enemies[1]).to_be("archer")
    end)

    t.it("returns nil for out of bounds wave", function()
        local procgen = require("core.procgen")

        local waves = procgen.waves {
            { enemies = { "slime" } }
        }

        t.expect(waves:get_wave(0)).to_be_falsy()
        t.expect(waves:get_wave(2)).to_be_falsy()
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Wave spawn patterns
--------------------------------------------------------------------------------

t.describe("procgen.waves - Spawn patterns", function()

    t.it("defaults to sequential pattern", function()
        local procgen = require("core.procgen")

        local waves = procgen.waves {
            { enemies = { "slime" } }
        }

        local wave = waves:get_wave(1)
        t.expect(wave.spawn_pattern).to_be("sequential")
    end)

    t.it("supports simultaneous pattern", function()
        local procgen = require("core.procgen")

        local waves = procgen.waves {
            { enemies = { "slime", "archer" }, spawn_pattern = "simultaneous" }
        }

        local wave = waves:get_wave(1)
        t.expect(wave.spawn_pattern).to_be("simultaneous")
    end)

    t.it("supports random_interval pattern with min/max", function()
        local procgen = require("core.procgen")

        local waves = procgen.waves {
            {
                enemies = { "slime", "archer" },
                spawn_pattern = "random_interval",
                min_interval = 0.5,
                max_interval = 1.5
            }
        }

        local wave = waves:get_wave(1)
        t.expect(wave.spawn_pattern).to_be("random_interval")
        t.expect(wave.min_interval).to_be(0.5)
        t.expect(wave.max_interval).to_be(1.5)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: procgen.scaled for dynamic enemy lists
--------------------------------------------------------------------------------

t.describe("procgen.scaled - Dynamic enemy lists", function()

    t.it("creates a scaled enemy definition", function()
        local procgen = require("core.procgen")

        local scaled = procgen.scaled {
            base = { "slime", "archer" },
            per_difficulty = { "knight" },
            max_enemies = 8
        }

        t.expect(scaled).to_be_truthy()
        t.expect(scaled.base).to_be_truthy()
        t.expect(type(scaled.resolve)).to_be("function")
    end)

    t.it("returns base enemies at difficulty 0", function()
        local procgen = require("core.procgen")

        local scaled = procgen.scaled {
            base = { "slime", "archer" },
            per_difficulty = { "knight" },
            max_enemies = 10
        }

        local enemies = scaled:resolve({ difficulty = 0 })
        t.expect(#enemies).to_be(2)
        t.expect(enemies[1]).to_be("slime")
        t.expect(enemies[2]).to_be("archer")
    end)

    t.it("adds per_difficulty enemies for each difficulty level", function()
        local procgen = require("core.procgen")

        local scaled = procgen.scaled {
            base = { "slime" },
            per_difficulty = { "knight" },
            max_enemies = 10
        }

        -- At difficulty 3, should have 1 base + 3 knights = 4 total
        local enemies = scaled:resolve({ difficulty = 3 })
        t.expect(#enemies).to_be(4)
        t.expect(enemies[1]).to_be("slime")
        t.expect(enemies[2]).to_be("knight")
        t.expect(enemies[3]).to_be("knight")
        t.expect(enemies[4]).to_be("knight")
    end)

    t.it("respects max_enemies cap", function()
        local procgen = require("core.procgen")

        local scaled = procgen.scaled {
            base = { "slime", "archer" },
            per_difficulty = { "knight" },
            max_enemies = 4
        }

        -- At difficulty 10, would be 2 + 10 = 12, but capped at 4
        local enemies = scaled:resolve({ difficulty = 10 })
        t.expect(#enemies).to_be(4)
    end)

    t.it("works when used in wave definition", function()
        local procgen = require("core.procgen")

        local waves = procgen.waves {
            {
                enemies = procgen.scaled {
                    base = { "slime" },
                    per_difficulty = { "knight" },
                    max_enemies = 5
                },
                spawn_delay = 1.0
            }
        }

        local rng = procgen.create_rng(1)
        local wave = waves:get_wave(1, { difficulty = 2, rng = rng })
        t.expect(#wave.enemies).to_be(3)  -- 1 base + 2 knights
    end)
end)

--------------------------------------------------------------------------------
-- Tests: procgen.curve for scaling values
--------------------------------------------------------------------------------

t.describe("procgen.curve - Value scaling", function()

    t.it("creates a curve that interpolates between values", function()
        local procgen = require("core.procgen")

        -- spawn_delay: 1.0s at difficulty 1, 0.3s at difficulty 10
        local curve = procgen.curve("difficulty", 1.0, 0.3)
        t.expect(curve).to_be_truthy()
        t.expect(type(curve.resolve)).to_be("function")
    end)

    t.it("returns start value at minimum (difficulty 1)", function()
        local procgen = require("core.procgen")

        local curve = procgen.curve("difficulty", 1.0, 0.3)
        local value = curve:resolve({ difficulty = 1 })
        t.expect(math.abs(value - 1.0) < 0.01).to_be(true)
    end)

    t.it("returns end value at maximum (difficulty 10)", function()
        local procgen = require("core.procgen")

        local curve = procgen.curve("difficulty", 1.0, 0.3)
        local value = curve:resolve({ difficulty = 10 })
        t.expect(math.abs(value - 0.3) < 0.01).to_be(true)
    end)

    t.it("interpolates linearly between values", function()
        local procgen = require("core.procgen")

        local curve = procgen.curve("difficulty", 10, 0)
        -- At difficulty 5.5 (midpoint), should be ~5
        local value = curve:resolve({ difficulty = 5.5 })
        t.expect(math.abs(value - 5) < 0.1).to_be(true)
    end)

    t.it("clamps below minimum", function()
        local procgen = require("core.procgen")

        local curve = procgen.curve("difficulty", 1.0, 0.3)
        local value = curve:resolve({ difficulty = 0 })
        t.expect(math.abs(value - 1.0) < 0.01).to_be(true)  -- Should clamp to start
    end)

    t.it("clamps above maximum", function()
        local procgen = require("core.procgen")

        local curve = procgen.curve("difficulty", 1.0, 0.3)
        local value = curve:resolve({ difficulty = 20 })
        t.expect(math.abs(value - 0.3) < 0.01).to_be(true)  -- Should clamp to end
    end)

    t.it("works with spawn_delay in wave definition", function()
        local procgen = require("core.procgen")

        local waves = procgen.waves {
            {
                enemies = { "slime" },
                spawn_delay = procgen.curve("difficulty", 1.0, 0.5)
            }
        }

        local rng = procgen.create_rng(1)
        local wave = waves:get_wave(1, { difficulty = 5.5, rng = rng })
        -- At difficulty 5.5 (midpoint), spawn_delay should be ~0.75
        t.expect(math.abs(wave.spawn_delay - 0.75) < 0.05).to_be(true)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Wave iteration
--------------------------------------------------------------------------------

t.describe("procgen.waves - Iteration", function()

    t.it("can iterate through all waves", function()
        local procgen = require("core.procgen")

        local waves = procgen.waves {
            { enemies = { "slime" } },
            { enemies = { "archer" } },
            { enemies = { "knight" } }
        }

        local count = 0
        for i, wave in waves:iter() do
            count = count + 1
            t.expect(wave.enemies).to_be_truthy()
        end

        t.expect(count).to_be(3)
    end)

    t.it("iteration respects context", function()
        local procgen = require("core.procgen")

        local waves = procgen.waves {
            {
                enemies = procgen.scaled {
                    base = { "slime" },
                    per_difficulty = { "knight" },
                    max_enemies = 10
                }
            }
        }

        local rng = procgen.create_rng(1)
        local ctx = { difficulty = 2, rng = rng }

        for i, wave in waves:iter(ctx) do
            t.expect(#wave.enemies).to_be(3)
        end
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

local success = t.run()
os.exit(success and 0 or 1)
