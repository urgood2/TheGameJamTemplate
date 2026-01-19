-- assets/scripts/tests/test_inventory_sorting.lua
--[[
================================================================================
TEST: Inventory Sorting Logic
================================================================================
Tests the sorting functions for inventory grid items by name and cost.

Run with: lua assets/scripts/tests/test_inventory_sorting.lua
================================================================================
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

local t = require("tests.test_runner")

-- Reset to clear any previous state
t.reset()

--------------------------------------------------------------------------------
-- Test Helpers - Extracted Sorting Logic
--------------------------------------------------------------------------------

-- Mock card data for testing
local function createMockCardData(name, cost)
    return {
        name = name,
        cardData = {
            name = name,
            mana_cost = cost,
        }
    }
end

-- Extracted from player_inventory.lua getSortValue()
local function getSortValue(cardData, field)
    if not cardData then return field == "cost" and 0 or "" end

    local sourceData = cardData.cardData or cardData

    if field == "name" then
        local nameVal = sourceData.name or cardData.id or ""
        if type(nameVal) == "function" then
            local ok, result = pcall(nameVal, sourceData)
            nameVal = ok and result or ""
        end
        return tostring(nameVal or "")
    end
    if field == "cost" then
        local costVal = sourceData.mana_cost or sourceData.manaCost or sourceData.cost or sourceData.price or 0
        if type(costVal) == "function" then
            local ok, result = pcall(costVal, sourceData)
            costVal = ok and result or 0
        end
        return tonumber(costVal) or 0
    end
    return ""
end

-- Sort function extracted from applySorting()
local function sortItems(items, sortField, ascending)
    -- Build sortable list
    local sortable = {}
    for i, item in ipairs(items) do
        table.insert(sortable, {
            entity = item.entity,
            slotIndex = i,
            name = string.lower(getSortValue(item.cardData, "name")),
            cost = getSortValue(item.cardData, "cost"),
        })
    end

    -- Sort
    table.sort(sortable, function(a, b)
        local valA = a[sortField]
        local valB = b[sortField]

        if valA ~= valB then
            if ascending then
                return valA < valB
            else
                return valA > valB
            end
        end

        -- Tiebreaker
        local secA = sortField == "cost" and a.name or a.cost
        local secB = sortField == "cost" and b.name or b.cost
        if ascending then
            return secA < secB
        else
            return secA > secB
        end
    end)

    return sortable
end

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

t.describe("InventorySorting", function()

    t.describe("getSortValue", function()

        t.it("returns name from cardData", function()
            local card = createMockCardData("Fireball", 25)
            local name = getSortValue(card, "name")
            t.expect(name).to_be("Fireball")
        end)

        t.it("returns cost from cardData.mana_cost", function()
            local card = createMockCardData("Fireball", 25)
            local cost = getSortValue(card, "cost")
            t.expect(cost).to_be(25)
        end)

        t.it("returns empty string for nil card name", function()
            local card = { cardData = {} }
            local name = getSortValue(card, "name")
            t.expect(name).to_be("")
        end)

        t.it("returns 0 for nil card cost", function()
            local card = { cardData = {} }
            local cost = getSortValue(card, "cost")
            t.expect(cost).to_be(0)
        end)

        t.it("handles nil cardData gracefully", function()
            local name = getSortValue(nil, "name")
            local cost = getSortValue(nil, "cost")
            t.expect(name).to_be("")
            t.expect(cost).to_be(0)
        end)

    end)

    t.describe("sortItems by name", function()

        t.it("sorts alphabetically ascending", function()
            local items = {
                { entity = 1, cardData = createMockCardData("Zephyr", 10) },
                { entity = 2, cardData = createMockCardData("Arcane", 20) },
                { entity = 3, cardData = createMockCardData("Meteor", 30) },
            }

            local sorted = sortItems(items, "name", true)

            t.expect(sorted[1].name).to_be("arcane")
            t.expect(sorted[2].name).to_be("meteor")
            t.expect(sorted[3].name).to_be("zephyr")
        end)

        t.it("sorts alphabetically descending", function()
            local items = {
                { entity = 1, cardData = createMockCardData("Arcane", 10) },
                { entity = 2, cardData = createMockCardData("Zephyr", 20) },
                { entity = 3, cardData = createMockCardData("Meteor", 30) },
            }

            local sorted = sortItems(items, "name", false)

            t.expect(sorted[1].name).to_be("zephyr")
            t.expect(sorted[2].name).to_be("meteor")
            t.expect(sorted[3].name).to_be("arcane")
        end)

    end)

    t.describe("sortItems by cost", function()

        t.it("sorts by cost ascending", function()
            local items = {
                { entity = 1, cardData = createMockCardData("A", 50) },
                { entity = 2, cardData = createMockCardData("B", 10) },
                { entity = 3, cardData = createMockCardData("C", 30) },
            }

            local sorted = sortItems(items, "cost", true)

            t.expect(sorted[1].cost).to_be(10)
            t.expect(sorted[2].cost).to_be(30)
            t.expect(sorted[3].cost).to_be(50)
        end)

        t.it("sorts by cost descending", function()
            local items = {
                { entity = 1, cardData = createMockCardData("A", 10) },
                { entity = 2, cardData = createMockCardData("B", 50) },
                { entity = 3, cardData = createMockCardData("C", 30) },
            }

            local sorted = sortItems(items, "cost", false)

            t.expect(sorted[1].cost).to_be(50)
            t.expect(sorted[2].cost).to_be(30)
            t.expect(sorted[3].cost).to_be(10)
        end)

        t.it("uses name as tiebreaker when costs are equal", function()
            local items = {
                { entity = 1, cardData = createMockCardData("Zephyr", 20) },
                { entity = 2, cardData = createMockCardData("Arcane", 20) },
                { entity = 3, cardData = createMockCardData("Meteor", 20) },
            }

            local sorted = sortItems(items, "cost", true)

            -- All same cost, so sorted by name (tiebreaker)
            t.expect(sorted[1].name).to_be("arcane")
            t.expect(sorted[2].name).to_be("meteor")
            t.expect(sorted[3].name).to_be("zephyr")
        end)

    end)

    t.describe("toggleSort behavior", function()

        t.it("toggles direction when clicking same field twice", function()
            -- Simulated state
            local state = { sortField = nil, sortAsc = true }

            -- First click on "name"
            if state.sortField == "name" then
                state.sortAsc = not state.sortAsc
            else
                state.sortField = "name"
                state.sortAsc = true
            end

            t.expect(state.sortField).to_be("name")
            t.expect(state.sortAsc).to_be(true)

            -- Second click on "name" (same field)
            if state.sortField == "name" then
                state.sortAsc = not state.sortAsc
            else
                state.sortField = "name"
                state.sortAsc = true
            end

            t.expect(state.sortField).to_be("name")
            t.expect(state.sortAsc).to_be(false)
        end)

        t.it("resets to ascending when switching fields", function()
            -- Simulated state - already sorting by cost descending
            local state = { sortField = "cost", sortAsc = false }

            -- Click on "name" (different field)
            if state.sortField == "name" then
                state.sortAsc = not state.sortAsc
            else
                state.sortField = "name"
                state.sortAsc = true
            end

            t.expect(state.sortField).to_be("name")
            t.expect(state.sortAsc).to_be(true)  -- Reset to ascending
        end)

    end)

end)

--------------------------------------------------------------------------------
-- Run Tests
--------------------------------------------------------------------------------

local success = t.run()
if not success then
    os.exit(1)
end

return t
