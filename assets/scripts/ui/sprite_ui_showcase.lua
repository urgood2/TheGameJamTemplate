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
            
            Showcase.createSizingModesDemo(),
            dsl.spacer(8),
            
            Showcase.createDecorationsDemo(),
            dsl.spacer(8),
            
            Showcase.createSpriteButtonDemo(),
        }
    }
end

function Showcase.createSpritePanelDemo()
    return dsl.vbox {
        config = { padding = 4 },
        children = {
            dsl.text("Nine-Patch Panel (Inline Definition)", { fontSize = 14, color = "gold", shadow = true }),
            dsl.spacer(4),
            
            dsl.spritePanel {
                sprite = "rounded_rect.png",
                borders = { 8, 8, 8, 8 },
                minWidth = 150,
                minHeight = 60,
                padding = 8,
                children = {
                    dsl.text("No JSON required!", { fontSize = 12, color = "white" })
                }
            }
        }
    }
end

function Showcase.createSizingModesDemo()
    return dsl.vbox {
        config = { padding = 4 },
        children = {
            dsl.text("Sizing Modes", { fontSize = 14, color = "gold", shadow = true }),
            dsl.spacer(4),
            
            dsl.hbox {
                config = { padding = 4 },
                children = {
                    dsl.vbox {
                        config = { padding = 2 },
                        children = {
                            dsl.text("fit_content", { fontSize = 10, color = "lightgray" }),
                            dsl.spritePanel {
                                sprite = "rounded_rect.png",
                                borders = { 8, 8, 8, 8 },
                                sizing = "fit_content",
                                minWidth = 80,
                                minHeight = 40,
                                padding = 4,
                                children = {
                                    dsl.text("Grows", { fontSize = 10, color = "white" })
                                }
                            }
                        }
                    },
                    dsl.spacer(8),
                    dsl.vbox {
                        config = { padding = 2 },
                        children = {
                            dsl.text("fit_sprite", { fontSize = 10, color = "lightgray" }),
                            dsl.spritePanel {
                                sprite = "rounded_rect.png",
                                borders = { 8, 8, 8, 8 },
                                sizing = "fit_sprite",
                                children = {
                                    dsl.text("Fixed", { fontSize = 10, color = "white" })
                                }
                            }
                        }
                    }
                }
            }
        }
    }
end

function Showcase.createDecorationsDemo()
    return dsl.vbox {
        config = { padding = 4 },
        children = {
            dsl.text("Decorations (Overlays)", { fontSize = 14, color = "gold", shadow = true }),
            dsl.spacer(4),
            
            dsl.spritePanel {
                sprite = "rounded_rect.png",
                borders = { 8, 8, 8, 8 },
                minWidth = 180,
                minHeight = 80,
                padding = 8,
                decorations = {
                    { sprite = "rounded_rect_small.png", position = "top_left", offset = { -4, -4 } },
                    { sprite = "rounded_rect_small.png", position = "top_right", offset = { 4, -4 } },
                    { sprite = "rounded_rect_small.png", position = "bottom_left", offset = { -4, 4 } },
                    { sprite = "rounded_rect_small.png", position = "bottom_right", offset = { 4, 4 } },
                },
                children = {
                    dsl.text("Corner flourishes!", { fontSize = 12, color = "white" })
                }
            }
        }
    }
end

function Showcase.createSpriteButtonDemo()
    return dsl.vbox {
        config = { padding = 4 },
        children = {
            dsl.text("Sprite Buttons", { fontSize = 14, color = "gold", shadow = true }),
            dsl.spacer(4),
            
            dsl.hbox {
                config = { padding = 4 },
                children = {
                    dsl.spriteButton {
                        sprite = "rounded_rect_small",
                        label = "Auto States",
                        onClick = function()
                            print("Button clicked!")
                        end
                    },
                    dsl.spacer(8),
                    dsl.spriteButton {
                        states = {
                            normal = "rounded_rect.png",
                            hover = "rounded_rect.png",
                            pressed = "rounded_rect_small.png",
                            disabled = "rounded_rect.png"
                        },
                        borders = { 8, 8, 8, 8 },
                        label = "Manual States",
                        onClick = function()
                            print("Manual button clicked!")
                        end
                    }
                }
            }
        }
    }
end

return Showcase
