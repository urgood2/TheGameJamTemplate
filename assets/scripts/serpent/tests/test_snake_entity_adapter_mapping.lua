--[[
================================================================================
TEST: Snake Entity Adapter Mapping
================================================================================
Run with: lua assets/scripts/serpent/tests/test_snake_entity_adapter_mapping.lua
]]

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

-- Mock log functions
local log_debug = log_debug or function(msg) end
local log_warning = log_warning or function(msg) end

-- Mock physics system
local mock_physics = { positions = {}, last_id = 100 }
function mock_physics.SetPosition(physics, registry, entity_id, x, y)
    mock_physics.positions[entity_id] = { x = x, y = y }
end
function mock_physics.GetPosition(physics, registry, entity_id)
    return mock_physics.positions[entity_id]
end

-- Mock PhysicsBuilder
local mock_physics_builder = {}
function mock_physics_builder.for_entity(entity_id)
    return {
        circle = function(self) return self end,
        tag = function(self, tag) return self end,
        density = function(self, d) return self end,
        friction = function(self, f) return self end,
        fixedRotation = function(self, fixed) return self end,
        apply = function(self) end
    }
end

-- Mock spawn/despawn
function spawn()
    mock_physics.last_id = mock_physics.last_id + 1
    return mock_physics.last_id
end

function despawn(entity_id)
    mock_physics.positions[entity_id] = nil
end

-- Stub constants and physics builder
package.loaded["core.constants"] = { CollisionTags = { SERPENT_SEGMENT = "serpent_segment" } }
package.loaded["core.physics_builder"] = mock_physics_builder

_G.physics = mock_physics
_G.registry = "mock_registry"

package.loaded["serpent.snake_entity_adapter"] = nil

local t = require("tests.test_runner")
local snake_entity_adapter = require("serpent.snake_entity_adapter")

t.describe("snake_entity_adapter mapping", function()
    t.it("tracks instance_id <-> entity_id and registers with contact_collector", function()
        snake_entity_adapter.init()

        local register_calls = {}
        local unregister_calls = {}
        _G.serpent_contact_collector = {
            register_segment_entity = function(instance_id, entity_id)
                table.insert(register_calls, { instance_id = instance_id, entity_id = entity_id })
            end,
            unregister_segment_entity = function(instance_id, entity_id)
                table.insert(unregister_calls, { instance_id = instance_id, entity_id = entity_id })
            end
        }

        local entity_id = snake_entity_adapter.spawn_segment(1, 10, 20, 8)

        t.expect(snake_entity_adapter.get_entity_id(1)).to_be(entity_id)
        t.expect(snake_entity_adapter.get_instance_id(entity_id)).to_be(1)
        t.expect(#register_calls).to_be(1)
        t.expect(register_calls[1].instance_id).to_be(1)
        t.expect(register_calls[1].entity_id).to_be(entity_id)

        snake_entity_adapter.despawn_segment(1)

        t.expect(snake_entity_adapter.get_entity_id(1)).to_be_nil()
        t.expect(#unregister_calls).to_be(1)
        t.expect(unregister_calls[1].instance_id).to_be(1)
        t.expect(unregister_calls[1].entity_id).to_be(entity_id)
    end)
end)
