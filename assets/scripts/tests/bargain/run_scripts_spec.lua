-- assets/scripts/tests/bargain/run_scripts_spec.lua

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local loader = require("bargain.scripts.loader")
local runner = require("bargain.scripts.runner")
local replay = require("bargain.replay.replay")
local sim = require("bargain.sim")
local boss = require("bargain.enemies.boss")
local victory = require("bargain.sim.victory")
local death = require("bargain.sim.death")
local caps = require("bargain.sim.caps")
local constants = require("bargain.sim.constants")

local GOLDEN_DIR = "assets/scripts/tests/bargain/goldens/scripts"

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local data = f:read("*a")
    f:close()
    return data
end

local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

t.describe("Bargain run scripts", function()
    t.it("runs scripts deterministically and matches goldens", function()
        local scripts = loader.load_all().list
        for _, script in ipairs(scripts) do
            local first = replay.run_script(script, 123)
            local second = replay.run_script(script, 123)
            t.expect(first.digest).to_be(second.digest)

            local ok, result, golden = replay.verify_script(script, 123, GOLDEN_DIR)
            t.expect(ok).to_be(true)
            t.expect(result.digest).to_be(first.digest)
            t.expect(trim(result.digest)).to_be(trim(golden))
        end
    end)

    t.it("victory_test", function()
        local world = sim.new_world(1)
        world.floor_num = 7
        local enemy = boss.spawn(world, { x = 2, y = 2 })
        enemy.hp = 0

        local state = victory.check(world)
        t.expect(state).to_be(constants.RUN_STATES.VICTORY)
        t.expect(world.events).to_be_type("table")
        t.expect(world.events[1].type).to_be("victory")

        local events_before = #world.events
        victory.check(world)
        t.expect(#world.events).to_be(events_before)
    end)

    t.it("death_test", function()
        local world = sim.new_world(1)
        local player = world.entities.by_id[world.player_id]
        player.hp = 0

        local state = death.check(world)
        t.expect(state).to_be(constants.RUN_STATES.DEATH)
        t.expect(world.events).to_be_type("table")
        t.expect(world.events[1].type).to_be("death")
        t.expect(world.events[1].reason).to_be("hp")

        local cap_world = sim.new_world(1)
        caps.trip_cap(cap_world, "max_steps", constants.MAX_STEPS_PER_RUN)
        t.expect(cap_world.run_state).to_be(constants.RUN_STATES.DEATH)
        t.expect(cap_world.events[1].reason).to_be("cap_max_steps")
    end)

    t.it("s1_test", function()
        local script = loader.load_all().by_id["S1"]
        local run = runner.run(script, 123)
        t.expect(run.world.run_state).to_be(constants.RUN_STATES.VICTORY)
        t.expect(#script.inputs).to_be(3)
        t.expect(script.inputs[1].type).to_be("move")
        t.expect(script.inputs[2].type).to_be("attack")
        t.expect(script.inputs[3].type).to_be("wait")
    end)

    t.it("s2_test", function()
        local script = loader.load_all().by_id["S2"]
        local run = runner.run(script, 123)
        t.expect(run.world.run_state).to_be(constants.RUN_STATES.VICTORY)
        t.expect(run.world.deal_state).to_be_type("table")
        t.expect(#run.world.deal_state.chosen).to_be(3)
        t.expect(script.inputs[1].type).to_be("deal_choose")
        t.expect(script.inputs[2].type).to_be("deal_choose")
        t.expect(script.inputs[3].type).to_be("deal_choose")
    end)

    t.it("s3_test", function()
        local script = loader.load_all().by_id["S3"]
        local run = runner.run(script, 123)
        t.expect(run.world.run_state).to_be(constants.RUN_STATES.VICTORY)
        t.expect(#script.inputs).to_be(2)
        t.expect(script.inputs[1].type).to_be("wait")
        t.expect(script.inputs[2].type).to_be("wait")
    end)
end)
