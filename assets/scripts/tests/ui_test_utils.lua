--[[
    UITestUtils - Test utilities for UI validation

    Provides helpers for spawning UI and asserting validation rules.
]]

local UITestUtils = {}

local dsl = require("ui.ui_syntax_sugar")
local UIValidator = require("core.ui_validator")

---Spawn UI and wait for layout to complete
---@param uiDef table UI definition from dsl.*
---@param pos table {x, y} spawn position
---@param opts? table Optional spawn options
---@return number entity
function UITestUtils.spawnAndWait(uiDef, pos, opts)
    local entity = dsl.spawn(pos, uiDef, nil, nil, opts)
    -- In synchronous tests, layout is immediate
    -- In real game, might need timer.after(0.01, callback)
    return entity
end

---Assert no validation errors for entity
---@param entity number Entity ID
---@param rules? string[] Optional: specific rules to check
function UITestUtils.assertNoErrors(entity, rules)
    local violations = UIValidator.validate(entity, rules)
    local errors = UIValidator.getErrors(violations)

    if #errors > 0 then
        local messages = {}
        for _, e in ipairs(errors) do
            table.insert(messages, string.format("%s: %s", e.type, e.message))
        end
        error("UI validation errors:\n  " .. table.concat(messages, "\n  "))
    end
end

---Assert no validation violations (errors OR warnings)
---@param entity number Entity ID
---@param rules? string[] Optional: specific rules to check
function UITestUtils.assertNoViolations(entity, rules)
    local violations = UIValidator.validate(entity, rules)

    if #violations > 0 then
        local messages = {}
        for _, v in ipairs(violations) do
            table.insert(messages, string.format("[%s] %s: %s", v.severity, v.type, v.message))
        end
        error("UI validation violations:\n  " .. table.concat(messages, "\n  "))
    end
end

---Assert a specific violation exists
---@param entity number Entity ID
---@param violationType string Expected violation type
---@param entityMatch? number|string Optional: entity that should have violation
function UITestUtils.assertHasViolation(entity, violationType, entityMatch)
    local violations = UIValidator.validate(entity)

    for _, v in ipairs(violations) do
        if v.type == violationType then
            if not entityMatch or v.entity == entityMatch then
                return -- Found it
            end
        end
    end

    error(string.format("Expected violation '%s' not found", violationType))
end

---Get all computed bounds for an entity tree
---@param entity number Root entity ID
---@return table Map of entity -> bounds
function UITestUtils.getAllBounds(entity)
    return UIValidator.getAllBounds(entity)
end

---Clean up spawned UI
---@param entity number Entity to remove
function UITestUtils.cleanup(entity)
    if entity and registry:valid(entity) then
        dsl.remove(entity)
    end
end

return UITestUtils
