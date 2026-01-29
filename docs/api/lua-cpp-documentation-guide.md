# Lua/C++ Binding Documentation Guide

Guidelines for writing, documenting, and consuming C++/Lua bindings in this codebase. Covers Sol2 patterns, common pitfalls, and UI DSL conventions.

---

## Table of Contents
1. [Sol2 Binding Patterns](#sol2-binding-patterns)
2. [UI DSL Conventions](#ui-dsl-conventions)
3. [Common Pitfalls & Fixes](#common-pitfalls--fixes)
4. [Documentation Standards](#documentation-standards)
5. [Testing Bindings](#testing-bindings)

---

## Sol2 Binding Patterns

### Exposing Types to Lua

**Basic usertype with properties:**
```cpp
lua.new_usertype<Transform>("Transform",
    sol::constructors<Transform()>(),
    "actualX", sol::property(&Transform::getActualX, &Transform::setActualX),
    "actualY", sol::property(&Transform::getActualY, &Transform::setActualY),
    "type_id", []() { return entt::type_hash<Transform>::value(); }
);
```

**Making a type callable (constructor):**
```cpp
lua.new_usertype<UIConfig>("UIConfig",
    sol::call_constructor, sol::constructors<UIConfig>()  // Allows: UIConfig()
);
```

### Exposing Functions

**Free functions:**
```cpp
lua.set_function("getEntityByAlias", getEntityByAlias);
```

**Namespaced functions (using tables):**
```cpp
sol::table physics_table = lua["physics"].get_or_create<sol::table>();
physics_table.set_function("create_body", createBody);
```

**Overloaded functions:**
```cpp
physics_table.set_function("enable_collision", sol::overload(
    [](PhysicsWorld& W, const std::string& a, const std::string& b) { ... },
    [](PhysicsWorld& W, const std::string& a, sol::table tags) { ... }
));
```

### Working with Lua Tables in C++

**Reading table values safely:**
```cpp
sol::table cfg = luaTable;
auto getString = [&](const char* key) -> std::string {
    if (auto v = cfg[key]; v.valid() && v.get_type() == sol::type::string)
        return v.get<std::string>();
    return "";
};

auto getFloat = [&](const char* key) -> float {
    if (auto v = cfg[key]; v.valid() && v.get_type() == sol::type::number)
        return v.get<float>();
    return 0.0f;
};
```

**Creating Lua tables from C++:**
```cpp
sol::table result = lua.create_table();
result["x"] = 100;
result["y"] = 200;
result["name"] = "player";
return result;
```

**Converting vectors to Lua arrays:**
```cpp
std::vector<entt::entity> entities = getEntities();
sol::table out = lua.create_table(static_cast<int>(entities.size()), 0);
for (size_t i = 0; i < entities.size(); ++i) {
    out[i + 1] = entities[i];  // Lua arrays are 1-indexed
}
return sol::as_table(out);
```

### Callback Handling

**Protected function calls (RECOMMENDED):**
```cpp
sol::protected_function pf = luaCallback;
auto result = pf(arg1, arg2);
if (!result.valid()) {
    sol::error err = result;
    SPDLOG_ERROR("Callback failed: {}", err.what());
}
```

**Coroutine handling:**
```cpp
sol::thread thr = sol::thread::create(lua);
sol::state_view thread_view{thr.state()};
sol::coroutine co{thread_fn};

auto result = co(args...);
if (result.status() == sol::call_status::yielded) {
    // Coroutine paused, can resume later
} else if (!result.valid()) {
    sol::error err = result;
    SPDLOG_ERROR("Coroutine error: {}", err.what());
}
```

---

## UI DSL Conventions

### Basic Structure

The UI DSL (`ui.ui_syntax_sugar`) provides declarative UI building:

```lua
local dsl = require("ui.ui_syntax_sugar")

local myUI = dsl.root {
    config = { padding = 10, color = "blackberry" },
    children = {
        dsl.vbox {
            children = {
                dsl.text("Title", { fontSize = 24 }),
                dsl.button("Click", { onClick = function() end }),
            }
        }
    }
}

local boxID = dsl.spawn({ x = 200, y = 200 }, myUI)
```

### Available DSL Functions

| Function | Purpose | Example |
|----------|---------|---------|
| `dsl.root{}` | Root container | `dsl.root { config = {}, children = {} }` |
| `dsl.vbox{}` | Vertical layout | `dsl.vbox { children = {...} }` |
| `dsl.hbox{}` | Horizontal layout | `dsl.hbox { children = {...} }` |
| `dsl.text(str, opts)` | Static text | `dsl.text("Hello", { fontSize = 16 })` |
| `dsl.button(label, opts)` | Clickable button | `dsl.button("OK", { onClick = fn })` |
| `dsl.anim(id, opts)` | Animated sprite | `dsl.anim("icon.png", { w = 32, h = 32 })` |
| `dsl.spacer(w, h)` | Empty space | `dsl.spacer(10, 20)` |
| `dsl.progressBar(opts)` | Progress bar | `dsl.progressBar({ getValue = fn })` |
| `dsl.tabs(opts)` | Tabbed container | `dsl.tabs({ tabs = {...} })` |
| `dsl.spriteBox(sprite, opts)` | Sprite background | `dsl.spriteBox("panel.png", { children = {...} })` |

### Config Options

Common config fields accepted by most DSL functions:

```lua
config = {
    id = "unique_id",           -- For lookup via GetUIEByID
    color = "blue",             -- Background color (name or Color)
    padding = 10,               -- Inner padding
    minWidth = 100,             -- Minimum width
    minHeight = 50,             -- Minimum height
    align = bit.bor(AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER),
    hover = true,               -- Enable hover effects
    canCollide = true,          -- Enable collision detection
    buttonCallback = function() end,  -- Click handler
    tooltip = "Tooltip text",   -- Simple tooltip
}
```

### UI Color Constants

Available color names (from `util.getColor()`):
- Basic: `red`, `green`, `blue`, `white`, `black`, `gray`
- Extended: `blackberry`, `gold`, `cyan`, `purple`, `orange`
- Elements: `fire`, `ice`, `poison`, `holy`, `void`, `electric`

---

## Common Pitfalls & Fixes

### 1. Data Loss with attach_ecs()

**THE BUG:** Data assigned after `attach_ecs()` is lost.

```lua
-- WRONG: Data assigned after attach_ecs
local script = EntityType {}
script:attach_ecs { create_new = true }
script.health = 100  -- LOST! getScriptTableFromEntityID won't see this

-- CORRECT: Data assigned before attach_ecs
local script = EntityType {}
script.health = 100  -- Assign FIRST
script:attach_ecs { create_new = true }  -- Then attach
```

**FIX:** Use `Node.quick()` or `EntityBuilder.validated()` which enforce correct ordering.

### 2. sol::optional with sol::function

**THE BUG:** Wrapping `sol::function` in `sol::optional` causes issues.

```cpp
// WRONG: May cause unexpected behavior
void setCallback(sol::optional<sol::function> fn);

// CORRECT: Handle nil explicitly
void setCallback(sol::object fnObj) {
    if (fnObj.is<sol::function>()) {
        callback_ = fnObj.as<sol::function>();
    } else if (fnObj.is<sol::nil_t>()) {
        callback_ = sol::nil;
    }
}
```

### 3. Userdata newindex Assignment Failure

**THE BUG:** Some C++ userdata don't support Lua field assignment.

```lua
-- May fail if go.methods is read-only userdata
go.methods.onHover = function() end  -- Error: no new_index operation
```

**FIX:** Use pcall for safety:
```lua
local function safeSetMethod(go, name, fn)
    local success, err = pcall(function()
        go.methods[name] = fn
    end)
    if not success then
        log_warn("Could not set method " .. name .. ": " .. tostring(err))
    end
    return success
end
```

### 4. EnTT "slot not available" Errors

**THE BUG:** Registering the same component type from different translation units.

**FIX:** See https://github.com/skypjack/entt/issues/1095
- Ensure component registration happens in a single place
- Use `entt::type_hash<T>::value()` consistently

### 5. Nil Return from getScriptTableFromEntityID

**THE BUG:** Returns nil for entities without proper script initialization.

```lua
local entity = registry:create()
local script = getScriptTableFromEntityID(entity)  -- Returns nil!
```

**FIX:** Always use the script table pattern or Entity Builder:
```lua
local entity, script = EntityBuilder.create({ sprite = "player" })
-- Now script is guaranteed to be valid
```

### 6. Callback Signature Mismatch

**THE BUG:** C++ expects specific callback signatures; Lua provides wrong params.

```lua
-- C++ expects: function(registry, entity, collisionList)
-- WRONG: Missing parameters
go.methods.onRelease = function()
    print("released")  -- Never receives collision info
end

-- CORRECT: Match expected signature
go.methods.onRelease = function(reg, self, collisionList)
    for _, hit in ipairs(collisionList) do
        print("Hit:", hit)
    end
end
```

### 7. Timer Callback in Wrong Lua State

**THE BUG:** Timer callbacks registered in a coroutine may fail after coroutine dies.

**FIX:** Clone functions to main state:
```cpp
auto clone_to_main = [](sol::function thread_fn) {
    sol::state_view main_sv{ ai_system::masterStateLua };
    main_sv["__timer_import"] = thread_fn;
    sol::function main_fn = main_sv.get<sol::function>("__timer_import");
    main_sv["__timer_import"] = sol::lua_nil;
    return main_fn;
};
```

### 8. UI Color Creation

**THE BUG:** Using Lua tables for colors instead of proper Color userdata.

```lua
-- WRONG: Creates a table, not a Color
local transparent = { r = 0, g = 0, b = 0, a = 0 }

-- CORRECT: Use Color.new() to create proper userdata
local transparent = Color.new(0, 0, 0, 0)
```

---

## Documentation Standards

### Recording Lua Bindings

Use `BindingRecorder` to document bindings automatically:

```cpp
auto& rec = BindingRecorder::instance();

// Document a type
auto& typeDef = rec.add_type("Transform", /*is_data_class=*/true);
typeDef.doc = "Represents position, rotation, and scale.";

// Document a property
rec.record_property("Transform", {"actualX", "number", "The actual X position."});

// Document a method
rec.record_method("Transform", {
    "setPosition",
    "---@param x number\n---@param y number\n---@return nil",
    "Sets the position.",
    /*is_static=*/false,
    /*is_overload=*/false
});

// Document a free function
rec.record_free_function({"physics", "world"}, {
    "create_body",
    "---@param entity Entity\n---@return boolean",
    "Creates a physics body for an entity.",
    /*is_free=*/true,
    /*is_overload=*/false
});
```

### LuaLS Annotations

Use EmmyLua/LuaLS annotations in generated definitions:

```lua
---@class Transform
---@field actualX number The actual X position
---@field actualY number The actual Y position
---@field rotation number Rotation in radians

---@param entity Entity
---@param x number
---@param y number
---@return nil
function transform.setPosition(entity, x, y) end
```

### C++ Doxygen Comments

Follow the standards in [DOCUMENTATION_STANDARDS.md](../guides/DOCUMENTATION_STANDARDS.md):

```cpp
/**
 * @brief Creates a physics body for the given entity.
 * 
 * @param registry The EnTT registry.
 * @param entity The entity to attach physics to.
 * @param config Configuration table from Lua.
 * @return true if body was created successfully.
 * 
 * @note Thread-safety: main thread only.
 * @note The entity must have a Transform component.
 */
bool createPhysicsBody(entt::registry& registry, entt::entity entity, sol::table config);
```

---

## Testing Bindings

### Unit Tests

```cpp
TEST(LuaBindings, TransformPropertyAccess) {
    sol::state lua;
    transform::exposeToLua(lua);
    
    lua.script(R"(
        local t = Transform()
        t.actualX = 100
        assert(t.actualX == 100, "X should be 100")
    )");
}
```

### Runtime Validation

Add validation in Lua for debugging:

```lua
local function validateEntity(e, context)
    if not registry:valid(e) then
        log_error(context .. ": invalid entity " .. tostring(e))
        return false
    end
    return true
end

local function validateComponent(e, compType, context)
    if not registry:has(e, compType) then
        log_warn(context .. ": entity " .. tostring(e) .. " missing " .. tostring(compType))
        return false
    end
    return true
end
```

---

## Quick Reference

### Global C++ Bindings (No require needed)

| Global | Purpose |
|--------|---------|
| `registry` | EnTT registry |
| `component_cache` | Cached component access |
| `localization` | i18n system |
| `physics` | Physics functions |
| `globals` | Game state |

### Common Lua Imports

```lua
local Q = require("core.Q")                    -- Quick helpers
local timer = require("core.timer")            -- Timers
local signal = require("external.hump.signal") -- Events
local dsl = require("ui.ui_syntax_sugar")      -- UI DSL
local EntityBuilder = require("core.entity_builder")
```

### UI Task Delegation

> **Note:** For UI/UX implementation tasks involving visual design, layout decisions, or styling, delegate to the `frontend-ui-ux-engineer` agent. This agent specializes in creating visually appealing interfaces even without design mockups.

---

## See Also

- [Working with Sol2](working_with_sol.md)
- [C++ Documentation Standards](../guides/DOCUMENTATION_STANDARDS.md)
- [UI Helper Reference](ui_helper_reference.md)
- [Entity State Management](../systems/core/entity_state_management_doc.md)

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
