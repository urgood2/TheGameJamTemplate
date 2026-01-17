--[[
================================================================================
UI FILLER DEMO - Comprehensive Feature Showcase
================================================================================
Demonstrates ALL UI filler capabilities with staggered display and labels.
Each feature is shown individually with its name and code example.

Usage:
    local UIFillerDemo = require("demos.ui_filler_demo")
    UIFillerDemo.start()    -- Start the demo
    UIFillerDemo.stop()     -- Stop and cleanup

Environment variables:
    RUN_UI_FILLER_DEMO=1    -- Auto-start demo in main menu
    AUTO_EXIT_AFTER_DEMO=1  -- Exit after demo completes
]]

local UIFillerDemo = {}

local dsl = require("ui.ui_syntax_sugar")
local timer = require("core.timer")

-- Demo state
local _active = false
local _timers = {}
local _demoTag = "ui_filler_demo"
local _currentDemo = 0
local _demoQueue = {}
local _spawnedBoxes = {}  -- Track spawned UI boxes for cleanup
local _originalMenuY = nil  -- Store original menu position for restore

--------------------------------------------------------------------------------
-- MAIN MENU REPOSITIONING
-- Move the main menu down when demo is active to avoid overlap
--------------------------------------------------------------------------------

local function getMainMenuEntity()
    -- Access the mainMenuEntities global from main.lua
    if mainMenuEntities and mainMenuEntities.main_menu_uibox then
        return mainMenuEntities.main_menu_uibox
    end
    return nil
end

local function moveMainMenuDown()
    local menuEntity = getMainMenuEntity()
    if not menuEntity then return end

    local transform = component_cache and component_cache.get(menuEntity, Transform)
    if not transform then return end

    -- Store original Y position for restoration
    _originalMenuY = transform.actualY

    -- Move menu to bottom area of screen (demo panel height ~400 + padding)
    local screenHeight = globals and globals.screenHeight and globals.screenHeight() or 1080
    local newY = screenHeight - 180  -- Place near bottom with some margin
    transform.actualY = newY

    print(string.format("[UIFillerDemo] Moved main menu from Y=%d to Y=%d", _originalMenuY, newY))
end

local function restoreMainMenuPosition()
    if not _originalMenuY then return end

    local menuEntity = getMainMenuEntity()
    if not menuEntity then return end

    local transform = component_cache and component_cache.get(menuEntity, Transform)
    if not transform then return end

    transform.actualY = _originalMenuY
    print(string.format("[UIFillerDemo] Restored main menu to Y=%d", _originalMenuY))
    _originalMenuY = nil
end

-- Screen helpers
local function screenW()
    return globals and globals.screenWidth and globals.screenWidth() or 1920
end

local function screenH()
    return globals and globals.screenHeight and globals.screenHeight() or 1080
end

-- Color palette for visual distinction
local colors = {
    panel = { r = 40, g = 45, b = 55, a = 240 },
    header = { r = 60, g = 65, b = 80, a = 255 },
    filler_visual = { r = 80, g = 120, b = 200, a = 180 },  -- Blue for filler areas
    content = { r = 100, g = 180, b = 100, a = 255 },        -- Green for content
    label = { r = 200, g = 200, b = 200, a = 255 },
    gold = { r = 255, g = 215, b = 0, a = 255 },
    silver = { r = 192, g = 192, b = 192, a = 255 },
    red = { r = 255, g = 100, b = 100, a = 255 },
    cyan = { r = 100, g = 200, b = 255, a = 255 },
}

--------------------------------------------------------------------------------
-- HELPER: Create a visible filler representation
-- Since fillers are invisible, we wrap them with a visual indicator
--------------------------------------------------------------------------------

local function visualFiller(opts)
    opts = opts or {}
    local flexWeight = opts.flex or 1
    local maxFill = opts.maxFill or 0

    -- Create a colored box that contains a filler
    -- The box will expand to match the filler's computed size
    return dsl.vbox {
        config = {
            background = colors.filler_visual,
            minHeight = opts.height or 40,
            padding = 4,
        },
        children = {
            dsl.text(
                maxFill > 0
                    and string.format("filler (flex=%d, max=%d)", flexWeight, maxFill)
                    or string.format("filler (flex=%d)", flexWeight),
                { fontSize = 12, color = "white" }
            ),
            dsl.filler(opts),
        }
    }
end

-- Simple content block (green, for visibility)
-- Uses container alignment to center text within the block
local function contentBlock(label, width, height)
    return dsl.vbox {
        config = {
            background = colors.content,
            minWidth = width or 80,
            minHeight = height or 40,
            padding = 8,
            -- Center children both horizontally and vertically within the block
            align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
        },
        children = {
            dsl.text(label, { fontSize = 14, color = "white" })
        }
    }
end

-- Label text
local function labelText(text, opts)
    opts = opts or {}
    return dsl.text(text, {
        fontSize = opts.fontSize or 16,
        color = opts.color or colors.silver,
    })
end

-- Code example text (smaller, mono-like)
local function codeText(text)
    return dsl.text(text, {
        fontSize = 12,
        color = colors.cyan,
    })
end

--------------------------------------------------------------------------------
-- CLEANUP UTILITY
--------------------------------------------------------------------------------

local function cleanupSpawnedBoxes()
    for _, boxId in ipairs(_spawnedBoxes) do
        if registry and registry:valid(boxId) then
            pcall(function() dsl.remove(boxId) end)
        end
    end
    _spawnedBoxes = {}
end

local function trackBox(boxId)
    table.insert(_spawnedBoxes, boxId)
    return boxId
end

--------------------------------------------------------------------------------
-- DEMO SEQUENCE DEFINITIONS
--------------------------------------------------------------------------------

local function buildDemoQueue()
    _demoQueue = {}

    local cx = screenW() * 0.5   -- Center X
    local panelW = 700           -- Demo panel width
    local panelH = 400           -- Demo panel height
    local startX = cx - panelW / 2
    local startY = 30            -- Near top of screen (below any top UI)

    -- Helper: Create standard demo panel
    local function createDemoPanel(title, description, contentDef, codeSample)
        return dsl.root {
            config = {
                background = colors.panel,
                minWidth = panelW,
                minHeight = panelH,
                padding = 20,
            },
            children = {
                dsl.vbox {
                    config = { spacing = 15, minWidth = panelW - 40 },
                    children = {
                        -- Title row (left-aligned)
                        dsl.text(title, {
                            fontSize = 28,
                            color = colors.gold,
                            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
                        }),
                        -- Description (left-aligned)
                        dsl.text(description, {
                            fontSize = 14,
                            color = colors.label,
                            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
                        }),
                        -- Divider
                        dsl.divider("horizontal", { color = colors.header, thickness = 2, length = panelW - 40 }),
                        -- Content area (the actual demo)
                        dsl.vbox {
                            config = {
                                minWidth = panelW - 40,
                                minHeight = 150,
                                padding = 10,
                                background = colors.header,
                            },
                            children = { contentDef }
                        },
                        -- Code sample
                        dsl.vbox {
                            config = {
                                background = { r = 30, g = 35, b = 45, a = 255 },
                                padding = 10,
                                minWidth = panelW - 40,
                            },
                            children = {
                                dsl.text(codeSample, { fontSize = 11, color = colors.cyan })
                            }
                        },
                    }
                }
            }
        }
    end

    --------------------------------------------------------------------------
    -- DEMO 1: Introduction
    --------------------------------------------------------------------------
    table.insert(_demoQueue, {
        name = "Introduction",
        duration = 5,
        spawn = function()
            local panel = createDemoPanel(
                "UI Filler Demo",
                "Fillers are invisible layout elements that claim remaining space in containers.",
                dsl.vbox {
                    config = { spacing = 10 },
                    children = {
                        labelText("Key Features:", { fontSize = 18 }),
                        labelText("  - Push elements to edges"),
                        labelText("  - Proportional space distribution (flex weights)"),
                        labelText("  - Maximum size constraints (maxFill)"),
                        labelText("  - Works in both hbox and vbox"),
                    }
                },
                "dsl.filler()  -- Default flex=1\ndsl.filler { flex = 2 }  -- Double weight\ndsl.filler { maxFill = 100 }  -- Max 100px"
            )
            trackBox(dsl.spawn({ x = startX, y = startY }, panel, "ui", 1000))
        end
    })

    --------------------------------------------------------------------------
    -- DEMO 2: Basic Filler - Push to Edges
    --------------------------------------------------------------------------
    table.insert(_demoQueue, {
        name = "Basic: Push to Edges",
        duration = 6,
        spawn = function()
            -- Correct visualization: filler is direct child, parent background shows claimed space
            local demo = dsl.vbox {
                config = { spacing = 5 },
                children = {
                    labelText("Blue area = filler's claimed space", { fontSize = 11, color = colors.cyan }),
                    dsl.hbox {
                        config = {
                            minWidth = panelW - 60,
                            minHeight = 50,
                            spacing = 0,
                            background = colors.filler_visual,  -- Filler area visible as blue
                        },
                        children = {
                            contentBlock("Left", 80, 50),
                            dsl.filler(),  -- Direct child - claims remaining horizontal space
                            contentBlock("Right", 80, 50),
                        }
                    },
                }
            }

            local panel = createDemoPanel(
                "Basic: Push to Edges",
                "A single filler between elements pushes them to opposite sides.",
                demo,
                "dsl.hbox {\n  children = {\n    dsl.text('Left'),\n    dsl.filler(),  -- Claims all remaining space\n    dsl.text('Right'),\n  }\n}"
            )
            trackBox(dsl.spawn({ x = startX, y = startY }, panel, "ui", 1000))
        end
    })

    --------------------------------------------------------------------------
    -- DEMO 3: Multiple Equal Fillers
    --------------------------------------------------------------------------
    table.insert(_demoQueue, {
        name = "Equal Distribution",
        duration = 6,
        spawn = function()
            -- Each filler gets 1/3 of remaining space (520px / 3 ≈ 173px each)
            local demo = dsl.vbox {
                config = { spacing = 5 },
                children = {
                    labelText("3 fillers split remaining space equally (1:1:1)", { fontSize = 11, color = colors.cyan }),
                    dsl.hbox {
                        config = {
                            minWidth = panelW - 60,
                            minHeight = 50,
                            spacing = 0,
                            background = colors.filler_visual,
                        },
                        children = {
                            dsl.filler(),  -- Gets 1/3 of remaining
                            contentBlock("A", 60, 50),
                            dsl.filler(),  -- Gets 1/3 of remaining
                            contentBlock("B", 60, 50),
                            dsl.filler(),  -- Gets 1/3 of remaining
                        }
                    },
                }
            }

            local panel = createDemoPanel(
                "Equal Distribution",
                "Multiple fillers with same flex weight split space evenly (1:1:1 ratio).",
                demo,
                "dsl.hbox {\n  children = {\n    dsl.filler(),      -- Gets 1/3\n    dsl.text('A'),\n    dsl.filler(),      -- Gets 1/3\n    dsl.text('B'),\n    dsl.filler(),      -- Gets 1/3\n  }\n}"
            )
            trackBox(dsl.spawn({ x = startX, y = startY }, panel, "ui", 1000))
        end
    })

    --------------------------------------------------------------------------
    -- DEMO 4: Proportional Flex Weights
    --------------------------------------------------------------------------
    table.insert(_demoQueue, {
        name = "Proportional Weights",
        duration = 7,
        spawn = function()
            -- Total remaining = 640 - (4*50) = 440px, distributed as 1:2:3 ratio
            -- flex=1 gets 440/6 ≈ 73px, flex=2 gets ≈ 147px, flex=3 gets ≈ 220px
            local demo = dsl.vbox {
                config = { spacing = 5 },
                children = {
                    labelText("Flex weights 1:2:3 distribute space proportionally", { fontSize = 11, color = colors.cyan }),
                    dsl.hbox {
                        config = {
                            minWidth = panelW - 60,
                            minHeight = 50,
                            spacing = 0,
                            background = colors.filler_visual,
                        },
                        children = {
                            contentBlock("A", 50, 50),
                            dsl.filler { flex = 1 },  -- Gets 1/6 of remaining
                            contentBlock("B", 50, 50),
                            dsl.filler { flex = 2 },  -- Gets 2/6 (double of first)
                            contentBlock("C", 50, 50),
                            dsl.filler { flex = 3 },  -- Gets 3/6 (triple of first)
                            contentBlock("D", 50, 50),
                        }
                    },
                    -- Visual legend showing expected proportions
                    labelText("Notice: gaps between content blocks grow progressively larger", { fontSize = 10, color = colors.silver }),
                }
            }

            local panel = createDemoPanel(
                "Proportional Flex Weights",
                "Fillers distribute space according to their flex ratio (1:2:3 = 1/6 : 2/6 : 3/6).",
                demo,
                "dsl.hbox {\n  children = {\n    contentBlock('A'),\n    dsl.filler { flex = 1 },  -- Gets 1/6\n    contentBlock('B'),\n    dsl.filler { flex = 2 },  -- Gets 2/6\n    contentBlock('C'),\n    dsl.filler { flex = 3 },  -- Gets 3/6\n    contentBlock('D'),\n  }\n}"
            )
            trackBox(dsl.spawn({ x = startX, y = startY }, panel, "ui", 1000))
        end
    })

    --------------------------------------------------------------------------
    -- DEMO 5: Max Fill Constraint
    --------------------------------------------------------------------------
    table.insert(_demoQueue, {
        name = "Max Fill Constraint",
        duration = 7,
        spawn = function()
            -- Two rows: one without constraint, one with maxFill
            local demo = dsl.vbox {
                config = { spacing = 15 },
                children = {
                    -- Row 1: No constraint (filler expands fully)
                    dsl.vbox {
                        config = { spacing = 3 },
                        children = {
                            labelText("Without maxFill: filler expands to fill all remaining space", { fontSize = 11, color = colors.cyan }),
                            dsl.hbox {
                                config = { minWidth = panelW - 80, minHeight = 40, spacing = 0, background = colors.filler_visual },
                                children = {
                                    contentBlock("L", 60, 40),
                                    dsl.filler(),  -- Expands fully
                                    contentBlock("R", 60, 40),
                                }
                            },
                        }
                    },
                    -- Row 2: With maxFill (filler capped at 100px)
                    dsl.vbox {
                        config = { spacing = 3 },
                        children = {
                            labelText("With maxFill=100: filler capped, remaining space is empty", { fontSize = 11, color = { r = 255, g = 150, b = 150, a = 255 } }),
                            dsl.hbox {
                                config = { minWidth = panelW - 80, minHeight = 40, spacing = 0, background = { r = 80, g = 80, b = 90, a = 255 } },
                                children = {
                                    contentBlock("L", 60, 40),
                                    dsl.filler { maxFill = 100 },  -- Capped at 100px
                                    contentBlock("R", 60, 40),
                                }
                            },
                            labelText("(Notice: R is NOT pushed to the edge because filler stopped at 100px)", { fontSize = 10, color = colors.silver }),
                        }
                    },
                }
            }

            local panel = createDemoPanel(
                "Max Fill Constraint",
                "maxFill limits how large a filler can grow, even if more space is available.",
                demo,
                "-- Filler won't exceed 100px\ndsl.filler { maxFill = 100 }"
            )
            trackBox(dsl.spawn({ x = startX, y = startY }, panel, "ui", 1000))
        end
    })

    --------------------------------------------------------------------------
    -- DEMO 6: Vertical Fillers (vbox)
    --------------------------------------------------------------------------
    table.insert(_demoQueue, {
        name = "Vertical Fillers",
        duration = 6,
        spawn = function()
            local demo = dsl.vbox {
                config = { spacing = 10 },
                children = {
                    labelText("Fillers work the same in vertical layouts (vbox)", { fontSize = 11, color = colors.cyan }),
                    dsl.hbox {
                        config = { spacing = 30 },
                        children = {
                            -- Example 1: Push to top/bottom
                            dsl.vbox {
                                config = { spacing = 3 },
                                children = {
                                    labelText("Push to edges:", { fontSize = 10 }),
                                    dsl.vbox {
                                        config = { minWidth = 140, minHeight = 120, background = colors.filler_visual, spacing = 0 },
                                        children = {
                                            contentBlock("Top", 130, 25),
                                            dsl.filler(),  -- Claims vertical space
                                            contentBlock("Bottom", 130, 25),
                                        }
                                    },
                                }
                            },
                            -- Example 2: Proportional vertical (flex 1:2)
                            dsl.vbox {
                                config = { spacing = 3 },
                                children = {
                                    labelText("Flex weights 1:2:", { fontSize = 10 }),
                                    dsl.vbox {
                                        config = { minWidth = 140, minHeight = 120, background = colors.filler_visual, spacing = 0 },
                                        children = {
                                            dsl.filler { flex = 1 },  -- Gets 1/3 of remaining
                                            contentBlock("Mid", 130, 25),
                                            dsl.filler { flex = 2 },  -- Gets 2/3 of remaining
                                        }
                                    },
                                }
                            },
                            -- Example 3: Center content
                            dsl.vbox {
                                config = { spacing = 3 },
                                children = {
                                    labelText("Center content:", { fontSize = 10 }),
                                    dsl.vbox {
                                        config = { minWidth = 140, minHeight = 120, background = colors.filler_visual, spacing = 0 },
                                        children = {
                                            dsl.filler(),  -- Equal
                                            contentBlock("CENTER", 130, 25),
                                            dsl.filler(),  -- Equal
                                        }
                                    },
                                }
                            },
                        }
                    },
                }
            }

            local panel = createDemoPanel(
                "Vertical Fillers (vbox)",
                "Fillers work identically in vbox containers, distributing vertical space.",
                demo,
                "dsl.vbox {\n  children = {\n    dsl.text('Top'),\n    dsl.filler(),  -- Vertical space\n    dsl.text('Bottom'),\n  }\n}"
            )
            trackBox(dsl.spawn({ x = startX, y = startY }, panel, "ui", 1000))
        end
    })

    --------------------------------------------------------------------------
    -- DEMO 7: Real-World Pattern - Dialog Buttons
    --------------------------------------------------------------------------
    table.insert(_demoQueue, {
        name = "Pattern: Dialog Buttons",
        duration = 6,
        spawn = function()
            local demo = dsl.vbox {
                config = {
                    minWidth = panelW - 60,
                    minHeight = 120,
                    background = { r = 50, g = 55, b = 65, a = 255 },
                    padding = 15,
                },
                children = {
                    dsl.vbox {
                        config = { spacing = 15 },
                        children = {
                            labelText("Save changes before closing?", { fontSize = 16 }),
                            labelText("Your unsaved changes will be lost.", { fontSize = 12 }),
                            dsl.spacer(1, 10),
                            -- Button row with filler
                            dsl.hbox {
                                config = { minWidth = panelW - 100, spacing = 10 },
                                children = {
                                    dsl.vbox {
                                        config = { background = { r = 80, g = 80, b = 90, a = 255 }, padding = 10, minWidth = 80 },
                                        children = { dsl.text("Cancel", { fontSize = 14, color = "white" }) }
                                    },
                                    dsl.filler(),  -- Push OK/Save to right
                                    dsl.vbox {
                                        config = { background = { r = 70, g = 130, b = 180, a = 255 }, padding = 10, minWidth = 80 },
                                        children = { dsl.text("Save", { fontSize = 14, color = "white" }) }
                                    },
                                    dsl.vbox {
                                        config = { background = { r = 60, g = 160, b = 80, a = 255 }, padding = 10, minWidth = 80 },
                                        children = { dsl.text("OK", { fontSize = 14, color = "white" }) }
                                    },
                                }
                            },
                        }
                    }
                }
            }

            local panel = createDemoPanel(
                "Pattern: Dialog Buttons",
                "Classic pattern: Cancel on left, primary actions on right, connected by filler.",
                demo,
                "dsl.hbox {\n  children = {\n    button('Cancel'),\n    dsl.filler(),  -- Push right buttons to edge\n    button('Save'),\n    button('OK'),\n  }\n}"
            )
            trackBox(dsl.spawn({ x = startX, y = startY }, panel, "ui", 1000))
        end
    })

    --------------------------------------------------------------------------
    -- DEMO 8: Real-World Pattern - Stats Row
    --------------------------------------------------------------------------
    table.insert(_demoQueue, {
        name = "Pattern: Stats Display",
        duration = 6,
        spawn = function()
            -- Width for stat rows: panel - padding - content padding
            local statRowWidth = panelW - 60 - 30  -- 610px (matches available content width)

            -- Helper for stat row: label on left, value pushed to right edge
            local function statRow(label, value, valueColor)
                return dsl.hbox {
                    config = { minWidth = statRowWidth, spacing = 0 },
                    children = {
                        dsl.text(label, {
                            fontSize = 14,
                            color = colors.silver,
                            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
                        }),
                        dsl.filler(),
                        dsl.text(value, {
                            fontSize = 14,
                            color = valueColor or colors.gold,
                            align = bit.bor(AlignmentFlag.HORIZONTAL_RIGHT, AlignmentFlag.VERTICAL_CENTER),
                        }),
                    }
                }
            end

            local demo = dsl.vbox {
                config = {
                    minWidth = panelW - 60,
                    background = { r = 50, g = 55, b = 65, a = 255 },
                    padding = 15,
                },
                children = {
                    dsl.vbox {
                        config = { spacing = 8, minWidth = statRowWidth },
                        children = {
                            dsl.text("Character Stats", {
                                fontSize = 18,
                                color = colors.gold,
                                align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
                            }),
                            dsl.divider("horizontal", { color = colors.header, thickness = 1, length = statRowWidth }),
                            statRow("Health", "100/100", colors.content),
                            statRow("Attack", "45", colors.red),
                            statRow("Defense", "32", colors.cyan),
                            statRow("Speed", "28"),
                            dsl.divider("horizontal", { color = colors.header, thickness = 1, length = statRowWidth }),
                            statRow("Gold", "1,234"),
                            statRow("Experience", "7,890 / 10,000"),
                        }
                    }
                }
            }

            local panel = createDemoPanel(
                "Pattern: Stats Display",
                "Label-value pairs with fillers create aligned stat displays.",
                demo,
                "-- Each row: Label + Filler + Value\ndsl.hbox {\n  children = {\n    text('Health'),\n    dsl.filler(),\n    text('100/100'),\n  }\n}"
            )
            trackBox(dsl.spawn({ x = startX, y = startY }, panel, "ui", 1000))
        end
    })

    --------------------------------------------------------------------------
    -- DEMO 9: Real-World Pattern - Navigation Bar
    --------------------------------------------------------------------------
    table.insert(_demoQueue, {
        name = "Pattern: Navigation Bar",
        duration = 6,
        spawn = function()
            local demo = dsl.vbox {
                config = {
                    minWidth = panelW - 60,
                    minHeight = 60,
                    background = { r = 35, g = 40, b = 50, a = 255 },
                    padding = 10,
                },
                children = {
                    dsl.hbox {
                        config = { spacing = 15, minWidth = panelW - 80 },
                        children = {
                            -- Logo
                            dsl.vbox {
                                config = { background = colors.gold, padding = 8, minWidth = 40, minHeight = 40 },
                                children = { dsl.text("LOGO", { fontSize = 10, color = "black" }) }
                            },
                            -- Nav links
                            labelText("Home", { fontSize = 14 }),
                            labelText("About", { fontSize = 14 }),
                            labelText("Products", { fontSize = 14 }),
                            -- Filler pushes settings to right
                            dsl.filler(),
                            -- Right side
                            labelText("Search", { fontSize = 14, color = colors.cyan }),
                            dsl.vbox {
                                config = { background = colors.header, padding = 8 },
                                children = { dsl.text("Settings", { fontSize = 12, color = "white" }) }
                            },
                        }
                    }
                }
            }

            local panel = createDemoPanel(
                "Pattern: Navigation Bar",
                "Logo + nav items on left, actions on right, connected by filler.",
                demo,
                "dsl.hbox {\n  children = {\n    logo, 'Home', 'About', 'Products',\n    dsl.filler(),  -- Push right items\n    search, settings,\n  }\n}"
            )
            trackBox(dsl.spawn({ x = startX, y = startY }, panel, "ui", 1000))
        end
    })

    --------------------------------------------------------------------------
    -- DEMO 10: Centering Content
    --------------------------------------------------------------------------
    table.insert(_demoQueue, {
        name = "Pattern: Centering",
        duration = 6,
        spawn = function()
            local demo = dsl.vbox {
                config = { spacing = 15 },
                children = {
                    -- Horizontal centering
                    dsl.vbox {
                        config = { spacing = 3 },
                        children = {
                            labelText("Horizontal centering: [filler] + [content] + [filler]", { fontSize = 11, color = colors.cyan }),
                            dsl.hbox {
                                config = { minWidth = panelW - 80, minHeight = 50, background = colors.filler_visual, spacing = 0 },
                                children = {
                                    dsl.filler(),  -- Equal filler pushes content to center
                                    contentBlock("CENTERED", 120, 45),
                                    dsl.filler(),  -- Equal filler
                                }
                            },
                        }
                    },
                    -- Vertical centering
                    dsl.vbox {
                        config = { spacing = 3 },
                        children = {
                            labelText("Vertical centering: same pattern in vbox", { fontSize = 11, color = colors.cyan }),
                            dsl.hbox {
                                config = { spacing = 20 },
                                children = {
                                    dsl.vbox {
                                        config = { minHeight = 100, minWidth = 180, background = colors.filler_visual, spacing = 0 },
                                        children = {
                                            dsl.filler(),  -- Equal filler pushes content to center
                                            contentBlock("CENTER", 170, 30),
                                            dsl.filler(),  -- Equal filler
                                        }
                                    },
                                }
                            },
                        }
                    },
                }
            }

            local panel = createDemoPanel(
                "Pattern: Centering",
                "Two equal fillers on opposite sides center content perfectly.",
                demo,
                "-- Horizontal centering\ndsl.hbox { children = { dsl.filler(), content, dsl.filler() } }\n-- Vertical centering\ndsl.vbox { children = { dsl.filler(), content, dsl.filler() } }"
            )
            trackBox(dsl.spawn({ x = startX, y = startY }, panel, "ui", 1000))
        end
    })

    --------------------------------------------------------------------------
    -- DEMO 11: Complex Layout - Card
    --------------------------------------------------------------------------
    table.insert(_demoQueue, {
        name = "Complex: Game Card",
        duration = 7,
        spawn = function()
            local demo = dsl.vbox {
                config = {
                    minWidth = 280,
                    minHeight = 180,
                    background = { r = 60, g = 50, b = 70, a = 255 },
                    padding = 12,
                },
                children = {
                    dsl.vbox {
                        config = { spacing = 8, minHeight = 150 },
                        children = {
                            -- Top row: Name + Cost (filler pushes cost to right)
                            dsl.hbox {
                                config = { minWidth = 250, spacing = 0 },
                                children = {
                                    dsl.text("Fireball", { fontSize = 18, color = colors.gold }),
                                    dsl.filler(),  -- Pushes cost badge to right edge
                                    dsl.vbox {
                                        config = { background = colors.cyan, padding = 5, minWidth = 30 },
                                        children = { dsl.text("3", { fontSize = 14, color = "black" }) }
                                    },
                                }
                            },
                            -- Card art area (fillers center the text vertically)
                            dsl.vbox {
                                config = { background = { r = 80, g = 60, b = 90, a = 255 }, minWidth = 250, minHeight = 55, padding = 5, spacing = 0 },
                                children = {
                                    dsl.filler(),  -- Pushes text to vertical center
                                    dsl.text("[Card Art]", { fontSize = 12, color = colors.silver }),
                                    dsl.filler(),  -- Equal filler below
                                }
                            },
                            -- Description
                            dsl.text("Deal 25 fire damage", { fontSize = 12, color = "white" }),
                            dsl.filler(),  -- Pushes bottom stats row to card bottom
                            -- Bottom stats row (filler separates type from rarity)
                            dsl.hbox {
                                config = { minWidth = 250, spacing = 0 },
                                children = {
                                    dsl.text("Fire", { fontSize = 11, color = { r = 255, g = 100, b = 50, a = 255 } }),
                                    dsl.filler(),  -- Pushes rarity to right edge
                                    dsl.text("Common", { fontSize = 11, color = colors.silver }),
                                }
                            },
                        }
                    }
                }
            }

            local panel = createDemoPanel(
                "Complex: Game Card",
                "Multiple fillers create a polished card layout with aligned elements.",
                demo,
                "-- Top: Name [filler] Cost\n-- Art: [filler] Art [filler] (centers)\n-- [filler] (pushes stats down)\n-- Bottom: Type [filler] Rarity"
            )
            trackBox(dsl.spawn({ x = startX, y = startY }, panel, "ui", 1000))
        end
    })

    --------------------------------------------------------------------------
    -- DEMO 12: Summary
    --------------------------------------------------------------------------
    table.insert(_demoQueue, {
        name = "Summary",
        duration = 8,
        spawn = function()
            local demo = dsl.vbox {
                config = { spacing = 12 },
                children = {
                    dsl.hbox {
                        config = { minWidth = panelW - 80, spacing = 0 },
                        children = {
                            dsl.vbox { config = { background = colors.filler_visual, minWidth = 60, minHeight = 30, padding = 5 }, children = { dsl.text("filler()", { fontSize = 10, color = "white" }) } },
                            labelText("  Default flex=1, claims remaining space", { fontSize = 13 }),
                        }
                    },
                    dsl.hbox {
                        config = { minWidth = panelW - 80, spacing = 0 },
                        children = {
                            dsl.vbox { config = { background = { r = 100, g = 150, b = 200, a = 200 }, minWidth = 60, minHeight = 30, padding = 5 }, children = { dsl.text("{flex=N}", { fontSize = 10, color = "white" }) } },
                            labelText("  Proportional weight for space distribution", { fontSize = 13 }),
                        }
                    },
                    dsl.hbox {
                        config = { minWidth = panelW - 80, spacing = 0 },
                        children = {
                            dsl.vbox { config = { background = { r = 200, g = 100, b = 100, a = 200 }, minWidth = 60, minHeight = 30, padding = 5 }, children = { dsl.text("{max=N}", { fontSize = 10, color = "white" }) } },
                            labelText("  Cap maximum expansion size", { fontSize = 13 }),
                        }
                    },
                    dsl.spacer(1, 10),
                    labelText("Common Patterns:", { fontSize = 16, color = colors.gold }),
                    labelText("  [A] [filler] [B]        - Push to edges", { fontSize = 12 }),
                    labelText("  [filler] [A] [filler]   - Center content", { fontSize = 12 }),
                    labelText("  [A] [f:1] [B] [f:2] [C] - Proportional spacing", { fontSize = 12 }),
                }
            }

            local panel = createDemoPanel(
                "Demo Complete!",
                "UI fillers enable flexible, responsive layouts without manual calculations.",
                demo,
                "require('ui.ui_syntax_sugar').filler(opts)\n-- opts.flex: number (default 1)\n-- opts.maxFill: number (default 0 = unlimited)"
            )
            trackBox(dsl.spawn({ x = startX, y = startY }, panel, "ui", 1000))
        end
    })
end

--------------------------------------------------------------------------------
-- DEMO CONTROL
--------------------------------------------------------------------------------

local function runNextDemo()
    if not _active then return end

    _currentDemo = _currentDemo + 1
    if _currentDemo > #_demoQueue then
        _currentDemo = 1  -- Loop
    end

    local demo = _demoQueue[_currentDemo]
    if not demo then return end

    -- Clear previous demo UI
    cleanupSpawnedBoxes()

    -- Log progress
    print(string.format("[UIFillerDemo] %d/%d: %s", _currentDemo, #_demoQueue, demo.name))

    -- Spawn demo content
    demo.spawn()

    -- Progress indicator in corner
    local progressPanel = dsl.root {
        config = {
            background = { r = 0, g = 0, b = 0, a = 150 },
            padding = 8,
        },
        children = {
            dsl.text(
                string.format("%d / %d", _currentDemo, #_demoQueue),
                { fontSize = 14, color = colors.silver }
            )
        }
    }
    trackBox(dsl.spawn({ x = 20, y = 20 }, progressPanel, "ui", 1001))

    -- Schedule next demo
    _timers.nextDemo = timer.after(
        demo.duration,
        runNextDemo,
        nil, nil,
        "ui_filler_next",
        _demoTag
    )
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Start the UI filler demo
function UIFillerDemo.start()
    if _active then return end
    _active = true

    print("[UIFillerDemo] Starting comprehensive UI filler showcase")

    -- Move main menu down to avoid overlap with demo panel
    moveMainMenuDown()

    -- Build demo queue
    buildDemoQueue()
    _currentDemo = 0

    -- Clear any existing demo content
    cleanupSpawnedBoxes()

    -- Start first demo
    runNextDemo()

    print("[UIFillerDemo] Started - " .. #_demoQueue .. " demos queued")
end

--- Stop the UI filler demo
function UIFillerDemo.stop()
    if not _active then return end
    _active = false

    -- Kill all demo timers
    timer.kill_group(_demoTag)
    _timers = {}

    -- Clean up all demo UI
    cleanupSpawnedBoxes()

    -- Restore main menu to original position
    restoreMainMenuPosition()

    _currentDemo = 0
    _demoQueue = {}

    print("[UIFillerDemo] Stopped")
end

--- Check if demo is active
function UIFillerDemo.isActive()
    return _active
end

--- Get current demo index
function UIFillerDemo.getCurrentDemo()
    return _currentDemo, #_demoQueue
end

--- Skip to next demo
function UIFillerDemo.next()
    if not _active then return end
    timer.kill("ui_filler_next")
    runNextDemo()
end

--- Skip to previous demo
function UIFillerDemo.prev()
    if not _active then return end
    _currentDemo = _currentDemo - 2
    if _currentDemo < 0 then _currentDemo = #_demoQueue - 1 end
    timer.kill("ui_filler_next")
    runNextDemo()
end

return UIFillerDemo
