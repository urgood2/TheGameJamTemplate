local dsl = require("ui.ui_syntax_sugar")

local Showcase = {}

function Showcase.createShowcase()
    return dsl.vbox {
        config = { padding = 8 },
        children = {
            dsl.text("Sprite UI Showcase", { fontSize = 18, color = "white", shadow = true }),
            dsl.spacer(12),
            
            Showcase.createSpritePanelDemo(),
            dsl.spacer(8),
            
            Showcase.createFixedPaneDemo(),
            dsl.spacer(8),
            
            Showcase.createDecorationsDemo(),
            dsl.spacer(8),
            
            Showcase.createDividerDemo(),
            dsl.spacer(8),
            
            Showcase.createSpriteButtonDemo(),
        }
    }
end

-- Nine-patch panel with test asset (stretches to fit content)
function Showcase.createSpritePanelDemo()
    return dsl.vbox {
        config = { padding = 4 },
        children = {
            dsl.text("Nine-Patch Panel (Stretches)", { fontSize = 14, color = "gold", shadow = true }),
            dsl.spacer(4),
            
            dsl.spritePanel {
                sprite = "ui-decor-test-1.png",
                borders = { 8, 8, 8, 8 },
                minWidth = 180,
                minHeight = 80,
                padding = 12,
                children = {
                    dsl.text("This panel stretches!", { fontSize = 12, color = "white" }),
                    dsl.text("44x27 sprite -> any size", { fontSize = 10, color = "lightgray" })
                }
            }
        }
    }
end

-- Fixed pane - renders at original sprite size
function Showcase.createFixedPaneDemo()
    return dsl.vbox {
        config = { padding = 4 },
        children = {
            dsl.text("Fixed Pane (Original Size)", { fontSize = 14, color = "gold", shadow = true }),
            dsl.spacer(4),
            
            dsl.spritePanel {
                sprite = "fixed-pane-test.png",
                sizing = "fit_sprite",  -- Use original sprite dimensions (130x66)
                padding = 8,
                children = {
                    dsl.text("130x66 fixed", { fontSize = 11, color = "white" })
                }
            }
        }
    }
end

-- Decorations demo with ornate corners and centered gem
function Showcase.createDecorationsDemo()
    return dsl.vbox {
        config = { padding = 4 },
        children = {
            dsl.text("Decorations (Corners + Gem)", { fontSize = 14, color = "gold", shadow = true }),
            dsl.spacer(4),
            
            dsl.spritePanel {
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
                    
                    -- Gem decoration at top center
                    { sprite = "test-gem-ui-decor.png", position = "top_center", offset = { 0, -16 } },
                },
                children = {
                    dsl.text("Ornate corners!", { fontSize = 12, color = "white" }),
                    dsl.text("+ centered gem", { fontSize = 10, color = "cyan" })
                }
            }
        }
    }
end

-- Divider demo - both as panel element and as decoration
function Showcase.createDividerDemo()
    return dsl.vbox {
        config = { padding = 4 },
        children = {
            dsl.text("Dividers", { fontSize = 14, color = "gold", shadow = true }),
            dsl.spacer(4),
            
            dsl.hbox {
                config = { padding = 4 },
                children = {
                    -- Divider as standalone panel element
                    dsl.vbox {
                        config = { padding = 2 },
                        children = {
                            dsl.text("As Panel:", { fontSize = 10, color = "lightgray" }),
                            dsl.spacer(4),
                            dsl.text("Above divider", { fontSize = 10, color = "white" }),
                            dsl.spritePanel {
                                sprite = "test-divider.png",
                                sizing = "fit_sprite",  -- 58x16 original size
                            },
                            dsl.text("Below divider", { fontSize = 10, color = "white" }),
                        }
                    },
                    
                    dsl.spacer(16),
                    
                    -- Divider as decoration on a panel
                    dsl.vbox {
                        config = { padding = 2 },
                        children = {
                            dsl.text("As Decoration:", { fontSize = 10, color = "lightgray" }),
                            dsl.spacer(4),
                            dsl.spritePanel {
                                sprite = "ui-decor-test-2.png",
                                borders = { 6, 6, 6, 6 },
                                minWidth = 80,
                                minHeight = 60,
                                padding = 8,
                                decorations = {
                                    { sprite = "test-divider.png", position = "bottom_center", offset = { 0, 12 } },
                                },
                                children = {
                                    dsl.text("Panel", { fontSize = 10, color = "white" })
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
    return dsl.vbox {
        config = { padding = 4 },
        children = {
            dsl.text("Sprite Buttons (4 States)", { fontSize = 14, color = "gold", shadow = true }),
            dsl.spacer(4),
            
            dsl.hbox {
                config = { padding = 4 },
                children = {
                    dsl.spriteButton {
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
                    dsl.spacer(8),
                    dsl.spriteButton {
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
