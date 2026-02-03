# State + Input Components (Draft)

Scope: Draft aggregation of input and state components; generated while B5 files locked.

Key considerations:
- StateTag and ActiveStates live in entity_gamestate_management.hpp and track active state hashes.
- Input navigation components live in controller_nav.hpp.
- ScriptComponent is manual draft from scripting_system.hpp; verify Lua access before mutation.

## IInputProvider
**doc_id:** `component:IInputProvider`
**Location:** `src/systems/input/input_polling.hpp:20`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## RaylibInputProvider
**doc_id:** `component:RaylibInputProvider`
**Location:** `src/systems/input/input_polling.hpp:50`
**Lua Access:** `TBD (verify in bindings)`

**Fields:** None

## NavSelectable
**doc_id:** `component:NavSelectable`
**Location:** `src/systems/input/controller_nav.hpp:21`
**Lua Access:** `TBD (verify in bindings)`

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
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| on_focus | sol::protected_function | None |  |
| on_unfocus | sol::protected_function | None |  |
| on_select | sol::protected_function | None |  |

## NavGroup
**doc_id:** `component:NavGroup`
**Location:** `src/systems/input/controller_nav.hpp:40`
**Lua Access:** `TBD (verify in bindings)`
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
| pushOnEnter | bool | false |  |
| popOnExit | bool | false |  |

## NavLayer
**doc_id:** `component:NavLayer`
**Location:** `src/systems/input/controller_nav.hpp:60`
**Lua Access:** `TBD (verify in bindings)`
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
**Lua Access:** `TBD (verify in bindings)`
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

## StateTag
**doc_id:** `component:StateTag`
**Location:** `src/systems/entity_gamestate_management/entity_gamestate_management.hpp:26`
**Lua Access:** `TBD (verify in bindings)`
**Notes:** 2 complex types need manual review

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| names | std::vector<std::string> | None | complex |
| hashes | std::vector<std::size_t> | None | complex |

## ActiveStates
**doc_id:** `component:ActiveStates`
**Location:** `src/systems/entity_gamestate_management/entity_gamestate_management.hpp:39`
**Lua Access:** `TBD (verify in bindings)`

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| active_hashes | std::unordered_set<std::size_t> | None |  |

## ScriptComponent
**doc_id:** `component:ScriptComponent`
**Location:** `src/systems/scripting/scripting_system.hpp:31`
**Lua Access:** `TBD (verify in bindings)`
**Notes:** manual draft: scripting_system.hpp; hooks include update/on_collision

**Fields:**

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| self | sol::table | None | complex |
| hooks | struct { update, on_collision } | None | complex |
| tasks | std::vector<sol::coroutine> | None | complex |
