#include "controller_nav.hpp"
#include "spdlog/spdlog.h"
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"
#include "systems/input/input_functions.hpp"
#include "systems/ui/ui_data.hpp"
#include "systems/ui/box.hpp"
#include "core/engine_context.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"
#include "sol/types.hpp"
#include "util/error_handling.hpp"

namespace controller_nav {

NavManager& NavManager::instance() {
    static NavManager mgr;
    return mgr;
}

// -----------------------------------------------------------------------------
// Layer Management
// -----------------------------------------------------------------------------
void NavManager::create_layer(const std::string& name) {
    if (!layers.contains(name))
        layers[name] = NavLayer{name, {}, false, 0};
}

void NavManager::add_group_to_layer(const std::string& layer, const std::string& group) {
    if (!layers.contains(layer) || !groups.contains(group)) return;
    auto& l = layers[layer];
    if (std::find(l.groups.begin(), l.groups.end(), group) == l.groups.end())
        l.groups.push_back(group);
    groupToLayer[group] = layer;
}

void NavManager::set_active_layer(const std::string& name) {
    if (!layers.contains(name)) {
        SPDLOG_ERROR("[Nav] Attempted to set active layer to non-existent layer '{}'", name);
        return;
    }
    if (!activeLayer.empty()) layers[activeLayer].active = false;
    activeLayer = name;
    layers[name].active = true;
}

void NavManager::push_layer(const std::string& name) {
    if (!layers.contains(name)) return;
    if (!activeLayer.empty()) layers[activeLayer].active = false;
    layerStack.push_back(name);
    set_active_layer(name);
}

void NavManager::pop_layer() {
    // Graceful error handling for production (asserts only fire in debug)
    if (layerStack.empty()) {
        SPDLOG_ERROR("[Nav] pop_layer() called on empty stack");
        return;
    }

    // Get the layer we're popping (to remove its focus state)
    std::string poppedLayer = layerStack.back();
    layerStack.pop_back();

    // Remove focus state for the popped layer
    layerFocusStack.erase(
        std::remove_if(layerFocusStack.begin(), layerFocusStack.end(),
            [&poppedLayer](const LayerFocusState& s) { return s.layerName == poppedLayer; }),
        layerFocusStack.end());

    if (!layerStack.empty()) {
        std::string newActiveLayer = layerStack.back();
        set_active_layer(newActiveLayer);

        // Clear previous restored focus; repopulate if we have a saved state
        lastRestoredFocus.entity = entt::null;
        lastRestoredFocus.group.clear();

        // Restore focus for the newly active layer
        for (const auto& state : layerFocusStack) {
            if (state.layerName == newActiveLayer) {
                lastRestoredFocus.entity = state.previousFocus;
                lastRestoredFocus.group = state.previousGroup;
                break;
            }
        }
    } else {
        activeLayer.clear();
        // Clear restored focus when no layers remain
        lastRestoredFocus.entity = entt::null;
        lastRestoredFocus.group.clear();
    }
}

// -----------------------------------------------------------------------------
// Group Management
// -----------------------------------------------------------------------------
void NavManager::create_group(const std::string& name) {
    NavGroup g{};
    g.name = name;
    g.active = true;
    g.linear = false;
    g.spatial = true;
    groups[name] = std::move(g);
}

void NavManager::add_entity(const std::string& group, entt::entity e) {
    if (!groups.contains(group)) return;
    groups[group].entries.push_back(e);
    entityToGroup[e] = group;
}

void NavManager::remove_entity(const std::string& group, entt::entity e) {
    if (!groups.contains(group)) return;
    auto& v = groups[group].entries;
    v.erase(std::remove(v.begin(), v.end(), e), v.end());
    // Clean up explicit neighbors for this entity
    explicitNeighbors.erase(e);
    // Remove from entity-to-group map
    entityToGroup.erase(e);
}

void NavManager::clear_group(const std::string& group) {
    if (!groups.contains(group)) return;
    // Clean up explicit neighbors and entity-to-group mappings for all entities
    for (entt::entity e : groups[group].entries) {
        explicitNeighbors.erase(e);
        entityToGroup.erase(e);
    }
    groups[group].entries.clear();
}

void NavManager::set_active(const std::string& group, bool active) {
    if (groups.contains(group)) groups[group].active = active;
}

entt::entity NavManager::get_selected(const std::string& group) {
    if (!groups.contains(group)) return entt::null;
    auto& g = groups[group];

    // Handle empty group gracefully
    if (g.entries.empty()) return entt::null;

    if (g.selectedIndex < 0 || g.selectedIndex >= (int)g.entries.size())
        return g.entries[0]; // default to first entry

    return g.entries[g.selectedIndex];
}

void NavManager::set_selected(const std::string& group, int index) {
    if (!groups.contains(group)) return;
    auto& g = groups[group];
    if (index < 0 || index >= (int)g.entries.size()) return;
    g.selectedIndex = index;
}

void NavManager::set_entity_enabled(entt::entity e, bool enabled) {
    if (enabled)
        disabledEntities.erase(e);
    else
        disabledEntities.insert(e);
}
bool NavManager::is_entity_enabled(entt::entity e) const {
    return disabledEntities.find(e) == disabledEntities.end();
}

std::string NavManager::get_group_for_entity(entt::entity e) const {
    auto it = entityToGroup.find(e);
    return it != entityToGroup.end() ? it->second : "";
}

// -----------------------------------------------------------------------------
// Explicit neighbor overrides
// -----------------------------------------------------------------------------
void NavManager::set_neighbors(entt::entity e, const NavNeighbors& neighbors) {
    explicitNeighbors[e] = neighbors;
}

NavNeighbors NavManager::get_neighbors(entt::entity e) const {
    auto it = explicitNeighbors.find(e);
    return it != explicitNeighbors.end() ? it->second : NavNeighbors{};
}

void NavManager::clear_neighbors(entt::entity e) {
    explicitNeighbors.erase(e);
}

// -----------------------------------------------------------------------------
// Controller-driven navigation
// -----------------------------------------------------------------------------
void NavManager::navigate(entt::registry& reg, input::InputState& state, const std::string& group, std::string_view dir)
{
    // Graceful error handling for invalid inputs
    if (group.empty()) {
        SPDLOG_ERROR("[Nav] navigate() called with empty group name");
        return;
    }
    if (dir.empty()) {
        SPDLOG_ERROR("[Nav] navigate() called with empty direction");
        return;
    }

    // -------------------------------------------------------------------------
    // Input repeat handling with initial delay + rate + acceleration
    // -------------------------------------------------------------------------
    auto& rs = repeatStates[group];
    std::string dirStr(dir);

    // Check if direction changed - if so, reset repeat state
    bool directionChanged = (rs.lastDirection != dirStr);
    if (directionChanged) {
        rs.lastDirection = dirStr;
        rs.repeatCount = 0;
        rs.timeUntilRepeat = 0.0f;
        rs.initialNavDone = false;
    }

    // If this is the first navigation in this direction, allow it immediately
    if (!rs.initialNavDone) {
        rs.initialNavDone = true;
        rs.timeUntilRepeat = repeatConfig.initialDelay;  // Set delay before first repeat
    } else {
        // We're in repeat mode - check if enough time has passed
        if (rs.timeUntilRepeat > 0.0f) {
            return; // Still waiting for repeat
        }

        // Increment repeat count and calculate NEXT repeat delay with acceleration
        rs.repeatCount++;
        float currentRate = repeatConfig.repeatRate;
        for (int i = 0; i < rs.repeatCount; ++i) {
            currentRate *= repeatConfig.acceleration;
        }
        currentRate = std::max(currentRate, repeatConfig.minRepeatRate);

        rs.timeUntilRepeat = currentRate;
    }


    if (!groups.contains(group)) return;
    auto& g = groups[group];
    if (!g.active || g.entries.empty()) return;

    entt::entity prev = get_selected(group);
    state.cursor_focused_target = prev;
    entt::entity nextEntity = entt::null;
    
    if (!activeLayer.empty()) {
        auto& layer = layers[activeLayer];
        if (std::find(layer.groups.begin(), layer.groups.end(), group) == layer.groups.end())
            return; // skip groups not part of the active layer
    }
    
    //---------------------------------------------------------------------
    // Validate current focused target, switch if needed to next available
    //---------------------------------------------------------------------
    if (reg.valid(state.cursor_focused_target) &&
    !entity_gamestate_management::isEntityActive(reg, state.cursor_focused_target))
    {
        // Try to find next available entry
        auto& entries = g.entries;
        auto it = std::find(entries.begin(), entries.end(), state.cursor_focused_target);
        if (it != entries.end()) {
            auto nextIt = std::next(it);
            while (nextIt != entries.end() && 
                (!reg.valid(*nextIt) || !entity_gamestate_management::isEntityActive(reg, *nextIt)))
                ++nextIt;
            if (nextIt != entries.end())
                state.cursor_focused_target = *nextIt;
            else
                state.cursor_focused_target = entt::null;
        }
    }

    //---------------------------------------------------------------------
    // EXPLICIT NEIGHBOR CHECK (highest priority)
    //---------------------------------------------------------------------
    entt::entity currentFocus = reg.valid(state.cursor_focused_target)
                                ? state.cursor_focused_target
                                : get_selected(group);
    if (reg.valid(currentFocus)) {
        auto it = explicitNeighbors.find(currentFocus);
        if (it != explicitNeighbors.end()) {
            const auto& neighbors = it->second;
            std::optional<entt::entity> explicitTarget;

            if (dir == "U" && neighbors.up) explicitTarget = neighbors.up;
            else if (dir == "D" && neighbors.down) explicitTarget = neighbors.down;
            else if (dir == "L" && neighbors.left) explicitTarget = neighbors.left;
            else if (dir == "R" && neighbors.right) explicitTarget = neighbors.right;

            // Only use explicit neighbor if it's valid, active, and enabled
            if (explicitTarget && reg.valid(*explicitTarget) &&
                entity_gamestate_management::isEntityActive(reg, *explicitTarget) &&
                is_entity_enabled(*explicitTarget)) {
                nextEntity = *explicitTarget;
                // Update selectedIndex if the target is in this group
                auto targetIt = std::find(g.entries.begin(), g.entries.end(), nextEntity);
                if (targetIt != g.entries.end()) {
                    g.selectedIndex = static_cast<int>(std::distance(g.entries.begin(), targetIt));
                }
            }
        }
    }

    //---------------------------------------------------------------------
    // SPATIAL MODE (reference-based directional focus)
    //---------------------------------------------------------------------
    if (nextEntity == entt::null && g.spatial)
    {
        // If nothing focused yet, use currently selectedIndex as base
        entt::entity referenceEntity = state.cursor_focused_target;
        if (!reg.valid(referenceEntity))
            referenceEntity = get_selected(group);

        if (!reg.valid(referenceEntity))
        {
            // fallback to first valid entry
            for (auto e : g.entries)
            {
                if (reg.valid(e) && entity_gamestate_management::isEntityActive(reg, e) && is_entity_enabled(e))
                {
                    referenceEntity = e;
                    break;
                }
            }
        }

        if (!reg.valid(referenceEntity))
            return; // nothing to base navigation on

        auto& curT = reg.get<transform::Transform>(referenceEntity);
        Vector2 curCenter{
            curT.getActualX() + curT.getActualW() * 0.5f,
            curT.getActualY() + curT.getActualH() * 0.5f
        };

        // Collect eligible candidates
        struct Candidate { entt::entity e; float dist; };
        std::vector<Candidate> candidates;

        for (auto e : g.entries)
        {
            if (e == referenceEntity) continue;
            if (!reg.valid(e)) continue;
            if (!entity_gamestate_management::isEntityActive(reg, e)) continue;
            if (!is_entity_enabled(e)) continue;

            auto& t = reg.get<transform::Transform>(e);
            Vector2 c{
                t.getActualX() + t.getActualW() * 0.5f,
                t.getActualY() + t.getActualH() * 0.5f
            };

            Vector2 diff{ c.x - curCenter.x, c.y - curCenter.y };
            float dist = fabs(diff.x) + fabs(diff.y);

            bool eligible = false;

            // Dominant-axis logic (matches your reference)
            if (fabs(diff.x) > fabs(diff.y))
            {
                if (diff.x > 0 && dir == "R") eligible = true;
                else if (diff.x < 0 && dir == "L") eligible = true;
            }
            else
            {
                if (diff.y > 0 && dir == "D") eligible = true;
                else if (diff.y < 0 && dir == "U") eligible = true;
            }

            // Optionally widen the acceptance cone
            if (!eligible)
            {
                float len = sqrtf(diff.x * diff.x + diff.y * diff.y);
                if (len > 1e-3f)
                {
                    Vector2 n{ diff.x / len, diff.y / len };
                    if (dir == "L" && n.x < -0.3f) eligible = true;
                    else if (dir == "R" && n.x > 0.3f) eligible = true;
                    else if (dir == "U" && n.y < -0.3f) eligible = true;
                    else if (dir == "D" && n.y > 0.3f) eligible = true;
                }
            }

            if (eligible)
                candidates.push_back({e, dist});
        }

        if (!candidates.empty())
        {
            std::sort(candidates.begin(), candidates.end(),
                [](const Candidate& a, const Candidate& b){ return a.dist < b.dist; });

            nextEntity = candidates.front().e;
            auto it = std::find(g.entries.begin(), g.entries.end(), nextEntity);
            g.selectedIndex = (it != g.entries.end()) ? std::distance(g.entries.begin(), it) : 0;
        }
        else
        {
            if (nextEntity == entt::null && !candidates.empty())
                nextEntity = candidates.front().e;
            else if (nextEntity == entt::null)
                return; // stop at edge instead of bouncing
            
            // Fallback: choose nearest valid entity even if diagonal
            float bestDist = std::numeric_limits<float>::max();
            for (auto e : g.entries)
            {
                if (!reg.valid(e)) continue;
                if (!entity_gamestate_management::isEntityActive(reg, e)) continue;
                if (!is_entity_enabled(e)) continue;
                if (!reg.all_of<transform::Transform>(e)) continue;

                auto& t = reg.get<transform::Transform>(e);
                Vector2 c{t.getActualX() + t.getActualW() * 0.5f,
                        t.getActualY() + t.getActualH() * 0.5f};
                float dx = c.x - curCenter.x;
                float dy = c.y - curCenter.y;
                float d = std::sqrt(dx*dx + dy*dy);
                if (d < bestDist && e != referenceEntity)
                {
                    bestDist = d;
                    nextEntity = e;
                }
            }

            // If still none, stay put
            if (nextEntity == entt::null)
                nextEntity = referenceEntity;
        }
    }


    //---------------------------------------------------------------------
    // LINEAR MODE (default or spatial fallback)
    //---------------------------------------------------------------------
    if (nextEntity == entt::null)
    {
        // Construct a filtered list of active entries
        std::vector<entt::entity> activeEntries;
        for (auto e : g.entries)
        {
            if (reg.valid(e) && entity_gamestate_management::isEntityActive(reg, e) && is_entity_enabled(e))
                activeEntries.push_back(e);
        }
        if (activeEntries.empty()) {
            g.selectedIndex = -1;
            return;
        }

        int prevIndex = g.selectedIndex;
        if (prevIndex < 0 || prevIndex >= (int)activeEntries.size())
            prevIndex = 0; // clamp to valid index if stale

        int nextIndex = prevIndex;
        if (dir == "L" || dir == "U") nextIndex--;
        else if (dir == "R" || dir == "D") nextIndex++;

        if (g.wrap) {
            if (nextIndex < 0) nextIndex = (int)activeEntries.size() - 1;
            if (nextIndex >= (int)activeEntries.size()) nextIndex = 0;
            g.selectedIndex = nextIndex;
            nextEntity = activeEntries[nextIndex];
        } else {
            // Check if we hit an edge (trying to go out of bounds)
            bool atEdge = (nextIndex < 0 || nextIndex >= (int)activeEntries.size());
            if (atEdge) {
                // Don't set nextEntity - let linked group transition code handle it
                // Keep selectedIndex at the edge
                g.selectedIndex = std::clamp(prevIndex, 0, (int)activeEntries.size() - 1);
            } else {
                g.selectedIndex = nextIndex;
                nextEntity = activeEntries[nextIndex];
            }
        }
    }


    //---------------------------------------------------------------------
    // Hierarchical or linked group transition
    //---------------------------------------------------------------------
    if (nextEntity == entt::null)
    {
        std::string targetGroup;
        if (dir == "U" && !g.upGroup.empty()) targetGroup = g.upGroup;
        else if (dir == "D" && !g.downGroup.empty()) targetGroup = g.downGroup;
        else if (dir == "L" && !g.leftGroup.empty()) targetGroup = g.leftGroup;
        else if (dir == "R" && !g.rightGroup.empty()) targetGroup = g.rightGroup;

        if (!targetGroup.empty() && groups.contains(targetGroup))
        {
            auto& ng = groups[targetGroup];

            // Make sure the target group has valid entries and is active
            if (!ng.active || ng.entries.empty()) return;

            // Find which layers these groups belong to
            std::string currentLayerName = groupToLayer[group];
            std::string targetLayerName  = groupToLayer[targetGroup];

            // Handle automatic layer switching and popping
            if (!targetLayerName.empty() && targetLayerName != activeLayer)
            {
                // Find current layer depth
                int currentDepth = -1;
                int targetDepth = -1;
                for (int i = 0; i < (int)layerStack.size(); ++i)
                {
                    if (layerStack[i] == currentLayerName) currentDepth = i;
                    if (layerStack[i] == targetLayerName) targetDepth = i;
                }

                // Case 1: target layer is not on stack → push it
                if (targetDepth == -1)
                {
                    push_layer(targetLayerName);
                }
                else if (targetDepth == currentDepth - 1)
                {
                    // Case 2: target layer is directly below current one → pop
                    pop_layer();
                }
                else if (targetDepth < currentDepth - 1)
                {
                    // Case 3: illegal jump (skipping layers) - log error and recover gracefully
                    SPDLOG_ERROR("[ControllerNav] Invalid layer transition: trying to skip multiple layers "
                                "(from {} -> {})", currentLayerName, targetLayerName);
                    return; // Don't crash - just abort the navigation attempt
                }
                else
                {
                    // Case 4: jumping sideways to a sibling layer on stack → just activate
                    set_active_layer(targetLayerName);
                }
            }


            // Focus the new group within its layer
            entt::entity nextFocus = get_selected(targetGroup);
            if (reg.valid(nextFocus))
            {
                state.cursor_prev_focused_target = state.cursor_focused_target;
                state.cursor_focused_target = nextFocus;
                notify_focus(prev, nextFocus, reg);
                input::UpdateCursor(state, reg);
            }

            return;
        }    
    }

    //---------------------------------------------------------------------
    // Apply focus change
    //---------------------------------------------------------------------
    state.cursor_prev_focused_target = state.cursor_focused_target;
    state.cursor_focused_target = nextEntity;
    state.controllerNavOverride = true;

    // Validate entity has Transform component (required for cursor positioning)
    if (reg.valid(nextEntity) && !reg.all_of<transform::Transform>(nextEntity)) {
        SPDLOG_ERROR("[Nav] Cannot focus entity {} - missing Transform component. "
                     "Keeping focus on entity {}",
                     static_cast<uint32_t>(nextEntity),
                     reg.valid(prev) ? static_cast<uint32_t>(prev) : 0);
        nextEntity = prev; // Stay on previous valid entity (or null)
        state.cursor_focused_target = nextEntity; // Update state to reflect fallback
    }

    notify_focus(prev, nextEntity, reg);
    scroll_into_view(reg, nextEntity);  // Auto-scroll to keep focused element visible
    input::UpdateCursor(state, reg);
}

void NavManager::select_current(entt::registry& reg, const std::string& group) {
    if (!groups.contains(group)) return;
    entt::entity e = get_selected(group);
    if (reg.valid(e))
        notify_select(e, reg);
}

// -----------------------------------------------------------------------------
// Scroll support
// -----------------------------------------------------------------------------
void NavManager::scroll_into_view(entt::registry& reg, entt::entity e) {
    if (!reg.valid(e)) return;

    // Check if entity has a scroll pane ancestor
    auto* paneRef = reg.try_get<ui::UIPaneParentRef>(e);
    if (!paneRef || !reg.valid(paneRef->pane)) return;

    auto* scroll = reg.try_get<ui::UIScrollComponent>(paneRef->pane);
    if (!scroll) return;

    // Get entity's transform for position
    auto* entityTransform = reg.try_get<transform::Transform>(e);
    auto* paneTransform = reg.try_get<transform::Transform>(paneRef->pane);
    if (!entityTransform || !paneTransform) return;

    // Calculate entity's position relative to the scroll pane
    float entityTop = entityTransform->getActualY();
    float entityBottom = entityTop + entityTransform->getActualH();
    float paneTop = paneTransform->getActualY();
    float oldOffset = scroll->offset;

    // Adjust scroll offset to ensure entity is visible
    // Account for current scroll offset in visibility check
    float visibleTop = paneTop - scroll->offset;
    float visibleBottom = visibleTop + scroll->viewportSize.y;

    if (entityTop < visibleTop) {
        // Entity is above visible area - scroll up
        scroll->offset = -(entityTop - paneTop);
        scroll->offset = std::clamp(scroll->offset, scroll->minOffset, scroll->maxOffset);
    } else if (entityBottom > visibleBottom) {
        // Entity is below visible area - scroll down
        scroll->offset = -(entityBottom - paneTop - scroll->viewportSize.y);
        scroll->offset = std::clamp(scroll->offset, scroll->minOffset, scroll->maxOffset);
    }

    if (scroll->offset != oldOffset) {
        // Update show timer so scrollbar is visible
        scroll->showUntilT = main_loop::getTime() + scroll->showSeconds;

        // Apply displacement to children (match mouse wheel behavior)
        ui::box::TraverseUITreeBottomUp(
            reg, paneRef->pane,
            [&](entt::entity child) {
                auto &go = reg.get<transform::GameObject>(child);
                go.scrollPaneDisplacement = Vector2{0.f, -scroll->offset};
            },
            true
        );

        scroll->prevOffset = scroll->offset;
    }
}

void NavManager::scroll_group(entt::registry& reg, const std::string& group, float deltaX, float deltaY) {
    if (!groups.contains(group)) return;

    // Find scroll pane for this group (first entity with scroll pane ancestor)
    auto& g = groups[group];
    for (entt::entity e : g.entries) {
        if (!reg.valid(e)) continue;

        auto* paneRef = reg.try_get<ui::UIPaneParentRef>(e);
        if (!paneRef || !reg.valid(paneRef->pane)) continue;

        auto* scroll = reg.try_get<ui::UIScrollComponent>(paneRef->pane);
        if (!scroll) continue;

        float oldOffset = scroll->offset;

        // Apply scroll delta
        if (scroll->vertical) {
            scroll->offset = std::clamp(scroll->offset - deltaY, scroll->minOffset, scroll->maxOffset);
        }
        if (scroll->horizontal) {
            // Horizontal scrolling would need a separate X offset field
            // For now, we only support vertical
        }

        if (scroll->offset != oldOffset) {
            // Update show timer
            scroll->showUntilT = main_loop::getTime() + scroll->showSeconds;

            // Apply displacement to children (match mouse wheel behavior)
            ui::box::TraverseUITreeBottomUp(
                reg, paneRef->pane,
                [&](entt::entity child) {
                    auto &go = reg.get<transform::GameObject>(child);
                    go.scrollPaneDisplacement = Vector2{0.f, -scroll->offset};
                },
                true
            );

            scroll->prevOffset = scroll->offset;
        }
        return; // Only scroll the first found pane
    }
}

// -----------------------------------------------------------------------------
// Update per-frame
// -----------------------------------------------------------------------------
void NavManager::update(float dt) {
    // Update old-style group cooldowns (kept for backward compatibility)
    for (auto& [name, t] : groupCooldowns)
        if (t > 0.0f) t -= dt;

    // Update repeat state timers
    for (auto& [name, rs] : repeatStates)
        if (rs.timeUntilRepeat > 0.0f) rs.timeUntilRepeat -= dt;
}

// -----------------------------------------------------------------------------
// Validation
// -----------------------------------------------------------------------------
std::string NavManager::validate() const {
    std::string errors;
    auto appendError = [&errors](const std::string& msg) {
        if (!errors.empty()) errors += "\n";
        errors += msg;
        SPDLOG_ERROR("[Nav] {}", msg);
    };

    // 1. Check layers reference valid groups
    for (auto& [lname, layer] : layers) {
        for (auto& gname : layer.groups) {
            if (!groups.contains(gname)) {
                appendError("Layer '" + lname + "' references missing group '" + gname + "'");
            }
        }
    }

    // 2. Check groupToLayer points to valid layers
    for (auto& [gname, lname] : groupToLayer) {
        if (!layers.contains(lname)) {
            appendError("groupToLayer: Group '" + gname + "' references non-existent layer '" + lname + "'");
        }
    }

    // 3. Check selectedIndex bounds for each group
    for (auto& [gname, group] : groups) {
        if (group.entries.empty()) {
            if (group.selectedIndex != -1) {
                appendError("Group '" + gname + "' is empty but selectedIndex is " +
                           std::to_string(group.selectedIndex) + " (should be -1)");
            }
        } else {
            if (group.selectedIndex >= static_cast<int>(group.entries.size())) {
                appendError("Group '" + gname + "' selectedIndex " +
                           std::to_string(group.selectedIndex) + " is out of bounds (size: " +
                           std::to_string(group.entries.size()) + ")");
            }
        }

        // 4. Check for duplicate entities in group
        std::unordered_set<entt::entity> seenEntities;
        for (auto e : group.entries) {
            if (seenEntities.contains(e)) {
                appendError("Group '" + gname + "' contains duplicate entity " +
                           std::to_string(static_cast<uint32_t>(e)));
            }
            seenEntities.insert(e);
        }
    }

    // 5. Check entityToGroup map consistency
    for (auto& [entity, gname] : entityToGroup) {
        if (!groups.contains(gname)) {
            appendError("entityToGroup: Entity " + std::to_string(static_cast<uint32_t>(entity)) +
                       " maps to non-existent group '" + gname + "'");
            continue;
        }
        const auto& entries = groups.at(gname).entries;
        if (std::find(entries.begin(), entries.end(), entity) == entries.end()) {
            appendError("entityToGroup: Stale entry - entity " +
                       std::to_string(static_cast<uint32_t>(entity)) +
                       " mapped to '" + gname + "' but not in entries");
        }
    }

    return errors;
}

// -----------------------------------------------------------------------------
// Stack / Focus group handling (SEPARATE from layer stack)
// -----------------------------------------------------------------------------
void NavManager::push_focus_group(const std::string& group) { focusGroupStack.push_back(group); }
void NavManager::pop_focus_group() { if (!focusGroupStack.empty()) focusGroupStack.pop_back(); }
std::string NavManager::current_focus_group() const {
    return focusGroupStack.empty() ? "" : focusGroupStack.back();
}

// -----------------------------------------------------------------------------
// Focus restoration for modal scope handling
// -----------------------------------------------------------------------------
void NavManager::record_focus_for_layer(entt::entity e, const std::string& group) {
    // Find if there's already a state for the current active layer
    // If not, create one
    if (activeLayer.empty()) {
        // No active layer - store in a default state
        LayerFocusState state;
        state.layerName = "";
        state.previousFocus = e;
        state.previousGroup = group;

        // Replace any existing default state or add new one
        bool found = false;
        for (auto& s : layerFocusStack) {
            if (s.layerName.empty()) {
                s = state;
                found = true;
                break;
            }
        }
        if (!found) {
            layerFocusStack.push_back(state);
        }
        return;
    }

    // Find existing state for this layer
    for (auto& state : layerFocusStack) {
        if (state.layerName == activeLayer) {
            state.previousFocus = e;
            state.previousGroup = group;
            return;
        }
    }

    // No existing state - create new one
    LayerFocusState state;
    state.layerName = activeLayer;
    state.previousFocus = e;
    state.previousGroup = group;
    layerFocusStack.push_back(state);
}

SavedFocusState NavManager::get_restored_focus() const {
    return lastRestoredFocus;
}

// -----------------------------------------------------------------------------
// Lua Hooks
// -----------------------------------------------------------------------------

void NavManager::notify_focus(entt::entity prev, entt::entity next, entt::registry& reg) {
    // global
    auto& globalCB = callbacks;
    // find per-group callbacks using O(1) lookup
    std::optional<NavCallbacks*> groupCB;
    std::string groupName = get_group_for_entity(next);
    if (!groupName.empty() && groups.contains(groupName)) {
        groupCB = &groups[groupName].callbacks;
    }

    auto fire = [&](sol::protected_function fn, entt::entity e, const char* label){
        if (fn.valid()) {
            auto r = util::safeLuaCall(fn, label, e);
            if (r.isErr()) {
                SPDLOG_ERROR("[Lua] {} error: {}", label, r.error());
            }
        }
    };

    if (prev != entt::null) {
        if (groupCB && (*groupCB)->on_unfocus.valid())
            fire((*groupCB)->on_unfocus, prev, "on_nav_unfocus (group)");
        else if (globalCB.on_unfocus.valid())
            fire(globalCB.on_unfocus, prev, "on_nav_unfocus (global)");
    }

    if (next != entt::null) {
        if (groupCB && (*groupCB)->on_focus.valid())
            fire((*groupCB)->on_focus, next, "on_nav_focus (group)");
        else if (globalCB.on_focus.valid())
            fire(globalCB.on_focus, next, "on_nav_focus (global)");
    }
}

void NavManager::notify_select(entt::entity selected, entt::registry& reg) {
    auto& globalCB = callbacks;
    // Use O(1) lookup to find the entity's group
    std::string groupName = get_group_for_entity(selected);
    if (!groupName.empty() && groups.contains(groupName)) {
        auto& g = groups[groupName];
        if (g.callbacks.on_select.valid()) {
            auto r = util::safeLuaCall(g.callbacks.on_select, "on_nav_select (group)", selected);
            if (r.isErr()) SPDLOG_ERROR("[Lua] on_nav_select error (group): {}", r.error());
            return;
        }
    }
    if (globalCB.on_select.valid()) {
        auto r = util::safeLuaCall(globalCB.on_select, "on_nav_select (global)", selected);
        if (r.isErr()) SPDLOG_ERROR("[Lua] on_nav_select error (global): {}", r.error());
    }
}

void NavManager::debug_print_state() const {
    SPDLOG_DEBUG("[Nav] Active layer: {}", activeLayer.empty() ? "none" : activeLayer);
    for (auto& [name, g] : groups)
        SPDLOG_DEBUG("  Group: {} ({} entries, active: {}, selected: {})",
                     name, g.entries.size(), g.active, g.selectedIndex);
}

void NavManager::reset() {
    callbacks.on_focus = sol::lua_nil_t{};
    callbacks.on_unfocus = sol::lua_nil_t{};
    callbacks.on_select = sol::lua_nil_t{};

    for (auto& [name, g] : groups) {
        g.callbacks.on_focus = sol::lua_nil_t{};
        g.callbacks.on_unfocus = sol::lua_nil_t{};
        g.callbacks.on_select = sol::lua_nil_t{};
    }
    groups.clear();
    layers.clear();
    layerStack.clear();
    focusGroupStack.clear();  // Separate from layerStack
    activeLayer.clear();
    disabledEntities.clear();
    groupToLayer.clear();
    groupCooldowns.clear();
    explicitNeighbors.clear();
    repeatStates.clear();
    layerFocusStack.clear();
    lastRestoredFocus.entity = entt::null;
    lastRestoredFocus.group.clear();
    entityToGroup.clear();
}

void exposeToLua(sol::state& lua, EngineContext* ctx) {
    (void)ctx; // placeholder for future context-aware bindings
    using std::string;
    auto& rec = BindingRecorder::instance();
    using controller_nav::NavManager;
    NavManager& NM = NavManager::instance();

    // -------------------------------------------------------------------------
    // Userdata: NavManagerUD
    // -------------------------------------------------------------------------
    auto nm_ud = lua.new_usertype<NavManager>(
        "NavManagerUD",
        sol::no_constructor,

        // Core management
        "update",             &NavManager::update,
        "validate",           &NavManager::validate,
        "debug_print_state",  &NavManager::debug_print_state,

        // Groups
        "create_group",       &NavManager::create_group,
        "add_entity",         &NavManager::add_entity,
        "remove_entity",      &NavManager::remove_entity,
        "clear_group",        &NavManager::clear_group,
        "set_active",         &NavManager::set_active,
        "set_selected",       &NavManager::set_selected,
        "get_selected",       &NavManager::get_selected,
        "set_entity_enabled", &NavManager::set_entity_enabled,
        "is_entity_enabled",  &NavManager::is_entity_enabled,

        // Explicit neighbors (per-element navigation overrides)
        "set_neighbors", [&lua](NavManager* self, entt::entity e, sol::table neighbors) {
            NavNeighbors n{};
            // Note: Use sol::type::lua_nil to avoid conflict with macOS nil macro
            if (neighbors["up"].valid() && neighbors["up"].get_type() != sol::type::lua_nil)
                n.up = neighbors["up"].get<entt::entity>();
            if (neighbors["down"].valid() && neighbors["down"].get_type() != sol::type::lua_nil)
                n.down = neighbors["down"].get<entt::entity>();
            if (neighbors["left"].valid() && neighbors["left"].get_type() != sol::type::lua_nil)
                n.left = neighbors["left"].get<entt::entity>();
            if (neighbors["right"].valid() && neighbors["right"].get_type() != sol::type::lua_nil)
                n.right = neighbors["right"].get<entt::entity>();
            self->set_neighbors(e, n);
        },
        "get_neighbors", [&lua](NavManager* self, entt::entity e) {
            NavNeighbors n = self->get_neighbors(e);
            sol::table result = lua.create_table();
            if (n.up) result["up"] = *n.up;
            if (n.down) result["down"] = *n.down;
            if (n.left) result["left"] = *n.left;
            if (n.right) result["right"] = *n.right;
            return result;
        },
        "clear_neighbors", &NavManager::clear_neighbors,

        // Scroll support
        "scroll_into_view", [](NavManager* self, entt::entity e) {
            auto& reg = (globals::g_ctx) ? globals::g_ctx->registry : globals::getRegistry();
            self->scroll_into_view(reg, e);
        },
        "scroll_group", [](NavManager* self, const std::string& group, float deltaX, float deltaY) {
            auto& reg = (globals::g_ctx) ? globals::g_ctx->registry : globals::getRegistry();
            self->scroll_group(reg, group, deltaX, deltaY);
        },

        // Navigation
        "navigate", [](NavManager* self, const string& group, const string& dir) {
            auto& reg = (globals::g_ctx) ? globals::g_ctx->registry : globals::getRegistry();
            auto& state = globals::getInputState();
            self->navigate(reg, state, group, dir);
        },
        "select_current", [](NavManager* self, const string& group) {
            auto& reg = (globals::g_ctx) ? globals::g_ctx->registry : globals::getRegistry();
            self->select_current(reg, group);
        },

        // Layers
        "create_layer",        &NavManager::create_layer,
        "add_group_to_layer",  &NavManager::add_group_to_layer,
        "set_active_layer",    &NavManager::set_active_layer,
        "push_layer",          &NavManager::push_layer,
        "pop_layer",           &NavManager::pop_layer,

        // Focus stack
        "push_focus_group",    &NavManager::push_focus_group,
        "pop_focus_group",     &NavManager::pop_focus_group,
        "current_focus_group", &NavManager::current_focus_group
    );

    rec.add_type("NavManagerUD").doc =
        "Userdata type for the controller navigation manager.\n"
        "Use the global `controller_nav` table for live access.";

    rec.record_property("NavManagerUD",
        {"update", "", "---@param dt number"});
    rec.record_property("NavManagerUD",
        {"validate", "", "---@param self NavManagerUD\n---@return string @Empty if valid, error messages otherwise"});
    rec.record_property("NavManagerUD",
        {"debug_print_state", "", "---@param self NavManagerUD\n---@return nil"});
    rec.record_property("NavManagerUD",
        {"create_group", "", "---@param name string"});
    rec.record_property("NavManagerUD",
        {"add_entity", "", "---@param group string\n---@param e entt.entity"});
    rec.record_property("NavManagerUD",
        {"remove_entity", "", "---@param group string\n---@param e entt.entity"});
    rec.record_property("NavManagerUD",
        {"clear_group", "", "---@param group string"});
    rec.record_property("NavManagerUD",
        {"set_active", "", "---@param group string\n---@param active boolean"});
    rec.record_property("NavManagerUD",
        {"set_selected", "", "---@param group string\n---@param index integer"});
    rec.record_property("NavManagerUD",
        {"get_selected", "", "---@param group string\n---@return entt.entity|nil"});
    rec.record_property("NavManagerUD",
        {"set_entity_enabled", "", "---@param e entt.entity\n---@param enabled boolean"});
    rec.record_property("NavManagerUD",
        {"is_entity_enabled", "", "---@param e entt.entity\n---@return boolean"});
    rec.record_property("NavManagerUD",
        {"navigate", "", "---@param group string\n---@param dir 'L'|'R'|'U'|'D'"});
    rec.record_property("NavManagerUD",
        {"select_current", "", "---@param group string"});
    rec.record_property("NavManagerUD",
        {"create_layer", "", "---@param name string"});
    rec.record_property("NavManagerUD",
        {"add_group_to_layer", "", "---@param layer string\n---@param group string"});
    rec.record_property("NavManagerUD",
        {"set_active_layer", "", "---@param name string"});
    rec.record_property("NavManagerUD",
        {"push_layer", "", "---@param name string"});
    rec.record_property("NavManagerUD",
        {"pop_layer", "", ""});
    rec.record_property("NavManagerUD",
        {"push_focus_group", "", "---@param name string"});
    rec.record_property("NavManagerUD",
        {"pop_focus_group", "", ""});
    rec.record_property("NavManagerUD",
        {"current_focus_group", "", "---@param self NavManagerUD\n---@return string"});

    // -------------------------------------------------------------------------
    // Global table controller_nav
    // -------------------------------------------------------------------------
    sol::table nav = lua["controller_nav"].get_or_create<sol::table>();
    rec.add_type("controller_nav").doc =
        "Controller navigation system entry point.\n"
        "Manages layers, groups, and spatial/linear focus movement for UI and in-game entities.";

    nav["ud"] = &NM; // expose userdata handle

    // convenience wrappers
    rec.bind_function(lua, {"controller_nav"}, "create_group",
        [&](const string& n){ NM.create_group(n); },
        "---@param n string\n"
        "---@return nil",
        "Create a navigation group.");
    rec.bind_function(lua, {"controller_nav"}, "create_layer",
        [&](const string& n){ NM.create_layer(n); },
        "---@param n string\n"
        "---@return nil",
        "Create a navigation layer.");
    rec.bind_function(lua, {"controller_nav"}, "add_group_to_layer",
        [&](const string& l, const string& g){ NM.add_group_to_layer(l, g); },
        "---@param l string\n"
        "---@param g string\n"
        "---@return nil",
        "Attach an existing group to a layer.");
    rec.bind_function(lua, {"controller_nav"}, "navigate",
        [&](const string& g, const string& d){
            auto& reg = (globals::g_ctx) ? globals::g_ctx->registry : globals::getRegistry();
            auto& state = globals::getInputState();
            NM.navigate(reg, state, g, d);
        },
        "---@param g string\n"
        "---@param d string\n"
        "---@return nil",
        "Navigate within or across groups.");
    rec.bind_function(lua, {"controller_nav"}, "select_current",
        [&](const string& g){
            auto& reg = (globals::g_ctx) ? globals::g_ctx->registry : globals::getRegistry();
            NM.select_current(reg, g);
        },
        "---@param g string\n"
        "---@return nil",
        "Trigger the select callback for the currently focused entity.");
    rec.bind_function(lua, {"controller_nav"}, "set_entity_enabled",
        [&](entt::entity e, bool enabled){ NM.set_entity_enabled(e, enabled); },
        "---@param e entt.entity\n"
        "---@param enabled boolean\n"
        "---@return nil",
        "Enable or disable a specific entity for navigation.");

    rec.bind_function(lua, {"controller_nav"}, "get_group_for_entity",
        [&](entt::entity e){ return NM.get_group_for_entity(e); },
        "---@param e entt.entity\n"
        "---@return string",
        "Get the group name for an entity (O(1) lookup). Returns empty string if not found.");

    // Explicit neighbor convenience wrappers
    rec.bind_function(lua, {"controller_nav"}, "set_neighbors",
        [&lua](entt::entity e, sol::table neighbors) {
            NavNeighbors n{};
            // Note: Use sol::type::lua_nil to avoid conflict with macOS nil macro
            if (neighbors["up"].valid() && neighbors["up"].get_type() != sol::type::lua_nil)
                n.up = neighbors["up"].get<entt::entity>();
            if (neighbors["down"].valid() && neighbors["down"].get_type() != sol::type::lua_nil)
                n.down = neighbors["down"].get<entt::entity>();
            if (neighbors["left"].valid() && neighbors["left"].get_type() != sol::type::lua_nil)
                n.left = neighbors["left"].get<entt::entity>();
            if (neighbors["right"].valid() && neighbors["right"].get_type() != sol::type::lua_nil)
                n.right = neighbors["right"].get<entt::entity>();
            NavManager::instance().set_neighbors(e, n);
        },
        "---@param e entt.entity\n"
        "---@param neighbors {up?: entt.entity, down?: entt.entity, left?: entt.entity, right?: entt.entity}\n"
        "---@return nil",
        "Set explicit navigation neighbors for an entity (overrides spatial/linear navigation).");
    rec.bind_function(lua, {"controller_nav"}, "get_neighbors",
        [&lua](entt::entity e) {
            NavNeighbors n = NavManager::instance().get_neighbors(e);
            sol::table result = lua.create_table();
            if (n.up) result["up"] = *n.up;
            if (n.down) result["down"] = *n.down;
            if (n.left) result["left"] = *n.left;
            if (n.right) result["right"] = *n.right;
            return result;
        },
        "---@param e entt.entity\n"
        "---@return {up?: entt.entity, down?: entt.entity, left?: entt.entity, right?: entt.entity}",
        "Get explicit navigation neighbors for an entity.");
    rec.bind_function(lua, {"controller_nav"}, "clear_neighbors",
        [&](entt::entity e){ NavManager::instance().clear_neighbors(e); },
        "---@param e entt.entity\n"
        "---@return nil",
        "Clear explicit navigation neighbors for an entity.");

    // Scroll support
    rec.bind_function(lua, {"controller_nav"}, "scroll_into_view",
        [&](entt::entity e){
            auto& reg = (globals::g_ctx) ? globals::g_ctx->registry : globals::getRegistry();
            NavManager::instance().scroll_into_view(reg, e);
        },
        "---@param e entt.entity\n"
        "---@return nil",
        "Scroll the parent scroll pane to ensure the entity is visible.");
    rec.bind_function(lua, {"controller_nav"}, "scroll_group",
        [&](const std::string& group, float deltaX, float deltaY){
            auto& reg = (globals::g_ctx) ? globals::g_ctx->registry : globals::getRegistry();
            NavManager::instance().scroll_group(reg, group, deltaX, deltaY);
        },
        "---@param group string\n"
        "---@param deltaX number\n"
        "---@param deltaY number\n"
        "---@return nil",
        "Apply scroll delta to the scroll pane containing the group's entities.");

    rec.bind_function(lua, {"controller_nav"}, "debug_print_state",
        [&]{ NM.debug_print_state(); },
        "---@return nil",
        "Print debug info on groups/layers.");
    rec.bind_function(lua, {"controller_nav"}, "validate",
        [&]{ return NM.validate(); },
        "---@return string @Empty if valid, error messages otherwise",
        "Validate layer/group configuration. Returns empty string if valid.");
    rec.bind_function(lua, {"controller_nav"}, "current_focus_group",
        [&]{ return NM.current_focus_group(); },
        "---@return string",
        "Return the currently focused group.");

    rec.bind_function(lua, {"controller_nav"}, "set_group_callbacks",
        [&](const std::string& group, sol::table tbl) {
            auto& mgr = controller_nav::NavManager::instance();
            if (!mgr.groups.contains(group)) return;
            auto& g = mgr.groups[group];
            if (tbl["on_focus"].valid())   g.callbacks.on_focus   = tbl["on_focus"];
            if (tbl["on_unfocus"].valid()) g.callbacks.on_unfocus = tbl["on_unfocus"];
            if (tbl["on_select"].valid())  g.callbacks.on_select  = tbl["on_select"];
        },
        "---@param group string\n"
        "---@param tbl table\n"
        "---@return nil",
        "Set Lua callbacks for a specific navigation group.");

    rec.bind_function(lua, {"controller_nav"}, "link_groups",
        [&](const std::string& from, sol::table dirs) {
            auto& mgr = controller_nav::NavManager::instance();
            if (!mgr.groups.contains(from)) return;
            auto& g = mgr.groups[from];
            if (dirs["up"].valid())    g.upGroup    = dirs["up"];
            if (dirs["down"].valid())  g.downGroup  = dirs["down"];
            if (dirs["left"].valid())  g.leftGroup  = dirs["left"];
            if (dirs["right"].valid()) g.rightGroup = dirs["right"];
        },
        "---@param from string\n"
        "---@param dirs table\n"
        "---@return nil",
        "Link a group's navigation directions to other groups.");

    rec.bind_function(lua, {"controller_nav"}, "set_group_mode",
        [&](const std::string& group, const std::string& mode) {
            auto& mgr = controller_nav::NavManager::instance();
            if (!mgr.groups.contains(group)) return;
            mgr.groups[group].spatial = (mode == "spatial");
        },
        "---@param group string\n"
        "---@param mode string\n"
        "---@return nil",
        "Toggle navigation mode for the group.");

    rec.bind_function(lua, {"controller_nav"}, "set_wrap",
        [&](const std::string& group, bool wrap) {
            auto& mgr = controller_nav::NavManager::instance();
            if (!mgr.groups.contains(group)) return;
            mgr.groups[group].wrap = wrap;
        },
        "---@param group string\n"
        "---@param wrap boolean\n"
        "---@return nil",
        "Enable or disable wrap-around navigation.");

    // Repeat configuration functions
    rec.bind_function(lua, {"controller_nav"}, "set_repeat_config",
        [&](sol::table config) {
            auto& mgr = controller_nav::NavManager::instance();
            if (config["initialDelay"].valid())
                mgr.repeatConfig.initialDelay = config["initialDelay"].get<float>();
            if (config["repeatRate"].valid())
                mgr.repeatConfig.repeatRate = config["repeatRate"].get<float>();
            if (config["minRepeatRate"].valid())
                mgr.repeatConfig.minRepeatRate = config["minRepeatRate"].get<float>();
            if (config["acceleration"].valid())
                mgr.repeatConfig.acceleration = config["acceleration"].get<float>();
        },
        "---@param config {initialDelay?: number, repeatRate?: number, minRepeatRate?: number, acceleration?: number}\n"
        "---@return nil",
        "Configure input repeat behavior. initialDelay is the delay before first repeat, "
        "repeatRate is the time between repeats, acceleration (<1) speeds up repeats over time.");

    rec.bind_function(lua, {"controller_nav"}, "get_repeat_config",
        [&lua]() {
            auto& mgr = controller_nav::NavManager::instance();
            sol::table result = lua.create_table();
            result["initialDelay"] = mgr.repeatConfig.initialDelay;
            result["repeatRate"] = mgr.repeatConfig.repeatRate;
            result["minRepeatRate"] = mgr.repeatConfig.minRepeatRate;
            result["acceleration"] = mgr.repeatConfig.acceleration;
            return result;
        },
        "---@return {initialDelay: number, repeatRate: number, minRepeatRate: number, acceleration: number}",
        "Get the current input repeat configuration.");

    rec.bind_function(lua, {"controller_nav"}, "focus_entity",
        [&](entt::entity e) {
            auto& state = globals::getInputState();
            state.cursor_focused_target = e;
        },
        "---@param e entt.entity\n"
        "---@return nil",
        "Force cursor focus to a specific entity. Note that this does not affect the navigation state, and may be overridden on next navigation action.");

    // Focus restoration functions
    rec.bind_function(lua, {"controller_nav"}, "record_focus_for_layer",
        [&](entt::entity e, const std::string& group) {
            NavManager::instance().record_focus_for_layer(e, group);
        },
        "---@param e entt.entity\n"
        "---@param group string\n"
        "---@return nil",
        "Record the current focus entity and group for the active layer. Call this before pushing a new layer (e.g., modal) to enable focus restoration when that layer is popped.");

    rec.bind_function(lua, {"controller_nav"}, "get_restored_focus",
        [&lua]() {
            auto& mgr = NavManager::instance();
            auto restored = mgr.get_restored_focus();
            sol::table result = lua.create_table();
            if (restored.entity != entt::null) {
                result["entity"] = restored.entity;
            }
            result["group"] = restored.group;
            return result;
        },
        "---@return {entity?: entt.entity, group: string}",
        "Get the focus state that was restored after the last pop_layer(). Returns entity and group of what was focused before the modal was opened.");
}

} // namespace controller_nav
