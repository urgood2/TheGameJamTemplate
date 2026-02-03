# State + Input Components (Draft)

Scope: Draft aggregation of input and state components; generated while B5 files locked.

Key considerations:
- StateTag/ActiveStates/InactiveTag live in entity_gamestate_management.hpp and drive active/inactive filtering; Lua functions wrap tag mutation and global state.
- Input navigation components live in controller_nav.hpp; Lua access is via the global `controller_nav` table (NavManagerUD), not direct component access.
- ScriptComponent is bound in scripting_system.cpp and is initialized/released via init_script/release_script hooks.

## IInputProvider
**doc_id:** `component:IInputProvider`
**Location:** `src/systems/input/input_polling.hpp:20`
**Lua Access:** None (C++ tag marker)

**Fields:** None

## RaylibInputProvider
**doc_id:** `component:RaylibInputProvider`
**Location:** `src/systems/input/input_polling.hpp:50`
**Lua Access:** None (C++ tag marker)

**Fields:** None

## NavSelectable
**doc_id:** `component:NavSelectable`
**Location:** `src/systems/input/controller_nav.hpp:21`
**Lua Access:** Indirect (component used by controller_nav; no direct Lua binding)

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| selected | bool | false |  |
| disabled | bool | false |  |
| group | std::string | None |  |
| subgroup | std::string | None |  |

## NavCallbacks
**doc_id:** `component:NavCallbacks`
**Location:** `src/systems/input/controller_nav.hpp:31`
**Lua Access:** Indirect via `controller_nav.set_group_callbacks(group, tbl)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| on_focus | sol::protected_function | None |  |
| on_unfocus | sol::protected_function | None |  |
| on_select | sol::protected_function | None |  |

## NavGroup
**doc_id:** `component:NavGroup`
**Location:** `src/systems/input/controller_nav.hpp:40`
**Lua Access:** Indirect via controller_nav helpers (`create_group`, `link_groups`, `set_group_mode`, `set_wrap`)
**Notes:** 1 complex types need manual review

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| name | std::string | None |  |
| active | bool | true |  |
| linear | bool | true |  |
| entries | std::vector<entt::entity> | None | complex |
| selectedIndex | int | -1 |  |
| spatial | bool | true |  |
| wrap | bool | true |  |
| callbacks | NavCallbacks | None |  |
| parent | std::string | None |  |
| upGroup | std::string | None |  |
| downGroup | std::string | None |  |
| leftGroup | std::string | None |  |
| rightGroup | std::string | None |  |
| pushOnEnter | bool | false |  |
| popOnExit | bool | false |  |

## NavLayer
**doc_id:** `component:NavLayer`
**Location:** `src/systems/input/controller_nav.hpp:60`
**Lua Access:** Indirect via controller_nav layer helpers (`create_layer`, `add_group_to_layer`, `set_active_layer`, `push_layer`, `pop_layer`)
**Notes:** 1 complex types need manual review

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| name | std::string | None |  |
| groups | std::vector<std::string> | None | complex |
| active | bool | false |  |
| focusGroupIndex | int | 0 |  |

## NavManager
**doc_id:** `component:NavManager`
**Location:** `src/systems/input/controller_nav.hpp:70`
**Lua Access:** `controller_nav` global table and `controller_nav.ud` (NavManagerUD userdata)
**Notes:** 5 complex types need manual review

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| groups | std::unordered_map<std::string, NavGroup> | None | complex |
| layers | std::unordered_map<std::string, NavLayer> | None | complex |
| layerStack | std::vector<std::string> | None | complex |
| activeLayer | std::string | None |  |
| disabledEntities | std::unordered_set<entt::entity> | None |  |
| groupToLayer | std::unordered_map<std::string, std::string> | None | complex |
| callbacks | NavCallbacks | None |  |
| groupCooldowns | std::unordered_map<std::string, float> | None | complex |
| globalCooldown | float | 0.08f |  |

## InactiveTag
**doc_id:** `component:InactiveTag`
**Location:** `src/systems/entity_gamestate_management/entity_gamestate_management.hpp:15`
**Lua Access:** None (auto-managed when state tags are inactive)

**Fields:** None

## StateTag
**doc_id:** `component:StateTag`
**Location:** `src/systems/entity_gamestate_management/entity_gamestate_management.hpp:26`
**Lua Access:** `add_state_tag`, `remove_state_tag`, `clear_state_tags`, `remove_default_state_tag`, `has_state_tag`, `is_state_active`, `is_entity_active`, `hasAnyTag`, `hasAllTags`
**Notes:** 2 complex types need manual review

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| names | std::vector<std::string> | None | complex |
| hashes | std::vector<std::size_t> | None | complex |

## ActiveStates
**doc_id:** `component:ActiveStates`
**Location:** `src/systems/entity_gamestate_management/entity_gamestate_management.hpp:39`
**Lua Access:** `active_states` singleton + `activate_state`, `deactivate_state`, `clear_states`, `is_state_active`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| active_hashes | std::unordered_set<std::size_t> | None |  |

## ScriptComponent
**doc_id:** `component:ScriptComponent`
**Location:** `src/systems/scripting/scripting_system.hpp:31`
**Lua Access:** `registry:add_script(entity, table)`, `get_script_component(entity_id)`, ScriptComponent usertype
**Notes:** init_script caches hooks + injects `id`/`owner`; release_script runs `destroy` and clears hooks

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| self | sol::table | None | complex |
| hooks | struct { update, on_collision } | None | complex |
| tasks | std::vector<sol::coroutine> | None | complex |
