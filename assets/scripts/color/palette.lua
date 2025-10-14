--[[
palette.lua — Pure‑Lua strict palette registry (single active palette)

Compatibility:
• Returns **Color usertype** values (from your C++ binding) everywhere.
• Accepts Color usertypes or Lua tables {r,g,b,a} as inputs; always snaps/compares using numeric rgba.
• Uses your constructor: Color(unsigned char r, unsigned char g, unsigned char b, unsigned char a).
• Assumes you provide util.getColor(name) → Color (usertype) for source names.

Design:
• Single active palette only (no families/versions).
• Register once with a list of names; each name is resolved via util.getColor.
• Strict lookup by name or index.
• Nearest‑color snapping using OKLab distance (perceptual) within the active palette.
• Quantized ramps: interpolate between two named swatches, then snap each step back to the palette.

Public API (require("palette")):

  local id = palette.register{
    names   = {"Pastel Pink", "Peach", "Apricot Cream"},
    slugger = function(name) return custom_slug end,   -- optional
  }

  -- Lookups (return Color usertype):
  palette.color(name)          -- strict by name
  palette.idx(i)               -- 1-based by index
  palette.list()               -- { {name, display, color=Color}, ... }

  -- Utilities:
  palette.snap(color_or_hex)   -- nearest swatch Color (usertype)
  palette.ramp_quantized(aName, bName, steps) -- {Color, ...}
  palette.strict_contains(color_like)         -- exact membership test
  palette.parse_hex("#RRGGBBAA" or "#RRGGBB") -- → Color usertype

----------------------------------------------------------------------------]]

local palette = {}

-- Keep handle to the usertype constructor provided by C++ binding
--   Color(unsigned char r, unsigned char g, unsigned char b, unsigned char a)
local ColorCtor = Col

-- Internal state -------------------------------------------------------------
local _active = {
  swatches = nil,   -- array of swatch records
  byName   = nil,   -- slug -> index
}

-- Helpers -------------------------------------------------------------------
local function default_slug(name)
  local s = tostring(name):lower()
  s = s:gsub("[^%w]+", "_")
  s = s:gsub("^_+", ""):gsub("_+$", "")
  return s
end

-- Convert any Color‑like (usertype or table) into:
--   user : Color usertype to return/pass to C++
--   rgb  : plain table {r,g,b,a} for math
local function to_user_and_rgb(c)
  assert(c ~= nil, "Color value is nil")
  local t = type(c)
  if t == "userdata" then
    -- Assume fields r,g,b,a are readable
    local r, g, b, a = c.r, c.g, c.b, c.a or 255
    assert(type(r)=="number" and type(g)=="number" and type(b)=="number", "Invalid Color userdata")
    return c, { r=r, g=g, b=b, a=a }
  elseif t == "table" then
    local r, g, b, a = c.r, c.g, c.b, c.a or 255
    assert(type(r)=="number" and type(g)=="number" and type(b)=="number", "Invalid Color table")
    -- Build a usertype for outward compatibility
    return ColorCtor(r, g, b, a), { r=r, g=g, b=b, a=a }
  else
    error("Unsupported Color type: "..t)
  end
end

local function color_equals(a,b)
  return a.r==b.r and a.g==b.g and a.b==b.b and (a.a or 255)==(b.a or 255)
end

-- sRGB 0..255 → linear 0..1
local function srgb_to_linear01(u8)
  local c = u8 / 255.0
  if c <= 0.04045 then return c / 12.92 end
  return ((c + 0.055) / 1.055) ^ 2.4
end

-- linear RGB → OKLab (Björn Ottosson)
local function rgb_to_oklab(c)
  local r = srgb_to_linear01(c.r)
  local g = srgb_to_linear01(c.g)
  local b = srgb_to_linear01(c.b)
  local l = 0.4122214708*r + 0.5363325363*g + 0.0514459929*b
  local m = 0.2119034982*r + 0.6806995451*g + 0.1073969566*b
  local s = 0.0883024619*r + 0.2817188376*g + 0.6299787005*b
  local lp = l^(1/3); local mp = m^(1/3); local sp = s^(1/3)
  return {
    L = 0.2104542553*lp + 0.7936177850*mp - 0.0040720468*sp,
    a = 1.9779984951*lp - 2.4285922050*mp + 0.4505937099*sp,
    b = 0.0259040371*lp + 0.7827717662*mp - 0.8086757660*sp
  }
end

local function ensure_active()
  assert(_active.swatches and _active.byName, "palette.register(...) must be called before use")
end

-- Registration ---------------------------------------------------------------

--- Register the single active palette from a list of names.
--- Each name is resolved via util.getColor(name) → Color (usertype).
---@param opt table { names = {..}, slugger? }
function palette.register(opt)
  assert(type(opt)=="table", "register expects a table")
  assert(type(opt.names)=="table" and #opt.names>0, "register requires non-empty names list")
  local slugger = opt.slugger or default_slug

  local swatches, byName = {}, {}
  for i, display in ipairs(opt.names) do
    local user, rgb = to_user_and_rgb(util.getColor(display))
    local slug = slugger(display)
    assert(not byName[slug], "duplicate color name: "..slug)
    local s = {
      index   = i,
      name    = slug,     -- slug for strict lookup
      display = display,  -- original string
      color_user = user,  -- Color usertype (returned externally)
      color_rgb  = rgb,   -- {r,g,b,a} for math
      oklab      = rgb_to_oklab(rgb),
    }
    swatches[i] = s
    byName[slug] = i
  end

  _active.swatches = swatches
  _active.byName   = byName
end

-- Lookups -------------------------------------------------------------------

--- Strict fetch by name (returns Color usertype).
function palette.color(name)
  ensure_active()
  local idx = _active.byName[default_slug(assert(name, "name required"))]
  assert(idx, ("color '%s' not found in active palette"):format(tostring(name)))
  return _active.swatches[idx].color_user
end

--- 1-based index lookup (returns Color usertype).
function palette.idx(i)
  ensure_active()
  local s = _active.swatches[i]
  assert(s, ("index %d out of range"):format(tonumber(i) or -1))
  return s.color_user
end

--- Enumerate swatches for UI/tools.
function palette.list()
  ensure_active()
  local out = {}
  for i,s in ipairs(_active.swatches) do
    out[i] = { name=s.name, display=s.display, color=s.color_user }
  end
  return out
end

--- Exact membership test for active palette.
function palette.strict_contains(c)
  ensure_active()
  local _, rgb = to_user_and_rgb(c)
  for _, s in ipairs(_active.swatches) do
    if color_equals(rgb, s.color_rgb) then return true end
  end
  return false
end

-- Nearest & Ramps ------------------------------------------------------------

-- Internal: nearest swatch record by OKLab distance.
local function nearest_swatch(color_like)
  ensure_active()
  local _, rgb = to_user_and_rgb(color_like)
  local lab = rgb_to_oklab(rgb)
  local best_i, best_d2 = 1, math.huge
  for i,s in ipairs(_active.swatches) do
    local dL = lab.L - s.oklab.L
    local da = lab.a - s.oklab.a
    local db = lab.b - s.oklab.b
    local d2 = dL*dL + da*da + db*db
    if d2 < best_d2 then best_d2 = d2; best_i = i end
  end
  return _active.swatches[best_i]
end

--- Snap an arbitrary color (Color usertype, {r,g,b,a} table, or hex string)
--- to the nearest palette swatch. Returns Color usertype.
function palette.snap(c)
  if type(c)=="string" then
    c = palette.parse_hex(c)
  end
  return nearest_swatch(c).color_user
end

--- Snap a named source color (resolved via util.getColor) to the nearest swatch.
--- @param name string  -- source color name (as util.getColor expects)
--- @return Color       -- Color usertype (snapped to active palette)
function palette.snapToColorName(name)
  assert(type(name) == "string" and #name > 0, "snapToColorName: name string required")
  ensure_active()
  local src = util.getColor(name)         -- returns Color usertype
  return palette.snap(src)                -- reuse existing snapping
end


--- Build a ramp between two named swatches; N steps ≥ 2.
--- Each step is snapped back to the palette (strict output). Returns {Color,...}.
function palette.ramp_quantized(nameA, nameB, steps)
  if (steps or 0) < 2 then 
    return { palette.snapToColorName(nameA), palette.snapToColorName(nameB) }
  end
  assert(steps and steps>=2, "steps >= 2 required")
  local A = palette.snapToColorName(nameA)
  local B = palette.snapToColorName(nameB)
  local _, Argb = to_user_and_rgb(A)
  local _, Brgb = to_user_and_rgb(B)

  local out = {}
  for i=0,steps-1 do
    local t = (steps==1) and 0 or (i/(steps-1))
    -- simple sRGB mix for proxy position; final value is snapped by OKLab
    local tmp = {
      r = math.floor(Argb.r + (Brgb.r-Argb.r)*t + 0.5),
      g = math.floor(Argb.g + (Brgb.g-Argb.g)*t + 0.5),
      b = math.floor(Argb.b + (Brgb.b-Argb.b)*t + 0.5),
      a = math.floor(Argb.a + (Brgb.a-Argb.a)*t + 0.5),
    }
    out[#out+1] = palette.snap(tmp)
  end
  return out
end

-- Hex Parsing ----------------------------------------------------------------

--- Parse hex strings: "#RRGGBBAA", "#RRGGBB", "RRGGBBAA", or "RRGGBB".
--- Returns a Color usertype using your 4‑arg constructor.
function palette.parse_hex(hex)
  assert(type(hex)=="string", "hex string expected")
  local h = hex:gsub("^#", "")
  assert(#h==6 or #h==8, "hex must be 6 or 8 digits")
  local r = tonumber(h:sub(1,2),16)
  local g = tonumber(h:sub(3,4),16)
  local b = tonumber(h:sub(5,6),16)
  local a = (#h==8) and tonumber(h:sub(7,8),16) or 255
  return ColorCtor(r,g,b,a)
end

return palette
