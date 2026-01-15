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

-- Forward declaration for validate (implemented after all rule functions)
local validateImpl

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
            -- stash entity id for clearer parent reporting downstream
            bounds.entity = ent
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

---Check if child bounds are fully inside parent bounds
---@param px number Parent x
---@param py number Parent y
---@param pw number Parent width
---@param ph number Parent height
---@param cx number Child x
---@param cy number Child y
---@param cw number Child width
---@param ch number Child height
---@return boolean contained
local function isContained(px, py, pw, ph, cx, cy, cw, ch)
    return cx >= px and
           cy >= py and
           (cx + cw) <= (px + pw) and
           (cy + ch) <= (py + ph)
end

---Check containment between specific parent/child bounds
---@param parentId string|number Parent identifier
---@param parentBounds table {x, y, w, h}
---@param childId string|number Child identifier
---@param childBounds table {x, y, w, h, allowEscape?}
---@return table[] violations
function UIValidator.checkContainmentWithBounds(parentId, parentBounds, childId, childBounds)
    local violations = {}

    -- Skip if child has allowEscape flag
    if childBounds.allowEscape then
        return violations
    end

    if not isContained(
        parentBounds.x, parentBounds.y, parentBounds.w, parentBounds.h,
        childBounds.x, childBounds.y, childBounds.w, childBounds.h
    ) then
        table.insert(violations, {
            type = "containment",
            severity = severities.containment,
            entity = childId,
            parent = parentId,
            message = string.format(
                "Entity %s escapes parent %s bounds (child: %.0f,%.0f %.0fx%.0f, parent: %.0f,%.0f %.0fx%.0f)",
                tostring(childId), tostring(parentId),
                childBounds.x, childBounds.y, childBounds.w, childBounds.h,
                parentBounds.x, parentBounds.y, parentBounds.w, parentBounds.h
            ),
        })
    end

    return violations
end

---Check containment rule for a UI entity tree
---@param entity number Root entity ID
---@return table[] violations
function UIValidator.checkContainment(entity)
    local violations = {}

    local function checkEntity(ent, parentBounds, parentId)
        if not ent or not registry:valid(ent) then return end

        local bounds = UIValidator.getBounds(ent)
        if not bounds then return end

        -- Check if this entity is contained in parent
        if parentBounds then
            -- Get allowEscape from config if available
            local go = component_cache.get(ent, GameObject)
            local allowEscape = go and go.config and go.config.allowEscape
            bounds.allowEscape = allowEscape

            local v = UIValidator.checkContainmentWithBounds(
                parentId or "parent", parentBounds,
                ent, bounds
            )
            for _, violation in ipairs(v) do
                table.insert(violations, violation)
            end
        end

        -- Check children
        local go = component_cache.get(ent, GameObject)
        if go and go.orderedChildren then
            for _, child in ipairs(go.orderedChildren) do
                checkEntity(child, bounds, ent)
            end
        end
    end

    checkEntity(entity, nil, nil)
    return violations
end

---Get window bounds
---@return table {x, y, w, h}
function UIValidator.getWindowBounds()
    local w = (globals and globals.screenWidth and globals.screenWidth()) or 1280
    local h = (globals and globals.screenHeight and globals.screenHeight()) or 720
    return { x = 0, y = 0, w = w, h = h }
end

---Check if bounds are inside window
---@param entityId string|number Entity identifier
---@param bounds table {x, y, w, h}
---@param windowBounds? table {x, y, w, h} Optional custom window bounds
---@return table[] violations
function UIValidator.checkWindowBoundsWithBounds(entityId, bounds, windowBounds)
    local violations = {}
    windowBounds = windowBounds or UIValidator.getWindowBounds()

    if not isContained(
        windowBounds.x, windowBounds.y, windowBounds.w, windowBounds.h,
        bounds.x, bounds.y, bounds.w, bounds.h
    ) then
        table.insert(violations, {
            type = "window_bounds",
            severity = severities.window_bounds,
            entity = entityId,
            message = string.format(
                "Entity %s outside window bounds (entity: %.0f,%.0f %.0fx%.0f, window: %.0f,%.0f %.0fx%.0f)",
                tostring(entityId),
                bounds.x, bounds.y, bounds.w, bounds.h,
                windowBounds.x, windowBounds.y, windowBounds.w, windowBounds.h
            ),
        })
    end

    return violations
end

---Check window bounds rule for a UI entity tree
---@param entity number Root entity ID
---@return table[] violations
function UIValidator.checkWindowBounds(entity)
    local violations = {}
    local windowBounds = UIValidator.getWindowBounds()

    local allBounds = UIValidator.getAllBounds(entity)
    for ent, bounds in pairs(allBounds) do
        local v = UIValidator.checkWindowBoundsWithBounds(ent, bounds, windowBounds)
        for _, violation in ipairs(v) do
            table.insert(violations, violation)
        end
    end

    return violations
end

---Check if two rectangles overlap
---@return boolean
local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and
           ay < by + bh and ay + ah > by
end

---Check sibling overlap with provided bounds
---@param siblings table[] Array of {id, bounds: {x,y,w,h,allowOverlap?}}
---@return table[] violations
function UIValidator.checkSiblingOverlapWithBounds(siblings)
    local violations = {}

    for i = 1, #siblings - 1 do
        for j = i + 1, #siblings do
            local a = siblings[i]
            local b = siblings[j]

            -- Skip if either has allowOverlap
            if a.bounds.allowOverlap or b.bounds.allowOverlap then
                goto continue
            end

            if rectsOverlap(
                a.bounds.x, a.bounds.y, a.bounds.w, a.bounds.h,
                b.bounds.x, b.bounds.y, b.bounds.w, b.bounds.h
            ) then
                table.insert(violations, {
                    type = "sibling_overlap",
                    severity = severities.sibling_overlap,
                    entity = b.id,
                    sibling = a.id,
                    message = string.format(
                        "Entity %s overlaps sibling %s",
                        tostring(b.id), tostring(a.id)
                    ),
                })
            end

            ::continue::
        end
    end

    return violations
end

---Check sibling overlap for children of an entity
---@param entity number Parent entity ID
---@return table[] violations
function UIValidator.checkSiblingOverlap(entity)
    local violations = {}

    local function checkChildren(ent)
        if not ent or not registry:valid(ent) then return end

        local go = component_cache.get(ent, GameObject)
        if not go or not go.orderedChildren then return end

        -- Collect sibling bounds
        local siblings = {}
        for _, child in ipairs(go.orderedChildren) do
            local bounds = UIValidator.getBounds(child)
            if bounds then
                local childGo = component_cache.get(child, GameObject)
                local allowOverlap = childGo and childGo.config and childGo.config.allowOverlap
                bounds.allowOverlap = allowOverlap
                table.insert(siblings, { id = child, bounds = bounds })
            end
        end

        -- Check for overlaps
        local v = UIValidator.checkSiblingOverlapWithBounds(siblings)
        for _, violation in ipairs(v) do
            table.insert(violations, violation)
        end

        -- Recurse into children
        for _, child in ipairs(go.orderedChildren) do
            checkChildren(child)
        end
    end

    checkChildren(entity)
    return violations
end

---Get z-order for an entity
---@param entity number Entity ID
---@return number|nil z-order or nil
function UIValidator.getZOrder(entity)
    if not entity or not registry:valid(entity) then
        return nil
    end

    if layer_order_system and layer_order_system.getZIndex then
        return layer_order_system.getZIndex(entity)
    end

    -- Fallback to LayerOrderComponent
    local layerOrder = component_cache.get(entity, LayerOrderComponent)
    if layerOrder then
        return layerOrder.z or layerOrder.zIndex or 0
    end

    return 0
end

---Check z-order with provided hierarchy
---@param hierarchy table[] Array of {id, z, children: string[]}
---@return table[] violations
function UIValidator.checkZOrderWithHierarchy(hierarchy)
    local violations = {}

    -- Build lookup
    local byId = {}
    for _, node in ipairs(hierarchy) do
        byId[node.id] = node
    end

    -- Check each node
    for _, node in ipairs(hierarchy) do
        for _, childId in ipairs(node.children) do
            local child = byId[childId]
            if child and child.z <= node.z then
                table.insert(violations, {
                    type = "z_order_hierarchy",
                    severity = severities.z_order_hierarchy,
                    entity = childId,
                    parent = node.id,
                    message = string.format(
                        "Entity %s (z=%d) behind parent %s (z=%d)",
                        tostring(childId), child.z,
                        tostring(node.id), node.z
                    ),
                })
            end
        end
    end

    return violations
end

---Check z-order hierarchy for a UI entity tree
---@param entity number Root entity ID
---@return table[] violations
function UIValidator.checkZOrder(entity)
    local violations = {}

    local function checkEntity(ent, parentZ)
        if not ent or not registry:valid(ent) then return end

        local z = UIValidator.getZOrder(ent) or 0

        -- Check against parent
        if parentZ and z <= parentZ then
            table.insert(violations, {
                type = "z_order_hierarchy",
                severity = severities.z_order_hierarchy,
                entity = ent,
                message = string.format(
                    "Entity %s (z=%d) not above parent (z=%d)",
                    tostring(ent), z, parentZ
                ),
            })
        end

        -- Check children
        local go = component_cache.get(ent, GameObject)
        if go and go.orderedChildren then
            for _, child in ipairs(go.orderedChildren) do
                checkEntity(child, z)
            end
        end
    end

    checkEntity(entity, nil)
    return violations
end

-- Rule check functions lookup (must be after function definitions)
local ruleChecks = {
    containment = function(entity) return UIValidator.checkContainment(entity) end,
    window_bounds = function(entity) return UIValidator.checkWindowBounds(entity) end,
    sibling_overlap = function(entity) return UIValidator.checkSiblingOverlap(entity) end,
    z_order_hierarchy = function(entity) return UIValidator.checkZOrder(entity) end,
    layer_consistency = function(entity) return UIValidator.checkRenderConsistency(entity) end,
    space_consistency = function(_) return {} end, -- space is evaluated within checkRenderConsistency
}

---Validate a UI entity and return all violations
---@param entity number Entity ID
---@param rules? string[] Optional: specific rules to check (default: all)
---@return table[] violations List of {type, severity, entity, message}
function UIValidator.validate(entity, rules)
    local violations = {}

    if not entity then
        return violations
    end

    -- Determine which rules to run
    local rulesToRun = rules or {
        "containment",
        "window_bounds",
        "sibling_overlap",
        "z_order_hierarchy",
        "layer_consistency",
    }

    -- Rules that don't require valid registry entities (work from render log)
    local renderLogRules = {
        layer_consistency = true,
        space_consistency = true,
    }

    local isValidEntity = registry and registry:valid(entity)

    for _, ruleName in ipairs(rulesToRun) do
        local checkFn = ruleChecks[ruleName]
        if checkFn then
            -- Skip entity-based rules for invalid entities, but allow render log rules
            if renderLogRules[ruleName] or isValidEntity then
                local v = checkFn(entity)
                for _, violation in ipairs(v) do
                    table.insert(violations, violation)
                end
            end
        end
    end

    return violations
end

---Filter violations to errors only
---@param violations table[]
---@return table[]
function UIValidator.getErrors(violations)
    local errors = {}
    for _, v in ipairs(violations) do
        if v.severity == "error" then
            table.insert(errors, v)
        end
    end
    return errors
end

---Filter violations to warnings only
---@param violations table[]
---@return table[]
function UIValidator.getWarnings(violations)
    local warnings = {}
    for _, v in ipairs(violations) do
        if v.severity == "warning" then
            table.insert(warnings, v)
        end
    end
    return warnings
end

---Validate and print results (convenience function)
---@param entity number Entity ID
---@return boolean hasErrors
function UIValidator.validateAndReport(entity)
    local violations = UIValidator.validate(entity)
    local errors = UIValidator.getErrors(violations)
    local warnings = UIValidator.getWarnings(violations)

    if #errors > 0 then
        print(string.format("[UIValidator] %d ERRORS:", #errors))
        for _, e in ipairs(errors) do
            print(string.format("  X %s: %s", e.type, e.message))
        end
    end

    if #warnings > 0 then
        print(string.format("[UIValidator] %d warnings:", #warnings))
        for _, w in ipairs(warnings) do
            print(string.format("  ! %s: %s", w.type, w.message))
        end
    end

    return #errors > 0
end

-- Normalize layer identifier to a stable string so parent/child comparisons match
local function normalizeLayerId(layer)
    if not layer then return "nil" end
    if type(layer) == "table" then
        if layer.name then return tostring(layer.name) end
        if layer.id then return tostring(layer.id) end
    end
    return tostring(layer)
end

-- Normalize draw space to "Screen"/"World" (or fallback tostring)
local function normalizeSpace(space, layer)
    if space == nil then return "nil" end

    local dc = layer and layer.DrawCommandSpace
    if dc then
        if space == dc.Screen then return "Screen" end
        if space == dc.World then return "World" end
    end

    if DrawCommandSpace then
        if space == DrawCommandSpace.Screen then return "Screen" end
        if space == DrawCommandSpace.World then return "World" end
    end

    if type(space) == "string" then return space end
    return tostring(space)
end

---Track render info for entities (call this instead of direct command_buffer calls)
---@param parentUI number|nil Parent UI entity (nil for roots)
---@param layer any Layer userdata or name
---@param entities table[] Entities being rendered
---@param z number Z-order
---@param space any DrawCommandSpace value
function UIValidator.trackRender(parentUI, layer, entities, z, space)
    local frameNum = globals and globals.frameCount or 0
    local layerName = normalizeLayerId(layer)
    local spaceName = normalizeSpace(space, layer)

    for _, entity in ipairs(entities) do
        renderLog[entity] = {
            parent = parentUI,
            layer = layerName,
            z = z,
            space = spaceName,
            frame = frameNum,
        }
    end
end

---Queue draw and track for validation (wraps command_buffer.queueDrawBatchedEntities)
---@param parentUI number Parent UI entity for association
---@param layer userdata Layer to render to
---@param entities table[] Entities to render
---@param z number Z-order
---@param space userdata DrawCommandSpace
function UIValidator.queueDrawEntities(parentUI, layer, entities, z, space)
    -- Track for validation
    UIValidator.trackRender(parentUI, layer, entities, z, space)

    -- Perform actual render (only if command_buffer exists)
    if command_buffer and command_buffer.queueDrawBatchedEntities then
        command_buffer.queueDrawBatchedEntities(layer, function(cmd)
            cmd.entities = entities
        end, z, space)
    end
end

---Check render consistency for a UI entity and its associated renders
---@param parentUI number Parent UI entity
---@return table[] violations
function UIValidator.checkRenderConsistency(parentUI)
    local violations = {}

    -- Get parent's render info
    local parentInfo = renderLog[parentUI]
    if not parentInfo then
        return violations -- No parent info, can't check
    end

    -- Check all entities associated with this parent
    for entity, info in pairs(renderLog) do
        if info.parent == parentUI then
            -- Check layer consistency
            if info.layer ~= parentInfo.layer then
                table.insert(violations, {
                    type = "layer_consistency",
                    severity = severities.layer_consistency,
                    entity = entity,
                    parent = parentUI,
                    message = string.format(
                        "Entity %s renders to %s, parent %s uses %s",
                        tostring(entity), info.layer,
                        tostring(parentUI), parentInfo.layer
                    ),
                })
            end

            -- Check space consistency
            if info.space ~= parentInfo.space then
                table.insert(violations, {
                    type = "space_consistency",
                    severity = severities.space_consistency,
                    entity = entity,
                    parent = parentUI,
                    message = string.format(
                        "Entity %s uses %s space, parent %s uses %s",
                        tostring(entity), info.space,
                        tostring(parentUI), parentInfo.space
                    ),
                })
            end
        end
    end

    return violations
end

return UIValidator
