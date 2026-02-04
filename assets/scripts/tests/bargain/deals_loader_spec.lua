-- assets/scripts/tests/bargain/deals_loader_spec.lua

package.path = package.path .. ";./assets/scripts/?.lua;./assets/scripts/?/init.lua"

local t = require("tests.test_runner")
local loader = require("bargain.deals.loader")

local function count_sins(list)
    local counts = {}
    for _, deal in ipairs(list) do
        counts[deal.sin] = (counts[deal.sin] or 0) + 1
    end
    return counts
end

t.describe("Bargain deals loader", function()
    t.it("loads exactly 21 deals with unique IDs", function()
        local data = loader.load()
        t.expect(#data.list).to_be(21)

        local seen = {}
        for _, deal in ipairs(data.list) do
            t.expect(deal.id).to_be_type("string")
            t.expect(seen[deal.id]).to_be_nil()
            seen[deal.id] = true
        end
    end)

    t.it("contains 7 sins with 3 deals each", function()
        local data = loader.load()
        local counts = count_sins(data.list)
        local sins = { "wrath", "pride", "greed", "sloth", "envy", "gluttony", "lust" }
        for _, sin in ipairs(sins) do
            t.expect(counts[sin]).to_be(3)
        end
    end)

    t.it("IDs follow <sin>.<index> format", function()
        local data = loader.load()
        for _, deal in ipairs(data.list) do
            local prefix = deal.sin .. "."
            t.expect(deal.id:sub(1, #prefix)).to_be(prefix)
        end
    end)

    t.it("includes offers_weight metadata", function()
        local data = loader.load()
        for _, deal in ipairs(data.list) do
            t.expect(deal.offers_weight).to_be_type("number")
        end
    end)

    t.it("offer_test", function()
        local offer = require("bargain.deals.offer")
        local rng = require("bargain.sim.rng")
        local catalog = require("bargain.data.deals.catalog")

        local world_a = {
            seed = 7,
            rng = rng.new(7),
            floor_num = 1,
            deal_state = { chosen = {} },
        }
        local world_b = {
            seed = 7,
            rng = rng.new(7),
            floor_num = 1,
            deal_state = { chosen = {} },
        }
        local first = offer.generate(world_a, 3)
        local second = offer.generate(world_b, 3)
        t.expect(#first).to_be(#second)
        for i = 1, #first do
            t.expect(first[i]).to_be(second[i])
        end

        local target = catalog[1]
        local original_requires = target.requires
        local original_weights = {}
        for i, deal in ipairs(catalog) do
            original_weights[i] = deal.offers_weight
            deal.offers_weight = (i == 1) and 1 or 0
        end
        target.requires = { "prereq.deal" }

        local gated_world = {
            seed = 9,
            rng = rng.new(9),
            floor_num = 1,
            deal_state = { chosen = {} },
        }
        local gated_offers = offer.generate(gated_world, 3)
        for _, id in ipairs(gated_offers) do
            t.expect(id).never().to_be(target.id)
        end

        gated_world.deal_state.chosen = { "prereq.deal" }
        gated_world.rng = rng.new(9)
        local unlocked = offer.generate(gated_world, 3)
        local found = false
        for _, id in ipairs(unlocked) do
            if id == target.id then
                found = true
            end
        end
        t.expect(found).to_be(true)

        local offer_floor = offer.create_pending_offer(gated_world, "floor_start")
        t.expect(offer_floor.reason).to_be("floor_start")
        gated_world.deal_state.pending_offer = nil
        local offer_level = offer.create_pending_offer(gated_world, "level_up")
        t.expect(offer_level.reason).to_be("level_up")

        target.requires = original_requires
        for i, deal in ipairs(catalog) do
            deal.offers_weight = original_weights[i]
        end
    end)
end)
