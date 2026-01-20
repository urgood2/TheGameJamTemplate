--[[
================================================================================
CONTROLLER NAVIGATION DEMO - Comprehensive Feature Showcase
================================================================================
Demonstrates ALL controller navigation features implemented in this worktree:

P0 Bug Fixes:
  - Separated layerStack and focusGroupStack
  - Spatial nav fallback to linked groups
  - Selection validity enforcement
  - Graceful error recovery

P1 Features:
  - Explicit per-element neighbors
  - Scroll-into-view
  - Input repeat with acceleration
  - Focus restoration for modals

P2 Features:
  - Entity-to-group mapping (O(1) lookup)
  - Comprehensive validation

Usage:
    local ControllerNavDemo = require("demos.controller_nav_demo")
    ControllerNavDemo.start()    -- Start the demo
    ControllerNavDemo.stop()     -- Stop and cleanup
]]

local ControllerNavDemo = {}

local dsl = require("ui.ui_syntax_sugar")
local timer = require("core.timer")
local component_cache = require("core.component_cache")
local z_orders = require("core.z_orders")

-- Demo state
local _active = false
local _state = {
    entities = {},      -- All created entities
    groups = {},        -- Navigation group names
    layers = {},        -- Navigation layer names
    currentSection = 1, -- Current demo section
    inputTimerId = nil, -- Timer for input polling
}

local DEMO_TIMER_GROUP = "controller_nav_demo"
local DEMO_LAYER = "controller_nav_demo_layer"
local DEMO_GROUP_GRID = "demo_grid"
local DEMO_GROUP_CUSTOM = "demo_custom_path"
local DEMO_GROUP_SCROLL = "demo_scroll_list"
local DEMO_GROUP_MODAL = "demo_modal"

-- Screen helpers
local function screenW()
    return globals and globals.screenWidth and globals.screenWidth() or 1920
end

local function screenH()
    return globals and globals.screenHeight and globals.screenHeight() or 1080
end

--------------------------------------------------------------------------------
-- VISUAL FEEDBACK HELPERS
--------------------------------------------------------------------------------

local function createFocusIndicator(entity)
    -- Add visual indicator when focused
    local transform = component_cache.get(entity, Transform)
    if not transform then return end

    -- Use shader or outline for focus effect
    if shader_pipeline and shader_pipeline.addShaderPass then
        shader_pipeline.addShaderPass(registry, entity, "3d_skew_holo", {
            sheen_strength = 1.5,
            edge_glow = 1.0
        })
    end
end

local function removeFocusIndicator(entity)
    if shader_pipeline and shader_pipeline.removeShaderPass then
        shader_pipeline.removeShaderPass(registry, entity, "3d_skew_holo")
    end
end

--------------------------------------------------------------------------------
-- DEMO SECTIONS
--------------------------------------------------------------------------------

--[[
SECTION 1: Spatial Navigation Grid (3x3)
Demonstrates automatic spatial navigation based on entity positions.
]]
local function createSpatialGrid(startX, startY)
    local entities = {}
    local gridSize = 3
    local buttonW, buttonH = 80, 50
    local spacing = 20

    for row = 1, gridSize do
        for col = 1, gridSize do
            local x = startX + (col - 1) * (buttonW + spacing)
            local y = startY + (row - 1) * (buttonH + spacing)
            local label = string.format("%d,%d", row, col)

            local buttonDef = dsl.strict.root {
                config = {
                    color = util.getColor("deep_teal"),
                    padding = 8,
                    minWidth = buttonW,
                    minHeight = buttonH,
                    emboss = 2,
                },
                children = {
                    dsl.strict.text(label, {
                        fontSize = 14,
                        color = "white",
                        shadow = true,
                    })
                }
            }

            local entity = dsl.spawn({ x = x, y = y }, buttonDef, "ui", z_orders.ui_tooltips + 50)
            ui.box.set_draw_layer(entity, "ui")

            table.insert(entities, entity)
            table.insert(_state.entities, entity)

            -- Add to navigation group
            controller_nav.ud:add_entity(DEMO_GROUP_GRID, entity)
        end
    end

    -- Set up callbacks
    controller_nav.set_group_callbacks(DEMO_GROUP_GRID, {
        on_focus = function(entity)
            log_debug("[NavDemo] Grid focus: " .. tostring(entity))
            createFocusIndicator(entity)
        end,
        on_unfocus = function(entity)
            log_debug("[NavDemo] Grid unfocus: " .. tostring(entity))
            removeFocusIndicator(entity)
        end,
        on_select = function(entity)
            log_debug("[NavDemo] Grid select: " .. tostring(entity))
            if playSoundEffect then playSoundEffect("effects", "button-click") end
        end
    })

    return entities
end

--[[
SECTION 2: Explicit Neighbor Navigation (Custom Path)
Demonstrates manual navigation override - a non-grid layout with custom paths.
]]
local function createCustomPathDemo(startX, startY)
    local entities = {}

    -- Create buttons in a custom arrangement (not a grid)
    local positions = {
        { x = startX + 100, y = startY,       label = "TOP" },
        { x = startX,       y = startY + 60,  label = "LEFT" },
        { x = startX + 200, y = startY + 60,  label = "RIGHT" },
        { x = startX + 50,  y = startY + 120, label = "BOTTOM-L" },
        { x = startX + 150, y = startY + 120, label = "BOTTOM-R" },
    }

    for i, pos in ipairs(positions) do
        local buttonDef = dsl.strict.root {
            config = {
                color = util.getColor("mulberry"),
                padding = 8,
                minWidth = 80,
                minHeight = 40,
                emboss = 2,
            },
            children = {
                dsl.strict.text(pos.label, {
                    fontSize = 12,
                    color = "white",
                    shadow = true,
                })
            }
        }

        local entity = dsl.spawn({ x = pos.x, y = pos.y }, buttonDef, "ui", z_orders.ui_tooltips + 50)
        ui.box.set_draw_layer(entity, "ui")

        table.insert(entities, entity)
        table.insert(_state.entities, entity)
        controller_nav.ud:add_entity(DEMO_GROUP_CUSTOM, entity)
    end

    -- Set explicit neighbors (circular navigation: TOP -> RIGHT -> BOTTOM-R -> BOTTOM-L -> LEFT -> TOP)
    local top, left, right, bottomL, bottomR = entities[1], entities[2], entities[3], entities[4], entities[5]

    controller_nav.set_neighbors(top, { down = right, left = left, right = right })
    controller_nav.set_neighbors(left, { up = top, right = bottomL, down = bottomL })
    controller_nav.set_neighbors(right, { up = top, left = bottomR, down = bottomR })
    controller_nav.set_neighbors(bottomL, { up = left, right = bottomR })
    controller_nav.set_neighbors(bottomR, { up = right, left = bottomL })

    -- Set up callbacks
    controller_nav.set_group_callbacks(DEMO_GROUP_CUSTOM, {
        on_focus = function(entity)
            log_debug("[NavDemo] Custom focus: " .. tostring(entity))
            createFocusIndicator(entity)
        end,
        on_unfocus = function(entity)
            removeFocusIndicator(entity)
        end,
        on_select = function(entity)
            if playSoundEffect then playSoundEffect("effects", "button-click") end
        end
    })

    return entities
end

--[[
SECTION 3: Group Linking Demo
Demonstrates navigation between different groups.
]]
local function createGroupLinkingDemo(startX, startY)
    -- Already have grid and custom groups, link them together
    controller_nav.link_groups(DEMO_GROUP_GRID, {
        right = DEMO_GROUP_CUSTOM
    })
    controller_nav.link_groups(DEMO_GROUP_CUSTOM, {
        left = DEMO_GROUP_GRID
    })

    -- Create a label showing the linking
    local labelDef = dsl.strict.root {
        config = {
            color = util.getColor("charcoal"),
            padding = 4,
        },
        children = {
            dsl.strict.text("Grid <---> Custom Path (linked)", {
                fontSize = 12,
                color = "lime",
            })
        }
    }

    local entity = dsl.spawn({ x = startX, y = startY }, labelDef, "ui", z_orders.ui_tooltips + 40)
    ui.box.set_draw_layer(entity, "ui")
    table.insert(_state.entities, entity)
end

--[[
SECTION 4: Scrollable List with Scroll-into-View
Demonstrates auto-scrolling when navigating to off-screen items.
]]
local function createScrollableListDemo(startX, startY)
    local entities = {}

    -- Create scroll container (simulated - just a column of items)
    local itemCount = 12
    local itemH = 30
    local visibleItems = 5

    for i = 1, itemCount do
        local y = startY + (i - 1) * (itemH + 4)
        local label = string.format("Item %02d", i)

        local itemDef = dsl.strict.root {
            config = {
                color = i <= visibleItems and util.getColor("forest_slate") or util.getColor("charcoal"),
                padding = 4,
                minWidth = 120,
                minHeight = itemH,
                emboss = 1,
            },
            children = {
                dsl.strict.text(label, {
                    fontSize = 12,
                    color = i <= visibleItems and "white" or "gray",
                })
            }
        }

        local entity = dsl.spawn({ x = startX, y = y }, itemDef, "ui", z_orders.ui_tooltips + 50)
        ui.box.set_draw_layer(entity, "ui")

        table.insert(entities, entity)
        table.insert(_state.entities, entity)
        controller_nav.ud:add_entity(DEMO_GROUP_SCROLL, entity)
    end

    -- Set linear mode for the scroll list
    controller_nav.set_group_mode(DEMO_GROUP_SCROLL, "linear")
    controller_nav.set_wrap(DEMO_GROUP_SCROLL, true)

    -- Set up callbacks with scroll-into-view
    controller_nav.set_group_callbacks(DEMO_GROUP_SCROLL, {
        on_focus = function(entity)
            log_debug("[NavDemo] Scroll focus: " .. tostring(entity))
            createFocusIndicator(entity)
            -- Trigger scroll-into-view (would work with actual scroll pane)
            controller_nav.scroll_into_view(entity)
        end,
        on_unfocus = function(entity)
            removeFocusIndicator(entity)
        end,
        on_select = function(entity)
            if playSoundEffect then playSoundEffect("effects", "button-click") end
        end
    })

    -- Link scroll list to other groups
    controller_nav.link_groups(DEMO_GROUP_SCROLL, {
        left = DEMO_GROUP_CUSTOM
    })
    controller_nav.link_groups(DEMO_GROUP_CUSTOM, {
        right = DEMO_GROUP_SCROLL
    })

    return entities
end

--[[
SECTION 5: Input Repeat Configuration Demo
Shows the repeat acceleration settings.
]]
local function createRepeatConfigDemo(startX, startY)
    -- Display current config
    local config = controller_nav.get_repeat_config()

    local lines = {
        string.format("initialDelay: %.2fs", config.initialDelay),
        string.format("repeatRate: %.2fs", config.repeatRate),
        string.format("minRepeatRate: %.2fs", config.minRepeatRate),
        string.format("acceleration: %.2f", config.acceleration),
    }

    local text = table.concat(lines, "\n")

    local configDef = dsl.strict.root {
        config = {
            color = util.getColor("espresso"),
            padding = 8,
            emboss = 2,
        },
        children = {
            dsl.strict.vbox {
                config = { padding = 4 },
                children = {
                    dsl.strict.text("Input Repeat Config:", {
                        fontSize = 14,
                        color = "gold",
                        shadow = true,
                    }),
                    dsl.strict.spacer(4),
                    dsl.strict.text(lines[1], { fontSize = 11, color = "white" }),
                    dsl.strict.text(lines[2], { fontSize = 11, color = "white" }),
                    dsl.strict.text(lines[3], { fontSize = 11, color = "white" }),
                    dsl.strict.text(lines[4], { fontSize = 11, color = "cyan" }),
                }
            }
        }
    }

    local entity = dsl.spawn({ x = startX, y = startY }, configDef, "ui", z_orders.ui_tooltips + 40)
    ui.box.set_draw_layer(entity, "ui")
    table.insert(_state.entities, entity)

    -- Create buttons to modify config
    local slowBtn = dsl.strict.root {
        config = {
            color = util.getColor("indian_red"),
            padding = 6,
            emboss = 2,
        },
        children = {
            dsl.strict.button("Slow Repeat", {
                fontSize = 12,
                color = "transparent",
                textColor = "white",
                onClick = function()
                    controller_nav.set_repeat_config({
                        initialDelay = 0.6,
                        repeatRate = 0.2,
                        minRepeatRate = 0.1,
                        acceleration = 0.95
                    })
                    log_debug("[NavDemo] Set SLOW repeat config")
                end
            })
        }
    }

    local fastBtn = dsl.strict.root {
        config = {
            color = util.getColor("jade_green"),
            padding = 6,
            emboss = 2,
        },
        children = {
            dsl.strict.button("Fast Repeat", {
                fontSize = 12,
                color = "transparent",
                textColor = "white",
                onClick = function()
                    controller_nav.set_repeat_config({
                        initialDelay = 0.25,
                        repeatRate = 0.06,
                        minRepeatRate = 0.02,
                        acceleration = 0.85
                    })
                    log_debug("[NavDemo] Set FAST repeat config")
                end
            })
        }
    }

    local slowEntity = dsl.spawn({ x = startX, y = startY + 120 }, slowBtn, "ui", z_orders.ui_tooltips + 50)
    local fastEntity = dsl.spawn({ x = startX + 100, y = startY + 120 }, fastBtn, "ui", z_orders.ui_tooltips + 50)
    ui.box.set_draw_layer(slowEntity, "ui")
    ui.box.set_draw_layer(fastEntity, "ui")
    table.insert(_state.entities, slowEntity)
    table.insert(_state.entities, fastEntity)
end

--[[
SECTION 6: Modal / Layer System Demo
Demonstrates push/pop layers with focus restoration.
]]
local function createModalDemo(startX, startY)
    local MODAL_LAYER = "demo_modal_layer"

    local openModalBtn = dsl.strict.root {
        config = {
            color = util.getColor("royal_blue"),
            padding = 8,
            emboss = 2,
        },
        children = {
            dsl.strict.button("Open Modal (Push Layer)", {
                fontSize = 12,
                color = "transparent",
                textColor = "white",
                onClick = function()
                    log_debug("[NavDemo] Opening modal...")

                    -- Record current focus before pushing modal
                    local currentFocus = controller_nav.ud:get_selected(DEMO_GROUP_GRID)
                    if currentFocus and registry:valid(currentFocus) then
                        controller_nav.record_focus_for_layer(currentFocus, DEMO_GROUP_GRID)
                    end

                    -- Create modal content
                    local modalDef = dsl.strict.root {
                        config = {
                            color = util.getColor("blackberry"),
                            padding = 16,
                            emboss = 4,
                            minWidth = 300,
                            minHeight = 200,
                        },
                        children = {
                            dsl.strict.vbox {
                                config = { padding = 8 },
                                children = {
                                    dsl.strict.text("MODAL DIALOG", {
                                        fontSize = 20,
                                        color = "gold",
                                        shadow = true,
                                    }),
                                    dsl.strict.spacer(12),
                                    dsl.strict.text("This is a modal layer.", {
                                        fontSize = 14,
                                        color = "white",
                                    }),
                                    dsl.strict.text("Press Close to pop layer", {
                                        fontSize = 14,
                                        color = "white",
                                    }),
                                    dsl.strict.text("and restore previous focus.", {
                                        fontSize = 14,
                                        color = "white",
                                    }),
                                    dsl.strict.spacer(16),
                                    dsl.strict.button("Close Modal (Pop Layer)", {
                                        fontSize = 14,
                                        color = "indian_red",
                                        textColor = "white",
                                        minWidth = 200,
                                        onClick = function()
                                            log_debug("[NavDemo] Closing modal...")
                                            controller_nav.ud:pop_layer()

                                            -- Check restored focus
                                            local restored = controller_nav.get_restored_focus()
                                            if restored.entity then
                                                log_debug("[NavDemo] Focus restored to: " .. tostring(restored.entity) .. " in group: " .. restored.group)
                                            end

                                            -- Cleanup modal entity
                                            if _state.modalEntity and registry:valid(_state.modalEntity) then
                                                ui.box.Remove(registry, _state.modalEntity)
                                                _state.modalEntity = nil
                                            end
                                        end
                                    }),
                                }
                            }
                        }
                    }

                    -- Spawn modal in center
                    local modalX = screenW() / 2 - 150
                    local modalY = screenH() / 2 - 100
                    _state.modalEntity = dsl.spawn({ x = modalX, y = modalY }, modalDef, "ui", z_orders.ui_tooltips + 200)
                    ui.box.set_draw_layer(_state.modalEntity, "ui")

                    -- Create modal layer and group
                    controller_nav.create_layer(MODAL_LAYER)
                    controller_nav.create_group(DEMO_GROUP_MODAL)
                    controller_nav.add_group_to_layer(MODAL_LAYER, DEMO_GROUP_MODAL)
                    controller_nav.ud:add_entity(DEMO_GROUP_MODAL, _state.modalEntity)

                    -- Push the modal layer
                    controller_nav.ud:push_layer(MODAL_LAYER)

                    log_debug("[NavDemo] Modal layer pushed")
                end
            })
        }
    }

    local entity = dsl.spawn({ x = startX, y = startY }, openModalBtn, "ui", z_orders.ui_tooltips + 50)
    ui.box.set_draw_layer(entity, "ui")
    table.insert(_state.entities, entity)
end

--[[
SECTION 7: Validation Demo
Shows the validation system output.
]]
local function createValidationDemo(startX, startY)
    local validateBtn = dsl.strict.root {
        config = {
            color = util.getColor("verdigris"),
            padding = 8,
            emboss = 2,
        },
        children = {
            dsl.strict.button("Run Validation", {
                fontSize = 12,
                color = "transparent",
                textColor = "white",
                onClick = function()
                    local errors = controller_nav.validate()
                    if errors == "" then
                        log_debug("[NavDemo] Validation PASSED - no errors!")
                    else
                        log_warn("[NavDemo] Validation errors:\n" .. errors)
                    end
                end
            })
        }
    }

    local debugBtn = dsl.strict.root {
        config = {
            color = util.getColor("purple_orchid"),
            padding = 8,
            emboss = 2,
        },
        children = {
            dsl.strict.button("Debug Print State", {
                fontSize = 12,
                color = "transparent",
                textColor = "white",
                onClick = function()
                    controller_nav.debug_print_state()
                end
            })
        }
    }

    local validateEntity = dsl.spawn({ x = startX, y = startY }, validateBtn, "ui", z_orders.ui_tooltips + 50)
    local debugEntity = dsl.spawn({ x = startX, y = startY + 45 }, debugBtn, "ui", z_orders.ui_tooltips + 50)
    ui.box.set_draw_layer(validateEntity, "ui")
    ui.box.set_draw_layer(debugEntity, "ui")
    table.insert(_state.entities, validateEntity)
    table.insert(_state.entities, debugEntity)
end

--[[
SECTION 8: Instructions Panel
]]
local function createInstructionsPanel(startX, startY)
    local instructionsDef = dsl.strict.root {
        config = {
            color = util.getColor("midnight_blue"),
            padding = 12,
            emboss = 2,
            minWidth = 320,
        },
        children = {
            dsl.strict.vbox {
                config = { padding = 4 },
                children = {
                    dsl.strict.text("CONTROLLER NAV DEMO", {
                        fontSize = 18,
                        color = "gold",
                        shadow = true,
                    }),
                    dsl.strict.spacer(8),
                    dsl.strict.text("Controls:", {
                        fontSize = 14,
                        color = "cyan",
                    }),
                    dsl.strict.text("  D-Pad / WASD: Navigate", {
                        fontSize = 12,
                        color = "white",
                    }),
                    dsl.strict.text("  A / Enter: Select", {
                        fontSize = 12,
                        color = "white",
                    }),
                    dsl.strict.text("  Tab: Switch Groups", {
                        fontSize = 12,
                        color = "white",
                    }),
                    dsl.strict.spacer(8),
                    dsl.strict.text("Features:", {
                        fontSize = 14,
                        color = "cyan",
                    }),
                    dsl.strict.text("  - Spatial navigation (grid)", {
                        fontSize = 11,
                        color = "lime",
                    }),
                    dsl.strict.text("  - Explicit neighbors (custom path)", {
                        fontSize = 11,
                        color = "lime",
                    }),
                    dsl.strict.text("  - Group linking", {
                        fontSize = 11,
                        color = "lime",
                    }),
                    dsl.strict.text("  - Scroll-into-view (list)", {
                        fontSize = 11,
                        color = "lime",
                    }),
                    dsl.strict.text("  - Input repeat acceleration", {
                        fontSize = 11,
                        color = "lime",
                    }),
                    dsl.strict.text("  - Modal layers with focus restore", {
                        fontSize = 11,
                        color = "lime",
                    }),
                    dsl.strict.text("  - Validation system", {
                        fontSize = 11,
                        color = "lime",
                    }),
                }
            }
        }
    }

    local entity = dsl.spawn({ x = startX, y = startY }, instructionsDef, "ui", z_orders.ui_tooltips + 30)
    ui.box.set_draw_layer(entity, "ui")
    table.insert(_state.entities, entity)
end

--[[
SECTION 9: Current Focus Display
]]
local function createFocusDisplay(startX, startY)
    local focusDef = dsl.strict.root {
        config = {
            color = util.getColor("charcoal"),
            padding = 8,
            emboss = 1,
            minWidth = 200,
        },
        children = {
            dsl.strict.vbox {
                config = { padding = 2 },
                children = {
                    dsl.strict.text("Current State:", {
                        fontSize = 12,
                        color = "gold",
                    }),
                    dsl.strict.text("Focus Group: ---", {
                        fontSize = 11,
                        color = "white",
                        id = "focus_group_text",
                    }),
                    dsl.strict.text("Active Layer: ---", {
                        fontSize = 11,
                        color = "white",
                        id = "active_layer_text",
                    }),
                }
            }
        }
    }

    local entity = dsl.spawn({ x = startX, y = startY }, focusDef, "ui", z_orders.ui_tooltips + 30)
    ui.box.set_draw_layer(entity, "ui")
    table.insert(_state.entities, entity)
    _state.focusDisplayEntity = entity
end

--------------------------------------------------------------------------------
-- INPUT HANDLING
--------------------------------------------------------------------------------

local function bindDemoInputs()
    -- Bind keyboard navigation for demo (context: main-menu so it works on main menu)
    input.bind("demo_nav_up", { device = "keyboard", key = KeyboardKey.KEY_W, trigger = "Pressed", context = "main-menu" })
    input.bind("demo_nav_up", { device = "keyboard", key = KeyboardKey.KEY_UP, trigger = "Pressed", context = "main-menu" })
    input.bind("demo_nav_down", { device = "keyboard", key = KeyboardKey.KEY_S, trigger = "Pressed", context = "main-menu" })
    input.bind("demo_nav_down", { device = "keyboard", key = KeyboardKey.KEY_DOWN, trigger = "Pressed", context = "main-menu" })
    input.bind("demo_nav_left", { device = "keyboard", key = KeyboardKey.KEY_A, trigger = "Pressed", context = "main-menu" })
    input.bind("demo_nav_left", { device = "keyboard", key = KeyboardKey.KEY_LEFT, trigger = "Pressed", context = "main-menu" })
    input.bind("demo_nav_right", { device = "keyboard", key = KeyboardKey.KEY_D, trigger = "Pressed", context = "main-menu" })
    input.bind("demo_nav_right", { device = "keyboard", key = KeyboardKey.KEY_RIGHT, trigger = "Pressed", context = "main-menu" })
    input.bind("demo_nav_select", { device = "keyboard", key = KeyboardKey.KEY_ENTER, trigger = "Pressed", context = "main-menu" })
    input.bind("demo_nav_select", { device = "keyboard", key = KeyboardKey.KEY_SPACE, trigger = "Pressed", context = "main-menu" })
    input.bind("demo_nav_switch_group", { device = "keyboard", key = KeyboardKey.KEY_TAB, trigger = "Pressed", context = "main-menu" })

    -- Also bind gamepad D-pad for controller support
    input.bind("demo_nav_up", { device = "gamepad_button", button = GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_UP, trigger = "Pressed", context = "main-menu" })
    input.bind("demo_nav_down", { device = "gamepad_button", button = GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_DOWN, trigger = "Pressed", context = "main-menu" })
    input.bind("demo_nav_left", { device = "gamepad_button", button = GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_LEFT, trigger = "Pressed", context = "main-menu" })
    input.bind("demo_nav_right", { device = "gamepad_button", button = GamepadButton.GAMEPAD_BUTTON_LEFT_FACE_RIGHT, trigger = "Pressed", context = "main-menu" })
    input.bind("demo_nav_select", { device = "gamepad_button", button = GamepadButton.GAMEPAD_BUTTON_RIGHT_FACE_DOWN, trigger = "Pressed", context = "main-menu" })
    input.bind("demo_nav_switch_group", { device = "gamepad_button", button = GamepadButton.GAMEPAD_BUTTON_RIGHT_TRIGGER_1, trigger = "Pressed", context = "main-menu" })
end

local function setupInputPolling()
    _state.activeGroup = DEMO_GROUP_GRID

    _state.inputTimerId = timer.every_opts({
        delay = 0.016, -- ~60fps
        action = function()
            if not _active then return end

            local activeGroup = _state.activeGroup

            -- Check for navigation inputs using the input binding system
            if input and input.action_down then
                -- WASD / Arrow keys / D-pad for navigation
                if input.action_down("demo_nav_up") then
                    controller_nav.navigate(activeGroup, "U")
                    log_debug("[NavDemo] Navigate UP in group: " .. activeGroup)
                elseif input.action_down("demo_nav_down") then
                    controller_nav.navigate(activeGroup, "D")
                    log_debug("[NavDemo] Navigate DOWN in group: " .. activeGroup)
                elseif input.action_down("demo_nav_left") then
                    controller_nav.navigate(activeGroup, "L")
                    log_debug("[NavDemo] Navigate LEFT in group: " .. activeGroup)
                elseif input.action_down("demo_nav_right") then
                    controller_nav.navigate(activeGroup, "R")
                    log_debug("[NavDemo] Navigate RIGHT in group: " .. activeGroup)
                end

                -- Enter/Space/A button for select
                if input.action_down("demo_nav_select") then
                    controller_nav.select_current(activeGroup)
                    log_debug("[NavDemo] SELECT in group: " .. activeGroup)
                end

                -- Tab/RB to switch between groups
                if input.action_down("demo_nav_switch_group") then
                    if activeGroup == DEMO_GROUP_GRID then
                        _state.activeGroup = DEMO_GROUP_CUSTOM
                    elseif activeGroup == DEMO_GROUP_CUSTOM then
                        _state.activeGroup = DEMO_GROUP_SCROLL
                    else
                        _state.activeGroup = DEMO_GROUP_GRID
                    end
                    log_debug("[NavDemo] Switched to group: " .. _state.activeGroup)
                end
            end

            -- Update focus display
            if _state.focusDisplayEntity then
                local focusGroup = controller_nav.current_focus_group()
                -- Could update text here if we had text update capability
            end
        end,
        tag = "nav_demo_input",
        group = DEMO_TIMER_GROUP
    })
end

--------------------------------------------------------------------------------
-- SECTION LABELS
--------------------------------------------------------------------------------

local function createSectionLabel(x, y, text)
    local labelDef = dsl.strict.root {
        config = {
            color = "transparent",
            padding = 2,
        },
        children = {
            dsl.strict.text(text, {
                fontSize = 14,
                color = "gold",
                shadow = true,
            })
        }
    }

    local entity = dsl.spawn({ x = x, y = y }, labelDef, "ui", z_orders.ui_tooltips + 35)
    ui.box.set_draw_layer(entity, "ui")
    table.insert(_state.entities, entity)
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

function ControllerNavDemo.start()
    if _active then
        log_debug("[NavDemo] Already active, stopping first...")
        ControllerNavDemo.stop()
    end

    log_debug("[NavDemo] Starting Controller Navigation Demo...")
    _active = true

    -- Bind input keys for demo navigation
    bindDemoInputs()

    -- Create the main layer and groups
    controller_nav.create_layer(DEMO_LAYER)
    controller_nav.create_group(DEMO_GROUP_GRID)
    controller_nav.create_group(DEMO_GROUP_CUSTOM)
    controller_nav.create_group(DEMO_GROUP_SCROLL)

    -- Add groups to layer
    controller_nav.add_group_to_layer(DEMO_LAYER, DEMO_GROUP_GRID)
    controller_nav.add_group_to_layer(DEMO_LAYER, DEMO_GROUP_CUSTOM)
    controller_nav.add_group_to_layer(DEMO_LAYER, DEMO_GROUP_SCROLL)

    -- Set spatial mode for grid, linear for scroll
    controller_nav.set_group_mode(DEMO_GROUP_GRID, "spatial")
    controller_nav.set_group_mode(DEMO_GROUP_CUSTOM, "spatial")
    controller_nav.set_group_mode(DEMO_GROUP_SCROLL, "linear")

    -- Enable wrap for all groups
    controller_nav.set_wrap(DEMO_GROUP_GRID, true)
    controller_nav.set_wrap(DEMO_GROUP_CUSTOM, false)
    controller_nav.set_wrap(DEMO_GROUP_SCROLL, true)

    -- Layout positions
    local baseY = 80
    local col1X = 20
    local col2X = 340
    local col3X = 640

    -- Create instructions panel
    createInstructionsPanel(col1X, baseY)

    -- Section 1: Spatial Grid
    createSectionLabel(col2X, baseY - 20, "1. Spatial Navigation (3x3 Grid)")
    createSpatialGrid(col2X, baseY)

    -- Section 2: Custom Path
    createSectionLabel(col2X, baseY + 220, "2. Explicit Neighbors (Custom Path)")
    createCustomPathDemo(col2X, baseY + 240)

    -- Section 3: Group Linking (just text indicator)
    createGroupLinkingDemo(col2X, baseY + 400)

    -- Section 4: Scroll List
    createSectionLabel(col3X, baseY - 20, "3. Scroll List (Linear Mode)")
    createScrollableListDemo(col3X, baseY)

    -- Section 5: Repeat Config
    createSectionLabel(col3X, baseY + 430, "4. Input Repeat Config")
    createRepeatConfigDemo(col3X, baseY + 450)

    -- Section 6: Modal Demo
    createSectionLabel(col1X, baseY + 320, "5. Modal Layer Demo")
    createModalDemo(col1X, baseY + 340)

    -- Section 7: Validation
    createSectionLabel(col1X, baseY + 420, "6. Validation Tools")
    createValidationDemo(col1X, baseY + 440)

    -- Section 8: Focus Display
    createFocusDisplay(col1X, baseY + 540)

    -- Push the demo layer
    controller_nav.ud:push_layer(DEMO_LAYER)

    -- Set up input polling
    setupInputPolling()

    -- Run initial validation
    timer.after_opts({
        delay = 0.5,
        action = function()
            local errors = controller_nav.validate()
            if errors == "" then
                log_debug("[NavDemo] Initial validation PASSED")
            else
                log_warn("[NavDemo] Initial validation found issues:\n" .. errors)
            end
        end,
        tag = "nav_demo_validate",
        group = DEMO_TIMER_GROUP
    })

    log_debug("[NavDemo] Demo setup complete!")
end

function ControllerNavDemo.stop()
    if not _active then return end

    log_debug("[NavDemo] Stopping Controller Navigation Demo...")
    _active = false

    -- Kill all timers
    timer.kill_group(DEMO_TIMER_GROUP)

    -- Pop the layer if it's active
    -- (Safe because pop_layer handles empty stack gracefully)
    controller_nav.ud:pop_layer()

    -- Clean up modal if open
    if _state.modalEntity and registry:valid(_state.modalEntity) then
        ui.box.Remove(registry, _state.modalEntity)
        _state.modalEntity = nil
    end

    -- Clean up all entities
    for _, entity in ipairs(_state.entities) do
        if entity and registry:valid(entity) then
            if ui and ui.box and ui.box.Remove then
                ui.box.Remove(registry, entity)
            end
        end
    end

    -- Clear groups
    controller_nav.ud:clear_group(DEMO_GROUP_GRID)
    controller_nav.ud:clear_group(DEMO_GROUP_CUSTOM)
    controller_nav.ud:clear_group(DEMO_GROUP_SCROLL)
    controller_nav.ud:clear_group(DEMO_GROUP_MODAL)

    -- Reset state
    _state = {
        entities = {},
        groups = {},
        layers = {},
        currentSection = 1,
        inputTimerId = nil,
    }

    log_debug("[NavDemo] Cleanup complete")
end

function ControllerNavDemo.isActive()
    return _active
end

function ControllerNavDemo.toggle()
    if _active then
        ControllerNavDemo.stop()
    else
        ControllerNavDemo.start()
    end
end

return ControllerNavDemo
