# C++ Codebase Refactoring Plan

**Date:** 2026-01-10
**Estimated Duration:** 3-4 weeks
**Methodology:** Test-Driven Development (TDD)

---

## Implementation Status

| Task | Status | Commit |
|------|--------|--------|
| 1.1: Protected Lua Callback Wrapper | DONE | b2c5509d7 |
| 1.2: [[nodiscard]]/noexcept Attributes | DONE | b2c5509d7 |
| 1.3: Replace C-Style Casts | DONE | b2c5509d7 |
| 1.4: Result<T> Convenience Macros | DONE | b2c5509d7 |
| 2.1: Split ldtk_lua_bindings.cpp | DONE | 099eb9788 |
| 2.2: InputState Facade | DEFERRED | (breaking API change) |
| 2.3: Binding Helpers | DONE | 3066919d9 |
| 2.4: Standardize Result<T> | DEFERRED | (widespread change) |
| 3.x: Architecture Tasks | DEFERRED | (major refactors) |

**Branch:** `cpp-refactoring-phase1`

---

## Overview

This plan addresses 64+ refactoring opportunities identified across the C++ codebase, organized into three phases:

| Phase | Focus | Duration | Tasks |
|-------|-------|----------|-------|
| **Phase 1** | Quick Wins | 1-2 days | 4 tasks |
| **Phase 2** | High Impact | 1 week | 4 tasks |
| **Phase 3** | Architecture | 2-3 weeks | 4 tasks |

### TDD Approach for Each Task

Every task follows RED-GREEN-REFACTOR:
1. **RED**: Write failing test that defines expected behavior
2. **GREEN**: Write minimal code to pass the test
3. **REFACTOR**: Clean up while keeping tests green

---

## Phase 1: Quick Wins (1-2 Days)

### Task 1.1: Protected Lua Callback Wrapper

**Problem:** Lua callbacks crash the engine when they throw errors.

**Files to Modify:**
- `src/systems/input/input_lua_bindings.cpp` (line 834)
- `src/systems/input/input_keyboard.cpp` (lines 45-46, 94-95)

**Files to Create:**
- `src/systems/scripting/sol2_helpers.hpp`
- `src/systems/scripting/tests/sol2_helpers_test.cpp`

#### TDD Steps

**RED - Write Failing Test First:**
```cpp
// src/systems/scripting/tests/sol2_helpers_test.cpp
#include <catch2/catch_test_macros.hpp>
#include "systems/scripting/sol2_helpers.hpp"

TEST_CASE("safe_lua_call handles throwing Lua functions", "[sol2_helpers]") {
    sol::state lua;
    lua.open_libraries(sol::lib::base);

    // Create a function that throws
    lua.script("function bad_callback() error('intentional error') end");
    sol::function bad_fn = lua["bad_callback"];

    // Should NOT crash, should return false
    bool result = sol2_util::safe_call(bad_fn, "test_context");
    REQUIRE(result == false);
}

TEST_CASE("safe_lua_call succeeds with valid functions", "[sol2_helpers]") {
    sol::state lua;
    lua.open_libraries(sol::lib::base);

    lua.script("function good_callback() return 42 end");
    sol::function good_fn = lua["good_callback"];

    auto result = sol2_util::safe_call_with_result<int>(good_fn, "test_context");
    REQUIRE(result.has_value());
    REQUIRE(result.value() == 42);
}

TEST_CASE("safe_lua_call logs errors with context", "[sol2_helpers]") {
    // Test that error logging includes the context string
    // (Mock spdlog or check log output)
}
```

**GREEN - Implement Minimal Solution:**
```cpp
// src/systems/scripting/sol2_helpers.hpp
#pragma once
#include "sol/sol.hpp"
#include <spdlog/spdlog.h>
#include <optional>
#include <string>

namespace sol2_util {

// Safe call that returns bool success
template<typename... Args>
inline bool safe_call(sol::function fn, const char* context, Args&&... args) {
    if (!fn.valid()) {
        SPDLOG_WARN("[Lua] {}: Function is invalid", context);
        return false;
    }

    sol::protected_function pf(fn);
    auto result = pf(std::forward<Args>(args)...);

    if (!result.valid()) {
        sol::error err = result;
        SPDLOG_ERROR("[Lua Error] {}: {}", context, err.what());
        return false;
    }
    return true;
}

// Safe call that returns optional result
template<typename R, typename... Args>
inline std::optional<R> safe_call_with_result(sol::function fn, const char* context, Args&&... args) {
    if (!fn.valid()) {
        SPDLOG_WARN("[Lua] {}: Function is invalid", context);
        return std::nullopt;
    }

    sol::protected_function pf(fn);
    auto result = pf(std::forward<Args>(args)...);

    if (!result.valid()) {
        sol::error err = result;
        SPDLOG_ERROR("[Lua Error] {}: {}", context, err.what());
        return std::nullopt;
    }
    return result.get<R>();
}

// Wrap a sol::function for repeated safe calls
template<typename R, typename... Args>
inline std::function<std::optional<R>(Args...)> wrap_safe(sol::function fn, std::string context) {
    return [fn = std::move(fn), ctx = std::move(context)](Args... args) -> std::optional<R> {
        return safe_call_with_result<R>(fn, ctx.c_str(), args...);
    };
}

} // namespace sol2_util
```

**REFACTOR - Update Callsites:**
```cpp
// src/systems/input/input_lua_bindings.cpp:834
// Before:
cb(ok, out);

// After:
sol2_util::safe_call(cb, "input_rebind_callback", ok, out);
```

#### Verification
```bash
just test  # Run test suite
just build-debug && ./build/raylib-cpp-cmake-template  # Manual smoke test
```

---

### Task 1.2: Add [[nodiscard]] and noexcept Attributes

**Problem:** Query functions can have their return values silently ignored; getters can throw unexpectedly.

**Files to Modify:**
- `src/systems/ui/box.hpp` (lines 51-52)
- `src/systems/physics/physics_world.hpp`
- `src/core/init.hpp`

#### TDD Steps

**RED - Write Compile-Time Test:**
```cpp
// src/tests/attribute_compliance_test.cpp
#include <catch2/catch_test_macros.hpp>

// This test verifies that nodiscard functions produce warnings when ignored
// We can't easily test this at runtime, so we document expected compiler behavior

TEST_CASE("Query functions should be marked nodiscard", "[attributes]") {
    // If these functions are NOT marked [[nodiscard]],
    // uncommenting this code should compile without warning (BAD)
    // With [[nodiscard]], it produces a warning (GOOD)

    // Example verification (commented to avoid noise):
    // GetUIEByID(registry, "test");  // Should warn: ignoring return value

    SUCCEED();  // Placeholder - real verification is compiler warnings
}
```

**GREEN - Add Attributes:**
```cpp
// src/systems/ui/box.hpp
[[nodiscard]] extern std::optional<entt::entity> GetUIEByID(
    entt::registry& registry,
    const std::string& id
) noexcept;

[[nodiscard]] extern UIBoxComponent* GetUIBoxByID(
    entt::registry& registry,
    const std::string& id
) noexcept;

// src/systems/physics/physics_world.hpp
[[nodiscard]] static inline std::string MakeKey(
    const std::string& a,
    const std::string& b
) noexcept {
    return (a <= b) ? (a + ":" + b) : (b + ":" + a);
}
```

#### Verification
```bash
# Compile with -Werror=unused-result to catch missing nodiscard usage
cmake -DCMAKE_CXX_FLAGS="-Werror=unused-result" ..
just build-debug
```

---

### Task 1.3: Replace C-Style Casts

**Problem:** C-style casts bypass type safety and can hide bugs.

**Files to Modify:**
- `src/core/game.cpp` (lines 965, 1004)

#### TDD Steps

**RED - Document Current Behavior:**
```cpp
// src/tests/type_safety_test.cpp
TEST_CASE("Image pixel casting is type-safe", "[type_safety]") {
    // Create a test image
    Image img = GenImageColor(4, 4, RED);

    // The cast should work correctly
    Color* pixels = static_cast<Color*>(img.data);
    REQUIRE(pixels != nullptr);
    REQUIRE(pixels[0].r == RED.r);

    UnloadImage(img);
}
```

**GREEN - Replace Casts:**
```cpp
// src/core/game.cpp:965
// Before:
Color* pixels = (Color*)img.data;

// After:
Color* pixels = static_cast<Color*>(img.data);

// src/core/game.cpp:1004
// Before:
Color* pixels = (Color*)img.data;

// After:
Color* pixels = static_cast<Color*>(img.data);
```

#### Verification
```bash
just build-debug
just test
```

---

### Task 1.4: Standardize Error Handling with Result<T>

**Problem:** Three different error handling patterns cause inconsistency.

**Files to Modify:**
- Audit all void-returning functions that can fail
- Add Result<T> returns where appropriate

**Files to Create:**
- `src/util/result_macros.hpp` - Convenience macros

#### TDD Steps

**RED - Test Result Pattern Usage:**
```cpp
// src/tests/result_pattern_test.cpp
#include "util/error_handling.hpp"

TEST_CASE("Result pattern provides clear error information", "[error_handling]") {
    // Simulate a failing operation
    auto loadResult = loadResource("nonexistent.png");

    REQUIRE(loadResult.isErr());
    REQUIRE(loadResult.error().find("not found") != std::string::npos);
}

TEST_CASE("Result pattern propagates success", "[error_handling]") {
    auto result = Result<int, std::string>::ok(42);

    REQUIRE(result.isOk());
    REQUIRE(result.value() == 42);
}
```

**GREEN - Add Convenience Macros:**
```cpp
// src/util/result_macros.hpp
#pragma once
#include "error_handling.hpp"

// Early return on error
#define TRY(expr) \
    do { \
        auto _result = (expr); \
        if (_result.isErr()) return _result; \
    } while(0)

// Early return with transformation
#define TRY_OR_LOG(expr, context) \
    do { \
        auto _result = (expr); \
        if (_result.isErr()) { \
            SPDLOG_ERROR("[{}] {}", context, _result.error()); \
            return _result; \
        } \
    } while(0)

// Unwrap or return default
#define UNWRAP_OR(expr, default_val) \
    ((expr).isOk() ? (expr).value() : (default_val))
```

#### Verification
```bash
just test
grep -r "TRY\|TRY_OR_LOG" src/  # Verify adoption
```

---

## Phase 2: High Impact (1 Week)

### Task 2.1: Split ldtk_lua_bindings.cpp (Highest Complexity)

**Problem:** 878 lines, cyclomatic complexity 93, 8 levels of nesting, 18-case switch statement.

**Files to Modify:**
- `src/systems/ldtk_loader/ldtk_lua_bindings.cpp`

**Files to Create:**
- `src/systems/ldtk_loader/ldtk_field_converters.hpp`
- `src/systems/ldtk_loader/ldtk_field_converters.cpp`
- `src/systems/ldtk_loader/tests/ldtk_field_converters_test.cpp`

#### TDD Steps

**RED - Test Field Conversion Dispatch:**
```cpp
// src/systems/ldtk_loader/tests/ldtk_field_converters_test.cpp
#include <catch2/catch_test_macros.hpp>
#include "systems/ldtk_loader/ldtk_field_converters.hpp"

TEST_CASE("Int field converts to Lua number", "[ldtk_converters]") {
    sol::state lua;
    ldtk::Field field;
    field.type = ldtk::FieldType::Int;
    // ... setup field value

    sol::object result = ldtk_converters::convert(lua, field);
    REQUIRE(result.is<int>());
}

TEST_CASE("Color field converts to Lua table with r,g,b,a", "[ldtk_converters]") {
    sol::state lua;
    ldtk::Field field;
    field.type = ldtk::FieldType::Color;
    // ... setup color value

    sol::object result = ldtk_converters::convert(lua, field);
    REQUIRE(result.is<sol::table>());

    sol::table t = result;
    REQUIRE(t["r"].valid());
    REQUIRE(t["g"].valid());
    REQUIRE(t["b"].valid());
    REQUIRE(t["a"].valid());
}

TEST_CASE("Point field converts to table with x,y", "[ldtk_converters]") {
    sol::state lua;
    ldtk::Field field;
    field.type = ldtk::FieldType::Point;
    // ... setup point value

    sol::object result = ldtk_converters::convert(lua, field);
    REQUIRE(result.is<sol::table>());

    sol::table t = result;
    REQUIRE(t["x"].valid());
    REQUIRE(t["y"].valid());
}

TEST_CASE("Unknown field type returns nil", "[ldtk_converters]") {
    sol::state lua;
    ldtk::Field field;
    field.type = static_cast<ldtk::FieldType>(999);  // Invalid

    sol::object result = ldtk_converters::convert(lua, field);
    REQUIRE(result == sol::nil);
}
```

**GREEN - Implement Dispatch Table:**
```cpp
// src/systems/ldtk_loader/ldtk_field_converters.hpp
#pragma once
#include "sol/sol.hpp"
#include <ldtk.hpp>
#include <functional>
#include <unordered_map>

namespace ldtk_converters {

using Converter = std::function<sol::object(sol::state&, const ldtk::Field&)>;

// Individual converters
sol::object convertInt(sol::state& lua, const ldtk::Field& field);
sol::object convertFloat(sol::state& lua, const ldtk::Field& field);
sol::object convertBool(sol::state& lua, const ldtk::Field& field);
sol::object convertString(sol::state& lua, const ldtk::Field& field);
sol::object convertColor(sol::state& lua, const ldtk::Field& field);
sol::object convertPoint(sol::state& lua, const ldtk::Field& field);
sol::object convertEntityRef(sol::state& lua, const ldtk::Field& field);
sol::object convertFilePath(sol::state& lua, const ldtk::Field& field);
sol::object convertEnum(sol::state& lua, const ldtk::Field& field);
sol::object convertTile(sol::state& lua, const ldtk::Field& field);
sol::object convertArray(sol::state& lua, const ldtk::Field& field);

// Main dispatch function
sol::object convert(sol::state& lua, const ldtk::Field& field);

// Get dispatch table (for testing/extension)
const std::unordered_map<ldtk::FieldType, Converter>& getConverters();

} // namespace ldtk_converters
```

```cpp
// src/systems/ldtk_loader/ldtk_field_converters.cpp
#include "ldtk_field_converters.hpp"
#include <spdlog/spdlog.h>

namespace ldtk_converters {

namespace {
    // Static dispatch table - replaces 18-case switch
    const std::unordered_map<ldtk::FieldType, Converter> converters = {
        {ldtk::FieldType::Int,       convertInt},
        {ldtk::FieldType::Float,     convertFloat},
        {ldtk::FieldType::Bool,      convertBool},
        {ldtk::FieldType::String,    convertString},
        {ldtk::FieldType::Multiline, convertString},
        {ldtk::FieldType::Color,     convertColor},
        {ldtk::FieldType::Point,     convertPoint},
        {ldtk::FieldType::EntityRef, convertEntityRef},
        {ldtk::FieldType::FilePath,  convertFilePath},
        {ldtk::FieldType::Enum,      convertEnum},
        {ldtk::FieldType::Tile,      convertTile},
        // Array types
        {ldtk::FieldType::ArrayInt,       convertArray},
        {ldtk::FieldType::ArrayFloat,     convertArray},
        {ldtk::FieldType::ArrayBool,      convertArray},
        {ldtk::FieldType::ArrayString,    convertArray},
        {ldtk::FieldType::ArrayColor,     convertArray},
        {ldtk::FieldType::ArrayPoint,     convertArray},
        {ldtk::FieldType::ArrayEntityRef, convertArray},
    };
}

sol::object convert(sol::state& lua, const ldtk::Field& field) {
    auto it = converters.find(field.type);
    if (it == converters.end()) {
        SPDLOG_WARN("Unknown LDtk field type: {}", static_cast<int>(field.type));
        return sol::nil;
    }
    return it->second(lua, field);
}

sol::object convertColor(sol::state& lua, const ldtk::Field& field) {
    sol::table t = lua.create_table();
    // Extract color from field...
    t["r"] = 255;  // TODO: actual extraction
    t["g"] = 255;
    t["b"] = 255;
    t["a"] = 255;
    return t;
}

sol::object convertPoint(sol::state& lua, const ldtk::Field& field) {
    sol::table t = lua.create_table();
    // Extract point from field...
    t["x"] = 0.0f;  // TODO: actual extraction
    t["y"] = 0.0f;
    return t;
}

// ... implement other converters

const std::unordered_map<ldtk::FieldType, Converter>& getConverters() {
    return converters;
}

} // namespace ldtk_converters
```

**REFACTOR - Update Original File:**
```cpp
// src/systems/ldtk_loader/ldtk_lua_bindings.cpp
// Replace 100+ line switch statement with:
#include "ldtk_field_converters.hpp"

// In exposeToLua():
// Before: 100+ line switch (field.type) { case Int: ... case Float: ... }
// After:
auto luaValue = ldtk_converters::convert(lua, field);
```

#### Verification
```bash
just test
# Verify complexity reduction:
# Before: CC=93, Depth=8
# After: CC<20 per function, Depth<4
```

---

### Task 2.2: Create InputState Facade

**Problem:** 50+ internal fields exposed directly to Lua, allowing corruption of input system state.

**Files to Modify:**
- `src/systems/input/input_lua_bindings.cpp` (lines 62-151)

**Files to Create:**
- `src/systems/input/input_lua_facade.hpp`
- `src/systems/input/input_lua_facade.cpp`
- `src/systems/input/tests/input_facade_test.cpp`

#### TDD Steps

**RED - Test Facade Prevents Direct State Access:**
```cpp
// src/systems/input/tests/input_facade_test.cpp
#include <catch2/catch_test_macros.hpp>
#include "systems/input/input_lua_facade.hpp"

TEST_CASE("Facade provides read-only access to cursor position", "[input_facade]") {
    input::InputState state;
    state.cursor.x = 100;
    state.cursor.y = 200;

    input::LuaFacade facade(state);

    auto pos = facade.getCursorPosition();
    REQUIRE(pos.x == 100);
    REQUIRE(pos.y == 200);
}

TEST_CASE("Facade validates entity targets before returning", "[input_facade]") {
    entt::registry registry;
    input::InputState state;

    // Set an invalid entity
    state.cursor_focused_target = entt::entity{999};

    input::LuaFacade facade(state, registry);

    // Should return nullopt for invalid entity
    auto target = facade.getFocusedTarget();
    REQUIRE(!target.has_value());
}

TEST_CASE("Facade prevents setting internal collision list", "[input_facade]") {
    // The facade should NOT expose collision_list directly
    // This test documents the API surface

    input::LuaFacade facade;

    // These should NOT compile (not exposed):
    // facade.collision_list = {...};
    // facade.nodes_at_cursor = {...};

    SUCCEED();  // API design verification
}
```

**GREEN - Implement Facade:**
```cpp
// src/systems/input/input_lua_facade.hpp
#pragma once
#include "input_state.hpp"
#include <entt/entt.hpp>
#include <optional>

namespace input {

// Lua-safe facade over InputState
// Exposes only safe, validated accessors
class LuaFacade {
public:
    explicit LuaFacade(InputState& state, entt::registry& registry);

    // Read-only accessors
    [[nodiscard]] Vector2 getCursorPosition() const noexcept;
    [[nodiscard]] Vector2 getWorldCursorPosition() const noexcept;
    [[nodiscard]] bool isMouseDown(int button) const noexcept;
    [[nodiscard]] bool isMousePressed(int button) const noexcept;
    [[nodiscard]] bool isKeyDown(int key) const noexcept;
    [[nodiscard]] bool isKeyPressed(int key) const noexcept;

    // Validated entity accessors (return nullopt for invalid entities)
    [[nodiscard]] std::optional<entt::entity> getFocusedTarget() const;
    [[nodiscard]] std::optional<entt::entity> getClickedTarget() const;
    [[nodiscard]] std::optional<entt::entity> getDraggingTarget() const;

    // Controlled state modification
    void requestFocus(entt::entity entity);
    void clearFocus();

    // Query methods (read-only)
    [[nodiscard]] bool isEntityHovered(entt::entity entity) const;
    [[nodiscard]] bool isEntityClicked(entt::entity entity) const;

private:
    InputState& m_state;
    entt::registry& m_registry;

    [[nodiscard]] bool isValidEntity(entt::entity e) const;
};

// Sol2 binding helper
void exposeFacadeToLua(sol::state& lua, LuaFacade& facade);

} // namespace input
```

**REFACTOR - Update Bindings:**
```cpp
// src/systems/input/input_lua_bindings.cpp
// Before: 90 lines of direct field exposure
// After:
void exposeInputToLua(sol::state& lua, InputState& state, entt::registry& registry) {
    static LuaFacade facade(state, registry);
    exposeFacadeToLua(lua, facade);
}
```

#### Verification
```bash
just test
# Lua test: verify old direct access fails gracefully
```

---

### Task 2.3: Extract Binding Helpers

**Problem:** 1,000+ lines of duplicated BindingRecorder boilerplate across 8+ files.

**Files to Modify:**
- All `*_lua_bindings.cpp` files

**Files to Create:**
- `src/systems/scripting/binding_helpers.hpp`
- `src/systems/scripting/binding_macros.hpp`

#### TDD Steps

**RED - Test Macro Reduces Boilerplate:**
```cpp
// src/systems/scripting/tests/binding_helpers_test.cpp
#include <catch2/catch_test_macros.hpp>
#include "systems/scripting/binding_helpers.hpp"

TEST_CASE("BIND_PROPERTY macro records property correctly", "[binding_helpers]") {
    auto& rec = BindingRecorder::instance();
    rec.clear();  // Reset for test

    // Using the macro
    BIND_PROPERTY("TestType", "field", "number", "A test field");

    auto props = rec.get_properties("TestType");
    REQUIRE(props.size() == 1);
    REQUIRE(props[0].name == "field");
    REQUIRE(props[0].type == "number");
}

TEST_CASE("BIND_METHOD macro records method correctly", "[binding_helpers]") {
    auto& rec = BindingRecorder::instance();
    rec.clear();

    BIND_METHOD("TestType", "doThing", "---@param x number\n---@return boolean", "Does a thing");

    auto methods = rec.get_methods("TestType");
    REQUIRE(methods.size() == 1);
    REQUIRE(methods[0].name == "doThing");
}
```

**GREEN - Implement Macros:**
```cpp
// src/systems/scripting/binding_macros.hpp
#pragma once
#include "binding_recorder.hpp"

// Property binding with automatic recording
#define BIND_PROPERTY(type_name, field_name, field_type, doc) \
    do { \
        auto& rec = BindingRecorder::instance(); \
        rec.record_property(type_name, {field_name, field_type, doc}); \
    } while(0)

// Method binding with automatic recording
#define BIND_METHOD(type_name, method_name, signature, doc) \
    do { \
        auto& rec = BindingRecorder::instance(); \
        rec.record_method(type_name, {method_name, signature, doc}); \
    } while(0)

// Start a new type registration
#define BEGIN_TYPE(lua, type_name, doc) \
    auto& _rec_##type_name = BindingRecorder::instance(); \
    _rec_##type_name.add_type(type_name).doc = doc; \
    auto _ut_##type_name = lua.new_usertype<type_name>(type_name

// End type registration
#define END_TYPE() )

// Shorthand for common patterns
#define BIND_READONLY(ut, type, field) \
    ut[#field] = sol::readonly(&type::field); \
    BIND_PROPERTY(#type, #field, "auto", "Read-only field")

#define BIND_READWRITE(ut, type, field) \
    ut[#field] = &type::field; \
    BIND_PROPERTY(#type, #field, "auto", "Read-write field")
```

```cpp
// src/systems/scripting/binding_helpers.hpp
#pragma once
#include "sol/sol.hpp"
#include <vector>
#include <string>

namespace binding_helpers {

// Convert Lua table to vector of strings (common pattern)
template<typename T = std::string>
std::vector<T> table_to_vector(const sol::table& t) {
    std::vector<T> result;
    result.reserve(t.size());
    for (auto& kv : t) {
        if (kv.second.is<T>()) {
            result.push_back(kv.second.as<T>());
        }
    }
    return result;
}

// Convert vector to Lua table
template<typename T>
sol::table vector_to_table(sol::state& lua, const std::vector<T>& vec) {
    sol::table t = lua.create_table();
    for (size_t i = 0; i < vec.size(); ++i) {
        t[i + 1] = vec[i];
    }
    return t;
}

// Safe optional extraction
template<typename T>
std::optional<T> safe_get(const sol::table& t, const char* key) {
    if (auto val = t[key]; val.valid() && val.is<T>()) {
        return val.get<T>();
    }
    return std::nullopt;
}

// Vector2/cpVect conversion helpers
inline sol::table vec_to_lua(sol::state& lua, float x, float y) {
    sol::table t = lua.create_table();
    t["x"] = x;
    t["y"] = y;
    return t;
}

inline std::pair<float, float> vec_from_lua(const sol::table& t) {
    return {
        t.get_or<float>("x", 0.0f),
        t.get_or<float>("y", 0.0f)
    };
}

} // namespace binding_helpers
```

#### Verification
```bash
just test
# Line count comparison:
wc -l src/systems/*/\*_lua_bindings.cpp  # Before and after
```

---

### Task 2.4: Standardize Result<T> Across Systems

**Problem:** Physics, Layer, and IO systems use silent void returns or bool for errors.

**Files to Modify:**
- `src/systems/physics/physics_world.hpp`
- `src/systems/layer/layer.hpp`
- Resource loading functions

#### TDD Steps

**RED - Test Physics Returns Result:**
```cpp
// src/systems/physics/tests/physics_result_test.cpp
TEST_CASE("Physics body creation returns Result", "[physics]") {
    PhysicsWorld world;

    // Valid creation
    auto result = world.createBody(validConfig);
    REQUIRE(result.isOk());

    // Invalid creation
    auto badResult = world.createBody(invalidConfig);
    REQUIRE(badResult.isErr());
    REQUIRE(badResult.error().find("invalid") != std::string::npos);
}
```

**GREEN - Add Result Returns:**
```cpp
// src/systems/physics/physics_world.hpp
[[nodiscard]] Result<cpBody*, std::string> createBody(const BodyConfig& config);
[[nodiscard]] Result<void, std::string> destroyBody(cpBody* body);
[[nodiscard]] Result<void, std::string> setCollisionMask(const std::string& tag, uint32_t mask);
```

#### Verification
```bash
just test
grep -r "Result<" src/systems/physics/  # Verify adoption
```

---

## Phase 3: Architecture (2-3 Weeks)

### Task 3.1: Split Transform System

**Problem:** 164KB file with 30+ operations mixing transforms, drag, alignment, collision, and UI.

**Files to Modify:**
- `src/systems/transform/transform_functions.cpp`
- `src/systems/transform/transform_functions.hpp`

**Files to Create:**
- `src/systems/transform/transform_core.hpp/cpp` - Position, rotation, scale only
- `src/systems/drag/drag_system.hpp/cpp` - Drag/drop logic
- `src/systems/alignment/alignment_system.hpp/cpp` - UI alignment
- `src/systems/transform/tests/` - Test suite

#### TDD Steps

**RED - Test Systems Are Independent:**
```cpp
// src/systems/transform/tests/transform_core_test.cpp
TEST_CASE("Transform core handles position updates independently", "[transform]") {
    entt::registry registry;
    auto entity = registry.create();
    registry.emplace<Transform>(entity);

    // Transform core should work without drag or alignment systems
    transform_core::setPosition(registry, entity, 100, 200);

    auto& t = registry.get<Transform>(entity);
    REQUIRE(t.actualX == 100);
    REQUIRE(t.actualY == 200);
}

// src/systems/drag/tests/drag_system_test.cpp
TEST_CASE("Drag system operates independently of alignment", "[drag]") {
    entt::registry registry;
    auto entity = registry.create();
    registry.emplace<Transform>(entity);
    registry.emplace<Draggable>(entity);

    drag_system::startDrag(registry, entity, {50, 50});
    drag_system::updateDrag(registry, entity, {100, 100});
    drag_system::endDrag(registry, entity);

    // Verify transform was updated
    auto& t = registry.get<Transform>(entity);
    REQUIRE(t.actualX == 100);
}
```

**GREEN - Extract Systems:**
```cpp
// src/systems/transform/transform_core.hpp
#pragma once
#include <entt/entt.hpp>

namespace transform_core {
    void setPosition(entt::registry& reg, entt::entity e, float x, float y);
    void setRotation(entt::registry& reg, entt::entity e, float radians);
    void setScale(entt::registry& reg, entt::entity e, float sx, float sy);
    void updateAll(entt::registry& reg, float dt);
}

// src/systems/drag/drag_system.hpp
#pragma once
#include <entt/entt.hpp>

namespace drag_system {
    void startDrag(entt::registry& reg, entt::entity e, Vector2 mousePos);
    void updateDrag(entt::registry& reg, entt::entity e, Vector2 mousePos);
    void endDrag(entt::registry& reg, entt::entity e);
    bool isDragging(entt::registry& reg, entt::entity e);
}

// src/systems/alignment/alignment_system.hpp
#pragma once
#include <entt/entt.hpp>

namespace alignment_system {
    void alignToParent(entt::registry& reg, entt::entity e);
    void alignChildren(entt::registry& reg, entt::entity parent);
    void updateAllAlignments(entt::registry& reg);
}
```

#### Verification
```bash
just test
# File size comparison:
ls -la src/systems/transform/*.cpp  # Should be <50KB each
```

---

### Task 3.2: Split Layer System

**Problem:** 294KB file handling rendering, sorting, batching, shaders, and textures.

**Files to Modify:**
- `src/systems/layer/layer.cpp`

**Files to Create:**
- `src/systems/layer/command_buffer.hpp/cpp` - Deferred draw commands
- `src/systems/layer/render_queue.hpp/cpp` - Sorting by depth/shader
- `src/systems/layer/render_backend.hpp/cpp` - Raylib draw calls
- `src/systems/layer/layer_manager.hpp/cpp` - Coordination (thin)

#### TDD Steps

**RED - Test Command Buffer Independence:**
```cpp
// src/systems/layer/tests/command_buffer_test.cpp
TEST_CASE("Command buffer queues commands without rendering", "[layer]") {
    CommandBuffer buffer;

    buffer.queueRect({10, 10, 100, 50}, RED, 1);
    buffer.queueRect({20, 20, 50, 50}, BLUE, 2);

    REQUIRE(buffer.size() == 2);

    auto commands = buffer.getSortedCommands();
    REQUIRE(commands[0].zIndex == 1);  // Lower z first
    REQUIRE(commands[1].zIndex == 2);
}

// src/systems/layer/tests/render_queue_test.cpp
TEST_CASE("Render queue batches by shader", "[layer]") {
    RenderQueue queue;

    // Commands with same shader should batch
    queue.addCommand({.shader = "default", .zIndex = 1});
    queue.addCommand({.shader = "default", .zIndex = 2});
    queue.addCommand({.shader = "glow", .zIndex = 3});

    auto batches = queue.getBatches();
    REQUIRE(batches.size() == 2);  // Two shader groups
}
```

**GREEN - Implement Separated Systems:**
```cpp
// src/systems/layer/command_buffer.hpp
#pragma once
#include <vector>
#include <variant>

namespace layer {

struct DrawCommand {
    enum class Type { Rect, Circle, Texture, Text, Custom };
    Type type;
    int zIndex;
    // ... command-specific data
};

class CommandBuffer {
public:
    void queueRect(Rectangle rect, Color color, int z);
    void queueCircle(Vector2 center, float radius, Color color, int z);
    void queueTexture(Texture2D tex, Rectangle src, Rectangle dst, int z);
    void queueText(const std::string& text, Vector2 pos, int fontSize, int z);

    [[nodiscard]] size_t size() const noexcept;
    [[nodiscard]] std::vector<DrawCommand> getSortedCommands() const;
    void clear();

private:
    std::vector<DrawCommand> m_commands;
};

} // namespace layer
```

#### Verification
```bash
just test
ls -la src/systems/layer/*.cpp  # Should be <75KB each
```

---

### Task 3.3: Split UI System

**Problem:** element.cpp (153KB) threads 8+ component parameters through functions.

**Files to Modify:**
- `src/systems/ui/element.cpp`
- `src/systems/ui/box.cpp`

**Files to Create:**
- `src/systems/ui/ui_layout_system.hpp/cpp` - Size/position calculations
- `src/systems/ui/ui_render_system.hpp/cpp` - Drawing
- `src/systems/ui/ui_interaction_system.hpp/cpp` - Input/hover/click

#### TDD Steps

**RED - Test Layout System Independence:**
```cpp
// src/systems/ui/tests/ui_layout_test.cpp
TEST_CASE("Layout system calculates sizes without rendering", "[ui]") {
    entt::registry registry;
    auto entity = registry.create();
    registry.emplace<UILayoutConfig>(entity, UILayoutConfig{
        .width = 100,
        .height = 50,
        .padding = 10
    });

    ui_layout::calculateSize(registry, entity);

    auto& config = registry.get<UILayoutConfig>(entity);
    REQUIRE(config.calculatedWidth == 100);
    REQUIRE(config.calculatedHeight == 50);
}

// src/systems/ui/tests/ui_interaction_test.cpp
TEST_CASE("Interaction system handles hover without render", "[ui]") {
    entt::registry registry;
    auto entity = registry.create();
    registry.emplace<Transform>(entity, Transform{.actualX = 0, .actualY = 0});
    registry.emplace<UIInteractive>(entity);

    // Simulate cursor at (50, 25) - inside a 100x50 element at origin
    ui_interaction::updateHover(registry, {50, 25});

    auto& interactive = registry.get<UIInteractive>(entity);
    REQUIRE(interactive.isHovered == true);
}
```

**GREEN - Implement Separated Systems:**
```cpp
// src/systems/ui/ui_layout_system.hpp
#pragma once
#include <entt/entt.hpp>

namespace ui_layout {
    void calculateSize(entt::registry& reg, entt::entity e);
    void calculatePosition(entt::registry& reg, entt::entity e);
    void layoutChildren(entt::registry& reg, entt::entity parent);
    void updateAll(entt::registry& reg);
}

// src/systems/ui/ui_render_system.hpp
#pragma once
#include <entt/entt.hpp>
#include "layer/command_buffer.hpp"

namespace ui_render {
    void queueElement(entt::registry& reg, entt::entity e, layer::CommandBuffer& buffer);
    void queueAll(entt::registry& reg, layer::CommandBuffer& buffer);
}

// src/systems/ui/ui_interaction_system.hpp
#pragma once
#include <entt/entt.hpp>

namespace ui_interaction {
    void updateHover(entt::registry& reg, Vector2 cursorPos);
    void processClick(entt::registry& reg, Vector2 clickPos);
    void processDrag(entt::registry& reg, Vector2 dragDelta);
}
```

#### Verification
```bash
just test
ls -la src/systems/ui/*.cpp  # Should be <50KB each
```

---

### Task 3.4: Migrate EngineContext to ECS Components

**Problem:** 60+ mutable global fields that should be ECS components.

**Files to Modify:**
- `src/core/engine_context.hpp`
- `src/core/globals.hpp`

**Files to Create:**
- `src/components/engine_state_components.hpp`
- `src/systems/engine_state/engine_state_system.hpp/cpp`

#### TDD Steps

**RED - Test Component-Based State:**
```cpp
// src/tests/engine_state_test.cpp
TEST_CASE("Mouse state accessible via component", "[engine_state]") {
    entt::registry registry;

    // Create world entity with mouse state component
    auto worldEntity = registry.create();
    registry.emplace<MouseStateComponent>(worldEntity, MouseStateComponent{
        .position = {100, 200},
        .worldPosition = {150, 250},
        .isDown = {true, false, false}
    });

    // Query mouse state
    auto view = registry.view<MouseStateComponent>();
    for (auto [entity, mouse] : view.each()) {
        REQUIRE(mouse.position.x == 100);
        REQUIRE(mouse.isDown[0] == true);
    }
}

TEST_CASE("Cursor entity accessible via component", "[engine_state]") {
    entt::registry registry;

    auto worldEntity = registry.create();
    auto cursorEntity = registry.create();

    registry.emplace<CursorStateComponent>(worldEntity, CursorStateComponent{
        .cursor = cursorEntity,
        .focusedTarget = std::nullopt,
        .clickedTarget = std::nullopt
    });

    auto& cursorState = registry.get<CursorStateComponent>(worldEntity);
    REQUIRE(cursorState.cursor == cursorEntity);
}
```

**GREEN - Define State Components:**
```cpp
// src/components/engine_state_components.hpp
#pragma once
#include <entt/entt.hpp>
#include <raylib.h>
#include <optional>
#include <vector>

// Replaces EngineContext mouse fields
struct MouseStateComponent {
    Vector2 position{};
    Vector2 worldPosition{};
    Vector2 scaledPosition{};
    Vector2 lastClick{};
    std::array<bool, 3> isDown{};
    std::array<bool, 3> isPressed{};
};

// Replaces EngineContext cursor/focus fields
struct CursorStateComponent {
    entt::entity cursor{entt::null};
    std::optional<entt::entity> focusedTarget;
    std::optional<entt::entity> clickedTarget;
    std::optional<entt::entity> draggingTarget;
};

// Replaces EngineContext render scale fields
struct RenderScaleComponent {
    float finalRenderScale{1.0f};
    float letterboxOffsetX{0.0f};
    float letterboxOffsetY{0.0f};
};

// Replaces globals.enemies vector
struct EnemyListComponent {
    std::vector<entt::entity> enemies;
};

// Single "world" entity that holds global state
struct WorldEntityTag {};
```

**REFACTOR - Migrate Gradually:**
```cpp
// src/core/engine_context.hpp
// Add deprecation warnings and forwarding
struct EngineContext {
    // DEPRECATED: Use MouseStateComponent instead
    [[deprecated("Use MouseStateComponent")]]
    Vector2 worldMousePosition;

    // Helper to get component-based state
    template<typename T>
    T& getState(entt::registry& reg) {
        auto view = reg.view<WorldEntityTag, T>();
        return view.get<T>(view.front());
    }
};
```

#### Verification
```bash
just test
grep -r "EngineContext::" src/  # Track migration progress
grep -r "WorldEntityTag" src/   # Verify adoption
```

---

## Appendix A: Test Infrastructure Setup

### Catch2 Integration

```cmake
# CMakeLists.txt additions
include(FetchContent)
FetchContent_Declare(
    Catch2
    GIT_REPOSITORY https://github.com/catchorg/Catch2.git
    GIT_TAG v3.5.0
)
FetchContent_MakeAvailable(Catch2)

# Add test executable
add_executable(tests
    src/tests/main_test.cpp
    src/systems/scripting/tests/sol2_helpers_test.cpp
    src/systems/ldtk_loader/tests/ldtk_field_converters_test.cpp
    # ... more test files
)
target_link_libraries(tests PRIVATE Catch2::Catch2WithMain)

# Register with CTest
include(CTest)
include(Catch)
catch_discover_tests(tests)
```

### Test Main File

```cpp
// src/tests/main_test.cpp
#define CATCH_CONFIG_MAIN
#include <catch2/catch_all.hpp>
```

---

## Appendix B: Subagent Task Assignments

For parallel execution, these tasks can be distributed to subagents:

### Phase 1 (Can run in parallel):
- **Agent 1**: Task 1.1 (sol2_helpers) + Task 1.4 (Result macros)
- **Agent 2**: Task 1.2 (nodiscard) + Task 1.3 (C-style casts)

### Phase 2 (Sequential dependencies):
- **Agent 3**: Task 2.1 (ldtk split) - blocks nothing
- **Agent 4**: Task 2.2 (InputState facade) - after Agent 1
- **Agent 5**: Task 2.3 (binding helpers) - after Agent 3
- **Agent 6**: Task 2.4 (Result adoption) - after Agent 1

### Phase 3 (Can run in parallel after Phase 2):
- **Agent 7**: Task 3.1 (transform split)
- **Agent 8**: Task 3.2 (layer split)
- **Agent 9**: Task 3.3 (UI split)
- **Agent 10**: Task 3.4 (EngineContext migration) - after all others

---

## Appendix C: Success Metrics

| Metric | Before | Target |
|--------|--------|--------|
| Max function lines | 2,980 | <300 |
| Max cyclomatic complexity | 93 | <20 |
| Max nesting depth | 8 | <4 |
| Duplicated code | ~2,350 lines | <500 lines |
| Lua binding boilerplate | 1,000+ lines | <200 lines |
| Exposed InputState fields | 50+ | <10 (via facade) |
| EngineContext global fields | 60+ | 0 (migrated to ECS) |
| Test coverage | Unknown | >70% for new code |

---

## Appendix D: Rollback Plan

Each phase can be rolled back independently:

1. **Phase 1**: Revert new helper files, no API changes
2. **Phase 2**: Facade and converters are additive, old code still works
3. **Phase 3**: System splits maintain backward compatibility via forwarding headers

```cpp
// Example forwarding header for gradual migration
// src/systems/transform/transform_functions.hpp
#pragma once
#include "transform_core.hpp"
#include "drag/drag_system.hpp"
#include "alignment/alignment_system.hpp"

// Deprecated forwarding functions
[[deprecated("Use transform_core::setPosition")]]
inline void SetPosition(...) { transform_core::setPosition(...); }
```

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
