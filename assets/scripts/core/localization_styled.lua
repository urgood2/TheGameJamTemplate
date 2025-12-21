--- localization_styled.lua
--- Extends localization global with getStyled() for color-coded text
---
--- Usage:
---   local text = localization.getStyled("tooltip.attack", { damage = 25 })
---   -- With JSON: "Deal {damage|red} damage"
---   -- Returns: "Deal [25](color=red) damage"

local M = {}

--- Parse {param|color} patterns and substitute with colored markup
--- @param key string Localization key (e.g., "tooltip.attack_desc")
--- @param params table|nil Parameter values, either simple or {value=X, color="Y"}
--- @return string Processed string with [value](color=X) markup
function M.getStyled(key, params)
    -- Get raw template without fmt substitution
    local template = localization.getRaw(key)
    if not template then
        return "[MISSING: " .. tostring(key) .. "]"
    end

    -- Parse {param|color} patterns
    local result = template:gsub("{([^}]+)}", function(match)
        -- Split on pipe: "damage|red" -> name="damage", defaultColor="red"
        local name, defaultColor = match:match("^([^|]+)|?(.*)$")

        -- Look up parameter
        local param = params and params[name]

        -- If no param provided, keep original placeholder
        if param == nil then
            return "{" .. match .. "}"
        end

        -- Handle table form: {value=X, color="Y"} or simple value
        local value, color
        if type(param) == "table" then
            value = param.value
            color = param.color or (defaultColor ~= "" and defaultColor) or nil
        else
            value = param
            color = (defaultColor ~= "" and defaultColor) or nil
        end

        -- Wrap in color markup if color specified
        if color then
            return "[" .. tostring(value) .. "](color=" .. color .. ")"
        else
            return tostring(value)
        end
    end)

    return result
end

-- Register on localization global
if localization then
    localization.getStyled = M.getStyled
end

return M
