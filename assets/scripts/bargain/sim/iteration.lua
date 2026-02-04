-- assets/scripts/bargain/sim/iteration.lua

local iteration = {}

--- Deterministic iteration over array-like tables
--- @param list table Array
--- @return function iterator
function iteration.ipairs_ordered(list)
    local i = 0
    local n = #list
    return function()
        i = i + 1
        if i <= n then
            return i, list[i]
        end
        return nil
    end
end

--- Deterministic iteration over table keys
--- @param tbl table
--- @param comparator function|nil Optional comparator for keys
--- @return function iterator
function iteration.sorted_pairs(tbl, comparator)
    local keys = {}
    for k in pairs(tbl) do
        keys[#keys + 1] = k
    end

    local cmp = comparator
    if not cmp then
        cmp = function(a, b)
            return tostring(a) < tostring(b)
        end
    end

    table.sort(keys, cmp)

    local i = 0
    return function()
        i = i + 1
        local key = keys[i]
        if key ~= nil then
            return key, tbl[key]
        end
        return nil
    end
end

return iteration
