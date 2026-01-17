--[[
    UISnapshot - UI layout measurement and comparison system

    Captures exact bounds of all UI elements for baseline comparison
    and regression detection during refactoring.

    Part of the box.cpp refactoring verification infrastructure.
]]

local UISnapshot = {}

local json = require("external.json")

---Helper to check bounds equality within tolerance
---@param a table {x, y, w, h}
---@param b table {x, y, w, h}
---@param tolerance number
---@return boolean
function UISnapshot.boundsEqual(a, b, tolerance)
    tolerance = tolerance or 0.5
    return math.abs(a.x - b.x) <= tolerance and
           math.abs(a.y - b.y) <= tolerance and
           math.abs(a.w - b.w) <= tolerance and
           math.abs(a.h - b.h) <= tolerance
end

---Capture complete bounds of a UI tree
---@param uiBoxEntity number Entity ID of the UIBox or root element
---@return table snapshot {timestamp, entities = {[entity] = {x, y, w, h, vx, vy, id}}}
function UISnapshot.capture(uiBoxEntity)
    if not uiBoxEntity or not registry:valid(uiBoxEntity) then
        return {
            timestamp = os.time(),
            entities = {},
            error = "Invalid entity",
        }
    end

    local snapshot = {
        timestamp = os.time(),
        entities = {},
        entityCount = 0,
    }

    -- Get the UI root (might be uiBoxEntity itself or via UIBoxComponent)
    local uiRoot = uiBoxEntity
    local uiBox = component_cache.get(uiBoxEntity, UIBoxComponent)
    if uiBox and uiBox.uiRoot and registry:valid(uiBox.uiRoot) then
        uiRoot = uiBox.uiRoot
    end

    -- Traverse the UI tree and capture all bounds
    ui.box.TraverseUITreeBottomUp(registry, uiRoot, function(entity)
        if not registry:valid(entity) then return end

        local transform = component_cache.get(entity, Transform)
        local uiConfig = component_cache.get(entity, UIConfig)

        if transform then
            local entityKey = tostring(entity)
            local id = nil
            local uiType = nil

            if uiConfig then
                id = uiConfig.id
                uiType = uiConfig.uiType
            end

            snapshot.entities[entityKey] = {
                id = id,
                uiType = uiType,
                x = transform.actualX or 0,
                y = transform.actualY or 0,
                w = transform.actualW or 0,
                h = transform.actualH or 0,
                -- Store visual position too (for spring-animated elements)
                vx = transform.visualX or transform.actualX or 0,
                vy = transform.visualY or transform.actualY or 0,
            }
            snapshot.entityCount = snapshot.entityCount + 1
        end
    end, false)

    return snapshot
end

---Compare two snapshots, return differences
---@param before table Previous snapshot
---@param after table Current snapshot
---@param tolerance number Float precision tolerance (default 0.5)
---@return table {changed = {}, added = {}, removed = {}}
function UISnapshot.diff(before, after, tolerance)
    tolerance = tolerance or 0.5
    local changes = {
        changed = {},
        added = {},
        removed = {},
        summary = "",
    }

    -- Check for changed or removed entities
    for entityKey, bounds in pairs(before.entities) do
        local afterBounds = after.entities[entityKey]
        if not afterBounds then
            table.insert(changes.removed, {
                entity = entityKey,
                id = bounds.id,
                bounds = bounds,
            })
        elseif not UISnapshot.boundsEqual(bounds, afterBounds, tolerance) then
            table.insert(changes.changed, {
                entity = entityKey,
                id = bounds.id or afterBounds.id,
                before = bounds,
                after = afterBounds,
                delta = {
                    dx = afterBounds.x - bounds.x,
                    dy = afterBounds.y - bounds.y,
                    dw = afterBounds.w - bounds.w,
                    dh = afterBounds.h - bounds.h,
                },
            })
        end
    end

    -- Check for added entities
    for entityKey, bounds in pairs(after.entities) do
        if not before.entities[entityKey] then
            table.insert(changes.added, {
                entity = entityKey,
                id = bounds.id,
                bounds = bounds,
            })
        end
    end

    -- Generate summary
    local parts = {}
    if #changes.changed > 0 then
        table.insert(parts, #changes.changed .. " changed")
    end
    if #changes.added > 0 then
        table.insert(parts, #changes.added .. " added")
    end
    if #changes.removed > 0 then
        table.insert(parts, #changes.removed .. " removed")
    end
    changes.summary = #parts > 0 and table.concat(parts, ", ") or "no changes"

    return changes
end

---Save snapshot to file for later comparison
---@param snapshot table Snapshot to save
---@param filename string Path to save to
---@return boolean success
function UISnapshot.save(snapshot, filename)
    local ok, err = pcall(function()
        -- Convert entities table keys from numbers/strings to consistent format
        local saveData = {
            timestamp = snapshot.timestamp,
            entityCount = snapshot.entityCount,
            entities = {},
        }

        for k, v in pairs(snapshot.entities) do
            saveData.entities[tostring(k)] = v
        end

        local content = json.encode(saveData)
        local file = io.open(filename, "w")
        if not file then
            error("Could not open file for writing: " .. filename)
        end
        file:write(content)
        file:close()
    end)

    if not ok then
        print("[UISnapshot] Save failed: " .. tostring(err))
        return false
    end
    return true
end

---Load snapshot from file
---@param filename string Path to load from
---@return table|nil snapshot or nil if failed
function UISnapshot.load(filename)
    local file = io.open(filename, "r")
    if not file then
        print("[UISnapshot] Could not open file: " .. filename)
        return nil
    end

    local content = file:read("*all")
    file:close()

    local ok, result = pcall(function()
        return json.decode(content)
    end)

    if not ok then
        print("[UISnapshot] Parse failed: " .. tostring(result))
        return nil
    end

    return result
end

---Print a human-readable diff report
---@param diff table Result from UISnapshot.diff()
function UISnapshot.printDiff(diff)
    if #diff.changed == 0 and #diff.added == 0 and #diff.removed == 0 then
        print("[UISnapshot] No differences found")
        return
    end

    print(string.format("[UISnapshot] Differences: %s", diff.summary))

    if #diff.changed > 0 then
        print("\n  CHANGED:")
        for _, change in ipairs(diff.changed) do
            local name = change.id or change.entity
            print(string.format("    %s: pos (%+.1f, %+.1f) size (%+.1f, %+.1f)",
                name,
                change.delta.dx, change.delta.dy,
                change.delta.dw, change.delta.dh
            ))
        end
    end

    if #diff.removed > 0 then
        print("\n  REMOVED:")
        for _, removed in ipairs(diff.removed) do
            print(string.format("    %s at (%.0f, %.0f) %.0fx%.0f",
                removed.id or removed.entity,
                removed.bounds.x, removed.bounds.y,
                removed.bounds.w, removed.bounds.h
            ))
        end
    end

    if #diff.added > 0 then
        print("\n  ADDED:")
        for _, added in ipairs(diff.added) do
            print(string.format("    %s at (%.0f, %.0f) %.0fx%.0f",
                added.id or added.entity,
                added.bounds.x, added.bounds.y,
                added.bounds.w, added.bounds.h
            ))
        end
    end
end

---Check if diff has any regressions (changes or removals)
---@param diff table Result from UISnapshot.diff()
---@return boolean hasRegressions
function UISnapshot.hasRegressions(diff)
    return #diff.changed > 0 or #diff.removed > 0
end

---Quick verification: capture, compare to baseline, report
---@param uiBoxEntity number Entity to verify
---@param baselineFile string Path to baseline snapshot
---@param tolerance? number Optional tolerance (default 0.5)
---@return boolean passed, table diff
function UISnapshot.verify(uiBoxEntity, baselineFile, tolerance)
    local baseline = UISnapshot.load(baselineFile)
    if not baseline then
        print("[UISnapshot] Could not load baseline: " .. baselineFile)
        return false, { error = "no baseline" }
    end

    local current = UISnapshot.capture(uiBoxEntity)
    local diff = UISnapshot.diff(baseline, current, tolerance)

    if UISnapshot.hasRegressions(diff) then
        print("[UISnapshot] REGRESSION DETECTED")
        UISnapshot.printDiff(diff)
        return false, diff
    end

    print("[UISnapshot] OK - no regressions")
    return true, diff
end

return UISnapshot
