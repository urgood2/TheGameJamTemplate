-- assets/scripts/tests/bargain/deals_downside_spec.lua

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local sim = require("bargain.sim")
local loader = require("bargain.deals.loader")
local apply = require("bargain.deals.apply")

local METRICS = {
    "hp_lost_total",
    "turns_elapsed",
    "damage_dealt_total",
    "damage_taken_total",
    "forced_actions_count",
    "denied_actions_count",
    "visible_tiles_count",
    "resources_spent_total",
}

local function stats_snapshot(world)
    local out = {}
    for _, key in ipairs(METRICS) do
        out[key] = world.stats[key] or 0
    end
    return out
end

local function stats_changed(a, b)
    for _, key in ipairs(METRICS) do
        if (a[key] or 0) ~= (b[key] or 0) then
            return true
        end
    end
    return false
end

t.describe("Bargain deals downside metrics", function()
    local data = loader.load()
    for _, deal in ipairs(data.list) do
        t.it("deal " .. deal.id .. " flips at least one downside metric", function()
            local baseline = sim.new_world(1)
            local before = stats_snapshot(baseline)

            local applied = sim.new_world(1)
            local ok, err = apply.apply_deal(applied, deal.id)
            t.expect(ok).to_be(true)
            t.expect(err).to_be_nil()

            local after = stats_snapshot(applied)
            t.expect(stats_changed(before, after)).to_be(true)
        end)
    end
end)
