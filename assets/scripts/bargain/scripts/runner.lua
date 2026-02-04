-- assets/scripts/bargain/scripts/runner.lua

local sim = require("bargain.sim")
local digest = require("bargain.sim.digest")
local victory = require("bargain.victory")
local death = require("bargain.death")

local runner = {}

function runner.run(script, seed)
    local world = sim.new_world(seed or 1)
    if type(script.setup) == "function" then
        script.setup(world)
    end

    for _, input in ipairs(script.inputs or {}) do
        sim.step(world, input)
        if world.run_state ~= "running" then
            break
        end
    end

    victory.check(world)
    death.check(world)

    return {
        world = world,
        digest = digest.compute(world),
        digest_version = digest.version,
    }
end

return runner
