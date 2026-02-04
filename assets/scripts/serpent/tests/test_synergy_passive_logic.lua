--[[
================================================================================
TEST: Synergy + Passive Computation
================================================================================
Tests for stacking multipliers, support global bonuses, hp clamping,
and combat snapshot filtering.

Run with: lua assets/scripts/serpent/tests/test_synergy_passive_logic.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

package.loaded["serpent.synergy_passive_logic"] = nil
package.loaded["serpent.synergy_system"] = nil
package.loaded["serpent.specials_system"] = nil

local t = require("tests.test_runner")
local synergy_passive_logic = require("serpent.synergy_passive_logic")

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

t.describe("synergy_passive_logic - multiplier stacking", function()
    t.it("stacks warrior synergy, support global, and berserker passive", function()
        local unit_defs = {
            berserker = { class = "Warrior", special_id = "berserker_frenzy" },
            knight = { class = "Warrior", special_id = "knight_block" },
            support = { class = "Support", special_id = nil }
        }

        local snake_state = {
            segments = {
                {
                    instance_id = 1,
                    def_id = "berserker",
                    level = 1,
                    hp = 100,
                    hp_max_base = 100,
                    attack_base = 100,
                    range_base = 50,
                    atk_spd_base = 1.0,
                    cooldown = 0,
                    special_state = { kill_count = 2 }
                },
                {
                    instance_id = 2,
                    def_id = "knight",
                    level = 1,
                    hp = 100,
                    hp_max_base = 100,
                    attack_base = 50,
                    range_base = 50,
                    atk_spd_base = 1.0,
                    cooldown = 0
                },
                { instance_id = 3, def_id = "support", level = 1, hp = 100, hp_max_base = 100, attack_base = 30, range_base = 50, atk_spd_base = 1.0, cooldown = 0 },
                { instance_id = 4, def_id = "support", level = 1, hp = 100, hp_max_base = 100, attack_base = 30, range_base = 50, atk_spd_base = 1.0, cooldown = 0 },
                { instance_id = 5, def_id = "support", level = 1, hp = 100, hp_max_base = 100, attack_base = 30, range_base = 50, atk_spd_base = 1.0, cooldown = 0 },
                { instance_id = 6, def_id = "support", level = 1, hp = 100, hp_max_base = 100, attack_base = 30, range_base = 50, atk_spd_base = 1.0, cooldown = 0 }
            },
            min_len = 1,
            max_len = 8
        }

        local _, snaps = synergy_passive_logic.compute(snake_state, unit_defs, {})

        local berserker_snap = find_snap(snaps, 1)
        local warrior_snap = find_snap(snaps, 2)
        local support_snap = find_snap(snaps, 3)

        t.expect(berserker_snap).to_be_truthy()
        t.expect(warrior_snap).to_be_truthy()
        t.expect(support_snap).to_be_truthy()

        -- 100 * 1.2 (warrior) * 1.1 (support global) * 1.1 (berserker stacks) = 145.2 -> 145
        t.expect(berserker_snap.effective_attack_int).to_be(145)

        -- 50 * 1.2 (warrior) * 1.1 (support global) = 66
        t.expect(warrior_snap.effective_attack_int).to_be(66)

        -- 30 * 1.1 (support global) = 33
        t.expect(support_snap.effective_attack_int).to_be(33)
    end)
end)

t.describe("synergy_passive_logic - hp clamp and dead skips", function()
    t.it("clamps hp when effective max decreases and excludes dead segments from snaps", function()
        local unit_defs = {
            warrior = { class = "Warrior", special_id = nil }
        }

        local snake_state = {
            segments = {
                {
                    instance_id = 1,
                    def_id = "warrior",
                    level = 1,
                    hp = 120,
                    hp_max_base = 100,
                    attack_base = 20,
                    range_base = 50,
                    atk_spd_base = 1.0,
                    cooldown = 0
                },
                {
                    instance_id = 2,
                    def_id = "warrior",
                    level = 1,
                    hp = 0,
                    hp_max_base = 100,
                    attack_base = 20,
                    range_base = 50,
                    atk_spd_base = 1.0,
                    cooldown = 0
                }
            },
            min_len = 1,
            max_len = 8
        }

        local updated_state, snaps = synergy_passive_logic.compute(snake_state, unit_defs, {})
        local updated_segment = find_segment(updated_state.segments, 1)
        local dead_snap = find_snap(snaps, 2)

        t.expect(updated_segment).to_be_truthy()
        t.expect(updated_segment.hp).to_be(100)
        t.expect(dead_snap).to_be_nil()
    end)
end)
