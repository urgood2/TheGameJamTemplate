--[[
================================================================================
SPAWN MODULE TESTS
================================================================================
Tests for the spawn module (spawn.lua)

Run with:
    lua assets/scripts/tests/test_spawn.lua

Note: Tests mock dependencies for standalone testing.
]]

-- Add assets/scripts to package path
package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

--------------------------------------------------------------------------------
-- TEST FRAMEWORK
--------------------------------------------------------------------------------

local test_count = 0
local pass_count = 0
local fail_count = 0
local test_output = {}

local function log_test(msg)
    table.insert(test_output, msg)
end

local function assert_eq(actual, expected, msg)
    test_count = test_count + 1
    if actual ~= expected then
        fail_count = fail_count + 1
        local error_msg = string.format("FAIL: %s - expected '%s', got '%s'",
            msg, tostring(expected), tostring(actual))
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

local function assert_not_nil(value, msg)
    test_count = test_count + 1
    if value == nil then
        fail_count = fail_count + 1
        local error_msg = "FAIL: " .. msg .. " - expected non-nil, got nil"
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

local function assert_nil(value, msg)
    test_count = test_count + 1
    if value ~= nil then
        fail_count = fail_count + 1
        local error_msg = string.format("FAIL: %s - expected nil, got '%s'",
            msg, tostring(value))
        log_test(error_msg)
        print(error_msg)
    else
        pass_count = pass_count + 1
        local pass_msg = "PASS: " .. msg
        log_test(pass_msg)
        print(pass_msg)
    end
end

--------------------------------------------------------------------------------
-- MOCK DEPENDENCIES
--------------------------------------------------------------------------------

-- Mock globals
_G.entt_null = 0
_G.log_warn = print
_G.log_error = print
_G.log_debug = function() end

-- Mock registry
local next_entity_id = 1
local entities = {}

_G.registry = {
    create = function()
        local eid = next_entity_id
        next_entity_id = next_entity_id + 1
        entities[eid] = true
        return eid
    end,
    destroy = function(self, eid)
        entities[eid] = nil
    end,
    valid = function(self, eid)
        return entities[eid] == true
    end
}

-- Mock Transform
_G.Transform = "Transform"

-- Mock components
local components = {}

-- Mock component_cache
package.loaded["core.component_cache"] = {
    get = function(eid, comp)
        if not components[eid] then
            components[eid] = {}
        end
        if not components[eid][comp] then
            components[eid][comp] = {
                actualX = 0,
                actualY = 0,
                actualW = 32,
                actualH = 32,
                actualR = 0,
            }
        end
        return components[eid][comp]
    end
}

-- Mock entity_cache
package.loaded["core.entity_cache"] = {
    valid = function(eid)
        return entities[eid] == true
    end
}

-- Mock Node
package.loaded["monobehavior.behavior_script_v2"] = {
    extend = function(self)
        return setmetatable({}, {
            __index = self,
            __call = function(cls, ...)
                local instance = setmetatable({}, { __index = cls })
                return instance
            end
        })
    end,
    attach_ecs = function(self, opts)
        self._eid = opts.existing_entity
        return self
    end
}

-- Mock animation_system
_G.animation_system = {
    createAnimatedObjectWithTransform = function(sprite, fromSprite, x, y, shaderPass, shadow)
        return registry:create()
    end,
    resizeAnimationObjectsInEntityToFit = function(eid, w, h)
        -- no-op
    end
}

-- Mock signal
local signal_events = {}
package.loaded["external.hump.signal"] = {
    emit = function(event, ...)
        if not signal_events[event] then
            signal_events[event] = {}
        end
        table.insert(signal_events[event], {...})
    end,
    get_events = function()
        return signal_events
    end,
    clear = function()
        signal_events = {}
    end
}

-- Mock timer
package.loaded["core.timer"] = {
    after = function(delay, callback)
        -- Immediately execute for test purposes
        callback()
    end
}

-- Mock EntityBuilder
package.loaded["core.entity_builder"] = {
    create = function(opts)
        local eid = registry:create()
        local script = nil

        if opts.data then
            -- Simulate script table creation
            local Node = require("monobehavior.behavior_script_v2")
            local EntityType = Node:extend()
            script = EntityType {}

            for k, v in pairs(opts.data) do
                script[k] = v
            end

            script:attach_ecs { create_new = false, existing_entity = eid }
        end

        return eid, script
    end
}

-- Mock PhysicsBuilder
local physics_applied = {}
package.loaded["core.physics_builder"] = {
    quick = function(eid, opts)
        physics_applied[eid] = opts
        return true
    end,
    get_applied = function()
        return physics_applied
    end,
    clear = function()
        physics_applied = {}
    end
}

-- Mock SpawnPresets
package.loaded["data.spawn_presets"] = {
    enemies = {
        kobold = {
            sprite = "b1060.png",
            size = { 32, 32 },
            shadow = true,
            physics = {
                shape = "rectangle",
                tag = "enemy",
                collideWith = { "player", "projectile" }
            },
            data = {
                health = 50,
                max_health = 50,
                damage = 10,
                faction = "enemy"
            }
        }
    },
    projectiles = {
        fireball = {
            sprite = "b1060.png",
            size = { 24, 24 },
            shadow = false,
            physics = {
                shape = "circle",
                tag = "projectile",
                collideWith = { "enemy", "WORLD" }
            },
            data = {
                damage = 25,
                damage_type = "fire",
                speed = 400
            }
        }
    },
    pickups = {
        gold_coin = {
            sprite = "b8090.png",
            size = { 16, 16 },
            shadow = false,
            physics = {
                shape = "circle",
                tag = "pickup",
                collideWith = { "player" }
            },
            data = {
                pickup_type = "gold",
                value = 5
            }
        }
    },
    effects = {
        explosion = {
            sprite = "b3997.png",
            size = { 64, 64 },
            shadow = false,
            data = {
                effect_type = "explosion",
                lifetime = 500
            }
        }
    }
}

--------------------------------------------------------------------------------
-- LOAD MODULE
--------------------------------------------------------------------------------

-- Clear singleton guard
_G.__SPAWN_MODULE__ = nil

-- Load spawn module
local spawn = require("core.spawn")

--------------------------------------------------------------------------------
-- TESTS
--------------------------------------------------------------------------------

print("\n=== SPAWN MODULE TESTS ===\n")

-- Test 1: Spawn enemy with preset
print("Test 1: Spawn enemy with preset")
local signal = require("external.hump.signal")
signal.clear()

local enemy, enemy_script = spawn.enemy("kobold", 100, 200)
assert_not_nil(enemy, "enemy entity should exist")
assert_not_nil(enemy_script, "enemy script should exist")
assert_eq(enemy_script.health, 50, "enemy should have preset health")
assert_eq(enemy_script.faction, "enemy", "enemy should have preset faction")

local events = signal.get_events()
assert_not_nil(events["enemy_spawned"], "enemy_spawned event should be emitted")

-- Test 2: Spawn enemy with overrides
print("\nTest 2: Spawn enemy with overrides")
signal.clear()

local enemy2, enemy2_script = spawn.enemy("kobold", 150, 250, {
    data = {
        health = 100,  -- override
        damage = 20    -- override
    }
})
assert_not_nil(enemy2, "enemy2 entity should exist")
assert_not_nil(enemy2_script, "enemy2 script should exist")
assert_eq(enemy2_script.health, 100, "enemy2 should have overridden health")
assert_eq(enemy2_script.damage, 20, "enemy2 should have overridden damage")
assert_eq(enemy2_script.faction, "enemy", "enemy2 should keep preset faction")

-- Test 3: Spawn projectile
print("\nTest 3: Spawn projectile")
signal.clear()

local proj = spawn.projectile("fireball", 300, 300, math.pi / 4)
assert_not_nil(proj, "projectile entity should exist")

local proj_events = signal.get_events()
assert_not_nil(proj_events["projectile_spawned"], "projectile_spawned event should be emitted")

-- Test 4: Spawn pickup
print("\nTest 4: Spawn pickup")
signal.clear()

local pickup, pickup_script = spawn.pickup("gold_coin", 200, 200)
assert_not_nil(pickup, "pickup entity should exist")
assert_not_nil(pickup_script, "pickup script should exist")
assert_eq(pickup_script.pickup_type, "gold", "pickup should have correct type")
assert_eq(pickup_script.value, 5, "pickup should have correct value")

local pickup_events = signal.get_events()
assert_not_nil(pickup_events["pickup_spawned"], "pickup_spawned event should be emitted")

-- Test 5: Spawn effect
print("\nTest 5: Spawn effect")
signal.clear()

local effect, effect_script = spawn.effect("explosion", 400, 400)
assert_not_nil(effect, "effect entity should exist")
assert_not_nil(effect_script, "effect script should exist")
assert_eq(effect_script.effect_type, "explosion", "effect should have correct type")
assert_eq(effect_script.lifetime, 500, "effect should have correct lifetime")

local effect_events = signal.get_events()
assert_not_nil(effect_events["effect_spawned"], "effect_spawned event should be emitted")

-- Test 6: Invalid preset
print("\nTest 6: Invalid preset handling")
local invalid = spawn.enemy("nonexistent_enemy", 100, 100)
assert_nil(invalid, "invalid preset should return nil")

-- Test 7: Invalid category
print("\nTest 7: Invalid category handling")
local invalid_cat = spawn.from_preset("nonexistent_category", "kobold", 100, 100)
assert_nil(invalid_cat, "invalid category should return nil")

-- Test 8: Physics application
print("\nTest 8: Physics application")
local PhysicsBuilder = require("core.physics_builder")
PhysicsBuilder.clear()

local enemy3 = spawn.enemy("kobold", 100, 100)
local physics_cfg = PhysicsBuilder.get_applied()
assert_not_nil(physics_cfg[enemy3], "physics should be applied to enemy")
assert_eq(physics_cfg[enemy3].shape, "rectangle", "physics shape should match preset")
assert_eq(physics_cfg[enemy3].tag, "enemy", "physics tag should match preset")

-- Test 9: Deep merge of overrides
print("\nTest 9: Deep merge of overrides")
local enemy4, enemy4_script = spawn.enemy("kobold", 100, 100, {
    data = {
        health = 75,  -- override only health
        -- damage should still be 10 from preset
        custom_field = "custom"  -- add new field
    }
})
assert_eq(enemy4_script.health, 75, "overridden field should be updated")
assert_eq(enemy4_script.damage, 10, "non-overridden field should keep preset value")
assert_eq(enemy4_script.faction, "enemy", "non-overridden field should keep preset value")
assert_eq(enemy4_script.custom_field, "custom", "custom field should be added")

--------------------------------------------------------------------------------
-- SUMMARY
--------------------------------------------------------------------------------

print("\n=== TEST SUMMARY ===")
print(string.format("Total: %d | Passed: %d | Failed: %d", test_count, pass_count, fail_count))

if fail_count == 0 then
    print("\nALL TESTS PASSED!")
    os.exit(0)
else
    print("\nSOME TESTS FAILED!")
    os.exit(1)
end
