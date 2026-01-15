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

---Get computed bounds for an entity
---@param entity number Entity ID
---@return table|nil {x, y, w, h} or nil if no bounds
function UIValidator.getBounds(entity)
    if not entity or not registry:valid(entity) then
        return nil
    end

    -- Try Transform component first (for positioned entities)
    local transform = component_cache.get(entity, Transform)
    if transform then
        local x = transform.actualX or transform.x or 0
        local y = transform.actualY or transform.y or 0
        local w = transform.w or 32
        local h = transform.h or 32
        return { x = x, y = y, w = w, h = h }
    end

    -- Try UIElementComponent for UI-specific bounds
    local uiElement = component_cache.get(entity, UIElementComponent)
    if uiElement and uiElement.bounds then
        return {
            x = uiElement.bounds.x or 0,
            y = uiElement.bounds.y or 0,
            w = uiElement.bounds.w or 0,
            h = uiElement.bounds.h or 0,
        }
    end

    -- Try CollisionShape2D for collision bounds
    local collision = component_cache.get(entity, CollisionShape2D)
    if collision then
        local minX = collision.aabb_min_x or 0
        local minY = collision.aabb_min_y or 0
        local maxX = collision.aabb_max_x or 0
        local maxY = collision.aabb_max_y or 0
        return {
            x = minX,
            y = minY,
            w = maxX - minX,
            h = maxY - minY,
        }
    end

    return nil
end

---Get bounds for entity and all descendants
---@param entity number Root entity ID
---@return table Map of entity -> bounds
function UIValidator.getAllBounds(entity)
    local result = {}

    local function collectBounds(ent, depth)
        if not ent or not registry:valid(ent) then return end
        if depth > 50 then return end -- Prevent infinite recursion

        local bounds = UIValidator.getBounds(ent)
        if bounds then
            result[ent] = bounds
        end

        -- Get children from GameObject
        local go = component_cache.get(ent, GameObject)
        if go and go.orderedChildren then
            for _, child in ipairs(go.orderedChildren) do
                collectBounds(child, depth + 1)
            end
        end

        -- Also check UIBoxComponent children
        local uiBox = component_cache.get(ent, UIBoxComponent)
        if uiBox and uiBox.uiRoot and registry:valid(uiBox.uiRoot) then
            collectBounds(uiBox.uiRoot, depth + 1)
        end
    end

    collectBounds(entity, 0)
    return result
end

return UIValidator
