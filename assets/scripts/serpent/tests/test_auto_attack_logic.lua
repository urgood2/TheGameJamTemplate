--[[
================================================================================
TEST: Auto Attack Logic
================================================================================
Tests for auto-attack targeting, range checking, multi-attack cadence,
tie-breaking, and stable ordering.

Run with: lua assets/scripts/serpent/tests/test_auto_attack_logic.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

package.loaded["serpent.auto_attack_logic"] = nil

local t = require("tests.test_runner")
local auto_attack_logic = require("serpent.auto_attack_logic")

t.describe("auto_attack_logic - Multi-Attack Cadence", function()
    t.it("attacks multiple times when cooldown allows", function()
        local segment_snap = {
            instance_id = 1,
            x = 0, y = 0,
            effective_attack_int = 25,
            effective_range_num = 100,
            effective_period_num = 1.0,
            cooldown_num = -2.5 -- Ready for multiple attacks
        }

        local enemy_snaps = {
            { enemy_id = 1, x = 50, y = 0, hp = 100 }
        }

        local dt = 0
        local updated_cooldowns, attack_events = auto_attack_logic.tick(dt, {segment_snap}, enemy_snaps)

        -- Should attack 3 times: -2.5 + 1.0 + 1.0 + 1.0 = 0.5
        t.expect(#attack_events).to_be(3)
        t.expect(updated_cooldowns[1]).to_be(0.5)
    end)

    t.it("stops attacking when no target available", function()
        local segment_snap = {
            instance_id = 1,
            x = 0, y = 0,
            effective_attack_int = 25,
            effective_range_num = 50, -- Short range
            effective_period_num = 1.0,
            cooldown_num = -1.5
        }

        local enemy_snaps = {
            { enemy_id = 1, x = 100, y = 0, hp = 100 } -- Out of range
        }

        local dt = 0
        local updated_cooldowns, attack_events = auto_attack_logic.tick(dt, {segment_snap}, enemy_snaps)

        -- Should not attack due to range, cooldown clamped to 0
        t.expect(#attack_events).to_be(0)
        t.expect(updated_cooldowns[1]).to_be(0)
    end)
end)

t.describe("auto_attack_logic - Nearest Selection", function()
    t.it("selects nearest enemy within range", function()
        local segment_snap = {
            instance_id = 1,
            x = 0, y = 0,
            effective_attack_int = 25,
            effective_range_num = 100,
            effective_period_num = 1.0,
            cooldown_num = 0
        }

        local enemy_snaps = {
            { enemy_id = 1, x = 80, y = 0, hp = 50 },  -- Distance 80
            { enemy_id = 2, x = 30, y = 40, hp = 50 }, -- Distance 50 (30² + 40² = 2500, √2500 = 50)
            { enemy_id = 3, x = 60, y = 0, hp = 50 },  -- Distance 60
        }

        local dt = 0
        local updated_cooldowns, attack_events = auto_attack_logic.tick(dt, {segment_snap}, enemy_snaps)

        t.expect(#attack_events).to_be(1)
        t.expect(attack_events[1].target_enemy_id).to_be(2) -- Nearest (distance 50)
        t.expect(attack_events[1].distance).to_be(50)
    end)

    t.it("ignores dead enemies", function()
        local segment_snap = {
            instance_id = 1,
            x = 0, y = 0,
            effective_attack_int = 25,
            effective_range_num = 100,
            effective_period_num = 1.0,
            cooldown_num = 0
        }

        local enemy_snaps = {
            { enemy_id = 1, x = 30, y = 0, hp = 0 },  -- Dead (closest)
            { enemy_id = 2, x = 50, y = 0, hp = 25 }, -- Alive
        }

        local dt = 0
        local updated_cooldowns, attack_events = auto_attack_logic.tick(dt, {segment_snap}, enemy_snaps)

        t.expect(#attack_events).to_be(1)
        t.expect(attack_events[1].target_enemy_id).to_be(2) -- Should target living enemy
    end)
end)

t.describe("auto_attack_logic - Tie-Break Logic", function()
    t.it("breaks distance ties by lowest enemy_id", function()
        local segment_snap = {
            instance_id = 1,
            x = 0, y = 0,
            effective_attack_int = 25,
            effective_range_num = 100,
            effective_period_num = 1.0,
            cooldown_num = 0
        }

        local enemy_snaps = {
            { enemy_id = 5, x = 50, y = 0, hp = 25 }, -- Distance 50, higher ID
            { enemy_id = 2, x = 50, y = 0, hp = 25 }, -- Distance 50, lower ID
            { enemy_id = 8, x = 50, y = 0, hp = 25 }, -- Distance 50, highest ID
        }

        local dt = 0
        local updated_cooldowns, attack_events = auto_attack_logic.tick(dt, {segment_snap}, enemy_snaps)

        t.expect(#attack_events).to_be(1)
        t.expect(attack_events[1].target_enemy_id).to_be(2) -- Lowest enemy_id wins tie
    end)

    t.it("prefers distance over enemy_id", function()
        local segment_snap = {
            instance_id = 1,
            x = 0, y = 0,
            effective_attack_int = 25,
            effective_range_num = 100,
            effective_period_num = 1.0,
            cooldown_num = 0
        }

        local enemy_snaps = {
            { enemy_id = 1, x = 60, y = 0, hp = 25 }, -- Distance 60, lower ID
            { enemy_id = 9, x = 40, y = 0, hp = 25 }, -- Distance 40, higher ID
        }

        local dt = 0
        local updated_cooldowns, attack_events = auto_attack_logic.tick(dt, {segment_snap}, enemy_snaps)

        t.expect(#attack_events).to_be(1)
        t.expect(attack_events[1].target_enemy_id).to_be(9) -- Distance wins over ID
    end)
end)

t.describe("auto_attack_logic - Out-of-Range Handling", function()
    t.it("ignores enemies beyond effective range", function()
        local segment_snap = {
            instance_id = 1,
            x = 0, y = 0,
            effective_attack_int = 25,
            effective_range_num = 50, -- Limited range
            effective_period_num = 1.0,
            cooldown_num = 0
        }

        local enemy_snaps = {
            { enemy_id = 1, x = 30, y = 0, hp = 25 }, -- In range (distance 30)
            { enemy_id = 2, x = 70, y = 0, hp = 25 }, -- Out of range (distance 70)
            { enemy_id = 3, x = 100, y = 0, hp = 25 }, -- Far out of range
        }

        local dt = 0
        local updated_cooldowns, attack_events = auto_attack_logic.tick(dt, {segment_snap}, enemy_snaps)

        t.expect(#attack_events).to_be(1)
        t.expect(attack_events[1].target_enemy_id).to_be(1) -- Only target in range
    end)

    t.it("attacks nothing when all enemies out of range", function()
        local segment_snap = {
            instance_id = 1,
            x = 0, y = 0,
            effective_attack_int = 25,
            effective_range_num = 25, -- Very limited range
            effective_period_num = 1.0,
            cooldown_num = -0.5
        }

        local enemy_snaps = {
            { enemy_id = 1, x = 50, y = 0, hp = 25 }, -- Out of range
            { enemy_id = 2, x = 100, y = 0, hp = 25 }, -- Out of range
        }

        local dt = 0
        local updated_cooldowns, attack_events = auto_attack_logic.tick(dt, {segment_snap}, enemy_snaps)

        t.expect(#attack_events).to_be(0)
        t.expect(updated_cooldowns[1]).to_be(0) -- Cooldown clamped
    end)

    t.it("handles edge case at exact range boundary", function()
        local segment_snap = {
            instance_id = 1,
            x = 0, y = 0,
            effective_attack_int = 25,
            effective_range_num = 50, -- Exact boundary
            effective_period_num = 1.0,
            cooldown_num = 0
        }

        local enemy_snaps = {
            { enemy_id = 1, x = 50, y = 0, hp = 25 }, -- Exactly at range boundary
            { enemy_id = 2, x = 50.1, y = 0, hp = 25 }, -- Just beyond range
        }

        local dt = 0
        local updated_cooldowns, attack_events = auto_attack_logic.tick(dt, {segment_snap}, enemy_snaps)

        t.expect(#attack_events).to_be(1)
        t.expect(attack_events[1].target_enemy_id).to_be(1) -- Should hit exactly at boundary
    end)
end)

t.describe("auto_attack_logic - Stable Ordering", function()
    t.it("processes segments in head->tail order", function()
        local segment_snaps = {
            { -- Head segment
                instance_id = 1,
                x = 0, y = 0,
                effective_attack_int = 10,
                effective_range_num = 100,
                effective_period_num = 1.0,
                cooldown_num = 0
            },
            { -- Tail segment
                instance_id = 2,
                x = 10, y = 0,
                effective_attack_int = 15,
                effective_range_num = 100,
                effective_period_num = 1.0,
                cooldown_num = 0
            }
        }

        local enemy_snaps = {
            { enemy_id = 1, x = 50, y = 0, hp = 25 }
        }

        local dt = 0
        local updated_cooldowns, attack_events = auto_attack_logic.tick(dt, segment_snaps, enemy_snaps)

        t.expect(#attack_events).to_be(2)
        -- Head segment should attack first (deterministic ordering)
        t.expect(attack_events[1].attacker_instance_id).to_be(1)
        t.expect(attack_events[2].attacker_instance_id).to_be(2)
    end)

    t.it("handles segments with no attack capability", function()
        local segment_snaps = {
            { -- Can attack
                instance_id = 1,
                x = 0, y = 0,
                effective_attack_int = 25,
                effective_range_num = 100,
                effective_period_num = 1.0,
                cooldown_num = 0
            },
            { -- Cannot attack (no attack power)
                instance_id = 2,
                x = 10, y = 0,
                effective_attack_int = 0,
                effective_range_num = 100,
                effective_period_num = 1.0,
                cooldown_num = 2.0
            }
        }

        local enemy_snaps = {
            { enemy_id = 1, x = 50, y = 0, hp = 25 }
        }

        local dt = 0.5
        local updated_cooldowns, attack_events = auto_attack_logic.tick(dt, segment_snaps, enemy_snaps)

        t.expect(#attack_events).to_be(1) -- Only one segment can attack
        t.expect(attack_events[1].attacker_instance_id).to_be(1)

        -- Non-attacking segment should still have cooldown reduced
        t.expect(updated_cooldowns[2]).to_be(1.5) -- 2.0 - 0.5
    end)
end)

local success = t.run()
os.exit(success and 0 or 1)