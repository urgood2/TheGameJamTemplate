# GOAP Debug Window - Environment Validation

## Validation Results

### 1. F9 Key Availability: ✅ YES - AVAILABLE

**Status:** F9 is **NOT currently bound** to any function in the application.

**Evidence:**
- `src/main.cpp:269-332`: F-key handlers exist for F3, F7, F8, F10 only
  - F3 (line 270): toggles performance overlay
  - F7 (line 276): toggles hot-path analyzer  
  - F8 (line 303): prints ECS dashboard
  - F10 (line 316): manual crash report capture
  - **F9 is conspicuously absent** from this block

- `src/systems/input/input_lua_bindings.cpp:248, 620`: F9 is **exposed to Lua bindings** as `KEY_F9`
- `src/third_party/rlImGui/rlImGui.cpp:401`: F9 mapping exists for ImGui: `RaylibKeyMap[KEY_F9] = ImGuiKey_F9`

**Conclusion:** F9 can be safely bound without conflicts.

---

### 2. Entity Iteration Capability: ✅ YES - AVAILABLE

**Pattern:** `globals::getRegistry().view<GOAPComponent>()`

**Evidence:**
- `src/systems/ai/ai_system.cpp:578, 640, 1476`: Three confirmed usages of registry view pattern
  - Line 578: `auto view = globals::getRegistry().view<GOAPComponent>();`
  - Line 640: `auto view = globals::getRegistry().view<GOAPComponent>();`
  - Line 1476: `auto view = registry.view<GOAPComponent>();`

**Usage Pattern:**
```cpp
auto view = globals::getRegistry().view<GOAPComponent>();
for (auto entity : view) {
    auto& goap = view.get<GOAPComponent>(entity);
    // Process entity...
}
```

**Conclusion:** Full EnTT entity iteration is available and actively used in codebase.

---

### 3. ImGui TabBar Availability: ✅ YES - AVAILABLE

**Status:** `ImGui::BeginTabBar()` and `ImGui::EndTabBar()` are fully available.

**Evidence:**
- `src/third_party/rlImGui/imgui.h:837-838`: API declarations
  - `IMGUI_API bool BeginTabBar(const char* str_id, ImGuiTabBarFlags flags = 0);`
  - `IMGUI_API void EndTabBar();`

- `src/third_party/rlImGui/imgui_widgets.cpp:7938, 8016`: Implementations exist
- `src/third_party/rlImGui/imgui_demo.cpp`: Multiple usage examples (lines 1708, 1725, 1761, 1771, etc.)

**Conclusion:** Modern ImGui TabBar API is available in project's ImGui version.

---

### 4. Atom Name Registry Access: ✅ YES - ACCESSIBLE AT RUNTIME

**Status:** Atom names are accessible via `actionplanner_t::atm_names` array.

**Pattern:** Access atom names from `actionplanner_t` structure

**Evidence:**
- `src/systems/ai/ai_system.cpp:1375-1397` - Function `goap_worldstate_to_map()`:
  - Accesses `ap->atm_names[i]` for all atoms in world state
  - Loop pattern: `for (int i = 0; i < MAXATOMS; ++i)`
  - Checks `ap->atm_names[i]` for null before using

- `src/systems/ai/ai_system.cpp:192-207` - Function `goap_worldstate_get()`:
  - Iterates through atoms: `for (int i = 0; i < ap->numatoms; ++i)`
  - Compares: `strcmp(ap->atm_names[i], atomname) == 0`

- `src/systems/ai/goap_utils.hpp:15`: Additional pattern
  - Usage: `if (ap.atm_names[i] && nm == ap.atm_names[i])`

**Access from GOAPComponent:**
```cpp
GOAPComponent& goap = registry.get<GOAPComponent>(entity);
actionplanner_t& ap = goap.ap;
const char* atomName = ap.atm_names[i];  // Access atom names
int numAtoms = ap.numatoms;               // Get atom count
```

**Conclusion:** Atom names are fully accessible via GOAPComponent::ap structure at runtime.

---

## Summary Table

| Requirement | Status | File Reference | Notes |
|-------------|--------|-----------------|-------|
| F9 Free | ✅ YES | src/main.cpp:269-332 | F3, F7, F8, F10 bound; F9 available |
| Entity Iteration | ✅ YES | src/systems/ai/ai_system.cpp:578 | `registry.view<GOAPComponent>()` pattern |
| ImGui TabBar | ✅ YES | src/third_party/rlImGui/imgui.h:837-838 | Both BeginTabBar/EndTabBar available |
| Atom Names | ✅ YES | src/systems/ai/ai_system.cpp:1384 | Via `ap->atm_names[i]` array |

---

## Next Steps (Not in this task)

1. Bind F9 handler in `src/main.cpp` (around line 315)
2. Create ImGui window with TabBar for:
   - World State (current atoms and values)
   - Action Queue (pending actions)
   - Plan History (recently executed plans)
3. Iterate GOAPComponent entities and display debug info per entity
4. Show atom names with their boolean states using `goap_worldstate_to_map()`

All prerequisites validated. Ready for implementation.

## Task 2: AI Utility Bindings Implementation

### Implementation Summary
Added 5 new utility bindings to `src/systems/ai/ai_system.cpp:bind_ai_utilities()`:
1. `ai.dump_worldstate(entity)` - Returns table of `{atom_name = bool_value}`
2. `ai.dump_plan(entity)` - Returns 1-based array of action names
3. `ai.get_all_atoms(entity)` - Returns 1-based array of all registered atom names
4. `ai.has_plan(entity)` - Returns bool (`planSize > 0 && !dirty`)
5. `ai.dump_blackboard(entity)` - Returns table with type-aware value extraction

### Key Patterns Learned

#### Entity Validation Pattern
```cpp
if (!registry.valid(e) || !registry.all_of<GOAPComponent>(e)) {
    return sol::make_object(L, sol::lua_nil);
}
```
- Used consistently across all new bindings
- Returns `nil` for invalid entities (matches existing API)
- Note: `nil` entity still causes Sol2 type error (consistent with existing behavior)

#### Lua 1-Based Indexing Conversion
```cpp
for (int i = 0; i < goap.planSize; ++i) {
    result[i + 1] = goap.plan[i]; // Lua uses 1-based indexing
}
```
- Critical for `dump_plan` and `get_all_atoms`
- C++ loops use 0-based indexing, Lua tables use 1-based

#### Type Detection via std::any_cast
```cpp
try {
    bool val = goap.blackboard.get<bool>(key);
    entry["type"] = "bool";
    entry["value"] = val;
    result[key] = entry;
    continue;
} catch (const std::bad_any_cast&) {}
```
- Try-cast chain for: bool, int, double, float, string
- Fallback to `{type="unknown", value="<unsupported>"}` for unhandled types
- Important: Use `continue` after successful cast to avoid double-insertion

#### Blackboard getKeys() Addition
Added to `src/systems/ai/blackboard.hpp`:
```cpp
std::vector<std::string> getKeys() const {
    std::vector<std::string> keys;
    keys.reserve(data_.size());
    for (const auto& [key, _] : data_) {
        keys.push_back(key);
    }
    return keys;
}
```
- Required `#include <vector>` addition
- Uses structured binding for iteration
- Reserve optimization for performance

#### BindingRecorder Pattern
```cpp
rec.record_method("ai", {"dump_worldstate",
                         "---@param e Entity\n"
                         "---@return table<string,boolean>|nil",
                         "Returns a table of all worldstate atoms..."});
```
- All 5 functions registered with BindingRecorder
- LuaLS annotations for type checking
- Consistent documentation style

### Compilation Notes
- Build succeeded: `cmake --build build -j`
- Binary size: 208MB (Debug build)
- Only warnings from Tracy third-party code (deprecated `sprintf`)
- LSP shows false positives for templates/forward declarations (ignore)

### Files Modified
1. `src/systems/ai/blackboard.hpp` - Added `getKeys()` method + `<vector>` include
2. `src/systems/ai/ai_system.cpp` - Added 5 bindings in `bind_ai_utilities()`

### Next Steps Considerations
- These bindings enable comprehensive GOAP inspection from Lua
- Useful for debugging AI behavior and building test assertions
- `dump_blackboard` type detection limited to 5 types (bool/int/double/float/string)
- Consider adding entity type support if needed in future

