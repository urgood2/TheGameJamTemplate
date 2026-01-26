local T = {}

function T.apply(e, mappings)
    for _, m in ipairs(mappings) do
        local val = ai.bb.get(e, m.bb, m.default or 0)
        local result = false

        if m.gt and val > m.gt then result = true end
        if m.lt and val < m.lt then result = true end
        if m.eq and val == m.eq then result = true end

        ai.set_worldstate(e, m.atom, result)
    end
end

return T
