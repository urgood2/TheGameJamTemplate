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

-- ============================================================================
-- Gameplay Modules (namespaces)
-- These are placeholders for organization; you can attach functions later.
-- ============================================================================
local Effects, Combat, Items, Leveling, Content, StatusEngine, World = {}, {}, {}, {}, {}, {}, {}

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

-- === Spell identity & grant helpers =========================================
local function get_spell_id(spell_ref)
  local s = (type(spell_ref) == 'table') and spell_ref or Content.Spells[spell_ref]
  return (s and (s.id or s.name)) or tostring(spell_ref)
end

local function is_item_granted(caster, spell_ref)
  local id = get_spell_id(spell_ref)
  return caster and caster.granted_spells and caster.granted_spells[id] == true
end
-- ============================================================================

-- === Ability level per-entity ===============================================
local function get_ability_level(e, spell_ref)
  local id = get_spell_id(spell_ref)
  return (e.ability_levels and e.ability_levels[id]) or 1
end

local function set_ability_level(e, spell_ref, lvl)
  e.ability_levels = e.ability_levels or {}
  e.ability_levels[get_spell_id(spell_ref)] = math.max(1, math.floor(lvl or 1))
end
-- ============================================================================

-- === Aggregate item-driven ability mods =====================================
-- Accumulates item-provided mods for a specific spell id.
-- Supports: dmg_pct (outgoing damage), cd_add (seconds), cost_pct (%).
local function collect_ability_mods(caster, spell_ref)
  local id = get_spell_id(spell_ref)
  local out = { dmg_pct = 0, cd_add = 0, cost_pct = 0 }
  if not caster or not caster.equipped then return out end
  for _, it in pairs(caster.equipped) do
    local m = it.ability_mods and it.ability_mods[id]
    if m then
      out.dmg_pct  = out.dmg_pct  + (m.dmg_pct  or 0)
      out.cd_add   = out.cd_add   + (m.cd_add   or 0)
      out.cost_pct = out.cost_pct + (m.cost_pct or 0)
    end
  end
  return out
end
-- ============================================================================

-- === Spell mutator pipeline ==================================================
-- A mutator is: function(orig_effects_fn) -> new_effects_fn
local function apply_spell_mutators(caster, ctx, spell_ref, effects_fn)
  local id = get_spell_id(spell_ref)
  local muts = caster and caster.spell_mutators and caster.spell_mutators[id]

  if muts and #muts > 0 then
    -- sort by priority if present
    table.sort(muts, function(a, b) return (a.pr or 0) < (b.pr or 0) end)

    if caster and ctx.debug then
      print(string.format("[DEBUG][Mutators] Applying %d mutator(s) to spell '%s'", #muts, tostring(id)))
    end

    for i = 1, #muts do
      local m = muts[i]
      if caster and ctx.debug then
        print(string.format("[DEBUG][Mutators]   #%d pr=%s wrap=%s", 
          i, tostring(m.pr or 0), tostring(m.wrap)))
      end
      effects_fn = m.wrap(effects_fn)
    end
  else
    if caster and ctx.debug then
      print(string.format("[DEBUG][Mutators] No mutators for spell '%s'", tostring(id)))
    end
  end

  return effects_fn
end
-- ============================================================================


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

  -- Level progress (safe against missing Leveling.xp_to_next)
  do
    local lvl = e.level or 1
    local xp  = e.xp or 0
    local need
    if Leveling and Leveling.xp_to_next then
      local ok, res = pcall(Leveling.xp_to_next, ctx, e, lvl)
      need = ok and res or (lvl * 1000)
    else
      need = lvl * 1000
    end
    local pct = (need > 0) and (xp / need * 100) or 0
    add(("Level  | L=%d  XP %.1f/%d (%.1f%%)"):format(lvl, xp, need, pct))
  end

  -- Equipped items + available slots
  do
    local eq = e.equipped or {}
    -- Equipped summary (sorted by slot)
    local slot_keys = {}
    for k in pairs(eq) do slot_keys[#slot_keys+1] = k end
    table.sort(slot_keys)
    if #slot_keys > 0 then
      local parts = {}
      for _, slot in ipairs(slot_keys) do
        local it = eq[slot]
        local label = it and (it.name or it.id or "?") or "-"
        parts[#parts+1] = string.format("%s=%s", slot, label)
      end
      add("Equip  | " .. join(parts, "  "))
    else
      add("Equip  | (none)")
    end

    -- Available/free slots (best-effort)
    local all = {}
    local function add_slotname(s) if s and s ~= "" then all[s] = true end end

    if Items then
      if type(Items.SLOTS) == "table" then
        for k, v in pairs(Items.SLOTS) do
          if type(k) == "number" then add_slotname(v) else add_slotname(k) end
        end
      end
      if type(Items.SlotOrder) == "table" then
        for i=1,#Items.SlotOrder do add_slotname(Items.SlotOrder[i]) end
      end
    end
    if Content and type(Content.ItemSlots) == "table" then
      for k, v in pairs(Content.ItemSlots) do
        if type(k) == "number" then add_slotname(v) else add_slotname(k) end
      end
    end
    if ctx and type(ctx.item_slots) == "table" then
      for k, v in pairs(ctx.item_slots) do
        if type(k) == "number" then add_slotname(v) else add_slotname(k) end
      end
    end
    -- Always include any slots we see in equipped
    for s in pairs(eq) do add_slotname(s) end

    local free = {}
    for s in pairs(all) do
      if eq[s] == nil then free[#free+1] = s end
    end
    table.sort(free)
    if next(all) ~= nil then
      add("Slots  | Free: " .. (#free > 0 and join(free, ", ") or "(none)"))
    else
      add("Slots  | (unknown slot set)")
    end
  end

  -- Enabled skills (innate + granted)
  do
    local set = {}
    local function add_skills(container)
      if type(container) ~= "table" then return end
      if #container > 0 then
        for i=1,#container do
          local v = container[i]
          if type(v) == "string" then
            set[v] = true
          elseif type(v) == "table" then
            local id = v.id or v.name
            if id then set[id] = true end
          end
        end
      else
        for k, v in pairs(container) do
          if v then set[tostring(k)] = true end
        end
      end
    end

    add_skills(e.spells)
    add_skills(e.known_spells)
    add_skills(e.innate_spells)
    add_skills(e.abilities)
    add_skills(e.granted_spells)

    local skills = {}
    for id in pairs(set) do skills[#skills+1] = id end
    table.sort(skills)
    add("Skills | " .. (#skills > 0 and join(skills, ", ") or "(none)"))
  end

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

  -- Optional: Statuses (buffs/debuffs)
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

  -- Optional: Granted spells (legacy view)
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

  -- Optional: Cooldown snapshot
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
  
  -- cooldowns and energy costs
  add_basic(defs, 'cooldown_reduction')               -- % reduces cooldowns (non-item-granted)
  add_basic(defs, 'skill_energy_cost_reduction')      -- % cheaper


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
    values = {},
    derived_hooks = {},
    _derived_marks = {},    -- track derived deltas: { {kind, name, amount}, ... }
  }
  for n, d in pairs(defs) do
    t.values[n] = { base = d.base, add_pct = 0, mul_pct = 0 }
  end
  return setmetatable(t, Stats)
end

-- Helpers to safely add derived deltas:
function Stats:_mark(kind, n, amt)
  self._derived_marks[#self._derived_marks+1] = { kind, n, amt }
end
function Stats:derived_add_base(n, a)    self.values[n].base    = self.values[n].base    + a; self:_mark('base',    n, a) end
function Stats:derived_add_add_pct(n, a) self.values[n].add_pct = self.values[n].add_pct + a; self:_mark('add_pct', n, a) end
function Stats:derived_add_mul_pct(n, a) self.values[n].mul_pct = self.values[n].mul_pct + a; self:_mark('mul_pct', n, a) end

-- Remove past derived deltas
function Stats:_clear_derived()
  for i = #self._derived_marks, 1, -1 do
    local kind, n, amt = self._derived_marks[i][1], self._derived_marks[i][2], self._derived_marks[i][3]
    if     kind == 'base'    then self.values[n].base    = self.values[n].base    - amt
    elseif kind == 'add_pct' then self.values[n].add_pct = self.values[n].add_pct - amt
    elseif kind == 'mul_pct' then self.values[n].mul_pct = self.values[n].mul_pct - amt
    end
  end
  self._derived_marks = {}
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
  -- 1) remove previous derived
  self:_clear_derived()
  -- 2) re-run derived hooks
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

-- Extend Cond with ctx-aware predicates (keep your old ones for per-entity checks)
function Cond.chance(pct)
  return function(ctx, ev, src, tgt) return math.random()*100 <= pct end
end

function Cond.has_status_id(id)
  return function(ctx, ev, src, tgt)
    local b = tgt and tgt.statuses and tgt.statuses[id]
    return b and #b.entries > 0
  end
end

function Cond.event_has_tag(tag)
  return function(ctx, ev) return ev and ev.tags and ev.tags[tag] end
end

function Cond.time_since_ev_le(dtmax)
  return function(ctx, ev) return ev and ev.time and (ctx.time.now - ev.time) <= dtmax end
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

-- Parallel executor (fire-and-forget effects on same tick)
Effects.par = function(list)
  return function(ctx, src, tgt)
    for i=1,#list do list[i](ctx, src, tgt) end
  end
end

-- Cleanse: remove debuffs/status entries by id/predicate
Effects.cleanse = function(p)
  -- p = { ids = {...} } or { predicate = function(id, entry) return true end }
  return function(ctx, src, tgt)
    if not tgt.statuses then return end
    for id, b in pairs(tgt.statuses) do
      local keep = {}
      for _, entry in ipairs(b.entries) do
        local remove =
          (p.ids and p.ids[id]) or
          (p.predicate and p.predicate(id, entry)) or
          false
        if remove then
          if entry.remove then entry.remove(tgt) end
          ctx.bus:emit('OnStatusExpired', { entity=tgt, id=id })
        else
          keep[#keep+1] = entry
        end
      end
      b.entries = keep
    end
  end
end

-- Extras Siralim-like (engine-backed) – safe stubs you can wire later:
Effects.resurrect = function(p)
  -- p={ hp_pct=50 }
  return function(ctx, src, tgt)
    if tgt.dead then
      tgt.dead = false
      local maxhp = tgt.max_health or tgt.stats:get('health')
      tgt.hp = math.max(tgt.hp or 0, maxhp * ((p.hp_pct or 50)/100))
      ctx.bus:emit('OnResurrect', { source=src, target=tgt, hp=tgt.hp })
    end
  end
end

Effects.summon = function(p)
  -- p={ blueprint='Wolf', count=1, side_of='source' }
  return function(ctx, src, tgt)
    if not ctx.spawn_entity then return end -- plug in your factory when ready
    for i=1,(p.count or 1) do ctx.spawn_entity(ctx, p.blueprint, p.side_of=='target' and tgt or src) end
  end
end

Effects.grant_extra_turn = function(p)
  -- requires your turn scheduler; for now, emit an intent event
  return function(ctx, src, tgt)
    ctx.bus:emit('OnExtraTurnGranted', { entity=tgt or src })
  end
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
    local crit_bonus = 1 + (src.stats:get('crit_damage_pct') or 0) / 100
    crit_mult = crit_mult * crit_bonus
    dbg("PTH-derived crit multiplier (with crit_damage_pct bonus): %.2f", crit_mult)
    
    -- Dodge (early-out, before block)
    local dodge = tgt.stats:get('dodge_chance_pct') or 0
    if math.random() * 100 < dodge then
      dbg("Target dodged!")
      ctx.bus:emit('OnDodge', { source = src, target = tgt, pth = PTH })
      return
    end

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
    
    if tgt.hp <= 0 and not tgt.dead then
      tgt.dead = true
      ctx.bus:emit('OnDeath', { entity = tgt, killer = src })
    end

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
  p = p or {}
  local scale = p.scale_pct or 100

  return function(ctx, src, tgt)         -- src = counter-attacker (Ogre), tgt = defender (Hero)
    if not src or src.dead or not tgt or tgt.dead then return end

    -- ✅ attacker is src, defender is tgt
    Effects.deal_damage { weapon = true, scale_pct = scale } (ctx, src, tgt)

    if ctx and ctx.bus and ctx.bus.emit then
      ctx.bus:emit('OnCounterAttack', { source = src, target = tgt, scale_pct = scale, is_counter = true })
    end
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

-- === Leveling curve registry ================================================
Leveling.curves = Leveling.curves or {}

-- Register a curve by id. fn(level) -> xp_to_next
function Leveling.register_curve(id, fn)
  Leveling.curves[id] = fn
end

-- Resolve xp needed for next level for entity e at its current level (or given L)
function Leveling.xp_to_next(ctx, e, L)
  local level = L or (e.level or 1)
  local curve_id = e.level_curve or 'default'
  local fn = Leveling.curves[curve_id] or Leveling.curves['default']
  return (fn and fn(level)) or (1000 * level) -- fallback
end

-- Defaults: current behavior
Leveling.register_curve('default', function(level)
  return 1000 * level
end)

-- Example alternates (optional):
Leveling.register_curve('fast_start', function(level)   -- generous early levels
  return math.floor(600 + (level - 1) * 800)
end)

Leveling.register_curve('veteran', function(level)      -- steeper
  return math.floor(1200 + (level - 1) * 1100)
end)
-- ============================================================================

-- ============================================================================
-- Leveling
-- Simple EXP -> Level conversion:
--   - xp threshold per level = (level * 1000)
--   - on level-up: +1 attribute point, +3 skill points, +1 mastery up to 2,
--     +10 OA and +10 DA via base add.
-- Emits: 'OnLevelUp' and 'OnExperienceGained' events.
-- ============================================================================
function Leveling.grant_exp(ctx, e, base)
  local pct = 0
  if e.stats and e.stats.get then
    pct = e.stats:get('experience_gained_pct') or 0
  end
  local gained = base * (1 + pct / 100)

  e.level = e.level or 1
  e.xp    = (e.xp or 0) + gained

  local levels_gained = 0
  while true do
    local need = Leveling.xp_to_next(ctx, e, e.level or 1)
    if (e.xp or 0) >= need then
      e.xp = (e.xp or 0) - need
      Leveling.level_up(ctx, e)         -- assumes this increments e.level
      e.level = e.level or (levels_gained + 2) -- belt-and-suspenders if level_up forgot
      levels_gained = levels_gained + 1
    else
      break
    end
  end

  if ctx and ctx.debug then
    local next_threshold = Leveling.xp_to_next(ctx, e, e.level or 1)
    local to_next = next_threshold - (e.xp or 0)
    print(string.format(
      "[DEBUG][Leveling] Level: %d | XP: %.1f | Next Threshold: %d | To Next: %.1f | Gained: %.1f (pct=%.1f%%) | Levels+%d",
      e.level, e.xp or 0, next_threshold, to_next, gained, pct, levels_gained
    ))
  end

  if ctx and ctx.bus and ctx.bus.emit then
    ctx.bus:emit('OnExperienceGained', { entity = e, amount = gained, levels = levels_gained })
  end

  return gained, levels_gained
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

    S:derived_add_base('health', 100 + p * 10)
    local extra = math.max(0, p - 10)
    S:derived_add_base('health_regen', extra * 0.2)

    S:derived_add_base('offensive_ability', c * 1)
    local chunks_c = math.floor(c / 5)
    S:derived_add_add_pct('physical_modifier_pct', chunks_c * 1)
    S:derived_add_add_pct('pierce_modifier_pct',   chunks_c * 1)
    S:derived_add_add_pct('bleed_duration_pct',    chunks_c * 1)
    S:derived_add_add_pct('trauma_duration_pct',   chunks_c * 1)

    S:derived_add_base('health',       s * 2)
    S:derived_add_base('energy',       s * 10)
    S:derived_add_base('energy_regen', s * 0.5)

    local chunks_s = math.floor(s / 5)
    for _, t in ipairs({ 'fire', 'cold', 'lightning', 'acid', 'vitality', 'aether', 'chaos' }) do
      S:derived_add_add_pct(t .. '_modifier_pct', chunks_s * 1)
    end
    for _, t in ipairs({ 'burn', 'frostburn', 'electrocute', 'poison', 'vitality_decay' }) do
      S:derived_add_add_pct(t .. '_duration_pct', chunks_s * 1)
    end
  end)
end

-- Example Spells ------------------------------------------------------
-- Each spell: { name, class, trigger, targeter(ctx)->targets, effects(ctx,src,tgt) }
Content.Spells = {
  -- Fireball = {
  --   name     = 'Fireball',
  --   class    = 'pyromancy',
  --   trigger  = 'OnCast',
  --   targeter = function(ctx) return { ctx.target } end,
  --   effects  = Effects.seq {
  --     Effects.deal_damage { components = { { type = 'fire', amount = 120 } } },
  --     Effects.apply_rr    { kind = 'rr1', damage = 'fire', amount = 20, duration = 4, stack = { mode='count', max=3 }  -- enables up to 3 concurrent stacks
  --     },
  --   },
  -- },
  
  Fireball = {
    id           = 'Fireball', -- optional ID, can differ from name
    name         = 'Fireball',
    class        = 'pyromancy',
    trigger      = 'OnCast',
    item_granted = true, -- optional, used for item-granted spells which don't get cooldown reduction
    targeter = function(ctx) return { ctx.target } end,

    -- Level/mod-aware builder. If absent, Cast.cast falls back to .effects.
    build = function(level, mods)
      level = level or 1
      mods  = mods or { dmg_pct = 0 }

      local base = 120 + (level - 1) * 40      -- +40 per level
      local rr   = 20  + (level - 1) * 5       -- +5% RR per level
      local dmg_scale = 1 + (mods.dmg_pct or 0) / 100

      -- return Effects.seq {
      --   Effects.deal_damage {
      --     components = { { type = 'fire', amount = base * dmg_scale } }
      --   },
      --   Effects.apply_rr {
      --     kind = 'rr1', damage = 'fire', amount = rr, duration = 4
      --   },
      -- }
      
      return function (ctx, src, tgt)
        -- If Cast.cast already called .build, .effects won’t be used.
        Effects.deal_damage { components = { { type='fire', amount = base * dmg_scale } } } (ctx, src, tgt)
        Effects.apply_rr { kind='rr1', damage='fire', amount=rr, duration=4 } (ctx, src, tgt)
      end
    end,

    -- Backward compatible default:
    effects = function(ctx, src, tgt)
      -- If Cast.cast already called .build, .effects won’t be used.
      Effects.deal_damage { components = { { type='fire', amount = 120 } } } (ctx, src, tgt)
      Effects.apply_rr { kind='rr1', damage='fire', amount=20, duration=4 } (ctx, src, tgt)
    end,
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
  
  -- RR pruning
  if e.active_rr then
    for t, bucket in pairs(e.active_rr) do
      local kept = {}
      for i = 1, #bucket do
        local r = bucket[i]
        if (not r.until_time) or r.until_time > ctx.time.now then kept[#kept+1] = r end
      end
      e.active_rr[t] = kept
    end
  end

  -- Tick DoTs -----------------------------------------------------------------
  if e.dots then
    local kept = {}
    for _, d in ipairs(e.dots) do
      if d.until_time and d.until_time <= ctx.time.now then
        ctx.bus:emit('OnDotExpired', { entity = e, dot = d })
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
  
  local function regen(ent)
    if not ent.stats then return end
    -- Health regen
    local maxhp  = ent.max_health or ent.stats:get('health')
    local hpr    = ent.stats:get('health_regen') or 0
    if hpr ~= 0 then
      ent.hp = util.clamp((ent.hp or maxhp) + hpr * dt, 0, maxhp)
    end
    -- Energy regen
    ent.max_energy = ent.max_energy or ent.stats:get('energy')
    ent.energy     = ent.energy     or ent.max_energy
    local epr = ent.stats:get('energy_regen') or 0
    if epr ~= 0 then
      ent.energy = util.clamp(ent.energy + epr * dt, 0, ent.max_energy)
    end
  end

  local function each(L)
    for _, ent in ipairs(L or {}) do
      StatusEngine.update_entity(ctx, ent, dt)
      regen(ent)
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
  local en = s:get('energy')

  return {
    name            = name,
    stats           = s,
    hp              = hp,
    max_health      = hp,
    energy          = en,
    max_energy      = en,
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
  if ctx.debug then
    print(string.format("[DEBUG][ItemSystem] Attempting to equip item '%s' into slot '%s'", item.id or "?", item.slot or "?"))
  end

  -- Gate by attribute and slot rules
  local ok, err = Items.can_equip(e, item)
  if not ok then
    if ctx.debug then
      print(string.format("[DEBUG][ItemSystem] Cannot equip '%s': %s", item.id or "?", err or "unknown error"))
    end
    return false, err
  end

  e.equipped = e.equipped or {}
  if e.equipped[item.slot] then
    if ctx.debug then
      print(string.format("[DEBUG][ItemSystem] Slot '%s' already occupied, unequipping current item", item.slot))
    end
    ItemSystem.unequip(ctx, e, item.slot)
  end

  -- Apply stat mods (tracked for clean removal)
  item._applied = {}
  for _, m in ipairs(item.mods or {}) do
    local n = m.stat
    if m.base then
      e.stats:add_base(n, m.base)
      table.insert(item._applied, { 'base', n, m.base })
      if ctx.debug then
        print(string.format("[DEBUG][ItemSystem] Applied base mod: %s %+d", n, m.base))
      end
    end
    if m.add_pct then
      e.stats:add_add_pct(n, m.add_pct)
      table.insert(item._applied, { 'add_pct', n, m.add_pct })
      if ctx.debug then
        print(string.format("[DEBUG][ItemSystem] Applied add_pct mod: %s %+d%%", n, m.add_pct))
      end
    end
    if m.mul_pct then
      e.stats:add_mul_pct(n, m.mul_pct)
      table.insert(item._applied, { 'mul_pct', n, m.mul_pct })
      if ctx.debug then
        print(string.format("[DEBUG][ItemSystem] Applied mul_pct mod: %s %+d%%", n, m.mul_pct))
      end
    end
  end

  -- Gear-wide conversions (append to entity’s list and remember the range)
  if item.conversions then
    e.gear_conversions = e.gear_conversions or {}
    item._conv_start = #e.gear_conversions
    for _, cv in ipairs(item.conversions) do
      table.insert(e.gear_conversions, cv)
      if ctx.debug then
        print(string.format("[DEBUG][ItemSystem] Added conversion: %s -> %s", cv.from or "?", cv.to or "?"))
      end
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
        if ctx.debug then
          print(string.format("[DEBUG][ItemSystem] Proc triggered on '%s': %s", item.id or "?", p.trigger or "?"))
        end
        p.effects(ctx, e, tgt)
      elseif ctx.debug then
        print(string.format("[DEBUG][ItemSystem] Proc check failed for '%s' (%s)", item.id or "?", p.trigger or "?"))
      end
    end

    table.insert(item._unsubs, _listen(ctx.bus, p.trigger, handler))
    if ctx.debug then
      print(string.format("[DEBUG][ItemSystem] Subscribed proc for trigger '%s'", p.trigger or "?"))
    end
  end
  
  
  -- Register spell mutators from the item (optional field on items)
  -- item.spell_mutators = {
  --   Fireball = {
  --     { pr = 0, wrap = function(orig) return function(ctx, src, tgt) ... end end },
  --     function(orig) return function(ctx, src, tgt) ... end end,  -- shorthand (pr=0)
  --   },
  --   BasicAttack = { ... }
  -- }
  if item.spell_mutators then
    e.spell_mutators = e.spell_mutators or {}
    item._mut_applied = {}  -- track inserts to remove on unequip

    for spell_key, list in pairs(item.spell_mutators) do
      local sid = get_spell_id(spell_key)  -- supports id or name as key
      local bucket = e.spell_mutators[sid]
      if not bucket then
        bucket = {}
        e.spell_mutators[sid] = bucket
      end

      -- Normalize each mutator to { pr=?, wrap=function } and insert
      for _, entry in ipairs(list) do
        local mut
        if type(entry) == 'function' then
          mut = { pr = 0, wrap = entry }
        else
          -- assume table { pr=?, wrap=function }
          mut = { pr = entry.pr or 0, wrap = entry.wrap }
        end
        table.insert(bucket, mut)
        -- remember where we inserted so we can remove later
        item._mut_applied[#item._mut_applied + 1] = { sid = sid, ref = mut }
      end
    end
  end


  -- Granted actives: toggle spell availability on the entity
  if item.granted_spells then
    e.granted_spells = e.granted_spells or {}
    for _, id in ipairs(item.granted_spells) do
      e.granted_spells[id] = true
      if ctx.debug then
        print(string.format("[DEBUG][ItemSystem] Granted spell: %s", id))
      end
    end
  end

  -- Commit equip and recompute stats
  e.equipped[item.slot] = item
  e.stats:recompute()
  if ctx.debug then
    print(string.format("[DEBUG][ItemSystem] Equipped '%s' into slot '%s'. Stats recomputed.", item.id or "?", item.slot or "?"))
  end
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
  
  -- Unregister mutators added by this item
  if item._mut_applied and e.spell_mutators then
    for i = 1, #item._mut_applied do
      local rec = item._mut_applied[i]
      local bucket = e.spell_mutators[rec.sid]
      if bucket then
        -- remove by identity
        for j = #bucket, 1, -1 do
          if bucket[j] == rec.ref then
            table.remove(bucket, j)
            break
          end
        end
        if #bucket == 0 then
          e.spell_mutators[rec.sid] = nil
        end
      end
    end
    item._mut_applied = nil
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
  local spell = (type(spell_ref) == 'table') and spell_ref or Content.Spells[spell_ref]
  if not spell then return false, 'unknown_spell' end

  local spell_id = get_spell_id(spell)                    -- NEW: canonical id
  caster.timers = caster.timers or {}
  local key = 'cd:' .. spell_id
  local cd  = spell.cooldown or 0

  -- Ability/item mods -------------------------------------------------------- NEW
  local lvl  = get_ability_level(caster, spell)           -- per-caster level
  local mods = collect_ability_mods(caster, spell)        -- dmg/cd/cost mods

  -- Cooldown reduction: skip if item-granted (your policy), then apply cd_add.
  if not is_item_granted(caster, spell) then
    local cdr = _get(caster.stats, 'cooldown_reduction')
    cd = cd * math.max(0, 1 - cdr / 100)
  end
  cd = math.max(0, cd + (mods.cd_add or 0))               -- additive seconds

  if not ctx.time:is_ready(caster.timers, key) then
    return false, 'cooldown'
  end

  -- Cost with reductions and item cost_pct ---------------------------------- NEW
  if spell.cost then
    local red  = _get(caster.stats, 'skill_energy_cost_reduction')
    local cost = spell.cost * math.max(0, 1 - red / 100)
    cost = cost * math.max(0, 1 + (mods.cost_pct or 0) / 100)
    caster.energy = caster.energy or _get(caster.stats, 'energy')
    if caster.energy < cost then
      return false, 'no_energy'
    end
    caster.energy = caster.energy - cost
  end

  ctx.bus:emit('OnCast', {
    ctx    = ctx,
    source = caster,
    spell  = spell,
    spell_id = spell_id,                                   -- NEW
    target = primary_target
  })

  -- Build target list (same as before)
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

  -- Prepare effects function, wrapping with mutators if any ------------------ NEW
  local eff = spell.effects
  -- If the spell provided a level-aware builder, prefer it:
  if spell.build then
    eff = spell.build(lvl, mods)  -- pass both, non-breaking for old spells
  end
  eff = apply_spell_mutators(caster, ctx, spell, eff)

  -- Execute effects
  for _, t in ipairs(tgt_list or {}) do
    eff(ctx, caster, t)
  end

  ctx.time:set_cooldown(caster.timers, key, cd)
  return true
end

-- SKILLS.lua
local Skills = {}

-- Design:
-- - Node kinds: 'active', 'passive', 'modifier', 'transmuter', 'exclusive_aura'
-- - Ranks with soft_cap and ultimate ranks beyond soft_cap with diminishing return curve
-- - Modifiers and transmuters *wrap* base skill using your existing spell_mutators channel
-- - Each skill can optionally be a default-attack replacer (DAR) and/or have WPS entries

local function _lerp(a,b,t) return a + (b-a)*t end
local function _dim_return(x, knee, min_mult)
  if x <= knee then return 1 end
  local over = x - knee
  return math.max(min_mult or 0.5, 1 / (1 + 0.15*over))
end

-- Public DB
Skills.DB = {
  -- Example: Fire Strike-style default attack replacer
  FireStrike = {
    id = 'FireStrike', kind='active', is_dar=true,
    soft_cap = 12, ult_cap = 26,
    -- scaling function returns a table of scalar knobs used by the skill's build()
    scale = function(rank)
      local m = _dim_return(rank, 12, 0.6)
      local flat = 6 + 2.5*rank
      local wpn = 100 + 8*rank
      return { flat_fire = flat*m, weapon_scale_pct = wpn*m }
    end,
    -- optional: add WPS unlocked while investing into this line
    wps_unlocks = { -- id => {chance, effects}
      AmarastasQuickCut = { min_rank=4, chance=20 }, -- details in WPS section
    },
    -- optional default attack on-cast cost/cd hooks
    energy_cost = function(rank) return 0 end,
    cooldown    = function(rank) return 0 end,
  },

  -- Modifiers that *augment* FireStrike's output (applied as mutators)
  ExplosiveStrike = {
    id='ExplosiveStrike', kind='modifier', base='FireStrike',
    soft_cap=12, ult_cap=22,
    apply_mutator = function(rank)
      local radius = 1.8 + 0.05*rank
      local pct    = 30 + 3*rank
      return function(orig)
        return function(ctx, src, tgt)
          -- 1) run original
          if orig then orig(ctx, src, tgt) end
          -- 2) splash
          local allies = ctx.get_enemies_of(src)
          for i=1,#allies do
            local e = allies[i]
            if e ~= tgt then
              Effects.deal_damage{
                components = { { type='fire', amount = (src.stats:get('weapon_max') or 10) * (pct/100) } }
              }(ctx, src, e)
            end
          end
        end
      end
    end
  },

  -- Transmuter: toggled variant that changes base damage type/behavior
  SearingStrike = {
    id='SearingStrike', kind='transmuter', base='FireStrike',
    exclusive=true, -- only one transmuter of a base can be enabled at once
    apply_mutator = function()
      return function(orig)
        return function(ctx, src, tgt)
          -- Override "weapon -> all to fire" feel
          Effects.deal_damage{
            weapon = true, scale_pct = 100,
            skill_conversions = { {from='physical', to='fire', pct=100} }
          }(ctx, src, tgt)
          -- keep original secondary if desired:
          if orig then orig(ctx, src, tgt) end
        end
      end
    end
  },

  -- Passive example
  FlameTouched = {
    id='FlameTouched', kind='passive', soft_cap=12, ult_cap=22,
    apply_stats = function(S, rank)
      S:add_add_pct('fire_modifier_pct', 6 + 1.5*rank)
      S:add_base('offensive_ability', 6 + 2*rank)
    end
  },

  -- Exclusive aura (mutually exclusive—only one can be toggled)
  PossessionLike = {
    id='PossessionLike', kind='exclusive_aura',
    reservation_pct = 25, -- reserve 25% of max energy
    apply_aura = function(ctx, src, rank)
      return Effects.modify_stat { id='possess_aura', name='chaos_modifier_pct', add_pct_add=8 + 2*rank }
    end
  },
}

-- Player state and manipulation
local SkillTree = {}

function SkillTree.create_state()
  return {
    ranks = {}, enabled_transmuter = {}, toggled_exclusive = nil,
    dar_override = nil,
    _mutators = {}, -- { [sid] = {mut1, mut2, ...} } to undo later
    _passive_marks = {}, -- for removing passive stat adds
  }
end

local function _apply_passive(e, id, rank, node)
  local S = e.stats; if not S then return end
  local before = { #S._derived_marks } -- mark start
  if node.apply_stats then node.apply_stats(S, rank) end
  e.skills._passive_marks[id] = { start = before[1] + 1 }
  S:recompute()
end

local function _clear_passive(e, id)
  local mark = e.skills._passive_marks[id]; if not mark then return end
  -- we used permanent adds, so to remove we track via inverse application here:
  -- Simpler: recompute full Stats from base if you keep base copies. For now, ignore removal;
  -- typical flow only ever increases ranks. If you need removal, store diffs like ItemSystem does.
end

local function _attach_mutator(e, base_id, wrap)
  e.spell_mutators = e.spell_mutators or {}
  local bucket = e.spell_mutators[base_id] or {}
  e.spell_mutators[base_id] = bucket
  local rec = { pr=0, wrap=wrap }
  bucket[#bucket+1] = rec
  e.skills._mutators[base_id] = e.skills._mutators[base_id] or {}
  table.insert(e.skills._mutators[base_id], rec)
end

local function _clear_mutators_for(e, base_id)
  if not (e.skills and e.skills._mutators and e.skills._mutators[base_id]) then return end
  local list = e.skills._mutators[base_id]
  local bucket = e.spell_mutators and e.spell_mutators[base_id]
  if bucket then
    for i=#bucket,1,-1 do
      for j=#list,1,-1 do
        if bucket[i] == list[j] then table.remove(bucket, i); table.remove(list, j); break end
      end
    end
    if #bucket == 0 then e.spell_mutators[base_id] = nil end
  end
end

local function _apply_modifier(e, node, rank)
  if not node.base then return end
  _clear_mutators_for(e, node.base)
  local wrap = node.apply_mutator and node.apply_mutator(rank)
  if wrap then _attach_mutator(e, node.base, wrap) end
end

local function _apply_transmuter(e, node)
  if not node.base then return end
  _clear_mutators_for(e, node.base)
  local wrap = node.apply_mutator and node.apply_mutator()
  if wrap then _attach_mutator(e, node.base, wrap) end
end

function SkillTree.set_rank(e, id, rank)
  e.skills = e.skills or SkillTree.create_state()
  local node = Skills.DB[id]; if not node then return false, 'unknown_skill' end
  rank = math.max(0, math.min(rank, node.ult_cap or rank))
  e.skills.ranks[id] = rank

  if node.kind == 'passive' then
    _apply_passive(e, id, rank, node)
  elseif node.kind == 'modifier' then
    _apply_modifier(e, node, rank)
  end

  -- DAR marker
  if node.is_dar and rank > 0 then
    e.skills.dar_override = id
  end

  -- WPS unlocks are handled in WPS module by checking current ranks
  return true
end

function SkillTree.enable_transmuter(e, id)
  local node = Skills.DB[id]; if not (node and node.kind=='transmuter') then return false, 'not_transmuter' end
  e.skills.enabled_transmuter[node.base] = id
  _apply_transmuter(e, node)
  return true
end

function SkillTree.toggle_exclusive(e, id)
  local node = Skills.DB[id]; if not (node and node.kind=='exclusive_aura') then return false, 'not_exclusive' end
  e.skills.toggled_exclusive = (e.skills.toggled_exclusive == id) and nil or id
  return true
end

Skills.SkillTree = SkillTree


-- WPS.lua
local WPS = {}

-- A WPS table: id -> { chance=%, effects = function(ctx, src, tgt) ... }
WPS.DB = {
  AmarastasQuickCut = {
    id='AmarastasQuickCut', chance=20,
    effects = function(ctx, src, tgt)
      -- two rapid weapon strikes at reduced damage
      Effects.deal_damage { weapon=true, scale_pct=70 } (ctx, src, tgt)
      Effects.deal_damage { weapon=true, scale_pct=70 } (ctx, src, tgt)
    end
  },
  MarkoviansAdvantage = {
    id='MarkoviansAdvantage', chance=10,
    effects = function(ctx, src, tgt)
      Effects.deal_damage { weapon=true, scale_pct=180 } (ctx, src, tgt)
      Effects.apply_rr { kind='rr1', damage='physical', amount=10, duration=3 } (ctx, src, tgt)
    end
  },
}

-- WPS bucket resolution: roll once per default attack, pick a single WPS based on weights
local function _roll(wps_list)
  local total=0
  for i=1,#wps_list do total = total + (wps_list[i].chance or 0) end
  if total <= 0 then return nil end
  local r = math.random()*total; local acc=0
  for i=1,#wps_list do
    acc = acc + (wps_list[i].chance or 0)
    if r <= acc then return wps_list[i] end
  end
end

function WPS.collect_for(e, Skills)
  local list = {}
  for id, node in pairs(Skills.DB) do
    if node.wps_unlocks then
      local r = e.skills and e.skills.ranks and e.skills.ranks[node.id] or 0
      for wps_id, spec in pairs(node.wps_unlocks) do
        if r >= (spec.min_rank or 1) then
          local base = WPS.DB[wps_id]
          if base then
            list[#list+1] = { id=wps_id, chance=spec.chance or base.chance, effects=base.effects }
          end
        end
      end
    end
  end
  return list
end

-- Default Attack Replacer pipeline (called on OnDefaultAttack)
function WPS.handle_default_attack(ctx, src, tgt, Skills)
  local sid = src.skills and src.skills.dar_override
  if not sid then
    -- vanilla: just do a weapon swing
    Effects.deal_damage { weapon=true, scale_pct=100 } (ctx, src, tgt)
  else
    -- build from skill’s scaling
    local node = Skills.DB[sid]
    local r = (src.skills.ranks and src.skills.ranks[sid]) or 1
    local knobs = node.scale and node.scale(r) or { weapon_scale_pct = 100 }
    -- energy/cd
    local cost = node.energy_cost and node.energy_cost(r) or 0
    if cost > 0 then
      if (src.energy or 0) < cost then return end
      src.energy = src.energy - cost
    end
    local cd  = node.cooldown and node.cooldown(r) or 0
    if cd > 0 then
      src.timers = src.timers or {}
      local key = 'dar:' .. sid
      if not ctx.time:is_ready(src.timers, key) then return end
      ctx.time:set_cooldown(src.timers, key, cd)
    end
    -- main hit
    Effects.deal_damage { weapon=true, scale_pct=knobs.weapon_scale_pct or 100 } (ctx, src, tgt)
    if knobs.flat_fire and knobs.flat_fire > 0 then
      Effects.deal_damage { components = { {type='fire', amount=knobs.flat_fire} } } (ctx, src, tgt)
    end
  end

  -- Roll WPS
  local wps_list = WPS.collect_for(src, Skills)
  if #wps_list > 0 then
    local pick = _roll(wps_list)
    if pick and pick.effects then pick.effects(ctx, src, tgt) end
  end
end



-- AURAS.lua
local Auras = {}

-- Tracks reservations: e._energy_reserved
local function _reserve(e, pct)
  local maxE = e.max_energy or (e.stats and e.stats:get('energy')) or 0
  local need = maxE * (pct/100)
  e._energy_reserved = (e._energy_reserved or 0) + need
  e.max_energy = math.max(0, maxE - e._energy_reserved)
  e.energy = math.min(e.energy or 0, e.max_energy)
end

local function _unreserve_all(e)
  if not e._energy_reserved or e._energy_reserved == 0 then return end
  local baseMax = e.stats and e.stats:get('energy') or (e.max_energy or 0) + e._energy_reserved
  e.max_energy = baseMax
  e._energy_reserved = 0
end

-- Toggle an exclusive aura from the skill tree
function Auras.toggle_exclusive(ctx, e, Skills, id)
  local node = Skills.DB[id]
  if not node or node.kind ~= 'exclusive_aura' then return false, 'not_exclusive' end

  -- turn off previous
  if e._active_exclusive and e._active_exclusive.entry then
    e._active_exclusive.remove_fn(e)
    _unreserve_all(e)
    e._active_exclusive = nil
  end

  if e.skills and e.skills.toggled_exclusive == id then
    -- turn on
    local r = (e.skills.ranks and e.skills.ranks[id]) or 1
    local eff = node.apply_aura and node.apply_aura(ctx, e, r)
    if eff then
      local entry = { id='exclusive:'..id, until_time=nil, apply=eff.apply, remove=eff.remove }
      local function apply_now()
        if entry.apply then entry.apply(e) end
      end
      local function remove_now(ent)
        if entry.remove then entry.remove(ent) end
      end
      apply_now()
      if node.reservation_pct and node.reservation_pct > 0 then _reserve(e, node.reservation_pct) end
      e._active_exclusive = { id=id, remove_fn=remove_now, entry=entry }
    end
  end
  return true
end

-- ============================


-- DEVOTION.lua
local Devotion = {}

-- proc spec: { id, trigger, chance, icd, filter(ev)->bool, effects(ctx, source, target) }
function Devotion.attach(e, spec)
  e._devotion = e._devotion or {}
  e._devotion[spec.id] = { spec=spec, next_ok=0 }
end

local function _try_fire(ctx, e, ev, rec)
  local now = ctx.time.now
  if now < (rec.next_ok or 0) then return end
  local spec = rec.spec
  if spec.filter and not spec.filter(ev) then return end
  if math.random()*100 > (spec.chance or 100) then return end
  local src = ev.source or e
  local tgt = ev.target or e
  spec.effects(ctx, src, tgt)
  rec.next_ok = now + (spec.icd or 0)
end

function Devotion.handle_event(ctx, evname, ev)
  -- call on both attacker and defender, if present
  local function handle(e)
    if not (e and e._devotion) then return end
    for _, rec in pairs(e._devotion) do
      local spec = rec.spec
      if spec.trigger == evname then _try_fire(ctx, e, ev, rec) end
    end
  end
  handle(ev.source); handle(ev.target)
end


-- ================================


local Demo = {}

function Demo.run()
  math.randomseed(os.time())

  -- Core context --------------------------------------------------------------
  local bus   = EventBus.new()
  local time  = Time.new()
  local defs, DTS = StatDef.make()
  local combat    = Combat.new(RR, DTS)
  
  -- After creating bus, hook devotions
  for _, evn in ipairs({'OnHitResolved','OnBasicAttack','OnCrit','OnDeath','OnDodge'}) do
    bus:on(evn, function(ev) Devotion.handle_event(ctx, evn, ev) end)
  end

  
  --[[
    How to manage ctx in a real-time, many-entity scene

    Use one long-lived ctx per combat space (scene/arena/room).
    Keep it around as long as that space exists. This ctx holds:

      bus (events shared by everyone in the space)

      time (single clock all statuses, DoTs, cooldowns reference)

      get_enemies_of / get_allies_of (resolvers for that space)

      side/teams lists for iteration (ctx.side1, ctx.side2, …)

    Entities carry their own mutable state that must persist across frames:

      e.stats, e.hp/max_health, e.statuses, e.dots, e.timers,
      e.equipped, e.gear_conversions, e.granted_spells, etc.

    Item procs and custom hooks get subscribed to ctx.bus and you keep
    the unsubscribe closures somewhere on the entity/item to clean them up.

    Real-time loop: call World.update(ctx, dt) every frame.
    This advances ctx.time.now, ticks statuses/DoTs, and emits OnTick.

    Multiple concurrent fights?
    Make one ctx per arena. Moving an entity between arenas means:

    Remove it from the old arena’s lists, unsubscribe its handlers/mutators,

    Insert into the new arena’s lists, re-subscribe needed handlers/mutators.

    Lifetime: keep ctx as long as that scene is active.
    When the scene ends, discard the whole ctx (so clocks, listeners, etc. don’t leak).
  ]]-- 

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
  hero.level_curve = 'fast_start'  -- Example curve, default curve used otherwise
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
  
  -- Example sword giving Fireball +20% damage and -0.5s cooldown, -10% cost
  local FlamebandPlus = {
    id='flameband_plus', slot='sword1',
    requires = { attribute='cunning', value=12, mode='sole' },
    mods = { { stat='weapon_min', base=6 }, { stat='weapon_max', base=10 } },

    ability_mods = {
      Fireball = { dmg_pct = 20, cd_add = -0.5, cost_pct = -10 },
    },
  }
  
  -- spell-mutator
  local ThunderSeal = {
    id='thunder_seal', slot='amulet',
    mods = { },  -- normal stat mods if you want
    -- Change Fireball to deal 100% weapon as lightning instead of fire.
    spell_mutators = {
      Fireball = {
        { pr = 0, -- mutator priority, 0=first, higher=later
          wrap = function(orig) -- pass the original effects fn
            -- return a new function that replaces the original behavior
            return function(ctx, src, tgt)
              -- replace base behavior fully:
              Effects.deal_damage {
                weapon = true, scale_pct = 200,
                skill_conversions = { { from='physical', to='lightning', pct=100 } }
              } (ctx, src, tgt)
              -- If you wanted to *augment* instead, also call the original:
              -- orig(ctx, src, tgt)
            end
          end
        }
      }
    }
  }

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
  
  assert(ItemSystem.equip(ctx, hero, FlamebandPlus))
  
  util.dump_stats(hero, ctx, { rr=true, dots=true, statuses=true, conv=true, spells=true, tags=true, timers=true })
  
  assert(ItemSystem.equip(ctx, hero, ThunderSeal))
  
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
  
  
  
  -- leveling & granted spells
  ctx.bus:on('OnLevelUp', function(ev)
    local e = ev.entity
    -- Auto-allocate Physique each level:
    e.stats:add_base('physique', 1)
    e.stats:recompute()
    
    log_debug("Level up!", e.name, "now at level", e.level, "with", e.attr_points, "attribute points and", e.skill_points, "skill points.")
    
    -- Unlock Fireball at level 3:
    if e.level == 3 then
      e.granted_spells = e.granted_spells or {}
      e.granted_spells['Fireball'] = true
    end
  end)
  
  Leveling.grant_exp(ctx, hero, 1500)  -- grant some exp to level up
  Leveling.grant_exp(ctx, hero, 1500)  -- grant some exp to level up
  
  -- Final stats dump
  util.dump_stats(hero, ctx, { rr=true, dots=true, statuses=true, conv=true, spells=true, tags=true, timers=true })
  util.dump_stats(ogre, ctx, { rr=true, dots=true, statuses=true, conv=true, spells=true, tags=true, timers=true })
end

function Demo.run_full()
  math.randomseed(12345)

  local bus   = EventBus.new()
  local time  = Time.new()
  local defs, DTS = StatDef.make()
  local combat    = Combat.new(RR, DTS)
  
  -- After creating bus, hook devotions
  for _, evn in ipairs({'OnHitResolved','OnBasicAttack','OnCrit','OnDeath','OnDodge'}) do
    bus:on(evn, function(ev) Devotion.handle_event(ctx, evn, ev) end)
  end

  local ctx = {
    debug = true,
    bus   = bus,
    time  = time,
    combat = combat,
    get_enemies_of = function(a) return a.side == 1 and ctx.side2 or ctx.side1 end,
    get_allies_of  = function(a) return a.side == 1 and ctx.side1 or ctx.side2 end,
  }

  -- Actors
  local hero = make_actor('Hero', defs, Content.attach_attribute_derivations)
  hero.side = 1
  hero.level_curve = 'fast_start'
  hero.stats:add_base('physique',  16)
  hero.stats:add_base('cunning',   18)
  hero.stats:add_base('spirit',    12)
  hero.stats:add_base('weapon_min', 18)
  hero.stats:add_base('weapon_max', 25)
  hero.stats:add_base('life_steal_pct', 10)
  hero.stats:add_base('crit_damage_pct', 50) -- +50% crit damage
  hero.stats:add_base('cooldown_reduction', 20)
  hero.stats:add_base('skill_energy_cost_reduction', 15)
  hero.stats:add_base('attack_speed', 1.0)
  hero.stats:add_base('cast_speed',   1.0)
  hero.stats:recompute()

  local ogre = make_actor('Ogre', defs, Content.attach_attribute_derivations)
  ogre.side = 2
  ogre.stats:add_base('health', 400)
  ogre.stats:add_base('defensive_ability', 95)
  ogre.stats:add_base('armor', 50)
  ogre.stats:add_base('armor_absorption_bonus_pct', 20)
  ogre.stats:add_base('fire_resist_pct', 40)
  ogre.stats:add_base('dodge_chance_pct', 10)
  ogre.stats:add_base('deflect_chance_pct', 8)
  ogre.stats:add_base('reflect_damage_pct', 5)
  ogre.stats:add_base('retaliation_fire', 8)
  ogre.stats:add_base('retaliation_fire_modifier_pct', 25)
  ogre.stats:add_base('block_chance_pct', 30)
  ogre.stats:add_base('block_amount', 60)
  ogre.stats:add_base('block_recovery_reduction_pct', 25)
  ogre.stats:recompute()

  ctx.side1 = { hero }
  ctx.side2 = { ogre }

  -- Event logging
  local function on(ev, name, fmt, fields)
    bus:on(name, function(e)
      local vals = {}
      for _, k in ipairs(fields or {}) do vals[#vals+1] = tostring(e[k]) end
      print(("[EVT] %-16s " .. fmt):format(name, table.unpack(vals)))
    end)
  end

  on(bus, 'OnHitResolved', "[%s] -> [%s] dmg=%.1f crit=%s PTH=%.1f", {'source','target','damage','crit','pth'})
  on(bus, 'OnHealed', "[%s] +%.1f", {'target','amount'})
  on(bus, 'OnCounterAttack', "[%s] countered %s", {'source','target'})
  on(bus, 'OnRRApplied', "%s RR %s=%.1f%%", {'source','kind','amount'})
  on(bus, 'OnMiss', "[%s] missed %s", {'source','target'})
  on(bus, 'OnDodge', "%s dodged %s", {'target','source'})
  on(bus, 'OnStatusExpired', "status expired: %s", {'id'})
  on(bus, 'OnDotApplied', "dot %s on %s", {'dot','target'})
  on(bus, 'OnDotExpired', "dot expired on %s", {'entity'})
  on(bus, 'OnDeath', "%s died (killer=%s)", {'entity','killer'})
  on(bus, 'OnExperienceGained', "XP +%.1f (levels+%d)", {'amount','levels'})
  on(bus, 'OnLevelUp', "Level up: %s", {'entity'})

  -- Items: conversions, procs, mutators, granted spells, ability mods
  local Flamebrand = {
    id='flamebrand', slot='sword1',
    requires = { attribute='cunning', value=12, mode='sole' },
    mods = {
      { stat='weapon_min', base=6 },
      { stat='weapon_max', base=10 },
      { stat='fire_modifier_pct', add_pct=15 },
    },
    conversions = { { from='physical', to='fire', pct=25 } },
    procs = {
      { trigger='OnBasicAttack', chance=70,
        effects = Effects.deal_damage{
          components = { { type='fire', amount=40 } }, tags = { ability = true }
        },
      },
    },
    granted_spells = { 'Fireball' },
  }

  local FlamebandPlus = {
    id='flameband_plus', slot='sword1',
    requires = { attribute='cunning', value=12, mode='sole' },
    mods = { { stat='weapon_min', base=4 }, { stat='weapon_max', base=8 } },
    ability_mods = { Fireball = { dmg_pct = 20, cd_add = -0.5, cost_pct = -10 }, },
  }

  local ThunderSeal = {
    id='thunder_seal', slot='amulet',
    spell_mutators = {
      Fireball = {
        { pr = 0, wrap = function(orig)
            return function(ctx, src, tgt)
              if orig then orig(ctx, src, tgt) end
              Effects.deal_damage {
                weapon = true, scale_pct = 200,
                skill_conversions = { { from='physical', to='lightning', pct=100 } }
              } (ctx, src, tgt)
            end
          end
        }
      }
    }
  }

  print("\n== Equip sequence ==")
  util.dump_stats(hero, ctx, { conv=true, timers=true, spells=true })
  assert(ItemSystem.equip(ctx, hero, Flamebrand))
  util.dump_stats(hero, ctx, { conv=true, timers=true, spells=true })
  assert(ItemSystem.equip(ctx, hero, FlamebandPlus)) -- replaces sword
  util.dump_stats(hero, ctx, { conv=true, timers=true, spells=true })
  assert(ItemSystem.equip(ctx, hero, ThunderSeal))
  util.dump_stats(hero, ctx, { conv=true, timers=true, spells=true })

  -- Ability level & mods
  set_ability_level(hero, 'Fireball', 3)

  print("\n== Openers ==")
  Effects.deal_damage { weapon = true, scale_pct = 100 } (ctx, hero, ogre)
  ctx.bus:emit('OnBasicAttack', { source = hero, target = ogre }) -- proc check

  -- RR tier tests (rr1, rr2, rr3)
  Content.Spells.ViperSigil.effects(ctx, hero, ogre)      -- rr2
  Content.Spells.ElementalStorm.effects(ctx, hero, ogre)  -- rr3
  util.dump_stats(ogre, ctx, { rr=true, timers=true })

  print("\n== Fireball cast (with mutator, level, and item mods) ==")
  local ok, why = Cast.cast(ctx, hero, 'Fireball', ogre)
  if not ok then print("Cast failed:", why) end
  util.dump_stats(ogre, ctx, { rr=true, dots=true, statuses=true, timers=true })

  print("\n== Poison DoT + tick ==")
  Cast.cast(ctx, hero, 'PoisonDart', ogre)
  for i=1,5 do World.update(ctx, 1.0) end
  util.dump_stats(ogre, ctx, { rr=true, dots=true, timers=true })

  print("\n== Barrier & Heal ==")
  Effects.grant_barrier { amount = 50, duration = 3 } (ctx, hero, hero)
  Effects.heal { percent_of_max = 15 } (ctx, hero, hero)
  util.dump_stats(hero, ctx, { statuses=true, timers=true })

  print("\n== Provoke & counter chain ==")
  bus:emit('OnProvoke', { source = hero, target = ogre })  -- your handler forces counter

  print("\n== Cooldowns & costs ==")
  -- Make Fireball have a cost/cd for demonstration:
  Content.Spells.Fireball.cost = 40
  Content.Spells.Fireball.cooldown = 3.0
  ok, why = Cast.cast(ctx, hero, 'Fireball', ogre)
  print("Fireball #1:", ok, why or "")
  ok, why = Cast.cast(ctx, hero, 'Fireball', ogre)
  print("Fireball #2 immediately:", ok, why or "")
  World.update(ctx, 1.6)
  ok, why = Cast.cast(ctx, hero, 'Fireball', ogre)
  print("Fireball #3 at t=1.6:", ok, why or "")
  World.update(ctx, 2.0)
  ok, why = Cast.cast(ctx, hero, 'Fireball', ogre)
  print("Fireball #4 at t=3.6:", ok, why or "")
  util.dump_stats(hero, ctx, { timers=true })

  print("\n== Leveling & granted spell at level 3 ==")
  bus:on('OnLevelUp', function(ev)
    local e = ev.entity
    e.stats:add_base('physique', 1)
    e.stats:recompute()
    print(("Level up! %s -> L%d  attr=%d skill=%d"):format(
      e.name, e.level, e.attr_points or 0, e.skill_points or 0))
    if e.level == 3 then
      e.granted_spells = e.granted_spells or {}
      e.granted_spells['Fireball'] = true
      print("Granted Fireball at level 3")
    end
  end)
  Leveling.grant_exp(ctx, hero, 1500)
  Leveling.grant_exp(ctx, hero, 1500)
  util.dump_stats(hero, ctx, { spells=true })

  print("\n== Cleanup ticks ==")
  for i=1,5 do World.update(ctx, 1.0) end
  util.dump_stats(ogre, ctx, { rr=true, dots=true, statuses=true, timers=true })
end


local _core = dofile and package and package.loaded and package.loaded['part1_core'] or nil
if not _core then _core = (function() return Core end)() end
local _game = (function() return { Effects = Effects, Combat = Combat, Items = Items, Leveling = Leveling, Content =
  Content, StatusEngine = StatusEngine, World = World, ItemSystem = ItemSystem, Cast = Cast, WPS = WPS, Skills = Skills, Auras = Auras, Demo = Demo } end)()

return { Core = _core, Game = _game }
