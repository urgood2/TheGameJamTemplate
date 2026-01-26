ai = ai or {}
ai.bb = ai.bb or {}

if not blackboardContains then
    function blackboardContains(e, key)
        if ai.bb.has then
            return ai.bb.has(e, key)
        end
        if ai.get_blackboard then
            local bb = ai.get_blackboard(e)
            return bb and bb:contains(key) or false
        end
        return false
    end
end

if not getBlackboardFloat then
    function getBlackboardFloat(e, key)
        if not blackboardContains(e, key) then return nil end
        if ai.bb.get then
            return ai.bb.get(e, key, 0.0)
        end
        if ai.get_blackboard then
            local bb = ai.get_blackboard(e)
            return bb and bb:get_float(key) or nil
        end
        return nil
    end
end

if not setBlackboardFloat then
    function setBlackboardFloat(e, key, v)
        if ai.bb.set then
            ai.bb.set(e, key, v)
            return
        end
        if ai.get_blackboard then
            local bb = ai.get_blackboard(e)
            if bb then bb:set_float(key, v) end
        end
    end
end

if not getBlackboardInt then
    function getBlackboardInt(e, key)
        if not blackboardContains(e, key) then return nil end
        if ai.bb.get then
            return ai.bb.get(e, key, 0)
        end
        if ai.get_blackboard then
            local bb = ai.get_blackboard(e)
            return bb and bb:get_int(key) or nil
        end
        return nil
    end
end

if not setBlackboardInt then
    function setBlackboardInt(e, key, v)
        if ai.bb.set then
            ai.bb.set(e, key, v)
            return
        end
        if ai.get_blackboard then
            local bb = ai.get_blackboard(e)
            if bb then bb:set_int(key, v) end
        end
    end
end

if not getBlackboardBool then
    function getBlackboardBool(e, key)
        if not blackboardContains(e, key) then return nil end
        if ai.bb.get then
            return ai.bb.get(e, key, false)
        end
        if ai.get_blackboard then
            local bb = ai.get_blackboard(e)
            return bb and bb:get_bool(key) or nil
        end
        return nil
    end
end

if not setBlackboardBool then
    function setBlackboardBool(e, key, v)
        if ai.bb.set then
            ai.bb.set(e, key, v)
            return
        end
        if ai.get_blackboard then
            local bb = ai.get_blackboard(e)
            if bb then bb:set_bool(key, v) end
        end
    end
end

if not getBlackboardString then
    function getBlackboardString(e, key)
        if not blackboardContains(e, key) then return nil end
        if ai.bb.get then
            return ai.bb.get(e, key, "")
        end
        if ai.get_blackboard then
            local bb = ai.get_blackboard(e)
            return bb and bb:get_string(key) or nil
        end
        return nil
    end
end

if not setBlackboardString then
    function setBlackboardString(e, key, v)
        if ai.bb.set then
            ai.bb.set(e, key, v)
            return
        end
        if ai.get_blackboard then
            local bb = ai.get_blackboard(e)
            if bb then bb:set_string(key, v) end
        end
    end
end

if not setBlackboardVector2 then
    function setBlackboardVector2(e, key, pos)
        if ai.bb.set_vec2 then
            ai.bb.set_vec2(e, key, pos)
            return
        end
        if ai.get_blackboard then
            local bb = ai.get_blackboard(e)
            if bb then
                local x = pos and pos.x or 0
                local y = pos and pos.y or 0
                bb:set_float(key .. ".x", x)
                bb:set_float(key .. ".y", y)
            end
        end
    end
end

if not getBlackboardVector2 then
    function getBlackboardVector2(e, key)
        if ai.bb.get_vec2 then
            return ai.bb.get_vec2(e, key)
        end
        if ai.get_blackboard then
            local bb = ai.get_blackboard(e)
            if bb then
                local kx = key .. ".x"
                local ky = key .. ".y"
                if bb:contains(kx) and bb:contains(ky) then
                    local x = bb:get_float(kx)
                    local y = bb:get_float(ky)
                    return { x = x, y = y }
                end
            end
        end
        return nil
    end
end

return ai.bb
