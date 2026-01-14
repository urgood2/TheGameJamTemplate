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

--[[
================================================================================
PRIMITIVE SHOWCASES
================================================================================
Demonstrates individual UI primitive components with documentation of all
available properties (props).

TEXT PROPS:
  text       - (string) The text content to display
  fontSize   - (number) Font size in pixels (default: engine default)
  fontName   - (string) Font family name (default: engine default)
  color      - (string|Color) Text color (named color or Color object)
  shadow     - (bool) Enable drop shadow (default: false)
  align      - (number) Alignment flags via bit.bor(AlignmentFlag.*, ...)
               Horizontal: HORIZONTAL_LEFT, HORIZONTAL_CENTER, HORIZONTAL_RIGHT
               Vertical: VERTICAL_TOP, VERTICAL_CENTER, VERTICAL_BOTTOM
  onClick    - (function) Click callback, makes text interactive
  tooltip    - (table) Tooltip configuration
  hover      - (table) Hover state configuration
  id         - (string) Unique identifier for the element

ANIM/IMAGE PROPS:
  id         - (string) Sprite filename or animation id
  w, h       - (number) Width and height in pixels
  shadow     - (bool) Enable shadow under sprite (default: true)
  isAnimation - (bool) If true, treat id as existing animation id

  Post-creation manipulation via animation_system:
  animation_system.setSpeed(entity, speed)  -- Animation playback speed
  animation_system.setFGColorForAllAnimationObjects(entity, r, g, b, a) -- Tint

SPACER PROPS:
  w          - (number) Width in pixels (default: 10)
  h          - (number) Height in pixels (default: w or 10)
  Note: Creates invisible RECT_SHAPE with transparent color

DIVIDER PROPS:
  direction  - (string) "horizontal" or "vertical"
  color      - (string|Color) Line color
  thickness  - (number) Line thickness in pixels (default: 1)
  length     - (number) Line length in pixels (for vertical, default: 20)
================================================================================
]]

ShowcaseRegistry._showcases.primitives = {
    order = {
        "text_basic",
        "text_sizes",
        "text_colors",
        "text_alignments",
        "text_styled",
        "image_basic",
        "image_sizing",
        "image_tinting",
        "anim_basic",
        "anim_speed",
        "spacer_horizontal",
        "spacer_vertical",
        "spacer_combined",
        "divider",
        "icon_label",
    },

    --[[--------------------------------------------------------------------
    TEXT SHOWCASES
    Demonstrates: various sizes, colors, alignments, and styling options
    ----------------------------------------------------------------------]]

    text_basic = {
        name = "Text (Basic)",
        description = "Simple text label with default styling",
        -- PROPS: text (required), all others optional
        source = [[
dsl.text("Hello World")]],
        create = function()
            return dsl.text("Hello World")
        end,
    },

    text_sizes = {
        name = "Text Sizes",
        description = "Text at various font sizes (12px to 32px)",
        -- PROPS: fontSize controls the rendered size
        source = [[
dsl.vbox {
    config = { spacing = 4 },
    children = {
        dsl.text("Size 12", { fontSize = 12, color = "white" }),
        dsl.text("Size 16", { fontSize = 16, color = "white" }),
        dsl.text("Size 20", { fontSize = 20, color = "white" }),
        dsl.text("Size 24", { fontSize = 24, color = "white" }),
        dsl.text("Size 32", { fontSize = 32, color = "white" }),
    }
}]],
        create = function()
            return dsl.vbox {
                config = { spacing = 4 },
                children = {
                    dsl.text("Size 12", { fontSize = 12, color = "white" }),
                    dsl.text("Size 16", { fontSize = 16, color = "white" }),
                    dsl.text("Size 20", { fontSize = 20, color = "white" }),
                    dsl.text("Size 24", { fontSize = 24, color = "white" }),
                    dsl.text("Size 32", { fontSize = 32, color = "white" }),
                }
            }
        end,
    },

    text_colors = {
        name = "Text Colors",
        description = "Text with various named colors",
        -- PROPS: color accepts named colors (red, gold, cyan, etc.) or Color objects
        source = [[
dsl.vbox {
    config = { spacing = 4 },
    children = {
        dsl.text("White text", { color = "white" }),
        dsl.text("Gold text", { color = "gold" }),
        dsl.text("Red text", { color = "red" }),
        dsl.text("Green text", { color = "green" }),
        dsl.text("Cyan text", { color = "cyan" }),
        dsl.text("Purple text", { color = "purple" }),
    }
}]],
        create = function()
            return dsl.vbox {
                config = { spacing = 4 },
                children = {
                    dsl.text("White text", { color = "white" }),
                    dsl.text("Gold text", { color = "gold" }),
                    dsl.text("Red text", { color = "red" }),
                    dsl.text("Green text", { color = "green" }),
                    dsl.text("Cyan text", { color = "cyan" }),
                    dsl.text("Purple text", { color = "purple" }),
                }
            }
        end,
    },

    text_alignments = {
        name = "Text Alignments",
        description = "Text with different horizontal alignments",
        -- PROPS: align uses bit.bor with AlignmentFlag constants
        -- HORIZONTAL_LEFT=1, HORIZONTAL_CENTER=2, HORIZONTAL_RIGHT=4
        -- VERTICAL_TOP=8, VERTICAL_CENTER=16, VERTICAL_BOTTOM=32
        source = [[
dsl.vbox {
    config = { minWidth = 200, color = "darkgray", padding = 8 },
    children = {
        dsl.text("Left aligned", {
            color = "white",
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER)
        }),
        dsl.text("Center aligned", {
            color = "gold",
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
        }),
        dsl.text("Right aligned", {
            color = "cyan",
            align = bit.bor(AlignmentFlag.HORIZONTAL_RIGHT, AlignmentFlag.VERTICAL_CENTER)
        }),
    }
}]],
        create = function()
            return dsl.vbox {
                config = { minWidth = 200, color = "darkgray", padding = 8 },
                children = {
                    dsl.text("Left aligned", {
                        color = "white",
                        align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER)
                    }),
                    dsl.text("Center aligned", {
                        color = "gold",
                        align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
                    }),
                    dsl.text("Right aligned", {
                        color = "cyan",
                        align = bit.bor(AlignmentFlag.HORIZONTAL_RIGHT, AlignmentFlag.VERTICAL_CENTER)
                    }),
                }
            }
        end,
    },

    text_styled = {
        name = "Text (Full Styling)",
        description = "Text with fontSize, color, shadow, and alignment combined",
        -- PROPS: Combining multiple style properties
        source = [[
dsl.text("Styled Text", {
    fontSize = 24,
    color = "gold",
    shadow = true,
    align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
})]],
        create = function()
            return dsl.text("Styled Text", {
                fontSize = 24,
                color = "gold",
                shadow = true,
                align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
            })
        end,
    },

    --[[--------------------------------------------------------------------
    IMAGE/ANIM SHOWCASES
    Demonstrates: sizing, tinting, and animation speed control
    Note: dsl.anim() is used for both static images and animations
    ----------------------------------------------------------------------]]

    image_basic = {
        name = "Image (Basic)",
        description = "Display a static sprite/image",
        -- PROPS: id (sprite filename), w, h (dimensions)
        source = [[
dsl.anim("ui-decor-test-1.png", {
    w = 48,
    h = 48
})]],
        create = function()
            return dsl.anim("ui-decor-test-1.png", {
                w = 48,
                h = 48
            })
        end,
    },

    image_sizing = {
        name = "Image Sizing",
        description = "Same image at different sizes",
        -- PROPS: w, h control rendered dimensions (maintains aspect by default)
        source = [[
dsl.hbox {
    config = { spacing = 8 },
    children = {
        dsl.anim("ui-decor-test-1.png", { w = 24, h = 24 }),
        dsl.anim("ui-decor-test-1.png", { w = 48, h = 48 }),
        dsl.anim("ui-decor-test-1.png", { w = 72, h = 72 }),
    }
}]],
        create = function()
            return dsl.hbox {
                config = { spacing = 8 },
                children = {
                    dsl.anim("ui-decor-test-1.png", { w = 24, h = 24 }),
                    dsl.anim("ui-decor-test-1.png", { w = 48, h = 48 }),
                    dsl.anim("ui-decor-test-1.png", { w = 72, h = 72 }),
                }
            }
        end,
    },

    image_tinting = {
        name = "Image Tinting",
        description = "Images with color tint applied via animation_system",
        -- PROPS: Tinting is applied post-creation using animation_system
        -- animation_system.setFGColorForAllAnimationObjects(entity, r, g, b, a)
        source = [[
-- Create image then apply tint:
local img = dsl.anim("ui-decor-test-1.png", { w = 48, h = 48 })
-- After spawning, call:
-- animation_system.setFGColorForAllAnimationObjects(entity, 255, 0, 0, 255)

-- Example shows labeled tinted images:
dsl.hbox {
    config = { spacing = 8 },
    children = {
        dsl.vbox { children = {
            dsl.anim("ui-decor-test-1.png", { w = 48, h = 48 }),
            dsl.text("Normal", { fontSize = 10, color = "white" })
        }},
        dsl.vbox { children = {
            dsl.anim("ui-decor-test-1.png", { w = 48, h = 48 }),  -- tint red
            dsl.text("Red tint", { fontSize = 10, color = "red" })
        }},
        dsl.vbox { children = {
            dsl.anim("ui-decor-test-1.png", { w = 48, h = 48 }),  -- tint blue
            dsl.text("Blue tint", { fontSize = 10, color = "cyan" })
        }},
    }
}]],
        create = function()
            -- Note: Actual tinting requires animation_system call on spawned entity
            -- This showcase demonstrates the visual layout
            return dsl.hbox {
                config = { spacing = 8 },
                children = {
                    dsl.vbox { children = {
                        dsl.anim("ui-decor-test-1.png", { w = 48, h = 48 }),
                        dsl.text("Normal", { fontSize = 10, color = "white" })
                    }},
                    dsl.vbox { children = {
                        dsl.anim("ui-decor-test-1.png", { w = 48, h = 48 }),
                        dsl.text("Red tint*", { fontSize = 10, color = "red" })
                    }},
                    dsl.vbox { children = {
                        dsl.anim("ui-decor-test-1.png", { w = 48, h = 48 }),
                        dsl.text("Blue tint*", { fontSize = 10, color = "cyan" })
                    }},
                }
            }
        end,
    },

    anim_basic = {
        name = "Animation (Basic)",
        description = "Display an animated sprite",
        -- PROPS: isAnimation=true treats id as animation id, not sprite filename
        source = [[
-- For static sprites (most common):
dsl.anim("sprite.png", { w = 48, h = 48 })

-- For pre-registered animations:
dsl.anim("my_animation_id", {
    w = 48,
    h = 48,
    isAnimation = true  -- Use existing animation id
})]],
        create = function()
            return dsl.anim("ui-decor-test-1.png", {
                w = 48,
                h = 48
            })
        end,
    },

    anim_speed = {
        name = "Animation Speed",
        description = "Control animation playback speed (requires post-spawn call)",
        -- PROPS: Speed is controlled via animation_system.setSpeed(entity, speed)
        -- speed < 1.0 = slower, speed > 1.0 = faster
        source = [[
-- Animation speed is set AFTER spawning:
local entity = dsl.spawn({ x = 100, y = 100 }, dsl.anim("walk.png", { w = 48, h = 48 }))

-- Set playback speed (1.0 = normal, 0.5 = half speed, 2.0 = double)
animation_system.setSpeed(entity, 0.5)   -- Slow animation
animation_system.setSpeed(entity, 1.0)   -- Normal speed
animation_system.setSpeed(entity, 2.0)   -- Fast animation

-- Other animation controls:
animation_system.play(entity)            -- Start playing
animation_system.pause(entity)           -- Pause playback
animation_system.stop(entity)            -- Stop and reset
animation_system.seekFrame(entity, 0)    -- Jump to frame
animation_system.setDirection(entity, -1) -- Reverse playback]],
        create = function()
            return dsl.vbox {
                children = {
                    dsl.anim("ui-decor-test-1.png", { w = 48, h = 48 }),
                    dsl.text("Speed control via animation_system", { fontSize = 10, color = "lightgray" }),
                }
            }
        end,
    },

    --[[--------------------------------------------------------------------
    SPACER SHOWCASES
    Demonstrates: horizontal gaps, vertical gaps, and combined usage
    ----------------------------------------------------------------------]]

    spacer_horizontal = {
        name = "Spacer (Horizontal)",
        description = "Create horizontal gaps in hbox layouts",
        -- PROPS: dsl.spacer(w) creates gap of w pixels width
        source = [[
dsl.hbox {
    children = {
        dsl.text("Left", { color = "cyan" }),
        dsl.spacer(40),  -- 40px horizontal gap
        dsl.text("Right", { color = "gold" }),
    }
}]],
        create = function()
            return dsl.hbox {
                children = {
                    dsl.text("Left", { color = "cyan" }),
                    dsl.spacer(40),
                    dsl.text("Right", { color = "gold" }),
                }
            }
        end,
    },

    spacer_vertical = {
        name = "Spacer (Vertical)",
        description = "Create vertical gaps in vbox layouts",
        -- PROPS: dsl.spacer(w, h) - in vbox, h determines vertical gap
        source = [[
dsl.vbox {
    children = {
        dsl.text("Top", { color = "cyan" }),
        dsl.spacer(10, 40),  -- 40px vertical gap
        dsl.text("Bottom", { color = "gold" }),
    }
}]],
        create = function()
            return dsl.vbox {
                children = {
                    dsl.text("Top", { color = "cyan" }),
                    dsl.spacer(10, 40),
                    dsl.text("Bottom", { color = "gold" }),
                }
            }
        end,
    },

    spacer_combined = {
        name = "Spacer (Layout Control)",
        description = "Using spacers to control complex layouts",
        -- PROPS: Spacers are invisible RECT_SHAPE elements
        -- Useful for: margins, gaps between elements, pushing elements apart
        source = [[
dsl.vbox {
    config = { padding = 10, color = "darkgray" },
    children = {
        dsl.text("Header", { fontSize = 16, color = "gold" }),
        dsl.spacer(10, 8),  -- Gap after header
        dsl.hbox {
            children = {
                dsl.text("Item 1", { color = "white" }),
                dsl.spacer(30),   -- Push items apart
                dsl.text("Item 2", { color = "white" }),
                dsl.spacer(30),
                dsl.text("Item 3", { color = "white" }),
            }
        },
        dsl.spacer(10, 16), -- Large gap before footer
        dsl.text("Footer", { fontSize = 12, color = "lightgray" }),
    }
}]],
        create = function()
            return dsl.vbox {
                config = { padding = 10, color = "darkgray" },
                children = {
                    dsl.text("Header", { fontSize = 16, color = "gold" }),
                    dsl.spacer(10, 8),
                    dsl.hbox {
                        children = {
                            dsl.text("Item 1", { color = "white" }),
                            dsl.spacer(30),
                            dsl.text("Item 2", { color = "white" }),
                            dsl.spacer(30),
                            dsl.text("Item 3", { color = "white" }),
                        }
                    },
                    dsl.spacer(10, 16),
                    dsl.text("Footer", { fontSize = 12, color = "lightgray" }),
                }
            }
        end,
    },

    --[[--------------------------------------------------------------------
    DIVIDER SHOWCASE
    ----------------------------------------------------------------------]]

    divider = {
        name = "Divider",
        description = "Horizontal and vertical line separators",
        -- PROPS: direction ("horizontal"|"vertical"), color, thickness, length
        source = [[
dsl.vbox {
    config = { spacing = 8 },
    children = {
        dsl.text("Section 1", { color = "white" }),
        dsl.divider("horizontal", { color = "gray", thickness = 1 }),
        dsl.text("Section 2", { color = "white" }),
        dsl.divider("horizontal", { color = "gold", thickness = 2 }),
        dsl.text("Section 3", { color = "white" }),
    }
}]],
        create = function()
            return dsl.vbox {
                config = { spacing = 8 },
                children = {
                    dsl.text("Section 1", { color = "white" }),
                    dsl.divider("horizontal", { color = "gray", thickness = 1 }),
                    dsl.text("Section 2", { color = "white" }),
                    dsl.divider("horizontal", { color = "gold", thickness = 2 }),
                    dsl.text("Section 3", { color = "white" }),
                }
            }
        end,
    },

    --[[--------------------------------------------------------------------
    ICON + LABEL SHOWCASE
    ----------------------------------------------------------------------]]

    icon_label = {
        name = "Icon + Label",
        description = "Icon with text label side by side",
        -- PROPS: iconId, label, iconSize, fontSize, textColor, shadow
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
