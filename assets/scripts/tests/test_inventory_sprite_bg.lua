-- assets/scripts/tests/test_inventory_sprite_bg.lua
--[[
================================================================================
TEST: Inventory Panel Sprite Background
================================================================================
Tests the sprite background configuration for the inventory panel.

Run with: lua assets/scripts/tests/test_inventory_sprite_bg.lua
================================================================================
]]

-- Setup package path for standalone execution
package.path = package.path .. ";./assets/scripts/?.lua"

local t = require("tests.test_runner")

-- Reset to clear any previous state
t.reset()

--------------------------------------------------------------------------------
-- Extracted Constants (mirrors player_inventory.lua)
--------------------------------------------------------------------------------

-- These should match what's in player_inventory.lua
local PANEL_SPRITE = "ui-decor-test-1.png"  -- Placeholder until inventory-back-panel.png created
local PANEL_SPRITE_SCALE = 2.5

-- Content-driven dimensions (mirrors player_inventory.lua)
local SPRITE_BASE_W = 32
local SPRITE_BASE_H = 32
local SPRITE_SCALE = 2.5
local SLOT_WIDTH = SPRITE_BASE_W * SPRITE_SCALE
local SLOT_HEIGHT = SPRITE_BASE_H * SPRITE_SCALE
local SLOT_SPACING = 4
local GRID_ROWS = 3
local GRID_COLS = 6
local GRID_PADDING = 6
local PANEL_PADDING = 10
local HEADER_HEIGHT = 32
local TABS_HEIGHT = 32
local FOOTER_HEIGHT = 36
local GRID_WIDTH = GRID_COLS * SLOT_WIDTH + (GRID_COLS - 1) * SLOT_SPACING + GRID_PADDING * 2
local GRID_HEIGHT = GRID_ROWS * SLOT_HEIGHT + (GRID_ROWS - 1) * SLOT_SPACING + GRID_PADDING * 2
local CONTENT_WIDTH = GRID_WIDTH + PANEL_PADDING * 2
local CONTENT_HEIGHT = HEADER_HEIGHT + TABS_HEIGHT + GRID_HEIGHT + FOOTER_HEIGHT + PANEL_PADDING * 2

--------------------------------------------------------------------------------
-- Helper Functions (extracted logic for testing)
--------------------------------------------------------------------------------

-- Mock sprite dimensions for testing (simulates animation_system.getNinepatchUIBorderInfo)
local mockSpriteDimensions = {
    ["ui-decor-test-1.png"] = { width = 140, height = 180 },
    ["inventory-back-panel.png"] = { width = 160, height = 210 },
}

local function getSpriteDimensions(spriteName)
    local mock = mockSpriteDimensions[spriteName]
    if mock then
        return mock.width, mock.height, true
    end
    return CONTENT_WIDTH, CONTENT_HEIGHT, false
end

local function calculateScaledDimensions(spriteName, scale)
    local w, h = getSpriteDimensions(spriteName)
    return math.floor(w * scale), math.floor(h * scale)
end

local function calculatePanelDimensions(spriteName, scale)
    local w, h, found = getSpriteDimensions(spriteName)
    if found then
        local scaledW = math.floor(w * scale)
        local scaledH = math.floor(h * scale)
        return math.max(CONTENT_WIDTH, scaledW), math.max(CONTENT_HEIGHT, scaledH)
    end
    return CONTENT_WIDTH, CONTENT_HEIGHT
end

--------------------------------------------------------------------------------
-- Tests
--------------------------------------------------------------------------------

t.describe("InventorySpriteBg", function()

    t.describe("sprite dimensions", function()

        t.it("gets dimensions for known sprite", function()
            local w, h = getSpriteDimensions("ui-decor-test-1.png")
            t.expect(w).to_be(140)
            t.expect(h).to_be(180)
        end)

        t.it("falls back for unknown sprite", function()
            local w, h, found = getSpriteDimensions("nonexistent.png")
            t.expect(found).to_be(false)
            t.expect(w).to_be(CONTENT_WIDTH)
            t.expect(h).to_be(CONTENT_HEIGHT)
        end)

    end)

    t.describe("scaled dimensions", function()

        t.it("calculates 2.5x scaled dimensions", function()
            local w, h = calculateScaledDimensions("ui-decor-test-1.png", 2.5)
            t.expect(w).to_be(350)  -- 140 * 2.5
            t.expect(h).to_be(450)  -- 180 * 2.5
        end)

        t.it("calculates 1x scaled dimensions", function()
            local w, h = calculateScaledDimensions("ui-decor-test-1.png", 1)
            t.expect(w).to_be(140)
            t.expect(h).to_be(180)
        end)

        t.it("handles fractional scales", function()
            local w, h = calculateScaledDimensions("ui-decor-test-1.png", 1.5)
            t.expect(w).to_be(210)  -- floor(140 * 1.5)
            t.expect(h).to_be(270)  -- floor(180 * 1.5)
        end)

    end)

    t.describe("sprite panel config", function()

        t.it("generates correct config for spritePanel", function()
            local scale = PANEL_SPRITE_SCALE
            local w, h = calculatePanelDimensions(PANEL_SPRITE, scale)
            local borders = { 8, 8, 8, 8 }  -- Nine-patch borders (matches PANEL_BORDERS)

            local config = {
                sprite = PANEL_SPRITE,
                borders = borders,
                minWidth = w,
                minHeight = h,
                maxWidth = w,
                maxHeight = h,
            }

            t.expect(config.sprite).to_be("ui-decor-test-1.png")
            t.expect(config.borders[1]).to_be(8)
            -- Validate calculated dimensions match expected values (max of content and sprite)
            t.expect(w).to_be(math.max(CONTENT_WIDTH, 350))  -- 140 * 2.5
            t.expect(h).to_be(math.max(CONTENT_HEIGHT, 450)) -- 180 * 2.5
            t.expect(config.minWidth).to_be(w)
            t.expect(config.minHeight).to_be(h)
        end)

    end)

    t.describe("dimension caching", function()

        t.it("ensurePanelDimensions pattern caches values", function()
            local state = { panelWidth = nil, panelHeight = nil }

            -- Simulated ensurePanelDimensions
            local function ensurePanelDimensions()
                if state.panelWidth and state.panelHeight then return end
                local w, h = calculatePanelDimensions(PANEL_SPRITE, PANEL_SPRITE_SCALE)
                state.panelWidth = w
                state.panelHeight = h
            end

            -- First call computes
            ensurePanelDimensions()
            t.expect(state.panelWidth).to_be(math.max(CONTENT_WIDTH, 350))
            t.expect(state.panelHeight).to_be(math.max(CONTENT_HEIGHT, 450))

            -- Modify cached values
            state.panelWidth = 999

            -- Second call should NOT recompute (cached)
            ensurePanelDimensions()
            t.expect(state.panelWidth).to_be(999)  -- Should remain 999, not recomputed
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
