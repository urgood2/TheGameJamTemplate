--[[
    UIValidator - Rule-based UI validation system

    Validates UI elements for:
    - containment: children inside parent bounds
    - window_bounds: UI inside game window
    - sibling_overlap: same z-order siblings don't overlap
    - z_order_hierarchy: z-order respects hierarchy
    - collision_alignment: collision bounds inside visual bounds
    - layer_consistency: all elements same render layer
    - space_consistency: all elements same DrawCommandSpace
]]

local UIValidator = {}

-- State
local enabled = false
local severities = {
    containment = "error",
    window_bounds = "error",
    sibling_overlap = "warning",
    z_order_hierarchy = "warning",
    collision_alignment = "error",
    layer_consistency = "error",
    space_consistency = "error",
}

-- Render tracking (for manually-rendered entities)
local renderLog = {}

---Enable auto-validation
function UIValidator.enable()
    enabled = true
end

---Disable auto-validation
function UIValidator.disable()
    enabled = false
end

---Check if validation is enabled
---@return boolean
function UIValidator.isEnabled()
    return enabled
end

---Validate a UI entity and return violations
---@param entity number Entity ID
---@param rules? string[] Optional: specific rules to check (default: all)
---@return table[] violations List of {type, severity, entity, message}
function UIValidator.validate(entity, rules)
    -- Placeholder - will implement in subsequent tasks
    return {}
end

---Set severity for a rule
---@param rule string Rule name
---@param severity "error"|"warning" Severity level
function UIValidator.setSeverity(rule, severity)
    if severities[rule] then
        severities[rule] = severity
    end
end

---Get severity for a rule
---@param rule string Rule name
---@return "error"|"warning"
function UIValidator.getSeverity(rule)
    return severities[rule] or "warning"
end

---Clear render log (call at frame start)
function UIValidator.clearRenderLog()
    renderLog = {}
end

---Get render log for inspection
---@return table
function UIValidator.getRenderLog()
    return renderLog
end

return UIValidator
