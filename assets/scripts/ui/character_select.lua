--[[
================================================================================
CHARACTER SELECT SCREEN
================================================================================
Character selection screen for choosing a God (patron deity) and Class (combat
style) before starting a run. Appears once per run, cannot be re-accessed mid-game.

USAGE:
------
local CharacterSelect = require("ui.character_select")

CharacterSelect.open()                  -- Show character select panel
CharacterSelect.close()                 -- Hide character select panel
CharacterSelect.toggle()                -- Toggle visibility
CharacterSelect.selectGod("pyr")        -- Select a god
CharacterSelect.selectClass("channeler")-- Select a class
CharacterSelect.randomize()             -- Randomly select both
CharacterSelect.confirm()               -- Confirm selection and start game

EVENTS (via hump.signal):
-------------------------
"character_select_opened"               -- Panel opened
"character_select_closed"               -- Panel closed
"character_select_god_changed"          -- God selection changed
"character_select_class_changed"        -- Class selection changed
"character_select_confirmed"            -- Selection confirmed, starting game

================================================================================
]]

local CharacterSelect = {}

--------------------------------------------------------------------------------
-- DEPENDENCIES
--------------------------------------------------------------------------------

-- Signal is optional in standalone mode (for testing without game engine)
local signal
pcall(function()
    signal = require("external.hump.signal")
end)

-- UI DSL is optional in standalone mode
local dsl
local strict  -- dsl.strict alias for schema validation
pcall(function()
    dsl = require("ui.ui_syntax_sugar")
    strict = dsl and dsl.strict
end)

-- UI scale is optional in standalone mode
local ui_scale
pcall(function()
    ui_scale = require("ui.ui_scale")
end)

-- Component cache is optional in standalone mode
local component_cache
pcall(function()
    component_cache = require("core.component_cache")
end)

-- Timer is optional in standalone mode
local timer
pcall(function()
    timer = require("core.timer")
end)

-- Helper to emit signals safely (no-op if signal not available)
local function emit(eventName, ...)
    if signal and signal.emit then
        signal.emit(eventName, ...)
    end
end

-- Helper to get localized text with fallback
local function L(key, fallback)
    if localization and localization.get then
        local result = localization.get(key)
        if result and result ~= key then return result end
    end
    return fallback or key
end

-- Helper to get UI-scaled value
local function UI(value)
    if ui_scale and ui_scale.ui then
        return ui_scale.ui(value)
    end
    return value
end

--------------------------------------------------------------------------------
-- LAYOUT CONSTANTS
--------------------------------------------------------------------------------

CharacterSelect.LAYOUT = {
    -- Portrait grid configuration
    GOD_ROW_SLOTS = 6,        -- 4 unlocked + 2 locked gods
    CLASS_ROW_SLOTS = 3,      -- 2 unlocked + 1 locked class

    -- Info zone split (percentage)
    INFO_GOD_WIDTH_PCT = 60,
    INFO_CLASS_WIDTH_PCT = 40,

    -- Animation timing (ms)
    SLIDE_IN_DURATION = 300,
    SLIDE_OUT_DURATION = 200,

    -- Panel dimensions (will be set dynamically based on screen)
    PANEL_PADDING = 10,
    PORTRAIT_SIZE = 64,
    PORTRAIT_SPACING = 8,
}

--------------------------------------------------------------------------------
-- VISUAL POLISH CONFIGURATION (CS-07)
--------------------------------------------------------------------------------

-- Particle aura configurations for selected gods
CharacterSelect.AURA_PARTICLES = {
    pyr = {
        sprite = "fire_particles",
        color = { 255, 120, 0 },  -- Orange/red
        rate = 20,
        lifetime = 0.8,
    },
    glah = {
        sprite = "ice_particles",
        color = { 100, 200, 255 },  -- Blue/cyan
        rate = 15,
        lifetime = 1.0,
    },
    vix = {
        sprite = "spark_particles",
        color = { 255, 255, 100 },  -- Yellow/white
        rate = 25,
        lifetime = 0.5,
    },
    ["nil"] = {
        sprite = "void_particles",
        color = { 128, 0, 255 },  -- Purple/black
        rate = 12,
        lifetime = 1.2,
    },
}

-- Sound effect keys for UI events
CharacterSelect.SOUNDS = {
    HOVER = "ui_hover",              -- Portrait hover
    SELECT = "ui_select",            -- Portrait/button select
    CONFIRM_ENABLED = "ui_ready",    -- Confirm button becomes enabled
    CONFIRM_PRESSED = "ui_confirm",  -- Confirm button pressed
    RANDOM = "ui_shuffle",           -- Random button pressed
}

--------------------------------------------------------------------------------
-- GOD DATA
--------------------------------------------------------------------------------

CharacterSelect.GOD_DATA = {
    pyr = {
        name_key = "god.pyr.name",
        lore_key = "god.pyr.lore",
        blessing_key = "god.pyr.blessing",
        passive_key = "god.pyr.passive",
        starterEquipment = "burning_gloves",
        starterArtifact = "ember_charm",
        portrait = "ui_god_pyr",
        aura = "fire",
        unlocked = true,
    },
    glah = {
        name_key = "god.glah.name",
        lore_key = "god.glah.lore",
        blessing_key = "god.glah.blessing",
        passive_key = "god.glah.passive",
        starterEquipment = "frost_gauntlets",
        starterArtifact = "ice_crystal",
        portrait = "ui_god_glah",
        aura = "ice",
        unlocked = true,
    },
    vix = {
        name_key = "god.vix.name",
        lore_key = "god.vix.lore",
        blessing_key = "god.vix.blessing",
        passive_key = "god.vix.passive",
        starterEquipment = "spark_bracers",
        starterArtifact = "lightning_rod",
        portrait = "ui_god_vix",
        aura = "lightning",
        unlocked = true,
    },
    ["nil"] = {
        name_key = "god.nil.name",
        lore_key = "god.nil.lore",
        blessing_key = "god.nil.blessing",
        passive_key = "god.nil.passive",
        starterEquipment = "void_wraps",
        starterArtifact = "void_shard",
        portrait = "ui_god_nil",
        aura = "void",
        unlocked = true,
    },
    -- Locked gods (demo placeholders)
    locked_god_1 = {
        name_key = "character_select.locked",
        lore_key = "character_select.locked",
        portrait = "ui_portrait_locked",
        unlocked = false,
        unlock_hint_key = "character_select.unlock_hint",
    },
    locked_god_2 = {
        name_key = "character_select.locked",
        lore_key = "character_select.locked",
        portrait = "ui_portrait_locked",
        unlocked = false,
        unlock_hint_key = "character_select.unlock_hint",
    },
}

--------------------------------------------------------------------------------
-- CLASS DATA
--------------------------------------------------------------------------------

CharacterSelect.CLASS_DATA = {
    channeler = {
        name_key = "class.channeler.name",
        lore_key = "class.channeler.lore",
        passive_key = "class.channeler.passive",
        triggered_key = "class.channeler.triggered",
        starterWand = "void_edge",
        portrait = "ui_class_channeler",
        unlocked = true,
    },
    seer = {
        name_key = "class.seer.name",
        lore_key = "class.seer.lore",
        passive_key = "class.seer.passive",
        triggered_key = "class.seer.triggered",
        starterWand = "sight_beam",
        portrait = "ui_class_seer",
        unlocked = true,
    },
    -- Locked class (demo placeholder)
    locked_class_1 = {
        name_key = "character_select.locked",
        lore_key = "character_select.locked",
        portrait = "ui_portrait_locked",
        unlocked = false,
        unlock_hint_key = "character_select.unlock_hint",
    },
}

--------------------------------------------------------------------------------
-- FOCUS SECTIONS
--------------------------------------------------------------------------------

CharacterSelect.FOCUS_SECTIONS = {
    GODS = 1,
    CLASSES = 2,
    BUTTONS = 3,
}

-- Button order for focus navigation
local BUTTON_ORDER = { "random", "confirm" }

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local state = {
    initialized = false,
    isVisible = false,
    panelEntity = nil,

    -- Selection state
    selectedGod = nil,
    selectedClass = nil,

    -- Focus state
    focusSection = 1,  -- GODS by default
    focusIndex = 1,    -- First item in section

    -- Persistence
    lastGod = nil,
    lastClass = nil,

    -- Callbacks
    onConfirm = nil,
}

--------------------------------------------------------------------------------
-- CORE API
--------------------------------------------------------------------------------

function CharacterSelect.open()
    if state.isVisible then return end

    state.isVisible = true

    -- Spawn the UI panel if game engine available
    if dsl then
        CharacterSelect.spawnPanel()
    end

    emit("character_select_opened")
end

function CharacterSelect.close()
    if not state.isVisible then return end

    state.isVisible = false

    -- Remove the UI panel if it exists
    if dsl and state.panelEntity then
        dsl.remove(state.panelEntity)
        state.panelEntity = nil
    end

    emit("character_select_closed")
end

function CharacterSelect.toggle()
    if state.isVisible then
        CharacterSelect.close()
    else
        CharacterSelect.open()
    end
end

function CharacterSelect.isOpen()
    return state.isVisible
end

function CharacterSelect.destroy()
    -- Clean up UI panel if it exists
    if dsl and state.panelEntity then
        dsl.remove(state.panelEntity)
    end

    state.initialized = false
    state.isVisible = false
    state.panelEntity = nil
    state.selectedGod = nil
    state.selectedClass = nil
    state.focusSection = 1
    state.focusIndex = 1
    state.onConfirm = nil
end

function CharacterSelect.getPanelEntity()
    return state.panelEntity
end

--------------------------------------------------------------------------------
-- SELECTION API
--------------------------------------------------------------------------------

function CharacterSelect.getSelectedGod()
    return state.selectedGod
end

function CharacterSelect.getSelectedClass()
    return state.selectedClass
end

function CharacterSelect.selectGod(godId)
    local godData = CharacterSelect.GOD_DATA[godId]
    if not godData then return false end
    if not godData.unlocked then return false end

    local previousGod = state.selectedGod
    state.selectedGod = godId

    if previousGod ~= godId then
        emit("character_select_god_changed", godId, previousGod)
    end
    return true
end

function CharacterSelect.selectClass(classId)
    local classData = CharacterSelect.CLASS_DATA[classId]
    if not classData then return false end
    if not classData.unlocked then return false end

    local previousClass = state.selectedClass
    state.selectedClass = classId

    if previousClass ~= classId then
        emit("character_select_class_changed", classId, previousClass)
    end
    return true
end

function CharacterSelect.isConfirmEnabled()
    return state.selectedGod ~= nil and state.selectedClass ~= nil
end

function CharacterSelect.randomize()
    -- Collect unlocked gods
    local unlockedGods = {}
    for id, data in pairs(CharacterSelect.GOD_DATA) do
        if data.unlocked then
            table.insert(unlockedGods, id)
        end
    end

    -- Collect unlocked classes
    local unlockedClasses = {}
    for id, data in pairs(CharacterSelect.CLASS_DATA) do
        if data.unlocked then
            table.insert(unlockedClasses, id)
        end
    end

    -- Random selection
    if #unlockedGods > 0 then
        local randomGodIndex = math.random(1, #unlockedGods)
        state.selectedGod = unlockedGods[randomGodIndex]
    end

    if #unlockedClasses > 0 then
        local randomClassIndex = math.random(1, #unlockedClasses)
        state.selectedClass = unlockedClasses[randomClassIndex]
    end
end

--------------------------------------------------------------------------------
-- INFO PANEL API
--------------------------------------------------------------------------------

function CharacterSelect.getGodInfo()
    if not state.selectedGod then return nil end
    local data = CharacterSelect.GOD_DATA[state.selectedGod]
    if not data then return nil end

    return {
        id = state.selectedGod,
        name_key = data.name_key,
        lore_key = data.lore_key,
        blessing_key = data.blessing_key,
        passive_key = data.passive_key,
        starterEquipment = data.starterEquipment,
        starterArtifact = data.starterArtifact,
        portrait = data.portrait,
        aura = data.aura,
    }
end

function CharacterSelect.getClassInfo()
    if not state.selectedClass then return nil end
    local data = CharacterSelect.CLASS_DATA[state.selectedClass]
    if not data then return nil end

    return {
        id = state.selectedClass,
        name_key = data.name_key,
        lore_key = data.lore_key,
        passive_key = data.passive_key,
        triggered_key = data.triggered_key,
        starterWand = data.starterWand,
        portrait = data.portrait,
    }
end

--------------------------------------------------------------------------------
-- CONFIRM API
--------------------------------------------------------------------------------

function CharacterSelect.setOnConfirm(callback)
    state.onConfirm = callback
end

function CharacterSelect.confirm()
    if not CharacterSelect.isConfirmEnabled() then
        return nil
    end

    local godData = CharacterSelect.GOD_DATA[state.selectedGod]
    local classData = CharacterSelect.CLASS_DATA[state.selectedClass]

    local selection = {
        god = state.selectedGod,
        class = state.selectedClass,
        godAura = godData.aura,  -- For particle effects on game start
        starterGear = {
            equipment = godData.starterEquipment,
            artifact = godData.starterArtifact,
        },
        starterWand = classData.starterWand,
    }

    -- Emit signal before callback
    emit("character_select_confirmed", selection)

    -- Call callback if set
    if state.onConfirm then
        state.onConfirm(selection)
    end

    return selection
end

--------------------------------------------------------------------------------
-- PERSISTENCE API
--------------------------------------------------------------------------------

function CharacterSelect.setLastSelection(godId, classId)
    state.lastGod = godId
    state.lastClass = classId
end

function CharacterSelect.getLastSelection()
    return state.lastGod, state.lastClass
end

function CharacterSelect.applyLastSelection()
    -- Validate and apply last god selection
    if state.lastGod then
        local godData = CharacterSelect.GOD_DATA[state.lastGod]
        if godData and godData.unlocked then
            state.selectedGod = state.lastGod
        end
    end

    -- Validate and apply last class selection
    if state.lastClass then
        local classData = CharacterSelect.CLASS_DATA[state.lastClass]
        if classData and classData.unlocked then
            state.selectedClass = state.lastClass
        end
    end
end

--------------------------------------------------------------------------------
-- FOCUS MANAGEMENT API
--------------------------------------------------------------------------------

-- Order arrays for focus navigation (must match UI scaffold order)
local FOCUS_GOD_ORDER = { "pyr", "glah", "vix", "nil", "locked_god_1", "locked_god_2" }
local FOCUS_CLASS_ORDER = { "channeler", "seer", "locked_class_1" }
local FOCUS_BUTTON_ORDER = { "random", "confirm" }

-- Get section size for wrapping
local function getSectionSize(section)
    if section == CharacterSelect.FOCUS_SECTIONS.GODS then
        return #FOCUS_GOD_ORDER
    elseif section == CharacterSelect.FOCUS_SECTIONS.CLASSES then
        return #FOCUS_CLASS_ORDER
    elseif section == CharacterSelect.FOCUS_SECTIONS.BUTTONS then
        return #FOCUS_BUTTON_ORDER
    end
    return 1
end

--- Get current focus section
--- @return number Section ID (1=GODS, 2=CLASSES, 3=BUTTONS)
function CharacterSelect.getFocusSection()
    return state.focusSection
end

--- Get current focus index within section
--- @return number 1-based index
function CharacterSelect.getFocusIndex()
    return state.focusIndex
end

--- Set focus to a specific section and index
--- @param section number Section ID
--- @param index number 1-based index
function CharacterSelect.setFocus(section, index)
    state.focusSection = section
    state.focusIndex = index
    emit("character_select_focus_changed", section, index)
end

--- Move focus right within current section (with wrap)
function CharacterSelect.moveFocusRight()
    local size = getSectionSize(state.focusSection)
    state.focusIndex = state.focusIndex + 1
    if state.focusIndex > size then
        state.focusIndex = 1
    end
    emit("character_select_focus_changed", state.focusSection, state.focusIndex)
end

--- Move focus left within current section (with wrap)
function CharacterSelect.moveFocusLeft()
    local size = getSectionSize(state.focusSection)
    state.focusIndex = state.focusIndex - 1
    if state.focusIndex < 1 then
        state.focusIndex = size
    end
    emit("character_select_focus_changed", state.focusSection, state.focusIndex)
end

--- Move to next focus section (Tab key)
function CharacterSelect.nextFocusSection()
    state.focusSection = state.focusSection + 1
    if state.focusSection > 3 then
        state.focusSection = 1
    end
    state.focusIndex = 1  -- Reset to first item in new section
    emit("character_select_focus_changed", state.focusSection, state.focusIndex)
end

--- Move to previous focus section (Shift+Tab)
function CharacterSelect.prevFocusSection()
    state.focusSection = state.focusSection - 1
    if state.focusSection < 1 then
        state.focusSection = 3
    end
    state.focusIndex = 1  -- Reset to first item in new section
    emit("character_select_focus_changed", state.focusSection, state.focusIndex)
end

--- Get the ID of the currently focused item
--- @return string|nil The god/class/button ID or nil
function CharacterSelect.getFocusedItemId()
    if state.focusSection == CharacterSelect.FOCUS_SECTIONS.GODS then
        return FOCUS_GOD_ORDER[state.focusIndex]
    elseif state.focusSection == CharacterSelect.FOCUS_SECTIONS.CLASSES then
        return FOCUS_CLASS_ORDER[state.focusIndex]
    elseif state.focusSection == CharacterSelect.FOCUS_SECTIONS.BUTTONS then
        return FOCUS_BUTTON_ORDER[state.focusIndex]
    end
    return nil
end

--- Activate the currently focused item (Enter/Space key)
function CharacterSelect.activateFocus()
    local itemId = CharacterSelect.getFocusedItemId()
    if not itemId then return end

    if state.focusSection == CharacterSelect.FOCUS_SECTIONS.GODS then
        -- Try to select the god (will fail silently if locked)
        CharacterSelect.selectGod(itemId)
    elseif state.focusSection == CharacterSelect.FOCUS_SECTIONS.CLASSES then
        -- Try to select the class (will fail silently if locked)
        CharacterSelect.selectClass(itemId)
    elseif state.focusSection == CharacterSelect.FOCUS_SECTIONS.BUTTONS then
        if itemId == "random" then
            CharacterSelect.randomize()
        elseif itemId == "confirm" then
            CharacterSelect.confirm()
        end
    end
end

--------------------------------------------------------------------------------
-- VISUAL STATE HELPERS (CS-07)
--------------------------------------------------------------------------------

--- Check if a specific item is currently focused
--- @param id string The item ID (god/class/button name)
--- @param itemType string The item type: "god", "class", or "button"
--- @return boolean True if this item is currently focused
function CharacterSelect.isItemFocused(id, itemType)
    -- Map itemType to section constant
    local expectedSection
    local orderArray
    if itemType == "god" then
        expectedSection = CharacterSelect.FOCUS_SECTIONS.GODS
        orderArray = FOCUS_GOD_ORDER
    elseif itemType == "class" then
        expectedSection = CharacterSelect.FOCUS_SECTIONS.CLASSES
        orderArray = FOCUS_CLASS_ORDER
    elseif itemType == "button" then
        expectedSection = CharacterSelect.FOCUS_SECTIONS.BUTTONS
        orderArray = FOCUS_BUTTON_ORDER
    else
        return false
    end

    -- Check if we're in the right section
    if state.focusSection ~= expectedSection then
        return false
    end

    -- Check if the focused item matches the given ID
    local focusedId = orderArray[state.focusIndex]
    return focusedId == id
end

--- Check if a specific item is currently selected
--- @param id string The item ID (god/class name)
--- @param itemType string The item type: "god" or "class"
--- @return boolean True if this item is currently selected
function CharacterSelect.isItemSelected(id, itemType)
    if itemType == "god" then
        return state.selectedGod == id
    elseif itemType == "class" then
        return state.selectedClass == id
    end
    return false
end

--------------------------------------------------------------------------------
-- UI SCAFFOLD (requires game engine)
--------------------------------------------------------------------------------

-- Order for god portraits (left-to-right)
local GOD_ORDER = { "pyr", "glah", "vix", "nil", "locked_god_1", "locked_god_2" }

-- Order for class portraits (left-to-right)
local CLASS_ORDER = { "channeler", "seer", "locked_class_1" }

--- Create a portrait button for a god or class
--- @param id string The god/class ID
--- @param data table The god/class data
--- @param isGod boolean True if this is a god, false for class
--- @return table DSL node for the portrait
local function createPortrait(id, data, isGod)
    if not dsl then return nil end

    local isLocked = not data.unlocked
    local isSelected = isGod and (state.selectedGod == id) or (state.selectedClass == id)

    -- Portrait container with selection highlight
    local portraitColor = isLocked and "charcoal" or (isSelected and "gold" or "slate")

    return strict.vbox {
        config = {
            id = "portrait_" .. id,
            padding = UI(4),
            spacing = UI(2),
            color = portraitColor,
            minWidth = UI(CharacterSelect.LAYOUT.PORTRAIT_SIZE),
            minHeight = UI(CharacterSelect.LAYOUT.PORTRAIT_SIZE + 20),
        },
        children = {
            -- Portrait sprite
            strict.anim(data.portrait, {
                w = UI(CharacterSelect.LAYOUT.PORTRAIT_SIZE),
                h = UI(CharacterSelect.LAYOUT.PORTRAIT_SIZE),
            }),
            -- Name label (short)
            strict.text(L(data.name_key, id), {
                fontSize = UI(10),
                color = isLocked and "gray" or "white",
            }),
        },
        onClick = isLocked and nil or function()
            if isGod then
                CharacterSelect.selectGod(id)
            else
                CharacterSelect.selectClass(id)
            end
            CharacterSelect.refreshUI()
        end,
    }
end

--- Create the god selection row
--- @return table DSL node for the god row
local function createGodRow()
    if not dsl then return nil end

    local children = {}
    for _, godId in ipairs(GOD_ORDER) do
        local data = CharacterSelect.GOD_DATA[godId]
        if data then
            table.insert(children, createPortrait(godId, data, true))
        end
    end

    return strict.hbox {
        config = {
            id = "god_row",
            spacing = UI(CharacterSelect.LAYOUT.PORTRAIT_SPACING),
            padding = UI(8),
        },
        children = children,
    }
end

--- Create the class selection row
--- @return table DSL node for the class row
local function createClassRow()
    if not dsl then return nil end

    local children = {}
    for _, classId in ipairs(CLASS_ORDER) do
        local data = CharacterSelect.CLASS_DATA[classId]
        if data then
            table.insert(children, createPortrait(classId, data, false))
        end
    end

    return strict.hbox {
        config = {
            id = "class_row",
            spacing = UI(CharacterSelect.LAYOUT.PORTRAIT_SPACING),
            padding = UI(8),
        },
        children = children,
    }
end

--- Create the god info panel (left 60%)
--- @return table DSL node for god info
local function createGodInfoPanel()
    if not dsl then return nil end

    local info = CharacterSelect.getGodInfo()

    if not info then
        return strict.vbox {
            config = { id = "god_info", padding = UI(10), color = "charcoal" },
            children = {
                strict.text(L("character_select.select_god", "Select a God"), {
                    fontSize = UI(16),
                    color = "gray",
                }),
            },
        }
    end

    return strict.vbox {
        config = {
            id = "god_info",
            padding = UI(10),
            spacing = UI(6),
            color = "charcoal",
        },
        children = {
            -- God name
            strict.text(L(info.name_key, info.id), {
                fontSize = UI(18),
                color = "gold",
            }),
            -- Lore/description
            strict.text(L(info.lore_key, ""), {
                fontSize = UI(12),
                color = "white",
            }),
            strict.divider("horizontal", { color = "slate" }),
            -- Blessing label
            strict.text(L("character_select.blessing", "Blessing:"), {
                fontSize = UI(12),
                color = "cyan",
            }),
            strict.text(L(info.blessing_key, ""), {
                fontSize = UI(11),
                color = "white",
            }),
            -- Passive label
            strict.text(L("character_select.passive", "Passive:"), {
                fontSize = UI(12),
                color = "green",
            }),
            strict.text(L(info.passive_key, ""), {
                fontSize = UI(11),
                color = "white",
            }),
        },
    }
end

--- Create the class info panel (right 40%)
--- @return table DSL node for class info
local function createClassInfoPanel()
    if not dsl then return nil end

    local info = CharacterSelect.getClassInfo()

    if not info then
        return strict.vbox {
            config = { id = "class_info", padding = UI(10), color = "charcoal" },
            children = {
                strict.text(L("character_select.select_class", "Select a Class"), {
                    fontSize = UI(16),
                    color = "gray",
                }),
            },
        }
    end

    return strict.vbox {
        config = {
            id = "class_info",
            padding = UI(10),
            spacing = UI(6),
            color = "charcoal",
        },
        children = {
            -- Class name
            strict.text(L(info.name_key, info.id), {
                fontSize = UI(18),
                color = "gold",
            }),
            -- Lore/description
            strict.text(L(info.lore_key, ""), {
                fontSize = UI(12),
                color = "white",
            }),
            strict.divider("horizontal", { color = "slate" }),
            -- Passive label
            strict.text(L("character_select.passive", "Passive:"), {
                fontSize = UI(12),
                color = "green",
            }),
            strict.text(L(info.passive_key, ""), {
                fontSize = UI(11),
                color = "white",
            }),
            -- Triggered ability
            strict.text(L("character_select.triggered", "Triggered:"), {
                fontSize = UI(12),
                color = "orange",
            }),
            strict.text(L(info.triggered_key, ""), {
                fontSize = UI(11),
                color = "white",
            }),
        },
    }
end

--- Create the info zone (god info left, class info right)
--- @return table DSL node for info zone
local function createInfoZone()
    if not dsl then return nil end

    return strict.hbox {
        config = {
            id = "info_zone",
            spacing = UI(10),
            padding = UI(10),
        },
        children = {
            createGodInfoPanel(),
            createClassInfoPanel(),
        },
    }
end

--- Create the button row (Random, Confirm)
--- @return table DSL node for button row
local function createButtonRow()
    if not dsl then return nil end

    local confirmEnabled = CharacterSelect.isConfirmEnabled()

    return strict.hbox {
        config = {
            id = "button_row",
            spacing = UI(20),
            padding = UI(10),
        },
        children = {
            -- Random button (left side)
            strict.button(L("character_select.random", "Random"), {
                minWidth = UI(100),
                color = "blue",
                onClick = function()
                    CharacterSelect.randomize()
                    CharacterSelect.refreshUI()
                end,
            }),
            -- Filler to push Confirm to right side
            dsl.filler and dsl.filler() or strict.spacer(UI(100)),
            -- Confirm button (right side)
            strict.button(L("character_select.confirm", "Confirm"), {
                minWidth = UI(120),
                color = confirmEnabled and "green" or "charcoal",
                disabled = not confirmEnabled,
                onClick = function()
                    if CharacterSelect.isConfirmEnabled() then
                        CharacterSelect.confirm()
                        CharacterSelect.close()
                    end
                end,
            }),
        },
    }
end

--- Create the full panel definition
--- @return table DSL root node for the character select panel
local function createPanelDefinition()
    if not dsl then return nil end

    return strict.root {
        config = {
            id = "character_select_panel",
            color = "blackberry",
            padding = UI(CharacterSelect.LAYOUT.PANEL_PADDING),
        },
        children = {
            strict.vbox {
                config = {
                    spacing = UI(10),
                },
                children = {
                    -- Title
                    strict.text(L("character_select.title", "Choose Your Path"), {
                        fontSize = UI(24),
                        color = "white",
                    }),
                    -- Gods section
                    strict.text(L("character_select.gods_label", "Patron God"), {
                        fontSize = UI(14),
                        color = "gold",
                    }),
                    createGodRow(),
                    -- Classes section
                    strict.text(L("character_select.classes_label", "Combat Style"), {
                        fontSize = UI(14),
                        color = "gold",
                    }),
                    createClassRow(),
                    -- Divider
                    strict.divider("horizontal", { color = "slate" }),
                    -- Info zone
                    createInfoZone(),
                    -- Buttons
                    createButtonRow(),
                },
            },
        },
    }
end

--- Spawn the character select panel
--- @return entity|nil The panel entity or nil if DSL not available
function CharacterSelect.spawnPanel()
    if not dsl then return nil end
    if state.panelEntity then return state.panelEntity end

    -- Get screen dimensions (function calls per player_inventory.lua pattern)
    local screenWidth = globals and globals.screenWidth and globals.screenWidth() or 800
    local screenHeight = globals and globals.screenHeight and globals.screenHeight() or 600

    local panelDef = createPanelDefinition()
    if not panelDef then return nil end

    -- Center the panel
    local x = screenWidth / 2
    local y = screenHeight / 2

    -- Get z-order from constants if available
    local panelZ = 800  -- Default fallback
    pcall(function()
        local z_orders = require("core.z_orders")
        if z_orders and z_orders.CHARACTER_SELECT then
            panelZ = z_orders.CHARACTER_SELECT
        elseif z_orders and z_orders.OVERLAY then
            panelZ = z_orders.OVERLAY
        end
    end)

    state.panelEntity = dsl.spawn({ x = x, y = y }, panelDef, "ui", panelZ)
    state.initialized = true

    -- CRITICAL: Add state tags to UI boxes so they render
    if ui and ui.box and ui.box.AddStateTagToUIBox and registry then
        ui.box.AddStateTagToUIBox(registry, state.panelEntity, "default_state")
    end

    -- CRITICAL: Renew alignment after spawn
    if ui and ui.box and ui.box.RenewAlignment and registry then
        ui.box.RenewAlignment(registry, state.panelEntity)
    end

    return state.panelEntity
end

--- Refresh the UI to reflect current selection state
function CharacterSelect.refreshUI()
    if not state.panelEntity then return end
    if not dsl then return end

    -- Destroy and respawn with updated state
    dsl.remove(state.panelEntity)
    state.panelEntity = nil
    CharacterSelect.spawnPanel()

    -- RenewAlignment is called inside spawnPanel, no need to call again
end

--- Check if running with game engine (has DSL available)
--- @return boolean True if game engine is available
function CharacterSelect.hasGameEngine()
    return dsl ~= nil
end

return CharacterSelect
