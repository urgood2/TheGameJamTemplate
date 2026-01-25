--[[
================================================================================
SKILLS PANEL - Right-Aligned Skills Selection Panel
================================================================================

A slide-out panel on the right edge of the screen displaying all available
skills organized by element (Fire, Ice, Lightning, Void).

USAGE:
------
local SkillsPanel = require("ui.skills_panel")

SkillsPanel.open()           -- Show panel
SkillsPanel.close()          -- Hide panel
SkillsPanel.toggle()         -- Toggle visibility
SkillsPanel.isOpen()         -- Check if visible

EVENTS (via hump.signal):
-------------------------
"skills_panel_opened"        -- Panel opened
"skills_panel_closed"        -- Panel closed
"skill_button_clicked"       -- Skill button clicked (for modal)

================================================================================
]]

local SkillsPanel = {}

--------------------------------------------------------------------------------
-- DEPENDENCIES (safe requires for unit testing)
--------------------------------------------------------------------------------

local function safeRequire(module)
    local ok, result = pcall(require, module)
    return ok and result or nil
end

local Skills = safeRequire("data.skills")
local SkillSystem = safeRequire("core.skill_system")
local signal = safeRequire("external.hump.signal")
local timer = safeRequire("core.timer")
local ui_scale = safeRequire("ui.ui_scale")
local z_orders = safeRequire("core.z_orders")
local dsl = safeRequire("ui.ui_syntax_sugar")
local component_cache = _G.component_cache or { get = function() return nil end }

--------------------------------------------------------------------------------
-- CONFIGURATION
--------------------------------------------------------------------------------

local CONFIG = {
    -- Element columns
    columns = 4,
    rows = 8,

    -- Unlocked/locked elements for demo
    unlocked_elements = { "fire", "ice", "lightning" },
    locked_elements = { "void" },

    -- Element column order
    element_order = { "fire", "ice", "lightning", "void" },

    -- Sprites
    -- TODO: Create dedicated skills-panel sprites
    -- Using placeholder sprites until skill icons are created
    skill_icon_sprite = "button-test-normal",
    locked_sprite = "button-test-disabled",
    learned_overlay = "button-test-pressed",  -- Placeholder checkmark sprite
    panel_background = "inventory-back-panel",

    -- Hotkey
    toggle_key = "K",
}

-- Build locked lookup table
local LOCKED_ELEMENTS = {}
for _, elem in ipairs(CONFIG.locked_elements) do
    LOCKED_ELEMENTS[elem] = true
end

--------------------------------------------------------------------------------
-- UI DIMENSIONS
--------------------------------------------------------------------------------

local UI = ui_scale and ui_scale.ui or function(x) return x end
local SPRITE_SCALE = ui_scale and ui_scale.SPRITE_SCALE or 1

local SLOT_BASE_SIZE = 48
local SLOT_SIZE = UI(SLOT_BASE_SIZE)
local SLOT_SPACING = UI(0)  -- No spacing between grid cells
local GRID_PADDING = UI(2)  -- Minimal grid padding
local HEADER_HEIGHT = UI(24)  -- Compact header
local HEADER_SPACING = UI(1)  -- Near-zero spacing between sections
local COLUMN_HEADER_HEIGHT = UI(14)  -- Compact column headers
local PANEL_PADDING = UI(4)  -- Minimal panel padding
local SEARCH_BAR_HEIGHT = UI(22)  -- Compact search bar

-- Grid dimensions (4 columns × 8 rows)
local GRID_WIDTH = CONFIG.columns * SLOT_SIZE + (CONFIG.columns - 1) * SLOT_SPACING + GRID_PADDING * 2
local GRID_HEIGHT = CONFIG.rows * SLOT_SIZE + (CONFIG.rows - 1) * SLOT_SPACING + GRID_PADDING * 2

-- Panel dimensions
local PANEL_WIDTH = GRID_WIDTH + PANEL_PADDING * 2
local COLUMN_HEADER_BLOCK_HEIGHT = COLUMN_HEADER_HEIGHT + UI(2)  -- Minimal header block padding
local PANEL_HEIGHT = HEADER_HEIGHT
    + HEADER_SPACING
    + SEARCH_BAR_HEIGHT
    + HEADER_SPACING
    + COLUMN_HEADER_BLOCK_HEIGHT
    + HEADER_SPACING
    + GRID_HEIGHT
    + PANEL_PADDING * 2

local RENDER_LAYER = "ui"
local PANEL_Z = 800
local TIMER_GROUP = "skills_panel"

--------------------------------------------------------------------------------
-- MODULE STATE
--------------------------------------------------------------------------------

local state = {
    initialized = false,
    isVisible = false,
    panelEntity = nil,
    gridEntity = nil,
    skillButtons = {},       -- skillId -> buttonEntity
    headerTextEntity = nil,
    searchInputEntity = nil,
    panelX = 0,
    panelY = 0,
    hiddenX = 0,
    player = nil,            -- Reference to player for skill point queries
    activeTooltipKey = nil,
    entityTooltipKeys = {},  -- Lua-side storage for entity tooltip keys (can't store on C++ userdata)
    searchText = "",         -- Current search filter text
    matchingSkills = {},     -- Set of skill IDs that match current search
    searchFocused = false,   -- True when search input has keyboard focus
}

--------------------------------------------------------------------------------
-- HELPER FUNCTIONS
--------------------------------------------------------------------------------

local function getLocalizedText(key, fallback)
    if localization and localization.get then
        local text = localization.get(key)
        if text and text ~= key then
            return text
        end
    end
    return fallback or key
end

local function isElementLocked(element)
    return LOCKED_ELEMENTS[element] == true
end

--------------------------------------------------------------------------------
-- SEARCH FUNCTIONALITY
--------------------------------------------------------------------------------

--- Check if a skill matches the search query
--- @param skillDef table Skill definition
--- @param query string Search query (lowercase)
--- @return boolean True if the skill matches
local function skillMatchesSearch(skillDef, query)
    if not skillDef or not query or query == "" then
        return true  -- Empty query matches all
    end

    -- Search in name (case-insensitive)
    if skillDef.name and string.find(string.lower(skillDef.name), query, 1, true) then
        return true
    end

    -- Search in element (case-insensitive)
    if skillDef.element and string.find(string.lower(skillDef.element), query, 1, true) then
        return true
    end

    -- Search in description (case-insensitive)
    if skillDef.description and string.find(string.lower(skillDef.description), query, 1, true) then
        return true
    end

    -- Search in ID (case-insensitive)
    if skillDef.id and string.find(string.lower(skillDef.id), query, 1, true) then
        return true
    end

    return false
end

--- Update the set of matching skills based on search text
--- @param searchText string The search query
local function updateMatchingSkills(searchText)
    state.matchingSkills = {}
    local query = searchText and string.lower(searchText) or ""

    if query == "" then
        -- Empty search = all skills match
        return
    end

    if not Skills then return end

    -- Check each skill for matches
    local gridData = SkillsPanel.getGridData()
    for _, element in ipairs(CONFIG.element_order) do
        local skills = gridData[element]
        if skills then
            for _, entry in ipairs(skills) do
                if entry and entry.def and skillMatchesSearch(entry.def, query) then
                    state.matchingSkills[entry.id] = true
                end
            end
        end
    end
end

--- Check if a skill should be highlighted (matches current search)
--- @param skillId string Skill ID
--- @return boolean True if the skill matches and should be highlighted
local function isSkillHighlighted(skillId)
    -- If no search text, nothing is highlighted (all visible)
    if not state.searchText or state.searchText == "" then
        return false
    end
    -- If there's search text, return true only for matching skills
    return state.matchingSkills[skillId] == true
end

--- Check if a skill should be dimmed (doesn't match current search)
--- @param skillId string Skill ID
--- @return boolean True if the skill should be dimmed
local function isSkillDimmed(skillId)
    -- If no search text, nothing is dimmed
    if not state.searchText or state.searchText == "" then
        return false
    end
    -- If there's search text, dim non-matching skills
    return state.matchingSkills[skillId] ~= true
end

--------------------------------------------------------------------------------
-- SKILL BUTTON STATE
--------------------------------------------------------------------------------

--- Determine the visual state of a skill button
--- @param player table Player object with skill_points and skill_state
--- @param skillId string Skill ID
--- @return string "locked", "learned", "available", or "insufficient"
function SkillsPanel.getSkillButtonState(player, skillId)
    if not Skills or not SkillSystem then return "locked" end

    local skill = Skills.get(skillId)
    if not skill then return "locked" end

    -- Check if element is locked for demo
    if isElementLocked(skill.element) then
        return "locked"
    end

    -- Check if already learned
    if SkillSystem.has_skill(player, skillId) then
        return "learned"
    end

    -- Check if can afford
    if SkillSystem.can_learn_skill(player, skillId) then
        return "available"
    end

    return "insufficient"
end

--------------------------------------------------------------------------------
-- GRID DATA
--------------------------------------------------------------------------------

--- Get skills organized by element for the grid
--- @return table { fire = {...}, ice = {...}, lightning = {...}, void = {...} }
function SkillsPanel.getGridData()
    if not Skills then return {} end

    local gridData = {}
    for _, element in ipairs(CONFIG.element_order) do
        gridData[element] = Skills.getOrderedByElement(element)
    end
    return gridData
end

--------------------------------------------------------------------------------
-- SKILL POINTS DISPLAY
--------------------------------------------------------------------------------

--- Get formatted skill points display string
--- @param player table Player object
--- @return string "Skill Points: X/Y"
function SkillsPanel.getSkillPointsDisplay(player)
    if not SkillSystem then return "Skill Points: 0/0" end

    local remaining = SkillSystem.get_skill_points_remaining(player)
    local total = player and player.skill_points or 0

    return string.format("Skill Points: %d/%d", remaining, total)
end

--------------------------------------------------------------------------------
-- CONFIGURATION ACCESS
--------------------------------------------------------------------------------

--- Get panel configuration
--- @return table Configuration table
function SkillsPanel.getConfig()
    return CONFIG
end

--- Get panel dimensions for tab marker positioning
--- @return number width Panel width in pixels
--- @return number height Panel height in pixels
function SkillsPanel.getPanelDimensions()
    return PANEL_WIDTH, PANEL_HEIGHT
end

--------------------------------------------------------------------------------
-- POSITION CALCULATION
--------------------------------------------------------------------------------

local function calculatePositions()
    local screenWidth = GetScreenWidth and GetScreenWidth() or 1920
    local screenHeight = GetScreenHeight and GetScreenHeight() or 1080

    -- Panel on right edge, vertically centered
    state.panelX = screenWidth - PANEL_WIDTH - PANEL_PADDING
    local desiredY = (screenHeight - PANEL_HEIGHT) / 2
    local minY = PANEL_PADDING
    local maxY = math.max(minY, screenHeight - PANEL_HEIGHT - PANEL_PADDING)
    state.panelY = math.max(minY, math.min(maxY, desiredY))
    state.hiddenX = screenWidth + PANEL_PADDING  -- Offscreen to the right

    return true
end

--------------------------------------------------------------------------------
-- VISIBILITY CONTROL
--------------------------------------------------------------------------------

local function setEntityVisible(entity, visible, onscreenX, onscreenY, offscreenX)
    if not entity then return end
    if not _G.registry or not _G.registry.valid or not _G.registry:valid(entity) then return end

    local hiddenX = offscreenX or (onscreenX - PANEL_WIDTH - PANEL_PADDING)
    local targetX = visible and onscreenX or hiddenX
    local targetY = onscreenY

    -- Update Transform
    local t = component_cache.get(entity, Transform)
    if t then
        t.actualX = targetX
        t.actualY = targetY
    end

    -- Update InheritedProperties offset
    local role = component_cache.get(entity, InheritedProperties)
    if role and role.offset then
        role.offset.x = targetX
        role.offset.y = targetY
    end

    -- For UIBox entities, also update uiRoot
    local boxComp = component_cache.get(entity, UIBoxComponent)
    if boxComp and boxComp.uiRoot and _G.registry:valid(boxComp.uiRoot) then
        local rt = component_cache.get(boxComp.uiRoot, Transform)
        if rt then
            rt.actualX = targetX
            rt.actualY = targetY
        end
        local rootRole = component_cache.get(boxComp.uiRoot, InheritedProperties)
        if rootRole and rootRole.offset then
            rootRole.offset.x = targetX
            rootRole.offset.y = targetY
        end

        -- Force layout recalculation
        if ui and ui.box and ui.box.RenewAlignment then
            ui.box.RenewAlignment(_G.registry, entity)
        end
    end
end

--------------------------------------------------------------------------------
-- UI BUILDING (Requires game engine)
--------------------------------------------------------------------------------
-- NOTE: Signal handling (skill_learned, skill_unlearned, player_level_up)
-- is consolidated in skills_panel_input.lua to avoid duplicate handlers.

-- Element colors - must be string color names for dsl.strict compatibility
local ELEMENT_COLORS = {
    fire = "gold",
    ice = "cyan",
    lightning = "amber",
    void = "purple_slate",
}

local TOOLTIP_OFFSET_X = UI(8)
local TOOLTIP_TITLE_SIZE = UI(14)
local TOOLTIP_BODY_SIZE = UI(11)
local TOOLTIP_MAX_WIDTH = UI(220)

--- Create the header row with title and skill points
local function createHeader()
    if not dsl then return nil end

    return dsl.strict.hbox {
        config = {
            id = "skills_header",
            padding = UI(2),  -- Compact padding
            minHeight = HEADER_HEIGHT,
            align = "center",
        },
        children = {
            dsl.strict.text("Skills", {
                id = "skills_title",
                fontSize = UI(12),  -- Smaller font
                color = "white",
            }),
            dsl.strict.spacer(UI(8)),  -- Less spacing
            dsl.strict.text("Points: 0/0", {
                id = "skills_points_display",
                fontSize = UI(10),  -- Smaller font
                color = "yellow",
            }),
        },
    }
end

--- Handle search text changes
--- @param newText string The new search text
local function onSearchTextChanged(newText)
    state.searchText = newText or ""
    updateMatchingSkills(state.searchText)

    -- Refresh skill button visuals to apply highlighting
    SkillsPanel.refreshButtonStates()
end

--- Create the search bar for filtering skills
local function createSearchBar()
    if not dsl then return nil end

    return dsl.strict.hbox {
        config = {
            id = "search_bar_container",
            padding = UI(1),  -- Minimal padding
            minHeight = SEARCH_BAR_HEIGHT,
            minWidth = GRID_WIDTH,
            align = "center",
        },
        children = {
            dsl.strict.text("Search:", {
                fontSize = UI(9),  -- Smaller font
                color = "gray",
            }),
            dsl.strict.spacer(UI(3)),  -- Less spacer
            dsl.inputText({
                id = "skills_search_input",
                placeholder = "name, element...",
                minWidth = GRID_WIDTH - UI(48),  -- More space for input
                minHeight = SEARCH_BAR_HEIGHT - UI(2),
                fontSize = UI(9),  -- Smaller font
                color = "white",
                backgroundColor = "blackberry",
                emboss = 1,
                onTextChange = onSearchTextChanged,
            }),
        },
    }
end

--- Create the element column headers (Fire, Ice, Lightning, Void)
--- Headers are aligned with grid columns by using the same width as skill buttons
local function createColumnHeaders()
    if not dsl then return nil end

    local headers = {}
    for _, element in ipairs(CONFIG.element_order) do
        local color = ELEMENT_COLORS[element] or "white"
        local isLocked = LOCKED_ELEMENTS[element]

        -- Wrap text in hbox with same width as skill buttons to align with grid
        table.insert(headers, dsl.strict.hbox {
            config = {
                id = "header_" .. element,
                minWidth = SLOT_SIZE,
                minHeight = COLUMN_HEADER_HEIGHT,
                align = "center",
            },
            children = {
                dsl.strict.text(element:sub(1,1):upper() .. element:sub(2), {
                    fontSize = UI(8),  -- Smaller compact font
                    color = isLocked and "gray" or color,
                }),
            },
        })

        -- Add spacing between columns (except after last) - matches grid spacing
        if element ~= CONFIG.element_order[#CONFIG.element_order] then
            table.insert(headers, dsl.strict.spacer(SLOT_SPACING))
        end
    end

    return dsl.strict.hbox {
        config = {
            id = "column_headers",
            padding = GRID_PADDING,
            minWidth = GRID_WIDTH,
            minHeight = COLUMN_HEADER_BLOCK_HEIGHT,
        },
        children = headers,
    }
end

--- Build tooltip body text for a skill
--- @param skillDef table Skill definition
--- @param element string Element name
--- @param buttonState string Current button state
--- @param isLocked boolean Whether the element is locked
--- @return string Formatted tooltip body
local function buildSkillTooltipBody(skillDef, element, buttonState, isLocked)
    local lines = {}

    -- Element and cost
    local elementName = element:sub(1,1):upper() .. element:sub(2)
    table.insert(lines, elementName .. " • Cost: " .. (skillDef.cost or 1) .. " point(s)")

    -- Description
    if skillDef.description then
        table.insert(lines, "")
        table.insert(lines, skillDef.description)
    end

    -- Status indicator
    if isLocked then
        table.insert(lines, "")
        table.insert(lines, "[LOCKED - Complete demo to unlock]")
    elseif buttonState == "learned" then
        table.insert(lines, "")
        table.insert(lines, "[LEARNED]")
    elseif buttonState == "insufficient" then
        table.insert(lines, "")
        table.insert(lines, "[Not enough skill points]")
    elseif buttonState == "available" then
        table.insert(lines, "")
        table.insert(lines, "[Click to learn]")
    end

    return table.concat(lines, "\n")
end

local function showSkillTooltip(anchorEntity, tooltipKey, tooltipTitle, tooltipBody)
    if not ensureSimpleTooltip then return end

    local tooltip = ensureSimpleTooltip(tooltipKey, tooltipTitle, tooltipBody, {
        titleFontSize = TOOLTIP_TITLE_SIZE,
        bodyFontSize = TOOLTIP_BODY_SIZE,
        maxWidth = TOOLTIP_MAX_WIDTH,
    })

    if not tooltip or not _G.registry or not _G.registry.valid or not _G.registry:valid(tooltip) then
        return
    end

    if ui and ui.box and ui.box.AddStateTagToUIBox then
        ui.box.ClearStateTagsFromUIBox(tooltip)
        if PLANNING_STATE then ui.box.AddStateTagToUIBox(tooltip, PLANNING_STATE) end
        if ACTION_STATE then ui.box.AddStateTagToUIBox(tooltip, ACTION_STATE) end
        if SHOP_STATE then ui.box.AddStateTagToUIBox(tooltip, SHOP_STATE) end
    end

    local anchor = component_cache.get(anchorEntity, Transform)
    local tt = component_cache.get(tooltip, Transform)
    if anchor and tt then
        local anchorX = anchor.actualX or 0
        local anchorY = anchor.actualY or 0
        local anchorW = anchor.actualW or SLOT_SIZE
        local anchorH = anchor.actualH or SLOT_SIZE
        local tooltipH = tt.actualH or 0

        local tooltipX = anchorX + anchorW + TOOLTIP_OFFSET_X
        local tooltipY = anchorY + (anchorH - tooltipH) * 0.5

        tt.actualX = tooltipX
        tt.actualY = tooltipY
        tt.visualX = tt.actualX
        tt.visualY = tt.actualY
    end
end

local function attachSkillTooltipHandlers(skillId, element)
    if not _G.registry or not ui or not ui.box or not ui.box.GetUIEByID then return end

    local entity = ui.box.GetUIEByID(_G.registry, state.panelEntity, "skill_btn_" .. skillId)
    if not entity then return end

    local go = component_cache.get(entity, GameObject)
    if not go then return end

    go.state.hoverEnabled = true
    go.state.collisionEnabled = true

    go.methods.onHover = function()
        local skillDef = Skills and Skills.get and Skills.get(skillId) or nil
        local skillElement = element or (skillDef and skillDef.element) or "unknown"
        local isLocked = isElementLocked(skillElement)
        local buttonState = state.player and SkillsPanel.getSkillButtonState(state.player, skillId) or "locked"
        local tooltipTitle = (skillDef and skillDef.name) or skillId
        local tooltipBody = buildSkillTooltipBody(skillDef or {}, skillElement, buttonState, isLocked)
        local tooltipKey = "skills_panel_" .. skillId .. "_" .. buttonState

        -- Store in Lua-side table (can't set properties on C++ userdata)
        state.entityTooltipKeys[entity] = tooltipKey
        state.activeTooltipKey = tooltipKey
        showSkillTooltip(entity, tooltipKey, tooltipTitle, tooltipBody)
    end

    go.methods.onStopHover = function()
        local tooltipKey = state.entityTooltipKeys[entity]
        if hideSimpleTooltip and tooltipKey then
            hideSimpleTooltip(tooltipKey)
        end
        if state.activeTooltipKey == tooltipKey then
            state.activeTooltipKey = nil
        end
        state.entityTooltipKeys[entity] = nil
    end
end

local function applySkillTooltips()
    if not state.panelEntity or not ui or not ui.box or not ui.box.GetUIEByID then return end

    local gridData = SkillsPanel.getGridData()
    if not gridData then return end

    for _, element in ipairs(CONFIG.element_order) do
        local skills = gridData[element]
        if skills then
            for _, entry in ipairs(skills) do
                if entry and entry.id then
                    attachSkillTooltipHandlers(entry.id, element)
                end
            end
        end
    end
end

--- Create a single skill button
--- @param skillId string Skill ID
--- @param skillDef table Skill definition from skills.lua
--- @param element string Element name
--- @param isLocked boolean Whether element is locked for demo
local function createSkillButton(skillId, skillDef, element, isLocked)
    if not dsl then return nil end

    local buttonState = state.player and SkillsPanel.getSkillButtonState(state.player, skillId) or "locked"
    local isLearned = buttonState == "learned"
    local isAvailable = buttonState == "available"
    local isInsufficient = buttonState == "insufficient"

    -- Check search matching for visual highlighting
    local isDimmed = isSkillDimmed(skillId)
    local isHighlighted = isSkillHighlighted(skillId)

    -- Use placeholder sprites for all icons (skill, lock, checkmark)
    local skillSprite = CONFIG.skill_icon_sprite or "test-inventory-square-single"
    local lockedSprite = CONFIG.locked_sprite or skillSprite
    local learnedSprite = CONFIG.learned_overlay or skillSprite

    local sprite = skillSprite
    if isLocked then
        sprite = lockedSprite
    elseif isLearned then
        sprite = learnedSprite
    end

    -- Determine background color based on search state
    local bgColor = nil
    if isHighlighted then
        -- Highlight matching skills with element color glow
        bgColor = ELEMENT_COLORS[element] or "gold"
    elseif isDimmed then
        -- Dim non-matching skills with dark overlay
        bgColor = "blackberry"
    end

    local children = {
        dsl.strict.anim(sprite .. ".png", {
            w = SLOT_SIZE - UI(4),
            h = SLOT_SIZE - UI(4),
        }),
    }

    return dsl.strict.hbox {
        config = {
            id = "skill_btn_" .. skillId,
            minWidth = SLOT_SIZE,
            minHeight = SLOT_SIZE,
            canCollide = true,  -- Enable collision for click detection
            hover = true,       -- Required for buttonCallback to work
            padding = UI(2),
            align = "center",
            color = bgColor,
            emboss = isHighlighted and 2 or nil,  -- Add depth to highlighted skills
            -- Click callback only for available/insufficient skills (not locked or learned)
            buttonCallback = (not isLocked and not isLearned) and function()
                -- Clear search focus when clicking a skill button
                state.searchFocused = false

                local ok, SkillsPanelInput = pcall(require, "ui.skills_panel_input")
                if ok and SkillsPanelInput and SkillsPanelInput.onSkillButtonClicked then
                    SkillsPanelInput.onSkillButtonClicked(skillId)
                end
            end or nil,
        },
        children = children,
    }
end

--- Create the skill grid (4 columns × 8 rows)
local function createSkillGrid()
    if not dsl then return nil end

    local gridData = SkillsPanel.getGridData()
    if not gridData then return nil end

    local rows = {}

    for row = 1, CONFIG.rows do
        local rowChildren = {}

        for _, element in ipairs(CONFIG.element_order) do
            local isLocked = LOCKED_ELEMENTS[element]
            local skills = gridData[element]
            local skillEntry = skills and skills[row]

            if skillEntry then
                table.insert(rowChildren, createSkillButton(
                    skillEntry.id,
                    skillEntry.def,
                    element,
                    isLocked
                ))
            else
                -- Empty slot
                table.insert(rowChildren, dsl.strict.spacer(SLOT_SIZE))
            end

            -- Add spacing between columns (except after last)
            if element ~= CONFIG.element_order[#CONFIG.element_order] then
                table.insert(rowChildren, dsl.strict.spacer(SLOT_SPACING))
            end
        end

        table.insert(rows, dsl.strict.hbox {
            config = {
                id = "skill_row_" .. row,
                padding = 0,
            },
            children = rowChildren,
        })

        -- Add spacing between rows (except after last)
        if row ~= CONFIG.rows then
            table.insert(rows, dsl.strict.spacer(SLOT_SPACING))
        end
    end

    return dsl.strict.vbox {
        config = {
            id = "skill_grid",
            padding = GRID_PADDING,
        },
        children = rows,
    }
end

--- Build the complete panel definition
local function buildPanelDef()
    if not dsl then return nil end

    return dsl.strict.spritePanel {
        sprite = CONFIG.panel_background .. ".png",
        borders = { 8, 8, 8, 8 },  -- Nine-patch borders
        sizing = "stretch",
        config = {
            id = "skills_panel",
            padding = PANEL_PADDING,
            minWidth = PANEL_WIDTH,
            minHeight = PANEL_HEIGHT,
        },
        children = {
            createHeader(),
            dsl.strict.spacer(HEADER_SPACING),
            createSearchBar(),
            dsl.strict.spacer(HEADER_SPACING),
            createColumnHeaders(),
            dsl.strict.spacer(HEADER_SPACING),
            createSkillGrid(),
        },
    }
end

local function initializePanel()
    if state.initialized then return end

    if not calculatePositions() then
        return
    end

    -- Check if we have the required game engine globals
    if not dsl or not _G.registry then
        -- Running in test mode without game engine
        state.initialized = true
        return
    end

    -- Build and spawn the panel
    local panelDef = buildPanelDef()
    if not panelDef then
        print("[SkillsPanel] Failed to build panel definition")
        state.initialized = true
        return
    end

    -- Spawn panel offscreen to the right (will slide in on open)
    local screenWidth = GetScreenWidth and GetScreenWidth() or 1920
    local offscreenX = state.hiddenX or (screenWidth + PANEL_PADDING)
    state.panelEntity = dsl.spawn(
        { x = offscreenX, y = state.panelY },
        panelDef,
        RENDER_LAYER,
        PANEL_Z
    )

    if not state.panelEntity then
        print("[SkillsPanel] Failed to spawn panel entity")
        state.initialized = true
        return
    end

    -- Set draw layer
    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(state.panelEntity, "sprites")
    end

    -- Add state tags for rendering
    if ui and ui.box and ui.box.AddStateTagToUIBox then
        ui.box.AddStateTagToUIBox(_G.registry, state.panelEntity, "default_state")
    end

    -- Store reference to header text for updates
    if ui and ui.box and ui.box.GetUIEByID then
        state.headerTextEntity = ui.box.GetUIEByID(_G.registry, state.panelEntity, "skills_points_display")
    end

    -- Set up search input entity and polling for text changes
    -- Note: TextInput.callback only fires on Enter, so we poll for real-time updates
    -- IMPORTANT: Do NOT override go.methods.onClick - it breaks C++ text input activation!
    if ui and ui.box and ui.box.GetUIEByID then
        state.searchInputEntity = ui.box.GetUIEByID(_G.registry, state.panelEntity, "skills_search_input")
        if state.searchInputEntity and _G.registry:valid(state.searchInputEntity) then
            -- Poll the TextInput.text field for real-time search updates
            -- Also track focus state by checking if this is the active text input
            if timer and TextInput then
                local lastSearchText = ""
                timer.every_opts({
                    delay = 0.1,  -- Poll every 100ms
                    tag = "skills_search_poll",
                    group = TIMER_GROUP,
                    action = function()
                        if not state.searchInputEntity or not _G.registry:valid(state.searchInputEntity) then
                            return
                        end

                        -- Check if search input has keyboard focus
                        local inputState = globals and globals.inputState
                        if inputState then
                            state.searchFocused = (inputState.activeTextInput == state.searchInputEntity)
                        end

                        -- Check for text changes
                        local textInput = component_cache.get(state.searchInputEntity, TextInput)
                        if textInput and textInput.text ~= lastSearchText then
                            lastSearchText = textInput.text
                            onSearchTextChanged(textInput.text or "")
                        end
                    end,
                })
            end
        end
    end

    -- Update the header text
    SkillsPanel.refreshHeader()

    applySkillTooltips()

    state.initialized = true
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Check if panel is initialized
--- @return boolean
function SkillsPanel.isInitialized()
    return state.initialized
end

--- Check if panel is open
--- @return boolean
function SkillsPanel.isOpen()
    return state.isVisible
end

--- Check if search input has keyboard focus
--- @return boolean
function SkillsPanel.isSearchFocused()
    return state.searchFocused
end

--- Set search input focus state
--- @param focused boolean True if search has focus
function SkillsPanel.setSearchFocused(focused)
    state.searchFocused = focused
end

--- Open the skills panel
function SkillsPanel.open()
    if not state.initialized then
        initializePanel()
    end

    if state.isVisible then return end

    setEntityVisible(state.panelEntity, true, state.panelX, state.panelY, state.hiddenX)
    state.isVisible = true

    if signal then
        signal.emit("skills_panel_opened")
    end
end

--- Close the skills panel
function SkillsPanel.close()
    if not state.isVisible then return end

    if state.activeTooltipKey and hideSimpleTooltip then
        hideSimpleTooltip(state.activeTooltipKey)
        state.activeTooltipKey = nil
    end

    -- Clear search focus when panel closes
    state.searchFocused = false

    setEntityVisible(state.panelEntity, false, state.panelX, state.panelY, state.hiddenX)
    state.isVisible = false

    if signal then
        signal.emit("skills_panel_closed")
    end
end

--- Toggle the skills panel
function SkillsPanel.toggle()
    if state.isVisible then
        SkillsPanel.close()
    else
        SkillsPanel.open()
    end
end

--- Set player reference for skill point queries
--- @param player table Player object
function SkillsPanel.setPlayer(player)
    state.player = player
end

--- Get current player reference
--- @return table|nil
function SkillsPanel.getPlayer()
    return state.player
end

--- Refresh skill button visual states
function SkillsPanel.refreshButtonStates()
    if not state.initialized or not state.panelEntity then return end
    if not _G.registry or not _G.registry.valid or not _G.registry:valid(state.panelEntity) then return end

    if state.activeTooltipKey and hideSimpleTooltip then
        hideSimpleTooltip(state.activeTooltipKey)
        state.activeTooltipKey = nil
    end

    -- For a full refresh, rebuild the grid
    -- This is simpler than tracking individual button entities
    if ui and ui.box and ui.box.GetUIEByID then
        local gridEntity = ui.box.GetUIEByID(_G.registry, state.panelEntity, "skill_grid")
        if gridEntity and ui.box.ReplaceChildren then
            local newGrid = createSkillGrid()
            if newGrid then
                ui.box.ReplaceChildren(gridEntity, newGrid)

                -- Reapply state tags
                if ui.box.AddStateTagToUIBox then
                    ui.box.AddStateTagToUIBox(_G.registry, state.panelEntity, "default_state")
                end

                -- Force layout recalculation
                if ui.box.RenewAlignment then
                    ui.box.RenewAlignment(_G.registry, state.panelEntity)
                end

                applySkillTooltips()
            end
        end
    end
end

--- Refresh header text (skill points display)
function SkillsPanel.refreshHeader()
    if not state.player then return end

    local displayText = SkillsPanel.getSkillPointsDisplay(state.player)

    -- Update the header text entity if we have UI access
    if state.headerTextEntity and _G.registry and _G.registry.valid and _G.registry:valid(state.headerTextEntity) then
        -- Try to update the text component
        local textComp = component_cache.get(state.headerTextEntity, Text)
        if textComp then
            textComp.text = displayText
        end
    end
end

--- Destroy the panel and cleanup
function SkillsPanel.destroy()
    if not state.initialized then return end

    if timer then
        timer.kill_group(TIMER_GROUP)
    end

    if state.activeTooltipKey and hideSimpleTooltip then
        hideSimpleTooltip(state.activeTooltipKey)
        state.activeTooltipKey = nil
    end

    -- Destroy panel entity
    if state.panelEntity and _G.registry and _G.registry.valid and _G.registry:valid(state.panelEntity) then
        if ui and ui.box and ui.box.Remove then
            ui.box.Remove(_G.registry, state.panelEntity)
        end
    end

    -- Reset state
    state.initialized = false
    state.isVisible = false
    state.panelEntity = nil
    state.gridEntity = nil
    state.skillButtons = {}
    state.headerTextEntity = nil
    state.searchInputEntity = nil
    state.player = nil
    state.activeTooltipKey = nil
    state.searchText = ""
    state.matchingSkills = {}
    state.searchFocused = false
end

--- Reset module state (for testing)
function SkillsPanel._reset()
    SkillsPanel.destroy()
end

return SkillsPanel
