-- assets/scripts/test/json.lua
-- Minimal JSON encoder with deterministic key ordering.

local json = {}

local function is_array(tbl)
    if type(tbl) ~= "table" then
        return false, 0
    end
    local count = 0
    for k, _ in pairs(tbl) do
        if type(k) ~= "number" then
            return false, 0
        end
        if k > count then
            count = k
        end
    end
    for i = 1, count do
        if tbl[i] == nil then
            return false, 0
        end
    end
    return true, count
end

local function escape_string(value)
    return value
        :gsub("\\", "\\\\")
        :gsub("\"", "\\\"")
        :gsub("\n", "\\n")
        :gsub("\r", "\\r")
        :gsub("\t", "\\t")
end

local function sorted_keys(tbl)
    local keys = {}
    for k, _ in pairs(tbl) do
        table.insert(keys, k)
    end
    table.sort(keys, function(a, b)
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function encode_value(value, indent, pretty)
    local t = type(value)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return value and "true" or "false"
    elseif t == "number" then
        return tostring(value)
    elseif t == "string" then
        return "\"" .. escape_string(value) .. "\""
    elseif t == "table" then
        local is_arr, count = is_array(value)
        if is_arr then
            local parts = {}
            for i = 1, count do
                table.insert(parts, encode_value(value[i], indent, pretty))
            end
            if pretty then
                return "[ " .. table.concat(parts, ", ") .. " ]"
            end
            return "[" .. table.concat(parts, ",") .. "]"
        end

        local parts = {}
        local keys = sorted_keys(value)
        local child_indent = indent .. "  "
        for _, k in ipairs(keys) do
            local v = value[k]
            local key = "\"" .. escape_string(tostring(k)) .. "\""
            local encoded = encode_value(v, child_indent, pretty)
            if pretty then
                table.insert(parts, child_indent .. key .. ": " .. encoded)
            else
                table.insert(parts, key .. ":" .. encoded)
            end
        end

        if pretty then
            if #parts == 0 then
                return "{}"
            end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
        end
        return "{" .. table.concat(parts, ",") .. "}"
    end

    return "null"
end

function json.encode(value, pretty)
    return encode_value(value, "", pretty == true)
end

return json
