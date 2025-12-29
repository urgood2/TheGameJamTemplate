--[[
================================================================================
UI OVERLAY TOGGLES
================================================================================
ImGui panel providing checkboxes to toggle visibility of action mode UI overlays:
- Wand Cast Display (CastExecutionGraphUI)
- Cast Feed (CastFeedUI)
- Wand Cooldown (WandCooldownUI)
- Timer Debug (SubcastDebugUI)
]]--

local UIOverlayToggles = {}

-- Default visibility states (all enabled by default except cast_feed which is permanently off)
UIOverlayToggles.state = {
    show_wand_cooldown = true,
    show_cast_feed = false,  -- Permanently disabled
    show_cast_execution_graph = true,
    show_subcast_debug = true,
}

UIOverlayToggles.isActive = false
UIOverlayToggles._windowOpen = false

function UIOverlayToggles.init()
    UIOverlayToggles.isActive = true
end

function UIOverlayToggles.clear()
    UIOverlayToggles.isActive = false
end

-- Getter functions for each overlay to check visibility
function UIOverlayToggles.isWandCooldownVisible()
    return UIOverlayToggles.state.show_wand_cooldown
end

function UIOverlayToggles.isCastFeedVisible()
    return UIOverlayToggles.state.show_cast_feed
end

function UIOverlayToggles.isCastExecutionGraphVisible()
    return UIOverlayToggles.state.show_cast_execution_graph
end

function UIOverlayToggles.isSubcastDebugVisible()
    return UIOverlayToggles.state.show_subcast_debug
end

-- Toggle functions for programmatic control
function UIOverlayToggles.toggleWandCooldown()
    UIOverlayToggles.state.show_wand_cooldown = not UIOverlayToggles.state.show_wand_cooldown
end

function UIOverlayToggles.toggleCastFeed()
    UIOverlayToggles.state.show_cast_feed = not UIOverlayToggles.state.show_cast_feed
end

function UIOverlayToggles.toggleCastExecutionGraph()
    UIOverlayToggles.state.show_cast_execution_graph = not UIOverlayToggles.state.show_cast_execution_graph
end

function UIOverlayToggles.toggleSubcastDebug()
    UIOverlayToggles.state.show_subcast_debug = not UIOverlayToggles.state.show_subcast_debug
end

-- Set all overlays visible or hidden
function UIOverlayToggles.setAllVisible(visible)
    UIOverlayToggles.state.show_wand_cooldown = visible
    UIOverlayToggles.state.show_cast_feed = visible
    UIOverlayToggles.state.show_cast_execution_graph = visible
    UIOverlayToggles.state.show_subcast_debug = visible
end

--- Render the ImGui panel with checkboxes for each overlay
function UIOverlayToggles.render()
    if not ImGui then return end

    -- Use a collapsing header within existing debug windows, or create own window
    if ImGui.Begin("UI Overlay Toggles") then
        ImGui.Text("ACTION MODE OVERLAYS")
        ImGui.Separator()

        -- Note: ImGui.Checkbox returns (new_value, was_pressed) - value comes FIRST

        -- Wand Cooldown (left side panel)
        UIOverlayToggles.state.show_wand_cooldown =
            ImGui.Checkbox("Wand Cooldown (Left)", UIOverlayToggles.state.show_wand_cooldown)

        -- Cast Feed (bottom area - spell type discoveries)
        UIOverlayToggles.state.show_cast_feed =
            ImGui.Checkbox("Cast Feed (Bottom)", UIOverlayToggles.state.show_cast_feed)

        -- Cast Execution Graph (wand cast block display)
        UIOverlayToggles.state.show_cast_execution_graph =
            ImGui.Checkbox("Cast Execution Graph", UIOverlayToggles.state.show_cast_execution_graph)

        -- Subcast Debug (timer debug prints)
        UIOverlayToggles.state.show_subcast_debug =
            ImGui.Checkbox("Timer Debug (Subcast)", UIOverlayToggles.state.show_subcast_debug)

        ImGui.Separator()

        -- Quick toggle buttons
        if ImGui.Button("Show All") then
            UIOverlayToggles.setAllVisible(true)
        end
        ImGui.SameLine()
        if ImGui.Button("Hide All") then
            UIOverlayToggles.setAllVisible(false)
        end
    end
    ImGui.End()
end

return UIOverlayToggles
