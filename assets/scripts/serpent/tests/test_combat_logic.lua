--[[
================================================================================
TEST: Combat Logic Coverage
================================================================================
Exercises class multipliers, global regen, contact cooldowns, deaths,
and berserker kill stacks across the pure combat modules.

Run with: lua assets/scripts/serpent/tests/test_combat_logic.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

package.loaded["serpent.synergy_system"] = nil
package.loaded["serpent.combat_logic"] = nil
package.loaded["serpent.unit_damage_logic"] = nil
package.loaded["serpent.special_event_hooks"] = nil

local t = require("tests.test_runner")
local synergy_system = require("serpent.synergy_system")
local combat_logic = require("serpent.combat_logic")
local unit_damage_logic = require("serpent.unit_damage_logic")
local special_event_hooks = require("serpent.special_event_hooks")

t.describe("combat_logic - class multipliers + global regen", function()
    t.it("computes class bonuses and support regen", function()
        local unit_defs = {
            warrior = { class = "Warrior" },
            support = { class = "Support" }
        }

        local warrior_segments = {
            { instance_id = 1, def_id = "warrior", hp = 100 },
            { instance_id = 2, def_id = "warrior", hp = 100 }
        }

        local support_segments = {
            { instance_id = 3, def_id = "support", hp = 80 },
            { instance_id = 4, def_id = "support", hp = 80 }
        }

        local synergy_state = synergy_system.calculate(warrior_segments, unit_defs)
        t.expect(synergy_state.active_bonuses.Warrior.atk_mult).to_be(1.2)

        local support_state = synergy_system.calculate(support_segments, unit_defs)
        local regen = synergy_system.get_global_regen_rate(support_state)
        t.expect(regen).to_be(5)
    end)
end)

t.describe("combat_logic - contact cooldown", function()
    t.it("prevents repeated contact damage within cooldown window", function()
        local player_units = {
            { id = 1, stats = { hp = 100, defense = 0 } }
        }

        local enemy_units = {
            { id = 10, stats = { attack = 20 } }
        }

        local contact_snapshot = {
            { enemy_id = 10, instance_id = 1 }
        }

        local contact_cooldowns = {}

        local processed_first = combat_logic.process_contact_damage(
            contact_snapshot, player_units, enemy_units, contact_cooldowns, 0.0
        )
        t.expect(processed_first).to_be(1)

        local hp_after_first = player_units[1].stats.hp

        local processed_second = combat_logic.process_contact_damage(
            contact_snapshot, player_units, enemy_units, contact_cooldowns, 0.2
        )
        t.expect(processed_second).to_be(0)
        t.expect(player_units[1].stats.hp).to_be(hp_after_first)
    end)
end)

t.describe("combat_logic - deaths", function()
    t.it("emits death events when damage kills a segment", function()
        local snake_state = {
            segments = {
                {
                    instance_id = 1,
                    def_id = "warrior",
                    level = 1,
                    hp = 10,
                    hp_max_base = 10,
                    attack_base = 5,
                    range_base = 50,
                    atk_spd_base = 1.0,
                    cooldown = 0
                }
            },
            min_len = 1,
            max_len = 8
        }

        local ctx = { snake_state = snake_state }
        local damage_events = {
            { type = "DamageEventUnit", target_instance_id = 1, amount_int = 15, source_type = "test" }
        }

        local updated_state, death_events = unit_damage_logic.process_damage_events(
            damage_events, snake_state, ctx
        )

        t.expect(#death_events).to_be(1)
        t.expect(#updated_state.segments).to_be(0)
    end)
end)

t.describe("combat_logic - berserker stacks", function()
    t.it("credits berserker kills on enemy death events", function()
        local ctx = {
            snake_state = {
                segments = {
                    {
                        instance_id = 1,
                        special_id = "berserker_frenzy",
                        hp = 100,
                        special_state = { kill_count = 0 }
                    }
                }
            }
        }

        local death_events = {
            { type = "DeathEventEnemy", enemy_id = 5 }
        }

        special_event_hooks.process_enemy_death_events(death_events, ctx)
        t.expect(ctx.snake_state.segments[1].special_state.kill_count).to_be(1)
    end)
end)
