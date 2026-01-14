--[[
================================================================================
GALLERY VIEWER - Interactive UI Showcase Browser
================================================================================
A gallery viewer for browsing UI component examples visually.

Features:
- Category-based navigation (primitives, layouts, patterns)
- Visual preview of selected showcase
- Source code display alongside preview
- Keyboard navigation (Up/Down to browse, Enter to select)
- Mouse support for clicking items

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
- UP/DOWN or W/S: Navigate through showcases
- ENTER or SPACE: Select/expand current showcase
- ESC: Close viewer or go back to category list
- TAB: Switch between category list and showcase list
================================================================================
]]

local dsl = require("ui.ui_syntax_sugar")
local timer = require("core.timer")
local ShowcaseRegistry = require("ui.showcase.showcase_registry")

local GalleryViewer = {}
GalleryViewer.__index = GalleryViewer

-- Key mappings
local KEY_MAPPINGS = {
    up = { "KEY_UP", "KEY_W" },
    down = { "KEY_DOWN", "KEY_S" },
    select = { "KEY_ENTER", "KEY_SPACE" },
    back = { "KEY_ESCAPE" },
    tab = { "KEY_TAB" },
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
    self._previewEntity = nil
    self._position = { x = 0, y = 0 }

    -- Navigation state
    self._categories = ShowcaseRegistry.getCategories()
    self._currentCategoryIndex = 1
    self._currentShowcaseIndex = 1
    self._flatList = ShowcaseRegistry.getFlatList()
    self._flatIndex = 1  -- Current position in flat list
    self._viewMode = "list"  -- "list" or "detail"

    -- UI dimensions
    self._width = options.width or 700
    self._height = options.height or 450
    self._listWidth = 200
    self._previewWidth = self._width - self._listWidth - 20  -- 20 for gap

    -- Colors
    self._colors = {
        background = "darkslategray",
        listBg = "slategray",
        selectedBg = "steelblue",
        hoverBg = "lightslategray",
        headerBg = "dimgray",
        text = "white",
        textDim = "lightgray",
        categoryText = "gold",
        sourceCodeBg = "black",
        sourceCodeText = "lime",
    }

    return self
end

--------------------------------------------------------------------------------
-- Public Methods
--------------------------------------------------------------------------------

--- Show the gallery viewer at the specified position
---@param x number X position
---@param y number Y position
function GalleryViewer:show(x, y)
    self._position = { x = x or 0, y = y or 0 }
    self._visible = true
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
-- Navigation
--------------------------------------------------------------------------------

function GalleryViewer:_navigateUp()
    if self._flatIndex > 1 then
        self._flatIndex = self._flatIndex - 1
        self:_rebuild()
    end
end

function GalleryViewer:_navigateDown()
    if self._flatIndex < #self._flatList then
        self._flatIndex = self._flatIndex + 1
        self:_rebuild()
    end
end

function GalleryViewer:_selectCurrent()
    -- Toggle detail/list view or trigger preview update
    self:_rebuildPreview()
end

function GalleryViewer:_goBack()
    if self._viewMode == "detail" then
        self._viewMode = "list"
        self:_rebuild()
    else
        self:hide()
    end
end

--------------------------------------------------------------------------------
-- Input Handling
--------------------------------------------------------------------------------

function GalleryViewer:_startInputPolling()
    timer.every(0.05, function()
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
    self:_cleanup()
    if not self._visible then return end

    local ui = self:_buildUI()
    if ui and dsl.spawn then
        self._entity = dsl.spawn(
            { x = self._position.x, y = self._position.y },
            ui,
            "ui",
            900  -- High z-order for overlay
        )
    end

    self:_rebuildPreview()
end

function GalleryViewer:_rebuildPreview()
    -- Clean up existing preview
    if self._previewEntity and registry and registry:valid(self._previewEntity) then
        registry:destroy(self._previewEntity)
        self._previewEntity = nil
    end

    local currentItem = self._flatList[self._flatIndex]
    if not currentItem then return end

    local showcase = currentItem.showcase
    if showcase and showcase.create then
        local previewUI = self:_buildPreviewPanel(showcase)
        if previewUI and dsl.spawn then
            self._previewEntity = dsl.spawn(
                {
                    x = self._position.x + self._listWidth + 10,
                    y = self._position.y + 50  -- Below header
                },
                previewUI,
                "ui",
                901  -- Above main panel
            )
        end
    end
end

function GalleryViewer:_buildUI()
    return dsl.root {
        config = {
            padding = 0,
            color = self._colors.background,
            minWidth = self._width,
            minHeight = self._height,
        },
        children = {
            dsl.vbox {
                children = {
                    self:_buildHeader(),
                    dsl.hbox {
                        children = {
                            self:_buildCategoryList(),
                        }
                    }
                }
            }
        }
    }
end

function GalleryViewer:_buildHeader()
    local currentItem = self._flatList[self._flatIndex]
    local categoryName = currentItem and ShowcaseRegistry.getCategoryName(currentItem.category) or "Gallery"
    local showcaseName = currentItem and currentItem.showcase.name or ""

    return dsl.vbox {
        config = { padding = 10, color = self._colors.headerBg, minWidth = self._width },
        children = {
            dsl.hbox {
                children = {
                    dsl.text("UI Showcase Gallery", { fontSize = 18, color = "white", shadow = true }),
                    dsl.spacer(20),
                    dsl.text(categoryName .. " > " .. showcaseName, { fontSize = 12, color = "lightgray" }),
                }
            },
            dsl.spacer(4),
            dsl.text("Use UP/DOWN to navigate, ENTER to select, ESC to close", { fontSize = 10, color = "gray" }),
        }
    }
end

function GalleryViewer:_buildCategoryList()
    local children = {}
    local itemIndex = 0

    for _, categoryId in ipairs(self._categories) do
        -- Category header
        children[#children + 1] = dsl.vbox {
            config = { padding = 4, color = self._colors.headerBg, minWidth = self._listWidth },
            children = {
                dsl.text(ShowcaseRegistry.getCategoryName(categoryId), {
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

            local capturedIndex = itemIndex
            children[#children + 1] = dsl.vbox {
                config = {
                    padding = 6,
                    color = itemBgColor,
                    minWidth = self._listWidth,
                    hover = true,
                    canCollide = true,
                    buttonCallback = function()
                        self._flatIndex = capturedIndex
                        self:_rebuild()
                    end
                },
                children = {
                    dsl.text(showcase.name, {
                        fontSize = 11,
                        color = isSelected and "white" or self._colors.textDim
                    })
                }
            }
        end

        -- Spacer between categories
        children[#children + 1] = dsl.spacer(4)
    end

    return dsl.vbox {
        config = { padding = 4, minWidth = self._listWidth, minHeight = self._height - 50 },
        children = children
    }
end

function GalleryViewer:_buildPreviewPanel(showcase)
    local previewContent
    local success, result = pcall(function()
        return showcase.create()
    end)

    if success and result then
        previewContent = result
    else
        previewContent = dsl.text("Error creating preview", { color = "red" })
    end

    -- Build source code display
    local sourceLines = {}
    if showcase.source then
        for line in showcase.source:gmatch("[^\n]+") do
            sourceLines[#sourceLines + 1] = dsl.text(line, {
                fontSize = 9,
                color = self._colors.sourceCodeText,
                fontName = "monospace"
            })
        end
    end

    return dsl.vbox {
        config = { padding = 8, color = self._colors.background, minWidth = self._previewWidth },
        children = {
            -- Preview section
            dsl.vbox {
                config = { padding = 4 },
                children = {
                    dsl.text("Preview", { fontSize = 12, color = self._colors.categoryText, shadow = true }),
                    dsl.spacer(4),
                    dsl.text(showcase.description or "", { fontSize = 10, color = self._colors.textDim }),
                    dsl.spacer(8),
                }
            },

            -- Live preview
            dsl.vbox {
                config = { padding = 10, color = "dimgray", minWidth = self._previewWidth - 20, minHeight = 100 },
                children = { previewContent }
            },

            dsl.spacer(12),

            -- Source code section
            dsl.vbox {
                config = { padding = 4 },
                children = {
                    dsl.text("Source Code", { fontSize = 12, color = self._colors.categoryText, shadow = true }),
                    dsl.spacer(4),
                }
            },

            -- Source code display
            dsl.vbox {
                config = {
                    padding = 8,
                    color = self._colors.sourceCodeBg,
                    minWidth = self._previewWidth - 20,
                    minHeight = 80
                },
                children = #sourceLines > 0 and sourceLines or {
                    dsl.text("-- No source available", { fontSize = 9, color = "gray" })
                }
            },
        }
    }
end

--------------------------------------------------------------------------------
-- Cleanup
--------------------------------------------------------------------------------

function GalleryViewer:_cleanup()
    if self._entity and registry and registry:valid(self._entity) then
        registry:destroy(self._entity)
        self._entity = nil
    end

    if self._previewEntity and registry and registry:valid(self._previewEntity) then
        registry:destroy(self._previewEntity)
        self._previewEntity = nil
    end

    timer.kill_group(self._timerGroup .. "_input")
end

--------------------------------------------------------------------------------
-- Module Functions (for direct usage without instance)
--------------------------------------------------------------------------------

local _globalViewer = nil

--- Show a global gallery viewer instance
---@param x number|nil X position (default: 50)
---@param y number|nil Y position (default: 50)
function GalleryViewer.showGlobal(x, y)
    if not _globalViewer then
        _globalViewer = GalleryViewer.new()
    end
    _globalViewer:show(x or 50, y or 50)
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
