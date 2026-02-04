-- assets/scripts/tests/bargain/sim_smoke_spec.lua

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local sim = require("bargain.sim")
local constants = require("bargain.sim.constants")
local digest = require("bargain.sim.digest")
local death = require("bargain.death")

t.describe("Bargain sim smoke", function()
    t.it("builds a tiny fixed map", function()
        local world = sim.new_world(7)
        t.expect(world.grid.w).to_be(3)
        t.expect(world.grid.h).to_be(3)
        t.expect(world.grid.tiles).to_be_type("table")
    end)

    t.it("handles move/attack/wait inputs", function()
        local world = sim.new_world(7)
        local spawn = require("bargain.enemies.spawn")

        local r1 = sim.step(world, { type = "move", dx = 1, dy = 0 })
        t.expect(r1.ok).to_be(true)

        local player = world.entities.by_id[world.player_id]
        player.pos.x = 2
        player.pos.y = 2
        local enemy = spawn.create_enemy(world, "rat", { x = 2, y = 1 })

        local r2 = sim.step(world, { type = "attack", dx = 0, dy = -1 })
        t.expect(r2.ok).to_be(true)
        t.expect(enemy.hp).to_be(1)

        local r3 = sim.step(world, { type = "wait" })
        t.expect(r3.ok).to_be(true)

        t.expect(world.run_state).to_be(constants.RUN_STATES.RUNNING)
    end)

    t.it("wait_test", function()
        local world = sim.new_world(7)
        world.phase = constants.PHASES.PLAYER_INPUT
        local result = sim.step(world, { type = "wait" })
        t.expect(result.ok).to_be(true)
        t.expect(world.phase).to_be(constants.PHASES.ENEMY_ACTIONS)
    end)

    t.it("attack_test", function()
        local world = sim.new_world(7)
        local spawn = require("bargain.enemies.spawn")
        local player = world.entities.by_id[world.player_id]

        player.pos.x = 2
        player.pos.y = 2

        local enemy = spawn.create_enemy(world, "rat", { x = 2, y = 1 })

        local hit = sim.step(world, { type = "attack", dx = 0, dy = -1 })
        t.expect(hit.ok).to_be(true)
        t.expect(enemy.hp).to_be(1)

        local miss = sim.step(world, { type = "attack", dx = 1, dy = 0 })
        t.expect(miss.ok).to_be(false)
    end)

    t.it("combat_test", function()
        local combat = require("bargain.sim.combat")
        local events = require("bargain.sim.events")
        local spawn = require("bargain.enemies.spawn")

        local world = sim.new_world(7)
        local player = world.entities.by_id[world.player_id]
        player.damage = 3

        local enemy = spawn.create_enemy(world, "rat", { x = 2, y = 1 })
        enemy.hp = 3

        events.begin(world)
        local ok, dead = combat.apply_attack(world, player.id, enemy.id)
        t.expect(ok).to_be(true)
        t.expect(enemy.hp).to_be(0)
        t.expect(dead).to_be(true)

        local emitted = events.snapshot(world)
        t.expect(emitted[1].type).to_be("damage")
        t.expect(emitted[2].type).to_be("death")
    end)

    t.it("move_test", function()
        local world = sim.new_world(7)
        world.grid = {
            w = 4,
            h = 4,
            tiles = {
                { "#", "#", "#", "#" },
                { "#", ".", ".", "#" },
                { "#", ".", ".", "#" },
                { "#", "#", "#", "#" },
            },
        }
        local player = world.entities.by_id[world.player_id]
        player.pos.x = 2
        player.pos.y = 2

        world.phase = constants.PHASES.PLAYER_INPUT
        sim.step(world, { type = "move", dx = 1, dy = 0 })
        t.expect(player.pos.x).to_be(3)
        t.expect(player.pos.y).to_be(2)

        local spawn = require("bargain.enemies.spawn")
        spawn.create_enemy(world, "rat", { x = 3, y = 3 })
        world.phase = constants.PHASES.PLAYER_INPUT
        sim.step(world, { type = "move", dx = 0, dy = 1 })
        t.expect(player.pos.x).to_be(3)
        t.expect(player.pos.y).to_be(2)

        player.pos.x = 2
        player.pos.y = 2
        world.phase = constants.PHASES.PLAYER_INPUT
        sim.step(world, { type = "move", dx = -1, dy = 0 })
        t.expect(player.pos.x).to_be(2)
        t.expect(player.pos.y).to_be(2)
    end)

    t.it("returns deterministic events list", function()
        local world = sim.new_world(8)
        local result = sim.step(world, { type = "move", dx = 0, dy = 1 })
        t.expect(result.events).to_be_type("table")
        if #result.events > 0 then
            t.expect(result.events[1].type).to_be_type("string")
        end
    end)

    t.it("produces stable digest across reruns", function()
        local inputs = {
            { type = "move", dx = 1, dy = 0 },
            { type = "attack", dx = 0, dy = -1 },
            { type = "wait" },
        }

        local world_a = sim.new_world(9)
        for _, input in ipairs(inputs) do
            sim.step(world_a, input)
        end
        local digest_a = digest.compute(world_a)

        local world_b = sim.new_world(9)
        for _, input in ipairs(inputs) do
            sim.step(world_b, input)
        end
        local digest_b = digest.compute(world_b)

        t.expect(digest_a).to_be(digest_b)
    end)

    t.it("verifies terminal outcome", function()
        local world = sim.new_world(11)
        local player = world.entities.by_id[world.player_id]
        player.hp = 0
        death.check(world)
        t.expect(world.run_state).to_be(constants.RUN_STATES.DEATH)
    end)
end)
