------------------------------------------------------------
-- ui_definitions.lua
-- Converts compact Lua tables into full UIElementTemplateNode trees.
-- Example usage:
-- ui.definitions.def{
--     type = "HORIZONTAL_CONTAINER",
--     config = { color = "dusty_rose", align = AlignmentFlag.HORIZONTAL_CENTER },
--     children = { ... }
-- }
------------------------------------------------------------

local Sol2Safety = require("core.sol2_safety")

ui.definitions = ui.definitions or {}

------------------------------------------------------------
-- Helper: Process sprite panel special fields
-- Translates _isSpritePanel, _spriteName, _borders into existing 
-- UIConfig fields (stylingType, nPatchInfo) using animation_system API
------------------------------------------------------------
local function processSpritePanelFields(tbl, builder)
    if not tbl._isSpritePanel then return false end
    
    local spriteName = tbl._spriteName
    if not spriteName then
        log_warn("[ui.def] _isSpritePanel set but no _spriteName provided")
        return false
    end
    
    local nPatchInfo, atlasTexture = animation_system.getNinepatchUIBorderInfo(spriteName)
    if not nPatchInfo then
        log_warn("[ui.def] Sprite not found for spritePanel: " .. tostring(spriteName))
        return false
    end
    
    local borders = tbl._borders or { left = 8, top = 8, right = 8, bottom = 8 }
    if type(borders) == "table" and borders[1] then
        borders = { left = borders[1], top = borders[2], right = borders[3], bottom = borders[4] }
    end
    
    nPatchInfo.left = borders.left or 8
    nPatchInfo.top = borders.top or 8
    nPatchInfo.right = borders.right or 8
    nPatchInfo.bottom = borders.bottom or 8
    
    builder:addStylingType(UIStylingType.NinePatchBorders)
    builder:addNPatchInfo(nPatchInfo)
    builder:addNPatchSourceTexture(atlasTexture)
    
    local sizing = tbl._sizing or "fit_content"
    if sizing == "fit_sprite" then
        local sw = nPatchInfo.source.width
        local sh = nPatchInfo.source.height
        builder:addMinWidth(math.floor(sw))
        builder:addMinHeight(math.floor(sh))
        builder:addMaxWidth(math.floor(sw))
        builder:addMaxHeight(math.floor(sh))
    end
    
    if tbl._tint then
        builder:addColor(tbl._tint)
    else
        builder:addColor(Col(255, 255, 255, 255))
    end
    
    if tbl._decorations and #tbl._decorations > 0 then
        local positionToAnchor = {
            top_left = UIDecorationAnchor.TopLeft,
            top_center = UIDecorationAnchor.TopCenter,
            top_right = UIDecorationAnchor.TopRight,
            middle_left = UIDecorationAnchor.MiddleLeft,
            center = UIDecorationAnchor.Center,
            middle_right = UIDecorationAnchor.MiddleRight,
            bottom_left = UIDecorationAnchor.BottomLeft,
            bottom_center = UIDecorationAnchor.BottomCenter,
            bottom_right = UIDecorationAnchor.BottomRight,
        }
        
        local decorations = UIDecorations.new()
        for _, decor in ipairs(tbl._decorations) do
            if not decor.sprite or decor.sprite == "" then
                log_warn("[ui.def] Decoration missing sprite name, skipping")
                goto continue_decoration
            end
            
            local d = UIDecoration.new()
            d.spriteName = decor.sprite
            d.anchor = positionToAnchor[decor.position] or UIDecorationAnchor.TopLeft
            if decor.offset then
                d.offset = Vector2(decor.offset[1] or 0, decor.offset[2] or 0)
            end
            d.opacity = decor.opacity or 1.0
            d.flipX = decor.flip == "x" or decor.flip == "both"
            d.flipY = decor.flip == "y" or decor.flip == "both"
            d.rotation = decor.rotation or 0
            if decor.scale then
                if type(decor.scale) == "number" then
                    d.scale = Vector2(decor.scale, decor.scale)
                else
                    d.scale = Vector2(decor.scale[1] or 1, decor.scale[2] or 1)
                end
            else
                d.scale = Vector2(1.0, 1.0)
            end
            d.zOffset = decor.zOffset or 0
            d.visible = decor.visible ~= false
            d.id = decor.id or ""
            if decor.tint then
                if type(decor.tint) == "string" then
                    local ok, result = pcall(util.getColor, decor.tint)
                    if ok and result then
                        d.tint = result
                    end
                elseif type(decor.tint) == "userdata" then
                    d.tint = decor.tint
                end
            end
            decorations:add(d)
            
            ::continue_decoration::
        end
        builder:addDecorations(decorations)
        log_debug("[ui.def] Added " .. decorations:count() .. " decorations")
    end
    
    log_debug("[ui.def] Configured spritePanel with sprite: " .. spriteName)
    return true
end

------------------------------------------------------------
-- Helper: Process sprite button special fields
-- Translates _isSpriteButton, _states into existing UIConfig fields
------------------------------------------------------------
local function processSpriteButtonFields(tbl, builder)
    if not tbl._isSpriteButton then return false end
    
    local states = tbl._states
    if not states or not states.normal then
        log_warn("[ui.def] _isSpriteButton set but no _states.normal provided")
        return false
    end
    
    local spriteName = states.normal
    local nPatchInfo, atlasTexture = animation_system.getNinepatchUIBorderInfo(spriteName)
    if not nPatchInfo then
        log_warn("[ui.def] Sprite not found for spriteButton: " .. tostring(spriteName))
        return false
    end
    
    local borders = tbl._borders or { left = 4, top = 4, right = 4, bottom = 4 }
    if type(borders) == "table" and borders[1] then
        borders = { left = borders[1], top = borders[2], right = borders[3], bottom = borders[4] }
    end
    
    nPatchInfo.left = borders.left or 4
    nPatchInfo.top = borders.top or 4
    nPatchInfo.right = borders.right or 4
    nPatchInfo.bottom = borders.bottom or 4
    
    builder:addStylingType(UIStylingType.NinePatchBorders)
    builder:addNPatchInfo(nPatchInfo)
    builder:addNPatchSourceTexture(atlasTexture)
    builder:addColor(Col(255, 255, 255, 255))
    
    log_debug("[ui.def] Configured spriteButton with sprite: " .. spriteName)
    return true
end

------------------------------------------------------------
-- Helper: Build UIConfig from table
------------------------------------------------------------
local function makeConfigFromTable(tbl)
    if not tbl then
        return UIConfigBuilder.create():build()
    end

    local b = UIConfigBuilder.create()

    -- Process sprite panel/button fields first (they set up stylingType etc.)
    local isSprite = processSpritePanelFields(tbl, b)
    if not isSprite then
        processSpriteButtonFields(tbl, b)
    end

    for k, v in pairs(tbl) do
        ------------------------------------------------------------
        -- CRITICAL: Skip nil values entirely
        -- Sol2 crashes with SIGSEGV when passing nil to C++ methods
        -- expecting const references (e.g., addColor(const Color&))
        -- The crash happens during argument conversion, before pcall can catch it
        ------------------------------------------------------------
        if not Sol2Safety.isSafe(v) then
            goto continue
        end
        
        -- Skip underscore-prefixed sprite panel/button fields (already processed above)
        if k:sub(1, 1) == "_" then
            goto continue
        end

        ------------------------------------------------------------
        -- Inline conversions and type validation
        ------------------------------------------------------------
        -- Handle color keys specially: they must be valid Color userdata
        local colorKeys = { color = true, outlineColor = true, shadowColor = true,
                            progressBarEmptyColor = true, progressBarFullColor = true }

        if colorKeys[k] then
            -- If it's a string, convert to Color
            if type(v) == "string" then
                local ok, result = pcall(util.getColor, v)
                if not ok or result == nil then
                    log_debug("[ui.def] util.getColor failed for " .. k .. ": " .. tostring(v) .. ", skipping")
                    goto continue
                end
                v = result
            end
            -- Validate that v is now a userdata (Color)
            if type(v) ~= "userdata" then
                local tableInfo = ""
                if type(v) == "table" then
                    local keys = {}
                    for tk, _ in pairs(v) do keys[#keys+1] = tostring(tk) end
                    tableInfo = " (keys: " .. table.concat(keys, ", ") .. ")"
                end
                log_debug("[ui.def] Invalid type for " .. k .. ": expected Color userdata, got " .. type(v) .. tableInfo .. ", skipping")
                goto continue
            end
        elseif k == "tooltip" and type(v) == "table" then
            local t = Tooltip.new()
            t.title = v.title or ""
            t.text = v.text or ""
            v = t
        elseif k == "focusArgs" and type(v) == "table" then
            local f = FocusArgs.new()
            for fk, fv in pairs(v) do f[fk] = fv end
            v = f
        end

        ------------------------------------------------------------
        -- Resolve addX() builder methods dynamically
        ------------------------------------------------------------
        local addFn = "add" .. k:sub(1,1):upper() .. k:sub(2)
        local fn = b[addFn]

        if fn then
            local ok, err = pcall(fn, b, v)
            if not ok then
                log_debug("[ui.def] Failed to apply key: " .. k .. " (" .. tostring(err) .. ")")
            end
        else
            log_debug("[ui.def] Unknown config key: " .. tostring(k))
        end

        ::continue::
    end

    return b:build()
end

------------------------------------------------------------
-- Helper: Recursively build UIElementTemplateNode
------------------------------------------------------------
local function makeNodeFromTable(tbl)
    -- Entity wrapper shortcut: { obj = entity }
    if tbl.obj then
        return ui.definitions.wrapEntityInsideObjectElement(tbl.obj)
    end

    local nb = UIElementTemplateNodeBuilder.create()

    ------------------------------------------------------------
    -- Type (string or enum)
    ------------------------------------------------------------
    local t = tbl.type
    if type(t) == "string" then
        local enumVal = UITypeEnum[t]
        if not enumVal then
            error("[ui.def] Unknown UITypeEnum: " .. tostring(t))
        end
        nb:addType(enumVal)
    elseif type(t) == "number" then
        nb:addType(t)
    end

    ------------------------------------------------------------
    -- Config
    ------------------------------------------------------------
    if tbl.config then
        local cfg = tbl.config

        -- if it's a Lua table, build it
        if type(cfg) == "table" then
            nb:addConfig(makeConfigFromTable(cfg))

        -- if it's a userdata (already a UIConfig)
        elseif type(cfg) == "userdata" or type(cfg) == "cdata" then
            nb:addConfig(cfg)

        else
            log_debug("[ui.def] Unsupported config type: " .. tostring(type(cfg)))
        end
    end

    ------------------------------------------------------------
    -- Children (recursive)
    ------------------------------------------------------------
    if tbl.children then
        for _, child in ipairs(tbl.children) do
            nb:addChild(makeNodeFromTable(child))
        end
    end

    return nb:build()
end

------------------------------------------------------------
-- Public entry point
------------------------------------------------------------
ui.definitions.def = makeNodeFromTable
