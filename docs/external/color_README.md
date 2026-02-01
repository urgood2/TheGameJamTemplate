# palette.lua — strict single‑palette registry (Lua)

A tiny, dependency‑free Lua module for games that use a **single fixed palette** and a C++ **Color** usertype (bound via sol2). You register once with a list of color names; the module resolves each name via `util.getColor(name) → Color` (your hook), then provides strict lookup, nearest‑color snapping (OKLab), and quantized ramps that never leave the palette.

> **C++ binding (expected):**
>
> ```cpp
> lua.new_usertype<Color>(
>   "Color",
>   sol::constructors<
>     Color(),
>     Color(unsigned char, unsigned char, unsigned char, unsigned char)
>   >(),
>   "r", &Color::r,
>   "g", &Color::g,
>   "b", &Color::b,
>   "a", &Color::a
> );
> ```

---

## Does color order matter?

**Yes, for indexing; no, for matching.**

* The order you pass `names = { ... }` is preserved. `palette.idx(i)` returns the *i‑th* swatch of that order, and `palette.list()` respects it.
* Strict name lookups (`palette.color("Peach")`) and nearest snapping are **order‑independent**.
* Ramps are by **name**, so order does not affect ramp endpoints (only your chosen names do).

---

## Installation

Copy `palette.lua` into your Lua path and ensure your project exposes:

```lua
-- util.lua
function util.getColor(name) -- -> Color usertype
  -- You provide this. Typically wraps a C++ registry or a name→hex map.
end
```

Require the module where needed:

```lua
local palette = require("palette")
```

---

## Quick start

```lua
local palette = require("palette")
local util    = require("util")  -- must implement util.getColor(name)

-- 1) Register once (order becomes your palette index order)
palette.register{
  names = {
    "Pastel Pink",
    "Peach",
    "Apricot Cream",
  }
}

-- 2) Strict lookups (return C++ Color usertypes)
local peach  = palette.color("Peach")
local first  = palette.idx(1)

-- 3) Nearest snap (always returns a palette Color)
local snapped = palette.snap("#F4A3B2")

-- 4) Quantized ramp: smooth in OKLab → snapped to discrete swatches
local ramp = palette.ramp_quantized("Pastel Pink", "Apricot Cream", 6)
for i,c in ipairs(ramp) do
  -- c is a Color usertype safe to pass to C++ draw calls
end

-- 5) Introspection (order preserved)
for _, s in ipairs(palette.list()) do
  -- s = { name = "apricot_cream", display = "Apricot Cream", color = <Color> }
end
```

---

## API

### `palette.register{ names = {...}, slugger? = fn }`

Registers the single active palette.

* **names**: list of display names (strings). Order defines `idx(i)` ordering.
* **slugger** (optional): function(name) → slug. Defaults to lowercased `[-A-Za-z0-9]+` → `_`.

> On registration, each name is resolved via `util.getColor(name)` to a **Color usertype**; we also cache a numeric `{r,g,b,a}` copy for distance math.

### `palette.color(name) -> Color`

Strict fetch by name (case/space‑insensitive via slug). Errors if not found.

### `palette.idx(i) -> Color`

1‑based index fetch. Errors if out of range.

### `palette.list() -> { {name, display, color=Color}, ... }`

Enumerate swatches in palette order.

### `palette.snap(color_like) -> Color`

Returns the nearest palette swatch using **OKLab** distance.

* Accepts a Color usertype, a `{r,g,b,a}` table, or a hex string `#RRGGBB` / `#RRGGBBAA` (also without `#`).

### `palette.ramp_quantized(nameA, nameB, steps) -> { Color, ... }`

Builds a perceptual ramp from color **A** to **B**:

1. positions are interpolated,
2. each step is **snapped** back to the nearest palette swatch.

### `palette.strict_contains(color_like) -> boolean`

Exact membership test (compares RGBA numerically).

### `palette.parse_hex(hex) -> Color`

Parses `#RRGGBB` or `#RRGGBBAA` (with or without `#`) into a **Color usertype** using your 4‑arg constructor.

---

## `util.getColor(name)` (you provide this)

`palette.register` calls `util.getColor(displayName) → Color` for each entry. Implement it however you like. Examples:

**A. Wrap a C++ registry (recommended for performance):**

```lua
-- util.lua (example)
local color_db = require("color_db") -- C++ module exposing get(name)->Color
function util.getColor(name)
  local c = color_db.get(name)
  assert(c, ("Unknown color name: %s"):format(tostring(name)))
  return c
end
```

**B. Lightweight Lua map (good for tests/tools):**

```lua
local map = {
  ["Pastel Pink"]  = Color(246,129,129,255),
  ["Peach"]        = Color(252,167,144,255),
  ["Apricot Cream"] = Color(253,203,176,255),
}
function util.getColor(name)
  local c = map[name]
  assert(c, "Unknown color: "..tostring(name))
  return c
end
```

---

## Strictness & pitfalls

* **Strict outputs:** All public getters return **palette members** only. `snap()` ensures that even arbitrary inputs end up on a valid swatch.
* **Equality:** We compare numeric channels, not identity of the usertype, so both `Color(1,2,3,255)` and a table `{1,2,3,255}` are treated the same.
* **Alpha handling:** If `util.getColor` omits `a`, we assume `255`. Ramps interpolate alpha as well before snapping.
* **Duplicates:** Two entries with identical RGBA are allowed, but **slug names must be unique** (or registration fails).

---

## Performance notes

* OKLab distance is computed against all swatches on demand. For medium palettes (≤256) this is trivial. If you later need more speed, pre‑bake a small 3D LUT or cache nearest hits by RGB quantization.
* All outputs are **Color usertypes**, ready for C++ draw calls—no conversion cost at the call site.

---

## FAQ

**Q: Can I add or remove colors after registration?**
A: Re‑register with a fresh `names` list. The module holds only one active palette.

**Q: Do I need to expose `Color()` to Lua?**
A: Yes. The module constructs usertypes in a few paths (hex parsing and when normalizing tables). It uses your 4‑arg constructor.

**Q: Can I get both the slug and display name?**
A: Use `palette.list()`; each entry has `name` (slug) and `display` (original string).

---

## License

Do whatever you want with this file. Attribution appreciated but not required.

<!-- Verified: 2026-01-30 against commit 8d9e2ea52 -->
