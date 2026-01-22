--[[
================================================================================
TEST: Procedural Generation DSL - Stats
================================================================================
Tests for the procgen stats system for enemy/item stat scaling.

TDD Approach:
- RED: Tests fail before implementation
- GREEN: Implement, tests pass

Run with: lua assets/scripts/tests/test_procgen_stats.lua
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
-- Tests: stats API existence
--------------------------------------------------------------------------------

t.describe("procgen.stats - API", function()

    t.it("has stats function", function()
        local procgen = require("core.procgen")
        t.expect(type(procgen.stats)).to_be("function")
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Basic stats definition
--------------------------------------------------------------------------------

t.describe("procgen.stats - Basic definition", function()

    t.it("creates a stats object from definition", function()
        local procgen = require("core.procgen")

        local stats = procgen.stats {
            base = {
                health = 100,
                damage = 10,
                speed = 50
            }
        }

        t.expect(stats).to_be_truthy()
        t.expect(type(stats.generate)).to_be("function")
    end)

    t.it("returns base stats with no scaling", function()
        local procgen = require("core.procgen")

        local stats = procgen.stats {
            base = {
                health = 100,
                damage = 10,
                speed = 50
            }
        }

        local rng = procgen.create_rng(1)
        local result = stats:generate({ rng = rng })

        t.expect(result.health).to_be(100)
        t.expect(result.damage).to_be(10)
        t.expect(result.speed).to_be(50)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Stat scaling
--------------------------------------------------------------------------------

t.describe("procgen.stats - Scaling", function()

    t.it("supports function-based scaling", function()
        local procgen = require("core.procgen")

        local stats = procgen.stats {
            base = {
                health = 100,
                damage = 10
            },
            scaling = {
                health = function(ctx)
                    return ctx.base * (1 + ctx.difficulty * 0.2)
                end,
                damage = function(ctx)
                    return ctx.base * (1 + ctx.difficulty * 0.1)
                end
            }
        }

        local rng = procgen.create_rng(1)
        local result = stats:generate({ difficulty = 5, rng = rng })

        -- health = 100 * (1 + 5 * 0.2) = 100 * 2 = 200
        t.expect(result.health).to_be(200)
        -- damage = 10 * (1 + 5 * 0.1) = 10 * 1.5 = 15
        t.expect(result.damage).to_be(15)
    end)

    t.it("supports procgen.constant for non-scaling stats", function()
        local procgen = require("core.procgen")

        local stats = procgen.stats {
            base = {
                health = 100,
                speed = 50
            },
            scaling = {
                health = function(ctx)
                    return ctx.base * 2
                end,
                speed = procgen.constant()  -- Won't scale
            }
        }

        local rng = procgen.create_rng(1)
        local result = stats:generate({ difficulty = 10, rng = rng })

        t.expect(result.health).to_be(200)
        t.expect(result.speed).to_be(50)  -- Unchanged
    end)

    t.it("defaults to base value if no scaling defined", function()
        local procgen = require("core.procgen")

        local stats = procgen.stats {
            base = {
                health = 100,
                damage = 10,
                speed = 50
            },
            scaling = {
                health = function(ctx) return ctx.base * 2 end
                -- damage and speed have no scaling
            }
        }

        local rng = procgen.create_rng(1)
        local result = stats:generate({ difficulty = 5, rng = rng })

        t.expect(result.health).to_be(200)
        t.expect(result.damage).to_be(10)  -- Base value
        t.expect(result.speed).to_be(50)   -- Base value
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Variants
--------------------------------------------------------------------------------

t.describe("procgen.stats - Variants", function()

    t.it("supports variant multipliers", function()
        local procgen = require("core.procgen")

        local stats = procgen.stats {
            base = {
                health = 100,
                damage = 10,
                speed = 50
            },
            variants = {
                elite = { health = 2.0, damage = 1.5 },
                boss = { health = 5.0, damage = 2.0, speed = 0.8 }
            }
        }

        local rng = procgen.create_rng(1)

        -- Elite variant
        local elite = stats:generate({ variant = "elite", rng = rng })
        t.expect(elite.health).to_be(200)
        t.expect(elite.damage).to_be(15)
        t.expect(elite.speed).to_be(50)  -- No multiplier, so base

        -- Boss variant
        local boss = stats:generate({ variant = "boss", rng = rng })
        t.expect(boss.health).to_be(500)
        t.expect(boss.damage).to_be(20)
        t.expect(boss.speed).to_be(40)  -- 50 * 0.8
    end)

    t.it("applies variant AFTER scaling", function()
        local procgen = require("core.procgen")

        local stats = procgen.stats {
            base = {
                health = 100
            },
            scaling = {
                health = function(ctx)
                    return ctx.base * (1 + ctx.difficulty * 0.1)
                end
            },
            variants = {
                elite = { health = 2.0 }
            }
        }

        local rng = procgen.create_rng(1)
        -- At difficulty 5: base health = 100 * 1.5 = 150
        -- Elite multiplier: 150 * 2.0 = 300
        local result = stats:generate({ difficulty = 5, variant = "elite", rng = rng })
        t.expect(result.health).to_be(300)
    end)

    t.it("ignores unknown variant", function()
        local procgen = require("core.procgen")

        local stats = procgen.stats {
            base = { health = 100 },
            variants = { elite = { health = 2.0 } }
        }

        local rng = procgen.create_rng(1)
        local result = stats:generate({ variant = "unknown", rng = rng })
        t.expect(result.health).to_be(100)
    end)
end)

--------------------------------------------------------------------------------
-- Tests: Stat ranges with randomization
--------------------------------------------------------------------------------

t.describe("procgen.stats - Randomization", function()

    t.it("supports base stats as ranges", function()
        local procgen = require("core.procgen")

        local stats = procgen.stats {
            base = {
                health = procgen.range(90, 110),
                damage = 10
            }
        }

        local rng = procgen.create_rng(42)
        local result = stats:generate({ rng = rng })

        t.expect(result.health >= 90).to_be(true)
        t.expect(result.health <= 110).to_be(true)
        t.expect(result.damage).to_be(10)
    end)

    t.it("randomization is deterministic with same seed", function()
        local procgen = require("core.procgen")

        local stats = procgen.stats {
            base = {
                health = procgen.range(1, 1000)
            }
        }

        local rng1 = procgen.create_rng(123)
        local rng2 = procgen.create_rng(123)

        local result1 = stats:generate({ rng = rng1 })
        local result2 = stats:generate({ rng = rng2 })

        t.expect(result1.health).to_be(result2.health)
    end)
end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

local success = t.run()
os.exit(success and 0 or 1)
