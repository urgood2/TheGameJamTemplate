-- assets/scripts/tests/bargain/victory_death_spec.lua

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local sim = require("bargain.sim")
local boss = require("bargain.boss")
local victory = require("bargain.victory")
local death = require("bargain.death")
local constants = require("bargain.sim.constants")

t.describe("Bargain victory and death", function()
    t.it("sets victory when boss is dead on floor 7", function()
        local world = sim.new_world(1)
        world.floor_num = 7
        local b = boss.spawn(world, { x = 2, y = 2 })
        b.hp = 0

        victory.check(world)
        t.expect(world.run_state).to_be(constants.RUN_STATES.VICTORY)
    end)

    t.it("sets death when player HP is zero", function()
        local world = sim.new_world(1)
        local player = world.entities.by_id[world.player_id]
        player.hp = 0

        death.check(world)
        t.expect(world.run_state).to_be(constants.RUN_STATES.DEATH)
    end)
end)
