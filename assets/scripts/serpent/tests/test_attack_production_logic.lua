--[[
================================================================================
TEST: Attack Production Logic
================================================================================
Tests for attack event ordering and cooldown updates.

Run with: lua assets/scripts/serpent/tests/test_attack_production_logic.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

package.loaded["serpent.attack_production_logic"] = nil

local t = require("tests.test_runner")
local attack_production_logic = require("serpent.attack_production_logic")

local function find_segment(segments, instance_id)
    for _, segment in ipairs(segments or {}) do
        if segment.instance_id == instance_id then
            return segment
        end
    end
    return nil
end

t.describe("attack_production_logic - order + cooldowns", function()
    t.it("emits attacks head->tail and updates cooldowns", function()
        local snake_state = {
            segments = {
                {
                    instance_id = 1,
                    def_id = "warrior",
                    level = 1,
                    hp = 100,
                    hp_max_base = 100,
                    attack_base = 10,
                    range_base = 100,
                    atk_spd_base = 1.0,
                    cooldown = -0.1
                },
                {
                    instance_id = 2,
                    def_id = "warrior",
                    level = 1,
                    hp = 100,
                    hp_max_base = 100,
                    attack_base = 10,
                    range_base = 100,
                    atk_spd_base = 1.0,
                    cooldown = 0.2
                },
                {
                    instance_id = 3,
                    def_id = "warrior",
                    level = 1,
                    hp = 0,
                    hp_max_base = 100,
                    attack_base = 10,
                    range_base = 100,
                    atk_spd_base = 1.0,
                    cooldown = 0.7
                }
            },
            min_len = 1,
            max_len = 8
        }

        local segment_combat_snaps = {
            {
                instance_id = 1,
                x = 0, y = 0,
                effective_attack_int = 10,
                effective_range_num = 100,
                effective_period_num = 1.0,
                cooldown_num = -0.1
            },
            {
                instance_id = 2,
                x = 0, y = 0,
                effective_attack_int = 0, -- cannot attack
                effective_range_num = 100,
                effective_period_num = 1.0,
                cooldown_num = 0.2
            }
        }

        local enemy_snaps = {
            { enemy_id = 1, x = 10, y = 0, hp = 10 }
        }

        local updated_state, attack_events = attack_production_logic.produce_attacks(
            0.1, snake_state, segment_combat_snaps, enemy_snaps
        )

        t.expect(#attack_events).to_be(1)
        t.expect(attack_events[1].attacker_instance_id).to_be(1)

        local seg1 = find_segment(updated_state.segments, 1)
        local seg2 = find_segment(updated_state.segments, 2)
        local seg3 = find_segment(updated_state.segments, 3)

        t.expect(seg1.cooldown).to_be(0.8)
        t.expect(seg2.cooldown).to_be(0.1)
        t.expect(seg3.cooldown).to_be(0.7)
    end)
end)

t.describe("attack_production_logic - empty inputs", function()
    t.it("handles missing snapshots gracefully", function()
        local snake_state = { segments = {}, min_len = 1, max_len = 8 }
        local updated_state, attack_events = attack_production_logic.produce_attacks(0.1, snake_state, nil, nil)

        t.expect(#(updated_state.segments or {})).to_be(0)
        t.expect(#attack_events).to_be(0)
    end)
end)
