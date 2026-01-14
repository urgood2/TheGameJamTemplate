---@module core.sol2_safety
--- Safety utilities for Sol2 C++ interop.
--- Prevents SIGSEGV crashes from passing nil to C++ methods.

local Sol2Safety = {}

--- Safely call a builder method, skipping if value is nil.
--- @param builder userdata The Sol2 builder object
--- @param method string The method name (e.g., "addColor")
--- @param value any The value to pass (skipped if nil)
--- @return userdata The builder (for chaining)
function Sol2Safety.safeBuilderCall(builder, method, value)
    if value == nil then
        return builder
    end

    local fn = builder[method]
    if not fn then
        log_debug("[sol2_safety] Unknown method: " .. tostring(method))
        return builder
    end

    local ok, err = pcall(fn, builder, value)
    if not ok then
        log_warn("[sol2_safety] Builder call failed: " .. method .. " - " .. tostring(err))
    end

    return builder
end

--- Safely apply multiple values to a builder.
--- @param builder userdata The Sol2 builder object
--- @param values table Key-value pairs where keys are method suffixes (e.g., "Color" for "addColor")
--- @return userdata The builder (for chaining)
function Sol2Safety.safeApplyAll(builder, values)
    for key, value in pairs(values) do
        if value ~= nil then
            local method = "add" .. key:sub(1,1):upper() .. key:sub(2)
            Sol2Safety.safeBuilderCall(builder, method, value)
        end
    end
    return builder
end

--- Check if a value is safe to pass to C++ (not nil, not invalid userdata).
--- @param value any The value to check
--- @return boolean True if safe to pass
function Sol2Safety.isSafe(value)
    if value == nil then
        return false
    end

    -- Check for invalid userdata (destroyed Sol2 objects)
    if type(value) == "userdata" then
        local ok, _ = pcall(tostring, value)
        return ok
    end

    return true
end

--- Wrap a function to skip execution if any argument is nil.
--- @param fn function The function to wrap
--- @return function The wrapped function
function Sol2Safety.nilGuard(fn)
    return function(...)
        local args = {...}
        for i, arg in ipairs(args) do
            if arg == nil then
                log_debug("[sol2_safety] nilGuard: skipping call, arg " .. i .. " is nil")
                return nil
            end
        end
        return fn(...)
    end
end

return Sol2Safety
