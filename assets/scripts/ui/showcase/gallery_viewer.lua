--[[
================================================================================
GALLERY VIEWER - Interactive UI Showcase Browser
================================================================================
A gallery viewer for browsing UI component examples visually.

Features:
- Category-based navigation (primitives, layouts, patterns)
- Visual preview of selected showcase
- Source code display in a scrollable panel
- Keyboard navigation (W/S to browse, A/D or E to switch Preview/Source)
- Mouse support for clicking items + mouse wheel scrolling

Usage:
local GalleryViewer = require("ui.showcase.gallery_viewer")

-- Create and show the gallery
local viewer = GalleryViewer.new()
viewer:show(100, 50)  -- Position at x=100, y=50

-- In your update loop
viewer:update(dt)

-- Clean up when done
viewer:destroy()

Keyboard Controls:
- UP/DOWN or W/S: Navigate through showcases (up/down)
- LEFT/RIGHT or A/D: Toggle Preview/Source panel
- ENTER or SPACE: Toggle Preview/Source panel
- ESC: Close viewer
================================================================================
]]

local dsl = require("ui.ui_syntax_sugar")
local timer = require("core.timer")
local component_cache = require("core.component_cache")
local ShowcaseRegistry = require("ui.showcase.showcase_registry")

local function resolveScreenSize()
    local w, h = 1920, 1080
    if globals then
        w = (globals.screenWidth and globals.screenWidth()) or (globals.getScreenWidth and globals.getScreenWidth()) or w
        h = (globals.screenHeight and globals.screenHeight()) or (globals.getScreenHeight and globals.getScreenHeight()) or h
    end
    return w, h
end

local function clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function resolveColor(name)
    if util and util.getColor then
        local ok, c = pcall(util.getColor, name)
        if ok and c then return c end
    end
    return name
end

local function createScrollPane(children, opts)
    opts = opts or {}
    local width = opts.width
    local height = opts.height
    local align = opts.align or bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP)

    if not (ui and ui.definitions and ui.definitions.def) then
        return dsl.strict.vbox { children = children or {} }
    end

    return ui.definitions.def {
        type = "SCROLL_PANE",
        config = {
            id = opts.id,
            maxWidth = width,
            width = width,
            maxHeight = height,
            height = height,
            padding = opts.padding or 4,
            color = opts.color,
            align = align,
        },
        children = children or {},
    }
end

local GalleryViewer = {}
GalleryViewer.__index = GalleryViewer

-- Key mappings (supports arrows + WASD + Enter/Space)
local KEY_MAPPINGS = {
    up = { "KEY_UP", "KEY_W" },
    down = { "KEY_DOWN", "KEY_S" },
    left = { "KEY_LEFT", "KEY_A" },
    right = { "KEY_RIGHT", "KEY_D" },
    select = { "KEY_ENTER", "KEY_SPACE", "KEY_E" },  -- E toggles preview/source
    back = { "KEY_ESCAPE" },
}

--------------------------------------------------------------------------------
-- Constructor
--------------------------------------------------------------------------------

function GalleryViewer.new(options)
    local self = setmetatable({}, GalleryViewer)

    options = options or {}

    self._timerGroup = "gallery_viewer_" .. math.random(1, 99999)
    self._visible = false
    self._entity = nil
    self._position = { x = 0, y = 0 }

    -- Navigation state
    self._categories = ShowcaseRegistry.getCategories()
    self._currentCategoryIndex = 1
    self._currentShowcaseIndex = 1
    self._flatList = ShowcaseRegistry.getFlatList()
    self._flatIndex = 1  -- Current position in flat list
    self._lastFlatIndex = 1
    self._viewMode = "list"  -- "list" or "detail"
    self._panelMode = "preview"  -- "preview" or "source"
    self._scrollOffsets = { list = 0, preview = 0, source = 0 }
    self._rebuildScheduled = false

    -- UI dimensions
    self._desiredWidth = options.width or 700
    self._desiredHeight = options.height or 450
    self._minWidth = options.minWidth or 520
    self._minHeight = options.minHeight or 360
    self._gap = options.gap or 12
    self._minListWidth = options.minListWidth or 180
    self._minPreviewWidth = options.minPreviewWidth or 260
    self._safeMargins = options.safeMargins or { left = 24, right = 24, top = 24, bottom = 48 }

    self._width = self._desiredWidth
    self._height = self._desiredHeight
    self._listWidth = self._minListWidth
    self._previewWidth = self._width - self._listWidth - self._gap
    self._headerHeight = 64
    self._bodyHeight = math.max(0, self._height - self._headerHeight)
    self._listHeight = self._bodyHeight
    self._panelContentHeight = math.max(0, self._bodyHeight - 36)

    -- Colors - using valid palette colors (see util.getColor)
    self._colors = {
        background = "blackberry",       -- dark purple-gray
        listBg = "charcoal",             -- dark gray
        selectedBg = "deep_teal",        -- teal highlight
        hoverBg = "purple_slate",        -- purple-gray
        headerBg = "charcoal",           -- dark gray
        text = "white",
        textDim = "gray",
        categoryText = "gold",
        sourceCodeBg = "charcoal",
        sourceCodeText = "green_jade",
    }

    -- Flag to prevent multiple timer creation
    self._inputPollingActive = false

    return self
end

function GalleryViewer:_applyOptions(options)
    if not options then return end

    if options.width ~= nil then self._desiredWidth = options.width end
    if options.height ~= nil then self._desiredHeight = options.height end
    if options.minWidth ~= nil then self._minWidth = options.minWidth end
    if options.minHeight ~= nil then self._minHeight = options.minHeight end
    if options.gap ~= nil then self._gap = options.gap end
    if options.minListWidth ~= nil then self._minListWidth = options.minListWidth end
    if options.minPreviewWidth ~= nil then self._minPreviewWidth = options.minPreviewWidth end
    if options.safeMargins ~= nil then self._safeMargins = options.safeMargins end
end

--------------------------------------------------------------------------------
-- Public Methods
--------------------------------------------------------------------------------

--- Show the gallery viewer at the specified position
---@param x number X position
---@param y number Y position
function GalleryViewer:show(x, y)
    self._visible = true
    self:_applyLayout(x, y)
    self:_rebuild()
    self:_startInputPolling()
end

--- Hide the gallery viewer
function GalleryViewer:hide()
    self._visible = false
    self:_cleanup()
end

--- Toggle visibility
function GalleryViewer:toggle()
    if self._visible then
        self:hide()
    else
        self:show(self._position.x, self._position.y)
    end
end

--- Update (call in game loop)
---@param dt number Delta time
function GalleryViewer:update(dt)
    -- Input polling is handled by timers
end

--- Clean up resources
function GalleryViewer:destroy()
    self:_cleanup()
    timer.kill_group(self._timerGroup)
end

--- Get current selected showcase
---@return table|nil Currently selected showcase
function GalleryViewer:getCurrentShowcase()
    if self._flatIndex > 0 and self._flatIndex <= #self._flatList then
        return self._flatList[self._flatIndex].showcase
    end
    return nil
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

function GalleryViewer:_applyLayout(x, y)
    local screenW, screenH = resolveScreenSize()
    local margins = self._safeMargins or { left = 0, right = 0, top = 0, bottom = 0 }

    local availableW = math.max(240, screenW - margins.left - margins.right)
    local availableH = math.max(200, screenH - margins.top - margins.bottom)

    local minW = math.min(self._minWidth, availableW)
    local minH = math.min(self._minHeight, availableH)
    local targetW = clamp(self._desiredWidth, minW, availableW)
    local targetH = clamp(self._desiredHeight, minH, availableH)

    self._width = targetW
    self._height = targetH

    local defaultX = margins.left + (availableW - self._width) * 0.5
    local defaultY = margins.top + (availableH - self._height) * 0.5

    local posX = x
    local posY = y
    if posX == nil then posX = defaultX end
    if posY == nil then posY = defaultY end

    posX = clamp(posX, margins.left, margins.left + availableW - self._width)
    posY = clamp(posY, margins.top, margins.top + availableH - self._height)

    self._position = { x = posX, y = posY }

    local maxListWidth = math.max(140, self._width - self._gap - self._minPreviewWidth)
    local listWidth = clamp(math.floor(self._width * 0.30), self._minListWidth, maxListWidth)
    self._listWidth = listWidth
    self._previewWidth = self._width - listWidth - self._gap

    if self._previewWidth < self._minPreviewWidth then
        self._previewWidth = math.max(180, self._previewWidth)
        self._listWidth = math.max(140, self._width - self._gap - self._previewWidth)
    end

    self._headerHeight = math.max(64, math.floor(self._height * 0.18))
    self._bodyHeight = math.max(0, self._height - self._headerHeight)
    self._listHeight = self._bodyHeight
    local contentMin = math.min(80, self._bodyHeight)
    self._panelContentHeight = clamp(self._bodyHeight - 36, contentMin, self._bodyHeight)
end

function GalleryViewer:_captureScrollOffsets()
    if not (self._entity and registry and registry.valid and ui and ui.box and ui.box.GetUIEByID) then
        return
    end
    if not UIScrollComponent then
        return
    end

    local function getOffset(id)
        local pane = ui.box.GetUIEByID(registry, self._entity, id)
        if not pane or not registry:valid(pane) then return nil end
        local scrollComp = component_cache.get(pane, UIScrollComponent)
        return scrollComp and (scrollComp.offset or 0) or nil
    end

    self._scrollOffsets.list = getOffset("gallery_list_scroll") or self._scrollOffsets.list or 0
    self._scrollOffsets.preview = getOffset("gallery_preview_scroll") or self._scrollOffsets.preview or 0
    self._scrollOffsets.source = getOffset("gallery_source_scroll") or self._scrollOffsets.source or 0
end

function GalleryViewer:_restoreScrollOffsets()
    if not (self._entity and registry and registry.valid and ui and ui.box and ui.box.GetUIEByID) then
        return
    end
    if not UIScrollComponent then
        return
    end

    local function setOffset(id, offset)
        if not offset or offset == 0 then return end
        local pane = ui.box.GetUIEByID(registry, self._entity, id)
        if not pane or not registry:valid(pane) then return end

        local scrollComp = component_cache.get(pane, UIScrollComponent)
        if not scrollComp then return end

        scrollComp.offset = math.min(offset, scrollComp.maxOffset or offset)
        scrollComp.prevOffset = scrollComp.offset

        if ui.box.TraverseUITreeBottomUp then
            ui.box.TraverseUITreeBottomUp(registry, pane, function(child)
                if GameObject then
                    local go = component_cache.get(child, GameObject)
                    if go then
                        go.scrollPaneDisplacement = { x = 0, y = -scrollComp.offset }
                    end
                end
            end, true)
        end
    end

    setOffset("gallery_list_scroll", self._scrollOffsets.list)
    if self._panelMode == "preview" then
        setOffset("gallery_preview_scroll", self._scrollOffsets.preview)
    else
        setOffset("gallery_source_scroll", self._scrollOffsets.source)
    end
end

function GalleryViewer:_queueRebuild()
    if self._rebuildScheduled then return end
    self._rebuildScheduled = true

    -- Small delay to batch rapid navigation changes (e.g., holding W/S keys)
    -- This reduces UI refresh work when scrolling quickly through items
    timer.after(0.05, function()
        self._rebuildScheduled = false
        if self._visible then
            self:_refreshUI()
        end
    end, self._timerGroup .. "_rebuild_once", self._timerGroup .. "_rebuild")
end

--------------------------------------------------------------------------------
-- Navigation
--------------------------------------------------------------------------------

function GalleryViewer:_navigateUp()
    if self._flatIndex > 1 then
        self._flatIndex = self._flatIndex - 1
        self:_queueRebuild()
    end
end

function GalleryViewer:_navigateDown()
    if self._flatIndex < #self._flatList then
        self._flatIndex = self._flatIndex + 1
        self:_queueRebuild()
    end
end

function GalleryViewer:_selectCurrent()
    self:_togglePanelMode()
end

function GalleryViewer:_setPanelMode(mode)
    if mode ~= "preview" and mode ~= "source" then return end
    if self._panelMode ~= mode then
        self:_captureScrollOffsets()
        self._panelMode = mode
        self:_queueRebuild()
    end
end

function GalleryViewer:_togglePanelMode()
    self:_captureScrollOffsets()
    if self._panelMode == "preview" then
        self._panelMode = "source"
    else
        self._panelMode = "preview"
    end
    self:_queueRebuild()
end

function GalleryViewer:_goBack()
    if self._viewMode == "detail" then
        self._viewMode = "list"
        self:_queueRebuild()
    else
        self:hide()
    end
end

--------------------------------------------------------------------------------
-- Input Handling
--------------------------------------------------------------------------------

function GalleryViewer:_startInputPolling()
    -- Prevent duplicate timers
    if self._inputPollingActive then return end
    self._inputPollingActive = true

    -- Poll input at 100ms intervals (10 FPS) - sufficient for keyboard navigation
    -- Faster polling (50ms) causes noticeable CPU overhead
    timer.every(0.1, function()
        if not self._visible then return end
        self:_pollInput()
    end, 0, false, nil, nil, self._timerGroup .. "_input")
end

function GalleryViewer:_pollInput()
    -- Check for key presses using available input system
    local function isPressed(keyName)
        local keys = KEY_MAPPINGS[keyName]
        if not keys then return false end

        for _, key in ipairs(keys) do
            if isKeyPressed and isKeyPressed(key) then
                return true
            end
        end
        return false
    end

    if isPressed("up") then
        self:_navigateUp()
    elseif isPressed("down") then
        self:_navigateDown()
    elseif isPressed("left") or isPressed("right") then
        self:_togglePanelMode()
    elseif isPressed("select") then
        self:_selectCurrent()
    elseif isPressed("back") then
        self:_goBack()
    end
end

--------------------------------------------------------------------------------
-- UI Building
--------------------------------------------------------------------------------

function GalleryViewer:_rebuild()
    self:_captureScrollOffsets()
    self:_cleanup(true)
    if not self._visible then return end

    local uiDef = self:_buildUI()
    if uiDef and dsl.spawn then
        self._entity = dsl.spawn(
            { x = self._position.x, y = self._position.y },
            uiDef,
            "ui",
            2000  -- High z-order for overlay
        )
        if ui and ui.box and ui.box.set_draw_layer then
            ui.box.set_draw_layer(self._entity, "ui")
        end

        -- Add state tags so UI elements are included in collision detection
        -- Deferred by one frame to ensure UI tree is fully constructed
        local entity = self._entity
        timer.after(0, function()
            if entity and registry and registry:valid(entity) then
                if ui and ui.box and ui.box.AddStateTagToUIBox then
                    ui.box.AddStateTagToUIBox(entity, "default_state")
                end
            end
        end, nil, self._timerGroup .. "_state_tags")
    end
    self:_restoreScrollOffsets()
    self._lastFlatIndex = self._flatIndex
end

function GalleryViewer:_buildUI()
    local currentItem = self._flatList[self._flatIndex]
    local showcase = currentItem and currentItem.showcase or nil

    return dsl.strict.root {
        config = {
            padding = 0,
            color = self._colors.background,
            minWidth = self._width,
            minHeight = self._height,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = {
            dsl.strict.vbox {
                config = {
                    align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
                },
                children = {
                    self:_buildHeader(),
                    dsl.strict.hbox {
                        config = {
                            spacing = self._gap,
                            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
                        },
                        children = {
                            self:_buildCategoryList(),
                            dsl.strict.vbox {
                                config = {
                                    id = "gallery_panel_slot",
                                    align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
                                },
                                children = { self:_buildPreviewPanel(showcase) }
                            },
                        }
                    }
                }
            }
        }
    }
end

function GalleryViewer:_buildHeader()
    local function statusTextFn()
        local currentItem = self._flatList[self._flatIndex]
        local categoryName = currentItem and ShowcaseRegistry.getCategoryName(currentItem.category) or "Gallery"
        local showcaseName = currentItem and currentItem.showcase.name or ""
        local totalCount = #self._flatList
        local modeLabel = (self._panelMode == "preview") and "Preview" or "Source"
        local statusText = categoryName
        if showcaseName ~= "" then
            statusText = statusText .. " > " .. showcaseName
        end
        if totalCount > 0 then
            statusText = string.format("%s  (%d/%d)  |  View: %s", statusText, self._flatIndex, totalCount, modeLabel)
        end
        return statusText
    end

    return dsl.strict.vbox {
        config = { padding = 10, color = self._colors.headerBg, minWidth = self._width },
        children = {
            dsl.strict.hbox {
                config = {
                    align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
                    spacing = 12,
                },
                children = {
                    dsl.strict.text("UI Showcase Gallery", { fontSize = 18, color = "white", shadow = true }),
                    dsl.dynamicText(statusTextFn, 11, "", { color = "gray_light", id = "gallery_header_status" }),
                }
            },
            dsl.strict.spacer(4),
            dsl.strict.text("Up/Down or W/S: item  Left/Right, A/D, or Enter/Space: toggle Preview/Source  Mouse wheel: scroll  ESC: close", { fontSize = 10, color = "gray" }),
        }
    }
end

function GalleryViewer:_buildCategoryList()
    local children = {}
    local itemIndex = 0

    for _, categoryId in ipairs(self._categories) do
        -- Category header
        children[#children + 1] = dsl.strict.vbox {
            config = { padding = 4, color = self._colors.headerBg, minWidth = self._listWidth },
            children = {
                dsl.strict.text(ShowcaseRegistry.getCategoryName(categoryId), {
                    fontSize = 12,
                    color = self._colors.categoryText,
                    shadow = true
                })
            }
        }

        -- Showcases in this category
        local showcases = ShowcaseRegistry.getShowcases(categoryId)
        for _, showcase in ipairs(showcases) do
            itemIndex = itemIndex + 1
            local isSelected = (itemIndex == self._flatIndex)
            local itemBgColor = isSelected and self._colors.selectedBg or self._colors.listBg
            local itemId = string.format("gallery_item_%d", itemIndex)
            local itemTextId = string.format("gallery_item_text_%d", itemIndex)

            local capturedIndex = itemIndex
            children[#children + 1] = dsl.strict.vbox {
                config = {
                    id = itemId,
                    padding = 6,
                    color = itemBgColor,
                    minWidth = self._listWidth,
                    hover = true,
                    canCollide = true,
                    buttonCallback = function()
                        self._flatIndex = capturedIndex
                        self:_queueRebuild()
                    end
                },
                children = {
                    dsl.strict.text(string.format("%02d. %s", itemIndex, showcase.name), {
                        id = itemTextId,
                        fontSize = 11,
                        color = isSelected and "white" or self._colors.textDim
                    })
                }
            }
        end

        -- Spacer between categories
        children[#children + 1] = dsl.strict.spacer(4)
    end

    local listContent = dsl.strict.vbox {
        config = {
            padding = 4,
            minWidth = self._listWidth,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = children
    }

    return createScrollPane({ listContent }, {
        id = "gallery_list_scroll",
        width = self._listWidth,
        height = self._listHeight,
        padding = 4,
        color = resolveColor(self._colors.listBg),
    })
end

function GalleryViewer:_buildPreviewPanel(showcase)
    local previewContent = dsl.strict.text("No showcase selected", { color = "gray" })
    if showcase and showcase.create then
        local success, result = pcall(function()
            return showcase.create()
        end)

        if success and result then
            previewContent = result
        else
            previewContent = dsl.strict.text("Error creating preview", { color = "red" })
        end
    end

    -- Build source code display as a single text block (more efficient than per-line elements)
    local sourceText = ""
    if showcase and showcase.source then
        local lines = {}
        local lineIndex = 0
        for line in showcase.source:gmatch("[^\n]+") do
            lineIndex = lineIndex + 1
            lines[#lines + 1] = string.format("%3d  %s", lineIndex, line)
        end
        sourceText = table.concat(lines, "\n")
    end

    local tabButtonWidth = 90
    local tabButtonHeight = 22
    local contentWidth = math.max(160, self._previewWidth - 12)

    local function tabButton(label, mode)
        local active = self._panelMode == mode
        return dsl.strict.button(label, {
            fontSize = 11,
            color = active and "deep_teal" or "charcoal",
            textColor = active and "white" or "gray_light",
            minWidth = tabButtonWidth,
            minHeight = tabButtonHeight,
            onClick = function()
                self:_setPanelMode(mode)
            end
        })
    end

    local tabRow = dsl.strict.hbox {
        config = {
            spacing = 6,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_CENTER),
        },
        children = {
            dsl.strict.text("View:", { fontSize = 11, color = "gray_light" }),
            tabButton("Preview", "preview"),
            tabButton("Source", "source"),
        }
    }

    local contentNode
    if self._panelMode == "source" then
        -- Use single text element for all source code (much more efficient)
        local sourceContent = dsl.strict.vbox {
            config = {
                padding = 2,
                align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
            },
            children = {
                dsl.strict.text(
                    (sourceText ~= "") and sourceText or "-- No source available",
                    {
                        fontSize = 9,
                        color = (sourceText ~= "") and self._colors.sourceCodeText or "gray",
                        fontName = "monospace"
                    }
                )
            }
        }

        contentNode = createScrollPane({ sourceContent }, {
            id = "gallery_source_scroll",
            width = contentWidth,
            height = self._panelContentHeight,
            padding = 6,
            color = resolveColor(self._colors.sourceCodeBg),
        })
    else
        local previewBlock = dsl.strict.vbox {
            config = { padding = 10, color = "dim_gray", minWidth = contentWidth - 20, minHeight = 100 },
            children = { previewContent }
        }

        local previewText = showcase and showcase.description or ""
        local previewContentBox = dsl.strict.vbox {
            config = {
                padding = 4,
                align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
            },
            children = {
                dsl.strict.text(previewText, { fontSize = 10, color = self._colors.textDim }),
                dsl.strict.spacer(8),
                previewBlock,
            }
        }

        contentNode = createScrollPane({ previewContentBox }, {
            id = "gallery_preview_scroll",
            width = contentWidth,
            height = self._panelContentHeight,
            padding = 6,
            color = resolveColor(self._colors.background),
        })
    end

    return dsl.strict.vbox {
        config = {
            padding = 6,
            color = self._colors.background,
            minWidth = self._previewWidth,
            minHeight = self._bodyHeight,
            align = bit.bor(AlignmentFlag.HORIZONTAL_LEFT, AlignmentFlag.VERTICAL_TOP),
        },
        children = {
            tabRow,
            dsl.strict.spacer(6),
            contentNode,
        }
    }
end

--------------------------------------------------------------------------------
-- Incremental Refresh (avoid rebuilding list scroll pane)
--------------------------------------------------------------------------------

function GalleryViewer:_setEntityColor(entity, colorValue)
    if not entity or not registry or not registry.valid then return end
    if not registry:valid(entity) then return end

    local resolved = resolveColor(colorValue)
    if UIStyleConfig then
        local style = component_cache.get(entity, UIStyleConfig)
        if style then
            style.color = resolved
            return
        end
    end

    if UIConfig then
        local cfg = component_cache.get(entity, UIConfig)
        if cfg then
            cfg.color = resolved
        end
    end
end

function GalleryViewer:_updateListSelection(previousIndex, currentIndex)
    if not (self._entity and ui and ui.box and ui.box.GetUIEByID) then return end

    local function updateIndex(index, isSelected)
        if not index or index <= 0 then return end
        local itemId = string.format("gallery_item_%d", index)
        local textId = string.format("gallery_item_text_%d", index)

        local item = ui.box.GetUIEByID(registry, self._entity, itemId)
        if item then
            self:_setEntityColor(item, isSelected and self._colors.selectedBg or self._colors.listBg)
        end

        local text = ui.box.GetUIEByID(registry, self._entity, textId)
        if text then
            self:_setEntityColor(text, isSelected and "white" or self._colors.textDim)
        end
    end

    if previousIndex and previousIndex ~= currentIndex then
        updateIndex(previousIndex, false)
    end
    updateIndex(currentIndex, true)
end

function GalleryViewer:_refreshPanel()
    if not (self._entity and ui and ui.box and ui.box.GetUIEByID and ui.box.ReplaceChildren) then
        return
    end

    local slot = ui.box.GetUIEByID(registry, self._entity, "gallery_panel_slot")
    if not slot or not registry:valid(slot) then return end

    local showcase = self:getCurrentShowcase()
    local newPanel = self:_buildPreviewPanel(showcase)
    ui.box.ReplaceChildren(slot, newPanel)

    if ui.box.AddStateTagToUIBox then
        ui.box.AddStateTagToUIBox(self._entity, "default_state")
    end
end

function GalleryViewer:_refreshUI()
    if not self._entity then return end

    local selectionChanged = (self._lastFlatIndex ~= self._flatIndex)

    self:_captureScrollOffsets()
    if selectionChanged then
        -- Reset preview/source scroll when switching showcases
        self._scrollOffsets.preview = 0
        self._scrollOffsets.source = 0
    end

    if selectionChanged then
        self:_updateListSelection(self._lastFlatIndex, self._flatIndex)
    end

    self:_refreshPanel()
    self:_restoreScrollOffsets()

    self._lastFlatIndex = self._flatIndex
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function GalleryViewer:_cleanup(keepInput)
    if self._entity then
        if dsl and dsl.remove then
            pcall(dsl.remove, self._entity)
        elseif registry and registry.valid and registry:valid(self._entity) then
            registry:destroy(self._entity)
        end
        self._entity = nil
    end

    if not keepInput then
        timer.kill_group(self._timerGroup .. "_input")
        timer.kill_group(self._timerGroup .. "_rebuild")
        timer.kill_group(self._timerGroup .. "_state_tags")
        self._inputPollingActive = false  -- Allow timer to be recreated on next show()
        self._rebuildScheduled = false
    end
end

--------------------------------------------------------------------------------
-- Module Functions (for direct usage without instance)
--------------------------------------------------------------------------------

local _globalViewer = nil

--- Show a global gallery viewer instance (auto-fits to screen if x/y omitted)
---@param x number|nil X position
---@param y number|nil Y position
function GalleryViewer.showGlobal(x, y)
    if not _globalViewer then
        _globalViewer = GalleryViewer.new()
    end
    _globalViewer:show(x, y)
    return _globalViewer
end

--- Show a global gallery viewer instance with optional overrides
---@param x number|nil X position
---@param y number|nil Y position
---@param options table|nil Overrides for size/margins
function GalleryViewer.showGlobalWithOptions(x, y, options)
    if not _globalViewer then
        _globalViewer = GalleryViewer.new(options)
    else
        _globalViewer:_applyOptions(options)
    end
    _globalViewer:show(x, y)
    return _globalViewer
end

--- Hide the global gallery viewer
function GalleryViewer.hideGlobal()
    if _globalViewer then
        _globalViewer:hide()
    end
end

--- Toggle the global gallery viewer
function GalleryViewer.toggleGlobal()
    if _globalViewer then
        _globalViewer:toggle()
    else
        GalleryViewer.showGlobal()
    end
end

--- Destroy the global gallery viewer
function GalleryViewer.destroyGlobal()
    if _globalViewer then
        _globalViewer:destroy()
        _globalViewer = nil
    end
end

return GalleryViewer
