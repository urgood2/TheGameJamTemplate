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

--[[
================================================================================
LAYOUT SHOWCASES
================================================================================
Demonstrates layout containers (vbox, hbox, root) with various configuration
options for spacing, padding, alignment, and nested compositions.

VBOX/HBOX CONFIG PROPS:
  spacing    - (number) Gap between children in pixels (default: 0)
  padding    - (number) Inner padding around all children (default: 0)
  color      - (string|Color) Background color (default: transparent)
  align      - (number) Child alignment using AlignmentFlag bitmask
  minWidth   - (number) Minimum container width
  minHeight  - (number) Minimum container height
  id         - (string) Unique identifier for the element

ROOT CONFIG PROPS:
  padding    - (number) Outer padding around content
  color      - (string|Color) Background color
  align      - (number) Content alignment using AlignmentFlag bitmask
  id         - (string) Unique identifier for the root

ALIGNMENT FLAGS (use with bit.bor):
  Horizontal: HORIZONTAL_LEFT (1), HORIZONTAL_CENTER (2), HORIZONTAL_RIGHT (4)
  Vertical: VERTICAL_TOP (8), VERTICAL_CENTER (16), VERTICAL_BOTTOM (32)

Example alignment: bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP)
================================================================================
]]

ShowcaseRegistry._showcases.layouts = {
    order = {
        -- VBox showcases
        "vbox_basic",
        "vbox_spacing",
        "vbox_align_horizontal",
        "vbox_align_vertical",
        "vbox_full_config",
        -- HBox showcases
        "hbox_basic",
        "hbox_spacing",
        "hbox_align_horizontal",
        "hbox_align_vertical",
        "hbox_full_config",
        -- Nested layouts
        "nested_columns",
        "nested_rows",
        "nested_complex",
        "nested_deep",
        -- Root showcases
        "root_basic",
        "root_padding",
        "root_alignment",
        "root_full_config",
    },

    --[[--------------------------------------------------------------------
    VBOX SHOWCASES
    Demonstrates: vertical stacking with spacing and alignment options
    ----------------------------------------------------------------------]]

    vbox_basic = {
        name = "VBox (Basic)",
        description = "Simple vertical stack of elements",
        -- PROPS: children (required), config (optional)
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

    vbox_spacing = {
        name = "VBox Spacing",
        description = "Vertical boxes with different spacing values (0, 4, 8, 16)",
        -- PROPS: spacing controls gap between children
        source = [[
dsl.hbox {
    config = { spacing = 20 },
    children = {
        dsl.vbox {
            config = { spacing = 0, padding = 4, color = "dimgray" },
            children = {
                dsl.text("spacing=0", { fontSize = 10, color = "gold" }),
                dsl.text("A", { color = "white" }),
                dsl.text("B", { color = "white" }),
                dsl.text("C", { color = "white" }),
            }
        },
        dsl.vbox {
            config = { spacing = 4, padding = 4, color = "dimgray" },
            children = {
                dsl.text("spacing=4", { fontSize = 10, color = "gold" }),
                dsl.text("A", { color = "white" }),
                dsl.text("B", { color = "white" }),
                dsl.text("C", { color = "white" }),
            }
        },
        dsl.vbox {
            config = { spacing = 8, padding = 4, color = "dimgray" },
            children = {
                dsl.text("spacing=8", { fontSize = 10, color = "gold" }),
                dsl.text("A", { color = "white" }),
                dsl.text("B", { color = "white" }),
                dsl.text("C", { color = "white" }),
            }
        },
        dsl.vbox {
            config = { spacing = 16, padding = 4, color = "dimgray" },
            children = {
                dsl.text("spacing=16", { fontSize = 10, color = "gold" }),
                dsl.text("A", { color = "white" }),
                dsl.text("B", { color = "white" }),
                dsl.text("C", { color = "white" }),
            }
        },
    }
}]],
        create = function()
            return dsl.hbox {
                config = { spacing = 20 },
                children = {
                    dsl.vbox {
                        config = { spacing = 0, padding = 4, color = "dimgray" },
                        children = {
                            dsl.text("spacing=0", { fontSize = 10, color = "gold" }),
                            dsl.text("A", { color = "white" }),
                            dsl.text("B", { color = "white" }),
                            dsl.text("C", { color = "white" }),
                        }
                    },
                    dsl.vbox {
                        config = { spacing = 4, padding = 4, color = "dimgray" },
                        children = {
                            dsl.text("spacing=4", { fontSize = 10, color = "gold" }),
                            dsl.text("A", { color = "white" }),
                            dsl.text("B", { color = "white" }),
                            dsl.text("C", { color = "white" }),
                        }
                    },
                    dsl.vbox {
                        config = { spacing = 8, padding = 4, color = "dimgray" },
                        children = {
                            dsl.text("spacing=8", { fontSize = 10, color = "gold" }),
                            dsl.text("A", { color = "white" }),
                            dsl.text("B", { color = "white" }),
                            dsl.text("C", { color = "white" }),
                        }
                    },
                    dsl.vbox {
                        config = { spacing = 16, padding = 4, color = "dimgray" },
                        children = {
                            dsl.text("spacing=16", { fontSize = 10, color = "gold" }),
                            dsl.text("A", { color = "white" }),
                            dsl.text("B", { color = "white" }),
                            dsl.text("C", { color = "white" }),
                        }
                    },
                }
            }
        end,
    },

    vbox_align_horizontal = {
        name = "VBox Horizontal Align",
        description = "VBox with left, center, right horizontal alignment",
        -- PROPS: align with HORIZONTAL_* flags
        source = [[
dsl.hbox {
    config = { spacing = 16 },
    children = {
        dsl.vbox {
            config = {
                minWidth = 80, padding = 6, color = "dimgray",
                align = AlignmentFlag.HORIZONTAL_LEFT
            },
            children = {
                dsl.text("LEFT", { fontSize = 10, color = "gold" }),
                dsl.text("Short", { color = "white" }),
                dsl.text("Longer text", { color = "white" }),
            }
        },
        dsl.vbox {
            config = {
                minWidth = 80, padding = 6, color = "dimgray",
                align = AlignmentFlag.HORIZONTAL_CENTER
            },
            children = {
                dsl.text("CENTER", { fontSize = 10, color = "gold" }),
                dsl.text("Short", { color = "white" }),
                dsl.text("Longer text", { color = "white" }),
            }
        },
        dsl.vbox {
            config = {
                minWidth = 80, padding = 6, color = "dimgray",
                align = AlignmentFlag.HORIZONTAL_RIGHT
            },
            children = {
                dsl.text("RIGHT", { fontSize = 10, color = "gold" }),
                dsl.text("Short", { color = "white" }),
                dsl.text("Longer text", { color = "white" }),
            }
        },
    }
}]],
        create = function()
            return dsl.hbox {
                config = { spacing = 16 },
                children = {
                    dsl.vbox {
                        config = {
                            minWidth = 80, padding = 6, color = "dimgray",
                            align = AlignmentFlag.HORIZONTAL_LEFT
                        },
                        children = {
                            dsl.text("LEFT", { fontSize = 10, color = "gold" }),
                            dsl.text("Short", { color = "white" }),
                            dsl.text("Longer text", { color = "white" }),
                        }
                    },
                    dsl.vbox {
                        config = {
                            minWidth = 80, padding = 6, color = "dimgray",
                            align = AlignmentFlag.HORIZONTAL_CENTER
                        },
                        children = {
                            dsl.text("CENTER", { fontSize = 10, color = "gold" }),
                            dsl.text("Short", { color = "white" }),
                            dsl.text("Longer text", { color = "white" }),
                        }
                    },
                    dsl.vbox {
                        config = {
                            minWidth = 80, padding = 6, color = "dimgray",
                            align = AlignmentFlag.HORIZONTAL_RIGHT
                        },
                        children = {
                            dsl.text("RIGHT", { fontSize = 10, color = "gold" }),
                            dsl.text("Short", { color = "white" }),
                            dsl.text("Longer text", { color = "white" }),
                        }
                    },
                }
            }
        end,
    },

    vbox_align_vertical = {
        name = "VBox Vertical Align",
        description = "VBox with top, center, bottom vertical alignment",
        -- PROPS: align with VERTICAL_* flags affects content placement
        source = [[
dsl.hbox {
    config = { spacing = 16 },
    children = {
        dsl.vbox {
            config = {
                minHeight = 80, padding = 6, color = "dimgray",
                align = AlignmentFlag.VERTICAL_TOP
            },
            children = {
                dsl.text("TOP", { fontSize = 10, color = "gold" }),
                dsl.text("Content", { color = "white" }),
            }
        },
        dsl.vbox {
            config = {
                minHeight = 80, padding = 6, color = "dimgray",
                align = AlignmentFlag.VERTICAL_CENTER
            },
            children = {
                dsl.text("CENTER", { fontSize = 10, color = "gold" }),
                dsl.text("Content", { color = "white" }),
            }
        },
        dsl.vbox {
            config = {
                minHeight = 80, padding = 6, color = "dimgray",
                align = AlignmentFlag.VERTICAL_BOTTOM
            },
            children = {
                dsl.text("BOTTOM", { fontSize = 10, color = "gold" }),
                dsl.text("Content", { color = "white" }),
            }
        },
    }
}]],
        create = function()
            return dsl.hbox {
                config = { spacing = 16 },
                children = {
                    dsl.vbox {
                        config = {
                            minHeight = 80, padding = 6, color = "dimgray",
                            align = AlignmentFlag.VERTICAL_TOP
                        },
                        children = {
                            dsl.text("TOP", { fontSize = 10, color = "gold" }),
                            dsl.text("Content", { color = "white" }),
                        }
                    },
                    dsl.vbox {
                        config = {
                            minHeight = 80, padding = 6, color = "dimgray",
                            align = AlignmentFlag.VERTICAL_CENTER
                        },
                        children = {
                            dsl.text("CENTER", { fontSize = 10, color = "gold" }),
                            dsl.text("Content", { color = "white" }),
                        }
                    },
                    dsl.vbox {
                        config = {
                            minHeight = 80, padding = 6, color = "dimgray",
                            align = AlignmentFlag.VERTICAL_BOTTOM
                        },
                        children = {
                            dsl.text("BOTTOM", { fontSize = 10, color = "gold" }),
                            dsl.text("Content", { color = "white" }),
                        }
                    },
                }
            }
        end,
    },

    vbox_full_config = {
        name = "VBox (Full Config)",
        description = "VBox using all available config options",
        -- PROPS: Complete example with spacing, padding, align, color, id
        source = [[
dsl.vbox {
    config = {
        spacing = 8,
        padding = 12,
        color = "darkslategray",
        align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP),
        minWidth = 150,
        id = "styled_vbox"
    },
    children = {
        dsl.text("Header", { fontSize = 16, color = "gold" }),
        dsl.divider("horizontal", { color = "gray" }),
        dsl.text("Body content", { color = "white" }),
        dsl.text("More content", { color = "lightgray" }),
    }
}]],
        create = function()
            return dsl.vbox {
                config = {
                    spacing = 8,
                    padding = 12,
                    color = "darkslategray",
                    align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP),
                    minWidth = 150,
                    id = "styled_vbox"
                },
                children = {
                    dsl.text("Header", { fontSize = 16, color = "gold" }),
                    dsl.divider("horizontal", { color = "gray" }),
                    dsl.text("Body content", { color = "white" }),
                    dsl.text("More content", { color = "lightgray" }),
                }
            }
        end,
    },

    --[[--------------------------------------------------------------------
    HBOX SHOWCASES
    Demonstrates: horizontal row with spacing and alignment options
    ----------------------------------------------------------------------]]

    hbox_basic = {
        name = "HBox (Basic)",
        description = "Simple horizontal row of elements",
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

    hbox_spacing = {
        name = "HBox Spacing",
        description = "Horizontal boxes with different spacing values (0, 8, 16, 24)",
        -- PROPS: spacing controls gap between children
        source = [[
dsl.vbox {
    config = { spacing = 12 },
    children = {
        dsl.vbox {
            children = {
                dsl.text("spacing=0", { fontSize = 10, color = "gold" }),
                dsl.hbox {
                    config = { spacing = 0, padding = 4, color = "dimgray" },
                    children = {
                        dsl.text("A", { color = "white" }),
                        dsl.text("B", { color = "white" }),
                        dsl.text("C", { color = "white" }),
                    }
                },
            }
        },
        dsl.vbox {
            children = {
                dsl.text("spacing=8", { fontSize = 10, color = "gold" }),
                dsl.hbox {
                    config = { spacing = 8, padding = 4, color = "dimgray" },
                    children = {
                        dsl.text("A", { color = "white" }),
                        dsl.text("B", { color = "white" }),
                        dsl.text("C", { color = "white" }),
                    }
                },
            }
        },
        dsl.vbox {
            children = {
                dsl.text("spacing=16", { fontSize = 10, color = "gold" }),
                dsl.hbox {
                    config = { spacing = 16, padding = 4, color = "dimgray" },
                    children = {
                        dsl.text("A", { color = "white" }),
                        dsl.text("B", { color = "white" }),
                        dsl.text("C", { color = "white" }),
                    }
                },
            }
        },
        dsl.vbox {
            children = {
                dsl.text("spacing=24", { fontSize = 10, color = "gold" }),
                dsl.hbox {
                    config = { spacing = 24, padding = 4, color = "dimgray" },
                    children = {
                        dsl.text("A", { color = "white" }),
                        dsl.text("B", { color = "white" }),
                        dsl.text("C", { color = "white" }),
                    }
                },
            }
        },
    }
}]],
        create = function()
            return dsl.vbox {
                config = { spacing = 12 },
                children = {
                    dsl.vbox {
                        children = {
                            dsl.text("spacing=0", { fontSize = 10, color = "gold" }),
                            dsl.hbox {
                                config = { spacing = 0, padding = 4, color = "dimgray" },
                                children = {
                                    dsl.text("A", { color = "white" }),
                                    dsl.text("B", { color = "white" }),
                                    dsl.text("C", { color = "white" }),
                                }
                            },
                        }
                    },
                    dsl.vbox {
                        children = {
                            dsl.text("spacing=8", { fontSize = 10, color = "gold" }),
                            dsl.hbox {
                                config = { spacing = 8, padding = 4, color = "dimgray" },
                                children = {
                                    dsl.text("A", { color = "white" }),
                                    dsl.text("B", { color = "white" }),
                                    dsl.text("C", { color = "white" }),
                                }
                            },
                        }
                    },
                    dsl.vbox {
                        children = {
                            dsl.text("spacing=16", { fontSize = 10, color = "gold" }),
                            dsl.hbox {
                                config = { spacing = 16, padding = 4, color = "dimgray" },
                                children = {
                                    dsl.text("A", { color = "white" }),
                                    dsl.text("B", { color = "white" }),
                                    dsl.text("C", { color = "white" }),
                                }
                            },
                        }
                    },
                    dsl.vbox {
                        children = {
                            dsl.text("spacing=24", { fontSize = 10, color = "gold" }),
                            dsl.hbox {
                                config = { spacing = 24, padding = 4, color = "dimgray" },
                                children = {
                                    dsl.text("A", { color = "white" }),
                                    dsl.text("B", { color = "white" }),
                                    dsl.text("C", { color = "white" }),
                                }
                            },
                        }
                    },
                }
            }
        end,
    },

    hbox_align_horizontal = {
        name = "HBox Horizontal Align",
        description = "HBox with left, center, right horizontal alignment",
        -- PROPS: align with HORIZONTAL_* flags
        source = [[
dsl.vbox {
    config = { spacing = 8 },
    children = {
        dsl.hbox {
            config = {
                minWidth = 200, padding = 6, color = "dimgray",
                align = AlignmentFlag.HORIZONTAL_LEFT
            },
            children = {
                dsl.text("LEFT", { color = "gold" }),
                dsl.text("items", { color = "white" }),
            }
        },
        dsl.hbox {
            config = {
                minWidth = 200, padding = 6, color = "dimgray",
                align = AlignmentFlag.HORIZONTAL_CENTER
            },
            children = {
                dsl.text("CENTER", { color = "gold" }),
                dsl.text("items", { color = "white" }),
            }
        },
        dsl.hbox {
            config = {
                minWidth = 200, padding = 6, color = "dimgray",
                align = AlignmentFlag.HORIZONTAL_RIGHT
            },
            children = {
                dsl.text("RIGHT", { color = "gold" }),
                dsl.text("items", { color = "white" }),
            }
        },
    }
}]],
        create = function()
            return dsl.vbox {
                config = { spacing = 8 },
                children = {
                    dsl.hbox {
                        config = {
                            minWidth = 200, padding = 6, color = "dimgray",
                            align = AlignmentFlag.HORIZONTAL_LEFT
                        },
                        children = {
                            dsl.text("LEFT", { color = "gold" }),
                            dsl.text("items", { color = "white" }),
                        }
                    },
                    dsl.hbox {
                        config = {
                            minWidth = 200, padding = 6, color = "dimgray",
                            align = AlignmentFlag.HORIZONTAL_CENTER
                        },
                        children = {
                            dsl.text("CENTER", { color = "gold" }),
                            dsl.text("items", { color = "white" }),
                        }
                    },
                    dsl.hbox {
                        config = {
                            minWidth = 200, padding = 6, color = "dimgray",
                            align = AlignmentFlag.HORIZONTAL_RIGHT
                        },
                        children = {
                            dsl.text("RIGHT", { color = "gold" }),
                            dsl.text("items", { color = "white" }),
                        }
                    },
                }
            }
        end,
    },

    hbox_align_vertical = {
        name = "HBox Vertical Align",
        description = "HBox with top, center, bottom vertical alignment (mixed heights)",
        -- PROPS: align with VERTICAL_* flags aligns children vertically
        source = [[
dsl.vbox {
    config = { spacing = 8 },
    children = {
        dsl.hbox {
            config = {
                padding = 6, color = "dimgray",
                align = AlignmentFlag.VERTICAL_TOP
            },
            children = {
                dsl.text("TOP", { fontSize = 10, color = "gold" }),
                dsl.text("Small", { fontSize = 12, color = "white" }),
                dsl.text("Large", { fontSize = 20, color = "cyan" }),
            }
        },
        dsl.hbox {
            config = {
                padding = 6, color = "dimgray",
                align = AlignmentFlag.VERTICAL_CENTER
            },
            children = {
                dsl.text("CENTER", { fontSize = 10, color = "gold" }),
                dsl.text("Small", { fontSize = 12, color = "white" }),
                dsl.text("Large", { fontSize = 20, color = "cyan" }),
            }
        },
        dsl.hbox {
            config = {
                padding = 6, color = "dimgray",
                align = AlignmentFlag.VERTICAL_BOTTOM
            },
            children = {
                dsl.text("BOTTOM", { fontSize = 10, color = "gold" }),
                dsl.text("Small", { fontSize = 12, color = "white" }),
                dsl.text("Large", { fontSize = 20, color = "cyan" }),
            }
        },
    }
}]],
        create = function()
            return dsl.vbox {
                config = { spacing = 8 },
                children = {
                    dsl.hbox {
                        config = {
                            padding = 6, color = "dimgray",
                            align = AlignmentFlag.VERTICAL_TOP
                        },
                        children = {
                            dsl.text("TOP", { fontSize = 10, color = "gold" }),
                            dsl.text("Small", { fontSize = 12, color = "white" }),
                            dsl.text("Large", { fontSize = 20, color = "cyan" }),
                        }
                    },
                    dsl.hbox {
                        config = {
                            padding = 6, color = "dimgray",
                            align = AlignmentFlag.VERTICAL_CENTER
                        },
                        children = {
                            dsl.text("CENTER", { fontSize = 10, color = "gold" }),
                            dsl.text("Small", { fontSize = 12, color = "white" }),
                            dsl.text("Large", { fontSize = 20, color = "cyan" }),
                        }
                    },
                    dsl.hbox {
                        config = {
                            padding = 6, color = "dimgray",
                            align = AlignmentFlag.VERTICAL_BOTTOM
                        },
                        children = {
                            dsl.text("BOTTOM", { fontSize = 10, color = "gold" }),
                            dsl.text("Small", { fontSize = 12, color = "white" }),
                            dsl.text("Large", { fontSize = 20, color = "cyan" }),
                        }
                    },
                }
            }
        end,
    },

    hbox_full_config = {
        name = "HBox (Full Config)",
        description = "HBox using all available config options",
        -- PROPS: Complete example with spacing, padding, align, color, id
        source = [[
dsl.hbox {
    config = {
        spacing = 12,
        padding = 10,
        color = "darkslategray",
        align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
        minHeight = 50,
        id = "toolbar_hbox"
    },
    children = {
        dsl.anim("ui-decor-test-1.png", { w = 24, h = 24 }),
        dsl.text("Toolbar Item", { color = "white" }),
        dsl.spacer(20),
        dsl.button("Action", { color = "blue", textColor = "white" }),
    }
}]],
        create = function()
            return dsl.hbox {
                config = {
                    spacing = 12,
                    padding = 10,
                    color = "darkslategray",
                    align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
                    minHeight = 50,
                    id = "toolbar_hbox"
                },
                children = {
                    dsl.anim("ui-decor-test-1.png", { w = 24, h = 24 }),
                    dsl.text("Toolbar Item", { color = "white" }),
                    dsl.spacer(20),
                    dsl.button("Action", { color = "blue", textColor = "white" }),
                }
            }
        end,
    },

    --[[--------------------------------------------------------------------
    NESTED LAYOUT SHOWCASES
    Demonstrates: complex compositions using nested containers
    ----------------------------------------------------------------------]]

    nested_columns = {
        name = "Nested Columns",
        description = "HBox containing VBox columns (common 2-column layout)",
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

    nested_rows = {
        name = "Nested Rows",
        description = "VBox containing HBox rows (common stacked layout)",
        source = [[
dsl.vbox {
    config = { spacing = 8, padding = 8, color = "darkgray" },
    children = {
        dsl.hbox {
            config = { spacing = 10, padding = 4, color = "slategray" },
            children = {
                dsl.text("Row 1:", { color = "gold" }),
                dsl.text("Left", { color = "white" }),
                dsl.text("Right", { color = "white" }),
            }
        },
        dsl.hbox {
            config = { spacing = 10, padding = 4, color = "slategray" },
            children = {
                dsl.text("Row 2:", { color = "gold" }),
                dsl.text("A", { color = "cyan" }),
                dsl.text("B", { color = "cyan" }),
                dsl.text("C", { color = "cyan" }),
            }
        },
        dsl.hbox {
            config = { spacing = 10, padding = 4, color = "slategray" },
            children = {
                dsl.text("Row 3:", { color = "gold" }),
                dsl.button("OK", { color = "green", textColor = "white" }),
            }
        },
    }
}]],
        create = function()
            return dsl.vbox {
                config = { spacing = 8, padding = 8, color = "darkgray" },
                children = {
                    dsl.hbox {
                        config = { spacing = 10, padding = 4, color = "slategray" },
                        children = {
                            dsl.text("Row 1:", { color = "gold" }),
                            dsl.text("Left", { color = "white" }),
                            dsl.text("Right", { color = "white" }),
                        }
                    },
                    dsl.hbox {
                        config = { spacing = 10, padding = 4, color = "slategray" },
                        children = {
                            dsl.text("Row 2:", { color = "gold" }),
                            dsl.text("A", { color = "cyan" }),
                            dsl.text("B", { color = "cyan" }),
                            dsl.text("C", { color = "cyan" }),
                        }
                    },
                    dsl.hbox {
                        config = { spacing = 10, padding = 4, color = "slategray" },
                        children = {
                            dsl.text("Row 3:", { color = "gold" }),
                            dsl.button("OK", { color = "green", textColor = "white" }),
                        }
                    },
                }
            }
        end,
    },

    nested_complex = {
        name = "Nested Complex",
        description = "Sidebar + main content layout (common app structure)",
        source = [[
dsl.hbox {
    config = { spacing = 0 },
    children = {
        -- Sidebar
        dsl.vbox {
            config = { padding = 10, spacing = 6, color = "navy", minWidth = 80 },
            children = {
                dsl.text("Menu", { fontSize = 14, color = "gold" }),
                dsl.divider("horizontal", { color = "gray" }),
                dsl.text("Home", { color = "cyan" }),
                dsl.text("Settings", { color = "white" }),
                dsl.text("Help", { color = "white" }),
            }
        },
        -- Main content
        dsl.vbox {
            config = { padding = 10, spacing = 8, color = "darkgray", minWidth = 150 },
            children = {
                dsl.text("Main Content", { fontSize = 16, color = "gold" }),
                dsl.divider("horizontal", { color = "gray" }),
                dsl.text("Welcome to the app!", { color = "white" }),
                dsl.hbox {
                    config = { spacing = 8 },
                    children = {
                        dsl.button("Save", { color = "green", textColor = "white" }),
                        dsl.button("Cancel", { color = "red", textColor = "white" }),
                    }
                },
            }
        },
    }
}]],
        create = function()
            return dsl.hbox {
                config = { spacing = 0 },
                children = {
                    -- Sidebar
                    dsl.vbox {
                        config = { padding = 10, spacing = 6, color = "navy", minWidth = 80 },
                        children = {
                            dsl.text("Menu", { fontSize = 14, color = "gold" }),
                            dsl.divider("horizontal", { color = "gray" }),
                            dsl.text("Home", { color = "cyan" }),
                            dsl.text("Settings", { color = "white" }),
                            dsl.text("Help", { color = "white" }),
                        }
                    },
                    -- Main content
                    dsl.vbox {
                        config = { padding = 10, spacing = 8, color = "darkgray", minWidth = 150 },
                        children = {
                            dsl.text("Main Content", { fontSize = 16, color = "gold" }),
                            dsl.divider("horizontal", { color = "gray" }),
                            dsl.text("Welcome to the app!", { color = "white" }),
                            dsl.hbox {
                                config = { spacing = 8 },
                                children = {
                                    dsl.button("Save", { color = "green", textColor = "white" }),
                                    dsl.button("Cancel", { color = "red", textColor = "white" }),
                                }
                            },
                        }
                    },
                }
            }
        end,
    },

    nested_deep = {
        name = "Nested Deep",
        description = "Four levels of nesting (root > vbox > hbox > vbox)",
        source = [[
dsl.root {
    config = { padding = 12, color = "darkslategray" },
    children = {
        dsl.vbox {
            config = { spacing = 8 },
            children = {
                dsl.text("Level 1: Root > VBox", { color = "gold" }),
                dsl.hbox {
                    config = { spacing = 12, padding = 8, color = "dimgray" },
                    children = {
                        dsl.text("L2: HBox", { fontSize = 10, color = "cyan" }),
                        dsl.vbox {
                            config = { padding = 6, color = "navy" },
                            children = {
                                dsl.text("L3: VBox", { fontSize = 10, color = "gold" }),
                                dsl.text("Deep content", { color = "white" }),
                            }
                        },
                        dsl.vbox {
                            config = { padding = 6, color = "darkgreen" },
                            children = {
                                dsl.text("L3: VBox", { fontSize = 10, color = "gold" }),
                                dsl.text("More content", { color = "white" }),
                            }
                        },
                    }
                },
            }
        }
    }
}]],
        create = function()
            return dsl.root {
                config = { padding = 12, color = "darkslategray" },
                children = {
                    dsl.vbox {
                        config = { spacing = 8 },
                        children = {
                            dsl.text("Level 1: Root > VBox", { color = "gold" }),
                            dsl.hbox {
                                config = { spacing = 12, padding = 8, color = "dimgray" },
                                children = {
                                    dsl.text("L2: HBox", { fontSize = 10, color = "cyan" }),
                                    dsl.vbox {
                                        config = { padding = 6, color = "navy" },
                                        children = {
                                            dsl.text("L3: VBox", { fontSize = 10, color = "gold" }),
                                            dsl.text("Deep content", { color = "white" }),
                                        }
                                    },
                                    dsl.vbox {
                                        config = { padding = 6, color = "darkgreen" },
                                        children = {
                                            dsl.text("L3: VBox", { fontSize = 10, color = "gold" }),
                                            dsl.text("More content", { color = "white" }),
                                        }
                                    },
                                }
                            },
                        }
                    }
                }
            }
        end,
    },

    --[[--------------------------------------------------------------------
    ROOT SHOWCASES
    Demonstrates: top-level container with various config options
    ----------------------------------------------------------------------]]

    root_basic = {
        name = "Root (Basic)",
        description = "Minimal root container",
        source = [[
dsl.root {
    children = {
        dsl.text("Simple root container", { color = "white" })
    }
}]],
        create = function()
            return dsl.root {
                children = {
                    dsl.text("Simple root container", { color = "white" })
                }
            }
        end,
    },

    root_padding = {
        name = "Root Padding",
        description = "Root containers with different padding values",
        source = [[
dsl.hbox {
    config = { spacing = 16 },
    children = {
        dsl.vbox {
            children = {
                dsl.text("padding=0", { fontSize = 10, color = "gold" }),
                dsl.root {
                    config = { padding = 0, color = "dimgray" },
                    children = { dsl.text("Content", { color = "white" }) }
                }
            }
        },
        dsl.vbox {
            children = {
                dsl.text("padding=8", { fontSize = 10, color = "gold" }),
                dsl.root {
                    config = { padding = 8, color = "dimgray" },
                    children = { dsl.text("Content", { color = "white" }) }
                }
            }
        },
        dsl.vbox {
            children = {
                dsl.text("padding=16", { fontSize = 10, color = "gold" }),
                dsl.root {
                    config = { padding = 16, color = "dimgray" },
                    children = { dsl.text("Content", { color = "white" }) }
                }
            }
        },
    }
}]],
        create = function()
            return dsl.hbox {
                config = { spacing = 16 },
                children = {
                    dsl.vbox {
                        children = {
                            dsl.text("padding=0", { fontSize = 10, color = "gold" }),
                            dsl.root {
                                config = { padding = 0, color = "dimgray" },
                                children = { dsl.text("Content", { color = "white" }) }
                            }
                        }
                    },
                    dsl.vbox {
                        children = {
                            dsl.text("padding=8", { fontSize = 10, color = "gold" }),
                            dsl.root {
                                config = { padding = 8, color = "dimgray" },
                                children = { dsl.text("Content", { color = "white" }) }
                            }
                        }
                    },
                    dsl.vbox {
                        children = {
                            dsl.text("padding=16", { fontSize = 10, color = "gold" }),
                            dsl.root {
                                config = { padding = 16, color = "dimgray" },
                                children = { dsl.text("Content", { color = "white" }) }
                            }
                        }
                    },
                }
            }
        end,
    },

    root_alignment = {
        name = "Root Alignment",
        description = "Root with different alignment options",
        source = [[
dsl.hbox {
    config = { spacing = 12 },
    children = {
        dsl.root {
            config = {
                padding = 8, color = "dimgray",
                minWidth = 100, minHeight = 60,
                align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP)
            },
            children = { dsl.text("Top-Left", { fontSize = 10, color = "white" }) }
        },
        dsl.root {
            config = {
                padding = 8, color = "dimgray",
                minWidth = 100, minHeight = 60,
                align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
            },
            children = { dsl.text("Center", { fontSize = 10, color = "white" }) }
        },
        dsl.root {
            config = {
                padding = 8, color = "dimgray",
                minWidth = 100, minHeight = 60,
                align = bit.bor(AlignmentFlag.HORIZONTAL_RIGHT, AlignmentFlag.VERTICAL_BOTTOM)
            },
            children = { dsl.text("Bottom-Right", { fontSize = 10, color = "white" }) }
        },
    }
}]],
        create = function()
            return dsl.hbox {
                config = { spacing = 12 },
                children = {
                    dsl.root {
                        config = {
                            padding = 8, color = "dimgray",
                            minWidth = 100, minHeight = 60,
                            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP)
                        },
                        children = { dsl.text("Top-Left", { fontSize = 10, color = "white" }) }
                    },
                    dsl.root {
                        config = {
                            padding = 8, color = "dimgray",
                            minWidth = 100, minHeight = 60,
                            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
                        },
                        children = { dsl.text("Center", { fontSize = 10, color = "white" }) }
                    },
                    dsl.root {
                        config = {
                            padding = 8, color = "dimgray",
                            minWidth = 100, minHeight = 60,
                            align = bit.bor(AlignmentFlag.HORIZONTAL_RIGHT, AlignmentFlag.VERTICAL_BOTTOM)
                        },
                        children = { dsl.text("Bottom-Right", { fontSize = 10, color = "white" }) }
                    },
                }
            }
        end,
    },

    root_full_config = {
        name = "Root (Full Config)",
        description = "Root container with all config options",
        source = [[
dsl.root {
    config = {
        padding = 16,
        color = "darkslategray",
        align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP),
        minWidth = 200,
        id = "main_root"
    },
    children = {
        dsl.vbox {
            config = { spacing = 8 },
            children = {
                dsl.text("Full Root Config", { fontSize = 18, color = "gold" }),
                dsl.divider("horizontal", { color = "gray" }),
                dsl.text("padding: 16", { color = "lightgray" }),
                dsl.text("color: darkslategray", { color = "lightgray" }),
                dsl.text("align: center-top", { color = "lightgray" }),
                dsl.text("minWidth: 200", { color = "lightgray" }),
            }
        }
    }
}]],
        create = function()
            return dsl.root {
                config = {
                    padding = 16,
                    color = "darkslategray",
                    align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_TOP),
                    minWidth = 200,
                    id = "main_root"
                },
                children = {
                    dsl.vbox {
                        config = { spacing = 8 },
                        children = {
                            dsl.text("Full Root Config", { fontSize = 18, color = "gold" }),
                            dsl.divider("horizontal", { color = "gray" }),
                            dsl.text("padding: 16", { color = "lightgray" }),
                            dsl.text("color: darkslategray", { color = "lightgray" }),
                            dsl.text("align: center-top", { color = "lightgray" }),
                            dsl.text("minWidth: 200", { color = "lightgray" }),
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

--[[
================================================================================
PATTERN SHOWCASES
================================================================================
Demonstrates common UI patterns that can be copied and adapted for real use.
Patterns combine primitives and layouts into reusable, proven solutions.

TOOLTIP PATTERN:
  Displays contextual information on hover. Structure:
  - Title (header)
  - Description (body text)
  - Stats grid (optional)
  - Tag pills (optional)

MODAL/DIALOG PATTERN:
  Overlays that capture focus. Structure:
  - Backdrop (semi-transparent)
  - Modal box (centered)
  - Header with close button
  - Content area
  - Action buttons

INVENTORY GRID PATTERN:
  Grid of interactive slots. Structure:
  - Container with grid layout
  - Slots with borders
  - Item icons in slots
  - Empty slot indicators

BUTTON WITH ICON PATTERN:
  Buttons that combine icon + label for clear actions.

PANEL WITH DECORATIONS PATTERN:
  Sprite panels with corner badges, icons, or other decorative elements.
================================================================================
]]

ShowcaseRegistry._showcases.patterns = {
    order = {
        -- Basic patterns
        "button_basic",
        "button_icon_label",
        "sprite_panel",
        "sprite_button",
        -- Complex patterns
        "tooltip_pattern",
        "modal_dialog",
        "inventory_grid",
        "panel_with_decorations",
        "form_layout",
        "card_layout",
    },

    --[[--------------------------------------------------------------------
    BUTTON SHOWCASES
    Demonstrates: basic buttons and icon+label buttons
    ----------------------------------------------------------------------]]

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

    button_icon_label = {
        name = "Button with Icon + Label",
        description = "Button combining icon and text for clear, visual actions",
        -- PATTERN: Icon + text in horizontal container with button styling
        source = [[
-- Button with icon and label (common action button pattern)
dsl.hbox {
    config = {
        padding = 8,
        spacing = 6,
        color = "blue",
        hover = true,
        canCollide = true,
        emboss = 2,
        buttonCallback = function() print("Save clicked!") end,
        align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
    },
    children = {
        dsl.anim("test-gem-ui-decor.png", { w = 20, h = 20, shadow = false }),
        dsl.text("Save Game", { fontSize = 14, color = "white", shadow = true }),
    }
}

-- Multiple icon buttons in a row:
dsl.hbox {
    config = { spacing = 8 },
    children = {
        -- Play button
        dsl.hbox {
            config = { padding = 6, color = "green", hover = true, canCollide = true, emboss = 2 },
            children = {
                dsl.anim("ui-decor-test-1.png", { w = 16, h = 16, shadow = false }),
                dsl.text("Play", { fontSize = 12, color = "white" }),
            }
        },
        -- Settings button
        dsl.hbox {
            config = { padding = 6, color = "gray", hover = true, canCollide = true, emboss = 2 },
            children = {
                dsl.anim("ui-decor-test-1.png", { w = 16, h = 16, shadow = false }),
                dsl.text("Settings", { fontSize = 12, color = "white" }),
            }
        },
    }
}]],
        create = function()
            return dsl.vbox {
                config = { spacing = 12 },
                children = {
                    -- Single icon+label button
                    dsl.hbox {
                        config = {
                            padding = 8,
                            spacing = 6,
                            color = "blue",
                            hover = true,
                            canCollide = true,
                            emboss = 2,
                            buttonCallback = function() print("Save clicked!") end,
                            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
                        },
                        children = {
                            dsl.anim("test-gem-ui-decor.png", { w = 20, h = 20, shadow = false }),
                            dsl.text("Save Game", { fontSize = 14, color = "white", shadow = true }),
                        }
                    },
                    -- Row of icon buttons
                    dsl.hbox {
                        config = { spacing = 8 },
                        children = {
                            dsl.hbox {
                                config = { padding = 6, color = "green", hover = true, canCollide = true, emboss = 2 },
                                children = {
                                    dsl.anim("ui-decor-test-1.png", { w = 16, h = 16, shadow = false }),
                                    dsl.text("Play", { fontSize = 12, color = "white" }),
                                }
                            },
                            dsl.hbox {
                                config = { padding = 6, color = "gray", hover = true, canCollide = true, emboss = 2 },
                                children = {
                                    dsl.anim("ui-decor-test-1.png", { w = 16, h = 16, shadow = false }),
                                    dsl.text("Settings", { fontSize = 12, color = "white" }),
                                }
                            },
                        }
                    },
                }
            }
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

    --[[--------------------------------------------------------------------
    TOOLTIP PATTERN
    Demonstrates: standard tooltip structure with title, body, stats, tags
    Reference: ui/tooltip_v2.lua for production implementation
    ----------------------------------------------------------------------]]

    tooltip_pattern = {
        name = "Tooltip Pattern",
        description = "Contextual info panel with title, description, stats, and tags",
        -- PATTERN: 3-box vertical stack - Name, Description, Info
        source = [[
-- Tooltip pattern: 3-box vertical stack
-- Box 1: Title (larger font, distinct background)
-- Box 2: Description (body text)
-- Box 3: Info (stats + tags)

dsl.vbox {
    config = { spacing = 4 },
    children = {
        -- Box 1: Title
        dsl.vbox {
            config = { padding = 6, color = "navy", minWidth = 180 },
            children = {
                dsl.text("Fireball", { fontSize = 14, color = "gold", shadow = true })
            }
        },
        -- Box 2: Description
        dsl.vbox {
            config = { padding = 8, color = "darkslategray", minWidth = 180 },
            children = {
                dsl.text("Deal 25 fire damage to target enemy.", {
                    fontSize = 11, color = "white"
                })
            }
        },
        -- Box 3: Stats + Tags
        dsl.vbox {
            config = { padding = 6, spacing = 4, color = "dimgray", minWidth = 180 },
            children = {
                -- Stats row
                dsl.hbox {
                    config = { spacing = 16 },
                    children = {
                        dsl.hbox {
                            children = {
                                dsl.text("Damage: ", { fontSize = 10, color = "lightgray" }),
                                dsl.text("25", { fontSize = 10, color = "red" }),
                            }
                        },
                        dsl.hbox {
                            children = {
                                dsl.text("Mana: ", { fontSize = 10, color = "lightgray" }),
                                dsl.text("12", { fontSize = 10, color = "cyan" }),
                            }
                        },
                    }
                },
                -- Tags row
                dsl.hbox {
                    config = { spacing = 4 },
                    children = {
                        dsl.vbox {
                            config = { padding = 2, color = "firebrick" },
                            children = { dsl.text("Fire", { fontSize = 9, color = "white" }) }
                        },
                        dsl.vbox {
                            config = { padding = 2, color = "steelblue" },
                            children = { dsl.text("Projectile", { fontSize = 9, color = "white" }) }
                        },
                    }
                },
            }
        },
    }
}]],
        create = function()
            return dsl.vbox {
                config = { spacing = 4 },
                children = {
                    -- Box 1: Title
                    dsl.vbox {
                        config = { padding = 6, color = "navy", minWidth = 180 },
                        children = {
                            dsl.text("Fireball", { fontSize = 14, color = "gold", shadow = true })
                        }
                    },
                    -- Box 2: Description
                    dsl.vbox {
                        config = { padding = 8, color = "darkslategray", minWidth = 180 },
                        children = {
                            dsl.text("Deal 25 fire damage to target enemy.", {
                                fontSize = 11, color = "white"
                            })
                        }
                    },
                    -- Box 3: Stats + Tags
                    dsl.vbox {
                        config = { padding = 6, spacing = 4, color = "dimgray", minWidth = 180 },
                        children = {
                            -- Stats row
                            dsl.hbox {
                                config = { spacing = 16 },
                                children = {
                                    dsl.hbox {
                                        children = {
                                            dsl.text("Damage: ", { fontSize = 10, color = "lightgray" }),
                                            dsl.text("25", { fontSize = 10, color = "red" }),
                                        }
                                    },
                                    dsl.hbox {
                                        children = {
                                            dsl.text("Mana: ", { fontSize = 10, color = "lightgray" }),
                                            dsl.text("12", { fontSize = 10, color = "cyan" }),
                                        }
                                    },
                                }
                            },
                            -- Tags row
                            dsl.hbox {
                                config = { spacing = 4 },
                                children = {
                                    dsl.vbox {
                                        config = { padding = 2, color = "firebrick" },
                                        children = { dsl.text("Fire", { fontSize = 9, color = "white" }) }
                                    },
                                    dsl.vbox {
                                        config = { padding = 2, color = "steelblue" },
                                        children = { dsl.text("Projectile", { fontSize = 9, color = "white" }) }
                                    },
                                }
                            },
                        }
                    },
                }
            }
        end,
    },

    --[[--------------------------------------------------------------------
    MODAL/DIALOG PATTERN
    Demonstrates: centered modal box with header, content, and actions
    Reference: ui/patch_notes_modal.lua for production implementation
    ----------------------------------------------------------------------]]

    modal_dialog = {
        name = "Modal/Dialog Pattern",
        description = "Centered dialog with header, content, close button, and actions",
        -- PATTERN: Layered structure - backdrop, modal container, header with X, content, buttons
        source = [[
-- Modal dialog pattern
-- Structure: Modal box with header (title + close), content, action buttons
-- Note: Backdrop handling is done at spawn time (separate entity)

dsl.vbox {
    config = { padding = 0, color = "darkslategray", minWidth = 250 },
    children = {
        -- Header with title and close button
        dsl.hbox {
            config = {
                padding = 8,
                color = "slategray",
                align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER)
            },
            children = {
                dsl.text("Confirm Action", { fontSize = 14, color = "white", shadow = true }),
                dsl.spacer(40),
                -- Close button (X)
                dsl.vbox {
                    config = {
                        padding = 4,
                        color = "red",
                        hover = true,
                        canCollide = true,
                        buttonCallback = function() print("Close clicked") end
                    },
                    children = { dsl.text("X", { fontSize = 12, color = "white" }) }
                },
            }
        },
        -- Content area
        dsl.vbox {
            config = { padding = 16, spacing = 8 },
            children = {
                dsl.text("Are you sure you want to", { fontSize = 12, color = "white" }),
                dsl.text("delete this item?", { fontSize = 12, color = "white" }),
                dsl.spacer(10, 8),
            }
        },
        -- Action buttons
        dsl.hbox {
            config = { padding = 10, spacing = 8, color = "dimgray" },
            children = {
                dsl.button("Delete", {
                    color = "red",
                    textColor = "white",
                    onClick = function() print("Delete confirmed") end
                }),
                dsl.button("Cancel", {
                    color = "gray",
                    textColor = "white",
                    onClick = function() print("Cancelled") end
                }),
            }
        },
    }
}]],
        create = function()
            return dsl.vbox {
                config = { padding = 0, color = "darkslategray", minWidth = 250 },
                children = {
                    -- Header with title and close button
                    dsl.hbox {
                        config = {
                            padding = 8,
                            color = "slategray",
                            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER)
                        },
                        children = {
                            dsl.text("Confirm Action", { fontSize = 14, color = "white", shadow = true }),
                            dsl.spacer(40),
                            -- Close button (X)
                            dsl.vbox {
                                config = {
                                    padding = 4,
                                    color = "red",
                                    hover = true,
                                    canCollide = true,
                                    buttonCallback = function() print("Close clicked") end
                                },
                                children = { dsl.text("X", { fontSize = 12, color = "white" }) }
                            },
                        }
                    },
                    -- Content area
                    dsl.vbox {
                        config = { padding = 16, spacing = 8 },
                        children = {
                            dsl.text("Are you sure you want to", { fontSize = 12, color = "white" }),
                            dsl.text("delete this item?", { fontSize = 12, color = "white" }),
                            dsl.spacer(10, 8),
                        }
                    },
                    -- Action buttons
                    dsl.hbox {
                        config = { padding = 10, spacing = 8, color = "dimgray" },
                        children = {
                            dsl.button("Delete", {
                                color = "red",
                                textColor = "white",
                                onClick = function() print("Delete confirmed") end
                            }),
                            dsl.button("Cancel", {
                                color = "gray",
                                textColor = "white",
                                onClick = function() print("Cancelled") end
                            }),
                        }
                    },
                }
            }
        end,
    },

    --[[--------------------------------------------------------------------
    INVENTORY GRID PATTERN
    Demonstrates: grid of interactive slots for item management
    Reference: ui/inventory_grid_init.lua for production implementation
    ----------------------------------------------------------------------]]

    inventory_grid = {
        name = "Inventory Grid Pattern",
        description = "Grid of slots for items with empty/filled states",
        -- PATTERN: Grid layout with uniform slot styling and item icons
        source = [[
-- Inventory grid pattern (3x3 example)
-- Each slot: colored box with border, optional item icon
-- Use dsl.grid() for data-driven generation

-- Manual construction (for control):
dsl.vbox {
    config = { padding = 8, spacing = 4, color = "darkslategray" },
    children = {
        dsl.text("Inventory", { fontSize = 14, color = "gold" }),
        dsl.spacer(10, 4),
        -- Grid rows
        dsl.hbox {
            config = { spacing = 4 },
            children = {
                -- Slot with item
                dsl.vbox {
                    config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                    children = { dsl.anim("test-gem-ui-decor.png", { w = 36, h = 36 }) }
                },
                -- Empty slot
                dsl.vbox {
                    config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                    children = {}
                },
                -- Slot with item
                dsl.vbox {
                    config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                    children = { dsl.anim("ui-decor-test-1.png", { w = 36, h = 36 }) }
                },
            }
        },
        dsl.hbox {
            config = { spacing = 4 },
            children = {
                dsl.vbox {
                    config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                    children = {}
                },
                dsl.vbox {
                    config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                    children = { dsl.anim("test-gem-ui-decor.png", { w = 36, h = 36 }) }
                },
                dsl.vbox {
                    config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                    children = {}
                },
            }
        },
        dsl.hbox {
            config = { spacing = 4 },
            children = {
                dsl.vbox {
                    config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                    children = { dsl.anim("ui-decor-test-1.png", { w = 36, h = 36 }) }
                },
                dsl.vbox {
                    config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                    children = {}
                },
                dsl.vbox {
                    config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                    children = { dsl.anim("test-gem-ui-decor.png", { w = 36, h = 36 }) }
                },
            }
        },
    }
}

-- Using dsl.grid() helper for generation:
dsl.vbox {
    config = { padding = 8, color = "darkslategray" },
    children = dsl.grid(3, 3, function(row, col)
        -- Generate slot content based on row/col
        local hasItem = (row + col) % 2 == 0
        return dsl.vbox {
            config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
            children = hasItem and { dsl.anim("test-gem-ui-decor.png", { w = 36, h = 36 }) } or {}
        }
    end)
}]],
        create = function()
            return dsl.vbox {
                config = { padding = 8, spacing = 4, color = "darkslategray" },
                children = {
                    dsl.text("Inventory", { fontSize = 14, color = "gold" }),
                    dsl.spacer(10, 4),
                    -- Grid rows
                    dsl.hbox {
                        config = { spacing = 4 },
                        children = {
                            -- Slot with item
                            dsl.vbox {
                                config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                                children = { dsl.anim("test-gem-ui-decor.png", { w = 36, h = 36 }) }
                            },
                            -- Empty slot
                            dsl.vbox {
                                config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                                children = {}
                            },
                            -- Slot with item
                            dsl.vbox {
                                config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                                children = { dsl.anim("ui-decor-test-1.png", { w = 36, h = 36 }) }
                            },
                        }
                    },
                    dsl.hbox {
                        config = { spacing = 4 },
                        children = {
                            dsl.vbox {
                                config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                                children = {}
                            },
                            dsl.vbox {
                                config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                                children = { dsl.anim("test-gem-ui-decor.png", { w = 36, h = 36 }) }
                            },
                            dsl.vbox {
                                config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                                children = {}
                            },
                        }
                    },
                    dsl.hbox {
                        config = { spacing = 4 },
                        children = {
                            dsl.vbox {
                                config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                                children = { dsl.anim("ui-decor-test-1.png", { w = 36, h = 36 }) }
                            },
                            dsl.vbox {
                                config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                                children = {}
                            },
                            dsl.vbox {
                                config = { padding = 4, color = "dimgray", minWidth = 48, minHeight = 48, emboss = 1 },
                                children = { dsl.anim("test-gem-ui-decor.png", { w = 36, h = 36 }) }
                            },
                        }
                    },
                }
            }
        end,
    },

    --[[--------------------------------------------------------------------
    PANEL WITH DECORATIONS PATTERN
    Demonstrates: sprite panel with corner badges and decorative elements
    Reference: docs/api/sprite-panels.md for full documentation
    ----------------------------------------------------------------------]]

    panel_with_decorations = {
        name = "Panel with Decorations",
        description = "Sprite panel with corner badges, icons, and decorative overlays",
        -- PATTERN: spritePanel with decorations array
        source = [[
-- Panel with decorations pattern
-- decorations: array of {sprite, position, offset, scale, rotation, flip, opacity, tint}
-- positions: top_left, top_center, top_right, middle_left, center, middle_right,
--            bottom_left, bottom_center, bottom_right

dsl.spritePanel {
    sprite = "ui-decor-test-1.png",
    borders = { 8, 8, 8, 8 },
    minWidth = 200,
    padding = 16,
    decorations = {
        -- Top left corner gem
        {
            sprite = "test-gem-ui-decor.png",
            position = "top_left",
            offset = { -8, -8 }
        },
        -- Top right corner gem
        {
            sprite = "test-gem-ui-decor.png",
            position = "top_right",
            offset = { 8, -8 }
        },
        -- Bottom center decoration
        {
            sprite = "ui-decor-test-1.png",
            position = "bottom_center",
            offset = { 0, 4 },
            scale = { 0.5, 0.5 }
        },
    },
    children = {
        dsl.vbox {
            config = { spacing = 4 },
            children = {
                dsl.text("Decorated Panel", { fontSize = 14, color = "gold", shadow = true }),
                dsl.text("Corner gems and bottom decoration", { fontSize = 10, color = "lightgray" }),
            }
        }
    }
}

-- Alternative: Manual decoration (without spritePanel)
dsl.vbox {
    config = { padding = 12, color = "darkslategray" },
    children = {
        -- Content with badge overlay (stacked)
        dsl.hbox {
            children = {
                dsl.vbox {
                    config = { padding = 8, color = "dimgray", minWidth = 120 },
                    children = {
                        dsl.text("Item Card", { fontSize = 12, color = "white" }),
                        dsl.anim("ui-decor-test-1.png", { w = 48, h = 48 }),
                    }
                },
                -- Notification badge (offset to corner)
                dsl.vbox {
                    config = {
                        padding = 4,
                        color = "red",
                        -- Use negative margin to overlay
                    },
                    children = { dsl.text("3", { fontSize = 10, color = "white" }) }
                },
            }
        },
    }
}]],
        create = function()
            return dsl.vbox {
                config = { spacing = 16 },
                children = {
                    -- Sprite panel with decorations (if spritePanel supports it)
                    dsl.spritePanel {
                        sprite = "ui-decor-test-1.png",
                        borders = { 8, 8, 8, 8 },
                        minWidth = 200,
                        padding = 16,
                        decorations = {
                            {
                                sprite = "test-gem-ui-decor.png",
                                position = "top_left",
                                offset = { -8, -8 }
                            },
                            {
                                sprite = "test-gem-ui-decor.png",
                                position = "top_right",
                                offset = { 8, -8 }
                            },
                            {
                                sprite = "ui-decor-test-1.png",
                                position = "bottom_center",
                                offset = { 0, 4 },
                                scale = { 0.5, 0.5 }
                            },
                        },
                        children = {
                            dsl.vbox {
                                config = { spacing = 4 },
                                children = {
                                    dsl.text("Decorated Panel", { fontSize = 14, color = "gold", shadow = true }),
                                    dsl.text("Corner gems and bottom decoration", { fontSize = 10, color = "lightgray" }),
                                }
                            }
                        }
                    },
                    -- Manual badge overlay example
                    dsl.vbox {
                        config = { padding = 8, color = "darkslategray" },
                        children = {
                            dsl.text("Manual Badge Overlay", { fontSize = 12, color = "gold" }),
                            dsl.hbox {
                                children = {
                                    dsl.vbox {
                                        config = { padding = 8, color = "dimgray", minWidth = 100 },
                                        children = {
                                            dsl.text("Item", { fontSize = 11, color = "white" }),
                                            dsl.anim("ui-decor-test-1.png", { w = 40, h = 40 }),
                                        }
                                    },
                                    -- Badge in adjacent container
                                    dsl.vbox {
                                        config = { padding = 3, color = "red" },
                                        children = { dsl.text("5", { fontSize = 10, color = "white" }) }
                                    },
                                }
                            },
                        }
                    },
                }
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
