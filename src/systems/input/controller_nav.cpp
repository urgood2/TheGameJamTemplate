#include "controller_nav.hpp"
#include "spdlog/spdlog.h"
#include "systems/entity_gamestate_management/entity_gamestate_management.hpp"
#include "systems/input/input_functions.hpp"
#include "systems/main_loop_enhancement/main_loop.hpp"
#include "sol/types.hpp"

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
    assert(!layerStack.empty() && "pop_layer() called on empty stack");

    if (layerStack.empty()) return;
    layerStack.pop_back();
    if (!layerStack.empty())
        set_active_layer(layerStack.back());
    else
        activeLayer.clear();
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
}

void NavManager::remove_entity(const std::string& group, entt::entity e) {
    if (!groups.contains(group)) return;
    auto& v = groups[group].entries;
    v.erase(std::remove(v.begin(), v.end(), e), v.end());
}

void NavManager::clear_group(const std::string& group) {
    if (groups.contains(group)) groups[group].entries.clear();
}

void NavManager::set_active(const std::string& group, bool active) {
    if (groups.contains(group)) groups[group].active = active;
}

entt::entity NavManager::get_selected(const std::string& group) {
    if (!groups.contains(group)) return entt::null;
    auto& g = groups[group];
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


// -----------------------------------------------------------------------------
// Controller-driven navigation
// -----------------------------------------------------------------------------
void NavManager::navigate(entt::registry& reg, input::InputState& state, const std::string& group, std::string_view dir)
{
    assert(!group.empty() && "controller_nav::navigate called with empty group name");
    assert(!dir.empty() && "controller_nav::navigate called with empty direction");

    float& timer = groupCooldowns[group];
    if (timer > 0.0f)
        return; // still cooling down

    // Reset to ensure cooldown activates even if delta > cooldown
    groupCooldowns[group] = globalCooldown;


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
    !entity_gamestate_management::isEntityActive(state.cursor_focused_target))
    {
        // Try to find next available entry
        auto& entries = g.entries;
        auto it = std::find(entries.begin(), entries.end(), state.cursor_focused_target);
        if (it != entries.end()) {
            auto nextIt = std::next(it);
            while (nextIt != entries.end() && 
                (!reg.valid(*nextIt) || !entity_gamestate_management::isEntityActive(*nextIt)))
                ++nextIt;
            if (nextIt != entries.end())
                state.cursor_focused_target = *nextIt;
            else
                state.cursor_focused_target = entt::null;
        }
    }

    //---------------------------------------------------------------------
    // SPATIAL MODE (reference-based directional focus)
    //---------------------------------------------------------------------
    if (g.spatial)
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
                if (reg.valid(e) && entity_gamestate_management::isEntityActive(e) && is_entity_enabled(e))
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
            if (!entity_gamestate_management::isEntityActive(e)) continue;
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
                if (!entity_gamestate_management::isEntityActive(e)) continue;
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
            if (reg.valid(e) && entity_gamestate_management::isEntityActive(e) && is_entity_enabled(e))
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
        } else {
            nextIndex = std::clamp(nextIndex, 0, (int)activeEntries.size() - 1);
        }

        g.selectedIndex = nextIndex;
        nextEntity = activeEntries[nextIndex];
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
                    // Case 3: illegal jump (skipping layers)
                    SPDLOG_ERROR("[ControllerNav] Invalid layer transition: trying to skip multiple layers "
                                "(from {} -> {})", currentLayerName, targetLayerName);
                    assert(false && "Invalid multi-layer downward transition in controller_nav");
                    return;
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
    
    assert(!reg.valid(nextEntity) || reg.all_of<transform::Transform>(nextEntity) && "controller_nav: focused entity lacks Transform component");

    notify_focus(prev, nextEntity, reg);
    input::UpdateCursor(state, reg);
}

void NavManager::select_current(entt::registry& reg, const std::string& group) {
    if (!groups.contains(group)) return;
    entt::entity e = get_selected(group);
    if (reg.valid(e))
        notify_select(e, reg);
}

// -----------------------------------------------------------------------------
// Update per-frame
// -----------------------------------------------------------------------------
void NavManager::update(float dt) {
    for (auto& [name, t] : groupCooldowns)
        if (t > 0.0f) t -= dt;
}

// -----------------------------------------------------------------------------
// Validation
// -----------------------------------------------------------------------------
void NavManager::validate() const {
    for (auto& [lname, layer] : layers) {
        for (auto& gname : layer.groups) {
            if (!groups.contains(gname))
                SPDLOG_ERROR("[Nav] Layer '{}' references missing group '{}'", lname, gname);
        }
    }
}

// -----------------------------------------------------------------------------
// Stack / Focus group handling
// -----------------------------------------------------------------------------
void NavManager::push_focus_group(const std::string& group) { layerStack.push_back(group); }
void NavManager::pop_focus_group() { if (!layerStack.empty()) layerStack.pop_back(); }
std::string NavManager::current_focus_group() const {
    return layerStack.empty() ? "" : layerStack.back();
}

// -----------------------------------------------------------------------------
// Lua Hooks
// -----------------------------------------------------------------------------

void NavManager::notify_focus(entt::entity prev, entt::entity next, entt::registry& reg) {
    // global
    auto& globalCB = callbacks;
    // find per-group callbacks
    std::optional<NavCallbacks*> groupCB;
    for (auto& [name, g] : groups) {
        if (std::find(g.entries.begin(), g.entries.end(), next) != g.entries.end()) {
            groupCB = &g.callbacks;
            break;
        }
    }

    auto fire = [&](sol::protected_function fn, entt::entity e, const char* label){
        if (fn.valid()) {
            auto r = fn(e);
            if (!r.valid()) {
                sol::error err = r;
                SPDLOG_ERROR("[Lua] {} error: {}", label, err.what());
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
    for (auto& [name, g] : groups) {
        if (std::find(g.entries.begin(), g.entries.end(), selected) != g.entries.end()) {
            if (g.callbacks.on_select.valid()) {
                auto r = g.callbacks.on_select(selected);
                if (!r.valid()) SPDLOG_ERROR("[Lua] on_nav_select error (group)");
                return;
            }
        }
    }
    if (globalCB.on_select.valid()) {
        auto r = globalCB.on_select(selected);
        if (!r.valid()) SPDLOG_ERROR("[Lua] on_nav_select error (global)");
    }
}

void NavManager::debug_print_state() const {
    SPDLOG_DEBUG("[Nav] Active layer: {}", activeLayer.empty() ? "none" : activeLayer);
    for (auto& [name, g] : groups)
        SPDLOG_DEBUG("  Group: {} ({} entries, active: {}, selected: {})",
                     name, g.entries.size(), g.active, g.selectedIndex);
}

void NavManager::reset() {
    for (auto& [name, g] : groups) {
        g.callbacks.on_focus = sol::lua_nil_t{};
        g.callbacks.on_unfocus = sol::lua_nil_t{};
        g.callbacks.on_select = sol::lua_nil_t{};
    }
    groups.clear();
    layers.clear();
    layerStack.clear();
    activeLayer.clear();
    disabledEntities.clear();
    groupToLayer.clear();
    groupCooldowns.clear();
}

void exposeToLua(sol::state& lua) {
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

        // Navigation
        "navigate", [](NavManager* self, const string& group, const string& dir) {
            auto& reg = globals::registry;
            auto& state = globals::inputState;
            self->navigate(reg, state, group, dir);
        },
        "select_current", [](NavManager* self, const string& group) {
            auto& reg = globals::registry;
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
        {"validate", "", ""});
    rec.record_property("NavManagerUD",
        {"debug_print_state", "", ""});
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
        {"current_focus_group", "", "---@return string"});

    // -------------------------------------------------------------------------
    // Global table controller_nav
    // -------------------------------------------------------------------------
    sol::table nav = lua["controller_nav"].get_or_create<sol::table>();
    rec.add_type("controller_nav").doc =
        "Controller navigation system entry point.\n"
        "Manages layers, groups, and spatial/linear focus movement for UI and in-game entities.";

    nav["ud"] = &NM; // expose userdata handle

    // convenience wrappers
    nav.set_function("create_group",        [&](const string& n){ NM.create_group(n); });
    nav.set_function("create_layer",        [&](const string& n){ NM.create_layer(n); });
    nav.set_function("add_group_to_layer",  [&](const string& l, const string& g){ NM.add_group_to_layer(l, g); });
    nav.set_function("navigate",            [&](const string& g, const string& d){ 
        NM.navigate(globals::registry, globals::inputState, g, d);
    });
    nav.set_function("select_current",      [&](const string& g){ NM.select_current(globals::registry, g); });
    nav.set_function("set_entity_enabled",  [&](entt::entity e, bool enabled){ NM.set_entity_enabled(e, enabled); });
    nav.set_function("debug_print_state",   [&]{ NM.debug_print_state(); });
    nav.set_function("validate",            [&]{ NM.validate(); });
    nav.set_function("current_focus_group", [&]{ return NM.current_focus_group(); });

    rec.record_free_function({"controller_nav"},
        {"create_group", "---@param name string", "Create a navigation group.", true, false});
    rec.record_free_function({"controller_nav"},
        {"create_layer", "---@param name string", "Create a navigation layer.", true, false});
    rec.record_free_function({"controller_nav"},
        {"add_group_to_layer", "---@param layer string\n---@param group string",
            "Attach an existing group to a layer.", true, false});
    rec.record_free_function({"controller_nav"},
        {"navigate", "---@param group string\n---@param dir 'L'|'R'|'U'|'D'",
            "Navigate within or across groups.", true, false});
    rec.record_free_function({"controller_nav"},
        {"select_current", "---@param group string",
            "Trigger the select callback for the currently focused entity.", true, false});
    rec.record_free_function({"controller_nav"},
        {"set_entity_enabled", "---@param e entt.entity\n---@param enabled boolean",
            "Enable or disable a specific entity for navigation.", true, false});
    rec.record_free_function({"controller_nav"},
        {"debug_print_state", "", "Print debug info on groups/layers.", true, false});
    rec.record_free_function({"controller_nav"},
        {"validate", "", "Validate layer/group configuration.", true, false});
    rec.record_free_function({"controller_nav"},
        {"current_focus_group", "---@return string", "Return the currently focused group.", true, false});
        
    nav.set_function("set_group_callbacks", [&](const std::string& group, sol::table tbl) {
        auto& mgr = controller_nav::NavManager::instance();
        if (!mgr.groups.contains(group)) return;
        auto& g = mgr.groups[group];
        if (tbl["on_focus"].valid())   g.callbacks.on_focus   = tbl["on_focus"];
        if (tbl["on_unfocus"].valid()) g.callbacks.on_unfocus = tbl["on_unfocus"];
        if (tbl["on_select"].valid())  g.callbacks.on_select  = tbl["on_select"];
    });
    rec.record_free_function({"controller_nav"},
        {"set_group_callbacks",
        "---@param group string\n---@param tbl table {on_focus:function|nil, on_unfocus:function|nil, on_select:function|nil}",
        "Set Lua callbacks for a specific navigation group.", true, false});
        
    nav.set_function("link_groups", [&](const std::string& from, sol::table dirs) {
        auto& mgr = controller_nav::NavManager::instance();
        if (!mgr.groups.contains(from)) return;
        auto& g = mgr.groups[from];
        if (dirs["up"].valid())    g.upGroup    = dirs["up"];
        if (dirs["down"].valid())  g.downGroup  = dirs["down"];
        if (dirs["left"].valid())  g.leftGroup  = dirs["left"];
        if (dirs["right"].valid()) g.rightGroup = dirs["right"];
    });
    rec.record_free_function({"controller_nav"},
        {"link_groups",
        "---@param from string\n---@param dirs table {up:string|nil, down:string|nil, left:string|nil, right:string|nil}",
        "Link a group's navigation directions to other groups.", true, false});
        
    nav.set_function("set_group_mode", [&](const std::string& group, const std::string& mode) {
        auto& mgr = controller_nav::NavManager::instance();
        if (!mgr.groups.contains(group)) return;
        mgr.groups[group].spatial = (mode == "spatial");
    });
    rec.record_free_function({"controller_nav"},
        {"set_group_mode",
        "---@param group string\n---@param mode 'spatial'|'linear'", "Toggle navigation mode for the group.", true, false});
        
    nav.set_function("set_wrap", [&](const std::string& group, bool wrap) {
        auto& mgr = controller_nav::NavManager::instance();
        if (!mgr.groups.contains(group)) return;
        mgr.groups[group].wrap = wrap;
    });
    rec.record_free_function({"controller_nav"},
        {"set_wrap", "---@param group string\n---@param wrap boolean", "Enable or disable wrap-around navigation.", true, false});
        
    nav.set_function("focus_entity", [&](entt::entity e) { globals::inputState.cursor_focused_target = e; }); rec.record_free_function({"controller_nav"}, {"focus_entity", "---@param e entt.entity", "Force cursor focus to a specific entity. Note that this does not affect the navigation state, and may be overridden on next navigation action.", true, false});
        
        



}


} // namespace controller_nav



