local A = {}

function A.instant(opts)
    return {
        name = opts.name,
        cost = opts.cost or 1,
        pre = opts.pre or {},
        post = opts.post or {},
        start = opts.on_start or function() end,
        update = function(e, dt)
            return ActionResult.SUCCESS
        end,
        finish = opts.on_finish or function() end,
    }
end

function A.timed(opts)
    local duration = opts.duration or 1.0
    local t0_key = "action." .. opts.name .. ".t0"

    return {
        name = opts.name,
        cost = opts.cost or 1,
        pre = opts.pre or {},
        post = opts.post or {},
        start = function(e)
            ai.bb.set(e, t0_key, GetTime())
            if opts.on_start then opts.on_start(e) end
        end,
        update = function(e, dt)
            if opts.on_tick then opts.on_tick(e, dt) end

            local elapsed = GetTime() - ai.bb.get(e, t0_key, GetTime())
            if elapsed >= duration then
                return ActionResult.SUCCESS
            end
            return ActionResult.RUNNING
        end,
        finish = opts.on_finish or function() end,
    }
end

function A.with_timeout(action, timeout)
    local t0_key = "action." .. action.name .. ".timeout_t0"
    local original_start = action.start
    local original_update = action.update

    action.start = function(e)
        ai.bb.set(e, t0_key, GetTime())
        if original_start then original_start(e) end
    end

    action.update = function(e, dt)
        local elapsed = GetTime() - ai.bb.get(e, t0_key, GetTime())
        if elapsed >= timeout then
            if ai.debug and ai.debug.trace then
                ai.debug.trace(e, "action", "Timeout: " .. action.name)
            end
            return ActionResult.FAILURE
        end
        return original_update(e, dt)
    end

    return action
end

return A
