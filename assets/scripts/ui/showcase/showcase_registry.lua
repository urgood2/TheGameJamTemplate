--[[
================================================================================
SHOWCASE REGISTRY - Categorized UI Component Examples
================================================================================
Central registry for all UI showcase examples, organized by category.
Used by the Gallery Viewer to browse and display UI examples.

Categories:
- primitives: Basic elements (text, spacer, divider, anim)
- layouts: Container layouts (vbox, hbox, root, nested)
- patterns: Common UI patterns (forms, cards, tooltips)

Usage:
local registry = require("ui.showcase.showcase_registry")

-- Get all categories
local categories = registry.getCategories()

-- Get showcases in a category
local showcases = registry.getShowcases("primitives")

-- Get a specific showcase
local showcase = registry.getShowcase("primitives", "text_basic")
================================================================================
]]

local dsl = require("ui.ui_syntax_sugar")

local ShowcaseRegistry = {
    _showcases = {},
    _categoryOrder = { "primitives", "layouts", "patterns" },
}

--------------------------------------------------------------------------------
-- Category: Primitives
--------------------------------------------------------------------------------

ShowcaseRegistry._showcases.primitives = {
    order = { "text_basic", "text_styled", "spacer", "divider", "anim_sprite", "icon_label" },

    text_basic = {
        name = "Text (Basic)",
        description = "Simple text label with default styling",
        source = [[
dsl.text("Hello World")]],
        create = function()
            return dsl.text("Hello World")
        end,
    },

    text_styled = {
        name = "Text (Styled)",
        description = "Text with custom font size, color, and shadow",
        source = [[
dsl.text("Styled Text", {
    fontSize = 20,
    color = "gold",
    shadow = true
})]],
        create = function()
            return dsl.text("Styled Text", {
                fontSize = 20,
                color = "gold",
                shadow = true
            })
        end,
    },

    spacer = {
        name = "Spacer",
        description = "Empty space for layout control",
        source = [[
dsl.vbox {
    children = {
        dsl.text("Above spacer", { color = "white" }),
        dsl.spacer(30),
        dsl.text("Below spacer (30px gap)", { color = "white" })
    }
}]],
        create = function()
            return dsl.vbox {
                children = {
                    dsl.text("Above spacer", { color = "white" }),
                    dsl.spacer(30),
                    dsl.text("Below spacer (30px gap)", { color = "white" })
                }
            }
        end,
    },

    divider = {
        name = "Divider",
        description = "Horizontal or vertical line separator",
        source = [[
dsl.vbox {
    children = {
        dsl.text("Section 1", { color = "white" }),
        dsl.divider("horizontal", { color = "gray" }),
        dsl.text("Section 2", { color = "white" })
    }
}]],
        create = function()
            return dsl.vbox {
                children = {
                    dsl.text("Section 1", { color = "white" }),
                    dsl.divider("horizontal", { color = "gray" }),
                    dsl.text("Section 2", { color = "white" })
                }
            }
        end,
    },

    anim_sprite = {
        name = "Animation/Sprite",
        description = "Display a sprite or animation",
        source = [[
dsl.anim("player_icon.png", {
    w = 48,
    h = 48
})]],
        create = function()
            -- Use a test sprite that should exist
            return dsl.anim("ui-decor-test-1.png", {
                w = 48,
                h = 48
            })
        end,
    },

    icon_label = {
        name = "Icon + Label",
        description = "Icon with text label side by side",
        source = [[
dsl.iconLabel("coin.png", "100 Gold", {
    iconSize = 20,
    fontSize = 14,
    textColor = "gold"
})]],
        create = function()
            return dsl.iconLabel("test-gem-ui-decor.png", "100 Gold", {
                iconSize = 20,
                fontSize = 14,
                textColor = "gold"
            })
        end,
    },
}

--------------------------------------------------------------------------------
-- Category: Layouts
--------------------------------------------------------------------------------

ShowcaseRegistry._showcases.layouts = {
    order = { "vbox_basic", "hbox_basic", "vbox_styled", "nested_layout", "root_container" },

    vbox_basic = {
        name = "VBox (Basic)",
        description = "Vertical stack of elements",
        source = [[
dsl.vbox {
    children = {
        dsl.text("Line 1", { color = "white" }),
        dsl.text("Line 2", { color = "white" }),
        dsl.text("Line 3", { color = "white" })
    }
}]],
        create = function()
            return dsl.vbox {
                children = {
                    dsl.text("Line 1", { color = "white" }),
                    dsl.text("Line 2", { color = "white" }),
                    dsl.text("Line 3", { color = "white" })
                }
            }
        end,
    },

    hbox_basic = {
        name = "HBox (Basic)",
        description = "Horizontal row of elements",
        source = [[
dsl.hbox {
    children = {
        dsl.text("Left", { color = "cyan" }),
        dsl.spacer(20),
        dsl.text("Center", { color = "gold" }),
        dsl.spacer(20),
        dsl.text("Right", { color = "cyan" })
    }
}]],
        create = function()
            return dsl.hbox {
                children = {
                    dsl.text("Left", { color = "cyan" }),
                    dsl.spacer(20),
                    dsl.text("Center", { color = "gold" }),
                    dsl.spacer(20),
                    dsl.text("Right", { color = "cyan" })
                }
            }
        end,
    },

    vbox_styled = {
        name = "VBox (Styled)",
        description = "Vertical box with padding, spacing, and background",
        source = [[
dsl.vbox {
    config = {
        padding = 12,
        spacing = 8,
        color = "darkgray"
    },
    children = {
        dsl.text("Header", { fontSize = 16, color = "gold" }),
        dsl.text("Content line 1", { color = "white" }),
        dsl.text("Content line 2", { color = "white" })
    }
}]],
        create = function()
            return dsl.vbox {
                config = {
                    padding = 12,
                    spacing = 8,
                    color = "darkgray"
                },
                children = {
                    dsl.text("Header", { fontSize = 16, color = "gold" }),
                    dsl.text("Content line 1", { color = "white" }),
                    dsl.text("Content line 2", { color = "white" })
                }
            }
        end,
    },

    nested_layout = {
        name = "Nested Layout",
        description = "HBox containing VBox columns",
        source = [[
dsl.hbox {
    config = { spacing = 16 },
    children = {
        dsl.vbox {
            config = { padding = 8, color = "navy" },
            children = {
                dsl.text("Column A", { color = "gold" }),
                dsl.text("Item 1", { color = "white" }),
                dsl.text("Item 2", { color = "white" })
            }
        },
        dsl.vbox {
            config = { padding = 8, color = "darkgreen" },
            children = {
                dsl.text("Column B", { color = "gold" }),
                dsl.text("Item X", { color = "white" }),
                dsl.text("Item Y", { color = "white" })
            }
        }
    }
}]],
        create = function()
            return dsl.hbox {
                config = { spacing = 16 },
                children = {
                    dsl.vbox {
                        config = { padding = 8, color = "navy" },
                        children = {
                            dsl.text("Column A", { color = "gold" }),
                            dsl.text("Item 1", { color = "white" }),
                            dsl.text("Item 2", { color = "white" })
                        }
                    },
                    dsl.vbox {
                        config = { padding = 8, color = "darkgreen" },
                        children = {
                            dsl.text("Column B", { color = "gold" }),
                            dsl.text("Item X", { color = "white" }),
                            dsl.text("Item Y", { color = "white" })
                        }
                    }
                }
            }
        end,
    },

    root_container = {
        name = "Root Container",
        description = "Top-level container with config",
        source = [[
dsl.root {
    config = { padding = 16, color = "darkslategray" },
    children = {
        dsl.vbox {
            children = {
                dsl.text("Root Container", { fontSize = 18, color = "white" }),
                dsl.text("With padding and background", { color = "lightgray" })
            }
        }
    }
}]],
        create = function()
            return dsl.root {
                config = { padding = 16, color = "darkslategray" },
                children = {
                    dsl.vbox {
                        children = {
                            dsl.text("Root Container", { fontSize = 18, color = "white" }),
                            dsl.text("With padding and background", { color = "lightgray" })
                        }
                    }
                }
            }
        end,
    },
}

--------------------------------------------------------------------------------
-- Category: Patterns
--------------------------------------------------------------------------------

ShowcaseRegistry._showcases.patterns = {
    order = { "button_basic", "sprite_panel", "sprite_button", "form_layout", "card_layout" },

    button_basic = {
        name = "Button (Basic)",
        description = "Clickable button with callback",
        source = [[
dsl.button("Click Me", {
    onClick = function()
        print("Button clicked!")
    end,
    color = "blue",
    textColor = "white",
    emboss = 2
})]],
        create = function()
            return dsl.button("Click Me", {
                onClick = function()
                    print("Button clicked!")
                end,
                color = "blue",
                textColor = "white",
                emboss = 2
            })
        end,
    },

    sprite_panel = {
        name = "Sprite Panel",
        description = "Nine-patch panel that stretches to fit content",
        source = [[
dsl.spritePanel {
    sprite = "ui-decor-test-1.png",
    borders = { 8, 8, 8, 8 },
    minWidth = 150,
    padding = 12,
    children = {
        dsl.text("Panel Content", { color = "white" })
    }
}]],
        create = function()
            return dsl.spritePanel {
                sprite = "ui-decor-test-1.png",
                borders = { 8, 8, 8, 8 },
                minWidth = 150,
                padding = 12,
                children = {
                    dsl.text("Panel Content", { color = "white" })
                }
            }
        end,
    },

    sprite_button = {
        name = "Sprite Button",
        description = "Button with 4 visual states (normal/hover/pressed/disabled)",
        source = [[
dsl.spriteButton {
    states = {
        normal = "button-test-normal.png",
        hover = "button-test-hover.png",
        pressed = "button-test-pressed.png",
        disabled = "button-test-disabled.png"
    },
    borders = { 6, 6, 6, 6 },
    label = "Sprite Btn",
    onClick = function()
        print("Sprite button clicked!")
    end
}]],
        create = function()
            return dsl.spriteButton {
                states = {
                    normal = "button-test-normal.png",
                    hover = "button-test-hover.png",
                    pressed = "button-test-pressed.png",
                    disabled = "button-test-disabled.png"
                },
                borders = { 6, 6, 6, 6 },
                label = "Sprite Btn",
                onClick = function()
                    print("Sprite button clicked!")
                end
            }
        end,
    },

    form_layout = {
        name = "Form Layout",
        description = "Common form pattern with labels and buttons",
        source = [[
dsl.vbox {
    config = { padding = 12, spacing = 8, color = "darkgray" },
    children = {
        dsl.text("Settings", { fontSize = 16, color = "gold", shadow = true }),
        dsl.divider("horizontal"),
        dsl.hbox {
            children = {
                dsl.text("Volume:", { color = "white" }),
                dsl.spacer(20),
                dsl.text("100%", { color = "cyan" })
            }
        },
        dsl.hbox {
            children = {
                dsl.text("Music:", { color = "white" }),
                dsl.spacer(20),
                dsl.text("ON", { color = "green" })
            }
        },
        dsl.spacer(8),
        dsl.hbox {
            children = {
                dsl.button("Save", { color = "green", textColor = "white" }),
                dsl.spacer(8),
                dsl.button("Cancel", { color = "red", textColor = "white" })
            }
        }
    }
}]],
        create = function()
            return dsl.vbox {
                config = { padding = 12, spacing = 8, color = "darkgray" },
                children = {
                    dsl.text("Settings", { fontSize = 16, color = "gold", shadow = true }),
                    dsl.divider("horizontal"),
                    dsl.hbox {
                        children = {
                            dsl.text("Volume:", { color = "white" }),
                            dsl.spacer(20),
                            dsl.text("100%", { color = "cyan" })
                        }
                    },
                    dsl.hbox {
                        children = {
                            dsl.text("Music:", { color = "white" }),
                            dsl.spacer(20),
                            dsl.text("ON", { color = "green" })
                        }
                    },
                    dsl.spacer(8),
                    dsl.hbox {
                        children = {
                            dsl.button("Save", { color = "green", textColor = "white" }),
                            dsl.spacer(8),
                            dsl.button("Cancel", { color = "red", textColor = "white" })
                        }
                    }
                }
            }
        end,
    },

    card_layout = {
        name = "Card Layout",
        description = "Card-like UI with header, content, and footer",
        source = [[
dsl.vbox {
    config = { padding = 0, color = "darkslategray" },
    children = {
        -- Header
        dsl.vbox {
            config = { padding = 10, color = "slategray" },
            children = {
                dsl.text("Card Title", { fontSize = 16, color = "white", shadow = true })
            }
        },
        -- Content
        dsl.vbox {
            config = { padding = 12 },
            children = {
                dsl.text("This is the card body.", { color = "lightgray" }),
                dsl.text("It can contain any content.", { color = "lightgray" })
            }
        },
        -- Footer
        dsl.hbox {
            config = { padding = 8, color = "dimgray" },
            children = {
                dsl.button("Action", { color = "blue", textColor = "white" })
            }
        }
    }
}]],
        create = function()
            return dsl.vbox {
                config = { padding = 0, color = "darkslategray" },
                children = {
                    -- Header
                    dsl.vbox {
                        config = { padding = 10, color = "slategray" },
                        children = {
                            dsl.text("Card Title", { fontSize = 16, color = "white", shadow = true })
                        }
                    },
                    -- Content
                    dsl.vbox {
                        config = { padding = 12 },
                        children = {
                            dsl.text("This is the card body.", { color = "lightgray" }),
                            dsl.text("It can contain any content.", { color = "lightgray" })
                        }
                    },
                    -- Footer
                    dsl.hbox {
                        config = { padding = 8, color = "dimgray" },
                        children = {
                            dsl.button("Action", { color = "blue", textColor = "white" })
                        }
                    }
                }
            }
        end,
    },
}

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Get list of category names in display order
---@return string[] List of category names
function ShowcaseRegistry.getCategories()
    return ShowcaseRegistry._categoryOrder
end

--- Get category display name
---@param categoryId string Category identifier
---@return string Display name for the category
function ShowcaseRegistry.getCategoryName(categoryId)
    local names = {
        primitives = "Primitives",
        layouts = "Layouts",
        patterns = "Patterns",
    }
    return names[categoryId] or categoryId
end

--- Get all showcases in a category
---@param categoryId string Category identifier
---@return table[] Array of showcase definitions in order
function ShowcaseRegistry.getShowcases(categoryId)
    local category = ShowcaseRegistry._showcases[categoryId]
    if not category then return {} end

    local result = {}
    for _, id in ipairs(category.order or {}) do
        if category[id] then
            local showcase = category[id]
            showcase.id = id
            showcase.category = categoryId
            result[#result + 1] = showcase
        end
    end
    return result
end

--- Get a specific showcase by category and id
---@param categoryId string Category identifier
---@param showcaseId string Showcase identifier
---@return table|nil Showcase definition or nil if not found
function ShowcaseRegistry.getShowcase(categoryId, showcaseId)
    local category = ShowcaseRegistry._showcases[categoryId]
    if not category then return nil end

    local showcase = category[showcaseId]
    if showcase then
        showcase.id = showcaseId
        showcase.category = categoryId
    end
    return showcase
end

--- Get total count of showcases
---@return number Total number of showcases across all categories
function ShowcaseRegistry.getTotalCount()
    local count = 0
    for _, categoryId in ipairs(ShowcaseRegistry._categoryOrder) do
        local showcases = ShowcaseRegistry.getShowcases(categoryId)
        count = count + #showcases
    end
    return count
end

--- Get flat list of all showcases for navigation
---@return table[] Array of {category, showcase} pairs in order
function ShowcaseRegistry.getFlatList()
    local result = {}
    for _, categoryId in ipairs(ShowcaseRegistry._categoryOrder) do
        for _, showcase in ipairs(ShowcaseRegistry.getShowcases(categoryId)) do
            result[#result + 1] = {
                category = categoryId,
                showcase = showcase,
            }
        end
    end
    return result
end

return ShowcaseRegistry
