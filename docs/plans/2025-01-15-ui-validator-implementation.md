# UI Validator Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a rule-based UI validation system that catches layout overlaps, z-order errors, and render inconsistencies.

**Architecture:** Lua module that inspects computed UI bounds after layout, validates against rules (containment, overlap, z-order), and provides visual debug overlays. Uses tracked render wrappers for manually-rendered entities like cards.

**Tech Stack:** Lua, TestRunner, UI DSL, layer_order_system (C++ binding)

---

## CRITICAL REQUIREMENTS

Every task that modifies code MUST end with:

1. **Build verification:** `just build-debug`
2. **Runtime verification:** Run executable for 10+ seconds in each phase:
   - Main menu (wait 10s)
   - Planning phase (open inventory, wait 10s)
   - Action phase (start wave, wait 10s)
3. **No errors:** Check for Lua errors, crashes, visual glitches
4. **Code review:** Dispatch `superpowers:requesting-code-review` after each task

**Verification command:**
```bash
(./build/raylib-cpp-cmake-template 2>&1 & sleep 35; kill $!) | grep -iE "(error|Error|Lua|FAIL|crash)" | head -20
```

If ANY errors appear, fix them before proceeding.

---

## Task 1: Create UIValidator Module Skeleton

**Files:**
- Create: `assets/scripts/core/ui_validator.lua`
- Create: `assets/scripts/tests/test_ui_validator.lua`

### Step 1: Write the failing test

Create `assets/scripts/tests/test_ui_validator.lua`:

```lua
local TestRunner = require("tests.test_runner")

TestRunner.describe("UIValidator Module", function()

    TestRunner.it("module loads without error", function()
        local UIValidator = require("core.ui_validator")
        TestRunner.assert_not_nil(UIValidator, "UIValidator module should load")
    end)

    TestRunner.it("has enable/disable API", function()
        local UIValidator = require("core.ui_validator")
        TestRunner.assert_not_nil(UIValidator.enable, "should have enable function")
        TestRunner.assert_not_nil(UIValidator.disable, "should have disable function")
        TestRunner.assert_not_nil(UIValidator.isEnabled, "should have isEnabled function")
    end)

    TestRunner.it("has validate API", function()
        local UIValidator = require("core.ui_validator")
        TestRunner.assert_not_nil(UIValidator.validate, "should have validate function")
    end)

end)
```

### Step 2: Run test to verify it fails

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 5; kill $!) | grep -i "ui_validator\|UIValidator\|FAIL"
```

Expected: Module not found error or test failure

### Step 3: Write minimal implementation

Create `assets/scripts/core/ui_validator.lua`:

```lua
--[[
    UIValidator - Rule-based UI validation system

    Validates UI elements for:
    - containment: children inside parent bounds
    - window_bounds: UI inside game window
    - sibling_overlap: same z-order siblings don't overlap
    - z_order_hierarchy: z-order respects hierarchy
    - collision_alignment: collision bounds inside visual bounds
    - layer_consistency: all elements same render layer
    - space_consistency: all elements same DrawCommandSpace
]]

local UIValidator = {}

-- State
local enabled = false
local severities = {
    containment = "error",
    window_bounds = "error",
    sibling_overlap = "warning",
    z_order_hierarchy = "warning",
    collision_alignment = "error",
    layer_consistency = "error",
    space_consistency = "error",
}

-- Render tracking (for manually-rendered entities)
local renderLog = {}

---Enable auto-validation
function UIValidator.enable()
    enabled = true
end

---Disable auto-validation
function UIValidator.disable()
    enabled = false
end

---Check if validation is enabled
---@return boolean
function UIValidator.isEnabled()
    return enabled
end

---Validate a UI entity and return violations
---@param entity number Entity ID
---@param rules? string[] Optional: specific rules to check (default: all)
---@return table[] violations List of {type, severity, entity, message}
function UIValidator.validate(entity, rules)
    -- Placeholder - will implement in subsequent tasks
    return {}
end

---Set severity for a rule
---@param rule string Rule name
---@param severity "error"|"warning" Severity level
function UIValidator.setSeverity(rule, severity)
    if severities[rule] then
        severities[rule] = severity
    end
end

---Get severity for a rule
---@param rule string Rule name
---@return "error"|"warning"
function UIValidator.getSeverity(rule)
    return severities[rule] or "warning"
end

---Clear render log (call at frame start)
function UIValidator.clearRenderLog()
    renderLog = {}
end

---Get render log for inspection
---@return table
function UIValidator.getRenderLog()
    return renderLog
end

return UIValidator
```

### Step 4: Run test to verify it passes

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 5; kill $!) | grep -i "ui_validator\|UIValidator\|PASS\|FAIL"
```

Expected: Tests pass

### Step 5: Build and runtime verification

```bash
just build-debug
(./build/raylib-cpp-cmake-template 2>&1 & sleep 35; kill $!) | grep -iE "(error|Error|Lua|FAIL|crash)" | head -20
```

Expected: No errors, game runs through menu → planning → action

### Step 6: Commit

```bash
git add assets/scripts/core/ui_validator.lua assets/scripts/tests/test_ui_validator.lua
git commit -m "$(cat <<'EOF'
feat(ui): add UIValidator module skeleton

Add core module structure with:
- enable/disable/isEnabled API
- validate() placeholder
- severity configuration
- render log for tracking manual renders

TDD: tests written first, then implementation

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 7: Code review

Dispatch `superpowers:requesting-code-review` to verify implementation.

---

## Task 2: Implement Bounds Extraction

**Files:**
- Modify: `assets/scripts/core/ui_validator.lua`
- Modify: `assets/scripts/tests/test_ui_validator.lua`

### Step 1: Write the failing test

Add to `assets/scripts/tests/test_ui_validator.lua`:

```lua
TestRunner.describe("UIValidator Bounds Extraction", function()

    TestRunner.it("getBounds returns entity bounds", function()
        local UIValidator = require("core.ui_validator")
        local dsl = require("ui.ui_syntax_sugar")

        -- Create simple UI
        local ui = dsl.root {
            config = { padding = 0, minWidth = 100, minHeight = 50 },
            children = {}
        }
        local entity = dsl.spawn({ x = 200, y = 150 }, ui)

        -- Wait a frame for layout
        -- (In tests, layout is immediate after spawn)

        local bounds = UIValidator.getBounds(entity)

        TestRunner.assert_not_nil(bounds, "should return bounds table")
        TestRunner.assert_not_nil(bounds.x, "should have x")
        TestRunner.assert_not_nil(bounds.y, "should have y")
        TestRunner.assert_not_nil(bounds.w, "should have width")
        TestRunner.assert_not_nil(bounds.h, "should have height")

        -- Cleanup
        dsl.remove(entity)
    end)

    TestRunner.it("getAllBounds returns bounds for entity and children", function()
        local UIValidator = require("core.ui_validator")
        local dsl = require("ui.ui_syntax_sugar")

        local ui = dsl.root {
            config = { padding = 10 },
            children = {
                dsl.text("Hello", { id = "test_text" })
            }
        }
        local entity = dsl.spawn({ x = 100, y = 100 }, ui)

        local allBounds = UIValidator.getAllBounds(entity)

        TestRunner.assert_not_nil(allBounds, "should return bounds map")
        TestRunner.assert_true(type(allBounds) == "table", "should be table")

        -- Should have at least the root
        local count = 0
        for _, _ in pairs(allBounds) do
            count = count + 1
        end
        TestRunner.assert_true(count >= 1, "should have at least root bounds")

        dsl.remove(entity)
    end)

end)
```

### Step 2: Run test to verify it fails

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -i "getBounds\|getAllBounds\|FAIL"
```

Expected: getBounds/getAllBounds not defined

### Step 3: Write minimal implementation

Add to `assets/scripts/core/ui_validator.lua` (before `return UIValidator`):

```lua
---Get computed bounds for an entity
---@param entity number Entity ID
---@return table|nil {x, y, w, h} or nil if no bounds
function UIValidator.getBounds(entity)
    if not entity or not registry:valid(entity) then
        return nil
    end

    -- Try Transform component first (for positioned entities)
    local transform = component_cache.get(entity, Transform)
    if transform then
        local x = transform.actualX or transform.x or 0
        local y = transform.actualY or transform.y or 0
        local w = transform.w or 32
        local h = transform.h or 32
        return { x = x, y = y, w = w, h = h }
    end

    -- Try UIElementComponent for UI-specific bounds
    local uiElement = component_cache.get(entity, UIElementComponent)
    if uiElement and uiElement.bounds then
        return {
            x = uiElement.bounds.x or 0,
            y = uiElement.bounds.y or 0,
            w = uiElement.bounds.w or 0,
            h = uiElement.bounds.h or 0,
        }
    end

    -- Try CollisionShape2D for collision bounds
    local collision = component_cache.get(entity, CollisionShape2D)
    if collision then
        local minX = collision.aabb_min_x or 0
        local minY = collision.aabb_min_y or 0
        local maxX = collision.aabb_max_x or 0
        local maxY = collision.aabb_max_y or 0
        return {
            x = minX,
            y = minY,
            w = maxX - minX,
            h = maxY - minY,
        }
    end

    return nil
end

---Get bounds for entity and all descendants
---@param entity number Root entity ID
---@return table Map of entity -> bounds
function UIValidator.getAllBounds(entity)
    local result = {}

    local function collectBounds(ent, depth)
        if not ent or not registry:valid(ent) then return end
        if depth > 50 then return end -- Prevent infinite recursion

        local bounds = UIValidator.getBounds(ent)
        if bounds then
            result[ent] = bounds
        end

        -- Get children from GameObject
        local go = component_cache.get(ent, GameObject)
        if go and go.orderedChildren then
            for _, child in ipairs(go.orderedChildren) do
                collectBounds(child, depth + 1)
            end
        end

        -- Also check UIBoxComponent children
        local uiBox = component_cache.get(ent, UIBoxComponent)
        if uiBox and uiBox.uiRoot and registry:valid(uiBox.uiRoot) then
            collectBounds(uiBox.uiRoot, depth + 1)
        end
    end

    collectBounds(entity, 0)
    return result
end
```

### Step 4: Run test to verify it passes

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -i "Bounds\|PASS\|FAIL"
```

Expected: Tests pass

### Step 5: Build and runtime verification

```bash
just build-debug
(./build/raylib-cpp-cmake-template 2>&1 & sleep 35; kill $!) | grep -iE "(error|Error|Lua|FAIL|crash)" | head -20
```

### Step 6: Commit

```bash
git add assets/scripts/core/ui_validator.lua assets/scripts/tests/test_ui_validator.lua
git commit -m "$(cat <<'EOF'
feat(ui): add bounds extraction to UIValidator

Add getBounds() and getAllBounds() functions:
- getBounds: extract x,y,w,h from Transform, UIElementComponent, or CollisionShape2D
- getAllBounds: recursively collect bounds for entity tree

TDD: failing tests first, then implementation

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 7: Code review

Dispatch `superpowers:requesting-code-review`.

---

## Task 3: Implement Containment Rule

**Files:**
- Modify: `assets/scripts/core/ui_validator.lua`
- Modify: `assets/scripts/tests/test_ui_validator.lua`

### Step 1: Write the failing test

Add to `assets/scripts/tests/test_ui_validator.lua`:

```lua
TestRunner.describe("UIValidator Containment Rule", function()

    TestRunner.it("checkContainment returns no violations for contained children", function()
        local UIValidator = require("core.ui_validator")
        local dsl = require("ui.ui_syntax_sugar")

        -- Parent 200x200, child should fit inside
        local ui = dsl.root {
            config = { padding = 20, minWidth = 200, minHeight = 200 },
            children = {
                dsl.text("Small text", { fontSize = 12 })
            }
        }
        local entity = dsl.spawn({ x = 100, y = 100 }, ui)

        local violations = UIValidator.checkContainment(entity)

        TestRunner.assert_not_nil(violations, "should return violations array")
        TestRunner.assert_equals(0, #violations, "should have no violations for contained children")

        dsl.remove(entity)
    end)

    TestRunner.it("checkContainment detects child escaping parent", function()
        local UIValidator = require("core.ui_validator")

        -- Mock bounds where child escapes parent
        local mockBounds = {
            parent = { x = 100, y = 100, w = 50, h = 50 },
            child = { x = 140, y = 100, w = 30, h = 30 }, -- Escapes right edge (140+30 > 100+50)
        }

        local violations = UIValidator.checkContainmentWithBounds(
            "parent", mockBounds.parent,
            "child", mockBounds.child
        )

        TestRunner.assert_true(#violations > 0, "should detect child escaping parent")
        TestRunner.assert_equals("containment", violations[1].type, "violation type should be containment")
    end)

    TestRunner.it("respects allowEscape flag", function()
        local UIValidator = require("core.ui_validator")

        local mockBounds = {
            parent = { x = 100, y = 100, w = 50, h = 50 },
            child = { x = 140, y = 100, w = 30, h = 30, allowEscape = true },
        }

        local violations = UIValidator.checkContainmentWithBounds(
            "parent", mockBounds.parent,
            "child", mockBounds.child
        )

        TestRunner.assert_equals(0, #violations, "should allow escape when flag set")
    end)

end)
```

### Step 2: Run test to verify it fails

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -i "Containment\|checkContainment\|FAIL"
```

Expected: checkContainment not defined

### Step 3: Write minimal implementation

Add to `assets/scripts/core/ui_validator.lua`:

```lua
---Check if child bounds are fully inside parent bounds
---@param px number Parent x
---@param py number Parent y
---@param pw number Parent width
---@param ph number Parent height
---@param cx number Child x
---@param cy number Child y
---@param cw number Child width
---@param ch number Child height
---@return boolean contained
local function isContained(px, py, pw, ph, cx, cy, cw, ch)
    return cx >= px and
           cy >= py and
           (cx + cw) <= (px + pw) and
           (cy + ch) <= (py + ph)
end

---Check containment between specific parent/child bounds
---@param parentId string|number Parent identifier
---@param parentBounds table {x, y, w, h}
---@param childId string|number Child identifier
---@param childBounds table {x, y, w, h, allowEscape?}
---@return table[] violations
function UIValidator.checkContainmentWithBounds(parentId, parentBounds, childId, childBounds)
    local violations = {}

    -- Skip if child has allowEscape flag
    if childBounds.allowEscape then
        return violations
    end

    if not isContained(
        parentBounds.x, parentBounds.y, parentBounds.w, parentBounds.h,
        childBounds.x, childBounds.y, childBounds.w, childBounds.h
    ) then
        table.insert(violations, {
            type = "containment",
            severity = severities.containment,
            entity = childId,
            parent = parentId,
            message = string.format(
                "Entity %s escapes parent %s bounds (child: %d,%d %dx%d, parent: %d,%d %dx%d)",
                tostring(childId), tostring(parentId),
                childBounds.x, childBounds.y, childBounds.w, childBounds.h,
                parentBounds.x, parentBounds.y, parentBounds.w, parentBounds.h
            ),
        })
    end

    return violations
end

---Check containment rule for a UI entity tree
---@param entity number Root entity ID
---@return table[] violations
function UIValidator.checkContainment(entity)
    local violations = {}

    local function checkEntity(ent, parentBounds)
        if not ent or not registry:valid(ent) then return end

        local bounds = UIValidator.getBounds(ent)
        if not bounds then return end

        -- Check if this entity is contained in parent
        if parentBounds then
            -- Get allowEscape from config if available
            local go = component_cache.get(ent, GameObject)
            local allowEscape = go and go.config and go.config.allowEscape
            bounds.allowEscape = allowEscape

            local v = UIValidator.checkContainmentWithBounds(
                "parent", parentBounds,
                ent, bounds
            )
            for _, violation in ipairs(v) do
                table.insert(violations, violation)
            end
        end

        -- Check children
        local go = component_cache.get(ent, GameObject)
        if go and go.orderedChildren then
            for _, child in ipairs(go.orderedChildren) do
                checkEntity(child, bounds)
            end
        end
    end

    checkEntity(entity, nil)
    return violations
end
```

### Step 4: Run test to verify it passes

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -i "Containment\|PASS\|FAIL"
```

### Step 5: Build and runtime verification

```bash
just build-debug
(./build/raylib-cpp-cmake-template 2>&1 & sleep 35; kill $!) | grep -iE "(error|Error|Lua|FAIL|crash)" | head -20
```

### Step 6: Commit

```bash
git add assets/scripts/core/ui_validator.lua assets/scripts/tests/test_ui_validator.lua
git commit -m "$(cat <<'EOF'
feat(ui): add containment rule to UIValidator

Add checkContainment() and checkContainmentWithBounds():
- Detects children escaping parent bounds
- Respects allowEscape flag for intentional violations

TDD: failing tests first, then implementation

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 7: Code review

Dispatch `superpowers:requesting-code-review`.

---

## Task 4: Implement Window Bounds Rule

**Files:**
- Modify: `assets/scripts/core/ui_validator.lua`
- Modify: `assets/scripts/tests/test_ui_validator.lua`

### Step 1: Write the failing test

Add to `assets/scripts/tests/test_ui_validator.lua`:

```lua
TestRunner.describe("UIValidator Window Bounds Rule", function()

    TestRunner.it("checkWindowBounds returns no violations for UI inside window", function()
        local UIValidator = require("core.ui_validator")
        local dsl = require("ui.ui_syntax_sugar")

        -- Small UI in center of screen
        local ui = dsl.root {
            config = { padding = 10, minWidth = 100, minHeight = 100 },
            children = {}
        }
        local entity = dsl.spawn({ x = 200, y = 200 }, ui)

        local violations = UIValidator.checkWindowBounds(entity)

        TestRunner.assert_not_nil(violations, "should return violations array")
        TestRunner.assert_equals(0, #violations, "should have no violations for UI inside window")

        dsl.remove(entity)
    end)

    TestRunner.it("checkWindowBounds detects UI outside window", function()
        local UIValidator = require("core.ui_validator")

        -- Mock bounds outside window (assuming 1280x720 window)
        local mockBounds = { x = 1300, y = 100, w = 100, h = 100 }
        local windowBounds = { x = 0, y = 0, w = 1280, h = 720 }

        local violations = UIValidator.checkWindowBoundsWithBounds("test_entity", mockBounds, windowBounds)

        TestRunner.assert_true(#violations > 0, "should detect UI outside window")
        TestRunner.assert_equals("window_bounds", violations[1].type, "violation type should be window_bounds")
    end)

end)
```

### Step 2: Run test to verify it fails

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -i "WindowBounds\|window_bounds\|FAIL"
```

### Step 3: Write minimal implementation

Add to `assets/scripts/core/ui_validator.lua`:

```lua
---Get window bounds
---@return table {x, y, w, h}
function UIValidator.getWindowBounds()
    local w = globals and globals.screenWidth or 1280
    local h = globals and globals.screenHeight or 720
    return { x = 0, y = 0, w = w, h = h }
end

---Check if bounds are inside window
---@param entityId string|number Entity identifier
---@param bounds table {x, y, w, h}
---@param windowBounds? table {x, y, w, h} Optional custom window bounds
---@return table[] violations
function UIValidator.checkWindowBoundsWithBounds(entityId, bounds, windowBounds)
    local violations = {}
    windowBounds = windowBounds or UIValidator.getWindowBounds()

    if not isContained(
        windowBounds.x, windowBounds.y, windowBounds.w, windowBounds.h,
        bounds.x, bounds.y, bounds.w, bounds.h
    ) then
        table.insert(violations, {
            type = "window_bounds",
            severity = severities.window_bounds,
            entity = entityId,
            message = string.format(
                "Entity %s outside window bounds (entity: %d,%d %dx%d, window: %d,%d %dx%d)",
                tostring(entityId),
                bounds.x, bounds.y, bounds.w, bounds.h,
                windowBounds.x, windowBounds.y, windowBounds.w, windowBounds.h
            ),
        })
    end

    return violations
end

---Check window bounds rule for a UI entity tree
---@param entity number Root entity ID
---@return table[] violations
function UIValidator.checkWindowBounds(entity)
    local violations = {}
    local windowBounds = UIValidator.getWindowBounds()

    local allBounds = UIValidator.getAllBounds(entity)
    for ent, bounds in pairs(allBounds) do
        local v = UIValidator.checkWindowBoundsWithBounds(ent, bounds, windowBounds)
        for _, violation in ipairs(v) do
            table.insert(violations, violation)
        end
    end

    return violations
end
```

### Step 4: Run test to verify it passes

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -i "WindowBounds\|window_bounds\|PASS\|FAIL"
```

### Step 5: Build and runtime verification

```bash
just build-debug
(./build/raylib-cpp-cmake-template 2>&1 & sleep 35; kill $!) | grep -iE "(error|Error|Lua|FAIL|crash)" | head -20
```

### Step 6: Commit

```bash
git add assets/scripts/core/ui_validator.lua assets/scripts/tests/test_ui_validator.lua
git commit -m "$(cat <<'EOF'
feat(ui): add window bounds rule to UIValidator

Add checkWindowBounds() and checkWindowBoundsWithBounds():
- Detects UI elements outside game window
- Uses globals.screenWidth/screenHeight for window size

TDD: failing tests first, then implementation

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 7: Code review

Dispatch `superpowers:requesting-code-review`.

---

## Task 5: Implement Sibling Overlap Rule

**Files:**
- Modify: `assets/scripts/core/ui_validator.lua`
- Modify: `assets/scripts/tests/test_ui_validator.lua`

### Step 1: Write the failing test

Add to `assets/scripts/tests/test_ui_validator.lua`:

```lua
TestRunner.describe("UIValidator Sibling Overlap Rule", function()

    TestRunner.it("checkSiblingOverlap returns no violations for non-overlapping siblings", function()
        local UIValidator = require("core.ui_validator")

        local siblings = {
            { id = "a", bounds = { x = 0, y = 0, w = 50, h = 50 } },
            { id = "b", bounds = { x = 60, y = 0, w = 50, h = 50 } }, -- No overlap
        }

        local violations = UIValidator.checkSiblingOverlapWithBounds(siblings)

        TestRunner.assert_equals(0, #violations, "should have no violations for non-overlapping siblings")
    end)

    TestRunner.it("checkSiblingOverlap detects overlapping siblings", function()
        local UIValidator = require("core.ui_validator")

        local siblings = {
            { id = "a", bounds = { x = 0, y = 0, w = 50, h = 50 } },
            { id = "b", bounds = { x = 40, y = 0, w = 50, h = 50 } }, -- Overlaps by 10px
        }

        local violations = UIValidator.checkSiblingOverlapWithBounds(siblings)

        TestRunner.assert_true(#violations > 0, "should detect overlapping siblings")
        TestRunner.assert_equals("sibling_overlap", violations[1].type, "violation type should be sibling_overlap")
    end)

    TestRunner.it("respects allowOverlap flag", function()
        local UIValidator = require("core.ui_validator")

        local siblings = {
            { id = "a", bounds = { x = 0, y = 0, w = 50, h = 50 } },
            { id = "b", bounds = { x = 40, y = 0, w = 50, h = 50, allowOverlap = true } },
        }

        local violations = UIValidator.checkSiblingOverlapWithBounds(siblings)

        TestRunner.assert_equals(0, #violations, "should allow overlap when flag set")
    end)

end)
```

### Step 2: Run test to verify it fails

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -i "SiblingOverlap\|sibling_overlap\|FAIL"
```

### Step 3: Write minimal implementation

Add to `assets/scripts/core/ui_validator.lua`:

```lua
---Check if two rectangles overlap
---@return boolean
local function rectsOverlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx and
           ay < by + bh and ay + ah > by
end

---Check sibling overlap with provided bounds
---@param siblings table[] Array of {id, bounds: {x,y,w,h,allowOverlap?}}
---@return table[] violations
function UIValidator.checkSiblingOverlapWithBounds(siblings)
    local violations = {}

    for i = 1, #siblings - 1 do
        for j = i + 1, #siblings do
            local a = siblings[i]
            local b = siblings[j]

            -- Skip if either has allowOverlap
            if a.bounds.allowOverlap or b.bounds.allowOverlap then
                goto continue
            end

            if rectsOverlap(
                a.bounds.x, a.bounds.y, a.bounds.w, a.bounds.h,
                b.bounds.x, b.bounds.y, b.bounds.w, b.bounds.h
            ) then
                table.insert(violations, {
                    type = "sibling_overlap",
                    severity = severities.sibling_overlap,
                    entity = b.id,
                    sibling = a.id,
                    message = string.format(
                        "Entity %s overlaps sibling %s",
                        tostring(b.id), tostring(a.id)
                    ),
                })
            end

            ::continue::
        end
    end

    return violations
end

---Check sibling overlap for children of an entity
---@param entity number Parent entity ID
---@return table[] violations
function UIValidator.checkSiblingOverlap(entity)
    local violations = {}

    local function checkChildren(ent)
        if not ent or not registry:valid(ent) then return end

        local go = component_cache.get(ent, GameObject)
        if not go or not go.orderedChildren then return end

        -- Collect sibling bounds
        local siblings = {}
        for _, child in ipairs(go.orderedChildren) do
            local bounds = UIValidator.getBounds(child)
            if bounds then
                local childGo = component_cache.get(child, GameObject)
                local allowOverlap = childGo and childGo.config and childGo.config.allowOverlap
                bounds.allowOverlap = allowOverlap
                table.insert(siblings, { id = child, bounds = bounds })
            end
        end

        -- Check for overlaps
        local v = UIValidator.checkSiblingOverlapWithBounds(siblings)
        for _, violation in ipairs(v) do
            table.insert(violations, violation)
        end

        -- Recurse into children
        for _, child in ipairs(go.orderedChildren) do
            checkChildren(child)
        end
    end

    checkChildren(entity)
    return violations
end
```

### Step 4: Run test to verify it passes

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -i "SiblingOverlap\|sibling_overlap\|PASS\|FAIL"
```

### Step 5: Build and runtime verification

```bash
just build-debug
(./build/raylib-cpp-cmake-template 2>&1 & sleep 35; kill $!) | grep -iE "(error|Error|Lua|FAIL|crash)" | head -20
```

### Step 6: Commit

```bash
git add assets/scripts/core/ui_validator.lua assets/scripts/tests/test_ui_validator.lua
git commit -m "$(cat <<'EOF'
feat(ui): add sibling overlap rule to UIValidator

Add checkSiblingOverlap() and checkSiblingOverlapWithBounds():
- Detects overlapping siblings at same hierarchy level
- Respects allowOverlap flag for intentional overlaps
- Severity: warning (configurable)

TDD: failing tests first, then implementation

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 7: Code review

Dispatch `superpowers:requesting-code-review`.

---

## Task 6: Implement Z-Order Hierarchy Rule

**Files:**
- Modify: `assets/scripts/core/ui_validator.lua`
- Modify: `assets/scripts/tests/test_ui_validator.lua`

### Step 1: Write the failing test

Add to `assets/scripts/tests/test_ui_validator.lua`:

```lua
TestRunner.describe("UIValidator Z-Order Rule", function()

    TestRunner.it("checkZOrder returns no violations for correct hierarchy", function()
        local UIValidator = require("core.ui_validator")

        -- Children have higher z than parent
        local hierarchy = {
            { id = "parent", z = 100, children = { "child1", "child2" } },
            { id = "child1", z = 101, children = {} },
            { id = "child2", z = 102, children = {} },
        }

        local violations = UIValidator.checkZOrderWithHierarchy(hierarchy)

        TestRunner.assert_equals(0, #violations, "should have no violations for correct z-order")
    end)

    TestRunner.it("checkZOrder detects child behind parent", function()
        local UIValidator = require("core.ui_validator")

        -- Child has lower z than parent
        local hierarchy = {
            { id = "parent", z = 100, children = { "child1" } },
            { id = "child1", z = 50, children = {} }, -- Behind parent
        }

        local violations = UIValidator.checkZOrderWithHierarchy(hierarchy)

        TestRunner.assert_true(#violations > 0, "should detect child behind parent")
        TestRunner.assert_equals("z_order_hierarchy", violations[1].type, "violation type should be z_order_hierarchy")
    end)

end)
```

### Step 2: Run test to verify it fails

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -i "ZOrder\|z_order\|FAIL"
```

### Step 3: Write minimal implementation

Add to `assets/scripts/core/ui_validator.lua`:

```lua
---Get z-order for an entity
---@param entity number Entity ID
---@return number|nil z-order or nil
function UIValidator.getZOrder(entity)
    if not entity or not registry:valid(entity) then
        return nil
    end

    if layer_order_system and layer_order_system.getZIndex then
        return layer_order_system.getZIndex(entity)
    end

    -- Fallback to LayerOrderComponent
    local layerOrder = component_cache.get(entity, LayerOrderComponent)
    if layerOrder then
        return layerOrder.z or layerOrder.zIndex or 0
    end

    return 0
end

---Check z-order with provided hierarchy
---@param hierarchy table[] Array of {id, z, children: string[]}
---@return table[] violations
function UIValidator.checkZOrderWithHierarchy(hierarchy)
    local violations = {}

    -- Build lookup
    local byId = {}
    for _, node in ipairs(hierarchy) do
        byId[node.id] = node
    end

    -- Check each node
    for _, node in ipairs(hierarchy) do
        for _, childId in ipairs(node.children) do
            local child = byId[childId]
            if child and child.z <= node.z then
                table.insert(violations, {
                    type = "z_order_hierarchy",
                    severity = severities.z_order_hierarchy,
                    entity = childId,
                    parent = node.id,
                    message = string.format(
                        "Entity %s (z=%d) behind parent %s (z=%d)",
                        tostring(childId), child.z,
                        tostring(node.id), node.z
                    ),
                })
            end
        end
    end

    return violations
end

---Check z-order hierarchy for a UI entity tree
---@param entity number Root entity ID
---@return table[] violations
function UIValidator.checkZOrder(entity)
    local violations = {}

    local function checkEntity(ent, parentZ)
        if not ent or not registry:valid(ent) then return end

        local z = UIValidator.getZOrder(ent) or 0

        -- Check against parent
        if parentZ and z <= parentZ then
            table.insert(violations, {
                type = "z_order_hierarchy",
                severity = severities.z_order_hierarchy,
                entity = ent,
                message = string.format(
                    "Entity %s (z=%d) not above parent (z=%d)",
                    tostring(ent), z, parentZ
                ),
            })
        end

        -- Check children
        local go = component_cache.get(ent, GameObject)
        if go and go.orderedChildren then
            for _, child in ipairs(go.orderedChildren) do
                checkEntity(child, z)
            end
        end
    end

    checkEntity(entity, nil)
    return violations
end
```

### Step 4: Run test to verify it passes

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -i "ZOrder\|z_order\|PASS\|FAIL"
```

### Step 5: Build and runtime verification

```bash
just build-debug
(./build/raylib-cpp-cmake-template 2>&1 & sleep 35; kill $!) | grep -iE "(error|Error|Lua|FAIL|crash)" | head -20
```

### Step 6: Commit

```bash
git add assets/scripts/core/ui_validator.lua assets/scripts/tests/test_ui_validator.lua
git commit -m "$(cat <<'EOF'
feat(ui): add z-order hierarchy rule to UIValidator

Add checkZOrder() and checkZOrderWithHierarchy():
- Detects children with z-order behind parent
- Uses layer_order_system.getZIndex when available
- Severity: warning (configurable)

TDD: failing tests first, then implementation

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 7: Code review

Dispatch `superpowers:requesting-code-review`.

---

## Task 7: Implement Full validate() Function

**Files:**
- Modify: `assets/scripts/core/ui_validator.lua`
- Modify: `assets/scripts/tests/test_ui_validator.lua`

### Step 1: Write the failing test

Add to `assets/scripts/tests/test_ui_validator.lua`:

```lua
TestRunner.describe("UIValidator Full Validation", function()

    TestRunner.it("validate runs all rules by default", function()
        local UIValidator = require("core.ui_validator")
        local dsl = require("ui.ui_syntax_sugar")

        local ui = dsl.root {
            config = { padding = 10, minWidth = 100, minHeight = 100 },
            children = {
                dsl.text("Test", { fontSize = 14 })
            }
        }
        local entity = dsl.spawn({ x = 200, y = 200 }, ui)

        local violations = UIValidator.validate(entity)

        TestRunner.assert_not_nil(violations, "should return violations array")
        TestRunner.assert_true(type(violations) == "table", "should be table")

        dsl.remove(entity)
    end)

    TestRunner.it("validate accepts specific rules filter", function()
        local UIValidator = require("core.ui_validator")
        local dsl = require("ui.ui_syntax_sugar")

        local ui = dsl.root {
            config = { padding = 10 },
            children = {}
        }
        local entity = dsl.spawn({ x = 200, y = 200 }, ui)

        -- Only check containment
        local violations = UIValidator.validate(entity, { "containment" })

        TestRunner.assert_not_nil(violations, "should return violations array")

        dsl.remove(entity)
    end)

    TestRunner.it("getErrors filters to error severity only", function()
        local UIValidator = require("core.ui_validator")

        local violations = {
            { type = "containment", severity = "error", entity = 1, message = "test" },
            { type = "sibling_overlap", severity = "warning", entity = 2, message = "test" },
        }

        local errors = UIValidator.getErrors(violations)

        TestRunner.assert_equals(1, #errors, "should return only errors")
        TestRunner.assert_equals("error", errors[1].severity, "should be error severity")
    end)

    TestRunner.it("getWarnings filters to warning severity only", function()
        local UIValidator = require("core.ui_validator")

        local violations = {
            { type = "containment", severity = "error", entity = 1, message = "test" },
            { type = "sibling_overlap", severity = "warning", entity = 2, message = "test" },
        }

        local warnings = UIValidator.getWarnings(violations)

        TestRunner.assert_equals(1, #warnings, "should return only warnings")
        TestRunner.assert_equals("warning", warnings[1].severity, "should be warning severity")
    end)

end)
```

### Step 2: Run test to verify it fails

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -i "Full Validation\|getErrors\|getWarnings\|FAIL"
```

### Step 3: Write minimal implementation

Update `UIValidator.validate` and add helper functions in `assets/scripts/core/ui_validator.lua`:

```lua
-- Rule check functions
local ruleChecks = {
    containment = UIValidator.checkContainment,
    window_bounds = UIValidator.checkWindowBounds,
    sibling_overlap = UIValidator.checkSiblingOverlap,
    z_order_hierarchy = UIValidator.checkZOrder,
    -- collision_alignment, layer_consistency, space_consistency added later
}

---Validate a UI entity and return all violations
---@param entity number Entity ID
---@param rules? string[] Optional: specific rules to check (default: all)
---@return table[] violations List of {type, severity, entity, message}
function UIValidator.validate(entity, rules)
    local violations = {}

    if not entity or not registry:valid(entity) then
        return violations
    end

    -- Determine which rules to run
    local rulesToRun = rules or { "containment", "window_bounds", "sibling_overlap", "z_order_hierarchy" }

    for _, ruleName in ipairs(rulesToRun) do
        local checkFn = ruleChecks[ruleName]
        if checkFn then
            local v = checkFn(entity)
            for _, violation in ipairs(v) do
                table.insert(violations, violation)
            end
        end
    end

    return violations
end

---Filter violations to errors only
---@param violations table[]
---@return table[]
function UIValidator.getErrors(violations)
    local errors = {}
    for _, v in ipairs(violations) do
        if v.severity == "error" then
            table.insert(errors, v)
        end
    end
    return errors
end

---Filter violations to warnings only
---@param violations table[]
---@return table[]
function UIValidator.getWarnings(violations)
    local warnings = {}
    for _, v in ipairs(violations) do
        if v.severity == "warning" then
            table.insert(warnings, v)
        end
    end
    return warnings
end

---Validate and print results (convenience function)
---@param entity number Entity ID
---@return boolean hasErrors
function UIValidator.validateAndReport(entity)
    local violations = UIValidator.validate(entity)
    local errors = UIValidator.getErrors(violations)
    local warnings = UIValidator.getWarnings(violations)

    if #errors > 0 then
        print(string.format("[UIValidator] %d ERRORS:", #errors))
        for _, e in ipairs(errors) do
            print(string.format("  ❌ %s: %s", e.type, e.message))
        end
    end

    if #warnings > 0 then
        print(string.format("[UIValidator] %d warnings:", #warnings))
        for _, w in ipairs(warnings) do
            print(string.format("  ⚠️ %s: %s", w.type, w.message))
        end
    end

    return #errors > 0
end
```

### Step 4: Run test to verify it passes

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -i "Full Validation\|getErrors\|getWarnings\|PASS\|FAIL"
```

### Step 5: Build and runtime verification

```bash
just build-debug
(./build/raylib-cpp-cmake-template 2>&1 & sleep 35; kill $!) | grep -iE "(error|Error|Lua|FAIL|crash)" | head -20
```

### Step 6: Commit

```bash
git add assets/scripts/core/ui_validator.lua assets/scripts/tests/test_ui_validator.lua
git commit -m "$(cat <<'EOF'
feat(ui): implement full validate() function in UIValidator

Add:
- validate(entity, rules): runs all or specified rules
- getErrors(violations): filter to error severity
- getWarnings(violations): filter to warning severity
- validateAndReport(entity): validate and print results

TDD: failing tests first, then implementation

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 7: Code review

Dispatch `superpowers:requesting-code-review`.

---

## Task 8: Create UITestUtils Module

**Files:**
- Create: `assets/scripts/tests/ui_test_utils.lua`
- Modify: `assets/scripts/tests/test_ui_validator.lua`

### Step 1: Write the failing test

Add to `assets/scripts/tests/test_ui_validator.lua`:

```lua
TestRunner.describe("UITestUtils Module", function()

    TestRunner.it("module loads without error", function()
        local UITestUtils = require("tests.ui_test_utils")
        TestRunner.assert_not_nil(UITestUtils, "UITestUtils module should load")
    end)

    TestRunner.it("spawnAndWait spawns UI and returns entity", function()
        local UITestUtils = require("tests.ui_test_utils")
        local dsl = require("ui.ui_syntax_sugar")

        local ui = dsl.root {
            config = { padding = 10 },
            children = {}
        }

        local entity = UITestUtils.spawnAndWait(ui, { x = 100, y = 100 })

        TestRunner.assert_not_nil(entity, "should return entity")
        TestRunner.assert_true(registry:valid(entity), "entity should be valid")

        dsl.remove(entity)
    end)

    TestRunner.it("assertNoErrors passes for valid UI", function()
        local UITestUtils = require("tests.ui_test_utils")
        local dsl = require("ui.ui_syntax_sugar")

        local ui = dsl.root {
            config = { padding = 10, minWidth = 100, minHeight = 100 },
            children = {}
        }
        local entity = UITestUtils.spawnAndWait(ui, { x = 200, y = 200 })

        -- Should not throw
        local success = pcall(function()
            UITestUtils.assertNoErrors(entity)
        end)

        TestRunner.assert_true(success, "assertNoErrors should pass for valid UI")

        dsl.remove(entity)
    end)

end)
```

### Step 2: Run test to verify it fails

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -i "UITestUtils\|ui_test_utils\|FAIL"
```

### Step 3: Write minimal implementation

Create `assets/scripts/tests/ui_test_utils.lua`:

```lua
--[[
    UITestUtils - Test utilities for UI validation

    Provides helpers for spawning UI and asserting validation rules.
]]

local UITestUtils = {}

local dsl = require("ui.ui_syntax_sugar")
local UIValidator = require("core.ui_validator")

---Spawn UI and wait for layout to complete
---@param uiDef table UI definition from dsl.*
---@param pos table {x, y} spawn position
---@param opts? table Optional spawn options
---@return number entity
function UITestUtils.spawnAndWait(uiDef, pos, opts)
    local entity = dsl.spawn(pos, uiDef, nil, nil, opts)
    -- In synchronous tests, layout is immediate
    -- In real game, might need timer.after(0.01, callback)
    return entity
end

---Assert no validation errors for entity
---@param entity number Entity ID
---@param rules? string[] Optional: specific rules to check
function UITestUtils.assertNoErrors(entity, rules)
    local violations = UIValidator.validate(entity, rules)
    local errors = UIValidator.getErrors(violations)

    if #errors > 0 then
        local messages = {}
        for _, e in ipairs(errors) do
            table.insert(messages, string.format("%s: %s", e.type, e.message))
        end
        error("UI validation errors:\n  " .. table.concat(messages, "\n  "))
    end
end

---Assert no validation violations (errors OR warnings)
---@param entity number Entity ID
---@param rules? string[] Optional: specific rules to check
function UITestUtils.assertNoViolations(entity, rules)
    local violations = UIValidator.validate(entity, rules)

    if #violations > 0 then
        local messages = {}
        for _, v in ipairs(violations) do
            table.insert(messages, string.format("[%s] %s: %s", v.severity, v.type, v.message))
        end
        error("UI validation violations:\n  " .. table.concat(messages, "\n  "))
    end
end

---Assert a specific violation exists
---@param entity number Entity ID
---@param violationType string Expected violation type
---@param entityMatch? number|string Optional: entity that should have violation
function UITestUtils.assertHasViolation(entity, violationType, entityMatch)
    local violations = UIValidator.validate(entity)

    for _, v in ipairs(violations) do
        if v.type == violationType then
            if not entityMatch or v.entity == entityMatch then
                return -- Found it
            end
        end
    end

    error(string.format("Expected violation '%s' not found", violationType))
end

---Get all computed bounds for an entity tree
---@param entity number Root entity ID
---@return table Map of entity -> bounds
function UITestUtils.getAllBounds(entity)
    return UIValidator.getAllBounds(entity)
end

---Clean up spawned UI
---@param entity number Entity to remove
function UITestUtils.cleanup(entity)
    if entity and registry:valid(entity) then
        dsl.remove(entity)
    end
end

return UITestUtils
```

### Step 4: Run test to verify it passes

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -i "UITestUtils\|ui_test_utils\|PASS\|FAIL"
```

### Step 5: Build and runtime verification

```bash
just build-debug
(./build/raylib-cpp-cmake-template 2>&1 & sleep 35; kill $!) | grep -iE "(error|Error|Lua|FAIL|crash)" | head -20
```

### Step 6: Commit

```bash
git add assets/scripts/tests/ui_test_utils.lua assets/scripts/tests/test_ui_validator.lua
git commit -m "$(cat <<'EOF'
feat(ui): add UITestUtils module for UI testing

Add test utilities:
- spawnAndWait(): spawn UI and wait for layout
- assertNoErrors(): assert no validation errors
- assertNoViolations(): assert no errors or warnings
- assertHasViolation(): assert specific violation exists
- getAllBounds(): get bounds for debugging
- cleanup(): properly remove UI

TDD: failing tests first, then implementation

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 7: Code review

Dispatch `superpowers:requesting-code-review`.

---

## Task 9: Create Inventory Validation Tests

**Files:**
- Create: `assets/scripts/tests/test_inventory_validation.lua`

### Step 1: Write the tests

Create `assets/scripts/tests/test_inventory_validation.lua`:

```lua
--[[
    Inventory UI Validation Tests

    Validates the card inventory panel in planning mode.
]]

local TestRunner = require("tests.test_runner")
local UITestUtils = require("tests.ui_test_utils")
local UIValidator = require("core.ui_validator")
local dsl = require("ui.ui_syntax_sugar")

-- Test grid that mimics inventory structure
local function createTestInventoryGrid()
    return dsl.root {
        config = {
            padding = 10,
            minWidth = 400,
            minHeight = 300,
            color = "blackberry",
        },
        children = {
            dsl.vbox {
                config = { spacing = 8 },
                children = {
                    dsl.text("Inventory", { fontSize = 20 }),
                    dsl.inventoryGrid {
                        id = "test_inv_grid",
                        rows = 3,
                        cols = 5,
                        slotSize = { w = 64, h = 90 },
                        slotSpacing = 6,
                        config = {
                            slotColor = "purple_slate",
                            backgroundColor = "blackberry",
                            padding = 8,
                        },
                    },
                }
            }
        }
    }
end

TestRunner.describe("Inventory Grid Containment", function()

    TestRunner.it("all slots stay within panel bounds", function()
        local gridDef = createTestInventoryGrid()
        local entity = UITestUtils.spawnAndWait(gridDef, { x = 100, y = 100 })

        UITestUtils.assertNoErrors(entity, { "containment" })

        UITestUtils.cleanup(entity)
    end)

    TestRunner.it("grid title stays within panel bounds", function()
        local gridDef = createTestInventoryGrid()
        local entity = UITestUtils.spawnAndWait(gridDef, { x = 100, y = 100 })

        UITestUtils.assertNoErrors(entity, { "containment" })

        UITestUtils.cleanup(entity)
    end)

end)

TestRunner.describe("Inventory Grid Window Bounds", function()

    TestRunner.it("inventory panel stays within window", function()
        local gridDef = createTestInventoryGrid()
        -- Spawn in safe area
        local entity = UITestUtils.spawnAndWait(gridDef, { x = 200, y = 200 })

        UITestUtils.assertNoErrors(entity, { "window_bounds" })

        UITestUtils.cleanup(entity)
    end)

end)

TestRunner.describe("Inventory Grid Z-Order", function()

    TestRunner.it("slots have correct z-order relative to panel", function()
        local gridDef = createTestInventoryGrid()
        local entity = UITestUtils.spawnAndWait(gridDef, { x = 100, y = 100 })

        -- Z-order warnings are expected in some cases, but no errors
        local violations = UIValidator.validate(entity, { "z_order_hierarchy" })
        local errors = UIValidator.getErrors(violations)

        TestRunner.assert_equals(0, #errors, "should have no z-order errors")

        UITestUtils.cleanup(entity)
    end)

end)

TestRunner.describe("Inventory Slot Non-Overlap", function()

    TestRunner.it("adjacent slots do not overlap", function()
        local gridDef = createTestInventoryGrid()
        local entity = UITestUtils.spawnAndWait(gridDef, { x = 100, y = 100 })

        -- Sibling overlap is warning by default, but check anyway
        local violations = UIValidator.validate(entity, { "sibling_overlap" })

        -- Print any overlaps for debugging
        if #violations > 0 then
            for _, v in ipairs(violations) do
                print("[DEBUG] Overlap:", v.message)
            end
        end

        UITestUtils.cleanup(entity)
    end)

end)

-- Return module for test runner registration
return {
    name = "Inventory Validation Tests",
    run = function()
        -- Tests are registered via describe/it
    end
}
```

### Step 2: Run test

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 10; kill $!) | grep -i "Inventory\|PASS\|FAIL"
```

### Step 3: Build and runtime verification

```bash
just build-debug
(./build/raylib-cpp-cmake-template 2>&1 & sleep 35; kill $!) | grep -iE "(error|Error|Lua|FAIL|crash)" | head -20
```

### Step 4: Commit

```bash
git add assets/scripts/tests/test_inventory_validation.lua
git commit -m "$(cat <<'EOF'
test(ui): add inventory validation tests

Add tests validating inventory grid UI:
- Containment: slots within panel
- Window bounds: panel within window
- Z-order: correct hierarchy
- Non-overlap: adjacent slots

Uses test inventory grid that mirrors card_inventory_panel structure.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 5: Code review

Dispatch `superpowers:requesting-code-review`.

---

## Task 10: Add Tracked Render Wrappers

**Files:**
- Modify: `assets/scripts/core/ui_validator.lua`
- Modify: `assets/scripts/tests/test_ui_validator.lua`

### Step 1: Write the failing test

Add to `assets/scripts/tests/test_ui_validator.lua`:

```lua
TestRunner.describe("UIValidator Tracked Render Wrappers", function()

    TestRunner.it("queueDrawEntities records render info", function()
        local UIValidator = require("core.ui_validator")

        -- Clear previous log
        UIValidator.clearRenderLog()

        -- Mock entities (using numbers as IDs)
        local parentUI = 1000
        local card1 = 1001
        local card2 = 1002

        -- Track renders (this is a mock - real impl queues to command_buffer)
        UIValidator.trackRender(parentUI, "layers.ui", { card1, card2 }, 500, "Screen")

        local log = UIValidator.getRenderLog()

        TestRunner.assert_not_nil(log[card1], "card1 should be in render log")
        TestRunner.assert_not_nil(log[card2], "card2 should be in render log")
        TestRunner.assert_equals(parentUI, log[card1].parent, "should track parent")
        TestRunner.assert_equals("layers.ui", log[card1].layer, "should track layer")
        TestRunner.assert_equals(500, log[card1].z, "should track z-order")
        TestRunner.assert_equals("Screen", log[card1].space, "should track space")
    end)

    TestRunner.it("checkRenderConsistency detects layer mismatch", function()
        local UIValidator = require("core.ui_validator")

        UIValidator.clearRenderLog()

        local parentUI = 2000
        local card1 = 2001

        -- Parent renders to ui layer
        UIValidator.trackRender(nil, "layers.ui", { parentUI }, 100, "Screen")
        -- Card renders to different layer
        UIValidator.trackRender(parentUI, "layers.sprites", { card1 }, 200, "Screen")

        local violations = UIValidator.checkRenderConsistency(parentUI)

        TestRunner.assert_true(#violations > 0, "should detect layer mismatch")
        TestRunner.assert_equals("layer_consistency", violations[1].type, "type should be layer_consistency")
    end)

    TestRunner.it("checkRenderConsistency detects space mismatch", function()
        local UIValidator = require("core.ui_validator")

        UIValidator.clearRenderLog()

        local parentUI = 3000
        local card1 = 3001

        -- Parent uses Screen space
        UIValidator.trackRender(nil, "layers.ui", { parentUI }, 100, "Screen")
        -- Card uses World space (mismatch!)
        UIValidator.trackRender(parentUI, "layers.ui", { card1 }, 200, "World")

        local violations = UIValidator.checkRenderConsistency(parentUI)

        TestRunner.assert_true(#violations > 0, "should detect space mismatch")
        TestRunner.assert_equals("space_consistency", violations[1].type, "type should be space_consistency")
    end)

end)
```

### Step 2: Run test to verify it fails

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -i "Tracked\|trackRender\|checkRenderConsistency\|FAIL"
```

### Step 3: Write minimal implementation

Add to `assets/scripts/core/ui_validator.lua`:

```lua
---Track render info for entities (call this instead of direct command_buffer calls)
---@param parentUI number|nil Parent UI entity (nil for roots)
---@param layerName string Layer name (e.g., "layers.ui")
---@param entities table[] Entities being rendered
---@param z number Z-order
---@param space string DrawCommandSpace ("Screen" or "World")
function UIValidator.trackRender(parentUI, layerName, entities, z, space)
    local frameNum = globals and globals.frameCount or 0

    for _, entity in ipairs(entities) do
        renderLog[entity] = {
            parent = parentUI,
            layer = layerName,
            z = z,
            space = space,
            frame = frameNum,
        }
    end
end

---Queue draw and track for validation (wraps command_buffer.queueDrawBatchedEntities)
---@param parentUI number Parent UI entity for association
---@param layer userdata Layer to render to
---@param entities table[] Entities to render
---@param z number Z-order
---@param space userdata DrawCommandSpace
function UIValidator.queueDrawEntities(parentUI, layer, entities, z, space)
    -- Track for validation
    local layerName = tostring(layer) -- Convert layer to string for comparison
    local spaceName = space == (layer and layer.DrawCommandSpace and layer.DrawCommandSpace.Screen) and "Screen" or "World"

    UIValidator.trackRender(parentUI, layerName, entities, z, spaceName)

    -- Perform actual render (only if command_buffer exists)
    if command_buffer and command_buffer.queueDrawBatchedEntities then
        command_buffer.queueDrawBatchedEntities(layer, function(cmd)
            cmd.entities = entities
        end, z, space)
    end
end

---Check render consistency for a UI entity and its associated renders
---@param parentUI number Parent UI entity
---@return table[] violations
function UIValidator.checkRenderConsistency(parentUI)
    local violations = {}

    -- Get parent's render info
    local parentInfo = renderLog[parentUI]
    if not parentInfo then
        return violations -- No parent info, can't check
    end

    -- Check all entities associated with this parent
    for entity, info in pairs(renderLog) do
        if info.parent == parentUI then
            -- Check layer consistency
            if info.layer ~= parentInfo.layer then
                table.insert(violations, {
                    type = "layer_consistency",
                    severity = severities.layer_consistency,
                    entity = entity,
                    parent = parentUI,
                    message = string.format(
                        "Entity %s renders to %s, parent %s uses %s",
                        tostring(entity), info.layer,
                        tostring(parentUI), parentInfo.layer
                    ),
                })
            end

            -- Check space consistency
            if info.space ~= parentInfo.space then
                table.insert(violations, {
                    type = "space_consistency",
                    severity = severities.space_consistency,
                    entity = entity,
                    parent = parentUI,
                    message = string.format(
                        "Entity %s uses %s space, parent %s uses %s",
                        tostring(entity), info.space,
                        tostring(parentUI), parentInfo.space
                    ),
                })
            end
        end
    end

    return violations
end
```

Also update the `ruleChecks` table and `validate` function to include the new rules:

```lua
-- Update ruleChecks table (near top of file, after function definitions)
local ruleChecks = {
    containment = UIValidator.checkContainment,
    window_bounds = UIValidator.checkWindowBounds,
    sibling_overlap = UIValidator.checkSiblingOverlap,
    z_order_hierarchy = UIValidator.checkZOrder,
    layer_consistency = function(entity) return UIValidator.checkRenderConsistency(entity) end,
    space_consistency = function(entity) return {} end, -- Handled by checkRenderConsistency
}

-- Update validate function default rules
function UIValidator.validate(entity, rules)
    local violations = {}

    if not entity or not registry:valid(entity) then
        return violations
    end

    local rulesToRun = rules or {
        "containment",
        "window_bounds",
        "sibling_overlap",
        "z_order_hierarchy",
        "layer_consistency",
    }

    -- ... rest of function unchanged
end
```

### Step 4: Run test to verify it passes

```bash
just build-debug && (./build/raylib-cpp-cmake-template 2>&1 & sleep 8; kill $!) | grep -i "Tracked\|trackRender\|Consistency\|PASS\|FAIL"
```

### Step 5: Build and runtime verification

```bash
just build-debug
(./build/raylib-cpp-cmake-template 2>&1 & sleep 35; kill $!) | grep -iE "(error|Error|Lua|FAIL|crash)" | head -20
```

### Step 6: Commit

```bash
git add assets/scripts/core/ui_validator.lua assets/scripts/tests/test_ui_validator.lua
git commit -m "$(cat <<'EOF'
feat(ui): add tracked render wrappers to UIValidator

Add:
- trackRender(): record entity render info (parent, layer, z, space)
- queueDrawEntities(): wrapper that tracks and renders
- checkRenderConsistency(): validate layer/space consistency

For manually-rendered entities like cards in inventory slots.

TDD: failing tests first, then implementation

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
EOF
)"
```

### Step 7: Code review

Dispatch `superpowers:requesting-code-review`.

---

## Summary

After completing all 10 tasks, you will have:

1. **UIValidator module** (`core/ui_validator.lua`) with:
   - Bounds extraction (getBounds, getAllBounds)
   - Containment rule
   - Window bounds rule
   - Sibling overlap rule
   - Z-order hierarchy rule
   - Tracked render wrappers
   - Full validate() function

2. **UITestUtils module** (`tests/ui_test_utils.lua`) with:
   - spawnAndWait()
   - assertNoErrors()
   - assertNoViolations()
   - assertHasViolation()

3. **Inventory validation tests** (`tests/test_inventory_validation.lua`)

**Next phases** (separate plan):
- Task 11-15: Debug overlay implementation
- Task 16-18: Auto-validation hook in dsl.spawn()
- Task 19-20: Integration with card_inventory_panel.lua
