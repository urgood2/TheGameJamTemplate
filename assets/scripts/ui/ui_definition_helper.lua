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

ui.definitions = ui.definitions or {}

------------------------------------------------------------
-- Helper: Build UIConfig from table
------------------------------------------------------------
local function makeConfigFromTable(tbl)
    if not tbl then
        return UIConfigBuilder.create():build()
    end

    local b = UIConfigBuilder.create()

    for k, v in pairs(tbl) do
        ------------------------------------------------------------
        -- CRITICAL: Skip nil values entirely
        -- Sol2 crashes with SIGSEGV when passing nil to C++ methods
        -- expecting const references (e.g., addColor(const Color&))
        -- The crash happens during argument conversion, before pcall can catch it
        ------------------------------------------------------------
        if v == nil then
            log_debug("[ui.def] Skipping nil value for key: " .. tostring(k))
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
                log_debug("[ui.def] Invalid type for " .. k .. ": expected Color userdata, got " .. type(v) .. ", skipping")
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
