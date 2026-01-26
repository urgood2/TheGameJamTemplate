local M = {}

local function k_val(k) return "mem." .. k .. ".val" end
local function k_exp(k) return "mem." .. k .. ".exp" end

function M.remember(e, key, value, ttl)
    ai.bb.set(e, k_val(key), value)
    if ttl then
        ai.bb.set(e, k_exp(key), GetTime() + ttl)
    else
        ai.bb.set(e, k_exp(key), -1)
    end
end

function M.recall(e, key, default)
    local exp = ai.bb.get(e, k_exp(key), -1)
    if exp ~= -1 and GetTime() > exp then
        ai.bb.set(e, k_exp(key), 0)
        return default
    end
    return ai.bb.get(e, k_val(key), default)
end

function M.has(e, key)
    local exp = ai.bb.get(e, k_exp(key), -1)
    if exp ~= -1 and GetTime() > exp then return false end
    return ai.bb.has(e, k_val(key))
end

function M.forget(e, key)
    ai.bb.set(e, k_exp(key), 0)
end

function M.remember_pos(e, key, pos, ttl)
    ai.bb.set_vec2(e, k_val(key), pos)
    if ttl then
        ai.bb.set(e, k_exp(key), GetTime() + ttl)
    else
        ai.bb.set(e, k_exp(key), -1)
    end
end

function M.recall_pos(e, key)
    local exp = ai.bb.get(e, k_exp(key), -1)
    if exp ~= -1 and GetTime() > exp then
        ai.bb.set(e, k_exp(key), 0)
        return nil
    end
    return ai.bb.get_vec2(e, k_val(key))
end

return M
