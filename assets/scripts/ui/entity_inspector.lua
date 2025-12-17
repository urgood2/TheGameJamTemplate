--[[
================================================================================
ENTITY INSPECTOR - Debug UI for inspecting entity components
================================================================================
ImGui-based panel for inspecting entities and their components at runtime.

Usage:
    local inspector = require("ui.entity_inspector")

    -- In your ImGui render loop:
    inspector.render()

    -- Set the entity to inspect:
    inspector.set_target(entity_id)

    -- Or inspect entity under mouse:
    inspector.inspect_hovered()
]]

local EntityInspector = {}

-- Dependencies
local component_cache = require("core.component_cache")
local entity_cache = require("core.entity_cache")

--===========================================================================
-- STATE
--===========================================================================

EntityInspector.target_entity = nil
EntityInspector.is_open = false
EntityInspector.auto_refresh = true
EntityInspector.show_nil_fields = false

-- Known component types to check (add more as needed)
EntityInspector.component_types = {
    "Transform",
    "GameObject",
    "ScriptComponent",
    "StateTag",
    "Shadow",
    "AnimationQueueComponent",
    "LayerConfig",
    "PhysicsSyncConfig",
}

--===========================================================================
-- CORE FUNCTIONS
--===========================================================================

--- Set the entity to inspect
--- @param eid number|nil Entity ID or nil to clear
function EntityInspector.set_target(eid)
    EntityInspector.target_entity = eid
end

--- Toggle the inspector window
function EntityInspector.toggle()
    EntityInspector.is_open = not EntityInspector.is_open
end

--- Open the inspector
function EntityInspector.open()
    EntityInspector.is_open = true
end

--- Close the inspector
function EntityInspector.close()
    EntityInspector.is_open = false
end

--===========================================================================
-- COMPONENT RENDERING
--===========================================================================

local function render_transform(transform)
    if not transform then return end

    imgui.Text("Position:")
    imgui.SameLine()
    imgui.Text(string.format("(%.1f, %.1f)", transform.actualX or 0, transform.actualY or 0))

    imgui.Text("Visual:")
    imgui.SameLine()
    imgui.Text(string.format("(%.1f, %.1f)", transform.visualX or 0, transform.visualY or 0))

    imgui.Text("Size:")
    imgui.SameLine()
    imgui.Text(string.format("%.0f x %.0f", transform.actualW or 0, transform.actualH or 0))

    imgui.Text("Rotation:")
    imgui.SameLine()
    imgui.Text(string.format("%.2f", transform.actualR or 0))
end

local function render_gameobject(go)
    if not go then return end

    if go.state then
        imgui.Text("State Flags:")
        imgui.Indent()
        local flags = {
            "hoverEnabled", "clickEnabled", "dragEnabled",
            "collisionEnabled", "isBeingDragged", "isHovered"
        }
        for _, flag in ipairs(flags) do
            local value = go.state[flag]
            if value ~= nil then
                imgui.Text(string.format("%s: %s", flag, tostring(value)))
            end
        end
        imgui.Unindent()
    end

    if go.methods then
        imgui.Text("Methods:")
        imgui.Indent()
        local methods = { "onClick", "onHover", "onDrag", "onStopDrag" }
        for _, method in ipairs(methods) do
            local has = go.methods[method] ~= nil
            imgui.Text(string.format("%s: %s", method, has and "defined" or "nil"))
        end
        imgui.Unindent()
    end
end

local function render_script_component(script)
    if not script then return end

    if script.self then
        imgui.Text("Script Table Fields:")
        imgui.Indent()
        local count = 0
        for k, v in pairs(script.self) do
            if type(v) ~= "function" then
                local display = tostring(v)
                if #display > 50 then display = display:sub(1, 47) .. "..." end
                imgui.Text(string.format("%s: %s", tostring(k), display))
                count = count + 1
                if count > 20 then
                    imgui.Text("... (more fields hidden)")
                    break
                end
            end
        end
        if count == 0 then
            imgui.TextColored(0.5, 0.5, 0.5, 1, "(no data fields)")
        end
        imgui.Unindent()
    end
end

local function render_generic_table(name, tbl, depth)
    depth = depth or 0
    if depth > 3 then
        imgui.Text("(max depth reached)")
        return
    end

    for k, v in pairs(tbl) do
        if type(v) == "table" then
            if imgui.TreeNode(tostring(k)) then
                render_generic_table(tostring(k), v, depth + 1)
                imgui.TreePop()
            end
        elseif type(v) ~= "function" then
            imgui.Text(string.format("%s: %s", tostring(k), tostring(v)))
        end
    end
end

--===========================================================================
-- MAIN RENDER
--===========================================================================

--- Render the entity inspector window
--- Call this in your ImGui render loop
function EntityInspector.render()
    if not EntityInspector.is_open then return end
    if not imgui then return end  -- ImGui not available

    local open = imgui.Begin("Entity Inspector", true, 0)
    if not open then
        EntityInspector.is_open = false
        imgui.End()
        return
    end

    -- Entity selection
    imgui.Text("Target Entity:")
    imgui.SameLine()

    local eid = EntityInspector.target_entity
    if eid and entity_cache.valid(eid) then
        imgui.TextColored(0, 1, 0, 1, tostring(eid))
    elseif eid then
        imgui.TextColored(1, 0, 0, 1, tostring(eid) .. " (INVALID)")
    else
        imgui.TextColored(0.5, 0.5, 0.5, 1, "None")
    end

    -- Controls
    if imgui.Button("Clear") then
        EntityInspector.set_target(nil)
    end
    imgui.SameLine()
    local _, auto = imgui.Checkbox("Auto-refresh", EntityInspector.auto_refresh)
    EntityInspector.auto_refresh = auto

    imgui.Separator()

    -- Component display
    if eid and entity_cache.valid(eid) then
        imgui.Text("Components:")
        imgui.Separator()

        -- Transform
        if imgui.CollapsingHeader("Transform", true) then
            local transform = component_cache.get(eid, Transform)
            if transform then
                render_transform(transform)
            else
                imgui.TextColored(0.5, 0.5, 0.5, 1, "(not present)")
            end
        end

        -- GameObject
        if imgui.CollapsingHeader("GameObject", false) then
            local go = nil
            pcall(function() go = component_cache.get(eid, GameObject) end)
            if go then
                render_gameobject(go)
            else
                imgui.TextColored(0.5, 0.5, 0.5, 1, "(not present)")
            end
        end

        -- ScriptComponent
        if imgui.CollapsingHeader("ScriptComponent", false) then
            local script = nil
            pcall(function() script = component_cache.get(eid, ScriptComponent) end)
            if script then
                render_script_component(script)
            else
                imgui.TextColored(0.5, 0.5, 0.5, 1, "(not present)")
            end
        end

        -- StateTag
        if imgui.CollapsingHeader("StateTag", false) then
            local stateTag = nil
            pcall(function() stateTag = component_cache.get(eid, StateTag) end)
            if stateTag then
                imgui.Text("Active Tags:")
                imgui.Indent()
                -- StateTag typically has a tags table or similar
                if type(stateTag) == "table" then
                    render_generic_table("StateTag", stateTag)
                else
                    imgui.Text(tostring(stateTag))
                end
                imgui.Unindent()
            else
                imgui.TextColored(0.5, 0.5, 0.5, 1, "(not present)")
            end
        end

        -- Other components (generic display)
        if imgui.CollapsingHeader("Other Components", false) then
            imgui.TextColored(0.7, 0.7, 0.7, 1, "Check registry manually for additional components")
        end
    else
        imgui.TextColored(0.7, 0.7, 0.7, 1, "Select an entity to inspect")
        imgui.Text("")
        imgui.Text("Tips:")
        imgui.BulletText("Call EntityInspector.set_target(eid)")
        imgui.BulletText("Use hover system to pick entities")
    end

    imgui.End()
end

--===========================================================================
-- HELPER FUNCTIONS
--===========================================================================

--- Get a summary string for an entity
--- @param eid number Entity ID
--- @return string Summary text
function EntityInspector.get_summary(eid)
    if not eid or not entity_cache.valid(eid) then
        return "Invalid entity"
    end

    local parts = { "Entity " .. tostring(eid) }

    -- Check for transform
    local transform = component_cache.get(eid, Transform)
    if transform then
        table.insert(parts, string.format("@ (%.0f, %.0f)", transform.actualX or 0, transform.actualY or 0))
    end

    -- Check for script
    local script = getScriptTableFromEntityID and getScriptTableFromEntityID(eid)
    if script then
        if script.type then
            table.insert(parts, "[" .. script.type .. "]")
        else
            table.insert(parts, "[scripted]")
        end
    end

    return table.concat(parts, " ")
end

--- List all entities in the registry (for debugging)
--- NOTE: Registry iteration may not be available depending on EnTT bindings.
--- This function provides multiple fallback strategies.
--- @param limit number? Max entities to return (default 100)
--- @return number[] List of entity IDs
function EntityInspector.list_entities(limit)
    limit = limit or 100
    local entities = {}

    -- Strategy 1: Try registry:each() if available (standard EnTT pattern)
    if registry and type(registry.each) == "function" then
        local ok = pcall(function()
            registry:each(function(eid)
                if #entities < limit then
                    table.insert(entities, eid)
                end
            end)
        end)
        if ok and #entities > 0 then
            return entities
        end
    end

    -- Strategy 2: Try registry:view() with Transform (most entities have Transform)
    if registry and type(registry.view) == "function" then
        local ok = pcall(function()
            local view = registry:view(Transform)
            if view and type(view.each) == "function" then
                view:each(function(eid)
                    if #entities < limit then
                        table.insert(entities, eid)
                    end
                end)
            end
        end)
        if ok and #entities > 0 then
            return entities
        end
    end

    -- Strategy 3: Fallback - manual range check (less reliable)
    -- EnTT entity IDs are typically sequential, try checking a range
    if registry and type(registry.valid) == "function" then
        for i = 0, limit * 10 do  -- Check 10x limit to find enough valid entities
            if registry:valid(i) then
                table.insert(entities, i)
                if #entities >= limit then
                    break
                end
            end
        end
        if #entities > 0 then
            return entities
        end
    end

    -- No strategy worked
    local log_fn = log_warn or print
    log_fn("[EntityInspector] Registry iteration not available - no entities listed")
    return entities
end

return EntityInspector
