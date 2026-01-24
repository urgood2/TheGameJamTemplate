# Implementation Plan: Enhanced ChildBuilder Positioning API

**Created**: 2026-01-24
**Status**: Approved, Ready for Implementation
**Decisions**: Default outside, no auto-centering, naming as proposed

---

## Executive Summary

The C++ transform system **already fully supports** edge-based alignment via `InheritedProperties::Alignment` flags and `ConfigureAlignment()`. The problem is simply that **ChildBuilder doesn't expose this capability** - it only uses `AssignRole()` with raw offsets.

**Solution**: Extend ChildBuilder with fluent methods that map to the existing C++ alignment system, requiring **zero C++ changes**.

---

## 1. Current State Analysis

### What ChildBuilder Does Now
```lua
-- ChildBuilder.apply() calls:
transform.AssignRole(registry, child, roleType, parent, locationBond, sizeBond, rotationBond, scaleBond, offset)
```
- Uses `AssignRole()` which only sets raw offset
- Does NOT use `ConfigureAlignment()` which accepts alignment flags

### What C++ Already Supports
```cpp
// Alignment flags already exist:
HORIZONTAL_LEFT, HORIZONTAL_CENTER, HORIZONTAL_RIGHT
VERTICAL_TOP, VERTICAL_CENTER, VERTICAL_BOTTOM
ALIGN_TO_INNER_EDGES

// And are exposed to Lua:
transform.ConfigureAlignment(registry, e, isChild, parent, xy, wh, rotation, scale, alignment, offset)
```

The alignment calculation logic (transform_functions.cpp:289-350) already handles:
- Inside vs outside edge positioning based on `ALIGN_TO_INNER_EDGES`
- Auto-adjustment when parent size changes
- Fine-tuning via `extraAlignmentFinetuningOffset`

---

## 2. Proposed API Design

### Final API (Approved)

```lua
-- Health bar above enemy (default outside, explicit center)
ChildBuilder.for_entity(healthBar)
    :attachTo(enemy)
    :anchor("top")
    :anchorCenterX()      -- Must be explicit (no auto-centering)
    :gapY(-5)             -- 5px gap above
    :apply()

-- Badge in top-right corner of card (explicit inside)
ChildBuilder.for_entity(badge)
    :attachTo(card)
    :anchor("top", "right")
    :inside()             -- Required for inside positioning
    :gap(-4, 4)           -- padding from corner
    :apply()

-- Weapon on player's right side
ChildBuilder.for_entity(weapon)
    :attachTo(player)
    :anchor("right")
    :rotateWith()
    :apply()

-- Shadow below sprite (inside, at bottom)
ChildBuilder.for_entity(shadow)
    :attachTo(sprite)
    :anchor("bottom")
    :anchorCenterX()
    :inside()
    :gapY(5)
    :apply()
```

### Design Decisions
1. **Default Outside**: When `:inside()` not called, positions outside parent bounds
2. **No Auto-Centering**: `:anchor("top")` alone does NOT auto-center horizontally; requires explicit `:anchorCenterX()`
3. **Naming**: Keep `:gap()`, `:anchor()`, `:inside()`/`:outside()` as proposed

---

## 3. New API Surface

### New Builder State Fields

```lua
-- Add to ChildBuilder.for_entity():
{
    -- ... existing fields ...
    _alignment = 0,           -- bitmask: combination of AlignmentFlag values
    _alignInside = false,     -- whether to use ALIGN_TO_INNER_EDGES (default: false = outside)
    _gap = { x = 0, y = 0 },  -- extraAlignmentFinetuningOffset
}
```

### New Methods

| Method | Description | Alignment Flags Set |
|--------|-------------|-------------------|
| `:anchor(v, h)` | Set anchor point(s) by string | Varies by args |
| `:anchorTop()` | Anchor to parent's top edge | `VERTICAL_TOP` |
| `:anchorBottom()` | Anchor to parent's bottom edge | `VERTICAL_BOTTOM` |
| `:anchorLeft()` | Anchor to parent's left edge | `HORIZONTAL_LEFT` |
| `:anchorRight()` | Anchor to parent's right edge | `HORIZONTAL_RIGHT` |
| `:anchorCenterX()` | Center horizontally | `HORIZONTAL_CENTER` |
| `:anchorCenterY()` | Center vertically | `VERTICAL_CENTER` |
| `:anchorCenter()` | Center both axes | `HORIZONTAL_CENTER \| VERTICAL_CENTER` |
| `:inside()` | Position inside parent bounds | Adds `ALIGN_TO_INNER_EDGES` |
| `:outside()` | Position outside parent bounds (default) | Removes `ALIGN_TO_INNER_EDGES` |
| `:gap(x, y)` | Fine-tune offset after alignment | Sets `extraAlignmentFinetuningOffset` |
| `:gapX(x)` | Fine-tune X offset | |
| `:gapY(y)` | Fine-tune Y offset | |

### Convenience Shorthand Methods

```lua
:anchorTopCenter()     -- :anchorTop():anchorCenterX()
:anchorBottomCenter()  -- :anchorBottom():anchorCenterX()
:anchorLeftCenter()    -- :anchorLeft():anchorCenterY()
:anchorRightCenter()   -- :anchorRight():anchorCenterY()
:anchorTopLeft()       -- :anchorTop():anchorLeft()
:anchorTopRight()      -- :anchorTop():anchorRight()
:anchorBottomLeft()    -- :anchorBottom():anchorLeft()
:anchorBottomRight()   -- :anchorBottom():anchorRight()
```

---

## 4. Implementation Steps

### Step 1: Add Alignment State to Builder (child_builder.lua:67-78)

**File**: `assets/scripts/core/child_builder.lua`
**Location**: Inside `ChildBuilder.for_entity()` function

Add new fields to the builder instance:
- `_alignment = 0` (bitmask)
- `_alignInside = false` (default outside)
- `_gap = { x = 0, y = 0 }`

### Step 2: Implement String-Based `:anchor()` Method

**File**: `assets/scripts/core/child_builder.lua`
**Location**: After `:offset()` method (~line 95)

```lua
local ANCHOR_MAP = {
    top = AlignmentFlag.VERTICAL_TOP,
    bottom = AlignmentFlag.VERTICAL_BOTTOM,
    left = AlignmentFlag.HORIZONTAL_LEFT,
    right = AlignmentFlag.HORIZONTAL_RIGHT,
    centerx = AlignmentFlag.HORIZONTAL_CENTER,
    centery = AlignmentFlag.VERTICAL_CENTER,
    center = AlignmentFlag.HORIZONTAL_CENTER + AlignmentFlag.VERTICAL_CENTER,
}

function ChildBuilder:anchor(...)
    local args = {...}
    for _, arg in ipairs(args) do
        local flag = ANCHOR_MAP[string.lower(arg)]
        if flag then
            self._alignment = bit.bor(self._alignment, flag)
        end
    end
    return self
end
```

### Step 3: Implement Explicit Anchor Methods

**File**: `assets/scripts/core/child_builder.lua`

```lua
function ChildBuilder:anchorTop()
    self._alignment = bit.bor(self._alignment, AlignmentFlag.VERTICAL_TOP)
    return self
end

function ChildBuilder:anchorBottom()
    self._alignment = bit.bor(self._alignment, AlignmentFlag.VERTICAL_BOTTOM)
    return self
end

function ChildBuilder:anchorLeft()
    self._alignment = bit.bor(self._alignment, AlignmentFlag.HORIZONTAL_LEFT)
    return self
end

function ChildBuilder:anchorRight()
    self._alignment = bit.bor(self._alignment, AlignmentFlag.HORIZONTAL_RIGHT)
    return self
end

function ChildBuilder:anchorCenterX()
    self._alignment = bit.bor(self._alignment, AlignmentFlag.HORIZONTAL_CENTER)
    return self
end

function ChildBuilder:anchorCenterY()
    self._alignment = bit.bor(self._alignment, AlignmentFlag.VERTICAL_CENTER)
    return self
end

function ChildBuilder:anchorCenter()
    self._alignment = bit.bor(self._alignment, AlignmentFlag.HORIZONTAL_CENTER, AlignmentFlag.VERTICAL_CENTER)
    return self
end
```

### Step 4: Implement `:inside()` / `:outside()` Methods

```lua
function ChildBuilder:inside()
    self._alignInside = true
    return self
end

function ChildBuilder:outside()
    self._alignInside = false
    return self
end
```

### Step 5: Implement `:gap()` Methods

```lua
function ChildBuilder:gap(x, y)
    self._gap = { x = x or 0, y = y or 0 }
    return self
end

function ChildBuilder:gapX(x)
    self._gap.x = x or 0
    return self
end

function ChildBuilder:gapY(y)
    self._gap.y = y or 0
    return self
end
```

### Step 6: Update `:apply()` to Use ConfigureAlignment

**File**: `assets/scripts/core/child_builder.lua`
**Location**: `ChildBuilder:apply()` function (~line 159-220)

Change from:
```lua
transform.AssignRole(registry, self._entity, self._roleType, self._parent, ...)
```

To:
```lua
-- Build final alignment flags
local finalAlignment = self._alignment
if self._alignInside then
    finalAlignment = bit.bor(finalAlignment, AlignmentFlag.ALIGN_TO_INNER_EDGES)
end

-- If any alignment is set, use ConfigureAlignment
if finalAlignment ~= 0 then
    transform.ConfigureAlignment(
        registry,
        self._entity,
        true,  -- isChild
        self._parent,
        self._locationBond or InheritedPropertiesSync.Strong,
        self._sizeBond,
        self._rotationBond,
        self._scaleBond,
        finalAlignment,
        Vector2 { x = self._gap.x, y = self._gap.y }
    )
else
    -- Fall back to AssignRole for backward compatibility (offset-only)
    transform.AssignRole(
        registry, self._entity, self._roleType, self._parent,
        self._locationBond or InheritedPropertiesSync.Strong,
        self._sizeBond, self._rotationBond, self._scaleBond,
        Vector2 { x = self._offset.x, y = self._offset.y }
    )
end
```

### Step 7: Add Convenience Shorthand Methods

```lua
function ChildBuilder:anchorTopCenter()
    return self:anchorTop():anchorCenterX()
end

function ChildBuilder:anchorBottomCenter()
    return self:anchorBottom():anchorCenterX()
end

function ChildBuilder:anchorLeftCenter()
    return self:anchorLeft():anchorCenterY()
end

function ChildBuilder:anchorRightCenter()
    return self:anchorRight():anchorCenterY()
end

function ChildBuilder:anchorTopLeft()
    return self:anchorTop():anchorLeft()
end

function ChildBuilder:anchorTopRight()
    return self:anchorTop():anchorRight()
end

function ChildBuilder:anchorBottomLeft()
    return self:anchorBottom():anchorLeft()
end

function ChildBuilder:anchorBottomRight()
    return self:anchorBottom():anchorRight()
end
```

### Step 8: Add Static Helper for Re-anchoring

```lua
--- Re-anchor an existing attached entity
--- @param entity number The child entity
--- @param anchor string|table The anchor position ("top", "bottom", etc.) or table {"top", "center"}
--- @param inside boolean|nil Whether to anchor inside parent bounds (default: false)
--- @param gap table|nil Optional {x, y} gap offset
function ChildBuilder.setAnchor(entity, anchor, inside, gap)
    local ip = component_cache.get(entity, InheritedProperties)
    if not ip or not ip.flags then
        print("[ChildBuilder] Warning: entity has no InheritedProperties")
        return entity
    end
    
    -- Clear existing alignment
    ip.flags.alignment = 0
    
    -- Parse anchor argument
    local anchors = type(anchor) == "table" and anchor or {anchor}
    for _, a in ipairs(anchors) do
        local flag = ANCHOR_MAP[string.lower(a)]
        if flag then
            ip.flags.alignment = bit.bor(ip.flags.alignment, flag)
        end
    end
    
    -- Apply inside/outside
    if inside then
        ip.flags.alignment = bit.bor(ip.flags.alignment, AlignmentFlag.ALIGN_TO_INNER_EDGES)
    end
    
    -- Apply gap
    if gap then
        ip.flags.extraAlignmentFinetuningOffset = Vector2 { x = gap.x or 0, y = gap.y or 0 }
    end
    
    return entity
end
```

---

## 5. Backward Compatibility

**Critical**: Existing code using `:offset()` must continue to work unchanged.

**Strategy**:
- If `_alignment == 0` (no anchor methods called), use existing `AssignRole()` with raw offset
- If alignment is set, use `ConfigureAlignment()` with gap as fine-tuning offset
- The `:offset()` method remains but is now for non-aligned positioning only

**Warning to add in docstring**: 
> "Note: `:offset()` and `:anchor()` are mutually exclusive. Use `:gap()` for fine-tuning anchor positions."

---

## 6. Testing Strategy

### Unit Tests for Each Use Case

| Test Case | Setup | Expected Behavior |
|-----------|-------|-------------------|
| Health bar above enemy | `:anchor("top"):anchorCenterX():gapY(-5)` | Child positioned above parent's top edge, centered, with 5px gap |
| Name label below character | `:anchor("bottom"):anchorCenterX()` | Child centered below parent |
| Weapon on right side | `:anchor("right"):rotateWith()` | Child to right of parent, rotates with parent |
| Badge in card corner | `:anchor("top", "right"):inside():gap(-4, 4)` | Child in top-right corner inside parent |
| Shadow below sprite | `:anchor("bottom"):anchorCenterX():inside():gapY(5)` | Child at parent's bottom edge, inside, offset down |
| Dynamic resize test | Resize parent after attach | Child maintains anchor position |
| Backward compat | `:offset(10, 20)` only | Works exactly as before |

### Test File Location

Create: `assets/scripts/tests/test_child_builder_anchors.lua`

---

## 7. Work Breakdown

| Step | Task | Est. Lines |
|------|------|------------|
| 1 | Add `_alignment`, `_alignInside`, `_gap` state fields | ~5 |
| 2 | Implement `:anchor(...)` string parser with ANCHOR_MAP | ~20 |
| 3 | Implement 7 explicit anchor methods | ~25 |
| 4 | Implement `:inside()`/`:outside()` | ~8 |
| 5 | Implement `:gap()`, `:gapX()`, `:gapY()` | ~12 |
| 6 | Update `:apply()` to use `ConfigureAlignment` when anchors set | ~25 |
| 7 | Add 8 shorthand combo methods | ~16 |
| 8 | Add static `setAnchor()` helper | ~20 |
| 9 | Tests + documentation updates | ~150 |
| **Total** | | **~280 lines** |

---

## 8. Files Modified

| File | Changes |
|------|---------|
| `assets/scripts/core/child_builder.lua` | Add ~130 lines: new state, 15+ new methods, updated apply() |
| `assets/scripts/tests/test_child_builder_anchors.lua` | New file: ~150 lines of tests |

**No C++ changes required** - the alignment system is already fully exposed via Sol2.

---

## 9. Reference: C++ Alignment Flags

From `src/systems/transform/transform.hpp:299-309`:

```cpp
struct Alignment {
    static constexpr int NONE = 0;                      // 0b00000000
    static constexpr int HORIZONTAL_LEFT = 1 << 0;      // 0b00000001
    static constexpr int HORIZONTAL_CENTER = 1 << 1;    // 0b00000010
    static constexpr int HORIZONTAL_RIGHT = 1 << 2;     // 0b00000100
    static constexpr int VERTICAL_TOP = 1 << 3;         // 0b00001000
    static constexpr int VERTICAL_CENTER = 1 << 4;      // 0b00010000
    static constexpr int VERTICAL_BOTTOM = 1 << 5;      // 0b00100000
    static constexpr int ALIGN_TO_INNER_EDGES = 1 << 6; // 0b01000000
};
```

These are exposed to Lua as `AlignmentFlag.*` via Sol2 bindings in `transform_functions.cpp:2557-2563`.
