-- assets/scripts/tests/test_card_categorization.lua
--[[
================================================================================
TEST: Card Categorization Logic
================================================================================
Tests the detectCardCategory() function for auto-routing cards to correct tabs.

Run with: lua assets/scripts/tests/test_card_categorization.lua
================================================================================
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

local t = require("tests.test_runner")

-- Reset to clear any previous state
t.reset()

--------------------------------------------------------------------------------
-- Extracted Category Detection Logic (mirrors player_inventory.lua)
--------------------------------------------------------------------------------

-- Mock WandEngine for testing
local MockWandEngine = {
    trigger_card_defs = {
        ["on_hit_trigger"] = { id = "on_hit_trigger" },
        ["timer_trigger"] = { id = "timer_trigger" },
    },
    card_defs = {
        ["fireball"] = { id = "fireball" },
        ["ice_shard"] = { id = "ice_shard" },
    }
}

-- Sentinel value to indicate "use MockWandEngine as default"
local USE_DEFAULT_WANDENGINE = {}

-- This mirrors the planned detectCardCategory() function
-- Pass nil for wandEngine to simulate when WandEngine global is not defined
-- Pass USE_DEFAULT_WANDENGINE (or omit 4th param via wrapper) to use MockWandEngine
local function detectCardCategory(cardEntity, cardData, script, wandEngine)
    local data = cardData or (script and script.cardData) or script or {}
    -- Default to MockWandEngine for most tests, but allow explicit nil
    if wandEngine == USE_DEFAULT_WANDENGINE then
        wandEngine = MockWandEngine
    end

    -- Explicit category wins
    if data.category then
        local c = data.category
        if c == "trigger" or c == "triggers" then return "triggers" end
        if c == "action" or c == "actions" then return "actions" end
        if c == "modifier" or c == "modifiers" then return "modifiers" end
        if c == "wand" or c == "wands" then return "wands" end
        if c == "equipment" then return "equipment" end
    end

    -- Card data type (common for cards.lua definitions)
    if data.type == "trigger" then return "triggers" end
    if data.type == "action" then return "actions" end
    if data.type == "modifier" then return "modifiers" end
    if data.type == "wand" then return "wands" end

    -- Legacy flags
    if script and script.isTrigger then return "triggers" end

    -- WandEngine definitions (if present)
    if data.cardID and wandEngine then
        if wandEngine.trigger_card_defs and wandEngine.trigger_card_defs[data.cardID] then
            return "triggers"
        end
        if wandEngine.card_defs and wandEngine.card_defs[data.cardID] then
            return "actions"
        end
    end

    -- Default to active tab (simulated as "equipment" for testing)
    return "equipment"
end

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

t.describe("CardCategorization", function()

    t.describe("explicit category field", function()

        t.it("routes 'trigger' to triggers tab", function()
            local data = { category = "trigger" }
            t.expect(detectCardCategory(nil, data, nil)).to_be("triggers")
        end)

        t.it("routes 'triggers' to triggers tab", function()
            local data = { category = "triggers" }
            t.expect(detectCardCategory(nil, data, nil)).to_be("triggers")
        end)

        t.it("routes 'action' to actions tab", function()
            local data = { category = "action" }
            t.expect(detectCardCategory(nil, data, nil)).to_be("actions")
        end)

        t.it("routes 'actions' to actions tab", function()
            local data = { category = "actions" }
            t.expect(detectCardCategory(nil, data, nil)).to_be("actions")
        end)

        t.it("routes 'modifier' to modifiers tab", function()
            local data = { category = "modifier" }
            t.expect(detectCardCategory(nil, data, nil)).to_be("modifiers")
        end)

        t.it("routes 'modifiers' to modifiers tab", function()
            local data = { category = "modifiers" }
            t.expect(detectCardCategory(nil, data, nil)).to_be("modifiers")
        end)

        t.it("routes 'wand' to wands tab", function()
            local data = { category = "wand" }
            t.expect(detectCardCategory(nil, data, nil)).to_be("wands")
        end)

        t.it("routes 'equipment' to equipment tab", function()
            local data = { category = "equipment" }
            t.expect(detectCardCategory(nil, data, nil)).to_be("equipment")
        end)

    end)

    t.describe("type field detection", function()

        t.it("routes type=trigger to triggers tab", function()
            local data = { type = "trigger" }
            t.expect(detectCardCategory(nil, data, nil)).to_be("triggers")
        end)

        t.it("routes type=action to actions tab", function()
            local data = { type = "action" }
            t.expect(detectCardCategory(nil, data, nil)).to_be("actions")
        end)

        t.it("routes type=modifier to modifiers tab", function()
            local data = { type = "modifier" }
            t.expect(detectCardCategory(nil, data, nil)).to_be("modifiers")
        end)

        t.it("routes type=wand to wands tab", function()
            local data = { type = "wand" }
            t.expect(detectCardCategory(nil, data, nil)).to_be("wands")
        end)

    end)

    t.describe("legacy script flags", function()

        t.it("routes script.isTrigger=true to triggers tab", function()
            local script = { isTrigger = true }
            t.expect(detectCardCategory(nil, nil, script)).to_be("triggers")
        end)

    end)

    t.describe("WandEngine lookup", function()

        t.it("routes cardID in trigger_card_defs to triggers", function()
            local data = { cardID = "on_hit_trigger" }
            t.expect(detectCardCategory(nil, data, nil, MockWandEngine)).to_be("triggers")
        end)

        t.it("routes cardID in card_defs to actions", function()
            local data = { cardID = "fireball" }
            t.expect(detectCardCategory(nil, data, nil, MockWandEngine)).to_be("actions")
        end)

        t.it("unknown cardID falls back to equipment", function()
            local data = { cardID = "unknown_card" }
            t.expect(detectCardCategory(nil, data, nil, MockWandEngine)).to_be("equipment")
        end)

        t.it("gracefully handles missing WandEngine", function()
            local data = { cardID = "fireball" }
            -- Pass nil for wandEngine to simulate when WandEngine global is not defined
            t.expect(detectCardCategory(nil, data, nil, nil)).to_be("equipment")
        end)

    end)

    t.describe("fallback behavior", function()

        t.it("returns equipment for empty data", function()
            t.expect(detectCardCategory(nil, {}, nil)).to_be("equipment")
        end)

        t.it("returns equipment for nil data", function()
            t.expect(detectCardCategory(nil, nil, nil)).to_be("equipment")
        end)

    end)

    t.describe("priority ordering", function()

        t.it("explicit category beats type field", function()
            local data = { category = "triggers", type = "action" }
            t.expect(detectCardCategory(nil, data, nil)).to_be("triggers")
        end)

        t.it("type field beats WandEngine lookup", function()
            local data = { type = "modifier", cardID = "fireball" }  -- fireball is in card_defs
            t.expect(detectCardCategory(nil, data, nil, MockWandEngine)).to_be("modifiers")
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
