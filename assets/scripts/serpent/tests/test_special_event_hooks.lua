--[[
================================================================================
TEST: Special Event Hooks Implementation
================================================================================
Verifies that special_event_hooks.lua correctly routes events to special abilities:
- enemy_dead events -> berserker frenzy (kill counter)
- wave_start events -> paladin divine shield reset

as specified in task bd-7v3.

Run with: lua assets/scripts/serpent/tests/test_special_event_hooks.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")

-- Mock dependencies
_G.log_debug = function(msg) end
_G.log_warning = function(msg) end

t.describe("special_event_hooks.lua - Event Routing", function()
    t.it("routes enemy death events to berserker frenzy", function()
        local special_event_hooks = require("serpent.special_event_hooks")

        -- Create test context with berserker
        local ctx = {
            snake_state = {
                segments = {
                    {
                        instance_id = 1,
                        special_id = "berserker_frenzy",
                        hp = 100,
                        special_state = { kill_count = 0 }
                    },
                    {
                        instance_id = 2,
                        special_id = "knight_block",
                        hp = 150
                    }
                }
            }
        }

        -- Create enemy death events
        local death_events = {
            {
                type = "DeathEventEnemy",
                enemy_id = 123,
                killed_by_instance_id = 1
            },
            {
                type = "DeathEventEnemy",
                enemy_id = 124,
                killed_by_instance_id = 2
            }
        }

        -- Process the events
        local extra_events = special_event_hooks.process_enemy_death_events(death_events, ctx)

        -- Check that berserker got kill credit
        local berserker = ctx.snake_state.segments[1]
        t.expect(berserker.special_state.kill_count).to_be(2) -- Should have 2 kills now

        -- Non-berserker should be unaffected
        local knight = ctx.snake_state.segments[2]
        t.expect(knight.special_state).to_be_nil() -- No special state
    end)

    t.it("routes wave start events to paladin shield reset", function()
        local special_event_hooks = require("serpent.special_event_hooks")

        -- Create test context with paladin (shield used)
        local ctx = {
            snake_state = {
                segments = {
                    {
                        instance_id = 1,
                        special_id = "paladin_divine_shield",
                        hp = 150,
                        special_state = { shield_used = true }
                    },
                    {
                        instance_id = 2,
                        special_id = "knight_block",
                        hp = 150
                    }
                }
            }
        }

        -- Process wave start event
        local extra_events = special_event_hooks.process_wave_start_event(5, ctx)

        -- Check that paladin shield was reset
        local paladin = ctx.snake_state.segments[1]
        t.expect(paladin.special_state.shield_used).to_be(false)

        -- Non-paladin should be unaffected
        local knight = ctx.snake_state.segments[2]
        t.expect(knight.special_state).to_be_nil()
    end)

    t.it("processes mixed event batches correctly", function()
        local special_event_hooks = require("serpent.special_event_hooks")

        -- Create test context with both berserker and paladin
        local ctx = {
            snake_state = {
                segments = {
                    {
                        instance_id = 1,
                        special_id = "berserker_frenzy",
                        hp = 100,
                        special_state = { kill_count = 1 }
                    },
                    {
                        instance_id = 2,
                        special_id = "paladin_divine_shield",
                        hp = 150,
                        special_state = { shield_used = true }
                    }
                }
            }
        }

        -- Create mixed event batch
        local events = {
            { type = "DeathEventEnemy", enemy_id = 123 },
            { type = "WaveStartEvent", wave_num = 5 },
            { type = "DeathEventEnemy", enemy_id = 124 },
            { type = "OtherEvent", data = "should be ignored" }
        }

        -- Process the batch
        local extra_events = special_event_hooks.process_event_batch(events, ctx)

        -- Check results
        local berserker = ctx.snake_state.segments[1]
        local paladin = ctx.snake_state.segments[2]

        t.expect(berserker.special_state.kill_count).to_be(3) -- 1 + 2 kills
        t.expect(paladin.special_state.shield_used).to_be(false) -- Reset
    end)

    t.it("handles empty event lists gracefully", function()
        local special_event_hooks = require("serpent.special_event_hooks")

        local ctx = {
            snake_state = {
                segments = {}
            }
        }

        -- Test empty events
        local extra_events1 = special_event_hooks.process_enemy_death_events({}, ctx)
        t.expect(#extra_events1).to_be(0)

        local extra_events2 = special_event_hooks.process_wave_start_event(1, ctx)
        t.expect(#extra_events2).to_be(0)

        local extra_events3 = special_event_hooks.process_event_batch({}, ctx)
        t.expect(#extra_events3).to_be(0)

        -- Test nil events
        local extra_events4 = special_event_hooks.process_enemy_death_events(nil, ctx)
        t.expect(#extra_events4).to_be(0)
    end)

    t.it("handles nil context gracefully", function()
        local special_event_hooks = require("serpent.special_event_hooks")

        local death_events = { { type = "DeathEventEnemy", enemy_id = 123 } }

        -- Test nil context
        local extra_events1 = special_event_hooks.process_enemy_death_events(death_events, nil)
        t.expect(#extra_events1).to_be(0)

        local extra_events2 = special_event_hooks.process_wave_start_event(1, nil)
        t.expect(#extra_events2).to_be(0)
    end)
end)

t.describe("special_event_hooks.lua - Statistics", function()
    t.it("provides correct berserker statistics", function()
        local special_event_hooks = require("serpent.special_event_hooks")

        -- Create test context with multiple berserkers
        local ctx = {
            snake_state = {
                segments = {
                    {
                        instance_id = 1,
                        special_id = "berserker_frenzy",
                        hp = 100,
                        special_state = { kill_count = 5 }
                    },
                    {
                        instance_id = 2,
                        special_id = "berserker_frenzy",
                        hp = 80,
                        special_state = { kill_count = 3 }
                    },
                    {
                        instance_id = 3,
                        special_id = "knight_block",
                        hp = 150
                    }
                }
            }
        }

        local stats = special_event_hooks.get_berserker_stats(ctx)

        t.expect(stats.berserker_count).to_be(2)
        t.expect(stats.total_kills).to_be(8) -- 5 + 3
        t.expect(stats.max_kills).to_be(5)
        t.expect(#stats.berserkers).to_be(2)

        -- Check individual berserker stats
        t.expect(stats.berserkers[1].instance_id).to_be(1)
        t.expect(stats.berserkers[1].kill_count).to_be(5)
        t.expect(stats.berserkers[1].attack_bonus_percent).to_be(25) -- 5 * 5%

        t.expect(stats.berserkers[2].instance_id).to_be(2)
        t.expect(stats.berserkers[2].kill_count).to_be(3)
        t.expect(stats.berserkers[2].attack_bonus_percent).to_be(15) -- 3 * 5%
    end)

    t.it("provides correct paladin statistics", function()
        local special_event_hooks = require("serpent.special_event_hooks")

        -- Create test context with multiple paladins
        local ctx = {
            snake_state = {
                segments = {
                    {
                        instance_id = 1,
                        special_id = "paladin_divine_shield",
                        hp = 150,
                        special_state = { shield_used = false }
                    },
                    {
                        instance_id = 2,
                        special_id = "paladin_divine_shield",
                        hp = 120,
                        special_state = { shield_used = true }
                    },
                    {
                        instance_id = 3,
                        special_id = "paladin_divine_shield",
                        hp = 100
                        -- No special_state means shield available
                    },
                    {
                        instance_id = 4,
                        special_id = "knight_block",
                        hp = 150
                    }
                }
            }
        }

        local stats = special_event_hooks.get_paladin_stats(ctx)

        t.expect(stats.paladin_count).to_be(3)
        t.expect(stats.shields_available).to_be(2) -- instances 1 and 3
        t.expect(stats.shields_used).to_be(1) -- instance 2
        t.expect(#stats.paladins).to_be(3)

        -- Check individual paladin stats
        t.expect(stats.paladins[1].instance_id).to_be(1)
        t.expect(stats.paladins[1].shield_available).to_be(true)

        t.expect(stats.paladins[2].instance_id).to_be(2)
        t.expect(stats.paladins[2].shield_available).to_be(false)

        t.expect(stats.paladins[3].instance_id).to_be(3)
        t.expect(stats.paladins[3].shield_available).to_be(true)
    end)

    t.it("handles empty snake state for statistics", function()
        local special_event_hooks = require("serpent.special_event_hooks")

        local empty_ctx = {
            snake_state = {
                segments = {}
            }
        }

        local berserker_stats = special_event_hooks.get_berserker_stats(empty_ctx)
        t.expect(berserker_stats.berserker_count).to_be(0)
        t.expect(berserker_stats.total_kills).to_be(0)
        t.expect(berserker_stats.max_kills).to_be(0)
        t.expect(#berserker_stats.berserkers).to_be(0)

        local paladin_stats = special_event_hooks.get_paladin_stats(empty_ctx)
        t.expect(paladin_stats.paladin_count).to_be(0)
        t.expect(paladin_stats.shields_available).to_be(0)
        t.expect(paladin_stats.shields_used).to_be(0)
        t.expect(#paladin_stats.paladins).to_be(0)

        -- Test nil context
        local berserker_stats_nil = special_event_hooks.get_berserker_stats(nil)
        t.expect(berserker_stats_nil.berserker_count).to_be(0)

        local paladin_stats_nil = special_event_hooks.get_paladin_stats(nil)
        t.expect(paladin_stats_nil.paladin_count).to_be(0)
    end)
end)

t.describe("special_event_hooks.lua - Built-in Tests", function()
    t.it("passes all built-in tests", function()
        local special_event_hooks = require("serpent.special_event_hooks")

        local berserker_test = special_event_hooks.test_berserker_kill_credit()
        t.expect(berserker_test).to_be(true)

        local paladin_test = special_event_hooks.test_paladin_shield_reset()
        t.expect(paladin_test).to_be(true)

        local batch_test = special_event_hooks.test_batch_processing()
        t.expect(batch_test).to_be(true)

        local all_tests = special_event_hooks.run_all_tests()
        t.expect(all_tests).to_be(true)
    end)
end)

t.describe("special_event_hooks.lua - Integration Consistency", function()
    t.it("integrates correctly with specials_system", function()
        local special_event_hooks = require("serpent.special_event_hooks")
        local specials_system = require("serpent.specials_system")

        -- Create test context
        local ctx = {
            snake_state = {
                segments = {
                    {
                        instance_id = 1,
                        special_id = "berserker_frenzy",
                        hp = 100,
                        special_state = { kill_count = 2 }
                    }
                }
            }
        }

        -- Test that our hooks produce same result as direct specials_system calls
        local death_event = { type = "DeathEventEnemy", enemy_id = 123 }

        -- Call via our hooks
        special_event_hooks.process_enemy_death_events({death_event}, ctx)
        local hooks_kill_count = ctx.snake_state.segments[1].special_state.kill_count

        -- Reset and call specials_system directly
        ctx.snake_state.segments[1].special_state.kill_count = 2
        specials_system.on_enemy_death(ctx, death_event)
        local direct_kill_count = ctx.snake_state.segments[1].special_state.kill_count

        t.expect(hooks_kill_count).to_be(direct_kill_count)
    end)

    t.it("maintains consistency across multiple event types", function()
        local special_event_hooks = require("serpent.special_event_hooks")

        -- Create comprehensive test context
        local ctx = {
            snake_state = {
                segments = {
                    {
                        instance_id = 1,
                        special_id = "berserker_frenzy",
                        hp = 100,
                        special_state = { kill_count = 0 }
                    },
                    {
                        instance_id = 2,
                        special_id = "paladin_divine_shield",
                        hp = 150,
                        special_state = { shield_used = true }
                    }
                }
            }
        }

        -- Process wave start first (should reset paladin)
        special_event_hooks.process_wave_start_event(1, ctx)

        -- Process enemy deaths (should credit berserker)
        local death_events = {
            { type = "DeathEventEnemy", enemy_id = 1 },
            { type = "DeathEventEnemy", enemy_id = 2 }
        }
        special_event_hooks.process_enemy_death_events(death_events, ctx)

        -- Verify final state
        local berserker = ctx.snake_state.segments[1]
        local paladin = ctx.snake_state.segments[2]

        t.expect(berserker.special_state.kill_count).to_be(2)
        t.expect(paladin.special_state.shield_used).to_be(false)
    end)
end)

local success = t.run()
os.exit(success and 0 or 1)