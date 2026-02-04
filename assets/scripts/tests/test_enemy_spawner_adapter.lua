--[[
================================================================================
TEST: Enemy Spawner Adapter
================================================================================
Tests for enemy entity mapping, contact collector integration, and spawn logic.

Run with: lua assets/scripts/tests/test_enemy_spawner_adapter.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

package.loaded["serpent.enemy_spawner_adapter"] = nil

local t = require("tests.test_runner")

-- Mock dependencies
_G.log_debug = print
_G.log_warning = print

-- Mock spawn/despawn functions
local mock_entity_counter = 1
_G.spawn = function()
    local entity_id = mock_entity_counter
    mock_entity_counter = mock_entity_counter + 1
    return entity_id
end

_G.despawn = function(entity_id)
    -- Mock implementation - entity cleanup
end

-- Mock physics module
_G.physics = {}
_G.registry = {}
physics.SetPosition = function(physics, registry, entity_id, x, y)
    -- Mock position setting
end

physics.GetPosition = function(physics, registry, entity_id)
    return { x = 100, y = 200 } -- Mock position
end

-- Mock PhysicsBuilder
local PhysicsBuilder = {
    for_entity = function(entity_id)
        return {
            circle = function(self) return self end,
            tag = function(self, tag) return self end,
            density = function(self, density) return self end,
            friction = function(self, friction) return self end,
            fixedRotation = function(self, fixed) return self end,
            apply = function(self) end
        }
    end
}

package.loaded["core.physics_builder"] = PhysicsBuilder
package.loaded["core.constants"] = { CollisionTags = { ENEMY = "ENEMY" } }

-- Mock enemy_factory
package.loaded["serpent.enemy_factory"] = {
    create_snapshot = function(enemy_def, enemy_id, wave_num, wave_config, x, y)
        return {
            enemy_id = enemy_id,
            def_id = enemy_def.id,
            type = enemy_def.type,
            hp = enemy_def.base_hp,
            x = x,
            y = y,
            is_alive = true
        }
    end
}

t.describe("enemy_spawner_adapter - Entity Mapping", function()
    t.it("maintains enemy_id to entity_id mapping", function()
        local adapter = require("serpent.enemy_spawner_adapter")
        adapter.init()

        local enemy_defs = {
            goblin = { id = "goblin", type = "goblin", base_hp = 30 }
        }

        local spawn_event = {
            kind = "spawn_enemy",
            enemy_id = 101,
            def_id = "goblin",
            spawn_rule = {
                mode = "edge_random",
                arena = { w = 800, h = 600, padding = 50 }
            }
        }

        -- Mock RNG
        local rng = {
            int = function(self, min, max) return min end,
            float = function(self) return 0.5 end
        }

        local snapshot = adapter.spawn_enemy(spawn_event, rng, 1, enemy_defs, {})

        -- Verify entity mapping works
        local entity_id = adapter.get_entity_id(101)
        t.expect(entity_id).to_be_truthy()
        t.expect(adapter.get_enemy_id(entity_id)).to_be(101)

        -- Verify snapshot returned
        t.expect(snapshot.enemy_id).to_be(101)
        t.expect(snapshot.def_id).to_be("goblin")
    end)

    t.it("registers with contact collector", function()
        local adapter = require("serpent.enemy_spawner_adapter")
        adapter.init()

        local registered_enemies = {}

        -- Mock contact collector
        _G.serpent_contact_collector = {
            register_enemy_entity = function(enemy_id, entity_id)
                registered_enemies[enemy_id] = entity_id
            end,
            unregister_enemy_entity = function(enemy_id, entity_id)
                registered_enemies[enemy_id] = nil
            end
        }

        local enemy_defs = {
            orc = { id = "orc", type = "orc", base_hp = 50 }
        }

        local spawn_event = {
            kind = "spawn_enemy",
            enemy_id = 202,
            def_id = "orc",
            spawn_rule = {
                mode = "edge_random",
                arena = { w = 800, h = 600, padding = 50 }
            }
        }

        local rng = {
            int = function(self, min, max) return min end,
            float = function(self) return 0.5 end
        }

        adapter.spawn_enemy(spawn_event, rng, 1, enemy_defs, {})

        -- Verify contact collector registration
        t.expect(registered_enemies[202]).to_be_truthy()

        -- Test unregistration
        adapter.despawn_enemy(202)
        t.expect(registered_enemies[202]).to_be_nil()
    end)

    t.it("handles multiple enemies correctly", function()
        local adapter = require("serpent.enemy_spawner_adapter")
        adapter.init()

        local enemy_defs = {
            slime = { id = "slime", type = "slime", base_hp = 20 }
        }

        local spawn_events = {
            { kind = "spawn_enemy", enemy_id = 301, def_id = "slime",
              spawn_rule = { mode = "edge_random", arena = { w = 800, h = 600, padding = 50 } } },
            { kind = "spawn_enemy", enemy_id = 302, def_id = "slime",
              spawn_rule = { mode = "edge_random", arena = { w = 800, h = 600, padding = 50 } } },
            { kind = "spawn_enemy", enemy_id = 303, def_id = "slime",
              spawn_rule = { mode = "edge_random", arena = { w = 800, h = 600, padding = 50 } } }
        }

        local rng = {
            int = function(self, min, max) return min end,
            float = function(self) return 0.5 end
        }

        local enemy_entities, enemy_snaps = adapter.apply(spawn_events, {}, {}, rng, 1, enemy_defs, {})

        -- Verify all enemies are mapped
        t.expect(adapter.get_entity_id(301)).to_be_truthy()
        t.expect(adapter.get_entity_id(302)).to_be_truthy()
        t.expect(adapter.get_entity_id(303)).to_be_truthy()

        -- Verify snapshots are sorted by enemy_id
        t.expect(#enemy_snaps).to_be(3)
        t.expect(enemy_snaps[1].enemy_id).to_be(301)
        t.expect(enemy_snaps[2].enemy_id).to_be(302)
        t.expect(enemy_snaps[3].enemy_id).to_be(303)
    end)

    t.it("builds position snapshots correctly", function()
        local adapter = require("serpent.enemy_spawner_adapter")
        adapter.init()

        local enemy_defs = {
            bat = { id = "bat", type = "bat", base_hp = 15 }
        }

        local spawn_event = {
            kind = "spawn_enemy",
            enemy_id = 401,
            def_id = "bat",
            spawn_rule = {
                mode = "edge_random",
                arena = { w = 800, h = 600, padding = 50 }
            }
        }

        local rng = {
            int = function(self, min, max) return min end,
            float = function(self) return 0.5 end
        }

        adapter.spawn_enemy(spawn_event, rng, 1, enemy_defs, {})

        local pos_snapshots = adapter.build_pos_snapshots()

        t.expect(#pos_snapshots).to_be(1)
        t.expect(pos_snapshots[1].enemy_id).to_be(401)
        t.expect(pos_snapshots[1].x).to_be(100) -- Mock position
        t.expect(pos_snapshots[1].y).to_be(200) -- Mock position
    end)
end)

local success = t.run()
os.exit(success and 0 or 1)