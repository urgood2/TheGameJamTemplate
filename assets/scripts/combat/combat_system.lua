--[[
Pure Lua Combat Backbone — Two-File Edition (Part 1 + Part 2 in one view)

How to use as two files:
  - Save the first block below as:  part1_core.lua
  - Save the second block below as: part2_gameplay.lua

Then in your runner:
  local Core = require('part1_core')
  local Game = require('part2_gameplay')
  Game.Demo.run()

For convenience, both files are shown here. If you keep it as a single file,
scroll to the bottom for a single-file return table as well.
]]

-- ============================================================================
-- Core module table
-- Exposes: util, EventBus, Time (and other core systems added later).
-- NOTE: Behavior unchanged—only formatting and documentation added.
-- ============================================================================
local Core = {}

-- ============================================================================
-- Utility Helpers
-- Small, dependency-free helpers for copying and random selection.
-- ============================================================================
local util = {}

--- Deep copy a Lua table (recursively copies nested tables).
--  Non-table values are copied by value; functions and metatables are not
--  specially handled (intended for plain data tables).
--  @param t table: source table
--  @return table: deep-copied table
function util.copy(t)
  local r = {}
  for k, v in pairs(t) do
    r[k] = (type(v) == 'table') and util.copy(v) or v
  end
  return r
end

--- Shallow copy a Lua table (copies only the first level).
--  @param t table: source table
--  @return table: shallow-copied table
function util.shallow_copy(t)
  local r = {}
  for k, v in pairs(t) do
    r[k] = v
  end
  return r
end

--- Clamp a number x into [a, b].
--  @param x number
--  @param a number: lower bound
--  @param b number: upper bound
--  @return number: x clamped into the inclusive range [a, b]
function util.clamp(x, a, b)
  if x < a then return a elseif x > b then return b else return x end
end

--- Random float in [0, 1). Thin wrapper over math.random() for clarity.
--  @return number
function util.rand() return math.random() end

--- Choose a random element from a list (1..#list).
--  @param list table: array-like table
--  @return any: randomly selected entry
function util.choice(list) return list[math.random(1, #list)] end

--- Weighted random choice.
--  Expects a list of entries like { { item = X, w = weight }, ... }.
--  If weights sum to 0, behavior follows math.random()*0 == 0 and falls back to last entry.
--  @param entries table
--  @return any: chosen entries[i].item
function util.weighted_choice(entries)
  local sum = 0
  for _, e in ipairs(entries) do
    sum = sum + (e.w or 0)
  end
  local r = math.random() * sum
  local acc = 0
  for _, e in ipairs(entries) do
    acc = acc + (e.w or 0)
    if r <= acc then
      return e.item
    end
  end
  -- Fallback to the last item (covers sum==0 or floating-point edge).
  return entries[#entries].item
end

-- Pretty-print a concise stat dump for an actor.
-- Compact, readable stat dump with optional runtime sections.
-- Usage:
--   util.dump_stats(hero)                       -- minimal
--   util.dump_stats(hero, ctx)                  -- adds time-aware info (cooldowns/RR timers)
--   util.dump_stats(hero, ctx, { rr=true, dots=true, statuses=true, conv=true, spells=true, tags=true, timers=true })
function util.dump_stats(e, ctx, opts)
  opts = opts or {}
  local S = e.stats
  if not S then
    print("[dump_stats] no stats for entity: " .. (e.name or "?"))
    return
  end

  local function G(n) return S:get(n) end
  local function gi(n) return math.floor(G(n) + 0.5) end
  local function gf(n, p) return tonumber(string.format("%." .. (p or 1) .. "f", G(n))) end
  local function fmt_pct(n) return string.format("%d%%", math.floor(G(n)+0.5)) end
  local function nonzero(v) return v ~= 0 and v ~= nil end
  local function join(arr, sep)
    local s, t = "", arr or {}
    for i=1,#t do
      s = s .. (i>1 and (sep or " ") or "") .. tostring(t[i])
    end
    return s
  end

  local lines = {}
  local function add(line) lines[#lines+1] = line end

  local name = e.name or "Entity"
  local maxhp = e.max_health or G("health")
  local hp = e.hp or maxhp
  add(("==== %s ===="):format(name))
  add(("HP %d/%d | Energy %d"):format(math.floor(hp+0.5), math.floor(maxhp+0.5), gi("energy")))

  -- Attributes
  add("Attr   | " .. join({
    ("physique=%d"):format(gi("physique")),
    ("cunning=%d"):format(gi("cunning")),
    ("spirit=%d"):format(gi("spirit")),
  }, "  "))

  -- Offense
  add("Off    | " .. join({
    ("OA=%d"):format(gi("offensive_ability")),
    ("AtkSpd=%.1f"):format(gf("attack_speed")),
    ("CastSpd=%.1f"):format(gf("cast_speed")),
    ("CritDmg=%s"):format(fmt_pct("crit_damage_pct")),
    ("Wpn=%d-%d"):format(gi("weapon_min"), gi("weapon_max")),
  }, "  "))

  -- Defense
  local block_line = ("Block=%s/%d"):format(fmt_pct("block_chance_pct"), gi("block_amount"))
  add("Def    | " .. join({
    ("DA=%d"):format(gi("defensive_ability")),
    ("Armor=%d"):format(gi("armor")),
    block_line,
    ("Dodge=%s"):format(fmt_pct("dodge_chance_pct")),
    ("Absorb=%%=%s flat=%d"):format(fmt_pct("percent_absorb_pct"), gi("flat_absorb")),
  }, "  "))

  -- Damage modifiers (only nonzero)
  do
    local mods = {}
    for _, t in ipairs(Core.DAMAGE_TYPES) do
      local v = G(t .. "_modifier_pct")
      if nonzero(v) then mods[#mods+1] = ("%s=%d%%"):format(t, math.floor(v+0.5)) end
    end
    if #mods > 0 then add("DmgMod | " .. join(mods, "  ")) end
  end

  -- Resistances (only nonzero)
  do
    local res = {}
    for _, t in ipairs(Core.DAMAGE_TYPES) do
      local v = G(t .. "_resist_pct")
      if nonzero(v) then res[#res+1] = ("%s=%d%%"):format(t, math.floor(v+0.5)) end
    end
    if #res > 0 then add("Resist | " .. join(res, "  ")) end
  end

  -- Optional: Active RR (per damage type), compact
  if opts.rr then
    local now = (ctx and ctx.time and ctx.time.now) or nil
    local rr_lines = {}
    if e.active_rr then
      for _, t in ipairs(Core.DAMAGE_TYPES) do
        local bucket = e.active_rr[t]
        if bucket and #bucket > 0 then
          local parts = {}
          for i=1,#bucket do
            local r = bucket[i]
            if (not r.until_time) or (not now) or (r.until_time > now) then
              local left = (now and r.until_time) and math.max(0, r.until_time - now) or nil
              parts[#parts+1] = string.format("%s:%d%%%s",
                r.kind, math.floor((r.amount or 0)+0.5),
                left and string.format("(%.1fs)", left) or "")
            end
          end
          if #parts > 0 then
            rr_lines[#rr_lines+1] = string.format("%s: %s", t, join(parts, ", "))
          end
        end
      end
    end
    if #rr_lines > 0 then add("RR     | " .. join(rr_lines, "  |  ")) end
  end

  -- Optional: Statuses (buffs/debuffs) — list IDs with remaining time
  if opts.statuses then
    local now = (ctx and ctx.time and ctx.time.now) or nil
    local st = {}
    if e.statuses then
      for id, b in pairs(e.statuses) do
        for i=1,#b.entries do
          local en = b.entries[i]
          local left = (now and en.until_time) and math.max(0, en.until_time - now) or nil
          st[#st+1] = left and (id .. string.format("(%.1fs)", left)) or id
        end
      end
    end
    if #st > 0 then add("Status | " .. join(st, "  ")) end
  end

  -- Optional: DoTs summary
  if opts.dots then
    local now = (ctx and ctx.time and ctx.time.now) or nil
    local ds = {}
    if e.dots then
      for i=1,#e.dots do
        local d = e.dots[i]
        local left = (now and d.until_time) and math.max(0, d.until_time - now) or nil
        local nt   = (now and d.next_tick) and math.max(0, d.next_tick - now) or nil
        ds[#ds+1] = string.format("%s dps=%.1f tick=%.1f%s%s",
          d.type, d.dps or 0, d.tick or 1,
          left and string.format(" left=%.1fs", left) or "",
          nt and string.format(" next=%.1fs", nt) or "")
      end
    end
    if #ds > 0 then add("DoTs   | " .. join(ds, "  ||  ")) end
  end

  -- Optional: Gear conversions (compact)
  if opts.conv then
    local cvs = {}
    local list = e.gear_conversions or {}
    for i=1,#list do
      local c = list[i]
      cvs[#cvs+1] = string.format("%s->%s:%d%%", c.from, c.to, c.pct or 0)
    end
    if #cvs > 0 then add("Conv   | " .. join(cvs, "  ")) end
  end

  -- Optional: Granted spells
  if opts.spells then
    local gs = {}
    if e.granted_spells then
      for id, on in pairs(e.granted_spells) do
        if on then gs[#gs+1] = id end
      end
      table.sort(gs)
    end
    if #gs > 0 then add("Spells | " .. join(gs, ", ")) end
  end

  -- Optional: Tags
  if opts.tags then
    local ts = {}
    if e.tags then
      for k, v in pairs(e.tags) do
        if v then ts[#ts+1] = tostring(k) end
      end
      table.sort(ts)
    end
    if #ts > 0 then add("Tags   | " .. join(ts, ", ")) end
  end

  -- Optional: Cooldown snapshot (keys starting with "cd:" & "block")
  if opts.timers then
    local now = (ctx and ctx.time and ctx.time.now) or nil
    local cds = {}
    if e.timers then
      for k, tready in pairs(e.timers) do
        if not now then
          cds[#cds+1] = string.format("%s=%.2f", k, tready)
        else
          local left = math.max(0, tready - now)
          if left > 0 then
            cds[#cds+1] = string.format("%s: %.2fs", k, left)
          end
        end
      end
    end
    if #cds > 0 then add("Timers | " .. join(cds, "  ")) end
  end

  add(("============"):rep(2))
  print(table.concat(lines, "\n"))
end


-- Expose util in Core
Core.util = util

-- Core-level helper (optional)
--- Subscribes a function to an event on the context's event bus and returns an unsubscribe function.
-- @param ctx table The context containing the event bus (`ctx.bus`).
-- @param ev string The event name to subscribe to.
-- @param fn function The callback function to invoke when the event is triggered.
-- @param pr any Optional priority or parameter passed to the bus's `on` method.
-- @return function A function that, when called, unsubscribes the callback from the event.
function Core.on(ctx, ev, fn, pr)
  local bus = ctx.bus
  bus:on(ev, fn, pr)
  return function()  -- unsubscribe
    local b = bus.listeners[ev]
    if not b then return end
    for i=#b,1,-1 do if b[i].fn == fn then table.remove(b, i) break end end
  end
end

-- ============================================================================
-- EventBus
-- Minimal pub/sub system for decoupled event handling.
-- Listeners are stored per event name with optional numeric priority (ascending).
-- ============================================================================
local EventBus = {}
EventBus.__index = EventBus

--- Construct a new EventBus.
--  @return EventBus
function EventBus.new()
  return setmetatable({ listeners = {} }, EventBus)
end

--- Register a listener for an event.
--  @param name string: event name
--  @param fn function: callback invoked as fn(ctx)
--  @param pr number|nil: optional priority (lower runs earlier, default 0)
function EventBus:on(name, fn, pr)
  local bucket = self.listeners[name] or {}
  table.insert(bucket, { fn = fn, pr = pr or 0 })
  table.sort(bucket, function(a, b) return a.pr < b.pr end)
  self.listeners[name] = bucket
end

--- Emit an event to all listeners for `name` in ascending priority order.
--  @param name string
--  @param ctx table: event context payload (shape is user-defined)
function EventBus:emit(name, ctx)
  local bucket = self.listeners[name]
  if not bucket then return end
  -- Note: iterate by index to avoid issues if listeners list is reused.
  for i = 1, #bucket do
    bucket[i].fn(ctx)
  end
end

-- Expose EventBus in Core
Core.EventBus = EventBus

-- ============================================================================
-- Time
-- Lightweight timekeeper supporting cooldown checks and duration bookkeeping.
-- Intended to be ticked by an external game loop.
-- ============================================================================
local Time = {}
Time.__index = Time

--- Construct a new Time object.
--  Fields:
--    now (number): accumulated time in seconds (or game ticks), starts at 0.
--  @return Time
function Time.new()
  return setmetatable({ now = 0 }, Time)
end

--- Advance the internal clock by dt.
--  @param dt number: delta time to advance (seconds or ticks)
function Time:tick(dt)
  self.now = self.now + dt
end

--- Check whether a keyed timer is ready.
--  Works with any table that holds absolute-unlock timestamps keyed by `key`.
--  @param tbl table: table where cooldown absolute times are stored
--  @param key any: key into tbl
--  @return boolean: true if not set or if current time >= stored unlock time
function Time:is_ready(tbl, key)
  return (tbl[key] or -1) <= self.now
end

--- Set/update a cooldown for `key` in `tbl` to expire after duration `d`.
--  Stores an absolute timestamp (now + d) into tbl[key].
--  @param tbl table
--  @param key any
--  @param d number: duration until ready (seconds or ticks)
function Time:set_cooldown(tbl, key, d)
  tbl[key] = self.now + d
end

-- Expose Time in Core
Core.Time = Time



-- ============================================================================
-- Stats Definitions
-- Provides a schema for all possible stats in the system and a factory
-- function to build default definitions.
-- ============================================================================
local StatDef = {}

-- Full list of supported damage types.
-- Includes both direct damage (e.g. physical, fire) and DoT types (e.g. bleed).
local DAMAGE_TYPES = {
  'physical', 'pierce', 'bleed', 'trauma',
  'fire', 'cold', 'lightning', 'acid',
  'vitality', 'aether', 'chaos',
  'burn', 'frostburn', 'electrocute', 'poison', 'vitality_decay'
}

--- Helper to insert a standard stat entry.
--  Fields per stat:
--    base    (number) initial value
--    add_pct (number) additive percentage modifier (%)
--    mul_pct (number) multiplicative percentage modifier (%)
local function add_basic(defs, name)
  defs[name] = { base = 0, add_pct = 0, mul_pct = 0 }
end

--- Build the canonical definitions table of all stats.
--  Includes attributes, combat stats, regen, damage types, retaliation,
--  crowd-control resistances, etc.
--  @return defs table: mapping statName -> { base, add_pct, mul_pct }
--  @return DAMAGE_TYPES table: list of all damage type strings
function StatDef.make()
  local defs = {}

  -- Core attributes
  add_basic(defs, 'physique')
  add_basic(defs, 'cunning')
  add_basic(defs, 'spirit')

  -- Abilities/meta
  add_basic(defs, 'offensive_ability')
  add_basic(defs, 'defensive_ability')
  add_basic(defs, 'level')
  add_basic(defs, 'experience_gained_pct')

  -- Health/energy and regeneration
  add_basic(defs, 'health')
  add_basic(defs, 'health_regen')
  add_basic(defs, 'energy')
  add_basic(defs, 'energy_regen')

  -- Speeds, crits, all-damage
  add_basic(defs, 'attack_speed')
  add_basic(defs, 'cast_speed')
  add_basic(defs, 'run_speed')
  add_basic(defs, 'crit_damage_pct')
  add_basic(defs, 'all_damage_pct')

  -- Weapon & shield stats
  add_basic(defs, 'weapon_min')
  add_basic(defs, 'weapon_max')
  add_basic(defs, 'weapon_damage_pct')
  add_basic(defs, 'block_chance_pct')
  add_basic(defs, 'block_amount')
  add_basic(defs, 'block_recovery_reduction_pct')

  -- Avoidance & absorption
  add_basic(defs, 'dodge_chance_pct')
  add_basic(defs, 'deflect_chance_pct')
  add_basic(defs, 'percent_absorb_pct')
  add_basic(defs, 'flat_absorb')

  -- Armor
  add_basic(defs, 'armor')
  add_basic(defs, 'armor_absorption_bonus_pct')

  -- Lifesteal/healing
  add_basic(defs, 'life_steal_pct')
  add_basic(defs, 'healing_received_pct')

  -- Per-damage-type packs (damage, modifier %, resist %, and DoT duration % where applicable)
  for _, dt in ipairs(DAMAGE_TYPES) do
    add_basic(defs, dt .. '_damage')
    add_basic(defs, dt .. '_modifier_pct')
    add_basic(defs, dt .. '_resist_pct')

    -- DoT types also get duration modifiers
    if dt == 'bleed' or dt == 'trauma'
       or dt == 'burn' or dt == 'frostburn'
       or dt == 'electrocute' or dt == 'poison'
       or dt == 'vitality_decay' then
      add_basic(defs, dt .. '_duration_pct')
    end
  end

  -- Reflect / Retaliation
  add_basic(defs, 'reflect_damage_pct')
  for _, dt in ipairs(DAMAGE_TYPES) do
    add_basic(defs, 'retaliation_' .. dt)
    add_basic(defs, 'retaliation_' .. dt .. '_modifier_pct')
  end

  -- Crowd-control resistances (suffix `_resist_pct`)
  for _, cc in ipairs({
    'stun', 'disruption', 'leech_life', 'leech_energy',
    'trap', 'petrify', 'freeze', 'sleep', 'slow', 'reflect'
  }) do
    add_basic(defs, cc .. '_resist_pct')
  end

  return defs, DAMAGE_TYPES
end

-- ============================================================================
-- Stats Class
-- Holds actual numeric values per entity (separate from definitions).
-- Supports recomputation hooks for derived stats.
-- ============================================================================
local Stats = {}
Stats.__index = Stats

--- Construct a new Stats instance from definitions.
--  @param defs table: definitions table from StatDef.make()
--  @return Stats
function Stats.new(defs)
  local t = {
    defs = defs,
    values = {},        -- statName -> { base, add_pct, mul_pct }
    derived_hooks = {}, -- list of functions(stats) called on recompute()
    cached = {}         -- optional user caching
  }
  for n, d in pairs(defs) do
    t.values[n] = { base = d.base, add_pct = 0, mul_pct = 0 }
  end
  return setmetatable(t, Stats)
end

--- Get the raw stored value object for a stat (base/add_pct/mul_pct).
function Stats:get_raw(n)
  return self.values[n]
end

--- Get the final computed value for a stat.
--  Computed as: base * (1 + add_pct/100) * (1 + mul_pct/100).
function Stats:get(n)
  local v = self.values[n] or { base = 0, add_pct = 0, mul_pct = 0 }
  return v.base * (1 + v.add_pct / 100) * (1 + v.mul_pct / 100)
end

--- Increment base value of a stat.
function Stats:add_base(n, a)
  self.values[n].base = self.values[n].base + a
end

--- Increment additive percentage modifier of a stat.
function Stats:add_add_pct(n, a)
  self.values[n].add_pct = self.values[n].add_pct + a
end

--- Increment multiplicative percentage modifier of a stat.
function Stats:add_mul_pct(n, a)
  self.values[n].mul_pct = self.values[n].mul_pct + a
end

--- Register a hook to be run when recompute() is called.
--  Useful for maintaining derived stats.
function Stats:on_recompute(fn)
  table.insert(self.derived_hooks, fn)
end

--- Run all registered recompute hooks.
function Stats:recompute()
  for _, fn in ipairs(self.derived_hooks) do
    fn(self)
  end
end

-- ============================================================================
-- Resistance Reduction (RR)
-- Implements three types of resistance reduction with correct order of ops:
--   rr1: additive reductions (can drop below 0)
--   rr2: multiplicative percentage (floors at 0)
--   rr3: flat reductions (can drop below 0 again)
-- ============================================================================
local RR = {}

--- Utility: pick the entry with the highest amount.
local function pick_highest(tbl)
  local best = nil
  for _, e in ipairs(tbl) do
    if (not best) or e.amount > best.amount then
      best = e
    end
  end
  return best
end

--- Apply all resistance reductions to a base resistance value.
--  @param base number: starting resistance %
--  @param list table: list of entries { kind = 'rr1'|'rr2'|'rr3', amount = number }
--  @return number: resulting resistance after reductions
function RR.apply_all(base, list)
  local r = base
  local rr1, rr2, rr3 = {}, {}, {}

  -- Partition by kind
  for _, e in ipairs(list or {}) do
    if e.kind == 'rr1' then
      rr1[#rr1 + 1] = e
    elseif e.kind == 'rr2' then
      rr2[#rr2 + 1] = e
    elseif e.kind == 'rr3' then
      rr3[#rr3 + 1] = e
    end
  end

  -- rr1: additive, can go below 0
  local sum1 = 0
  for _, e in ipairs(rr1) do
    sum1 = sum1 + e.amount
  end
  r = r - sum1

  -- rr2: multiplicative % reduction, apply only the strongest one
  if #rr2 > 0 then
    local hi = pick_highest(rr2)
    r = r * (1 - hi.amount / 100)
    if r < 0 then r = 0 end
  end

  -- rr3: flat, pick strongest, can go below 0 again
  if #rr3 > 0 then
    r = r - pick_highest(rr3).amount
  end

  return r
end




-- ============================================================================
-- Conversions (skill then gear)
-- Converts damage-component maps between types in two passes:
--   1) skill_bucket conversions
--   2) gear_bucket conversions
-- Buckets are arrays of { from = <type>, to = <type>, pct = <0..100> }.
-- Input "components" is an array of { type = <damageType>, amount = <number> }.
-- Output preserves total sum (modulo float precision).
-- ============================================================================
local Conv = {}

--- Internal: apply a single conversion bucket to a map of type->amount.
--  @param m table: { [type] = amount }
--  @param bucket table[]|nil: list of { from, to, pct }
--  @return table: new map after conversions
local function apply_bucket(m, bucket)
  if not bucket or #bucket == 0 then return m end
  local out = {}
  local map = util.shallow_copy(m)

  for _, cv in ipairs(bucket) do
    local avail = map[cv.from] or 0
    local move  = avail * (cv.pct / 100)
    map[cv.from] = avail - move
    map[cv.to]   = (map[cv.to] or 0) + move
  end

  -- Re-materialize into a fresh table (keeps semantics explicit)
  for k, v in pairs(map) do
    out[k] = v
  end
  return out
end

--- Convert an array of components through skill and gear buckets.
--  @param components table[]: { { type, amount }, ... }
--  @param skill_bucket table[]|nil
--  @param gear_bucket  table[]|nil
--  @return table[]: components array { { type, amount }, ... } after conversion
function Conv.apply(components, skill_bucket, gear_bucket)
  -- Fold array into a map of type -> total amount
  local m = {}
  for _, c in ipairs(components) do
    m[c.type] = (m[c.type] or 0) + c.amount
  end

  -- Apply skill conversions first, then gear conversions
  m = apply_bucket(m, skill_bucket)
  m = apply_bucket(m, gear_bucket)

  -- Unfold back into array of components (order unspecified)
  local out = {}
  for t, amt in pairs(m) do
    out[#out + 1] = { type = t, amount = amt }
  end
  return out
end

-- Expose conversion table if this file returns a bundle elsewhere
-- (left local here; attach to your module table as needed)
-- Core.Conv = Conv

-- ============================================================================
-- Targeters
-- A library of selection functions. Each targeter takes a context `ctx` and
-- returns an array of entity handles. The shape of `ctx` is user-defined but
-- expected to include:
--   ctx.source         -> the acting entity
--   ctx.target         -> an explicit target (for single-target skills)
--   ctx.get_enemies_of -> function(entity) -> { enemies... }
--   ctx.get_allies_of  -> function(entity) -> { allies... }
-- ============================================================================
local Targeters = {}

--- Return the acting entity as the only target.
function Targeters.self(ctx)
  return { ctx.source }
end

--- Return the explicit target set in ctx.
function Targeters.target_enemy(ctx)
  return { ctx.target }
end

--- Return all enemies of the source (shallow-copied).
function Targeters.all_enemies(ctx)
  return util.copy(ctx.get_enemies_of(ctx.source))
end

--- Return all allies of the source (shallow-copied).
function Targeters.all_allies(ctx)
  return util.copy(ctx.get_allies_of(ctx.source))
end

--- Return a single random enemy (or empty if none).
function Targeters.random_enemy(ctx)
  local es = ctx.get_enemies_of(ctx.source)
  if #es == 0 then return {} end
  return { util.choice(es) }
end

--- Return a higher-order targeter that filters enemies by a predicate.
--  @param predicate function(e) -> boolean
--  @return function(ctx) -> { filtered enemies }
function Targeters.enemies_with(predicate)
  return function(ctx)
    local out = {}
    for _, e in ipairs(ctx.get_enemies_of(ctx.source)) do
      if predicate(e) then
        out[#out + 1] = e
      end
    end
    return out
  end
end

-- Expose if needed:
-- Core.Targeters = Targeters

-- ============================================================================
-- Conditions
-- Small predicate helpers usable for filtering or gating effects.
-- Each condition returns a boolean. Some return higher-order functions that
-- close over parameters (e.g., has_tag('boss')).
-- ============================================================================
local Cond = {}

--- Always-true condition (useful as a default).
function Cond.always() return true end

--- Returns a predicate that checks if an entity has a tag set truthy.
--  Assumes entity has table `e.tags` keyed by tag name.
--  @param tag string
--  @return function(e) -> boolean
function Cond.has_tag(tag)
  return function(e)
    return e.tags and e.tags[tag]
  end
end

--- Returns a predicate that checks if an entity stat is below a threshold.
--  @param stat string
--  @param th number
--  @return function(e) -> boolean
function Cond.stat_below(stat, th)
  return function(e)
    return e.stats:get(stat) < th
  end
end

-- Expose Core ---------------------------------------------------------
Core.util = util
Core.EventBus = EventBus
Core.Time = Time
Core.StatDef = StatDef
Core.Stats = Stats
Core.RR = RR
Core.Conv = Conv
Core.Targeters = Targeters
Core.Cond = Cond
Core.DAMAGE_TYPES = DAMAGE_TYPES



-- ============================================================================
-- Gameplay Modules (namespaces)
-- These are placeholders for organization; you can attach functions later.
-- ============================================================================
local Effects, Combat, Items, Leveling, Content, StatusEngine, World = {}, {}, {}, {}, {}, {}, {}

-- Pull core dependencies out of Core (no behavior change)
local util, EventBus, Time, StatDef, Stats, RR, Conv, Targeters, Cond, DAMAGE_TYPES =
  Core.util, Core.EventBus, Core.Time, Core.StatDef, Core.Stats, Core.RR, Core.Conv, Core.Targeters, Core.Cond, Core.DAMAGE_TYPES

-- ============================================================================
-- Effects
-- Collection of effect builders. Each builder returns a closure of the form:
--   function(ctx, src, tgt) ... end
-- Effects may:
--   - modify stats (temporary via status entries),
--   - apply resistance reduction,
--   - deal damage, heal, apply DoTs, etc.
-- ctx is expected to provide:
--   ctx.time (Core.Time), ctx.bus (EventBus),
--   ctx.get_enemies_of, ctx.get_allies_of, etc. (from your game layer)
-- ============================================================================

-- Status helper -------------------------------------------------------
-- Applies (or replaces) a status entry on target keyed by status.id.
-- Status entry shape:
--   {
--     id = <string>,
--     until_time = <number|nil>, -- absolute time when it should expire
--     apply = function(entity) ... end,  -- runs immediately on apply
--     remove = function(entity) ... end, -- should be called by your status engine on expiry
--   }
-- Add an opt: status.stack = { mode='replace'|'time_extend'|'count', max=3 }
local function apply_status(target, status)
  target.statuses = target.statuses or {}
  local bucket = target.statuses[status.id] or { entries = {} }
  target.statuses[status.id] = bucket

  local st = status.stack
  if not st or st.mode == 'replace' then
    bucket.entries[1] = status
  elseif st.mode == 'time_extend' then
    -- Extend the first entry’s until_time if newer has longer/refresh
    if bucket.entries[1] then
      local cur = bucket.entries[1]
      if status.until_time and (not cur.until_time or status.until_time > cur.until_time) then
        cur.until_time = status.until_time
      end
    else
      bucket.entries[1] = status
    end
  elseif st.mode == 'count' then
    -- bounded stack count; all entries contribute to RR.apply_all
    table.insert(bucket.entries, status)
    if st.max and #bucket.entries > st.max then
      table.remove(bucket.entries, 1) -- FIFO
    end
  end

  if status.apply then status.apply(target) end
end

--- Apply Resistance Reduction (RR) to a specific damage type.
--  p = { kind = 'rr1'|'rr2'|'rr3', damage = <type>, amount = <number>, duration = <secs or 0> }
Effects.apply_rr = function(p)
  return function(ctx, src, tgt)
    tgt.active_rr = tgt.active_rr or {}
    tgt.active_rr[p.damage] = tgt.active_rr[p.damage] or {}

    table.insert(tgt.active_rr[p.damage], {
      kind       = p.kind,
      damage     = p.damage,
      amount     = p.amount,
      until_time = ctx.time.now + (p.duration or 0),
    })

    ctx.bus:emit('OnRRApplied', { source = src, target = tgt, kind = p.damage, rr = p, amount = p.amount })
  end
end

--- Temporarily modify a stat via a status entry.
--  p = {
--    id = <string>|nil (defaults to "buff:<name>"),
--    name = <statName>,
--    base_add    = <number>|nil,
--    add_pct_add = <number>|nil,
--    mul_pct_add = <number>|nil,
--    duration    = <number>|nil (secs; nil = permanent until manually removed)
--  }
Effects.modify_stat = function(p)
  return function(ctx, src, tgt)
    local entry = {
      id         = p.id or ('buff:' .. p.name),
      until_time = p.duration and (ctx.time.now + p.duration) or nil,

      apply = function(e)
        if p.base_add    then e.stats:add_base   (p.name, p.base_add)    end
        if p.add_pct_add then e.stats:add_add_pct(p.name, p.add_pct_add) end
        if p.mul_pct_add then e.stats:add_mul_pct(p.name, p.mul_pct_add) end
      end,

      remove = function(e)
        if p.base_add    then e.stats:add_base   (p.name, -p.base_add)    end
        if p.add_pct_add then e.stats:add_add_pct(p.name, -p.add_pct_add) end
        if p.mul_pct_add then e.stats:add_mul_pct(p.name, -p.mul_pct_add) end
      end
    }

    apply_status(tgt, entry)
    ctx.bus:emit('OnBuffApplied', { source = src, target = tgt, name = p.name })
  end
end
-- Deal damage with optional weapon scaling and conversions.
--  p = {
--    weapon = <bool>,          -- if true, use src weapon_min/max and scale_pct
--    scale_pct = <number>|100, -- weapon damage scale %
--    components = { { type, amount }, ... } -- used when weapon=false
--    skill_conversions = { { from, to, pct }, ... } -- skill-stage conversions
--  }
Effects.deal_damage = function(p)
  return function(ctx, src, tgt)
    -- ---------- DEBUG HELPERS (print only when ctx.debug == true) -----------
    local function dbg(fmt, ...)
      if ctx.debug then print(string.format("[DEBUG][deal_damage] " .. fmt, ...)) end
    end

    local function _round1(x) return (x ~= nil) and tonumber(string.format("%.1f", x)) or x end

    -- comps: array of { type=string, amount=number }
    local function _comps_to_string(comps)
      if not ctx.debug then return "" end
      local tmp = {}
      for i = 1, #comps do
        local c = comps[i]
        tmp[#tmp+1] = string.format("%s=%0.1f", tostring(c.type), _round1(c.amount))
      end
      table.sort(tmp) -- stable-ish, alphabetical by "type=…"
      return table.concat(tmp, ", ")
    end

    -- sums: map { [damageType]=amount }
    local function _sums_to_string(sums)
      if not ctx.debug then return "" end
      local keys, tmp = {}, {}
      for k in pairs(sums) do keys[#keys+1] = k end
      table.sort(keys)
      for i = 1, #keys do
        local k = keys[i]
        tmp[#tmp+1] = string.format("%s=%0.1f", tostring(k), _round1(sums[k]))
      end
      return table.concat(tmp, ", ")
    end

    local function _rr_bucket_to_string(rrs)
      if not ctx.debug then return "" end
      if not rrs or #rrs == 0 then return "(none)" end
      local parts = {}
      for i = 1, #rrs do
        local r = rrs[i]
        -- kind: rr1/rr2/rr3 | amount | time left if any
        local tleft = (r.until_time and (r.until_time - ctx.time.now)) or nil
        if tleft and tleft < 0 then tleft = 0 end
        parts[#parts+1] = string.format("%s:%s=%0.1f%s",
          tostring(r.kind), tostring(r.damage), _round1(r.amount),
          tleft and string.format(" (%.1fs)", _round1(tleft)) or "")
      end
      return table.concat(parts, ", ")
    end
    -- ------------------------------------------------------------------------

    -- Build raw components ----------------------------------------------------
    local comps = {}

    if p.weapon then
      local min  = src.stats:get('weapon_min')
      local max  = src.stats:get('weapon_max')
      local base = math.random() * (max - min) + min
      local scale = (p.scale_pct or 100) / 100

      comps[#comps + 1] = { type = 'physical', amount = base * scale }
      dbg("Weapon roll: min=%.1f max=%.1f base=%.1f scale=%.2f", min, max, base, scale)

      for _, dt in ipairs(DAMAGE_TYPES) do
        local flat = src.stats:get(dt .. '_damage')
        if flat ~= 0 then
          comps[#comps + 1] = { type = dt, amount = flat * scale }
          dbg("Flat %s damage (scaled): %.1f", dt, flat * scale)
        end
      end
    else
      for _, c in ipairs(p.components or {}) do
        comps[#comps + 1] = { type = c.type, amount = c.amount }
      end
      dbg("Direct components: %s", _comps_to_string(comps))
    end

    -- Apply conversions: skill stage then gear stage
    comps = Conv.apply(comps, p.skill_conversions, src.gear_conversions)
    dbg("After conversions: %s", _comps_to_string(comps))

    -- Hit/crit and defense ----------------------------------------------------
    local function pth(OA, DA)
      local term1 = 3.15 * (OA / (3.5 * OA + DA))
      local term2 = 0.0002275 * (OA - DA)
      return (term1 + term2 + 0.2) * 100
    end

    local OA  = src.stats:get('offensive_ability')
    local DA  = tgt.stats:get('defensive_ability')
    local PTH = util.clamp(pth(OA, DA), 60, 140)
    dbg("Hit check: OA=%.1f DA=%.1f PTH=%.1f%%", OA, DA, PTH)

    -- Miss check
    if math.random() * 100 > PTH then
      dbg("Attack missed!")
      ctx.bus:emit('OnMiss', { source = src, target = tgt, pth = PTH })
      return
    end

    -- Crit multiplier from PTH (piecewise)
    local crit_mult =
      (PTH < 75)  and (PTH / 75) or
      (PTH < 90)  and 1.0        or
      (PTH < 105) and 1.1        or
      (PTH < 120) and 1.2        or
      (PTH < 130) and 1.3        or
      (PTH < 135) and 1.4        or (1.5 + (PTH - 135) * 0.005)
    dbg("Crit multiplier: %.2f", crit_mult)

    -- Shield block ------------------------------------------------------------
    tgt.timers = tgt.timers or {}
    local blocked   = false
    local block_amt = 0

    if ctx.time:is_ready(tgt.timers, 'block')
       and math.random() * 100 < tgt.stats:get('block_chance_pct') then
      blocked   = true
      block_amt = tgt.stats:get('block_amount')

      local base = 1.0
      local rec  = base * (1 - tgt.stats:get('block_recovery_reduction_pct') / 100)
      ctx.time:set_cooldown(tgt.timers, 'block', math.max(0.1, rec))
      dbg("Block triggered: amt=%.1f next_ready=%.2f", block_amt, tgt.timers['block'] or -1)
    end

    -- Aggregate per-type and apply crit --------------------------------------
    local sums = {}
    for _, c in ipairs(comps) do
      sums[c.type] = (sums[c.type] or 0) + c.amount
    end
    for t, amt in pairs(sums) do
      sums[t] = amt * crit_mult
    end
    dbg("Post-crit sums: %s", _sums_to_string(sums))

    -- Apply outgoing modifiers (attacker) ------------------------------------
    local allpct = 1 + src.stats:get('all_damage_pct') / 100
    for t, amt in pairs(sums) do
      sums[t] = amt * allpct * (1 + src.stats:get(t .. '_modifier_pct') / 100)
    end
    dbg("After attacker mods: %s", _sums_to_string(sums))

    -- Defenses (RR, armor, resist, absorbs, block) ----------------------------
    local dealt = 0

    for t, amt in pairs(sums) do
      local base_res = tgt.stats:get(t .. '_resist_pct')

      -- Collect alive RR entries for this type
      local alive_rr = {}
      if tgt.active_rr and tgt.active_rr[t] then
        for _, e in ipairs(tgt.active_rr[t]) do
          if (not e.until_time) or e.until_time > ctx.time.now then
            alive_rr[#alive_rr + 1] = e
          end
        end
      end

      local res = RR.apply_all(base_res, alive_rr)
      dbg("Type %s: start=%.1f base_res=%.1f final_res=%.1f | RR: %s",
          t, amt, base_res, res, _rr_bucket_to_string(alive_rr))

      -- Armor mitigation (physical only)
      if t == 'physical' then
        local armor = tgt.stats:get('armor')
        local abs   = 0.70 * (1 + tgt.stats:get('armor_absorption_bonus_pct') / 100)
        local mit   = math.min(amt, armor) * abs
        amt = amt - mit
        dbg("  Armor: armor=%.1f abs=%.2f mit=%.1f remain=%.1f", armor, abs, mit, amt)
      end

      local after_res   = amt * (1 - res / 100)
      local after_pct   = after_res * (1 - tgt.stats:get('percent_absorb_pct') / 100)
      local after_block = after_pct

      if blocked then
        local used = math.min(block_amt, after_pct)
        after_block = after_pct - used
        block_amt   = block_amt - used
        dbg("  Block: used=%.1f remain=%.1f", used, block_amt)
      end

      local after_flat = math.max(0, after_block - tgt.stats:get('flat_absorb'))
      dbg("  After absorbs (flat=%0.1f): %s=%0.1f",
          tgt.stats:get('flat_absorb') or 0, t, after_flat)
      dealt = dealt + after_flat
    end

    -- Apply damage to target --------------------------------------------------
    local maxhp = tgt.max_health or tgt.stats:get('health')
    tgt.hp = util.clamp((tgt.hp or maxhp) - dealt, 0, maxhp)
    dbg("Damage dealt total=%.1f, Target HP=%.1f/%.1f", dealt, tgt.hp, maxhp)

    -- Lifesteal (attacker) ----------------------------------------------------
    local ls = src.stats:get('life_steal_pct') or 0
    if ls > 0 then
      local heal = dealt * (ls / 100)
      local smax = src.max_health or src.stats:get('health')
      src.hp = util.clamp((src.hp or smax) + heal, 0, smax)
      dbg("Lifesteal: +%.1f, Attacker HP=%.1f/%.1f", heal, src.hp, smax)
    end

    -- Reflect (target -> attacker) -------------------------------------------
    local ref = tgt.stats:get('reflect_damage_pct') or 0
    if ref > 0 then
      local re   = dealt * (ref / 100)
      local smax = src.max_health or src.stats:get('health')
      src.hp = util.clamp((src.hp or smax) - re, 0, smax)
      dbg("Reflect: -%.1f, Attacker HP=%.1f/%.1f", re, src.hp, smax)
    end

    -- Retaliation (flat sum across types) ------------------------------------
    local ret = 0
    for _, dt in ipairs(DAMAGE_TYPES) do
      local base = tgt.stats:get('retaliation_' .. dt) or 0
      local mod  = 1 + (tgt.stats:get('retaliation_' .. dt .. '_modifier_pct') or 0) / 100
      ret = ret + base * mod
    end
    if ret > 0 then
      local smax = src.max_health or src.stats:get('health')
      src.hp = util.clamp((src.hp or smax) - ret, 0, smax)
      dbg("Retaliation: -%.1f, Attacker HP=%.1f/%.1f", ret, src.hp, smax)
    end

    ctx.bus:emit('OnHitResolved', {
      source = src, target = tgt, damage = dealt, crit = (crit_mult > 1.0), pth = PTH
    })
  end
end

--- Heal target. Scales with target's healing_received_pct.
--  p = { flat = <number>|0, percent_of_max = <number>|nil }
Effects.heal = function(p)
  return function(ctx, src, tgt)
    local maxhp = tgt.max_health or tgt.stats:get('health')
    local amt   = (p.flat or 0) + (p.percent_of_max and maxhp * (p.percent_of_max / 100) or 0)
    amt = amt * (1 + tgt.stats:get('healing_received_pct') / 100)

    tgt.hp = util.clamp((tgt.hp or maxhp) + amt, 0, maxhp)
    ctx.bus:emit('OnHealed', { source = src, target = tgt, amount = amt })
  end
end

--- Convenience: temporary barrier as a flat_absorb buff.
--  p = { amount = <number>, duration = <secs> }
Effects.grant_barrier = function(p)
  return Effects.modify_stat {
    id        = 'barrier',
    name      = 'flat_absorb',
    base_add  = p.amount,
    duration  = p.duration
  }
end

--- Sequence multiple effects in order.
Effects.seq = function(list)
  return function(ctx, src, tgt)
    for _, e in ipairs(list) do
      e(ctx, src, tgt)
    end
  end
end

--- Execute `eff` with probability `pct` (0..100).
Effects.chance = function(pct, eff)
  return function(ctx, src, tgt)
    if math.random() * 100 <= pct then
      eff(ctx, src, tgt)
    end
  end
end

--- Build an effect by scaling with a source stat before building the effect.
--  Example:
--    Effects.scale_by_stat('spirit', 0.5, function(scaled)
--      return Effects.deal_damage{ components = { { type='fire', amount = scaled } } }
--    end)
Effects.scale_by_stat = function(stat, f, build)
  return function(ctx, src, tgt)
    local s = src.stats:get(stat) * f
    build(s)(ctx, src, tgt)
  end
end

-- ============================================================================
-- Custom Effects / Targeters / Triggers
-- ============================================================================

--- Apply a Damage-over-Time (DoT) entry to target.
--  p = { type = <damageType>, dps = <number>, tick = <secs>|1.0, duration = <secs> }
--  Note: This only registers the DoT; you should tick and apply its damage in
--  your game loop or a dedicated status system using the stored fields.
Effects.apply_dot = function(p)
  return function(ctx, src, tgt)
    tgt.dots = tgt.dots or {}
    table.insert(tgt.dots, {
      type       = p.type,
      dps        = p.dps,
      tick       = p.tick or 1.0,
      until_time = ctx.time.now + (p.duration or 0),
      next_tick  = ctx.time.now + (p.tick or 1.0),
      source     = src,
    })
    ctx.bus:emit('OnDotApplied', { source = src, target = tgt, dot = p })
  end
end

--- Force an immediate counter-attack from target against source.
--  p = { scale_pct = <number>|100 } -- uses weapon damage from the counter-attacker (tgt)
Effects.force_counter_attack = function(p)
  return function(ctx, src, tgt)
    if not tgt or tgt.dead then return end
    Effects.deal_damage { weapon = true, scale_pct = p.scale_pct or 100 } (ctx, tgt, src)
    ctx.bus:emit('OnCounterAttack', { source = tgt, target = src })
  end
end

-- New targeter example is already available via Core.Targeters.enemies_with(predicate)
-- New trigger example: emit 'OnProvoke' from your game layer when taunted, etc.

-- ============================================================================
-- Combat
-- Minimal constructor returning a small context bundle for convenience.
-- ============================================================================
Combat.new = function(rr, dts)
  return { RR = rr, DAMAGE_TYPES = dts }
end

-- ============================================================================
-- Items (equip gates, minimal)
-- Implements very lightweight attribute-based equip gating with slot allowlists.
-- `Items.can_equip(entity, item)` returns:
--   - true
--   - or false, 'attribute_too_low' | 'slot_not_allowed'
-- Items must declare:
--   item.slot = <string>
--   item.requires = { attribute = 'physique'|'cunning'|'spirit', value = <number>, mode = 'sole'|'with_other' }
-- ============================================================================
Items.equip_rules = {
  sole = {
    physique = { 'helm', 'shoulders', 'chest', 'gloves', 'belt', 'pants', 'boots', 'axe1', 'axe2', 'mace1', 'mace2', 'sword2', 'shield' },
    cunning  = { 'sword1', 'bow1', 'bow2', 'gun1', 'gun2' },
    spirit   = { 'offhand', 'ring', 'amulet', 'medal' },
  },
  with_other = {
    physique = { 'caster_helm', 'caster_chest', 'scepter' },
    cunning  = { 'dagger' },
    spirit   = { 'caster_helm', 'caster_chest', 'dagger', 'scepter' },
  },
}

function Items.can_equip(e, item)
  if not item.requires then return true end

  local req = item.requires
  if e.stats:get(req.attribute) < (req.value or 0) then
    return false, 'attribute_too_low'
  end

  local allowed = Items.equip_rules[req.mode or 'sole'][req.attribute]
  if allowed then
    for _, slot in ipairs(allowed) do
      if slot == item.slot then return true end
    end
    return false, 'slot_not_allowed'
  end

  -- If no rule exists for that attribute/mode, default to allowed.
  return true
end

-- ============================================================================
-- Leveling
-- Simple EXP -> Level conversion:
--   - xp threshold per level = (level * 1000)
--   - on level-up: +1 attribute point, +3 skill points, +1 mastery up to 2,
--     +10 OA and +10 DA via base add.
-- Emits: 'OnLevelUp'
-- ============================================================================
function Leveling.grant_exp(ctx, e, base)
  local bonus = 1 + e.stats:get('experience_gained_pct') / 100
  e.xp = (e.xp or 0) + base * bonus

  while e.xp >= ((e.level or 1) * 1000) do
    e.xp = e.xp - ((e.level or 1) * 1000)
    Leveling.level_up(ctx, e)
  end
end

function Leveling.level_up(ctx, e)
  e.level        = (e.level or 1) + 1
  e.attr_points  = (e.attr_points or 0) + 1
  e.skill_points = (e.skill_points or 0) + 3
  e.masteries    = math.min(2, (e.masteries or 0) + 1)

  e.stats:add_base('offensive_ability', 10)
  e.stats:add_base('defensive_ability', 10)

  ctx.bus:emit('OnLevelUp', { entity = e })
end

-- ============================================================================
-- Content (spells/traits)
-- Attribute derivations and a small library of example spells/traits.
-- Note: Derivations are wired as a recompute hook; calling `stats:recompute()`
-- will reapply these derived changes based on current base attributes.
-- ============================================================================
Content = {}

--- Attach attribute->stat derivations to a Stats instance (via recompute hook).
--  - Physique: +health (base), +health_regen beyond 10 physique
--  - Cunning : +OA, +modifiers and DoT durations (per 5 cunning)
--  - Spirit  : +health/energy/energy_regen, +elemental/chaos modifiers and DoT durations (per 5 spirit)
function Content.attach_attribute_derivations(S)
  S:on_recompute(function(S)
    local p = S:get_raw('physique').base
    local c = S:get_raw('cunning').base
    local s = S:get_raw('spirit').base

    -- Physique
    S:add_base('health', 100 + p * 10)
    local extra = math.max(0, p - 10)
    S:add_base('health_regen', extra * 0.2)

    -- Cunning
    S:add_base('offensive_ability', c * 1)
    local chunks_c = math.floor(c / 5)
    S:add_add_pct('physical_modifier_pct', chunks_c * 1)
    S:add_add_pct('pierce_modifier_pct',   chunks_c * 1)
    S:add_add_pct('bleed_duration_pct',    chunks_c * 1)
    S:add_add_pct('trauma_duration_pct',   chunks_c * 1)

    -- Spirit
    S:add_base('health',       s * 2)
    S:add_base('energy',       s * 10)
    S:add_base('energy_regen', s * 0.5)

    local chunks_s = math.floor(s / 5)
    for _, t in ipairs({ 'fire', 'cold', 'lightning', 'acid', 'vitality', 'aether', 'chaos' }) do
      S:add_add_pct(t .. '_modifier_pct', chunks_s * 1)
    end
    for _, t in ipairs({ 'burn', 'frostburn', 'electrocute', 'poison', 'vitality_decay' }) do
      S:add_add_pct(t .. '_duration_pct', chunks_s * 1)
    end
  end)
end

-- Example Spells ------------------------------------------------------
-- Each spell: { name, class, trigger, targeter(ctx)->targets, effects(ctx,src,tgt) }
Content.Spells = {
  Fireball = {
    name     = 'Fireball',
    class    = 'pyromancy',
    trigger  = 'OnCast',
    targeter = function(ctx) return { ctx.target } end,
    effects  = Effects.seq {
      Effects.deal_damage { components = { { type = 'fire', amount = 120 } } },
      Effects.apply_rr    { kind = 'rr1', damage = 'fire', amount = 20, duration = 4, stack = { mode='count', max=3 }  -- enables up to 3 concurrent stacks
      },
    },
  },

  ViperSigil = {
    name     = 'Viper Sigil',
    class    = 'hex',
    trigger  = 'OnCast',
    targeter = function(ctx) return Core.Targeters.all_enemies(ctx) end,
    effects  = Effects.apply_rr { kind = 'rr2', damage = 'cold', amount = 20, duration = 3 },
  },

  ElementalStorm = {
    name     = 'Elemental Storm',
    class    = 'aura',
    trigger  = 'OnCast',
    targeter = function(ctx) return Core.Targeters.all_enemies(ctx) end,
    effects  = Effects.apply_rr { kind = 'rr3', damage = 'cold', amount = 32, duration = 2 },
  },

  PoisonDart = {
    name     = 'Poison Dart',
    class    = 'toxic',
    trigger  = 'OnCast',
    targeter = function(ctx) return { ctx.target } end,
    effects  = Effects.apply_dot { type = 'poison', dps = 20, duration = 5, tick = 1 },
  },
}

-- Example Traits ------------------------------------------------------
-- Trait shapes vary; they usually have a trigger and either:
--  - a chance + targeter + effects, or
--  - a custom handler(ctx) reacting to ctx.event
Content.Traits = {
  EmberStrike = {
    name    = 'Ember Strike',
    class   = 'weapon_proc',
    trigger = 'OnBasicAttack',
    chance  = 35,
    targeter = function(ctx) return { ctx.target } end,
    effects  = Effects.deal_damage {
      weapon = true,
      scale_pct = 60,
      skill_conversions = {
        { from = 'physical', to = 'fire', pct = 50 }
      }
    },
  },

  RetaliatoryInstinct = {
    name    = 'Retaliatory Instinct',
    class   = 'counter',
    trigger = 'OnHitResolved',
    handler = function(ctx)
      local ev = ctx.event
      if ev and ev.target and ev.source and util.rand() * 100 < 25 then
        Effects.force_counter_attack { scale_pct = 50 } (ctx, ev.target, ev.source)
      end
    end,
  },
}

-- ============================================================================
-- Status engine + world tick
-- StatusEngine.update_entity:
--   - Expires timed buffs (calls entry.remove if present, emits 'OnStatusExpired')
--   - Ticks DoTs: on each tick, deals dps as instantaneous damage
-- World.update:
--   - Ticks global time, updates all entities on both sides, emits 'OnTick'
-- ============================================================================
StatusEngine.update_entity = function(ctx, e, dt)
  -- Expire timed buffs --------------------------------------------------------
  if e.statuses then
    for id, b in pairs(e.statuses) do
      local kept = {}
      for _, entry in ipairs(b.entries) do
        if (not entry.until_time) or entry.until_time > ctx.time.now then
          kept[#kept + 1] = entry
        else
          if entry.remove then entry.remove(e) end
          ctx.bus:emit('OnStatusExpired', { entity = e, id = id })
        end
      end
      b.entries = kept
    end
  end

  -- Tick DoTs -----------------------------------------------------------------
  if e.dots then
    local kept = {}
    for _, d in ipairs(e.dots) do
      if d.until_time and d.until_time <= ctx.time.now then
        -- drop expired dot
      else
        if ctx.time.now >= (d.next_tick or ctx.time.now) then
          Effects.deal_damage { components = { { type = d.type, amount = d.dps } } } (ctx, d.source, e)
          d.next_tick = (d.next_tick or ctx.time.now) + (d.tick or 1.0)
        end
        kept[#kept + 1] = d
      end
    end
    e.dots = kept
  end
end

World.update = function(ctx, dt)
  ctx.time:tick(dt)

  local function each(L)
    for _, ent in ipairs(L or {}) do
      StatusEngine.update_entity(ctx, ent, dt)
    end
  end

  each(ctx.side1)
  each(ctx.side2)

  ctx.bus:emit('OnTick', { dt = dt, now = ctx.time.now })
end


-- ============================================================================
-- Demo
-- Provides a runnable demonstration of the system:
--   - Creates hero + ogre actors with stats
--   - Hooks up EventBus listeners to print combat logs
--   - Executes: basic attack, EmberStrike chance, Fireball, Poison Dart with DoT ticks
--   - Demonstrates a custom trigger ("OnProvoke") causing counter-attack
-- ============================================================================
local function make_actor(name, defs, attach)
  -- Create a new Stats instance, attach attribute derivations, recompute, set HP.
  local s = Stats.new(defs)
  attach(s)
  s:recompute()
  local hp = s:get('health')

  return {
    name            = name,
    stats           = s,
    hp              = hp,
    max_health      = hp,
    gear_conversions= {},
    tags            = {},
    timers          = {},
  }
end

  
---------------------------
-- Items & Actives: ItemSystem (equip/unequip, procs, granted actives)
---------------------------
local ItemSystem = {}

-- Internal helper: subscribe to an EventBus event and return an unsubscribe fn.
--  Usage:
--    local un = _listen(bus, 'OnCast', handler, pr)
--    ... later ...
--    un()  -- removes that listener
local function _listen(bus, name, fn, pr)
  bus:on(name, fn, pr)
  return function()
    local b = bus.listeners[name]
    if not b then return end
    for i = #b, 1, -1 do
      if b[i].fn == fn then
        table.remove(b, i)
        break
      end
    end
  end
end

--- Equip an item to an entity.
--  Applies stat mods, installs gear-wide conversions, attaches proc listeners,
--  and grants active spells. Recomputes stats at the end.
--  @param ctx table: expects ctx.bus (EventBus)
--  @param e   table: entity with `stats`, optional `equipped`, `gear_conversions`, etc.
--  @param item table: see example at bottom for shape
--  @return boolean ok, string|nil err
function ItemSystem.equip(ctx, e, item)
  -- Gate by attribute and slot rules
  local ok, err = Items.can_equip(e, item)
  if not ok then return false, err end

  e.equipped = e.equipped or {}
  if e.equipped[item.slot] then
    ItemSystem.unequip(ctx, e, item.slot)
  end

  -- Apply stat mods (tracked for clean removal)
  item._applied = {}
  for _, m in ipairs(item.mods or {}) do
    local n = m.stat
    if m.base then
      e.stats:add_base(n, m.base)
      table.insert(item._applied, { 'base', n, m.base })
    end
    if m.add_pct then
      e.stats:add_add_pct(n, m.add_pct)
      table.insert(item._applied, { 'add_pct', n, m.add_pct })
    end
    if m.mul_pct then
      e.stats:add_mul_pct(n, m.mul_pct)
      table.insert(item._applied, { 'mul_pct', n, m.mul_pct })
    end
  end

  -- Gear-wide conversions (append to entity’s list and remember the range)
  if item.conversions then
    e.gear_conversions = e.gear_conversions or {}
    item._conv_start = #e.gear_conversions
    for _, cv in ipairs(item.conversions) do
      table.insert(e.gear_conversions, cv)
    end
    item._conv_end = #e.gear_conversions
  end

  -- Passive procs: subscribe handlers to the bus; store unsub fns
  item._unsubs = {}
  for _, p in ipairs(item.procs or {}) do
    local handler = function(ev)
      -- Default filter: only when this entity is the source (unless p.filter overrides)
      if p.filter then
        if not p.filter(ev) then return end
      else
        if ev.source ~= e then return end
      end

      if math.random() * 100 <= (p.chance or 100) then
        local tgt = ev.target or e
        p.effects(ctx, e, tgt)
      end
    end

    table.insert(item._unsubs, _listen(ctx.bus, p.trigger, handler))
  end

  -- Granted actives: toggle spell availability on the entity
  if item.granted_spells then
    e.granted_spells = e.granted_spells or {}
    for _, id in ipairs(item.granted_spells) do
      e.granted_spells[id] = true
    end
  end

  -- Commit equip and recompute stats
  e.equipped[item.slot] = item
  e.stats:recompute()
  return true
end

--- Unequip the item in a given slot from an entity.
--  Reverses stat mods, removes conversions, unsubscribes proc listeners,
--  clears granted actives for that item, and recomputes stats.
--  @return boolean ok, string|nil err
function ItemSystem.unequip(ctx, e, slot)
  local item = e.equipped and e.equipped[slot]
  if not item then return false, 'empty_slot' end

  -- Revert stat mods (mirror of equip tracking)
  for _, ap in ipairs(item._applied or {}) do
    local kind, n, amt = ap[1], ap[2], ap[3]
    if     kind == 'base'    then e.stats:add_base   (n, -amt)
    elseif kind == 'add_pct' then e.stats:add_add_pct(n, -amt)
    elseif kind == 'mul_pct' then e.stats:add_mul_pct(n, -amt)
    end
  end

  -- Remove conversions appended by this item
  if item._conv_start then
    for i = item._conv_end, item._conv_start + 1, -1 do
      table.remove(e.gear_conversions, i)
    end
    item._conv_start, item._conv_end = nil, nil
  end

  -- Unsubscribe proc listeners
  for _, un in ipairs(item._unsubs or {}) do
    un()
  end

  -- Remove granted actives
  if item.granted_spells and e.granted_spells then
    for _, id in ipairs(item.granted_spells) do
      e.granted_spells[id] = nil
    end
  end

  -- Clear equip slot and recompute
  e.equipped[slot] = nil
  e.stats:recompute()
  return true
end

--[[ ---------------------------------------------------------------------------
Example item (commented):

local Flamebrand = {
  id='flamebrand', slot='sword1',
  requires = { attribute='cunning', value=12, mode='sole' },

  mods = {
    { stat='weapon_min', base=6 },
    { stat='weapon_max', base=10 },
    { stat='fire_modifier_pct', add_pct=15 },
  },

  conversions = {
    { from='physical', to='fire', pct=25 }
  },

  procs = {
    {
      trigger='OnBasicAttack',
      chance=30,
      effects = Effects.deal_damage{
        components = { { type='fire', amount=40 } },
        tags = { ability = true }
      },
    },
  },

  granted_spells = { 'Fireball' },
}

-- usage:
-- assert(ItemSystem.equip(ctx, hero, Flamebrand))
---------------------------------------------------------------------------]]



---------------------------
-- Direct Casting: Cast (costs, cooldowns, OnCast emission)
---------------------------
local Cast = {}

-- Internal: safe stat fetch
-- Stats:get returns 0 for undefined names via our fallback; this just guards nil.
local function _get(S, name)
  local ok = S and S.get
  if not ok then return 0 end
  return S:get(name) or 0
end

--- Cast a spell from an entity.
--  @param ctx table: needs ctx.bus (EventBus), ctx.time (Time), get_enemies_of/get_allies_of
--  @param caster table: entity with .stats, .timers, .energy
--  @param spell_ref table|string: spell table or key in Content.Spells
--  @param primary_target any|nil: optional explicit target (bypasses spell.targeter)
--  @return boolean ok, string|nil err
function Cast.cast(ctx, caster, spell_ref, primary_target)
  local spell = (type(spell_ref) == 'string') and Content.Spells[spell_ref] or spell_ref
  if not spell then return false, 'unknown_spell' end

  -- Cooldown ----------------------------------------------------------
  caster.timers = caster.timers or {}
  local key = 'cd:' .. (spell.id or spell.name or 'spell')
  local cd  = spell.cooldown or 0

  -- Item-granted spells ignore caster cooldown reduction
  if not spell.item_granted then
    local cdr = _get(caster.stats, 'cooldown_reduction')
    cd = cd * math.max(0, 1 - cdr / 100)
  end

  if not ctx.time:is_ready(caster.timers, key) then
    return false, 'cooldown'
  end

  -- Costs -------------------------------------------------------------
  if spell.cost then
    local red  = _get(caster.stats, 'skill_energy_cost_reduction')
    local cost = spell.cost * math.max(0, 1 - red / 100)

    caster.energy = caster.energy or _get(caster.stats, 'energy')
    if caster.energy < cost then
      return false, 'no_energy'
    end
    caster.energy = caster.energy - cost
  end

  -- Fire uniform trigger for listeners (SAP-style "ability used")
  ctx.bus:emit('OnCast', {
    ctx    = ctx,
    source = caster,
    spell  = spell,
    target = primary_target
  })

  -- Target resolution -------------------------------------------------
  local tgt_list
  if primary_target then
    tgt_list = { primary_target }
  else
    tgt_list = spell.targeter({
      source        = caster,
      target        = primary_target,
      get_enemies_of= ctx.get_enemies_of,
      get_allies_of = ctx.get_allies_of,
    })
  end

  -- Execute spell effects for all targets
  for _, t in ipairs(tgt_list or {}) do
    spell.effects(ctx, caster, t)
  end

  -- Start cooldown
  ctx.time:set_cooldown(caster.timers, key, cd)
  return true
end


local Demo = {}

function Demo.run()
  math.randomseed(os.time())

  -- Core context --------------------------------------------------------------
  local bus   = EventBus.new()
  local time  = Time.new()
  local defs, DTS = StatDef.make()
  local combat    = Combat.new(RR, DTS)

  local ctx = {
    debug = true,  -- Set to true for verbose debug output
    bus = bus,
    time = time,
    combat = combat,

    -- Side-aware accessors (hero is side1, ogre is side2).
    get_enemies_of = function(a) return a.side == 1 and ctx.side2 or ctx.side1 end,
    get_allies_of  = function(a) return a.side == 1 and ctx.side1 or ctx.side2 end,
  }

  -- Create actors -------------------------------------------------------------
  local hero = make_actor('Hero', defs, Content.attach_attribute_derivations)
  hero.side = 1
  hero.stats:add_base('physique',    16)
  hero.stats:add_base('cunning',     14)
  hero.stats:add_base('spirit',      10)
  hero.stats:add_base('weapon_min',  12)
  hero.stats:add_base('weapon_max',  18)
  hero.stats:add_base('life_steal_pct', 12)
  hero.stats:recompute()

  local ogre = make_actor('Ogre', defs, Content.attach_attribute_derivations)
  ogre.side = 2
  ogre.stats:add_base('health', 260)
  ogre.stats:add_base('defensive_ability', 95)
  ogre.stats:add_base('armor', 40)
  ogre.stats:add_base('armor_absorption_bonus_pct', 20)
  ogre.stats:add_base('fire_resist_pct', 50)
  ogre.stats:recompute()

  ctx.side1 = { hero }
  ctx.side2 = { ogre }

  -- Event listeners -----------------------------------------------------------
  bus:on('OnHitResolved', function(ev)
    print(string.format(
      '[%s] hit [%s] for %.1f (crit=%s, PTH=%.1f%%)  HP: %.1f/%.1f',
      ev.source.name, ev.target.name, ev.damage, tostring(ev.crit),
      ev.pth, ev.target.hp, ev.target.max_health))
  end)

  bus:on('OnHealed', function(ev)
    print(string.format(
      '[%s] healed %.1f  HP: %.1f/%.1f',
      ev.target.name, ev.amount, ev.target.hp, ev.target.max_health))
  end)

  bus:on('OnDotApplied', function(ev)
    print(string.format(
      '[%s] applied DOT %s to [%s]',
      ev.source.name, ev.dot.type, ev.target.name))
  end)

  bus:on('OnCounterAttack', function(ev)
    print(string.format(
      '[%s] counter-attacked [%s]!',
      ev.source.name, ev.target.name))
  end)
  
  bus:on('OnRRApplied', function(ev)
    print(string.format(
      '[%s] applied %s RR to [%s] for %.1f%%',
      ev.source.name, ev.kind, ev.target.name, ev.amount))
  end)
  
  
  bus:on('OnMiss', function(ev)
    print(string.format(
      '[%s] missed [%s]!',
      ev.source.name, ev.target.name))
  end)

  -- Simulation sequence -------------------------------------------------------
  -- 1. Basic attack
  Effects.deal_damage { weapon = true, scale_pct = 100 } (ctx, hero, ogre)

  --    Ember Strike proc chance
  if util.rand() * 100.0 < (Content.Traits.EmberStrike.chance or 0) then
    Content.Traits.EmberStrike.effects(ctx, hero, ogre)
  end
  
  util.dump_stats(ogre, ctx, { rr=true, dots=true, statuses=true, conv=true, spells=true, tags=true, timers=true })

  -- 2. Cast Fireball
  local FB = Content.Spells.Fireball
  for _, t in ipairs(FB.targeter({ source = hero, target = ogre, get_enemies_of = ctx.get_enemies_of })) do
    FB.effects(ctx, hero, t)
  end
  
  util.dump_stats(ogre, ctx, { rr=true, dots=true, statuses=true, conv=true, spells=true, tags=true, timers=true })

  -- 3. Cast Poison Dart and tick DoTs
  local PD = Content.Spells.PoisonDart
  for _, t in ipairs(PD.targeter({ source = hero, target = ogre, get_enemies_of = ctx.get_enemies_of })) do
    PD.effects(ctx, hero, t)
  end
  for i = 1, 6 do
    World.update(ctx, 1.0)
  end
  
  -- check that ogre RR from fireball has disappeared
  util.dump_stats(ogre, ctx, { rr=true, dots=true, statuses=true, conv=true, spells=true, tags=true, timers=true })

  -- 4. Custom trigger: provoke (forces counter-attack)
  bus:on('OnProvoke', function(ev)
    print(string.format('[%s] provoked [%s]!', ev.source.name, ev.target.name))
    Effects.force_counter_attack { scale_pct = 40 } (ctx, ev.target, ev.source)
  end)

  ctx.bus:emit('OnProvoke', { source = hero, target = ogre })
  
  
  -- try item equip
  local Flamebrand = {
    id='flamebrand', slot='sword1',
    requires = { attribute='cunning', value=12, mode='sole' },

    mods = {
      { stat='weapon_min', base=6 },
      { stat='weapon_max', base=10 },
      { stat='fire_modifier_pct', add_pct=15 },
    },

    conversions = {
      { from='physical', to='fire', pct=25 }
    },

    procs = {
      {
        trigger='OnBasicAttack',
        chance=70,
        effects = Effects.deal_damage{
          components = { { type='fire', amount=40 } },
          tags = { ability = true }
        },
      },
    },

    granted_spells = { 'Fireball' },
  }
  
  util.dump_stats(hero, ctx, { rr=true, dots=true, statuses=true, conv=true, spells=true, tags=true, timers=true })
  
  assert(ItemSystem.equip(ctx, hero, Flamebrand))
  
  util.dump_stats(hero, ctx, { rr=true, dots=true, statuses=true, conv=true, spells=true, tags=true, timers=true })
  
  ctx.bus:emit('OnBasicAttack', { source = hero, target = ogre })
  ctx.bus:emit('OnBasicAttack', { source = hero, target = ogre })
  ctx.bus:emit('OnBasicAttack', { source = hero, target = ogre })
  
  
  -- (1) Player presses key: cast Fireball at a chosen enemy now
  
  local ok, why = Cast.cast(ctx, hero, 'Fireball', ogre)

  -- (2) Item-granted active with its own cooldown unaffected by CDR:
  -- mark the spell once at init-time:
  Content.Spells.Fireball.item_granted = true
  
  util.dump_stats(ogre, ctx, { rr=true, dots=true, statuses=true, conv=true, spells=true, tags=true, timers=true })

  -- (3) A ground-targeted or self-targeted buff:
  -- just pass the appropriate primary_target, or leave nil and let targeter select.

end




local _core = dofile and package and package.loaded and package.loaded['part1_core'] or nil
if not _core then _core = (function() return Core end)() end
local _game = (function() return { Effects = Effects, Combat = Combat, Items = Items, Leveling = Leveling, Content =
  Content, StatusEngine = StatusEngine, World = World, ItemSystem = ItemSystem, Cast = Cast, Demo = Demo } end)()

return { Core = _core, Game = _game }
