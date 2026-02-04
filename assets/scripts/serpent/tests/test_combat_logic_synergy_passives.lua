--[[
================================================================================
TEST: Combat Logic Synergy + Passive Computation
================================================================================
Verifies that combat_logic.compute_synergy_and_passives:
- Applies Support "all stats" synergy globally
- Applies class-specific bonuses without double-counting Support
- Applies passive special modifiers multiplicatively
- Computes effective stats with floor rules and clamps HP

Run with: lua assets/scripts/serpent/tests/test_combat_logic_synergy_passives.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")

_G.log_debug = function(msg) end
_G.log_warning = function(msg) end

local function find_snap(snaps, instance_id)
    for _, snap in ipairs(snaps or {}) do
        if snap.instance_id == instance_id then
            return snap
        end
    end
    return nil
end

local function find_segment(segments, instance_id)
    for _, segment in ipairs(segments or {}) do
        if segment.instance_id == instance_id then
            return segment
        end
    end
    return nil
end

t.describe("combat_logic.compute_synergy_and_passives", function()
    t.it("applies support globals, bard buffs, berserker stacks, clamps hp", function()
        local combat_logic = require("serpent.combat_logic")

        local snake_state = {
            segments = {
                { instance_id = 1, def_id = "support", hp = 100, hp_max_base = 100,
                  attack_base = 10, range_base = 50, atk_spd_base = 1.0, cooldown = 0 },
                { instance_id = 2, def_id = "support", hp = 100, hp_max_base = 100,
                  attack_base = 10, range_base = 50, atk_spd_base = 1.0, cooldown = 0 },
                { instance_id = 3, def_id = "bard", hp = 100, hp_max_base = 100,
                  attack_base = 10, range_base = 50, atk_spd_base = 1.0, cooldown = 0,
                  special_id = "bard_adjacent_atkspd" },
                { instance_id = 4, def_id = "warrior", hp = 120, hp_max_base = 100,
                  attack_base = 10, range_base = 50, atk_spd_base = 1.0, cooldown = 0,
                  special_id = "berserker_frenzy", special_state = { kill_count = 2 } },
                { instance_id = 5, def_id = "support", hp = 100, hp_max_base = 100,
                  attack_base = 10, range_base = 50, atk_spd_base = 1.0, cooldown = 0 }
            },
            min_len = 1,
            max_len = 8
        }

        local unit_defs = {
            support = { class = "Support" },
            bard = { class = "Support" },
            warrior = { class = "Warrior" }
        }

        local updated_state, synergy_state, passive_mods, snaps =
            combat_logic.compute_synergy_and_passives(snake_state, unit_defs)

        t.expect(synergy_state.class_counts.Support).to_be(4)

        local warrior_snap = find_snap(snaps, 4)
        t.expect(warrior_snap).to_be_truthy()

        -- Support all-stats (1.1) * berserker (1.1) = 1.21
        t.expect(warrior_snap.effective_attack_int).to_be(12) -- floor(10 * 1.21)

        -- Support range bonus only
        t.expect(math.abs(warrior_snap.effective_range_num - 55) < 0.001).to_be(true)

        -- Support atk spd (1.1) * bard adjacency (1.1) = 1.21
        t.expect(math.abs(warrior_snap.effective_atk_spd_num - 1.21) < 0.001).to_be(true)
        t.expect(math.abs(warrior_snap.effective_period_num - (1 / 1.21)) < 0.0001).to_be(true)

        -- HP max clamped from 120 to 110
        local updated_warrior = find_segment(updated_state.segments, 4)
        t.expect(updated_warrior.hp).to_be(110)

        -- Support segment should not double-apply support synergy
        local support_snap = find_snap(snaps, 1)
        t.expect(support_snap.effective_hp_max_int).to_be(110)
    end)

    t.it("applies mage cooldown period multiplier and class bonuses", function()
        local combat_logic = require("serpent.combat_logic")

        local snake_state = {
            segments = {
                { instance_id = 1, def_id = "mage", hp = 80, hp_max_base = 80,
                  attack_base = 10, range_base = 60, atk_spd_base = 2.0, cooldown = 0 },
                { instance_id = 2, def_id = "mage", hp = 80, hp_max_base = 80,
                  attack_base = 10, range_base = 60, atk_spd_base = 2.0, cooldown = 0 },
                { instance_id = 3, def_id = "mage", hp = 80, hp_max_base = 80,
                  attack_base = 10, range_base = 60, atk_spd_base = 2.0, cooldown = 0 },
                { instance_id = 4, def_id = "mage", hp = 80, hp_max_base = 80,
                  attack_base = 10, range_base = 60, atk_spd_base = 2.0, cooldown = 0 }
            },
            min_len = 1,
            max_len = 8
        }

        local unit_defs = {
            mage = { class = "Mage" }
        }

        local _, _, _, snaps = combat_logic.compute_synergy_and_passives(snake_state, unit_defs)
        local mage_snap = find_snap(snaps, 1)

        t.expect(mage_snap.effective_attack_int).to_be(14) -- 10 * 1.4
        t.expect(math.abs(mage_snap.effective_period_num - 0.4) < 0.0001).to_be(true)
        t.expect(math.abs(mage_snap.effective_range_num - 60) < 0.001).to_be(true)
    end)
end)

local success = t.run()
os.exit(success and 0 or 1)
