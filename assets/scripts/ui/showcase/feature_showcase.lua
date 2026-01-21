--[[
================================================================================
FEATURE SHOWCASE
================================================================================
Fullscreen overlay UI that demonstrates Phase 1-6 gameplay systems.
Shows automated pass/fail badges per item with category summary row.
Provides tab navigation and scrollable card grid.

Usage:
    local FeatureShowcase = require("ui.showcase.feature_showcase")
    FeatureShowcase.show()  -- Opens the showcase
    FeatureShowcase.hide()  -- Closes the showcase
================================================================================
]]

local ShowcaseVerifier = require("ui.showcase.showcase_verifier")
local ShowcaseCards = require("ui.showcase.showcase_cards")

-- Optional dependencies (may not be available in standalone tests)
local signal = nil
local UIValidator = nil

local function loadOptionalDeps()
    if not signal then
        local ok, mod = pcall(require, "external.hump.signal")
        if ok then signal = mod end
    end
    if not UIValidator then
        local ok, mod = pcall(require, "core.ui_validator")
        if ok then UIValidator = mod end
    end
end

local FeatureShowcase = {}

--------------------------------------------------------------------------------
-- CONSTANTS
--------------------------------------------------------------------------------

-- Category definitions with user-friendly labels
FeatureShowcase.CATEGORIES = {
    { id = "gods_classes", label = "Gods & Classes" },
    { id = "skills", label = "Skills" },
    { id = "artifacts", label = "Artifacts" },
    { id = "wands", label = "Wands" },
    { id = "status_effects", label = "Status Effects" },
}

-- Layout constants
local SCREEN_WIDTH = 1280
local SCREEN_HEIGHT = 720
local PANEL_MIN_WIDTH = 640
local PANEL_MIN_HEIGHT = 360
local PANEL_MAX_WIDTH = 1200
local PANEL_MARGIN = 24
local PANEL_PADDING = 16
local BODY_GAP = 12
local NAV_MIN_WIDTH = 180
local NAV_MAX_WIDTH = 260
local CARD_SPACING = 12

--------------------------------------------------------------------------------
-- STATE
--------------------------------------------------------------------------------

local state = {
    visible = false,
    currentCategory = "gods_classes",
    showOnlyIssues = false,
    rootEntity = nil,
    contentEntity = nil,
    verificationResults = nil,
    initialized = false,
    escHandler = nil,  -- ESC key handler for closing
}

--------------------------------------------------------------------------------
-- HELPERS
--------------------------------------------------------------------------------

-- Try to load DSL (may not be available in standalone tests)
local dsl = nil
local function getDsl()
    if dsl then return dsl end
    local ok, mod = pcall(require, "ui.ui_syntax_sugar")
    if ok then
        dsl = mod
    end
    return dsl
end

-- Get screen dimensions (with fallback)
local function getScreenDimensions()
    if globals and globals.screenWidth then
        return globals.screenWidth(), globals.screenHeight()
    end
    return SCREEN_WIDTH, SCREEN_HEIGHT
end

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function resolveLayout()
    local screenW, screenH = getScreenDimensions()
    local availableW = math.max(320, screenW - PANEL_MARGIN * 2)
    local availableH = math.max(240, screenH - PANEL_MARGIN * 2)
    local minW = math.min(PANEL_MIN_WIDTH, availableW)
    local minH = math.min(PANEL_MIN_HEIGHT, availableH)

    local targetW = clamp(math.floor(screenW * 0.92), minW, math.min(PANEL_MAX_WIDTH, availableW))
    local targetH = clamp(math.floor(screenH * 0.9), minH, availableH)

    local panelX = clamp((screenW - targetW) * 0.5, PANEL_MARGIN, screenW - targetW - PANEL_MARGIN)
    local panelY = clamp((screenH - targetH) * 0.5, PANEL_MARGIN, screenH - targetH - PANEL_MARGIN)

    local innerW = targetW - PANEL_PADDING * 2
    local innerH = targetH - PANEL_PADDING * 2
    local navMax = math.max(140, math.min(NAV_MAX_WIDTH, innerW - 220))
    local navMin = math.min(NAV_MIN_WIDTH, navMax)
    local navWidth = clamp(math.floor(innerW * 0.24), navMin, navMax)
    local contentWidth = math.max(160, innerW - navWidth - BODY_GAP)

    local headerHeight = 72
    local bodyHeight = math.max(140, innerH - headerHeight - BODY_GAP)
    local contentHeaderHeight = 30
    local contentToolbarHeight = 28
    local contentHeight = math.max(120, bodyHeight - contentHeaderHeight - contentToolbarHeight - 16)

    return {
        panelWidth = targetW,
        panelHeight = targetH,
        panelX = panelX,
        panelY = panelY,
        innerWidth = innerW,
        innerHeight = innerH,
        navWidth = navWidth,
        contentWidth = contentWidth,
        headerHeight = headerHeight,
        bodyHeight = bodyHeight,
        contentHeaderHeight = contentHeaderHeight,
        contentToolbarHeight = contentToolbarHeight,
        contentHeight = contentHeight,
        padding = PANEL_PADDING,
    }
end

-- Get category by ID
local function getCategoryById(id)
    for _, cat in ipairs(FeatureShowcase.CATEGORIES) do
        if cat.id == id then
            return cat
        end
    end
    return nil
end

local function computeTotals(results)
    local pass = 0
    local total = 0
    if results and results.categories then
        for _, cat in ipairs(FeatureShowcase.CATEGORIES) do
            local catResults = results.categories[cat.id]
            if catResults then
                pass = pass + (catResults.pass or 0)
                total = total + (catResults.total or 0)
            end
        end
    end
    return pass, total
end

local function createScrollPane(children, opts)
    opts = opts or {}
    local d = getDsl()
    if not d or not d.strict then
        return nil
    end

    if not (ui and ui.definitions and ui.definitions.def) then
        return d.strict.vbox { children = children or {} }
    end

    return ui.definitions.def {
        type = "SCROLL_PANE",
        config = {
            id = opts.id,
            maxWidth = opts.width,
            width = opts.width,
            maxHeight = opts.height,
            height = opts.height,
            padding = opts.padding or 6,
            color = opts.color,
            align = opts.align or bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = children or {},
    }
end

--------------------------------------------------------------------------------
-- DATA LOADERS
--------------------------------------------------------------------------------

-- Load data for a category
local function loadCategoryData(categoryId)
    local data = {}

    if categoryId == "gods_classes" then
        local ok, Avatars = pcall(require, "data.avatars")
        if ok then
            for _, id in ipairs(ShowcaseVerifier.getOrderedItems("gods_classes")) do
                data[#data + 1] = { id = id, def = Avatars[id] }
            end
        end
    elseif categoryId == "skills" then
        local ok, Skills = pcall(require, "data.skills")
        if ok then
            for _, id in ipairs(ShowcaseVerifier.getOrderedItems("skills")) do
                data[#data + 1] = { id = id, def = Skills[id] }
            end
        end
    elseif categoryId == "artifacts" then
        local ok, Artifacts = pcall(require, "data.artifacts")
        if ok then
            for _, id in ipairs(ShowcaseVerifier.getOrderedItems("artifacts")) do
                data[#data + 1] = { id = id, def = Artifacts[id] }
            end
        end
    elseif categoryId == "wands" then
        local ok, module = pcall(require, "core.card_eval_order_test")
        if ok then
            local wands = module.WandTemplates or module.wand_defs or _G.wand_defs or {}
            local wandsById = {}
            for _, w in ipairs(wands) do
                if w.id then wandsById[w.id] = w end
            end
            for _, id in ipairs(ShowcaseVerifier.getOrderedItems("wands")) do
                data[#data + 1] = { id = id, def = wandsById[id] }
            end
        end
    elseif categoryId == "status_effects" then
        local ok, StatusEffects = pcall(require, "data.status_effects")
        if ok then
            for _, id in ipairs(ShowcaseVerifier.getOrderedItems("status_effects")) do
                data[#data + 1] = { id = id, def = StatusEffects[id] }
            end
        end
    end

    return data
end

--------------------------------------------------------------------------------
-- UI BUILDERS (require DSL)
--------------------------------------------------------------------------------

local function buildCategoryNav(results, currentCategory, onTabClick, layout)
    local d = getDsl()
    if not d or not d.strict then return nil end

    local children = {}
    local overallPass, overallTotal = computeTotals(results)
    local overallColor = (overallTotal > 0 and overallPass == overallTotal) and "green" or "orange"

    children[#children + 1] = d.strict.text("Categories", { fontSize = 12, color = "lightgray" })
    children[#children + 1] = d.strict.text(string.format("Overall: %d/%d passing", overallPass, overallTotal), {
        fontSize = 10,
        color = overallColor,
    })
    children[#children + 1] = d.strict.spacer(4)

    for _, cat in ipairs(FeatureShowcase.CATEGORIES) do
        local catResults = results.categories[cat.id] or { pass = 0, total = 0 }
        local issues = (catResults.total or 0) - (catResults.pass or 0)
        local isActive = cat.id == currentCategory
        local bgColor = isActive and "deep_teal" or "charcoal"
        local textColor = isActive and "white" or "lightgray"
        local issueColor = issues > 0 and "orange" or "green"

        children[#children + 1] = d.strict.vbox {
            config = {
                padding = 6,
                spacing = 2,
                minWidth = layout.navWidth,
                color = bgColor,
                hover = true,
                canCollide = true,
                buttonCallback = function()
                    if onTabClick then onTabClick(cat.id) end
                end,
            },
            children = {
                d.strict.text(cat.label, { fontSize = 12, color = textColor }),
                d.strict.text(string.format("%d/%d passing  |  %d issues", catResults.pass or 0, catResults.total or 0, issues), {
                    fontSize = 10,
                    color = issueColor,
                }),
            },
        }
    end

    return d.strict.vbox {
        config = {
            padding = 8,
            spacing = 6,
            minWidth = layout.navWidth,
            minHeight = layout.bodyHeight,
            color = "black",
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = children,
    }
end

local function buildContentHeader(category, catResults)
    local d = getDsl()
    if not d or not d.strict then return nil end

    local label = category and category.label or "Category"
    local pass = catResults and catResults.pass or 0
    local total = catResults and catResults.total or 0
    local allPass = total > 0 and pass == total
    local statusColor = allPass and "green" or "orange"

    return d.strict.hbox {
        config = {
            spacing = 10,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
        },
        children = {
            d.strict.text(label, { fontSize = 16, color = "white" }),
            d.strict.text(string.format("%d/%d passing", pass, total), { fontSize = 12, color = statusColor }),
        },
    }
end

local function buildToolbar(showOnlyIssues, onToggle)
    local d = getDsl()
    if not d or not d.strict then return nil end

    local label = showOnlyIssues and "Showing: Issues" or "Showing: All"
    local buttonLabel = showOnlyIssues and "Show All" or "Show Issues"
    local buttonColor = showOnlyIssues and "orange" or "charcoal"

    return d.strict.hbox {
        config = {
            spacing = 8,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
        },
        children = {
            d.strict.text(label, { fontSize = 11, color = "lightgray" }),
            d.strict.button(buttonLabel, {
                onClick = onToggle,
                color = buttonColor,
                minWidth = 90,
                minHeight = 22,
            }),
            d.strict.text("Legend: [OK] pass  [X] issue", { fontSize = 10, color = "gray" }),
        },
    }
end

local function resolveGridColumns(availableWidth)
    local cardWidth = ShowcaseCards.CARD_WIDTH or 280
    local columns = math.floor((availableWidth + CARD_SPACING) / (cardWidth + CARD_SPACING))
    if columns < 1 then columns = 1 end
    if columns > 4 then columns = 4 end
    return columns
end

-- Build the card grid for a category
local function buildCardGrid(categoryId, results, opts)
    local d = getDsl()
    if not d or not d.strict then return nil end

    opts = opts or {}
    local data = loadCategoryData(categoryId)
    local catResults = results.categories[categoryId] or { items = {} }
    local builder = ShowcaseCards.getBuilderForCategory(categoryId)
    local columns = opts.columns or resolveGridColumns(opts.availableWidth or ShowcaseCards.CARD_WIDTH or 280)
    local showOnlyIssues = opts.showOnlyIssues

    if not builder then
        return d.strict.text("No card builder for this category.", { fontSize = 11, color = "red" })
    end

    if not data or #data == 0 then
        return d.strict.text("No data loaded for this category.", { fontSize = 11, color = "gray" })
    end

    local rows = {}
    local currentRow = {}
    local visibleCount = 0

    for _, item in ipairs(data) do
        local itemResult = catResults.items[item.id] or { ok = false, error = "Missing data" }
        if not (showOnlyIssues and itemResult.ok) then
            local cardDef = item.def or {}
            local displayDef = {}
            for k, v in pairs(cardDef) do displayDef[k] = v end
            displayDef.id = item.id

            local card = builder(displayDef, itemResult.ok, itemResult.error)
            currentRow[#currentRow + 1] = card
            visibleCount = visibleCount + 1

            if #currentRow == columns then
                rows[#rows + 1] = d.strict.hbox {
                    config = { spacing = CARD_SPACING },
                    children = currentRow,
                }
                currentRow = {}
            end
        end
    end

    if #currentRow > 0 then
        rows[#rows + 1] = d.strict.hbox {
            config = { spacing = CARD_SPACING },
            children = currentRow,
        }
    end

    if visibleCount == 0 then
        return d.strict.text("No issues found in this category.", { fontSize = 11, color = "green" })
    end

    return d.strict.vbox {
        config = { spacing = CARD_SPACING, padding = 8 },
        children = rows,
    }
end

-- Build the full showcase UI
local function buildShowcaseUI()
    local d = getDsl()
    if not d or not d.strict then
        error("DSL not available - feature_showcase requires ui_syntax_sugar")
    end

    local layout = resolveLayout()
    local results = FeatureShowcase.getVerificationResults()
    local currentCategory = getCategoryById(state.currentCategory) or FeatureShowcase.CATEGORIES[1]
    local catResults = results.categories[currentCategory.id] or { pass = 0, total = 0 }

    -- Close button handler
    local function onClose()
        print("[FeatureShowcase] Close button clicked")
        FeatureShowcase.hide()
    end

    -- Tab click handler
    local function onTabClick(categoryId)
        print("[FeatureShowcase] Tab clicked: " .. tostring(categoryId))
        FeatureShowcase.switchCategory(categoryId)
    end

    local function onToggleIssues()
        state.showOnlyIssues = not state.showOnlyIssues
        FeatureShowcase.refresh()
    end

    local overallPass, overallTotal = computeTotals(results)
    local overallColor = (overallTotal > 0 and overallPass == overallTotal) and "green" or "orange"

    return d.strict.root {
        config = {
            color = "blackberry",
            padding = layout.padding,
            minWidth = layout.panelWidth,
            minHeight = layout.panelHeight,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = {
            -- Main vertical layout
            d.strict.vbox {
                config = { spacing = BODY_GAP, minWidth = layout.innerWidth, minHeight = layout.innerHeight },
                children = {
                    -- Header row: title + close button
                    d.strict.hbox {
                        config = {
                            spacing = 12,
                            minWidth = layout.innerWidth,
                            minHeight = layout.headerHeight,
                            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
                        },
                        children = {
                            d.strict.vbox {
                                config = { spacing = 2 },
                                children = {
                                    d.strict.text("Feature Showcase", { fontSize = 22, color = "white" }),
                                    d.strict.text("Content validation dashboard for Phase 1-6 systems", { fontSize = 11, color = "gray" }),
                                    d.strict.text(string.format("Overall: %d/%d passing", overallPass, overallTotal), {
                                        fontSize = 11,
                                        color = overallColor,
                                    }),
                                },
                            },
                            d.strict.hbox {
                                config = { padding = 0, minWidth = 1, align = AlignmentFlag.HORIZONTAL_RIGHT },
                                children = {},
                            },
                            d.strict.button("Close", {
                                onClick = onClose,
                                color = "red",
                                minWidth = 64,
                                minHeight = 28,
                            }),
                        },
                    },
                    -- Body: category nav + content
                    d.strict.hbox {
                        config = {
                            spacing = BODY_GAP,
                            minWidth = layout.innerWidth,
                            minHeight = layout.bodyHeight,
                            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
                        },
                        children = {
                            buildCategoryNav(results, state.currentCategory, onTabClick, layout),
                            d.strict.vbox {
                                config = {
                                    spacing = 8,
                                    minWidth = layout.contentWidth,
                                    minHeight = layout.bodyHeight,
                                    color = "black",
                                    align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
                                },
                                children = {
                                    buildContentHeader(currentCategory, catResults),
                                    buildToolbar(state.showOnlyIssues, onToggleIssues),
                                    createScrollPane(
                                        { buildCardGrid(state.currentCategory, results, {
                                            availableWidth = layout.contentWidth - 16,
                                            showOnlyIssues = state.showOnlyIssues,
                                        }) },
                                        {
                                            id = "feature_showcase_scroll",
                                            width = layout.contentWidth,
                                            height = layout.contentHeight,
                                            padding = 6,
                                            color = "blackberry",
                                        }
                                    ),
                                },
                            },
                        },
                    },
                },
            },
        },
    }, layout.panelX, layout.panelY
end

--------------------------------------------------------------------------------
-- PUBLIC API
--------------------------------------------------------------------------------

--- Initialize the showcase module
function FeatureShowcase.init()
    if state.initialized then return end

    -- Pre-load verification results
    state.verificationResults = ShowcaseVerifier.runAll()
    state.initialized = true
end

--- Show the feature showcase overlay
function FeatureShowcase.show()
    local d = getDsl()
    if not d then
        error("DSL not available - cannot show feature showcase")
    end

    -- Load optional dependencies
    loadOptionalDeps()

    -- Initialize if needed
    if not state.initialized then
        FeatureShowcase.init()
    end

    -- Don't show if already visible
    if state.visible then return end

    -- Build and spawn UI
    local uiDef, panelX, panelY = buildShowcaseUI()
    state.rootEntity = d.spawn({ x = panelX, y = panelY }, uiDef, "ui", 1000)

    -- Set draw layer for proper z-ordering
    if ui and ui.box and ui.box.set_draw_layer then
        ui.box.set_draw_layer(state.rootEntity, "ui")
    end

    -- Add state tags so UI elements are included in collision detection
    -- Deferred by one frame to ensure UI tree is fully constructed
    local timer = require("core.timer")
    local entity = state.rootEntity
    timer.after(0, function()
        if entity and registry and registry:valid(entity) then
            if ui and ui.box and ui.box.AddStateTagToUIBox then
                ui.box.AddStateTagToUIBox(entity, "default_state")
            end
        end
    end)

    -- Validate UI after spawn
    if UIValidator and state.rootEntity then
        local violations = UIValidator.validate(state.rootEntity, nil, { skipHidden = true })
        if violations then
            local errors = UIValidator.getErrors and UIValidator.getErrors(violations) or {}
            if #errors > 0 then
                print("[FeatureShowcase] UI validation warnings:")
                for _, e in ipairs(errors) do
                    print("  " .. (e.type or "unknown") .. ": " .. (e.message or ""))
                end
            end
        end
    end

    -- Register ESC key handler
    if signal then
        state.escHandler = function(key)
            if (key == "escape" or key == 256) and state.visible then  -- 256 is KEY_ESCAPE in raylib
                FeatureShowcase.hide()
            end
        end
        signal.register("key_pressed", state.escHandler)
    end

    state.visible = true
end

--- Hide the feature showcase overlay
function FeatureShowcase.hide()
    local d = getDsl()

    if not state.visible then return end

    -- Unregister ESC key handler
    if signal and state.escHandler then
        signal.remove("key_pressed", state.escHandler)
        state.escHandler = nil
    end

    -- Remove UI entity
    if state.rootEntity and d and d.remove then
        d.remove(state.rootEntity)
    end

    state.rootEntity = nil
    state.visible = false
end

--- Rebuild UI if visible
function FeatureShowcase.refresh()
    if state.visible then
        print("[FeatureShowcase] Rebuilding UI...")
        FeatureShowcase.hide()
        FeatureShowcase.show()
        print("[FeatureShowcase] UI rebuilt successfully")
    end
end

--- Switch to a different category tab
--- @param categoryId string Category ID to switch to
function FeatureShowcase.switchCategory(categoryId)
    print("[FeatureShowcase] switchCategory called with: " .. tostring(categoryId))
    local cat = getCategoryById(categoryId)
    if not cat then
        print("[FeatureShowcase] Category not found: " .. tostring(categoryId))
        return
    end

    state.currentCategory = categoryId
    print("[FeatureShowcase] Current category set to: " .. tostring(categoryId))

    -- Rebuild UI if visible
    FeatureShowcase.refresh()
end

--- Cleanup and release resources
function FeatureShowcase.cleanup()
    FeatureShowcase.hide()
    state.initialized = false
    state.verificationResults = nil
    ShowcaseVerifier.invalidate()
end

--- Check if showcase is currently visible
--- @return boolean
function FeatureShowcase.isVisible()
    return state.visible
end

--- Get current category ID
--- @return string
function FeatureShowcase.getCurrentCategory()
    return state.currentCategory
end

--- Get verification results (cached)
--- @return table
function FeatureShowcase.getVerificationResults()
    if not state.verificationResults then
        state.verificationResults = ShowcaseVerifier.runAll()
    end
    return state.verificationResults
end

return FeatureShowcase
