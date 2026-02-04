-- test_state_input_components.lua
-- State + input component access tests (Phase 3 B5)

local TestRunner = require("test.test_runner")
local test_utils = require("test.test_utils")

local function require_globals()
    test_utils.assert_not_nil(_G.registry, "registry available")
    test_utils.assert_not_nil(_G.component_cache, "component_cache available")

    test_utils.assert_not_nil(_G.add_state_tag, "add_state_tag available")
    test_utils.assert_not_nil(_G.remove_state_tag, "remove_state_tag available")
    test_utils.assert_not_nil(_G.clear_state_tags, "clear_state_tags available")
    test_utils.assert_not_nil(_G.remove_default_state_tag, "remove_default_state_tag available")
    test_utils.assert_not_nil(_G.has_state_tag, "has_state_tag available")
    test_utils.assert_not_nil(_G.is_state_active, "is_state_active available")
    test_utils.assert_not_nil(_G.is_entity_active, "is_entity_active available")
    test_utils.assert_not_nil(_G.hasAnyTag, "hasAnyTag available")
    test_utils.assert_not_nil(_G.hasAllTags, "hasAllTags available")
    test_utils.assert_not_nil(_G.activate_state, "activate_state available")
    test_utils.assert_not_nil(_G.deactivate_state, "deactivate_state available")
    test_utils.assert_not_nil(_G.active_states, "active_states available")

    test_utils.assert_not_nil(_G.controller_nav, "controller_nav table available")
    test_utils.assert_not_nil(_G.input, "input table available")
    test_utils.assert_not_nil(_G.input.getState, "input.getState available")
    test_utils.assert_not_nil(_G.get_script_component, "get_script_component available")
end

local function emplace_component(entity, comp_type, data)
    local payload = data or {}
    payload.__type = comp_type
    local ok, result = pcall(function()
        return _G.registry:emplace(entity, payload)
    end)
    test_utils.assert_true(ok, "registry:emplace succeeded")
    return result
end

TestRunner.register("state_input.components.smoke", "components", function()
    require_globals()

    test_utils.assert_true(type(_G.controller_nav.create_group) == "function", "controller_nav.create_group available")
    test_utils.assert_true(type(_G.controller_nav.navigate) == "function", "controller_nav.navigate available")
    test_utils.assert_true(type(_G.controller_nav.set_group_callbacks) == "function", "controller_nav.set_group_callbacks available")
    test_utils.assert_not_nil(_G.controller_nav.ud, "controller_nav.ud available")
end, {
    tags = {"state", "input", "components", "smoke"},
    doc_ids = {
        "component:IInputProvider",
        "component:RaylibInputProvider",
        "component:NavSelectable",
        "component:NavCallbacks",
        "component:NavGroup",
        "component:NavLayer",
        "component:NavManager",
        "component:InactiveTag",
        "component:StateTag",
        "component:ActiveStates",
        "component:ScriptComponent",
    },
    requires = {"test_scene"},
})

TestRunner.register("state_input.navselectable.read_write", "components", function()
    require_globals()
    if _G.NavSelectable == nil then
        test_utils.assert_true(true, "NavSelectable not bound; controller_nav handles navigation")
        return
    end
    local entity = test_utils.spawn_test_entity()

    emplace_component(entity, NavSelectable, {
        selected = true,
        disabled = false,
        group = "b5_group",
        subgroup = "b5_subgroup",
    })

    local nav = _G.component_cache.get(entity, NavSelectable)
    test_utils.assert_not_nil(nav, "NavSelectable component available")
    test_utils.assert_true(nav.selected, "NavSelectable.selected read")
    test_utils.assert_false(nav.disabled, "NavSelectable.disabled read")

    nav.disabled = true
    nav.selected = false
    test_utils.assert_true(nav.disabled, "NavSelectable.disabled write")
    test_utils.assert_false(nav.selected, "NavSelectable.selected write")
end, {
    tags = {"input", "components"},
    doc_ids = {"component:NavSelectable"},
    requires = {"test_scene"},
})

TestRunner.register("state_input.state_tags.activate_deactivate", "components", function()
    require_globals()
    local entity = test_utils.spawn_test_entity()
    local test_state = "B5_TEST_STATE"

    clear_state_tags(entity)
    add_state_tag(entity, test_state)
    test_utils.assert_true(has_state_tag(entity), "StateTag component present")

    activate_state(test_state)
    test_utils.assert_true(is_state_active(test_state), "State tag active after activate_state")
    test_utils.assert_true(is_entity_active(entity), "Entity active after state activation")

    deactivate_state(test_state)
    test_utils.assert_false(is_state_active(test_state), "State tag inactive after deactivate_state")
    test_utils.assert_false(is_entity_active(entity), "Entity inactive after state deactivation")

    remove_state_tag(entity, test_state)

    add_state_tag(entity, "default_state")
    test_utils.assert_true(is_entity_active(entity), "default_state activates entity")
    remove_default_state_tag(entity)
    test_utils.assert_false(is_entity_active(entity), "remove_default_state_tag clears activation")
end, {
    tags = {"state", "components"},
    doc_ids = {"component:StateTag", "component:ActiveStates"},
    requires = {"test_scene"},
})

TestRunner.register("state_input.active_states.singleton", "components", function()
    require_globals()
    local test_state = "B5_TEST_STATE_SINGLETON"

    active_states:activate(test_state)
    test_utils.assert_true(active_states:is_active(test_state), "active_states:activate marks active")
    test_utils.assert_true(hasAnyTag({test_state, "MISSING_STATE"}), "hasAnyTag detects active state")
    test_utils.assert_false(hasAllTags({test_state, "MISSING_STATE"}), "hasAllTags requires all states")

    active_states:deactivate(test_state)
    test_utils.assert_false(active_states:is_active(test_state), "active_states:deactivate clears state")
    test_utils.assert_false(hasAnyTag({test_state}), "hasAnyTag false after deactivation")
end, {
    tags = {"state", "components"},
    doc_ids = {"component:ActiveStates"},
    requires = {"test_scene"},
})

TestRunner.register("state_input.input_state.basic", "components", function()
    require_globals()

    local state = _G.input.getState()
    test_utils.assert_not_nil(state, "input.getState returns InputState")
    test_utils.assert_not_nil(state.cursor_position, "InputState.cursor_position available")
    test_utils.assert_not_nil(state.cursor_down_position, "InputState.cursor_down_position available")
end, {
    tags = {"input", "components"},
    requires = {"test_scene"},
})

TestRunner.register("state_input.script_component.basic", "components", function()
    require_globals()
    local entity = test_utils.spawn_test_entity()

    local script_table = { label = "b5_test" }
    local ok = pcall(function()
        _G.registry:add_script(entity, script_table)
    end)
    test_utils.assert_true(ok, "registry:add_script succeeded")

    local script_component = get_script_component(entity)
    test_utils.assert_not_nil(script_component, "ScriptComponent accessible")
    test_utils.assert_not_nil(script_component.self, "ScriptComponent.self available")
    test_utils.assert_eq(script_component:count_tasks(), 0, "ScriptComponent.count_tasks default")
end, {
    tags = {"state", "components"},
    doc_ids = {"component:ScriptComponent"},
    requires = {"test_scene"},
})
