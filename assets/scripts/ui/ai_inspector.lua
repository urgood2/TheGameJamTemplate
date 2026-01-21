--[[
================================================================================
AI INSPECTOR - Debug UI for inspecting GOAP AI entities
================================================================================
ImGui-based panel for inspecting AI entities, their GOAP state, plans, and trace
buffer contents at runtime.

Phase 1.3 of GOAP AI System Improvement Plan.

Usage:
    local inspector = require("ui.ai_inspector")

    -- In your ImGui render loop:
    inspector.render()

    -- Set the entity to inspect:
    inspector.set_target(entity_id)
]]

local AIInspector = {}

-- Dependencies
local entity_cache = require("core.entity_cache")

--===========================================================================
-- STATE
--===========================================================================

AIInspector.target_entity = nil
AIInspector.is_open = false
AIInspector.auto_refresh = true
AIInspector.current_tab = 1  -- 1=State, 2=Plan, 3=Atoms, 4=Trace

-- Trace buffer state
AIInspector.trace_filter = ""
AIInspector.trace_count = 50  -- Number of trace events to display
AIInspector.show_timestamps = true

-- Cached GOAP state (refreshed each frame if auto_refresh is on)
AIInspector.cached_state = nil

--===========================================================================
-- CORE FUNCTIONS
--===========================================================================

--- Set the entity to inspect
--- @param eid number|nil Entity ID or nil to clear
function AIInspector.set_target(eid)
    AIInspector.target_entity = eid
    AIInspector.cached_state = nil  -- Clear cache when target changes
end

--- Toggle the inspector window
function AIInspector.toggle()
    AIInspector.is_open = not AIInspector.is_open
end

--- Open the inspector
function AIInspector.open()
    AIInspector.is_open = true
end

--- Close the inspector
function AIInspector.close()
    AIInspector.is_open = false
end

--===========================================================================
-- ENTITY SELECTION
--===========================================================================

local function render_entity_selector()
    imgui.Text("GOAP Entities:")
    imgui.SameLine()

    -- Get list of GOAP entities
    local entities = {}
    if ai and ai.list_goap_entities then
        entities = ai.list_goap_entities() or {}
    end

    if #entities == 0 then
        imgui.TextColored(0.5, 0.5, 0.5, 1, "(none found)")
        return
    end

    -- Create combo items
    local current_idx = 0
    local items = {"(none)"}
    for i, eid in ipairs(entities) do
        table.insert(items, tostring(eid))
        if eid == AIInspector.target_entity then
            current_idx = i  -- 0-based, so first entity is at index 1
        end
    end

    -- Render combo
    local changed, new_idx = imgui.Combo("##entity_selector", current_idx, items, #items)
    if changed then
        if new_idx == 0 then
            AIInspector.set_target(nil)
        else
            AIInspector.set_target(entities[new_idx])
        end
    end

    imgui.SameLine()
    imgui.Text(string.format("(%d entities)", #entities))
end

--===========================================================================
-- TAB 1: GOAP STATE
--===========================================================================

local function render_state_tab()
    local state = AIInspector.cached_state
    if not state then
        imgui.TextColored(0.5, 0.5, 0.5, 1, "No GOAP state available")
        return
    end

    -- Basic info
    if imgui.CollapsingHeader("Basic Info", true) then
        imgui.Indent()
        imgui.Text(string.format("Type: %s", state.type or "unknown"))
        imgui.Text(string.format("Dirty: %s", tostring(state.dirty)))
        imgui.Text(string.format("Current Goal: %s", state.current_goal or "(none)"))
        imgui.Text(string.format("Retries: %d / %d", state.retries or 0, state.max_retries or 3))
        imgui.Unindent()
    end

    -- Versioning
    if imgui.CollapsingHeader("Versioning", false) then
        imgui.Indent()
        imgui.Text(string.format("Actionset Version: %d", state.actionset_version or 0))
        imgui.Text(string.format("Atom Schema Version: %d", state.atom_schema_version or 0))
        imgui.Unindent()
    end
end

--===========================================================================
-- TAB 2: PLAN
--===========================================================================

local function render_plan_tab()
    local state = AIInspector.cached_state
    if not state then
        imgui.TextColored(0.5, 0.5, 0.5, 1, "No GOAP state available")
        return
    end

    -- Current action
    if imgui.CollapsingHeader("Current Execution", true) then
        imgui.Indent()
        if state.current_action then
            imgui.TextColored(0, 1, 0, 1, string.format("Action: %s", state.current_action))
            imgui.Text(string.format("Running: %s", tostring(state.action_running)))
        else
            imgui.TextColored(0.5, 0.5, 0.5, 1, "No action running")
        end
        imgui.Text(string.format("Queue Size: %d", state.queue_size or 0))
        imgui.Unindent()
    end

    -- Plan
    if imgui.CollapsingHeader("Plan", true) then
        imgui.Indent()
        local plan = state.plan or {}
        local plan_size = state.plan_size or 0
        local current_idx = state.current_action_idx or 0

        if plan_size == 0 then
            imgui.TextColored(0.5, 0.5, 0.5, 1, "(empty plan)")
        else
            imgui.Text(string.format("Plan Size: %d, Current Index: %d", plan_size, current_idx))
            imgui.Separator()
            for i, action_name in ipairs(plan) do
                local is_current = (i - 1) == current_idx
                if is_current then
                    imgui.TextColored(1, 1, 0, 1, string.format("> [%d] %s", i, action_name))
                elseif i - 1 < current_idx then
                    imgui.TextColored(0.5, 0.5, 0.5, 1, string.format("  [%d] %s (done)", i, action_name))
                else
                    imgui.Text(string.format("  [%d] %s", i, action_name))
                end
            end
        end
        imgui.Unindent()
    end
end

--===========================================================================
-- TAB 3: WORLD STATE ATOMS
--===========================================================================

local function render_atoms_tab()
    local state = AIInspector.cached_state
    if not state then
        imgui.TextColored(0.5, 0.5, 0.5, 1, "No GOAP state available")
        return
    end

    local atoms = state.atoms or {}
    local num_atoms = state.num_atoms or 0

    imgui.Text(string.format("Registered Atoms: %d", num_atoms))
    imgui.Separator()

    -- Column headers
    imgui.Columns(4, "atoms_columns", true)
    imgui.Text("Atom")
    imgui.NextColumn()
    imgui.Text("Current")
    imgui.NextColumn()
    imgui.Text("Goal")
    imgui.NextColumn()
    imgui.Text("Match")
    imgui.NextColumn()
    imgui.Separator()

    for i, atom in ipairs(atoms) do
        -- Name
        imgui.Text(atom.name or "?")
        imgui.NextColumn()

        -- Current value
        local current = atom.current
        if current == "dontcare" then
            imgui.TextColored(0.5, 0.5, 0.5, 1, "-")
        elseif current == true then
            imgui.TextColored(0, 1, 0, 1, "true")
        else
            imgui.TextColored(1, 0.3, 0.3, 1, "false")
        end
        imgui.NextColumn()

        -- Goal value
        local goal = atom.goal
        if goal == "dontcare" then
            imgui.TextColored(0.5, 0.5, 0.5, 1, "-")
        elseif goal == true then
            imgui.TextColored(0, 1, 0, 1, "true")
        else
            imgui.TextColored(1, 0.3, 0.3, 1, "false")
        end
        imgui.NextColumn()

        -- Match indicator
        if goal == "dontcare" then
            imgui.TextColored(0.5, 0.5, 0.5, 1, "n/a")
        elseif current == goal then
            imgui.TextColored(0, 1, 0, 1, "OK")
        else
            imgui.TextColored(1, 0, 0, 1, "MISMATCH")
        end
        imgui.NextColumn()
    end

    imgui.Columns(1)
end

--===========================================================================
-- TAB 4: TRACE BUFFER
--===========================================================================

local EVENT_TYPE_COLORS = {
    GOAL_SELECTED = {0.2, 0.8, 1.0, 1.0},      -- Cyan
    PLAN_BUILT = {0.2, 1.0, 0.2, 1.0},         -- Green
    ACTION_START = {1.0, 1.0, 0.2, 1.0},       -- Yellow
    ACTION_FINISH = {0.5, 1.0, 0.5, 1.0},      -- Light green
    ACTION_ABORT = {1.0, 0.3, 0.3, 1.0},       -- Red
    WORLDSTATE_CHANGED = {1.0, 0.6, 0.2, 1.0}, -- Orange
    REPLAN_TRIGGERED = {1.0, 0.2, 1.0, 1.0},   -- Magenta
}

local function render_trace_tab()
    local eid = AIInspector.target_entity
    if not eid then
        imgui.TextColored(0.5, 0.5, 0.5, 1, "No entity selected")
        return
    end

    -- Controls
    local _, count = imgui.SliderInt("Events to show", AIInspector.trace_count, 10, 100)
    AIInspector.trace_count = count

    imgui.SameLine()
    if imgui.Button("Clear Trace") then
        if ai and ai.clear_trace then
            ai.clear_trace(eid)
        end
    end

    local _, show_ts = imgui.Checkbox("Show timestamps", AIInspector.show_timestamps)
    AIInspector.show_timestamps = show_ts

    imgui.Separator()

    -- Get trace events
    local events = {}
    if ai and ai.get_trace_events then
        events = ai.get_trace_events(eid, AIInspector.trace_count) or {}
    end

    if #events == 0 then
        imgui.TextColored(0.5, 0.5, 0.5, 1, "No trace events recorded")
        return
    end

    imgui.Text(string.format("Showing %d events:", #events))

    -- Scrolling child region (use fixed height for compatibility)
    if imgui.BeginChild("trace_scroll", 0, 300, true) then
        for i, event in ipairs(events) do
            local type_str = event.type or "UNKNOWN"
            local color = EVENT_TYPE_COLORS[type_str] or {1, 1, 1, 1}

            -- Timestamp prefix
            local prefix = ""
            if AIInspector.show_timestamps and event.timestamp then
                prefix = string.format("[%.2f] ", event.timestamp)
            end

            -- Event type badge
            imgui.TextColored(color[1], color[2], color[3], color[4],
                string.format("%s[%s]", prefix, type_str))
            imgui.SameLine()

            -- Message
            imgui.TextWrapped(event.message or "")

            -- Extra data (collapsible)
            if event.extra_data and next(event.extra_data) then
                imgui.Indent()
                for k, v in pairs(event.extra_data) do
                    imgui.TextColored(0.7, 0.7, 0.7, 1, string.format("%s: %s", k, v))
                end
                imgui.Unindent()
            end
        end
    end
    imgui.EndChild()
end

--===========================================================================
-- MAIN RENDER
--===========================================================================

--- Render the AI inspector window
--- Call this in your ImGui render loop
function AIInspector.render()
    if not AIInspector.is_open then return end
    if not imgui then return end  -- ImGui not available

    local open = imgui.Begin("AI Inspector", true, 0)
    if not open then
        AIInspector.is_open = false
        imgui.End()
        return
    end

    -- Entity selection
    render_entity_selector()

    -- Controls
    local _, auto = imgui.Checkbox("Auto-refresh", AIInspector.auto_refresh)
    AIInspector.auto_refresh = auto

    imgui.Separator()

    -- Refresh GOAP state if needed
    local eid = AIInspector.target_entity
    if eid and (AIInspector.auto_refresh or not AIInspector.cached_state) then
        if entity_cache.valid(eid) and ai and ai.get_goap_state then
            AIInspector.cached_state = ai.get_goap_state(eid)
        else
            AIInspector.cached_state = nil
        end
    end

    -- Tab bar
    local tab_names = {"State", "Plan", "Atoms", "Trace"}
    for i, name in ipairs(tab_names) do
        if i > 1 then imgui.SameLine() end
        local is_selected = (AIInspector.current_tab == i)
        if is_selected then
            imgui.PushStyleColor(ImGuiCol.Button, 0.4, 0.4, 0.8, 1.0)
        end
        if imgui.Button(name) then
            AIInspector.current_tab = i
        end
        if is_selected then
            imgui.PopStyleColor()
        end
    end

    imgui.Separator()

    -- Render current tab
    if not eid then
        imgui.TextColored(0.7, 0.7, 0.7, 1, "Select an entity to inspect")
        imgui.Text("")
        imgui.Text("Tips:")
        imgui.BulletText("Use the dropdown above to select a GOAP entity")
        imgui.BulletText("Call AIInspector.set_target(eid) from console")
    elseif not entity_cache.valid(eid) then
        imgui.TextColored(1, 0, 0, 1, string.format("Entity %s is invalid!", tostring(eid)))
    else
        if AIInspector.current_tab == 1 then
            render_state_tab()
        elseif AIInspector.current_tab == 2 then
            render_plan_tab()
        elseif AIInspector.current_tab == 3 then
            render_atoms_tab()
        elseif AIInspector.current_tab == 4 then
            render_trace_tab()
        end
    end

    imgui.End()
end

return AIInspector
