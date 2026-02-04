--[[
================================================================================
TEST: Combine Logic Verification
================================================================================
Verifies that combine_logic.lua correctly handles unit combinations with:
- Lowest acquired_seq triple selection
- Chain combine processing
- Kept slot preserved (first unit stays in place)
- Full-heal on combine
as specified in task bd-27a.

Run with: lua assets/scripts/serpent/tests/test_combines.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")

-- Mock dependencies
_G.log_debug = function(msg) end
_G.log_warning = function(msg) end
_G.log_error = function(msg) end

t.describe("combine_logic.lua - Core Functionality", function()
    t.it("combines 3 units of same type and level", function()
        local combine_logic = require("serpent.combine_logic")

        local snake_state = {
            segments = {
                {instance_id = 1, def_id = "soldier", level = 1, acquired_seq = 10, hp = 50},
                {instance_id = 2, def_id = "soldier", level = 1, acquired_seq = 20, hp = 30},
                {instance_id = 3, def_id = "soldier", level = 1, acquired_seq = 30, hp = 40},
            },
            length = 3
        }

        local unit_defs = {
            soldier = {base_hp = 100, base_attack = 15}
        }

        local result_snake, combine_events = combine_logic.apply_combines_until_stable(snake_state, unit_defs)

        -- Should have 1 segment left (combined)
        t.expect(#result_snake.segments).to_be(1)

        -- Should have one combine event
        t.expect(#combine_events).to_be(1)

        -- Combined unit should be level 2
        t.expect(result_snake.segments[1].level).to_be(2)

        -- Combined unit should be at full health for level 2 (100 * 2 = 200)
        t.expect(result_snake.segments[1].hp).to_be(200)

        -- Should keep the first unit's instance_id (lowest acquired_seq)
        t.expect(result_snake.segments[1].instance_id).to_be(1)
    end)

    t.it("selects lowest acquired_seq triple", function()
        local combine_logic = require("serpent.combine_logic")

        local snake_state = {
            segments = {
                {instance_id = 1, def_id = "soldier", level = 1, acquired_seq = 50, hp = 50},
                {instance_id = 2, def_id = "soldier", level = 1, acquired_seq = 10, hp = 60}, -- lowest
                {instance_id = 3, def_id = "soldier", level = 1, acquired_seq = 30, hp = 70}, -- middle
                {instance_id = 4, def_id = "soldier", level = 1, acquired_seq = 20, hp = 80}, -- second lowest
                {instance_id = 5, def_id = "soldier", level = 1, acquired_seq = 100, hp = 90},
            },
            length = 5
        }

        local unit_defs = {
            soldier = {base_hp = 100, base_attack = 15}
        }

        local result_snake, combine_events = combine_logic.apply_combines_until_stable(snake_state, unit_defs)

        -- Should have 3 segments left (5 - 3 + 1 = 3)
        t.expect(#result_snake.segments).to_be(3)

        -- Should keep the unit with lowest acquired_seq (instance_id = 2, seq = 10)
        local kept_unit = nil
        for _, segment in ipairs(result_snake.segments) do
            if segment.level == 2 then
                kept_unit = segment
                break
            end
        end

        t.expect(kept_unit).to_be_truthy()
        t.expect(kept_unit.instance_id).to_be(2)
    end)

    t.it("preserves kept slot position", function()
        local combine_logic = require("serpent.combine_logic")

        local snake_state = {
            segments = {
                {instance_id = 10, def_id = "mage", level = 1, acquired_seq = 100, hp = 40},
                {instance_id = 1, def_id = "soldier", level = 1, acquired_seq = 10, hp = 50}, -- position 2
                {instance_id = 2, def_id = "soldier", level = 1, acquired_seq = 20, hp = 60},
                {instance_id = 3, def_id = "soldier", level = 1, acquired_seq = 30, hp = 70},
            },
            length = 4
        }

        local unit_defs = {
            soldier = {base_hp = 100, base_attack = 15},
            mage = {base_hp = 60, base_attack = 10}
        }

        local result_snake, combine_events = combine_logic.apply_combines_until_stable(snake_state, unit_defs)

        -- Should have 2 segments (1 mage + 1 combined soldier)
        t.expect(#result_snake.segments).to_be(2)

        -- Mage should still be at position 1
        t.expect(result_snake.segments[1].instance_id).to_be(10)

        -- Combined soldier should be at position 2 (where the kept soldier was)
        t.expect(result_snake.segments[2].instance_id).to_be(1)
        t.expect(result_snake.segments[2].level).to_be(2)
    end)

    t.it("applies full heal on combine", function()
        local combine_logic = require("serpent.combine_logic")

        local snake_state = {
            segments = {
                {instance_id = 1, def_id = "soldier", level = 1, acquired_seq = 10, hp = 10}, -- low HP
                {instance_id = 2, def_id = "soldier", level = 1, acquired_seq = 20, hp = 5},  -- very low HP
                {instance_id = 3, def_id = "soldier", level = 1, acquired_seq = 30, hp = 1},  -- near death
            },
            length = 3
        }

        local unit_defs = {
            soldier = {base_hp = 100, base_attack = 15}
        }

        local result_snake, combine_events = combine_logic.apply_combines_until_stable(snake_state, unit_defs)

        -- Should heal to full HP for level 2 (100 * 2 = 200)
        t.expect(result_snake.segments[1].hp).to_be(200)
        t.expect(result_snake.segments[1].hp_max_base).to_be(200)
    end)

    t.it("handles chain combines", function()
        local combine_logic = require("serpent.combine_logic")

        local snake_state = {
            segments = {
                -- 9 soldier level 1 units: 3->1 level 2, 3->1 level 2, 3->1 level 2, then 3 level 2s -> 1 level 3
                {instance_id = 1, def_id = "soldier", level = 1, acquired_seq = 10, hp = 100},
                {instance_id = 2, def_id = "soldier", level = 1, acquired_seq = 20, hp = 100},
                {instance_id = 3, def_id = "soldier", level = 1, acquired_seq = 30, hp = 100},
                {instance_id = 4, def_id = "soldier", level = 1, acquired_seq = 40, hp = 100},
                {instance_id = 5, def_id = "soldier", level = 1, acquired_seq = 50, hp = 100},
                {instance_id = 6, def_id = "soldier", level = 1, acquired_seq = 60, hp = 100},
                {instance_id = 7, def_id = "soldier", level = 1, acquired_seq = 70, hp = 100},
                {instance_id = 8, def_id = "soldier", level = 1, acquired_seq = 80, hp = 100},
                {instance_id = 9, def_id = "soldier", level = 1, acquired_seq = 90, hp = 100},
            },
            length = 9
        }

        local unit_defs = {
            soldier = {base_hp = 100, base_attack = 15}
        }

        local result_snake, combine_events = combine_logic.apply_combines_until_stable(snake_state, unit_defs)

        -- Should have 4 combine events (3 level 1->level 2 combines, then 1 level 2->level 3 combine)
        t.expect(#combine_events).to_be(4)

        -- Final result should have 1 segment (1 level 3 soldier)
        t.expect(#result_snake.segments).to_be(1)

        -- Check that we get a level 3 unit
        t.expect(result_snake.segments[1].level).to_be(3)
        t.expect(result_snake.segments[1].def_id).to_be("soldier")
    end)

    t.it("handles mixed unit types separately", function()
        local combine_logic = require("serpent.combine_logic")

        local snake_state = {
            segments = {
                {instance_id = 1, def_id = "soldier", level = 1, acquired_seq = 10, hp = 100},
                {instance_id = 2, def_id = "mage", level = 1, acquired_seq = 20, hp = 60},
                {instance_id = 3, def_id = "soldier", level = 1, acquired_seq = 30, hp = 100},
                {instance_id = 4, def_id = "mage", level = 1, acquired_seq = 40, hp = 60},
                {instance_id = 5, def_id = "soldier", level = 1, acquired_seq = 50, hp = 100},
                {instance_id = 6, def_id = "mage", level = 1, acquired_seq = 60, hp = 60},
            },
            length = 6
        }

        local unit_defs = {
            soldier = {base_hp = 100, base_attack = 15},
            mage = {base_hp = 60, base_attack = 10}
        }

        local result_snake, combine_events = combine_logic.apply_combines_until_stable(snake_state, unit_defs)

        -- Should have 2 combine events (soldiers combine, mages combine)
        t.expect(#combine_events).to_be(2)

        -- Should have 2 segments left (1 level 2 soldier, 1 level 2 mage)
        t.expect(#result_snake.segments).to_be(2)

        -- Both remaining units should be level 2
        for _, segment in ipairs(result_snake.segments) do
            t.expect(segment.level).to_be(2)
        end
    end)

    t.it("handles different level units separately", function()
        local combine_logic = require("serpent.combine_logic")

        local snake_state = {
            segments = {
                {instance_id = 1, def_id = "soldier", level = 1, acquired_seq = 10, hp = 100},
                {instance_id = 2, def_id = "soldier", level = 1, acquired_seq = 20, hp = 100},
                {instance_id = 3, def_id = "soldier", level = 1, acquired_seq = 30, hp = 100},
                {instance_id = 4, def_id = "soldier", level = 2, acquired_seq = 40, hp = 200},
                {instance_id = 5, def_id = "soldier", level = 2, acquired_seq = 50, hp = 200},
                {instance_id = 6, def_id = "soldier", level = 2, acquired_seq = 60, hp = 200},
            },
            length = 6
        }

        local unit_defs = {
            soldier = {base_hp = 100, base_attack = 15}
        }

        local result_snake, combine_events = combine_logic.apply_combines_until_stable(snake_state, unit_defs)

        -- Should have 2 combine events (level 1s combine, level 2s combine)
        t.expect(#combine_events).to_be(2)

        -- Should have 2 segments left (1 level 2 from level 1s, 1 level 3 from level 2s)
        t.expect(#result_snake.segments).to_be(2)

        -- Check final levels
        local has_level_2 = false
        local has_level_3 = false
        for _, segment in ipairs(result_snake.segments) do
            if segment.level == 2 then has_level_2 = true end
            if segment.level == 3 then has_level_3 = true end
        end
        t.expect(has_level_2).to_be(true)
        t.expect(has_level_3).to_be(true)
    end)
end)

t.describe("combine_logic.lua - Edge Cases", function()
    t.it("handles insufficient units for combine", function()
        local combine_logic = require("serpent.combine_logic")

        local snake_state = {
            segments = {
                {instance_id = 1, def_id = "soldier", level = 1, acquired_seq = 10, hp = 100},
                {instance_id = 2, def_id = "soldier", level = 1, acquired_seq = 20, hp = 100},
            },
            length = 2
        }

        local unit_defs = {
            soldier = {base_hp = 100, base_attack = 15}
        }

        local result_snake, combine_events = combine_logic.apply_combines_until_stable(snake_state, unit_defs)

        -- Should have no combine events
        t.expect(#combine_events).to_be(0)

        -- Should have same segments
        t.expect(#result_snake.segments).to_be(2)
    end)

    t.it("handles empty snake state", function()
        local combine_logic = require("serpent.combine_logic")

        local snake_state = {
            segments = {},
            length = 0
        }

        local result_snake, combine_events = combine_logic.apply_combines_until_stable(snake_state, {})

        t.expect(#combine_events).to_be(0)
        t.expect(#result_snake.segments).to_be(0)
    end)

    t.it("handles nil snake state", function()
        local combine_logic = require("serpent.combine_logic")

        local result_snake, combine_events = combine_logic.apply_combines_until_stable(nil, {})

        t.expect(combine_events).to_be_truthy()
        t.expect(#combine_events).to_be(0)
    end)

    t.it("handles missing unit definitions", function()
        local combine_logic = require("serpent.combine_logic")

        local snake_state = {
            segments = {
                {instance_id = 1, def_id = "unknown", level = 1, acquired_seq = 10, hp = 50},
                {instance_id = 2, def_id = "unknown", level = 1, acquired_seq = 20, hp = 50},
                {instance_id = 3, def_id = "unknown", level = 1, acquired_seq = 30, hp = 50},
            },
            length = 3
        }

        local unit_defs = {} -- No definitions

        local result_snake, combine_events = combine_logic.apply_combines_until_stable(snake_state, unit_defs)

        -- Should still combine but use default stats
        t.expect(#combine_events).to_be(1)
        t.expect(#result_snake.segments).to_be(1)
        t.expect(result_snake.segments[1].level).to_be(2)
    end)

    t.it("caps level at 3", function()
        local combine_logic = require("serpent.combine_logic")

        local unit_def = {base_hp = 100, base_attack = 15}

        -- Test level scaling caps at 3
        local stats_level_3 = combine_logic.apply_level_scaling(unit_def, 3)
        local stats_level_4 = combine_logic.apply_level_scaling(unit_def, 4) -- Should be same as 3
        local stats_level_10 = combine_logic.apply_level_scaling(unit_def, 10) -- Should be same as 3

        t.expect(stats_level_3.hp_max_base_int).to_be(400) -- 100 * 2^2
        t.expect(stats_level_4.hp_max_base_int).to_be(400) -- Capped at level 3
        t.expect(stats_level_10.hp_max_base_int).to_be(400) -- Capped at level 3
    end)

    t.it("handles deterministic processing order", function()
        local combine_logic = require("serpent.combine_logic")

        local snake_state = {
            segments = {
                -- Mixed types and levels - should process in deterministic order
                {instance_id = 1, def_id = "zebra", level = 1, acquired_seq = 10, hp = 100},
                {instance_id = 2, def_id = "apple", level = 2, acquired_seq = 20, hp = 200},
                {instance_id = 3, def_id = "zebra", level = 1, acquired_seq = 30, hp = 100},
                {instance_id = 4, def_id = "apple", level = 2, acquired_seq = 40, hp = 200},
                {instance_id = 5, def_id = "zebra", level = 1, acquired_seq = 50, hp = 100},
                {instance_id = 6, def_id = "apple", level = 2, acquired_seq = 60, hp = 200},
                {instance_id = 7, def_id = "apple", level = 1, acquired_seq = 70, hp = 100},
                {instance_id = 8, def_id = "apple", level = 1, acquired_seq = 80, hp = 100},
                {instance_id = 9, def_id = "apple", level = 1, acquired_seq = 90, hp = 100},
            },
            length = 9
        }

        local unit_defs = {
            apple = {base_hp = 100, base_attack = 10},
            zebra = {base_hp = 120, base_attack = 12}
        }

        local result_snake, combine_events = combine_logic.apply_combines_until_stable(snake_state, unit_defs)

        -- Should process apple level 1 first (alphabetical, then level order)
        t.expect(#combine_events >= 1).to_be(true)
        t.expect(combine_events[1].def_id).to_be("apple")
        t.expect(combine_events[1].new_level).to_be(2)
    end)
end)

t.describe("combine_logic.lua - Max Length Simulation", function()
    t.it("correctly simulates purchase at max length", function()
        local combine_logic = require("serpent.combine_logic")

        local snake_state = {
            segments = {
                {instance_id = 1, def_id = "soldier", level = 1, acquired_seq = 10, hp = 100},
                {instance_id = 2, def_id = "soldier", level = 1, acquired_seq = 20, hp = 100},
            },
            length = 2
        }

        local new_segment = {instance_id = 3, def_id = "soldier", level = 1, acquired_seq = 30, hp = 100}

        local unit_defs = {
            soldier = {base_hp = 100, base_attack = 15}
        }

        -- Should allow purchase at max length 2 because combine will reduce to 1
        local can_purchase = combine_logic.can_purchase_at_max_length(snake_state, new_segment, 2, unit_defs)
        t.expect(can_purchase).to_be(true)

        -- Should not allow purchase if max length is 1 and no combine happens
        local single_segment_snake = {
            segments = {
                {instance_id = 1, def_id = "mage", level = 1, acquired_seq = 10, hp = 60},
            },
            length = 1
        }
        local new_mage = {instance_id = 2, def_id = "ranger", level = 1, acquired_seq = 20, hp = 70}

        can_purchase = combine_logic.can_purchase_at_max_length(single_segment_snake, new_mage, 1, unit_defs)
        t.expect(can_purchase).to_be(false)
    end)
end)

local success = t.run()
os.exit(success and 0 or 1)