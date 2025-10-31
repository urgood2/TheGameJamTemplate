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
        -- Inline conversions
        ------------------------------------------------------------
        if k == "color" and type(v) == "string" then
            v = util.getColor(v)
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
