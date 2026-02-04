-- assets/scripts/tests/bargain/digest_spec.lua

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local sim = require("bargain.sim")
local digest = require("bargain.sim.digest")
local constants = require("bargain.sim.constants")
local scripts = require("bargain.scripts.loader")
local runner = require("bargain.scripts.runner")

t.describe("Bargain digest", function()
    t.it("uses the configured digest version", function()
        t.expect(digest.version).to_be(constants.DIGEST_VERSION)
        t.expect(type(digest.version)).to_be("string")
        t.expect(#digest.version > 0).to_be(true)
    end)

    t.it("is stable across repeated calls", function()
        local world = sim.new_world(7)
        local first = digest.compute(world)
        local second = digest.compute(world)
        t.expect(first).to_be(second)
    end)

    t.it("matches across consecutive runs for same seed and script", function()
        local script = scripts.load_all().by_id["S1"]
        local run_a = runner.run(script, 42)
        local run_b = runner.run(script, 42)
        t.expect(run_a.digest).to_be(run_b.digest)
    end)
end)
