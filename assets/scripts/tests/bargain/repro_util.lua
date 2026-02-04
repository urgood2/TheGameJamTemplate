-- assets/scripts/tests/bargain/repro_util.lua
-- Minimal JSON repro helpers for Bargain headless tests.

local repro_util = {}

local NULL = {}
local EMPTY_ARRAY = {}

repro_util.NULL = NULL
repro_util.EMPTY_ARRAY = EMPTY_ARRAY

local function json_encode(val)
    if val == NULL then return "null" end
    if val == EMPTY_ARRAY then return "[]" end

    local t = type(val)
    if t == "nil" then return "null"
    elseif t == "boolean" then return val and "true" or "false"
    elseif t == "number" then
        if val ~= val then return "null" end -- NaN
        if val == math.huge then return "1e308" end
        if val == -math.huge then return "-1e308" end
        return tostring(val)
    elseif t == "string" then
        return '"' .. val:gsub('\\', '\\\\')
                          :gsub('"', '\\"')
                          :gsub('\n', '\\n')
                          :gsub('\r', '\\r')
                          :gsub('\t', '\\t') .. '"'
    elseif t == "table" then
        -- Check if array
        local is_array = true
        local max_idx = 0
        local count = 0
        for k, _ in pairs(val) do
            count = count + 1
            if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
                is_array = false
                break
            end
            max_idx = math.max(max_idx, k)
        end
        if is_array and max_idx == count then
            local parts = {}
            for i = 1, #val do
                parts[i] = json_encode(val[i])
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            local keys = {}
            for k in pairs(val) do keys[#keys + 1] = k end
            table.sort(keys, function(a, b)
                return tostring(a) < tostring(b)
            end)
            for _, k in ipairs(keys) do
                parts[#parts + 1] = json_encode(tostring(k)) .. ":" .. json_encode(val[k])
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        return '"[' .. t .. ']"'
    end
end

repro_util.json_encode = json_encode

function repro_util.default_state()
    return {
        seed = 0,
        script_id = "HARNESS",
        floor_num = 0,
        turn = 0,
        phase = "INIT",
        run_state = "running",
        last_input = NULL,
        pending_offer = NULL,
        last_events = EMPTY_ARRAY,
        digest = "",
        digest_version = "bargain.v1",
        caps_hit = false,
        world_snapshot_path = NULL,
    }
end

local function merge_state(base, overrides)
    local out = {}
    for k, v in pairs(base) do
        out[k] = v
    end
    if overrides then
        for k, v in pairs(overrides) do
            if out[k] ~= nil then
                out[k] = v
            end
        end
    end
    return out
end

function repro_util.emit_repro(base_state, overrides)
    local payload = merge_state(base_state, overrides)
    print(json_encode(payload))
end

return repro_util
