--[[
================================================================================
SPRITE UI SHOWCASE - Reference Implementation for Custom UI Elements
================================================================================

This file demonstrates the UI DSL (Domain Specific Language) for creating
sprite-based UI elements. Use this as a reference when building your own UI.

QUICK START - Creating UI:
--------------------------
local dsl = require("ui.ui_syntax_sugar")

-- 1. Define your UI structure
local myUI = dsl.strict.vbox {
    config = { padding = 10, color = "darkgray" },
    children = {
        dsl.strict.text("Hello World", { fontSize = 16, color = "white" }),
        dsl.strict.button("Click Me", { onClick = function() print("clicked!") end })
    }
}

-- 2. Spawn it at a position
local entity = dsl.spawn({ x = 100, y = 100 }, myUI, "ui", 100)

LAYOUT CONTAINERS:
-----------------
dsl.strict.vbox { config = {...}, children = {...} }  -- Vertical stack
dsl.strict.hbox { config = {...}, children = {...} }  -- Horizontal stack
dsl.strict.root { config = {...}, children = {...} }  -- Root container

BASIC ELEMENTS:
--------------
dsl.strict.text(label, opts)           -- Text label
dsl.strict.button(label, opts)         -- Clickable button
dsl.strict.spacer(size)                -- Empty space for layout
dsl.strict.divider(direction, opts)    -- Horizontal/vertical line (participates in layout)

SPRITE ELEMENTS (demonstrated in this showcase):
-----------------------------------------------
dsl.strict.spritePanel { ... }         -- Nine-patch panel (stretches to fit content)
dsl.strict.spriteButton { ... }        -- Button with sprite states (normal/hover/pressed/disabled)

CONFIG OPTIONS:
--------------
config = {
    id = "my_element",          -- Unique ID for lookup
    padding = 10,               -- Inner padding
    color = "darkgray",         -- Background color (name or Color.new())
    minWidth = 100,             -- Minimum dimensions
    minHeight = 50,
    emboss = 2,                 -- 3D effect depth
    hover = true,               -- Enable hover detection
    canCollide = true,          -- Enable click detection
    buttonCallback = function() end,  -- Click handler
}

SPAWNING:
--------
dsl.spawn({ x = 100, y = 200 }, definition, "ui", zOrder)
  - position: { x, y } screen coordinates
  - definition: UI tree from dsl functions
  - layer: "ui" for UI layer
  - zOrder: higher = drawn on top

================================================================================
]]

local dsl = require("ui.ui_syntax_sugar")

local Showcase = {}

function Showcase.createShowcase()
    return dsl.strict.vbox {
        config = { padding = 8 },
        children = {
            dsl.strict.text("Sprite UI Showcase", { fontSize = 18, color = "white", shadow = true }),
            dsl.strict.spacer(12),

            Showcase.createSpritePanelDemo(),
            dsl.strict.spacer(8),

            Showcase.createFixedPaneDemo(),
            dsl.strict.spacer(8),

            Showcase.createDecorationsDemo(),
            dsl.strict.spacer(8),

            Showcase.createDividerDemo(),
            dsl.strict.spacer(8),

            Showcase.createSpriteButtonDemo(),
        }
    }
end

-- Nine-patch panel with test asset (stretches to fit content)
function Showcase.createSpritePanelDemo()
    return dsl.strict.vbox {
        config = { padding = 4 },
        children = {
            dsl.strict.text("Nine-Patch Panel (Stretches)", { fontSize = 14, color = "gold", shadow = true }),
            dsl.strict.spacer(4),

            dsl.strict.spritePanel {
                sprite = "ui-decor-test-1.png",
                borders = { 8, 8, 8, 8 },
                minWidth = 180,
                minHeight = 80,
                padding = 12,
                children = {
                    dsl.strict.text("This panel stretches!", { fontSize = 12, color = "white" }),
                    dsl.strict.text("44x27 sprite -> any size", { fontSize = 10, color = "lightgray" })
                }
            }
        }
    }
end

-- Fixed pane - renders at original sprite size
function Showcase.createFixedPaneDemo()
    return dsl.strict.vbox {
        config = { padding = 4 },
        children = {
            dsl.strict.text("Fixed Pane (Original Size)", { fontSize = 14, color = "gold", shadow = true }),
            dsl.strict.spacer(4),

            dsl.strict.spritePanel {
                sprite = "fixed-pane-test.png",
                sizing = "fit_sprite",  -- Use original sprite dimensions (130x66)
                padding = 8,
                children = {
                    dsl.strict.text("130x66 fixed", { fontSize = 11, color = "white" })
                }
            }
        }
    }
end

-- Decorations demo with ornate corners and centered gem
function Showcase.createDecorationsDemo()
    return dsl.strict.vbox {
        config = { padding = 4 },
        children = {
            dsl.strict.text("Decorations (Corners + Gem)", { fontSize = 14, color = "gold", shadow = true }),
            dsl.strict.spacer(4),

            dsl.strict.spritePanel {
                sprite = "ui-decor-test-2.png",
                borders = { 8, 8, 8, 8 },
                minWidth = 200,
                minHeight = 100,
                padding = 16,
                decorations = {
                    -- Ornate corners (flipped for each position)
                    { sprite = "ornate-corner-test.png", position = "top_left", offset = { -8, -8 } },
                    { sprite = "ornate-corner-test.png", position = "top_right", offset = { 8, -8 }, flip = "x" },
                    { sprite = "ornate-corner-test.png", position = "bottom_left", offset = { -8, 8 }, flip = "y" },
                    { sprite = "ornate-corner-test.png", position = "bottom_right", offset = { 8, 8 }, flip = "both" },

                    -- Gem decoration at top center (scaled to 60%, doesn't affect layout)
                    { sprite = "test-gem-ui-decor.png", position = "top_center", offset = { 0, -14 }, scale = { 0.6, 0.6 } },
                },
                children = {
                    dsl.strict.text("Ornate corners!", { fontSize = 12, color = "white" }),
                    dsl.strict.text("+ centered gem", { fontSize = 10, color = "cyan" })
                }
            }
        }
    }
end

-- Divider demo - both as panel element and as decoration
function Showcase.createDividerDemo()
    return dsl.strict.vbox {
        config = { padding = 4 },
        children = {
            dsl.strict.text("Dividers", { fontSize = 14, color = "gold", shadow = true }),
            dsl.strict.spacer(4),

            dsl.strict.hbox {
                config = { padding = 4 },
                children = {
                    dsl.strict.vbox {
                        config = { padding = 2 },
                        children = {
                            dsl.strict.text("As Panel:", { fontSize = 10, color = "lightgray" }),
                            dsl.strict.spacer(4),
                            dsl.strict.text("Above divider", { fontSize = 10, color = "white" }),
                            dsl.strict.spritePanel {
                                sprite = "test-divider.png",
                                sizing = "fit_sprite",
                            },
                            dsl.strict.text("Below divider", { fontSize = 10, color = "white" }),
                        }
                    },

                    dsl.strict.spacer(16),

                    -- Divider as decoration (arbitrary position, ignores layout)
                    dsl.strict.vbox {
                        config = { padding = 2 },
                        children = {
                            dsl.strict.text("As Decoration:", { fontSize = 10, color = "lightgray" }),
                            dsl.strict.spacer(4),
                            dsl.strict.spritePanel {
                                sprite = "ui-decor-test-2.png",
                                borders = { 6, 6, 6, 6 },
                                minWidth = 80,
                                minHeight = 70,
                                padding = 8,
                                decorations = {
                                    { sprite = "test-divider.png", position = "middle_left", offset = { -30, 0 } },
                                    { sprite = "test-divider.png", position = "bottom_center", offset = { 0, 16 } },
                                },
                                children = {
                                    dsl.strict.text("Panel", { fontSize = 10, color = "white" }),
                                    dsl.strict.text("(decor outside)", { fontSize = 8, color = "cyan" })
                                }
                            }
                        }
                    }
                }
            }
        }
    }
end

-- Sprite buttons with all 4 states
function Showcase.createSpriteButtonDemo()
    return dsl.strict.vbox {
        config = { padding = 4 },
        children = {
            dsl.strict.text("Sprite Buttons (4 States)", { fontSize = 14, color = "gold", shadow = true }),
            dsl.strict.spacer(4),

            dsl.strict.hbox {
                config = { padding = 4 },
                children = {
                    dsl.strict.spriteButton {
                        states = {
                            normal = "button-test-normal.png",
                            hover = "button-test-hover.png",
                            pressed = "button-test-pressed.png",
                            disabled = "button-test-disabled.png"
                        },
                        borders = { 6, 6, 6, 6 },
                        label = "Click",
                        onClick = function()
                            print("Button 1 clicked!")
                        end
                    },
                    dsl.strict.spacer(8),
                    dsl.strict.spriteButton {
                        states = {
                            normal = "button-test-normal.png",
                            hover = "button-test-hover.png",
                            pressed = "button-test-pressed.png",
                            disabled = "button-test-disabled.png"
                        },
                        borders = { 6, 6, 6, 6 },
                        label = "Hover Me",
                        onClick = function()
                            print("Button 2 clicked!")
                        end
                    }
                }
            }
        }
    }
end

return Showcase
