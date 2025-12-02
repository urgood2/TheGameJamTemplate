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
-- RENAME: Core -> CoreAPI    # More explicit when imported alongside other modules.
-- ============================================================================
local Core = {}

-- ============================================================================
-- Utility Helpers
-- Small, dependency-free helpers for copying and random selection.
-- Design goals:
--   * Keep hot-path helpers (copy/clamp/random) minimal and allocation-aware.
--   * Avoid metatable surprises: both copy helpers intentionally ignore metatables.
--   * Favor predictable behavior on edge cases (empty lists, zero/negative weights).
-- ============================================================================
local util = {}

-- ============================================================================
-- Gameplay Modules (namespaces)
-- These are placeholders for organization; you can attach functions later.
-- NOTE: Using tables here avoids require-time cycles and allows late binding.
-- RENAME: Effects -> EffectsAPI           # mirrors Core naming convention
-- RENAME: Items -> ItemsAPI
-- RENAME: ItemSystem -> EquipmentSystem   # "ItemSystem" vs "Items" can be confusing.
-- RENAME: World -> WorldLoop              # emphasizes update/tick responsibilities.
-- ============================================================================
local Effects, Combat, Items, Leveling, Content, StatusEngine, World = {}, {}, {}, {}, {}, {}, {}
local ItemSystem = {}
local PetsAndSets = {}

--- Deep copy a Lua table (recursively copies nested tables).
--  Non-table values are copied by value; functions and metatables are not
--  specially handled (intended for plain data tables).
--  Complexity: O(n) over keys; allocates one table per nested table encountered.
--  Safe for config/data payloads; NOT safe for cyclic graphs.
--  @param t table: source table
--  @return table: deep-copied table
--  RENAME: util.copy -> util.deep_copy   # conveys recursive behavior clearly.
function util.copy(t)
  local r = {}
  for k, v in pairs(t) do
    r[k] = (type(v) == 'table') and util.copy(v) or v
  end
  return r
end

--- Shallow copy a Lua table (copies only the first level).
--  Preserves references of nested tables.
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
--  Branching is minimal (two comparisons).
--  @param x number
--  @param a number: lower bound
--  @param b number: upper bound
--  @return number: x clamped into the inclusive range [a, b]
function util.clamp(x, a, b)
  if x < a then return a elseif x > b then return b else return x end
end

--- Random float in [0, 1). Thin wrapper over math.random() for clarity.
--  NOTE: Uses global Lua RNG; seed at app start for determinism if needed.
--  @return number
--  RENAME: util.rand -> util.randf       # clarifies float range semantics.
function util.rand() return math.random() end

--- Choose a random element from a list (1..#list).
--  WARN: Assumes array-like (contiguous numeric keys 1..N). For sparse arrays,
--        behavior is undefined.
--  @param list table: array-like table
--  @return any: randomly selected entry
--  RENAME: util.choice -> util.pick_random
function util.choice(list) return list[math.random(1, #list)] end

--- Weighted random choice.
--  Expects a list of entries like { { item = X, w = weight }, ... }.
--  Weights ≤ 0 are treated as 0 (ignored by sampling).
--  If weights sum to 0, picks a uniform random entry.
--  @param entries table
--  @return any: chosen entries[i].item
--  RENAME: util.weighted_choice -> util.sample_weighted
--  NOTE: This is one-pass O(n); avoids cumulative array allocations.
function util.weighted_choice(entries)
  if not entries or #entries == 0 then return nil end
  local sum = 0
  for _, e in ipairs(entries) do sum = sum + math.max(0, e.w or 0) end
  if sum <= 0 then return entries[math.random(1, #entries)].item end
  local r, acc = math.random() * sum, 0
  for _, e in ipairs(entries) do
    acc = acc + math.max(0, e.w or 0)
    if r <= acc then return e.item end
  end
  return entries[#entries].item
end

-- === Spell identity & grant helpers =========================================
-- DOC: get_spell_id
--   Purpose: normalize a spell reference (string key or table) into a canonical id.
--   Input: spell_ref (string | table) — if string, looks up Content.Spells[spell_ref].
--   Output: spell id (prefer s.id, fallback to s.name, else tostring(spell_ref)).
--   Edge cases: Handles unknown keys by tostring fallback; avoids throwing.
--   Coupling: Depends on Content.Spells table being populated by gameplay layer.
--   RENAME: get_spell_id -> resolve_spell_id
local function get_spell_id(spell_ref)
  local s = (type(spell_ref) == 'table') and spell_ref or Content.Spells[spell_ref]
  return (s and (s.id or s.name)) or tostring(spell_ref)
end

-- DOC: is_item_granted
--   Purpose: check if the given spell is flagged as granted by equipment on caster.
--   Contract: caster.granted_spells is a set-like table { [spell_id]=true }.
--   Use: differentiates CDR/cost handling for item-granted spells elsewhere.
--   RENAME: is_item_granted -> has_granted_spell
local function is_item_granted(caster, spell_ref)
  local id = get_spell_id(spell_ref)
  return caster and caster.granted_spells and caster.granted_spells[id] == true
end
-- ============================================================================

-- === Ability level per-entity ===============================================
-- DOC: get_ability_level
--   Purpose: retrieve per-entity ability rank for a spell id.
--   Default: returns 1 when unset (ensures build() has a sensible baseline).
--   Data shape: e.ability_levels = { [spell_id]=integer_rank }
--   RENAME: get_ability_level -> get_ability_rank
local function get_ability_level(e, spell_ref)
  local id = get_spell_id(spell_ref)
  return (e.ability_levels and e.ability_levels[id]) or 1
end

-- DOC: set_ability_level
--   Purpose: set per-entity ability rank; coerces to integer ≥ 1.
--   Side effect: creates e.ability_levels table on first use.
--   RENAME: set_ability_level -> set_ability_rank
--   WARN: No upper cap enforcement here; if you need soft/ultimate caps,
--         enforce at the caller or via a higher-level skill system.
local function set_ability_level(e, spell_ref, lvl)
  e.ability_levels = e.ability_levels or {}
  e.ability_levels[get_spell_id(spell_ref)] = math.max(1, math.floor(lvl or 1))
end
-- ============================================================================

-- === Aggregate item-driven ability mods =====================================
-- Accumulates item-provided mods for a specific spell id.
-- Supports: dmg_pct (outgoing damage), cd_add (seconds), cost_pct (%).
-- DOC: collect_ability_mods
--   Purpose: fold additive modifiers from all equipped items that target a spell.
--   Returns: { dmg_pct=number, cd_add=seconds, cost_pct=percent }
--   Complexity: O(n) over equipped slots.
--   RENAME: collect_ability_mods -> fold_item_spell_mods
--   NOTE: Order-independent sum; if you need multiplicative stacking, add fields
--         (e.g., dmg_mul_pct) and incorporate in consumers (e.g., build()).
local function collect_ability_mods(caster, spell_ref)
  local id = get_spell_id(spell_ref)
  local out = { dmg_pct = 0, cd_add = 0, cost_pct = 0 }
  if not caster or not caster.equipped then return out end
  for _, it in pairs(caster.equipped) do
    local m = it.ability_mods and it.ability_mods[id]
    if m then
      out.dmg_pct  = out.dmg_pct + (m.dmg_pct or 0)
      out.cd_add   = out.cd_add + (m.cd_add or 0)
      out.cost_pct = out.cost_pct + (m.cost_pct or 0)
    end
  end
  return out
end
-- ============================================================================

-- === Spell mutator pipeline ==================================================
-- A mutator is: function(orig_effects_fn) -> new_effects_fn
-- DOC: apply_spell_mutators
--   Purpose: build a final effects function by wrapping the base effect function
--            with zero or more mutators attached to the caster for this spell id.
--   Ordering: sorts by .pr ascending (lower runs earlier = closer to base).
--   Debugging: prints the pipeline when ctx.debug is true.
--   Return: composed effects function (callable as eff(ctx, src, tgt)).
--   Safety: if no mutators or empty, returns the original effects_fn.
--   RENAME: apply_spell_mutators -> compose_spell_effects
--   NOTE: Mutators are side-effect free by convention; if a mutator needs state,
--         prefer closures that capture immutable parameters.
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
      -- NOTE: Each mutator wraps the current head of the chain.
      -- Example: eff0 -> m1(eff0) -> eff1; eff1 -> m2(eff1) -> eff2; ...
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
-- DOC: dump_stats
--   Purpose: single-call diagnostic/telemetry snapshot for an entity.
--   Inputs:
--     e    : entity/actor record (expects .stats as Core.Stats instance).
--     ctx  : optional runtime context (expects .time.now for timers; safe when nil).
--     opts : optional toggles (booleans) for extra sections:
--            rr, dots, statuses, conv, spells, tags, timers
--   Output: prints a multi-line report via stdout; returns nothing.
--   Perf: O(#DAMAGE_TYPES) formatting passes + linear over equipped/status/dot lists.
--   Side effects: none (pure read + print).
-- RENAME: util.dump_stats -> util.print_stats_dump   # clearer intent that it prints.
function util.dump_stats(e, ctx, opts)
  opts = opts or {}
  local S = e.stats
  if not S then
    -- WARN: entity is missing a Stats table; nothing to render.
    print("[dump_stats] no stats for entity: " .. (e.name or "?"))
    return
  end

  -- Helpers bound to this entity's Stats for compact formatting.
  -- RENAME: G  -> getv          # "get value"
  -- RENAME: gi -> geti          # "get integer (rounded)"
  -- RENAME: gf -> getf          # "get float with precision"
  -- RENAME: fmt_pct -> fmt_pct_of
  -- RENAME: nonzero -> is_nonzero
  -- RENAME: join -> join_str
  local function G(n) return S:get(n) end
  local function gi(n) return math.floor(G(n) + 0.5) end        -- NOTE: bankers' rounding not used; simple +0.5.
  local function gf(n, p) return tonumber(string.format("%." .. (p or 1) .. "f", G(n))) end
  local function fmt_pct(n) return string.format("%d%%", math.floor(G(n) + 0.5)) end
  local function nonzero(v) return v ~= 0 and v ~= nil end
  local function join(arr, sep)
    -- NOTE: avoids table.concat on purpose to control separators and tostring on each item.
    local s, t = "", arr or {}
    for i = 1, #t do
      s = s .. (i > 1 and (sep or " ") or "") .. tostring(t[i])
    end
    return s
  end

  local lines = {}
  local function add(line) lines[#lines + 1] = line end

  -- Header line: name and primary resources at current snapshot.
  local name = e.name or "Entity"
  local maxhp = e.max_health or G("health")
  local hp = e.hp or maxhp
  add(("==== %s ===="):format(name))
  -- add(("HP %d/%d | Energy %d"):format(math.floor(hp+0.5), math.floor(maxhp+0.5), gi("energy")))
  -- NOTE: Energy prints both current and effective max; supports reserved-energy mechanics.
  local maxe = e.max_energy or G("energy")
  local ene  = (e.energy ~= nil) and e.energy or maxe
  add(("HP %d/%d | Energy %.0f/%.0f"):format(
    math.floor(hp + 0.5), math.floor(maxhp + 0.5), ene, maxe))

  -- Level progress (safe against missing Leveling.xp_to_next)
  do
    -- DOC: Uses pcall to isolate unknown curve failures; falls back to linear 1000*level.
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
    for k in pairs(eq) do slot_keys[#slot_keys + 1] = k end
    table.sort(slot_keys)
    if #slot_keys > 0 then
      local parts = {}
      for _, slot in ipairs(slot_keys) do
        local it = eq[slot]
        local label = it and (it.name or it.id or "?") or "-"
        parts[#parts + 1] = string.format("%s=%s", slot, label)
      end
      add("Equip  | " .. join(parts, "  "))
    else
      add("Equip  | (none)")
    end

    -- Available/free slots (best-effort)
    -- NOTE: Unifies multiple possible slot registries if present:
    --       Items.SLOTS / Items.SlotOrder / Content.ItemSlots / ctx.item_slots / observed equipped keys.
    --       This is tolerant of whichever layer defined the slot schema first.
    local all = {}
    local function add_slotname(s) if s and s ~= "" then all[s] = true end end

    if Items then
      if type(Items.SLOTS) == "table" then
        for k, v in pairs(Items.SLOTS) do
          if type(k) == "number" then add_slotname(v) else add_slotname(k) end
        end
      end
      if type(Items.SlotOrder) == "table" then
        for i = 1, #Items.SlotOrder do add_slotname(Items.SlotOrder[i]) end
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
      if eq[s] == nil then free[#free + 1] = s end
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
    -- DOC: Aggregates identifiers from various skill containers; accepts both array/list and set-like maps.
    local set = {}
    local function add_skills(container)
      if type(container) ~= "table" then return end
      if #container > 0 then
        for i = 1, #container do
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
    for id in pairs(set) do skills[#skills + 1] = id end
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
  -- NOTE: OA = hit/crit driver; Atk/Cast Speed shown as raw (not %).
  add("Off    | " .. join({
    ("OA=%d"):format(gi("offensive_ability")),
    ("AtkSpd=%.1f"):format(gf("attack_speed")),
    ("CastSpd=%.1f"):format(gf("cast_speed")),
    ("CritDmg=%s"):format(fmt_pct("crit_damage_pct")),
    ("Wpn=%d-%d"):format(gi("weapon_min"), gi("weapon_max")),
  }, "  "))

  -- Defense
  -- NOTE: Block prints chance% / flat absorb amount; Dodge shown as %; Absorb prints both percent and flat.
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
    -- DOC: Attacker-side additive/multiplicative final damage modifiers by type.
    local mods = {}
    for _, t in ipairs(Core.DAMAGE_TYPES) do
      local v = G(t .. "_modifier_pct")
      if nonzero(v) then mods[#mods + 1] = ("%s=%d%%"):format(t, math.floor(v + 0.5)) end
    end
    if #mods > 0 then add("DmgMod | " .. join(mods, "  ")) end
  end

  -- Resistances (only nonzero)
  do
    -- DOC: Defender-side resistances by type; printed only if nonzero to keep output compact.
    local res = {}
    for _, t in ipairs(Core.DAMAGE_TYPES) do
      local v = G(t .. "_resist_pct")
      if nonzero(v) then res[#res + 1] = ("%s=%d%%"):format(t, math.floor(v + 0.5)) end
    end
    if #res > 0 then add("Resist | " .. join(res, "  ")) end
  end
  
  -- Penetration (attacker-side)
  -- NOTE: These reduce target resistances of the specified type; "all" applies universally.
  do
    local ps = {}
    local allp = G('penetration_all_pct')
    if nonzero(allp) then ps[#ps+1] = string.format("all=%d%%", math.floor(allp + 0.5)) end
    for _, t in ipairs(Core.DAMAGE_TYPES) do
      local v = G('penetration_' .. t .. '_pct')
      if nonzero(v) then ps[#ps+1] = string.format("%s=%d%%", t, math.floor(v + 0.5)) end
    end
    if #ps > 0 then add("Pen    | " .. join(ps, "  ")) end
  end
  
  -- Pierce
  -- DOC: Offensive "pierce" of defensive mechanics:
  --   * blk_ch_pierce_pct: reduces target's chance to block
  --   * blk_amt_pierce_pct: reduces how much block absorbs
  --   * armor_penetration_pct: reduces effective armor vs physical damage
  do
    local bc = G('block_chance_pierce_pct')
    local ba = G('block_amount_pierce_pct')
    local ap = G('armor_penetration_pct')
    local parts = {}
    if nonzero(bc) then parts[#parts+1] = ("blk_ch_pierce=%d%%"):format(math.floor(bc+0.5)) end
    if nonzero(ba) then parts[#parts+1] = ("blk_amt_pierce=%d%%"):format(math.floor(ba+0.5)) end
    if nonzero(ap) then parts[#parts+1] = ("armor_pen=%d%%"):format(math.floor(ap+0.5)) end
    if #parts > 0 then add("Pierce | " .. join(parts, "  ")) end
  end

  -- Resist caps / overcap (defender-side)
  -- NOTE: gmax/gmin shift global caps; per-type caps override further.
  do
    local gmax = 100 + (G('max_resist_cap_pct') or 0)
    local gmin = -100 + (G('min_resist_cap_pct') or 0)
    local per = {}
    for _, t in ipairs(Core.DAMAGE_TYPES) do
      local mx = G('max_' .. t .. '_resist_cap_pct')
      local mn = G('min_' .. t .. '_resist_cap_pct')
      if nonzero(mx) then per[#per+1] = string.format("%s+max=%d%%", t, math.floor(mx + 0.5)) end
      if nonzero(mn) then per[#per+1] = string.format("%s+min=%d%%", t, math.floor(mn + 0.5)) end
    end
    if (math.floor(gmax+0.5) ~= 100) or (math.floor(gmin+0.5) ~= -100) or #per > 0 then
      local head = string.format("gmax=%d%% gmin=%d%%", math.floor(gmax + 0.5), math.floor(gmin + 0.5))
      if #per > 0 then
        add("ResCap | " .. head .. "  " .. join(per, "  "))
      else
        add("ResCap | " .. head)
      end
    end
  end

  -- Damage reduction (defender-side)
  -- DOC: Applies after resistance but before %/flat absorbs; prints only nonzero entries.
  do
    local drs = {}
    local g = G('damage_taken_reduction_pct')
    if nonzero(g) then drs[#drs+1] = string.format("all=%d%%", math.floor(g + 0.5)) end
    for _, t in ipairs(Core.DAMAGE_TYPES) do
      local v = G('damage_taken_' .. t .. '_reduction_pct')
      if nonzero(v) then drs[#drs+1] = string.format("%s=%d%%", t, math.floor(v + 0.5)) end
    end
    if #drs > 0 then add("DR     | " .. join(drs, "  ")) end
  end

  -- Optional: Active RR (per damage type), compact
  -- DOC: Shows active reduction-to-resistance stacks; rr1=sum flat, rr2=highest %, rr3=flat after rr2.
  if opts.rr then
    local now = (ctx and ctx.time and ctx.time.now) or nil
    local rr_lines = {}
    if e.active_rr then
      for _, t in ipairs(Core.DAMAGE_TYPES) do
        local bucket = e.active_rr[t]
        if bucket and #bucket > 0 then
          local parts = {}
          for i = 1, #bucket do
            local r = bucket[i]
            if (not r.until_time) or (not now) or (r.until_time > now) then
              local left = (now and r.until_time) and math.max(0, r.until_time - now) or nil
              parts[#parts + 1] = string.format("%s:%d%%%s",
                r.kind, math.floor((r.amount or 0) + 0.5),
                left and string.format("(%.1fs)", left) or "")
            end
          end
          if #parts > 0 then
            rr_lines[#rr_lines + 1] = string.format("%s: %s", t, join(parts, ", "))
          end
        end
      end
    end
    if #rr_lines > 0 then add("RR     | " .. join(rr_lines, "  |  ")) end
  end

  -- Optional: Statuses (buffs/debuffs)
  -- NOTE: Prints time-left when ctx.time.now available.
  if opts.statuses then
    local now = (ctx and ctx.time and ctx.time.now) or nil
    local st = {}
    if e.statuses then
      for id, b in pairs(e.statuses) do
        for i = 1, #b.entries do
          local en = b.entries[i]
          local left = (now and en.until_time) and math.max(0, en.until_time - now) or nil
          st[#st + 1] = left and (id .. string.format("(%.1fs)", left)) or id
        end
      end
    end
    if #st > 0 then add("Status | " .. join(st, "  ")) end
  end

  -- Optional: DoTs summary
  -- DOC: Each DoT prints DPS, tick period, time-left, and next tick ETA when known.
  if opts.dots then
    local now = (ctx and ctx.time and ctx.time.now) or nil
    local ds = {}
    if e.dots then
      for i = 1, #e.dots do
        local d    = e.dots[i]
        local left = (now and d.until_time) and math.max(0, d.until_time - now) or nil
        local nt   = (now and d.next_tick) and math.max(0, d.next_tick - now) or nil
        ds[#ds + 1] = string.format("%s dps=%.1f tick=%.1f%s%s",
          d.type, d.dps or 0, d.tick or 1,
          left and string.format(" left=%.1fs", left) or "",
          nt and string.format(" next=%.1fs", nt) or "")
      end
    end
    if #ds > 0 then add("DoTs   | " .. join(ds, "  ||  ")) end
  end

  -- Always: Gear conversions (compact)
  -- NOTE: Only gear-driven conversions listed here; skill-based conversions appear in damage resolution.
  local cvs = {}
  local list = e.gear_conversions or {}
  for i = 1, #list do
    local c = list[i]
    cvs[#cvs + 1] = string.format("%s->%s:%d%%", c.from, c.to, c.pct or 0)
  end
  if #cvs > 0 then add("Conv   | " .. join(cvs, "  ")) end

  -- Optional: Granted spells (legacy view)
  if opts.spells then
    local gs = {}
    if e.granted_spells then
      for id, on in pairs(e.granted_spells) do
        if on then gs[#gs + 1] = id end
      end
      table.sort(gs)
    end
    if #gs > 0 then add("Spells | " .. join(gs, ", ")) end
  end

  -- Optional: Tags
  -- NOTE: Treats truthy values as presence; sorts alphabetically for stability.
  if opts.tags then
    local ts = {}
    if e.tags then
      for k, v in pairs(e.tags) do
        if v then ts[#ts + 1] = tostring(k) end
      end
      table.sort(ts)
    end
    if #ts > 0 then add("Tags   | " .. join(ts, ", ")) end
  end

  -- Optional: Cooldown snapshot
  -- DOC: When ctx.time.now present, prints seconds remaining; otherwise raw ready-times.
  if opts.timers then
    local now = (ctx and ctx.time and ctx.time.now) or nil
    local cds = {}
    if e.timers then
      for k, tready in pairs(e.timers) do
        if not now then
          cds[#cds + 1] = string.format("%s=%.2f", k, tready)
        else
          local left = math.max(0, tready - now)
          if left > 0 then
            cds[#cds + 1] = string.format("%s: %.2fs", k, left)
          end
        end
      end
    end
    if #cds > 0 then add("Timers | " .. join(cds, "  ")) end
  end

  -- Aura / Reservation snapshot (prints only if present)
  -- DOC: Shows intent (desired toggle), actual active exclusive aura, and resource reservations.
  do
    local parts = {}

    -- desired toggle from skill tree (intent)
    local desired = e.skills and e.skills.toggled_exclusive or nil
    if desired then parts[#parts + 1] = "desired=" .. tostring(desired) end

    -- actually active exclusive aura
    local active = e._active_exclusive and e._active_exclusive.id or nil
    if active then parts[#parts + 1] = "active=" .. tostring(active) end

    -- reservation summary (best-effort; supports several shapes)
    local reserved_abs, reserved_pct = nil, nil
    if type(e._reservations) == "table" then
      local abs_sum, pct_sum = 0, 0
      for _, r in pairs(e._reservations) do
        if type(r) == "table" then
          if tonumber(r.amount) then abs_sum = abs_sum + r.amount end
          if tonumber(r.pct) then pct_sum = pct_sum + r.pct end
        end
      end
      if abs_sum > 0 then reserved_abs = abs_sum end
      if pct_sum > 0 then reserved_pct = pct_sum end
    end
    -- common alternates
    if (not reserved_abs) and tonumber(e._reserved) then reserved_abs = e._reserved end
    if (not reserved_abs) and tonumber(e._energy_reserved) then reserved_abs = e._energy_reserved end
    if (not reserved_pct) and tonumber(e._reserved_pct) then reserved_pct = e._reserved_pct end

    if reserved_abs or reserved_pct then
      local seg = "reserved="
      if reserved_abs then seg = seg .. string.format("%.1f", reserved_abs) end
      if reserved_pct then seg = seg .. (reserved_abs and "/" or "") .. tostring(reserved_pct) .. "%%" end
      parts[#parts + 1] = seg
    end

    if #parts > 0 then
      add("Aura   | " .. join(parts, "  "))
    end
  end
  
   -- Charges
   -- DOC: Generic stacks tracker view; prints fractional stacks when decay is continuous.
  do
    local cs = {}
    if e._charges then
      for id, c in pairs(e._charges) do
        local stacks = (c.stacks or 0)
        local maxs   = (c.max or 0)
        local dec    = (c.decay or 0)
        cs[#cs+1] = string.format("%s=%0.2f/%d%s",
          tostring(id), stacks, maxs, dec > 0 and (" (decay="..tostring(dec).."/s)") or "")
      end
    end
    if #cs > 0 then add("Charge | " .. join(cs, "  ")) end
  end

  -- Channeling
  -- DOC: Shows per-channel drain/sec and tick cadence; next tick ETA when ctx.time.now present.
  do
    local ch = {}
    if e._channel then
      local now = (ctx and ctx.time and ctx.time.now) or nil
      for id, rec in pairs(e._channel) do
        local nexts = (now and rec.next) and math.max(0, rec.next - now) or nil
        ch[#ch+1] = string.format("%s drain=%0.2f/s period=%0.2fs%s",
          tostring(id), rec.drain or 0, rec.period or 0.5,
          nexts and string.format(" next=%.2fs", nexts) or "")
      end
    end
    if #ch > 0 then add("Chan   | " .. join(ch, "  ")) end
  end

  -- Footer separator and flush to stdout.
  add(("============"):rep(2))
  print(table.concat(lines, "\n"))
end



-- Expose util in Core
-- DOC: Public API surface — attach utility helpers under Core.util.
-- RENAME: util -> Utils              -- if you prefer PascalCase for namespaces.
Core.util = util

-- Core-level helper (optional)
--- Subscribes a function to an event on the context's event bus and returns an unsubscribe function.
-- @param ctx table The context containing the event bus (`ctx.bus`).
-- @param ev string The event name to subscribe to.
-- @param fn function The callback function to invoke when the event is triggered.
-- @param pr any Optional priority or parameter passed to the bus's `on` method.
-- @return function A function that, when called, unsubscribes the callback from the event.
-- DOC: Wrapper over EventBus:on() that also returns a closure to remove the listener.
-- NOTE: Unsubscribe search matches by function identity; keep `fn` stable to remove.
-- RENAME: Core.on -> Core.subscribe  -- closer to intent and complements Core.hook below.
function Core.on(ctx, ev, fn, pr)
  local bus = ctx.bus
  bus:on(ev, fn, pr)
  return function() -- unsubscribe
    local b = bus.listeners[ev]
    if not b then return end
    for i = #b, 1, -1 do if b[i].fn == fn then
        table.remove(b, i)
        break
      end end
  end
end

local function _event_summary(ev)
  if type(ev) ~= "table" then return tostring(ev) end

  -- Try some common fields used in your combat events
  local parts = {}
  if ev.type        then table.insert(parts, ("type=%s"):format(ev.type)) end
  if ev.source_name then table.insert(parts, ("src=%s"):format(ev.source_name))
  elseif ev.source  then table.insert(parts, ("src=%s"):format(tostring(ev.source))) end
  if ev.target_name then table.insert(parts, ("tgt=%s"):format(ev.target_name))
  elseif ev.target  then table.insert(parts, ("tgt=%s"):format(tostring(ev.target))) end
  if ev.damage      then table.insert(parts, ("dmg=%.1f"):format(ev.damage)) end
  if ev.did_damage ~= nil then
    table.insert(parts, ("did_dmg=%s"):format(tostring(ev.did_damage)))
  end

  if #parts == 0 then return "<no fields>" end
  return table.concat(parts, " ")
end
-- One-liner utility
-- DOC: Lightweight conditional event binding with optional internal cooldown + rich debug logging.
--   opts:
--     pr        : number (priority; lower runs earlier)
--     filter    : function(ev)->bool (quick predicate on event payload)
--     condition : function(ctx, ev)->bool (context-aware predicate)
--     icd       : number (seconds/ticks) internal cooldown per-handler
--     run       : function(ctx, ev) (handler when all checks pass)
--   Returns: unsubscribe function.
-- NOTE: Stores state on `opts._next`; do not reuse the same `opts` table for multiple hooks unless you want shared cooldown.
-- RENAME: Core.hook -> Core.on_with      -- reads as “on event with options”.
-- RENAME: evname -> event_name           -- improves readability.
function Core.hook(ctx, evname, opts)
  local pr = opts.pr or 0

  -- Pretty printing helpers for debug logs
  local function _display_entity(v)
    if type(v) ~= "table" then return tostring(v) end
    -- Prefer common identity fields
    if v.name then return tostring(v.name) end
    if v.id   then return tostring(v.id)   end
    if v.label then return tostring(v.label) end
    -- Fallback to pointer-ish tostring
    return tostring(v)
  end

  local function _event_summary(ev)
    if type(ev) ~= "table" then return tostring(ev) end
    local parts = {}

    -- generic
    if ev.type          ~= nil then parts[#parts+1] = ("type=%s"):format(tostring(ev.type)) end
    if ev.reason        ~= nil then parts[#parts+1] = ("reason=%s"):format(tostring(ev.reason)) end
    if ev.tag           ~= nil then parts[#parts+1] = ("tag=%s"):format(tostring(ev.tag)) end

    -- common combat fields
    if ev.source        ~= nil then parts[#parts+1] = ("src=%s"):format(_display_entity(ev.source)) end
    if ev.target        ~= nil then parts[#parts+1] = ("tgt=%s"):format(_display_entity(ev.target)) end
    if ev.damage        ~= nil then parts[#parts+1] = ("dmg=%.1f"):format(ev.damage) end
    if ev.did_damage    ~= nil then parts[#parts+1] = ("did_dmg=%s"):format(tostring(ev.did_damage)) end
    if ev.crit          ~= nil then parts[#parts+1] = ("crit=%s"):format(tostring(ev.crit)) end
    if ev.pth           ~= nil then parts[#parts+1] = ("pth=%.1f"):format(ev.pth) end

    -- timing details if present
    if ev.time          ~= nil then parts[#parts+1] = ("t=%.2f"):format(ev.time) end

    if #parts == 0 then return "<no fields>" end
    return table.concat(parts, " ")
  end

  local fn = function(ev)
    -- Debug: event received
    local now = (ctx and ctx.time and ctx.time.now) or 0
    print(("[DEBUG][Hook] %s @%.2f received: %s"):format(evname, now, _event_summary(ev)))

    if opts.filter and not opts.filter(ev) then
      print(("[DEBUG][Hook] %s skipped by filter"):format(evname))
      return
    end

    if opts.condition and not opts.condition(ctx, ev) then
      print(("[DEBUG][Hook] %s skipped by condition"):format(evname))
      return
    end

    if opts.icd then
      opts._next = opts._next or 0
      if now < opts._next then
        print(("[DEBUG][Hook] %s blocked by ICD until %.2f (now=%.2f)"):format(evname, opts._next, now))
        return
      end
      opts._next = now + opts.icd
    end

    print(("[DEBUG][Hook] %s running handler"):format(evname))
    return opts.run(ctx, ev)
  end

  ctx.bus:on(evname, fn, pr)

  return function()
    local b = ctx.bus.listeners[evname]; if not b then return end
    for i=#b,1,-1 do
      if b[i].fn == fn then
        table.remove(b,i)
        print(("[DEBUG][Hook] %s removed"):format(evname))
        break
      end
    end
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
-- DOC: Event buckets: self.listeners[name] = { {fn=<callback>, pr=<priority>}, ... }
function EventBus.new()
  return setmetatable({ listeners = {} }, EventBus)
end

--- Register a listener for an event.
--  @param name string: event name
--  @param fn function: callback invoked as fn(ctx)
--  @param pr number|nil: optional priority (lower runs earlier, default 0)
-- NOTE: Stable call order is preserved by sorting on every registration (O(n log n)).
--       If registration happens hot, consider: insert + single swap, or group by priority value.
-- RENAME: pr -> priority
function EventBus:on(name, fn, pr)
  local bucket = self.listeners[name] or {}
  table.insert(bucket, { fn = fn, pr = pr or 0 })
  table.sort(bucket, function(a, b) return a.pr < b.pr end)
  self.listeners[name] = bucket
end

--- Emit an event to all listeners for `name` in ascending priority order.
--  @param name string
--  @param ctx table: event context payload (shape is user-defined)
-- NOTE: No try/pcall around listeners — a thrown error will bubble and halt remaining listeners.
--       If you prefer fault isolation, wrap each call with pcall and log failures.
-- CAVEAT: Mutating the bucket (adding/removing) during emit is not guarded; callers should avoid.
function EventBus:emit(name, ctx)
  local bucket = self.listeners[name]
  if not bucket then return end
  -- Note: iterate by index to avoid issues if listeners list is reused.
  for i = 1, #bucket do
    bucket[i].fn(ctx)
  end
end

-- Expose EventBus in Core
-- DOC: Public API surface for creating buses in game contexts.
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
-- RENAME: Time.new -> Time.create      -- consistency with other factories, if desired.
function Time.new()
  return setmetatable({ now = 0 }, Time)
end

--- Advance the internal clock by dt.
--  @param dt number: delta time to advance (seconds or ticks)
-- NOTE: Monotonic by construction; negative dt will move time backwards — avoid passing negatives.
function Time:tick(dt)
  self.now = self.now + dt
end

--- Check whether a keyed timer is ready.
--  Works with any table that holds absolute-unlock timestamps keyed by `key`.
--  @param tbl table: table where cooldown absolute times are stored
--  @param key any: key into tbl
--  @return boolean: true if not set or if current time >= stored unlock time
-- RENAME: is_ready -> cooldown_ready
function Time:is_ready(tbl, key)
  return (tbl[key] or -1) <= self.now
end

--- Set/update a cooldown for `key` in `tbl` to expire after duration `d`.
--  Stores an absolute timestamp (now + d) into tbl[key].
--  @param tbl table
--  @param key any
--  @param d number: duration until ready (seconds or ticks)
-- NOTE: Cooldown values are absolute; compare with Time.now, not a countdown.
-- RENAME: set_cooldown -> start_cooldown
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
-- NOTE: Order matters only for display; logic uses names.
-- RENAME: DAMAGE_TYPES -> DAMAGE_TYPES_ALL   -- clarifies scope (core, global list).
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
-- NOTE: Using separate add_pct/mul_pct simplifies final-value computation and stacking rules.
-- RENAME: add_basic -> define_stat
local function add_basic(defs, name)
  defs[name] = { base = 0, add_pct = 0, mul_pct = 0 }
end

--- Build the canonical definitions table of all stats.
--  Includes attributes, combat stats, regen, damage types, retaliation,
--  crowd-control resistances, etc.
--  @return defs table: mapping statName -> { base, add_pct, mul_pct }
--  @return DAMAGE_TYPES table: list of all damage type strings
-- DOC: This is the single source of truth for valid stat keys — extend here to add new systems.
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
  -- add_basic(defs, 'deflect_chance_pct')
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
  add_basic(defs, 'cooldown_reduction')          -- % reduces cooldowns (non-item-granted)
  add_basic(defs, 'skill_energy_cost_reduction') -- % cheaper
  
  -- === Resistance Penetration (attacker) ===
  add_basic(defs, 'penetration_all_pct')
  for _, dt in ipairs(DAMAGE_TYPES) do
    add_basic(defs, 'penetration_' .. dt .. '_pct')
  end

  -- === Resist Caps / Overcap (defender) ===
  -- Effective caps resolve to: max = 100 + max_resist_cap_pct + max_<t>_resist_cap_pct
  --                            min = -100 + min_resist_cap_pct + min_<t>_resist_cap_pct
  add_basic(defs, 'max_resist_cap_pct')  -- default 0 -> effective 100
  add_basic(defs, 'min_resist_cap_pct')  -- default 0 -> effective -100
  for _, dt in ipairs(DAMAGE_TYPES) do
    add_basic(defs, 'max_' .. dt .. '_resist_cap_pct')
    add_basic(defs, 'min_' .. dt .. '_resist_cap_pct')
  end

  -- === Damage Reduction (defender; multiplicative, after resist) ===
  add_basic(defs, 'damage_taken_reduction_pct') -- global
  for _, dt in ipairs(DAMAGE_TYPES) do
    add_basic(defs, 'damage_taken_' .. dt .. '_reduction_pct')
  end

  -- === OPTIONAL: Armor/Block Pierce (attacker) ===
  add_basic(defs, 'armor_penetration_pct')

  -- === Tag synergy / wand-specific stats ===
  -- These are granted by deck tag thresholds; keep in sync with TagEvaluator.
  add_basic(defs, 'burn_damage_pct')
  add_basic(defs, 'burn_tick_rate_pct')
  add_basic(defs, 'damage_vs_frozen_pct')
  add_basic(defs, 'buff_duration_pct')
  add_basic(defs, 'buff_effect_pct')
  add_basic(defs, 'chain_targets')
  add_basic(defs, 'on_move_proc_frequency_pct')
  add_basic(defs, 'move_speed_pct')
  add_basic(defs, 'hazard_radius_pct')
  add_basic(defs, 'hazard_damage_pct')
  add_basic(defs, 'hazard_duration')
  add_basic(defs, 'max_poison_stacks_pct')
  add_basic(defs, 'summon_hp_pct')
  add_basic(defs, 'summon_damage_pct')
  add_basic(defs, 'summon_persistence')
  add_basic(defs, 'barrier_refresh_rate_pct')
  add_basic(defs, 'health_pct')
  add_basic(defs, 'melee_damage_pct')
  add_basic(defs, 'melee_crit_chance_pct')

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
-- DOC: `values` keeps raw base/add/mul. Derived values are applied in-place and tracked
--      via _derived_marks so they can be cleanly removed before the next recompute().
function Stats.new(defs)
  local t = {
    defs = defs,
    values = {},
    derived_hooks = {},
    _derived_marks = {}, -- track derived deltas: { {kind, name, amount}, ... }
  }
  for n, d in pairs(defs) do
    t.values[n] = { base = d.base, add_pct = 0, mul_pct = 0 }
  end
  return setmetatable(t, Stats)
end

-- Ensure a stat bucket exists before mutating it.
function Stats:_ensure(n)
  if not self.values[n] then
    self.values[n] = { base = 0, add_pct = 0, mul_pct = 0 }
  end
end

-- Helpers to safely add derived deltas:
-- NOTE: Use these inside derived hooks to ensure changes are reversible.
-- RENAME: _mark -> _track_derived_delta
function Stats:_mark(kind, n, amt)
  self._derived_marks[#self._derived_marks + 1] = { kind, n, amt }
end

function Stats:derived_add_base(n, a)
  self:_ensure(n)
  self.values[n].base = self.values[n].base + a; self:_mark('base', n, a)
end

function Stats:derived_add_add_pct(n, a)
  self:_ensure(n)
  self.values[n].add_pct = self.values[n].add_pct + a; self:_mark('add_pct', n, a)
end

function Stats:derived_add_mul_pct(n, a)
  self:_ensure(n)
  self.values[n].mul_pct = self.values[n].mul_pct + a; self:_mark('mul_pct', n, a)
end

-- Remove past derived deltas
-- DOC: Called by recompute() prior to reapplying all derived hooks. Ensures idempotency.
function Stats:_clear_derived()
  for i = #self._derived_marks, 1, -1 do
    local kind, n, amt = self._derived_marks[i][1], self._derived_marks[i][2], self._derived_marks[i][3]
    if kind == 'base' then
      self.values[n].base = self.values[n].base - amt
    elseif kind == 'add_pct' then
      self.values[n].add_pct = self.values[n].add_pct - amt
    elseif kind == 'mul_pct' then
      self.values[n].mul_pct = self.values[n].mul_pct - amt
    end
  end
  self._derived_marks = {}
end

--- Get the raw stored value object for a stat (base/add_pct/mul_pct).
-- RENAME: get_raw -> peek                         -- signals “no compute”.
function Stats:get_raw(n)
  return self.values[n]
end

--- Get the final computed value for a stat.
--  Computed as: base * (1 + add_pct/100) * (1 + mul_pct/100).
-- NOTE: Nonexistent stats return 0 (via default table).
function Stats:get(n)
  local v = self.values[n]
  if not v then
    v = { base = 0, add_pct = 0, mul_pct = 0 }
  end
  return v.base * (1 + v.add_pct / 100) * (1 + v.mul_pct / 100)
end

--- Increment base value of a stat.
-- RENAME: add_base -> inc_base
function Stats:add_base(n, a)
  self:_ensure(n)
  self.values[n].base = self.values[n].base + a
end

--- Increment additive percentage modifier of a stat.
-- RENAME: add_add_pct -> inc_add_pct
function Stats:add_add_pct(n, a)
  self:_ensure(n)
  self.values[n].add_pct = self.values[n].add_pct + a
end

--- Increment multiplicative percentage modifier of a stat.
-- RENAME: add_mul_pct -> inc_mul_pct
function Stats:add_mul_pct(n, a)
  self:_ensure(n)
  self.values[n].mul_pct = self.values[n].mul_pct + a
end

--- Register a hook to be run when recompute() is called.
--  Useful for maintaining derived stats.
-- returns a function that, when called, removes the hook.
-- NOTE: Hooks should be pure (only call derived_* helpers). Side effects can lead to drift.
-- RENAME: on_recompute -> add_recompute_hook
function Stats:on_recompute(fn)
  table.insert(self.derived_hooks, fn)
  return function()
    for i = #self.derived_hooks, 1, -1 do
      if self.derived_hooks[i] == fn then
        table.remove(self.derived_hooks, i); break
      end
    end
  end
end

--- Run all registered recompute hooks.
-- DOC: Reapply all derived contributions from scratch. Call after any base/add/mul changes.
-- PERF: Cost proportional to number of hooks; keep heavy logic out of hooks when possible.
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
-- USAGE NOTES:
--   - "Resistance" is a percent that reduces incoming damage of a given type.
--   - Negative resistance means vulnerability (i.e., increased damage).
--   - Ordering matters: rr1 (sum all) -> rr2 (apply strongest %) -> rr3 (apply strongest flat).
--   - rr2 includes a floor at 0 *at that stage*, after which rr3 can push below 0 again.
-- RENAME: RR -> ResistReduction        -- more descriptive for discoverability.
-- ============================================================================
local RR = {}

--- Utility: pick the entry with the highest amount.
--  Pure max-by comparator over `.amount`.
--  @param tbl { { amount = number, ... }, ... }
--  @return table|nil the element with max amount or nil if empty
-- RENAME: pick_highest -> max_by_amount
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
-- DETAILS:
--   rr1  (additive): sums all e.amount and subtracts from base (can go below 0).
--   rr2  (percent) : applies the strongest (max amount) multiplicatively; floors at 0.
--   rr3  (flat)    : applies the strongest (max amount) flat subtraction (can go below 0).
-- EDGE CASES:
--   - Unknown kinds are ignored.
--   - Empty list returns base unchanged.
--   - rr2 flooring prevents multiplicative "overkill" from making resistance negative before rr3.
-- RENAME: apply_all -> apply_all_rr       -- clarifies domain (resistance reduction).
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
-- VALIDATION: This implementation trusts bucket inputs; pct is not clamped; from/to types are not validated.
--             Consider pre-validating outside if you ingest content from data files.
-- RENAME: Conv -> Conversions
-- ============================================================================
local Conv = {}

--- Internal: apply a single conversion bucket to a map of type->amount.
--  @param m table: { [type] = amount }
--  @param bucket table[]|nil: list of { from, to, pct }
--  @return table: new map after conversions
-- BEHAVIOR:
--   - Each rule pulls `pct%` from `from` and adds it to `to`.
--   - Multiple rules compound; order is bucket order.
--   - Missing `from` types are treated as 0.
-- PERF: O(T + R) where T=#types present and R=#rules in bucket.
-- RENAME: apply_bucket -> apply_conversion_bucket
local function apply_bucket(m, bucket)
  if not bucket or #bucket == 0 then return m end
  local out = {}
  local map = util.shallow_copy(m)

  for _, cv in ipairs(bucket) do
    local avail  = map[cv.from] or 0
    local move   = avail * (cv.pct / 100)
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
-- ORDERING: Skill conversions are applied before gear conversions (common ARPG convention).
-- STABILITY: The output component order is unspecified (hash iteration); consumers should not rely on order.
-- RENAME: apply -> apply_conversions
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
-- DESIGN:
--   - These are pure selectors; they do not validate alive/dead state unless your get_* functions do.
--   - Returning an empty array is a valid “no targets” signal.
-- RENAME: Targeters -> Targeting
-- ============================================================================
local Targeters = {}

--- Return the acting entity as the only target.
--  @return { entity }
-- RENAME: self -> self_only
function Targeters.self(ctx)
  return { ctx.source }
end

--- Return the explicit target set in ctx.
--  @return { entity }
-- CAVEAT: If ctx.target is nil, returns { nil }; most callers expect {}, so ensure callers guard against nil entries.
-- RENAME: target_enemy -> target_selected
function Targeters.target_enemy(ctx)
  return { ctx.target }
end

--- Return all enemies of the source (shallow-copied).
--  Uses util.copy which is a deep copy; if enemy entries are tables, this may be heavier than needed.
--  Consider util.shallow_copy if enemy list is an array of references you don't intend to mutate.
function Targeters.all_enemies(ctx)
  return util.copy(ctx.get_enemies_of(ctx.source))
end

--- Return all allies of the source (shallow-copied).
--  See note in all_enemies about deep vs shallow copy.
function Targeters.all_allies(ctx)
  return util.copy(ctx.get_allies_of(ctx.source))
end

--- Return a single random enemy (or empty if none).
--  RNG: math.random() uniform.
--  @return { entity } or {}
-- RENAME: random_enemy -> any_enemy_random
function Targeters.random_enemy(ctx)
  local es = ctx.get_enemies_of(ctx.source)
  if #es == 0 then return {} end
  return { util.choice(es) }
end

--- Return a higher-order targeter that filters enemies by a predicate.
--  @param predicate function(e) -> boolean
--  @return function(ctx) -> { filtered enemies }
-- PERF: O(N) scan of enemy list; fine for small squads, consider indexing for large rosters.
-- RENAME: enemies_with -> enemies_matching
-- RENAME: predicate -> filter_fn
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
-- API SHAPES:
--   - Entity predicates:  fn(e) -> bool         (e.g., has_tag, stat_below)
--   - Ctx-aware checks:   fn(ctx, ev, src, tgt) -> bool (e.g., chance)
-- Be mindful when passing them into systems: match the expected signature.
-- RENAME: Cond -> Conditions
-- ============================================================================
local Cond = {}

--- Always-true condition (useful as a default).
function Cond.always() return true end

--- Returns a predicate that checks if an entity has a tag set truthy.
--  Assumes entity has table `e.tags` keyed by tag name.
--  @param tag string
--  @return function(e) -> boolean
-- RENAME: has_tag -> entity_has_tag
function Cond.has_tag(tag)
  return function(e)
    return e.tags and e.tags[tag]
  end
end

--- Returns a predicate that checks if an entity stat is below a threshold.
--  @param stat string
--  @param th number
--  @return function(e) -> boolean
-- RENAME: stat_below -> entity_stat_below
function Cond.stat_below(stat, th)
  return function(e)
    return e.stats:get(stat) < th
  end
end

-- Extend Cond with ctx-aware predicates (keep your old ones for per-entity checks)
--- Roll a percentage chance check (<= pct succeeds).
--  @param pct number in [0,100]
--  @return function(ctx, ev, src, tgt) -> boolean
-- NOTE: Uses math.random() * 100; success if <= pct. No seed control here.
-- RENAME: chance -> chance_roll
function Cond.chance(pct)
  return function(ctx, ev, src, tgt) return math.random() * 100 <= pct end
end

--- Check whether target currently has a status bucket with at least one entry.
--  @param id string status identifier
--  @return function(ctx, ev, src, tgt) -> boolean
-- CAVEAT: Only checks presence and count; does not verify expiration here.
-- RENAME: has_status_id -> target_has_status
function Cond.has_status_id(id)
  return function(ctx, ev, src, tgt)
    local b = tgt and tgt.statuses and tgt.statuses[id]
    return b and #b.entries > 0
  end
end

--- Check whether the event has a specific tag.
--  @param tag string
--  @return function(ctx, ev)->boolean
-- RENAME: event_has_tag -> event_tag_is
function Cond.event_has_tag(tag)
  return function(ctx, ev) return ev and ev.tags and ev.tags[tag] end
end

--- Check that the event occurred within dtmax of the current time (ctx.time.now).
--  @param dtmax number (seconds/ticks)
--  @return function(ctx, ev)->boolean
-- RENAME: time_since_ev_le -> event_within_time
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
    Core.util, Core.EventBus, Core.Time, Core.StatDef, Core.Stats, Core.RR, Core.Conv, Core.Targeters, Core.Cond,
    Core.DAMAGE_TYPES

    
    
--[[-----------------------------------------------------------------------------
Effects Module — Deep-Dive Documentation & Rename Suggestions (comments only)
-------------------------------------------------------------------------------
Purpose
  A small, composable library of "effect builders" that yield closures with the
  signature: function(ctx, src, tgt). These closures implement gameplay actions
  (buffs, cleanses, RR, summons, etc.) in an engine-agnostic way.

Key Concepts
  • Status Entries:
      target.statuses[<id>].entries is a list of active status "records".
      Each record can apply/remove stat deltas and has an optional until_time.
      Stacking behavior is controlled via 'status.stack' options (replace, extend, count).
      Expiry/cleanup is expected to be handled by your status engine/tick loop.

  • Bus Events:
      Emits events like 'OnStatusApplied', 'OnStatusRemoved', 'OnRRApplied',
      'OnExtraTurnGranted', 'OnResurrect' for UI/logic hooks.

  • Resistance Reduction (RR):
      Effects.apply_rr records RR entries by damage type. Your damage resolver
      should gather only active entries for the damage type at hit-resolution time
      (filter by entry.until_time > ctx.time.now) and call RR.apply_all.

Conventions
  ctx  : Runtime context; expected to have ctx.time (Core.Time) and ctx.bus (EventBus).
         Also expects game-layer helpers (ctx.get_enemies_of / ctx.get_allies_of).
  src  : Source (acting entity).
  tgt  : Target entity; may be nil for some effects; fallbacks are usually sensible.

Performance & Integration Tips
  • If you expect tens of thousands of statuses, consider pooling status tables.
  • Cleanse/predicate paths are hot; micro-opt if needed (e.g., reuse tables).
  • For cast wrappers, note the separation between %WD target list vs. Cast.cast target.

Rename Suggestions (non-breaking, comments only)
  • 'p'        → 'params' | 'opts' | 'spec'
  • 'def'      → 'spec' | 'status_def'
  • 'ov'       → 'item_override'
  • 'wpct'     → 'weapon_pct'
  • 'list'     → 'effects' | 'targets'
  • 'runner'   → 'apply_fn' | 'effect_fn'
  • 'apply_status' → 'apply_status_entry'
  • 'ctx'/'src'/'tgt' are fine/idiomatic; optionally 'source'/'target' if preferred.
-----------------------------------------------------------------------------]]


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
-- NOTE: In 'time_extend' mode, if the current entry had nil until_time (permanent),
--       the code treats it as 0 then adds duration. If you want “permanent stays permanent”,
--       gate that in your status engine’s sweep logic (not here).
-- Rename suggestion: 'apply_status' → 'apply_status_entry'
local function apply_status(target, status)
  target.statuses = target.statuses or {}
  local bucket = target.statuses[status.id] or { entries = {} }
  target.statuses[status.id] = bucket

  local st = status.stack
  if not st or st.mode == 'replace' then
    local prev = bucket.entries[1]
    if prev and prev.remove then prev.remove(target) end
    bucket.entries[1] = status
    if status.apply then status.apply(target) end
  elseif st.mode == 'time_extend' then
    if bucket.entries[1] then
      local cur = bucket.entries[1]
      local add = status.extend_by or 0
      if add > 0 then
        cur.until_time = (cur.until_time or 0) + add
      end
    else
      bucket.entries[1] = status
      if status.apply then status.apply(target) end
    end
  elseif st.mode == 'count' then
    table.insert(bucket.entries, status)
    if status.apply then status.apply(target) end
    if st.max and #bucket.entries > st.max then
      local dropped = table.remove(bucket.entries, 1)
      if dropped and dropped.remove then dropped.remove(target) end
    end
  end
end


-- Parallel executor (fire-and-forget effects on same tick)
-- Executes each effect in-order in the same tick; if one throws, later ones won’t run.
-- Wrap with pcall at call sites if you want isolation.
-- Rename suggestion: 'list' → 'effects'
Effects.par = function(list)
  return function(ctx, src, tgt)
    for i = 1, #list do list[i](ctx, src, tgt) end
  end
end

-- Cleanse: remove debuffs/status entries by id/predicate
  -- p = { ids = { [id]=true, ... } } or
  --     { predicate = function(id, entry) return true end }
-- Emits OnStatusRemoved per removed entry with reason='cleanse'.
-- Buckets with no entries are pruned.
-- Rename suggestion: 'p' → 'params'
Effects.cleanse = function(p)
  p = p or {}
  return function(ctx, src, tgt)
    if not (tgt and tgt.statuses) then return end

    local to_nuke = {}

    for id, b in pairs(tgt.statuses) do
      local keep = {}
      for _, entry in ipairs(b.entries or {}) do
        local remove =
            (p.ids and p.ids[id] == true) or
            (p.predicate and p.predicate(id, entry)) or
            false

        if remove then
          if entry.remove then entry.remove(tgt) end
          if ctx and ctx.bus and ctx.bus.emit then
            ctx.bus:emit('OnStatusRemoved', {
              entity = tgt,      -- the target losing the status
              id     = id,       -- status id
              source = src,      -- who cleansed (may be nil)
              reason = 'cleanse' -- explicit reason
            })
          end
        else
          keep[#keep + 1] = entry
        end
      end
      b.entries = keep

      if #b.entries == 0 then
        to_nuke[#to_nuke + 1] = id
      end
    end

    for i = 1, #to_nuke do
      tgt.statuses[to_nuke[i]] = nil
    end
  end
end


-- Fire a spell from items/procs with optional %WD and custom targeter
-- p = { id, weapon_pct, override_targeter, pre_weapon=true|false, post_weapon=false|true }
-- Semantics:
--   • Builds a list of entities to receive optional % weapon damage (pre/post).
--   • Cast.cast runs once against 'tgt' (not against the override list).
--   • Item overrides (src._item_skill_overrides) can inject weapon_pct or targeter.
-- Rename suggestions: 'p' → 'params', 'ov' → 'item_override', 'wpct' → 'weapon_pct',
--                     'list' → 'targets' (for readability)
Effects.cast_spell = function(p)
  -- p = { id, weapon_pct, override_targeter, pre_weapon=true|false, post_weapon=false|true }
  return function(ctx, src, tgt)
    local spell_id = p.id
    if not spell_id then return end

    -- Pull item-level overrides if present (cooldown/cost/radius/targeter/weapon_pct)
    local ov = src._item_skill_overrides and src._item_skill_overrides[spell_id] or nil
    local wpct = p.weapon_pct or (ov and ov.weapon_pct) or 0

    -- Build target list (prefer override targeter if present)
    local targeter = p.override_targeter or (ov and ov.override_targeter) or nil
    local list
    if targeter then
      list = targeter({
        source = src, target = tgt,
        get_enemies_of = ctx.get_enemies_of, get_allies_of = ctx.get_allies_of
      })
    else
      list = { tgt or src }
    end

    -- Optional %WD pre/post wrappers
    if (p.pre_weapon ~= false) and wpct > 0 then
      for _, t in ipairs(list) do
        Effects.deal_damage { weapon = true, scale_pct = wpct } (ctx, src, t)
      end
    end

    local ok, why = Cast.cast(ctx, src, spell_id, tgt)

    if p.post_weapon and wpct > 0 then
      for _, t in ipairs(list) do
        Effects.deal_damage { weapon = true, scale_pct = wpct } (ctx, src, t)
      end
    end

    return ok, why
  end
end

-- Lightweight status constructor
-- def: { id, duration, stack, apply = function(e,ctx,src,tgt), remove=function(e,ctx) }
-- Emits 'OnStatusApplied' after applying. Expiry handled externally.
-- Rename suggestion: 'def' → 'status_def'
Effects.status = function(def)
  -- def: { id, duration, stack, apply = function(e,ctx,src,tgt), remove=function(e,ctx) }
  return function(ctx, src, tgt)
    local entry = {
      id         = assert(def.id, "status needs id"),
      until_time = def.duration and (ctx.time.now + def.duration) or nil,
      stack      = def.stack,
      extend_by  = def.duration or 0,
      apply      = function(e) if def.apply then def.apply(e, ctx, src, tgt) end end,
      remove     = function(e) if def.remove then def.remove(e, ctx) end end,
    }
    apply_status(tgt, entry)
    if ctx and ctx.bus then
      ctx.bus:emit('OnStatusApplied', { source = src, target = tgt, id = def.id })
    end
  end
end



-- Extras Siralim-like (engine-backed) – safe stubs you can wire later:
-- resurrect: flips dead→alive and sets hp to pct of max; emits OnResurrect
-- NOTE: Currently *sets* hp, rather than max(current, pct*max). Adjust in engine if desired.
-- Rename suggestion: 'p' → 'params'
Effects.resurrect = function(p)
  -- p={ hp_pct=50 }
  return function(ctx, src, tgt)
    if tgt.dead then
      tgt.dead = false
      local maxhp = tgt.max_health or tgt.stats:get('health')
      -- tgt.hp = math.max(tgt.hp or 0, maxhp * ((p.hp_pct or 50)/100))
      tgt.hp = maxhp * ((p.hp_pct or 50) / 100)
      ctx.bus:emit('OnResurrect', { source = src, target = tgt, hp = tgt.hp })
    end
  end
end

-- summon: spawns 'count' blueprints on side_of ('source' by default, 'target' if specified)
-- Requires ctx.spawn_entity(ctx, blueprint, allyOf)
-- Rename suggestion: 'p' → 'params'
Effects.summon = function(p)
  -- p={ blueprint='Wolf', count=1, side_of='source' }
  return function(ctx, src, tgt)
    if not ctx.spawn_entity then return end -- plug in your factory when ready
    for i = 1, (p.count or 1) do ctx.spawn_entity(ctx, p.blueprint, p.side_of == 'target' and tgt or src) end
  end
end

-- grant_extra_turn: emits an intent for your scheduler to interpret.
-- Rename suggestion: drop unused 'p' param or keep for API consistency.
Effects.grant_extra_turn = function(p)
  -- requires your turn scheduler; for now, emit an intent event
  return function(ctx, src, tgt)
    ctx.bus:emit('OnExtraTurnGranted', { entity = tgt or src })
  end
end

--- Apply Resistance Reduction (RR) to a specific damage type.
--  p = { kind = 'rr1'|'rr2'|'rr3', damage = <type>, amount = <number>, duration = <secs or 0> }
-- Stores an RR entry under tgt.active_rr[damage]. Damage resolver should:
--   • filter out expired entries (entry.until_time <= now) and
--   • call RR.apply_all(baseResist, filteredList).
-- Rename suggestion: 'p' → 'params'
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

    ctx.bus:emit('OnRRApplied', {
      source = src,
      target = tgt,
      rr_kind = p.kind,
      damage_type = p.damage,
      amount = p.amount
    })
  end
end


-- one-time registry: maps effect runners to entry builders
-- Weak-keyed map so storing metadata doesn't keep closures alive unnecessarily.
Effects._entry_of = Effects._entry_of or setmetatable({}, { __mode = "k" })


--- Temporarily modify a stat via a status entry.
--  p = {
--    id = <string>|nil (defaults to "buff:<name>"),
--    name = <statName>,
--    base_add    = <number>|nil,
--    add_pct_add = <number>|nil,
--    mul_pct_add = <number>|nil,
--    duration    = <number>|nil (secs; nil = permanent until manually removed)
--  }
-- Applies symmetric deltas on apply/remove; emits OnBuffApplied. Stack policy/duration via p.stack/p.duration.
-- Rename suggestions: 'p' → 'params', 'runner' → 'effect_fn'/'apply_fn'
Effects.modify_stat = function(p)
  -- unchanged legacy runner (kept exactly as-is)
  local function runner(ctx, src, tgt)
    local entry = {
      id         = p.id or ('buff:' .. p.name),
      until_time = p.duration and (ctx.time.now + p.duration) or nil,
      stack      = p.stack,
      extend_by  = p.duration or 0,
      apply      = function(e)
        if p.base_add then e.stats:add_base(p.name, p.base_add) end
        if p.add_pct_add then e.stats:add_add_pct(p.name, p.add_pct_add) end
        if p.mul_pct_add then e.stats:add_mul_pct(p.name, p.mul_pct_add) end
      end,
      remove     = function(e)
        if p.base_add then e.stats:add_base(p.name, -p.base_add) end
        if p.add_pct_add then e.stats:add_add_pct(p.name, -p.add_pct_add) end
        if p.mul_pct_add then e.stats:add_mul_pct(p.name, -p.mul_pct_add) end
      end
    }

    apply_status(tgt, entry)
    ctx.bus:emit('OnBuffApplied', { source = src, target = tgt, name = p.name })
    -- (no return; preserves legacy call sites)
  end

  -- NEW: builder for a plain, removable entry (no status/timers applied automatically)
  -- Useful for exclusive auras or external lifecycle control.
  -- Usage idea (pseudocode):
  --   local build_entry = Effects._entry_of[Effects.modify_stat{ name='armor', base_add=100, duration=10 }]
  --   local entry = build_entry(ctx, { exclusive = true })
  --   -- Then your aura engine can manage entry.apply/remove and exclusivity as needed.
  Effects._entry_of[runner] = function(ctx, opts)
    local exclusive = opts and opts.exclusive
    return {
      id         = p.id or ('buff:' .. p.name),
      until_time = exclusive and nil
          or (p.duration and (ctx.time.now + p.duration) or nil),
      stack      = exclusive and nil or p.stack,
      extend_by  = exclusive and 0 or (p.duration or 0),
      apply      = function(e)
        if p.base_add then e.stats:add_base(p.name, p.base_add) end
        if p.add_pct_add then e.stats:add_add_pct(p.name, p.add_pct_add) end
        if p.mul_pct_add then e.stats:add_mul_pct(p.name, p.mul_pct_add) end
      end,
      remove     = function(e)
        if p.base_add then e.stats:add_base(p.name, -p.base_add) end
        if p.add_pct_add then e.stats:add_add_pct(p.name, -p.add_pct_add) end
        if p.mul_pct_add then e.stats:add_mul_pct(p.name, -p.mul_pct_add) end
      end
    }
  end

  return runner
end

    
    




--[[-----------------------------------------------------------------------------
Damage, Healing & Utility Effects — Documentation & Rename Suggestions (comments only)
------------------------------------------------------------------------------------
Overview
  • Effects.deal_damage(params) — full hit pipeline with weapon rolls, conversions,
    hit/crit, dodge, block, armor, RR, penetration, caps, DR, absorbs, reflect, lifesteal,
    retaliation, and event emissions.
  • Effects.heal(params)        — flat and/or % max heal (scaled by healing_received_pct).
  • Effects.grant_barrier(...)  — convenience wrapper for a temporary flat_absorb buff.
  • Effects.seq(list)           — run effects in order (short-circuits only on user code).
  • Effects.chance(pct, eff)    — probabilistic effect runner.
  • Effects.scale_by_stat(...)  — stat-scaled builder helper.
  • Effects.apply_dot(params)   — registers a DoT entry (ticking handled by your game loop).
  • Effects.force_counter_attack(params) — immediate counter-attack (weapon-based).

Key Phases in deal_damage (order of operations)
  1) Build components:
       - weapon=true → random roll in [weapon_min, weapon_max] as physical + scaled flat typed adds
       - weapon=false → use provided components [{type, amount}]
       - Conversions: skill_conversions first, then src.gear_conversions (via Conv.apply)
  2) To-hit & crit:
       - PTH computed from OA/DA, clamped to [60, 140] (%); miss if rand > PTH
       - Piecewise crit multiplier from PTH, multiplied by (1 + crit_damage_pct/100)
  3) Early defenses:
       - Dodge (target) check; early out if successful
       - Shield block: chance (pierced), block amount (pierced), recovery cooldown set
  4) Aggregate & attacker mods:
       - Sum per damage type; multiply by crit; multiply by all_damage_pct and per-type modifier_pct
  5) Per-type defenses (for each damage type):
       - Physical armor mitigation (before resist), with attacker armor_penetration_pct and target armor_absorption_bonus_pct
       - Resistance Reduction (tgt.active_rr filtered by time) via RR.apply_all(base_res, alive_rr)
       - Penetration (attacker): penetration_all_pct + penetration_<type>_pct
       - Caps (defender): clamp final resist to [min_cap, max_cap] including type-specific cap deltas
       - Apply resist, then per-type and global damage_taken_*_reduction_pct
       - Percent absorb → Block consumption → Flat absorb
  6) Apply HP, death, lifesteal (attacker), reflect (target), retaliation (typed), emit OnHitResolved

Events emitted
  • OnMiss, OnDodge, OnDeath, OnHealed, OnHitResolved, and in retaliation path the nested call may emit OnDeath/OnHitResolved, etc.
  • Retaliation is executed by issuing a new Effects.deal_damage call from tgt→src.
    Consider tagging those calls to prevent infinite “ping-pong” chains (see notes below).

Integration Notes
  • Debug prints fire only when ctx.debug == true.
  • Block recovery uses a base of 1.0s reduced by target’s block_recovery_reduction_pct (floored at 0.1s).
  • Armor absorption uses a base 70% coefficient (0.70) modified by armor_absorption_bonus_pct.
  • Active RR entries are stored on the target: tgt.active_rr[damageType] = { {kind, amount, until_time}, ... }
  • Resist caps are applied after RR and penetration: final_res = clamp(baseRes→RR→penetration, min_cap, max_cap)

Potential Gameplay Tweaks (comments only; future enhancements)
  • Infinite retaliation risk: because retaliation deals damage which can trigger the other side’s retaliation,
    you can mark retaliation hits via p.reason="retaliation" or tags={retaliation=true} and have your combat
    rules ignore retaliation when reason/tags include "retaliation". (See inline note where retaliation is invoked.)
  • For counter-attacks, similarly tag with tags={counter=true} if you want UI/systems to distinguish them.
  • Consider emitting an event when a block occurs (e.g., OnBlock) if you want UI feedback.
  • Consider capturing overheal amount in heal (emit OnHealed with overheal, if desired).

Rename Suggestions (purely optional; comments only)
  • 'p'            → 'params' | 'opts' | 'spec'
  • 'comps'        → 'components'
  • 'sums'         → 'type_totals'
  • 'pth'          → 'calc_pth' | 'chance_to_hit'
  • 'PTH'          → 'hit_chance_pct'
  • 'ret_components' → 'retaliation_components'
  • 'dbg'          → 'debugf' | 'trace'
  • 'after_pct/after_block/after_flat' → 'post_pct_absorb'/'post_block'/'post_flat_absorb'
-----------------------------------------------------------------------------]]


-- Deal damage with optional weapon scaling and conversions.
--  p = {
--    weapon = <bool>,          -- if true, use src weapon_min/max and scale_pct
--    scale_pct = <number>|100, -- weapon damage scale %
--    components = { { type, amount }, ... } -- used when weapon=false
--    skill_conversions = { { from, to, pct }, ... } -- skill-stage conversions
--  }
Effects.deal_damage = function(p)
  return function(ctx, src, tgt)
    local reason = p.reason or "unknown" -- <— Used in OnHitResolved for downstream consumers/UI; suggest values like "attack", "spell", "retaliation", "counter".
    local tags   = p.tags or {}          -- <— Free-form metadata table to classify hits (e.g., {retaliation=true, aoe=true, ranged=true}).

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
        tmp[#tmp + 1] = string.format("%s=%0.1f", tostring(c.type), _round1(c.amount))
      end
      table.sort(tmp) -- stable-ish, alphabetical by "type=…"
      return table.concat(tmp, ", ")
    end

    -- sums: map { [damageType]=amount }
    local function _sums_to_string(sums)
      if not ctx.debug then return "" end
      local keys, tmp = {}, {}
      for k in pairs(sums) do keys[#keys + 1] = k end
      table.sort(keys)
      for i = 1, #keys do
        local k = keys[i]
        tmp[#tmp + 1] = string.format("%s=%0.1f", tostring(k), _round1(sums[k]))
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
        parts[#parts + 1] = string.format("%s:%s=%0.1f%s",
          tostring(r.kind), tostring(r.damage), _round1(r.amount),
          tleft and string.format(" (%.1fs)", _round1(tleft)) or "")
      end
      return table.concat(parts, ", ")
    end
    -- ------------------------------------------------------------------------

    -- Build raw components ----------------------------------------------------
    -- NOTE: weapon=true path rolls a random physical base and adds scaled flat typed adds.
    --       weapon=false path uses the provided components unchanged.
    local comps = {}

    if p.weapon then
      local min         = src.stats:get('weapon_min')
      local max         = src.stats:get('weapon_max')
      local base        = math.random() * (max - min) + min
      local scale       = (p.scale_pct or 100) / 100

      comps[#comps + 1] = { type = 'physical', amount = base * scale }
      dbg("Weapon roll: min=%.1f max=%.1f base=%.1f scale=%.2f", min, max, base, scale)

      -- Add per-type flat damage from source (also scaled by weapon scale)
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
    -- FYI: Conversions preserve total sum (modulo float precision).
    comps = Conv.apply(comps, p.skill_conversions, src.gear_conversions)
    dbg("After conversions: %s", _comps_to_string(comps))

    -- Hit/crit and defense ----------------------------------------------------
    -- Rename suggestion: 'pth' → 'calc_pth' | 'chance_to_hit'
    local function pth(OA, DA)
      -- Empirical hit-chance curve. Clamped later to [60, 140] (percent).
      local term1 = 3.15 * (OA / (3.5 * OA + DA))
      local term2 = 0.0002275 * (OA - DA)
      return (term1 + term2 + 0.2) * 100
    end

    local OA  = src.stats:get('offensive_ability')
    local DA  = tgt.stats:get('defensive_ability')
    local PTH = util.clamp(pth(OA, DA), 60, 140) -- Lower floor ensures some hit chance even when outmatched.
    dbg("Hit check: OA=%.1f DA=%.1f PTH=%.1f%%", OA, DA, PTH)

    -- Miss check
    if math.random() * 100 > PTH then
      dbg("Attack missed!")
      ctx.bus:emit('OnMiss', { source = src, target = tgt, pth = PTH })
      return
    end

    -- Crit multiplier from PTH (piecewise)
    -- Multiplied by (1 + crit_damage_pct/100). This lets gear/aura add crit damage scaling.
    local crit_mult =
        (PTH < 75) and (PTH / 75) or
        (PTH < 90) and 1.0 or
        (PTH < 105) and 1.1 or
        (PTH < 120) and 1.2 or
        (PTH < 130) and 1.3 or
        (PTH < 135) and 1.4 or (1.5 + (PTH - 135) * 0.005)
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
    -- Uses target cooldown gate; chance and amount can be pierced by attacker.
    tgt.timers      = tgt.timers or {}
    local blocked   = false
    local block_amt = 0
    -- (with pierce):
    local blk_chance = (tgt.stats:get('block_chance_pct') or 0)
                       - (src.stats:get('block_chance_pierce_pct') or 0)
    blk_chance = math.max(0, blk_chance)

    if ctx.time:is_ready(tgt.timers, 'block')
        and math.random() * 100 < blk_chance then
      blocked    = true
      block_amt  = tgt.stats:get('block_amount')

      -- reduce block amount if the hit is blocked
      local blk_amt_pierce = (src.stats:get('block_amount_pierce_pct') or 0)
      if blk_amt_pierce ~= 0 then
        block_amt = block_amt * math.max(0, 1 - blk_amt_pierce / 100)
      end

      -- Recovery: base 1.0s scaled by block_recovery_reduction_pct, floored at 0.1s
      local base = 1.0
      local rec  = base * (1 - tgt.stats:get('block_recovery_reduction_pct') / 100)
      ctx.time:set_cooldown(tgt.timers, 'block', math.max(0.1, rec))
      dbg("Block triggered: chance=%.1f%% amt=%.1f next_ready=%.2f",
        blk_chance, block_amt, tgt.timers['block'] or -1)
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
      -- Base (defender) resistance and active RR
      local base_res = tgt.stats:get(t .. '_resist_pct')
      local alive_rr = {}
      if tgt.active_rr and tgt.active_rr[t] then
        for _, e2 in ipairs(tgt.active_rr[t]) do
          if (not e2.until_time) or e2.until_time > ctx.time.now then
            alive_rr[#alive_rr + 1] = e2
          end
        end
      end
      local res_after_rr = RR.apply_all(base_res, alive_rr)

      -- Physical armor (before resist); supports attacker armor penetration
      if t == 'physical' then
        -- Armor mitigation: limited by effective armor, scaled by absorption (70% base + bonus)
        local armor = tgt.stats:get('armor')
        local apen  = (src.stats:get('armor_penetration_pct') or 0)
        local armor_eff = armor * math.max(0, 1 - apen / 100)
        local abs   = 0.70 * (1 + tgt.stats:get('armor_absorption_bonus_pct') / 100)
        local mit   = math.min(amt, armor_eff) * abs
        amt         = amt - mit
        dbg("  Armor: armor=%.1f apen=%.1f%% eff=%.1f abs=%.2f mit=%.1f remain=%.1f",
            armor, apen, armor_eff, abs, mit, amt)
      end

      -- Penetration (attacker)
      local pen_all = (src.stats:get('penetration_all_pct') or 0)
      local pen_t   = (src.stats:get('penetration_' .. t .. '_pct') or 0)
      local pen     = pen_all + pen_t

      -- Caps (defender)
      local max_cap = 100 + (tgt.stats:get('max_resist_cap_pct') or 0)
                           + (tgt.stats:get('max_' .. t .. '_resist_cap_pct') or 0)
      local min_cap = -100 + (tgt.stats:get('min_resist_cap_pct') or 0)
                            + (tgt.stats:get('min_' .. t .. '_resist_cap_pct') or 0)

      local res_after_pen = res_after_rr - pen
      local res_final     = util.clamp(res_after_pen, min_cap, max_cap)

      dbg("Type %s: start=%.1f base_res=%.1f after_rr=%.1f pen=%.1f caps=[%d,%d] -> final_res=%.1f | RR: %s",
          t, amt, base_res, res_after_rr, pen, math.floor(max_cap+0.5), math.floor(min_cap+0.5),
          res_final, _rr_bucket_to_string(alive_rr))

      -- Apply resistance
      local after_resisted = amt * (1 - res_final / 100)

      -- Per-type & global damage reduction (defender)
      local dr_t = (tgt.stats:get('damage_taken_' .. t .. '_reduction_pct') or 0)
      local dr_g = (tgt.stats:get('damage_taken_reduction_pct') or 0)
      local after_dr = after_resisted * (1 - dr_t / 100) * (1 - dr_g / 100)

      -- Percent absorb -> Block -> Flat absorb
      local after_pct   = after_dr * (1 - tgt.stats:get('percent_absorb_pct') / 100)
      local after_block = after_pct

      if blocked then
        local used  = math.min(block_amt, after_pct)
        after_block = after_pct - used
        block_amt   = block_amt - used
        dbg("  Block: used=%.1f remain=%.1f", used, block_amt)
      end

      local after_flat = math.max(0, after_block - tgt.stats:get('flat_absorb'))
      dbg("  Final after absorbs (flat=%0.1f): %s=%0.1f", tgt.stats:get('flat_absorb') or 0, t, after_flat)
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
      src.hp     = util.clamp((src.hp or smax) - re, 0, smax)
      dbg("Reflect: -%.1f, Attacker HP=%.1f/%.1f", re, src.hp, smax)
    end

    -- Retaliation (typed retaliation modification) ---------------------------
    -- NOTE: This recursively calls deal_damage from target → source.
    --       If both parties have retaliation > 0, this can “ping-pong”.
    --       Use 'reason'/'tags' to gate retaliation in your combat rules if desired.
    --       (e.g., treat hits with tags.retaliation=true as non-retaliable.)
    local ret_components = {}
    for _, dt in ipairs(DAMAGE_TYPES) do
      local base = tgt.stats:get('retaliation_' .. dt) or 0
      if base ~= 0 then
        local mod = 1 + (tgt.stats:get('retaliation_' .. dt .. '_modifier_pct') or 0) / 100
        table.insert(ret_components, { type = dt, amount = base * mod })
      end
    end
    if #ret_components > 0 then
      dbg(">> Executing target retaliation (typed): %s", _comps_to_string(ret_components))
      -- Future-friendly idea (do not change now): pass reason/tags like
      -- Effects.deal_damage{ components=ret_components, reason='retaliation', tags={retaliation=true} }(...)
      Effects.deal_damage { components = ret_components } (ctx, tgt, src)
    end

    ctx.bus:emit('OnHitResolved', {
      source     = src,
      target     = tgt,
      damage     = dealt,     -- total final damage after all defenses
      did_damage = (dealt or 0) > 0,
      crit       = (crit_mult > 1.0) or false,
      pth        = PTH or nil,
      reason     = reason,    -- supplied by caller to categorize the hit
      tags       = tags,      -- free-form classification (aoe, projectile, retaliation, etc.)
      components = sums,      -- pre-defense per-type totals (post-crit & attacker mods)
    })
  end
end

--- Heal target. Scales with target's healing_received_pct.
--  p = { flat = <number>|0, percent_of_max = <number>|nil }
-- Emits OnHealed with the actual amount applied (no overheal report by default).
-- Rename suggestions: include p.reason/tags similar to deal_damage for symmetry.
Effects.heal = function(p)
  return function(ctx, src, tgt)
    local maxhp = tgt.max_health or tgt.stats:get('health')
    local amt   = (p.flat or 0) + (p.percent_of_max and maxhp * (p.percent_of_max / 100) or 0)
    amt         = amt * (1 + tgt.stats:get('healing_received_pct') / 100)

    tgt.hp      = util.clamp((tgt.hp or maxhp) + amt, 0, maxhp)
    ctx.bus:emit('OnHealed', { source = src, target = tgt, amount = amt })
  end
end

--- Convenience: temporary barrier as a flat_absorb buff.
--  p = { amount = <number>, duration = <secs> }
-- Stacking semantics follow modify_stat + your status engine’s stack policy.
-- Fixed id='barrier' means subsequent calls will replace/extend depending on stack mode.
Effects.grant_barrier = function(p)
  return Effects.modify_stat {
    id       = 'barrier',
    name     = 'flat_absorb',
    base_add = p.amount,
    duration = p.duration
  }
end

--- Sequence multiple effects in order.
-- If a later effect depends on earlier state (e.g., a tag set), seq preserves that order.
-- Rename suggestion: 'list' → 'effects'
Effects.seq = function(list)
  return function(ctx, src, tgt)
    for _, e in ipairs(list) do
      e(ctx, src, tgt)
    end
  end
end

--- Execute `eff` with probability `pct` (0..100).
-- Use for proc-like effects; if you need ICDs, wrap with Core.hook/icd logic externally.
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
-- Handy when an effect’s magnitude depends on a stat snapshot at cast time.
-- Rename suggestion: 'f' → 'factor' | 'scale'
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
-- Suggested ticking model:
--   • On each tick, compute per-type damage using current resists (and alive RR),
--     so mid-fight RR and buffs affect ongoing DoTs dynamically.
-- Rename suggestions: 'tick' → 'period', 'next_tick' → 'next_time'
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
-- Emits OnCounterAttack with { is_counter = true } for downstream logic/UI.
-- Tip: If you want counter-attacks not to trigger retaliation, pass tags in the nested call
--      (future-friendly; keep code as-is now and handle in your rules when tags.reason='counter').
Effects.force_counter_attack = function(p)
  p = p or {}
  local scale = p.scale_pct or 100

  return function(ctx, src, tgt) -- src = counter-attacker (Ogre), tgt = defender (Hero)
    if not src or src.dead or not tgt or tgt.dead then return end

    -- ✅ attacker is src, defender is tgt
    Effects.deal_damage { weapon = true, scale_pct = scale } (ctx, src, tgt)

    if ctx and ctx.bus and ctx.bus.emit then
      ctx.bus:emit('OnCounterAttack', { source = src, target = tgt, scale_pct = scale, is_counter = true })
    end
  end
end





--[[-----------------------------------------------------------------------------
Combat, Items, Leveling, and Content — Documentation & Rename Suggestions
-------------------------------------------------------------------------------
Overview
  • Combat
      - Combat.new(rr, dts): tiny convenience container for RR implementation & damage type list.
      - Combat.get_penetration(src, type): sums src’s global + type-specific penetration.
      - Combat.get_caps(def, type): computes defender’s min/max resist caps for that type.

  • Items
      - Items.equip_rules: allowlists for which slots an item can use per attribute + mode.
      - Items.can_equip(entity, item): attribute gate + slot allowlist check.
      - Items.upgrade(ctx, e, item, spec): mutate item (level/mods); if equipped, re-equip to apply.

  • Leveling
      - Curve registry: Leveling.register_curve(id, fn) where fn(level) → xp_to_next.
      - Leveling.xp_to_next(ctx, e, L): resolves xp needed (entity can override curve via e.level_curve).
      - Leveling.grant_exp(ctx, e, base): apply XP (scaled by experience_gained_pct), loops level-ups.
      - Leveling.level_up(ctx, e): level increment + point grants + OA/DA bump; emits OnLevelUp.

  • Content
      - Content.attach_attribute_derivations(Stats): recompute hook wiring attribute→derived stats.
      - Content.Spells: examples; supports builder pattern via .build(level, mods) and fallback .effects.
      - Content.Traits: event-driven procs/counters; either effects specs or custom handler functions.

Event Emissions (from this chunk)
  • Leveling.grant_exp → OnExperienceGained
  • Leveling.level_up  → OnLevelUp
  • Content examples use Effects.* which emit their own events (e.g., OnRRApplied, OnHitResolved, etc.)

Design Notes & Integration Tips
  • Penetration vs. RR: Use Combat.get_penetration for attacker-side penetration; RR is handled elsewhere.
  • Equip rules give a clean “design surface” for slot gating; if your project uses dynamic slot sets,
    consider centralizing SLOTS/SlotOrder (as you already do elsewhere) and deriving allowlists from them.
  • Leveling.grant_exp handles multi-level-ups robustly and logs a clear debug line when ctx.debug is true.
  • Attribute derivations are applied through Stats:on_recompute; be sure to call stats:recompute() after
    any persistent base changes (e.g., allocating attribute points) to keep derived stats in sync.

Optional Rename Suggestions (comments only; do not change code now)
  • Combat.new(rr, dts)            → (rr)→rr_module | rr_impl, (dts)→damage_types
  • Items.can_equip(e, item)       → add local names: 'req'→'requirement', 'allowed'→'allowed_slots'
  • Items.upgrade(..., spec)       → spec→upgrade_spec (contains level_up, add_mods)
  • Leveling.grant_exp(..., base)  → base→xp_base, gained→xp_awarded, levels_gained→levels_delta
  • Content.attach_attribute_derivations(S) → S→stats (for readability)
  • Content.Spells.Fireball.build(level, mods) → mods→ability_mods or build_mods

Potential Extensions (future ideas; not changing code)
  • Items.can_equip: consider returning a richer object on failure (e.g., {ok=false, reason='slot_not_allowed', need=...}).
  • Items.upgrade: optionally support removing mods or upgrading by tier template.
  • Leveling: expose a Leveling.preview(ctx, e, xp) to see projected levels gained without mutating state.
  • Derivations: extract constants (per-point bonuses) at top for tuning knobs.
-----------------------------------------------------------------------------]]


-- ============================================================================
-- Combat
-- Minimal constructor returning a small context bundle for convenience.
-- Tips:
--   • 'rr' should be the RR module/table you want consumers to use.
--   • 'dts' is a canonical DAMAGE_TYPES list (keep in sync with StatDef.make()).
-- Rename ideas: rr→rr_module, dts→damage_types
-- ============================================================================
Combat.new = function(rr, dts)
  return { RR = rr, DAMAGE_TYPES = dts }
end

-- Attacker-side penetration helper.
-- Returns total % penetration for damage type 't' (global + typed).
-- Suggest: guard against nil src.stats when used outside combat setup.
function Combat.get_penetration(src, t)
  return ((src.stats:get('penetration_all_pct') or 0) + (src.stats:get('penetration_'..t..'_pct') or 0))
end

-- Defender-side cap helper.
-- Computes effective min/max caps including global and typed deltas.
-- Returns (min_cap, max_cap) in that order.
function Combat.get_caps(def, t)
  local max_cap = 100 + (def.stats:get('max_resist_cap_pct') or 0)
                       + (def.stats:get('max_'..t..'_resist_cap_pct') or 0)
  local min_cap = -100 + (def.stats:get('min_resist_cap_pct') or 0)
                        + (def.stats:get('min_'..t..'_resist_cap_pct') or 0)
  return min_cap, max_cap
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
-- Notes:
--   • The allowlist is purely declarative; extend or swap tables per game.
--   • If you wish to enforce two-handed mutual exclusion or set conflicts, do that in your ItemSystem.equip.
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

-- Returns boolean or (false, reason).
-- Reasons:
--   • 'attribute_too_low' → e.stats[attribute] < required value
--   • 'slot_not_allowed'  → item.slot not in allowlist for attribute/mode
-- If item.requires is missing, equipping is allowed by default.
function Items.can_equip(e, item)
  if not item.requires then return true end

  local req = item.requires -- rename idea: requirement
  if e.stats:get(req.attribute) < (req.value or 0) then
    return false, 'attribute_too_low'
  end

  local allowed = Items.equip_rules[req.mode or 'sole'][req.attribute] -- rename idea: allowed_slots
  if allowed then
    for _, slot in ipairs(allowed) do
      if slot == item.slot then return true end
    end
    return false, 'slot_not_allowed'
  end

  -- If no rule exists for that attribute/mode, default to allowed.
  -- You can tighten this to return false if you want strict schemas.
  return true
end

-- Upgrades an item in-place and re-equips it to apply fresh mods if currently worn.
-- spec = {
--   level_up = <+N levels>,
--   add_mods = { <mod1>, <mod2>, ... } -- appended to item.mods
-- }
-- Notes:
--   • Re-equipping ensures any equip-time effects (auras, derived stats) reapply deterministically.
--   • Requires ItemSystem.unequip/equip to exist and handle side effects (events, stat recompute).
--   • You may want to validate mod shapes in your game’s item schema.
function Items.upgrade(ctx, e, item, spec)
  -- mutate the item itself
  item.level = (item.level or 0) + (spec.level_up or 0)
  for _, m in ipairs(spec.add_mods or {}) do
    item.mods = item.mods or {}
    table.insert(item.mods, m)
  end
  -- if currently equipped on this entity, re-apply by re-equipping
  if e and e.equipped and e.equipped[item.slot] == item then
    ItemSystem.unequip(ctx, e, item.slot)
    ItemSystem.equip(ctx, e, item)
  end
  return item
end


-- === Leveling curve registry ================================================
-- Curve API:
--   Leveling.register_curve(id, fn) where fn(level:int) -> xp_to_next:int
-- Entity can choose curve by setting: e.level_curve = '<id>'
Leveling.curves = Leveling.curves or {}

-- Register a curve by id. fn(level) -> xp_to_next
function Leveling.register_curve(id, fn)
  Leveling.curves[id] = fn
end

-- Resolve xp needed for next level for entity e at its current level (or given L)
-- Fallback if curve missing: 1000 * level
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
Leveling.register_curve('fast_start', function(level) -- generous early levels
  return math.floor(600 + (level - 1) * 800)
end)

Leveling.register_curve('veteran', function(level) -- steeper
  return math.floor(1200 + (level - 1) * 1100)
end)
-- ============================================================================

-- ============================================================================
-- Leveling
-- Simple EXP -> Level conversion:
--   - xp threshold per level = (level * 1000) by default curve
--   - on level-up: +1 attribute point, +3 skill points, +1 mastery up to 2,
--     +10 OA and +10 DA (base adds).
-- Emits: 'OnLevelUp' and 'OnExperienceGained' events.
-- Tips:
--   • Uses e.stats:get('experience_gained_pct') to scale awarded XP.
--   • Loops multiple level-ups if enough XP remains.
--   • Debug print (ctx.debug) shows snapshot including “to next”.
-- Rename ideas: base→xp_base, gained→xp_awarded, levels_gained→levels_delta
-- ============================================================================
function Leveling.grant_exp(ctx, e, base)
  local pct = 0
  if e.stats and e.stats.get then
    pct = e.stats:get('experience_gained_pct') or 0
  end
  local gained        = base * (1 + pct / 100)

  e.level             = e.level or 1
  e.xp                = (e.xp or 0) + gained

  local levels_gained = 0
  while true do
    local need = Leveling.xp_to_next(ctx, e, e.level or 1)
    if (e.xp or 0) >= need then
      e.xp = (e.xp or 0) - need
      Leveling.level_up(ctx, e)                -- assumes this increments e.level
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

-- Applies a single level-up’s side effects and emits OnLevelUp.
-- Consider calling e.stats:recompute() in the system that processes point spends,
-- not necessarily here (to avoid double recompute when batching allocations).
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
-- Tips:
--   • Keep derivation constants centralized for easy tuning.
--   • Consider adding complementary defensive scaling to cunning/spirit if desired.
-- ============================================================================
Content = {}

--- Attach attribute->stat derivations to a Stats instance (via recompute hook).
--  - Physique:
--      + health: 100 flat + 10 per point
--      + health_regen: +0.2 per point above 10
--  - Cunning:
--      + OA: +1 per point
--      + per-5 points: +1% physical/pierce modifiers, +1% bleed/trauma duration
--  - Spirit:
--      + health: +2 per point
--      + energy: +10 per point
--      + energy_regen: +0.5 per point
--      + per-5 points: +1% elemental/acid/vitality/aether/chaos modifiers,
--                      +1% burn/frostburn/electrocute/poison/vitality_decay duration
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
    S:derived_add_add_pct('pierce_modifier_pct', chunks_c * 1)
    S:derived_add_add_pct('bleed_duration_pct', chunks_c * 1)
    S:derived_add_add_pct('trauma_duration_pct', chunks_c * 1)

    S:derived_add_base('health', s * 2)
    S:derived_add_base('energy', s * 10)
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
-- Shape:
--   {
--     id?         = <string>,
--     name        = <string>,
--     class       = <string>,
--     trigger     = 'OnCast' | 'OnHit' | ... (consumed by your runner),
--     item_granted? = <bool> (signals item-granted; often excluded from some reductions),
--     targeter(ctx) -> targets,
--     build?(level, mods) -> (ctx, src, tgt) runner,
--     effects?(ctx, src, tgt)  -- fallback if build not used
--   }
-- Notes:
--   • The build(level, mods) pattern lets you apply ability-level and item/gear mods cleanly.
--   • Your Cast.cast may choose build() first and fall back to effects if absent.
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
    targeter     = function(ctx) return { ctx.target } end,

    -- Level/mod-aware builder. If absent, Cast.cast falls back to .effects.
    build        = function(level, mods)
      level           = level or 1
      mods            = mods or { dmg_pct = 0 }

      local base      = 120 + (level - 1) * 40 -- +40 per level
      local rr        = 20 + (level - 1) * 5 -- +5% RR per level
      local dmg_scale = 1 + (mods.dmg_pct or 0) / 100

      -- return Effects.seq {
      --   Effects.deal_damage {
      --     components = { { type = 'fire', amount = base * dmg_scale } }
      --   },
      --   Effects.apply_rr {
      --     kind = 'rr1', damage = 'fire', amount = rr, duration = 4
      --   },
      -- }

      return function(ctx, src, tgt)
        -- If Cast.cast already called .build, .effects won’t be used.
        Effects.deal_damage { components = { { type = 'fire', amount = base * dmg_scale } } } (ctx, src, tgt)
        Effects.apply_rr { kind = 'rr1', damage = 'fire', amount = rr, duration = 4 } (ctx, src, tgt)
      end
    end,

    -- Backward compatible default:
    effects      = function(ctx, src, tgt)
      -- If Cast.cast already called .build, .effects won’t be used.
      Effects.deal_damage { components = { { type = 'fire', amount = 120 } } } (ctx, src, tgt)
      Effects.apply_rr { kind = 'rr1', damage = 'fire', amount = 20, duration = 4 } (ctx, src, tgt)
    end,
  },

  ViperSigil = {
    name     = 'Viper Sigil',
    class    = 'hex',
    trigger  = 'OnCast',
    targeter = function(ctx) return Core.Targeters.all_enemies(ctx) end,
    effects  = Effects.apply_rr { kind = 'rr2', damage = 'cold', amount = 20, duration = 3 },
    -- Note: rr2 is multiplicative; only the strongest rr2 applies when multiple are active.
  },

  ElementalStorm = {
    name     = 'Elemental Storm',
    class    = 'aura',
    trigger  = 'OnCast',
    targeter = function(ctx) return Core.Targeters.all_enemies(ctx) end,
    effects  = Effects.apply_rr { kind = 'rr3', damage = 'cold', amount = 32, duration = 2 },
    -- Note: rr3 is flat after multiplicative; strongest rr3 is applied.
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
-- Tips:
--   • For chance-based procs, consider adding an internal cooldown via Core.hook/icd pattern.
--   • Use tags/reason (supported by Effects.deal_damage) to classify proc hits if needed.
Content.Traits = {
  EmberStrike = {
    name     = 'Ember Strike',
    class    = 'weapon_proc',
    trigger  = 'OnBasicAttack',
    chance   = 35, -- % proc chance per basic attack
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
      -- 25% chance to counter-attack the last source that hit this target
      -- Rename ideas: extract 25 into a tuning constant, and/or add tags={counter=true} on the hit.
      if ev and ev.target and ev.source and util.rand() * 100 < 25 then
        Effects.force_counter_attack { scale_pct = 50 } (ctx, ev.target, ev.source)
      end
    end,
  },
}



--[[-----------------------------------------------------------------------------
Items & Actives + Direct Casting — Documentation & Rename Suggestions
-------------------------------------------------------------------------------
This file wires items into entities (equip/unequip), plugs proc listeners into
the EventBus, grants actives, and exposes a direct spell-casting flow with
cooldowns, costs, and mutator wrapping.

Key Concepts
  • Equip/Unequip lifecycle
      - Applies/removes stat modifiers (tracked for perfect reversal).
      - Adds/removes gear-wide damage conversions (tracked by range).
      - Subscribes/unsubscribes proc handlers per item (keeps unsubscribe fns).
      - Registers/unregisters spell mutators (keeps identity references).
      - Grants/removes active spells (boolean flags on entity).
      - Calls e.stats:recompute() after equip/unequip to refresh derived stats.
      - Optional item.on_equip() → returns cleanup fn (saved on item._cleanup).
      - Optional item.on_unequip(ctx, e) is invoked on removal.

  • Procs
      - Item.procs: array of { trigger, chance?, filter?(ev)->bool, effects(ctx, e, tgt, ev) }.
      - Default filter: only proc when ev.source == the equipped entity.
      - Subscriptions are stored in item._unsubs (unsubscribe on unequip).

  • Conversions
      - Item.conversions: array of { from, to, pct } appended to e.gear_conversions.
      - Start/end indices recorded on the item for removal on unequip.

  • Spell Mutators
      - item.spell_mutators[spellKey] = { fn | {pr, wrap} ... }
      - normalize to {pr=?, wrap=function}; store identity for later removal.

  • Direct Cast Flow (Cast.cast)
      - Resolves spell table (ref or key), canonicalizes spell id.
      - Computes cooldown with entity cooldown_reduction (unless item_granted)
        and item-level additive cd_add.
      - Computes and charges energy cost with skill_energy_cost_reduction and
        item-level cost_pct (positive raises cost, negative reduces).
      - Emits OnCast with spell & target; builds targets (explicit or spell.targeter).
      - Builds effects via spell.build(level, mods) if present; else uses .effects.
      - Wraps effects via apply_spell_mutators (sorted by pr).
      - Executes effects for every target and sets cooldown.

  • Events emitted here
      - ItemSystem.equip/unequip: debug prints only; effects & statuses emit in Effects.*
      - Cast.cast: OnCast before effects; cooldown is set after execution.

  • Safety & Robustness Notes
      - All removals are identity-based (mod lists, mutators, procs).
      - Unequip mirrors equip (tracked deltas) to avoid drift.
      - Re-equip pattern in Items.upgrade elsewhere ensures derived updates.
      - pcalls around cleanup hooks guard against hard failures.

Optional Rename Suggestions (comments only; do not change code now)
  • _listen(bus, name, fn, pr)            → subscribe_with_unsub
  • ItemSystem.equip(ctx, e, item)         → ctx→context, e→entity, item→itm (or equipped_item)
  • ok/err                                 → equip_ok/equip_err
  • item._applied                          → _applied_stat_deltas
  • item._unsubs                           → _proc_unsubscribers
  • item._mut_applied                      → _applied_mutators
  • Cast.cast(ctx, caster, spell_ref, primary_target)
      spell_ref→spell_or_id, primary_target→explicit_target
  • key ('cd:'..spell_id)                  → cd_key

Integration Tips
  • If you have set bonuses/pets (see PetsAndSets.recompute_sets), keep those
    calls centralized on equip/unequip as you do now.
  • Consider adding an optional ItemSystem.validate(item) in your project to
    assert expected shapes before equip (stat names, conversions, proc triggers).
  • To add internal cooldowns for procs, extend the proc entry with icd and
    track per-item timers (using ctx.time:is_ready / set_cooldown).
-----------------------------------------------------------------------------]]


---------------------------
-- Items & Actives: ItemSystem (equip/unequip, procs, granted actives)
---------------------------


-- Internal helper: subscribe to an EventBus event and return an unsubscribe fn.
--  Usage:
--    local un = _listen(bus, 'OnCast', handler, pr)
--    ... later ...
--    un()  -- removes that listener
-- Rename suggestion: _listen → subscribe_with_unsub (keeps intent obvious)
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
-- Notes:
--  • Mirrors all applied changes so unequip can perfectly reverse them.
--  • If the target slot is occupied, automatically unequips the old item first.
--  • on_equip may return a cleanup fn; both _cleanup() and on_unequip are called on removal.
function ItemSystem.equip(ctx, e, item)
  if ctx.debug then
    print(string.format("[DEBUG][ItemSystem] Attempting to equip item '%s' into slot '%s'", item.id or "?",
      item.slot or "?"))
  end

  -- Gate by attribute and slot rules
  local ok, err = Items.can_equip(e, item) -- rename idea: ok→equip_ok, err→equip_err
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
  -- Shape of a mod: { stat='...', base?=N, add_pct?=N, mul_pct?=N }
  item._applied = {} -- rename idea: _applied_stat_deltas
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
  
  -- on_equip hook
  -- If present, allows items to apply arbitrary side-effects and return a cleanup function.
  -- Example uses: registering temporary auras, toggling visuals, allocating temporary containers.
  if type(item.on_equip) == "function" then
    -- allow the hook to return a cleanup function
    item._cleanup = item.on_equip(ctx, e) or item._cleanup
  end


  -- Gear-wide conversions (append to entity’s list and remember the range)
  -- Conversions shape: { from='physical', to='fire', pct=25 }
  -- We record start/end indices so removal is O(k) and identity-safe on unequip.
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
  -- Proc shape:
  --   { trigger='OnHitResolved', chance=35, filter?(ev)->bool, effects(ctx, e, tgt, ev) }
  -- Defaults:
  --   • filter omitted → only triggers when ev.source == e.
  --   • chance omitted → 100%.
  item._unsubs = {} -- rename idea: _proc_unsubscribers
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
        
        -- pass ev through:
        p.effects(ctx, e, tgt, ev)
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
  -- Notes:
  --   • We normalize entries to {pr=?, wrap=function}.
  --   • We maintain identity references so we can remove exactly those on unequip.
  if item.spell_mutators then
    e.spell_mutators = e.spell_mutators or {}
    item._mut_applied = {} -- track inserts to remove on unequip

    for spell_key, list in pairs(item.spell_mutators) do
      local sid = get_spell_id(spell_key) -- supports id or name as key
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
  -- This simply sets boolean flags in e.granted_spells; your Cast.cast logic
  -- uses is_item_granted to decide CDR policy etc.
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
  -- Recompute once at the end to avoid thrashing derived recompute hooks.
  e.equipped[item.slot] = item
  e.stats:recompute()
  if ctx.debug then
    print(string.format("[DEBUG][ItemSystem] Equipped '%s' into slot '%s'. Stats recomputed.", item.id or "?",
      item.slot or "?"))
  end
  return true
end

--- Unequip the item in a given slot from an entity.
--  Reverses stat mods, removes conversions, unsubscribes proc listeners,
--  clears granted actives for that item, and recomputes stats.
--  @return boolean ok, string|nil err
-- Notes:
--  • Mirrors equip tracking fields (_applied, _conv_start/_end, _mut_applied, _unsubs).
--  • Calls both returned cleanup fn from on_equip and an explicit on_unequip hook if provided.
function ItemSystem.unequip(ctx, e, slot)
  local item = e.equipped and e.equipped[slot]
  if not item then return false, 'empty_slot' end

  -- Revert stat mods (mirror of equip tracking)
  for _, ap in ipairs(item._applied or {}) do
    local kind, n, amt = ap[1], ap[2], ap[3]
    if kind == 'base' then
      e.stats:add_base(n, -amt)
    elseif kind == 'add_pct' then
      e.stats:add_add_pct(n, -amt)
    elseif kind == 'mul_pct' then
      e.stats:add_mul_pct(n, -amt)
    end
    
    -- Note: recompute after each change ensures any dependent constraints (e.g., caps)
    -- stay consistent even if an error interrupts midway; you can batch if preferred.
    e.stats:recompute()
    PetsAndSets.recompute_sets(ctx, e)
  end

  -- Remove conversions appended by this item
  if item._conv_start then
    for i = item._conv_end, item._conv_start + 1, -1 do
      table.remove(e.gear_conversions, i)
    end
    item._conv_start, item._conv_end = nil, nil
  end

  -- Unregister mutators added by this item (remove by identity)
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
  
  -- on_unequip cleanup
  -- The returned cleanup from on_equip is called (pcall) first, then on_unequip hook.
  if type(item._cleanup) == "function" then
    pcall(item._cleanup, e); item._cleanup = nil
  end
  if type(item.on_unequip) == "function" then
    pcall(item.on_unequip, ctx, e)
  end


  -- Clear equip slot and recompute
  e.equipped[slot] = nil
  e.stats:recompute()
  PetsAndSets.recompute_sets(ctx, e)
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
-- Rename suggestion: _get → get_or_zero
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
-- Flow:
--  1) Resolve spell + canonical id; ensure caster timers table exists.
--  2) Compute cooldown:
--       - If not item_granted, apply cooldown_reduction %.
--       - Apply item ability mods (cd_add seconds).
--     Early out if not ready.
--  3) Compute energy cost:
--       - Apply skill_energy_cost_reduction %.
--       - Apply item ability mods (cost_pct %).
--     Early out if not enough energy; deduct otherwise.
--  4) Emit OnCast payload (ctx, source, spell, spell_id, target).
--  5) Build targets:
--       - If primary_target provided, singleton list.
--       - Else call spell.targeter with game-layer callbacks.
--  6) Build effects:
--       - If spell.build exists → build(level, mods), else use spell.effects.
--       - Wrap with apply_spell_mutators (sorted by pr).
--  7) Run effects against each target and set cooldown.
-- Notes:
--  • get_ability_level / collect_ability_mods derive level/mods per caster+spell.
--  • is_item_granted(caster, spell) controls CDR policy for granted actives.
function Cast.cast(ctx, caster, spell_ref, primary_target)
  local spell = (type(spell_ref) == 'table') and spell_ref or Content.Spells[spell_ref]
  if not spell then return false, 'unknown_spell' end

  local spell_id = get_spell_id(spell) -- NEW: canonical id
  caster.timers  = caster.timers or {}
  local key      = 'cd:' .. spell_id
  local cd       = spell.cooldown or 0

  -- Ability/item mods -------------------------------------------------------- NEW
  local lvl      = get_ability_level(caster, spell) -- per-caster level
  local mods     = collect_ability_mods(caster, spell) -- dmg/cd/cost mods

  -- Cooldown reduction: skip if item-granted (your policy), then apply cd_add.
  if not is_item_granted(caster, spell) then
    local cdr = _get(caster.stats, 'cooldown_reduction')
    cd = cd * math.max(0, 1 - cdr / 100)
  end
  cd = math.max(0, cd + (mods.cd_add or 0)) -- additive seconds

  if not ctx.time:is_ready(caster.timers, key) then
    return false, 'cooldown'
  end

  -- Cost with reductions and item cost_pct ---------------------------------- NEW
  if spell.cost then
    local red     = _get(caster.stats, 'skill_energy_cost_reduction')
    local cost    = spell.cost * math.max(0, 1 - red / 100)
    cost          = cost * math.max(0, 1 + (mods.cost_pct or 0) / 100)
    caster.energy = caster.energy or _get(caster.stats, 'energy')
    if caster.energy < cost then
      return false, 'no_energy'
    end
    caster.energy = caster.energy - cost
  end

  ctx.bus:emit('OnCast', {
    ctx      = ctx,
    source   = caster,
    spell    = spell,
    spell_id = spell_id, -- NEW
    target   = primary_target
  })

  -- Build target list (same as before)
  local tgt_list
  if primary_target then
    tgt_list = { primary_target }
  else
    tgt_list = spell.targeter({
      source         = caster,
      target         = primary_target,
      get_enemies_of = ctx.get_enemies_of,
      get_allies_of  = ctx.get_allies_of,
    })
  end

  -- Prepare effects function, wrapping with mutators if any ------------------ NEW
  local eff = spell.effects
  -- If the spell provided a level-aware builder, prefer it:
  if spell.build then
    eff = spell.build(lvl, mods) -- pass both, non-breaking for old spells
  end
  eff = apply_spell_mutators(caster, ctx, spell, eff)

  -- Execute effects
  for _, t in ipairs(tgt_list or {}) do
    eff(ctx, caster, t)
  end

  ctx.time:set_cooldown(caster.timers, key, cd)
  return true
end






--[[============================================================================
SKILLS.lua + WPS.lua — Documentation & Rename Suggestions (comments-only)
==============================================================================
Overview
  • Skills.DB is a declarative database describing skill nodes:
      kinds: 'active', 'passive', 'modifier', 'transmuter', 'exclusive_aura'
      soft_cap / ult_cap with a diminishing-returns helper on scaling
      - 'modifier' / 'transmuter' wrap the base skill via spell_mutators
      - 'active' can be a Default Attack Replacer (DAR) and unlock WPS entries
  • SkillTree manages player-side state (ranks, DAR override, enabled transmuters)
      and applies/removes mutators and passive effects.
  • WPS (Weapon Pool Skills) resolves per-default-attack extra swings/effects.

Integration contracts (where other systems plug in)
  • Effects.*: damage/heal/RR/status builders executed by skill effects.
  • EventBus: skill cast/attack events can be listened to by traits/items/etc.
  • Stats: passives add to base/add_pct/mul_pct; recompute() updates derived stats.
  • Charges system: SkillTree expects Charges.add_track(e, node, ..., {rank=...})
      - That function should create & maintain e._charges[...] and return a handle
        with a .remove() method. (See "Charges" notes below.)
  • Exclusive auras: toggle_exclusive only flips the chosen id; applying the aura,
    reservation accounting, and conflict resolution should be handled by your
    aura/reservation engine (see notes under PossessionLike).

Notable behavior
  • Modifiers/Transmuters:
      - modifier nodes recompute and *replace* the mutator for their base skill
        whenever rank changes (clear + attach).
      - transmuters are exclusive per base; enable_transmuter clears and reattaches.
  • DAR (Default Attack Replacer):
      - setting rank>0 on is_dar nodes flags src.skills.dar_override = id.
      - WPS.handle_default_attack then uses that scale() function for the main hit,
        adds any "flat" modifier packet, applies cost/cd hooks, and rolls WPS.
  • WPS:
      - rolls once per default attack and picks a single entry weighted by chance.
      - uses Effects.deal_damage(...) to execute the WPS effect(s).

Safe rename suggestions (comments-only; do not change code now)
  • _dim_return        → diminishing_return (or softcap_curve)
  • Skills.DB          → Skills.Templates (or Skills.Catalog)
  • SkillTree          → Skills.Tree (or SkillTreeAPI)
  • SkillTree.set_rank → set_skill_rank
  • enabled_transmuter → active_transmuter_by_base
  • _apply_passive     → apply_passive_stats
  • _apply_modifier    → apply_modifier_mutator
  • _apply_transmuter  → apply_transmuter_mutator
  • _clear_passive     → clear_passive_stats (and implement actual reversal if needed)
  • WPS.collect_for(Skills) param name → skills_mod (to avoid shadowing global)
  • In ExplosiveStrike: local allies → rename to enemies (it holds enemies)
  • In WPS.handle_default_attack meta: "tag" → prefer "tags" (table) to align with
    Effects.deal_damage(p) which supports p.tags (plural)

Caveats / TODOs (if you want to extend later)
  • _clear_passive currently does not undo changes; if you plan to respec, either:
      - store inverse deltas (like ItemSystem does) and subtract them on clear, or
      - apply passives via a recompute hook (derived_add_*) and rely on recompute
        rather than permanent adds.
  • Exclusive auras (toggle_exclusive) only mark an id; to actually apply/remove:
      - have your aura system observe e.skills.toggled_exclusive and install/remove
        the right Effects.modify_stat entry (+ reservation) when it changes.
  • Charges.add_track is referenced but not defined in this file; ensure your
    Charges module implements:
      add_track(e, node, ..., {rank=rank}) -> { remove=function() ... end }
  • WPS dedupe uses a synthesized string key; if you expand meta, keep keys stable.

==============================================================================]]


-- SKILLS.lua
local Skills = {}

-- Design:
-- - Node kinds: 'active', 'passive', 'modifier', 'transmuter', 'exclusive_aura'
-- - Ranks with soft_cap and ultimate ranks beyond soft_cap with diminishing return curve
-- - Modifiers and transmuters *wrap* base skill using your existing spell_mutators channel
-- - Each skill can optionally be a default-attack replacer (DAR) and/or have WPS entries

-- Helper: linear interpolation.
-- Rename suggestion: _lerp → lerp
local function _lerp(a, b, t) return a + (b - a) * t end

-- Helper: diminishing-returns multiplier beyond a "knee".
--   x        : rank (or any scale input)
--   knee     : soft-cap threshold
--   min_mult : floor multiplier as x → ∞ (defaults around 0.5)
-- Notes: returns 1 up to the knee, then smoothly decays.
-- Rename suggestion: _dim_return → diminishing_return (or softcap_curve)
local function _dim_return(x, knee, min_mult)
  if x <= knee then return 1 end
  local over = x - knee
  return math.max(min_mult or 0.5, 1 / (1 + 0.15 * over))
end

-- Public DB
-- Structure:
--   Skills.DB[<Id>] = {
--     id, kind=('active'|'passive'|'modifier'|'transmuter'|'exclusive_aura'),
--     soft_cap, ult_cap,
--     -- active/DAR:
--     is_dar?, scale(rank)->{ knobs... }, wps_unlocks?, energy_cost?(rank), cooldown?(rank),
--     -- modifier/transmuter:
--     base=<IdOfBaseSkill>, apply_mutator(rank?)->wrap(orig)->fn,
--     -- passive:
--     apply_stats(S, rank),
--     -- exclusive aura:
--     reservation_pct, apply_aura(ctx, src, rank)->Effects.* builder
--   }
Skills.DB = {
  -- Example: Fire Strike-style default attack replacer
  FireStrike = {
    id = 'FireStrike',
    kind = 'active',
    is_dar = true,              -- marks this skill as the default attack replacer when ranked
    soft_cap = 12,              -- below this, scale() applies fully
    ult_cap = 26,               -- hard cap for set_rank clamping
    -- scaling function returns a table of scalar knobs used by the skill's build()
    --   Return knobs:
    --     flat_fire        : flat component (used as a follow-up packet)
    --     weapon_scale_pct : %WD to use for the main DAR hit
    scale       = function(rank)
      local m = _dim_return(rank, 12, 0.6)
      local flat = 6 + 2.5 * rank
      local wpn = 100 + 8 * rank
      return { flat_fire = flat * m, weapon_scale_pct = wpn * m }
    end,
    -- optional: add WPS unlocked while investing into this line
    --   wps_unlocks[wps_id] = { min_rank = N, chance = % } — WPS details in WPS.DB
    wps_unlocks = {                                  -- id => {chance, effects}
      AmarastasQuickCut = { min_rank = 4, chance = 20 }, -- details in WPS section
    },
    -- optional default attack on-cast cost/cd hooks (used by WPS.handle_default_attack)
    energy_cost = function(rank) return 0 end,
    cooldown    = function(rank) return 0 end,
  },

  -- Modifiers that *augment* FireStrike's output (applied as mutators)
  -- Behavior: wraps the base skill effects; runs original, then applies a splash.
  -- Rename suggestion: allies var below → enemies (holds enemies of src)
  ExplosiveStrike = {
    id = 'ExplosiveStrike',
    kind = 'modifier',
    base = 'FireStrike',
    soft_cap = 12,
    ult_cap = 22,
    apply_mutator = function(rank)
      local radius = 1.8 + 0.05 * rank   -- NOTE: radius is illustrative; not used in this stub
      local pct    = 30 + 3 * rank
      return function(orig)
        return function(ctx, src, tgt)
          -- 1) run original
          if orig then orig(ctx, src, tgt) end
          -- 2) splash to other enemies around target (engine should provide radius checks if needed)
          local allies = ctx.get_enemies_of(src)  -- rename suggestion: enemies
          for i = 1, #allies do
            local e = allies[i]
            if e ~= tgt then
              Effects.deal_damage {
                components = { { type = 'fire', amount = (src.stats:get('weapon_max') or 10) * (pct / 100) } }
              } (ctx, src, e)
            end
          end
        end
      end
    end
  },

  -- Transmuter: toggled variant that changes base damage type/behavior.
  -- Only one transmuter per base should be active at once (exclusive=true).
  -- Here it converts the "weapon" packet fully to fire, then optionally preserves orig secondary.
  SearingStrike = {
    id = 'SearingStrike',
    kind = 'transmuter',
    base = 'FireStrike',
    exclusive = true, -- only one transmuter of a base can be enabled at once
    apply_mutator = function()
      return function(orig)
        return function(ctx, src, tgt)
          -- Override "weapon -> all to fire" feel
          Effects.deal_damage {
            weapon = true, scale_pct = 100,
            skill_conversions = { { from = 'physical', to = 'fire', pct = 100 } }
          } (ctx, src, tgt)
          -- keep original secondary if desired:
          if orig then orig(ctx, src, tgt) end
        end
      end
    end
  },

  -- Passive example — permanent stat bonuses while ranked.
  -- NOTE: uses S:add_* (permanent deltas), not derived_add_*. If you plan respecs,
  -- implement _clear_passive or convert to derived hooks.
  FlameTouched = {
    id = 'FlameTouched',
    kind = 'passive',
    soft_cap = 12,
    ult_cap = 22,
    apply_stats = function(S, rank)
      S:add_add_pct('fire_modifier_pct', 6 + 1.5 * rank)
      S:add_base('offensive_ability', 6 + 2 * rank)
    end
  },

  -- Exclusive aura (mutually exclusive—only one can be toggled)
  -- Reservation handling and “exclusive” enforcement should be done by your aura system.
  -- apply_aura returns an Effects.* builder; installing/removing should be done when toggled.
  PossessionLike = {
    id = 'PossessionLike',
    kind = 'exclusive_aura',
    reservation_pct = 25, -- reserve 25% of max energy
    apply_aura = function(ctx, src, rank)
      return Effects.modify_stat { id = 'possess_aura', name = 'chaos_modifier_pct', add_pct_add = 8 + 2 * rank }
    end
  },

  -- passive with charge system
  -- Contract expected of Charges.add_track:
  --   - Installs/updates e._charges[id] with {stacks, max, decay, ...}
  --   - Applies derived effects via a hook or by calling S:recompute() in on_change
  --   - Returns handle { remove=function() ... } to fully clean up (marks/derived/etc.)
  Overheat = {
    id               = 'Overheat',
    kind             = 'passive',
    -- charge spec co-located with the skill
    charges          = {
      id = 'Heat',
      max = 10,
      decay = 2,
      derived = function(S, e, stacks)
        -- +2% fire damage per stack (demo)
        S:derived_add_add_pct('fire_modifier_pct', 2 * stacks)
      end,
      on_change = function(e, stacks)
        -- any side-effects (marks, visuals); then recompute
        e.stats:recompute()
      end,
      on_remove = function(e)
        -- cleanup if you added any out-of-band marks
      end
    }
    
  },
  -- alternate version which changes the charge spec based on rank of the spell
  -- NOTE: Shares the same id ('Overheat'); define only one in production.
  -- Rename suggestion: OverheatWithRank.id → 'OverheatWithRank' to avoid confusion.
    OverheatWithRank = { id = 'Overheat', kind = 'passive', 
      charges = function(rank) 
      rank = tonumber(rank) or 0            -- default if caller forgot
      return { id = 'Heat', max = 8 +
      math.floor(rank / 2), decay = 2, derived = function(S, e, s) S:derived_add_add_pct('fire_modifier_pct', 1.5 * s) end, on_change = function(
          e) e.stats:recompute() end } end }

}

-- Player state and manipulation
-- SkillTree holds per-entity skill progression and mutator/passive attachments.
local SkillTree = {}

--- Initialize per-entity skill state container.
-- Fields:
--   ranks               : map skillId -> current rank
--   enabled_transmuter  : map baseSkillId -> active transmuterId
--   toggled_exclusive   : currently toggled exclusive aura id (or nil)
--   dar_override        : current default attack replacer skill id (or nil)
--   _mutators           : bookkeeping { [baseId] = { mut1, mut2, ... } } for undo
--   _passive_marks      : bookkeeping for passives (start index into S._derived_marks)
function SkillTree.create_state()
  return {
    ranks = {},
    enabled_transmuter = {},
    toggled_exclusive = nil,
    dar_override = nil,
    _mutators = {},      -- { [sid] = {mut1, mut2, ...} } to undo later
    _passive_marks = {}, -- for removing passive stat adds
  }
end

-- Apply a passive's stats at a given rank.
-- Implementation note:
--   • Uses permanent adds (S:add_*). _passive_marks stores a marker, but removal
--     is not implemented in _clear_passive yet.
local function _apply_passive(e, id, rank, node)
  local S = e.stats; if not S then return end
  local before = { #S._derived_marks } -- mark start (if you later convert to derived adds)
  if node.apply_stats then node.apply_stats(S, rank) end
  e.skills._passive_marks[id] = { start = before[1] + 1 }
  S:recompute()
end

-- Placeholder for reversing passive application.
-- TODO (if respec supported):
--   • mirror ItemSystem's tracked deltas, or
--   • move passive effects to derived_add_* and clear via recompute().
local function _clear_passive(e, id)
  local mark = e.skills._passive_marks[id]; if not mark then return end
  -- we used permanent adds, so to remove we track via inverse application here:
  -- Simpler: recompute full Stats from base if you keep base copies. For now, ignore removal;
  -- typical flow only ever increases ranks. If you need removal, store diffs like ItemSystem does.
end

-- Attach a mutator wrapper to a base skill; records identity for removal.
local function _attach_mutator(e, base_id, wrap)
  e.spell_mutators = e.spell_mutators or {}
  local bucket = e.spell_mutators[base_id] or {}
  e.spell_mutators[base_id] = bucket
  local rec = { pr = 0, wrap = wrap }
  bucket[#bucket + 1] = rec
  e.skills._mutators[base_id] = e.skills._mutators[base_id] or {}
  table.insert(e.skills._mutators[base_id], rec)
end

-- Remove previously attached mutators for a base skill by identity.
local function _clear_mutators_for(e, base_id)
  if not (e.skills and e.skills._mutators and e.skills._mutators[base_id]) then return end
  local list = e.skills._mutators[base_id]
  local bucket = e.spell_mutators and e.spell_mutators[base_id]
  if bucket then
    for i = #bucket, 1, -1 do
      for j = #list, 1, -1 do
        if bucket[i] == list[j] then
          table.remove(bucket, i); table.remove(list, j); break
        end
      end
    end
    if #bucket == 0 then e.spell_mutators[base_id] = nil end
  end
end

-- Apply/refresh a modifier mutator for its base based on rank.
local function _apply_modifier(e, node, rank)
  if not node.base then return end
  _clear_mutators_for(e, node.base)
  local wrap = node.apply_mutator and node.apply_mutator(rank)
  if wrap then _attach_mutator(e, node.base, wrap) end
end

-- Apply/refresh a transmuter mutator for its base (rankless).
local function _apply_transmuter(e, node)
  if not node.base then return end
  _clear_mutators_for(e, node.base)
  local wrap = node.apply_mutator and node.apply_mutator()
  if wrap then _attach_mutator(e, node.base, wrap) end
end

-- Charges system placeholder (actual implementation expected elsewhere).
-- Rename suggestion: Charges → SkillCharges
local Charges = {}

--- Set (and clamp) rank for a skill id, and apply its side-effects.
-- Behavior:
--   • Clamps to [0, node.ult_cap].
--   • Applies passives (permanent adds) or modifiers (mutators).
--   • Updates dar_override if is_dar and rank>0.
--   • (Re)attaches charge tracks via Charges.add_track(..., {rank=rank}).
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
  
  -- if skill has a charge system, handle the rank change
  if node.charges then
    e.skills = e.skills or {}
    e.skills._charge_handles = e.skills._charge_handles or {}

    -- remove old handle if present
    local old = e.skills._charge_handles[id]
    if old then old.remove(); e.skills._charge_handles[id] = nil end

    -- (re)attach only if rank > 0
    if rank > 0 then
      e.skills._charge_handles[id] =
        Charges.add_track(e, node, nil, nil, nil, { rank = rank })
    end
  end

  -- WPS unlocks are handled in WPS module by checking current ranks
  return true
end

--- Enable a transmuter for its base skill (exclusive per base).
-- Notes:
--   • Records enabled_transmuter[base] = id for UI/state.
--   • Clears prior mutators for the base and attaches this transmuter’s wrap.
function SkillTree.enable_transmuter(e, id)
  local node = Skills.DB[id]; if not (node and node.kind == 'transmuter') then return false, 'not_transmuter' end
  e.skills.enabled_transmuter[node.base] = id
  _apply_transmuter(e, node)
  return true
end

--- Toggle an exclusive aura by id.
-- Notes:
--   • This only flips e.skills.toggled_exclusive; applying/removing the actual
--     aura effect and managing energy reservation should be handled by your aura engine.
function SkillTree.toggle_exclusive(e, id)
  local node = Skills.DB[id]; if not (node and node.kind == 'exclusive_aura') then return false, 'not_exclusive' end
  e.skills.toggled_exclusive = (e.skills.toggled_exclusive == id) and nil or id
  return true
end

Skills.SkillTree = SkillTree


-- WPS.lua
local WPS = {}

-- A WPS table: id -> { chance=%, effects = function(ctx, src, tgt) ... }
-- Effects function signature here is (ctx, src, tgt); if you later want to pass
-- metadata (reason/tags), consider extending it to (ctx, src, tgt, meta).
WPS.DB = {
  AmarastasQuickCut = {
    id = 'AmarastasQuickCut',
    chance = 20,
    effects = function(ctx, src, tgt)
      -- two rapid weapon strikes at reduced damage
      Effects.deal_damage { weapon = true, scale_pct = 70 } (ctx, src, tgt)
      Effects.deal_damage { weapon = true, scale_pct = 70 } (ctx, src, tgt)
    end
  },
  MarkoviansAdvantage = {
    id = 'MarkoviansAdvantage',
    chance = 10,
    effects = function(ctx, src, tgt)
      Effects.deal_damage { weapon = true, scale_pct = 180 } (ctx, src, tgt)
      Effects.apply_rr { kind = 'rr1', damage = 'physical', amount = 10, duration = 3 } (ctx, src, tgt)
    end
  },
}

-- WPS bucket resolution: roll once per default attack, pick a single WPS based on weights
-- Implementation: simple weighted roll; returns one entry or nil if total chance ≤ 0.
local function _roll(wps_list)
  local total = 0
  for i = 1, #wps_list do total = total + (wps_list[i].chance or 0) end
  if total <= 0 then return nil end
  local r = math.random() * total; local acc = 0
  for i = 1, #wps_list do
    acc = acc + (wps_list[i].chance or 0)
    if r <= acc then return wps_list[i] end
  end
end

--- Gather all WPS unlocked for an entity by scanning Skills.DB and comparing ranks.
-- Returns a flat list of { id, chance, effects } resolved from WPS.DB.
-- Rename suggestion: param Skills → skills_mod (to avoid shadowing global Skills)
function WPS.collect_for(e, Skills)
  local list = {}
  for id, node in pairs(Skills.DB) do
    if node.wps_unlocks then
      local r = e.skills and e.skills.ranks and e.skills.ranks[node.id] or 0
      for wps_id, spec in pairs(node.wps_unlocks) do
        if r >= (spec.min_rank or 1) then
          local base = WPS.DB[wps_id]
          if base then
            list[#list + 1] = { id = wps_id, chance = spec.chance or base.chance, effects = base.effects }
          end
        end
      end
    end
  end
  return list
end

--- Default Attack Replacer pipeline (called on OnDefaultAttack).
-- Behavior:
--   • If no DAR set: do a plain 100% WD swing.
--   • If DAR present: fetch node.scale(rank) for knobs (e.g., weapon_scale_pct, flat_fire),
--       - charge energy/cooldown if supplied by node hooks,
--       - perform the main %WD hit,
--       - optionally fire a flat component (e.g., flat_fire),
--   • Then roll WPS once and execute exactly one picked WPS entry.
-- Dedupe:
--   • A per-call "seen" map prevents accidental double-application of identical packets.
-- Metadata:
--   • deal(...) sets q.reason and q.tag from meta; Effects.deal_damage supports .reason and .tags.
--     Consider switching meta.tag → meta.tags (table) for richer categorization later.
function WPS.handle_default_attack(ctx, src, tgt, Skills)
  -- Local deduper for this single attack sequence
  local seen = {}
  local function deal(p, meta)
    -- shallow copy so we don't mutate shared tables
    local q = {}
    for k, v in pairs(p) do q[k] = v end
    meta      = meta or {}
    q.reason  = meta.reason or q.reason
    q.tag     = meta.tag or q.tag   -- NOTE: Effects.deal_damage uses .tags (plural). Here it's kept for dedupe/meta only.

    -- dedupe key (only for this function invocation)
    local key = meta.key or (tostring(q.reason) .. "|" .. tostring(q.tag) ..
      "|" .. (q.weapon and ("WD:" .. tostring(q.scale_pct or 100))
        or ("CMP:" .. (q.components and #q.components or 0))))
    if seen[key] then return end
    seen[key] = true

    Effects.deal_damage(q)(ctx, src, tgt)
  end

  local sid = src.skills and src.skills.dar_override
  if not sid then
    -- vanilla: just do a weapon swing
    deal({ weapon = true, scale_pct = 100 }, {
      reason = "weapon",
      tag    = "DefaultAttack",
      key    = "basic:main"
    })
  else
    -- build from skill’s scaling
    local node  = Skills.DB[sid]
    local r     = (src.skills.ranks and src.skills.ranks[sid]) or 1
    local knobs = node.scale and node.scale(r) or { weapon_scale_pct = 100 }

    -- energy/cd
    local cost  = node.energy_cost and node.energy_cost(r) or 0
    if cost > 0 then
      if (src.energy or 0) < cost then return end
      src.energy = src.energy - cost
    end
    local cd = node.cooldown and node.cooldown(r) or 0
    if cd > 0 then
      src.timers = src.timers or {}
      local key = 'dar:' .. sid
      if not ctx.time:is_ready(src.timers, key) then return end
      ctx.time:set_cooldown(src.timers, key, cd)
    end

    -- main hit (weapon replacer)
    deal({ weapon = true, scale_pct = knobs.weapon_scale_pct or 100 }, {
      reason = "weapon",
      tag    = sid, -- e.g., "FireStrike"
      key    = "dar:" .. sid .. ":main"
    })

    -- modifier packet (e.g., Explosive/Searing add-on) if present
    if knobs.flat_fire and knobs.flat_fire > 0 then
      deal({ components = { { type = 'fire', amount = knobs.flat_fire } } }, {
        reason = "modifier",
        tag    = (node.mod_tag or (sid .. ":flat_fire")), -- best-effort tag
        key    = "dar:" .. sid .. ":mod:fire"
      })
    end
  end

  -- Roll WPS (kept as-is; if your WPS effects support meta, pass it here)
  local wps_list = WPS.collect_for(src, Skills)
  if #wps_list > 0 then
    local pick = _roll(wps_list)
    if pick and pick.effects then
      -- If you extend WPS effects to accept meta:
      -- pick.effects(ctx, src, tgt, { reason = "wps", tags = { pick.id or pick.name } })
      pick.effects(ctx, src, tgt)
    end
  end
end


--[[============================================================================
AURAS.lua — Exclusive Auras & Energy Reservation (comments-only docs)
==============================================================================
Purpose
  Manage a single “exclusive aura” per entity by:
    • Applying its stat effect (via an Effects entry or builder)
    • Reserving a % of max energy while active
    • Cleaning up both when switched off

Key ideas
  • Reservation model: reduces e.max_energy while active and clamps e.energy.
  • The currently active exclusive aura is tracked at e._active_exclusive.
  • SkillTree sets e.skills.toggled_exclusive; this module reads it and installs
    the corresponding effect (while it’s toggled) or cleans up (when switched).

Integration expectations
  • node.apply_aura(ctx, e, rank) should return either:
      – a prebuilt entry table { id, apply(e), remove(e), ... }   OR
      – a runner function that exists as a key in Effects._entry_of,
        mapping to a builder function that returns the entry table.
  • Reservation numbers are stored in e._energy_reserved for UI/debugging
    (see util.dump_stats “Aura” snapshot).

Caveats & tips
  • Multiple exclusives: this implementation always clears the previous one
    before applying the new one (as designed).
  • If other systems also reserve energy (e.g., channeled skills), consider
    migrating e._energy_reserved into a small ledger/table so you can show
    per-source reservation lines and unreserve the right amounts on removal.
  • Renaming suggestions (comments only):
      _reserve        → reserve_energy_pct
      _unreserve_all  → clear_all_energy_reservations
      Auras.toggle_exclusive → Auras.sync_exclusive_from_tree (emphasizes it reads SkillTree)
==============================================================================]]

-- AURAS.lua
local Auras = {}

-- Tracks reservations: e._energy_reserved
-- Behavior:
--   • Calculates `need = maxE * pct/100` based on current max (stat-augmented).
--   • Increases cumulative e._energy_reserved by `need`.
--   • Reduces e.max_energy by the new cumulative reservation value.
--   • Clamps e.energy to not exceed the reduced max.
-- Note: If you have multiple independent reservations, consider tracking them
--       per-source and recomputing the new reserved sum to avoid small drift.
local function _reserve(e, pct)
  local maxE = e.max_energy or (e.stats and e.stats:get('energy')) or 0
  local need = maxE * (pct / 100)
  e._energy_reserved = (e._energy_reserved or 0) + need
  e.max_energy = math.max(0, maxE - e._energy_reserved)
  e.energy = math.min(e.energy or 0, e.max_energy)
end

-- Undo *all* reservations applied through this module.
-- Logic:
--   • Restores max to the stat-driven value (S:get('energy')) if available,
--     otherwise returns to previous max + reserved delta.
--   • Zeros the reservation accumulator.
-- Rename suggestion: _unreserve_all → clear_all_energy_reservations
local function _unreserve_all(e)
  if not e._energy_reserved or e._energy_reserved == 0 then return end
  local baseMax = e.stats and e.stats:get('energy') or (e.max_energy or 0) + e._energy_reserved
  e.max_energy = baseMax
  e._energy_reserved = 0
end

-- Toggle an exclusive aura from the skill tree
-- Contract:
--   • id must reference a Skills.DB entry of kind 'exclusive_aura'
--   • If e.skills.toggled_exclusive == id, aura will be applied; otherwise removed
--   • Supports both prebuilt entry tables and registered Effects builders
-- Side effects:
--   • e._active_exclusive set to { id, remove_fn, entry }
--   • Energy reservation applied/removed around the entry’s lifetime
-- Safety:
--   • If apply_aura returns nil, this is treated as a “no-op aura” (reserved off)
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
    local r   = (e.skills.ranks and e.skills.ranks[id]) or 1
    local eff = node.apply_aura and node.apply_aura(ctx, e, r)
    if not eff then return true end

    -- Normalize: accept either a prebuilt entry table, or a runner mapped in Effects._entry_of
    local entry
    if type(eff) == "table" then
      entry = eff
    elseif type(eff) == "function" and Effects._entry_of and Effects._entry_of[eff] then
      entry = Effects._entry_of[eff](ctx, { exclusive = true })
    else
      return false, "bad_aura_entry"
    end

    -- Force “exclusive” lifetime semantics: stays while toggled on
    entry.id         = 'exclusive:' .. id
    entry.until_time = nil -- exclusives stay while toggled
    entry.stack      = nil
    entry.extend_by  = 0

    if entry.apply then entry.apply(e) end
    if node.reservation_pct and node.reservation_pct > 0 then _reserve(e, node.reservation_pct) end

    local function remove_now(ent)
      if entry.remove then entry.remove(ent) end
    end
    e._active_exclusive = { id = id, remove_fn = remove_now, entry = entry }
  end
  return true
end

-- ============================


--[[============================================================================
DEVOTION.lua — Lightweight Proc System (comments-only docs)
==============================================================================
Purpose
  Per-entity attachment of proc specs that can trigger on EventBus events,
  with chance and internal cooldown (ICD) control.

Spec shape
  spec = {
    id        = <string>,                  -- unique per entity
    trigger   = <eventName>,               -- e.g. 'OnHitResolved'
    chance    = <number 0..100>,           -- probability per eligible event
    icd       = <seconds>,                 -- internal cooldown
    filter    = function(ev)->bool,        -- quick filter on the event payload
    condition = function(ctx, ev, e)->bool,-- optional ctx-aware condition
    effects   = function(ctx, src, tgt, ev) -- effect runner; ev is forwarded
  }

Runtime / Flow
  • Call Devotion.attach(entity, spec) once to register.
  • On each bus event, call Devotion.handle_event(ctx, evname, ev).
    It attempts to fire for both ev.source and ev.target (when present).

Notes & Suggestions
  • Rename suggestions:
      Devotion.attach     → Devotion.attach_proc
      _try_fire           → try_fire_proc
      Devotion.handle_event → handle_proc_event
  • Consider adding a 'tags' field to spec for later analytics/telemetry.
  • If you need per-spec priorities, support spec.pr and sort when evaluating.
==============================================================================]]

-- DEVOTION.lua
local Devotion = {}

-- proc spec: { id, trigger, chance, icd, filter(ev)->bool, effects(ctx, source, target) }
function Devotion.attach(e, spec)
  e._devotion = e._devotion or {}
  e._devotion[spec.id] = { spec = spec, next_ok = 0 }
end

-- Try to fire a single proc record based on event + cooldown.
-- Order:
--   1) ICD gate (next_ok vs now)
--   2) filter(ev) and condition(ctx, ev, e)
--   3) chance roll
--   4) choose src/tgt (defaulting to event or self)
--   5) run effects and set next_ok = now + icd
local function _try_fire(ctx, e, ev, rec)
  local now = ctx.time.now
  if now < (rec.next_ok or 0) then return end
  local spec = rec.spec
  if spec.filter and not spec.filter(ev) then return end
  if spec.condition and not spec.condition(ctx, ev, e) then return end
  if math.random() * 100 > (spec.chance or 100) then return end
  local src = ev.source or e
  local tgt = ev.target or e
  spec.effects(ctx, src, tgt, ev)      -- pass ev
  rec.next_ok = now + (spec.icd or 0)
end

-- Router: check both ev.source and ev.target for attached devotions.
-- Assumes caller wires this to EventBus listeners:
--   bus:on(name, function(ev) Devotion.handle_event(ctx, name, ev) end)
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

--[[============================================================================
SYSTEMS.lua — Charges (stacking buffs with decay) (comments-only docs)
==============================================================================
Goal
  Provide a robust, flexible “charges”/“stacks” system that:
    • Accepts multiple configuration shapes (string id, skill node with .charges,
      or a flat spec table with aliases)
    • Tracks max stacks, per-second decay, and optional derived stat effects
    • Exposes a simple handle with .remove() so call sites can easily detach

Spec normalization
  _normalize_spec(...) returns a validated spec table:
    {
      id        : string                 -- charge bucket id (unique per entity)
      max       : number                 -- maximum stacks
      decay     : number                 -- stacks/second decay rate (0 disables decay)
      on_change : function(e, stacks)    -- called after stack changes (user can S:recompute())
      on_remove : function(e)            -- called when the track is removed
      derived   : function(S, e, stacks) -- derive stat effects (applied during recompute pass)
    }

Usage pattern (expected from the rest of your codebase)
  local h = Charges.add_track(e, skillNodeOrSpec, nil, nil, nil, { rank = someRank })
  -- h should expose: h.remove() to clear state and reverse any out-of-band effects.

Integration points
  • Apply derived effects by registering a recompute hook that reads e._charges[id]
    and calls spec.derived(S, e, stacks). Clear that hook inside h.remove().
  • Decay: schedule periodic ticks (with Time or an update loop) to reduce stacks
    toward 0 by (decay * dt), calling on_change per update.
  • Events: you might expose helpers to add stacks on hit/kill/etc.

Rename suggestions
  • Systems → Systems or ChargesSystem (clearer ownership)
  • _fail   → charges_fail or raise
  • _validate_spec → validate_charge_spec
  • _normalize_spec → normalize_charge_spec
==============================================================================]]

-- SYSTEMS.lua
local Systems = {}

-- Charges (e.g., Savagery): stack on hit, decay over time, modifies stats
-- Replace your current Charges with this upgraded version
local function _fail(msg) error("Charges.add_track: "..msg) end

-- Validate core spec fields; also normalizes numeric fields.
-- Throws via _fail on bad input so upstream callers can catch.
local function _validate_spec(spec)
  if type(spec) ~= "table" then _fail("spec is not a table") end
  if type(spec.id) ~= "string" or spec.id == "" then _fail("spec.id missing") end
  spec.max   = tonumber(spec.max   or 0) or 0
  spec.decay = tonumber(spec.decay or 0) or 0
  return spec
end

-- Normalize inputs into a validated spec table.
-- Accepted formats:
--   (A) Legacy:     ("Heat", 10, 2, on_change)
--   (B) Skill node: { id='SomeSkill', charges = { ... } } or charges = function(rank, e, opts) -> spec
--   (C) Flat spec:  { id, max, decay, on_change, on_remove, derived } with alias support
-- Notes:
--   • If the skill's .charges is a function, it’s invoked with (rank, e, opts)
--     and should return a flat spec table. Errors are surfaced via _fail.
--   • Id fallback: for skill nodes without an explicit charges.id, we derive one
--     as "<skill_id>:charges" to avoid collisions.
local function _normalize_spec(e, what, max_stacks, decay_per_sec, on_change, opts)
  opts = opts or {}

  -- Legacy signature: ("Heat", 10, 2, on_change)
  if type(what) == "string" then
    return _validate_spec{
      id = what, max = max_stacks or 0, decay = decay_per_sec or 0, on_change = on_change
    }
  end

  local skill_id = (type(what) == "table" and what.id) or nil

  -- Skill node with .charges (table | function)
  if type(what) == "table" and what.charges then
    local c = what.charges
    if type(c) == "function" then
      local r = (opts and opts.rank) or 0   -- ← default rank if not provided
      local ok, res = pcall(c, r, e, opts)
      if not ok then
        _fail(("charges() for skill '%s' threw: %s"):format(tostring(skill_id or "?"), tostring(res)))
      end
      what = res
    else
      what = c
    end
  end

  -- Flat spec table (support aliases + fallback id)
  if type(what) == "table" then
    local id = what.id or what.charge_id or what.name
              or (skill_id and (tostring(skill_id)..":charges"))  -- ← fallback
    local m  = what.max or what.max_stacks or what.stacks_max or what.limit or what.cap
    local d  = what.decay or what.decay_per_sec or what.decay_rate or what.per_sec
    return _validate_spec{
      id        = id,
      max       = m,
      decay     = d,
      on_change = what.on_change,
      on_remove = what.on_remove,
      derived   = what.derived or what.apply_derived,
    }
  end

  _fail("unsupported spec format: "..tostring(type(what)))
end




--[[============================================================================
CHARGES / CHANNEL / SYSTEMS / PETS & SETS — Developer Notes (comments only)
==============================================================================
This section wires together:
  • Charges: stackable, decaying “buff counters” per-entity with optional
             derived stat hooks and change/remove callbacks.
  • Channel: simple periodic effect runner that drains energy while active.
  • Systems.update: glue tick that advances Charges & Channel across two sides.
  • Pets & Sets: helper to spawn pets and recompute item set bonuses.

Core design principles
  • Non-invasive: derived stat effects are attached via Stats:on_recompute hooks
    and are removed cleanly by stored unsubscribe handles.
  • Shape-flexible configs: Charges accepts multiple signature styles, including
    skill nodes that provide rank-aware charge specs.
  • Separation of responsibilities:
      - Charges only stores counters & invokes callbacks; it does not apply
        stat effects on its own unless a `derived(S,e,stacks)` hook is provided.
      - Channel manages periodic ticks and energy drain; it does not schedule
        itself—caller must call Channel.update each frame/tick via Systems.update.

Gotchas
  • Floating stacks: Charges.update decays with real numbers; if you want integer
    stacks, round in `on_change` or clamp in gameplay reads.
  • Multiple reservations (from Auras & Channel): this module doesn’t reserve
    energy; it directly subtracts energy each tick. If you mix with aura
    reservations, keep UI clear: one reduces max capacity, the other consumes.
  • Pet inheritance: spawn_pet inherits “all_damage_pct” multiplicatively via
    a simple multiplier. Tune `inherit_damage_mult` on spec for balance.

Rename suggestions (comments only; code remains unchanged)
  • Charges.add_track         → Charges.track or Charges.add
  • Charges.remove_track      → Charges.untrack or Charges.remove
  • Charges.on_hit            → Charges.add_stacks or Charges.gain
  • Channel.start             → Channel.begin or Channel.start_drain
  • Channel.update            → Channel.tick
  • Systems.update.step       → tick_entities (local helper name)
  • PetsAndSets.spawn_pet     → PetsAndSets.spawn or PetsAndSets.spawn_minion
==============================================================================]]


-- spec form accepted:
-- 1) ("Heat", max, decay, on_change)
-- 2) { id, max, decay, on_change?, derived?(S,e,stacks), on_remove? }
-- 3) skillNode where skillNode.charges is (table | function(rank,e,opts)->spec)
-- Notes:
--   • `derived` is applied during Stats:recompute, not continuously; callers should
--     trigger recompute when they care (e.g., in on_change or periodically).
--   • `on_change(e, stacks)` is invoked on creation (with stacks=0) and any time
--     stacks change due to add/set/decay. Use it to refresh UI or recompute stats.
--   • `on_remove(e)` should undo any out-of-band effects you added in on_change.
--   • `opts.rank` can be passed so that skill-provided charge specs can scale.
function Charges.add_track(e, spec_or_skill, max_stacks, decay_per_sec, on_change, opts)
  e._charges = e._charges or {}
  local spec = _normalize_spec(e, spec_or_skill, max_stacks, decay_per_sec, on_change, opts)
  assert(spec and spec.id, "Charges.add_track: spec.id required")

  -- de-dupe
  if e._charges[spec.id] then Charges.remove_track(e, spec.id) end

  local rec = {
    stacks = 0,             -- float-friendly: decay can be fractional
    max = spec.max or 0,    -- hard cap (util.clamp applied in set)
    decay = spec.decay or 0,-- per-second decay rate; 0 disables decay
    on_change = spec.on_change,
    on_remove = spec.on_remove
  }
  e._charges[spec.id] = rec

  -- optional derived hook
  -- Installs a recompute hook that asks the current stacks at recompute time
  -- and calls spec.derived(S, e, stacks) to inject derived stats (using the
  -- provided S:derived_add_* helpers). Unsub handle is stored for removal.
  if spec.derived and e.stats and e.stats.on_recompute then
    local hook = function(S)
      local c = e._charges and e._charges[spec.id]; if not c then return end
      local s = c.stacks or 0
      if s > 0 then spec.derived(S, e, s) end
    end
    -- Try unsubscribe path; fall back to manual removal
    local unsub = e.stats:on_recompute(hook)
    rec._unsub, rec._hook, rec._stats = unsub, hook, e.stats
  end

  if rec.on_change then rec.on_change(e, rec.stacks) end -- initial callback (stacks=0)

  -- handle for easy removal (pattern: local h = Charges.add_track(...); h.remove())
  return { remove = function() Charges.remove_track(e, spec.id) end }
end

-- Removes the track, unsubscribes derived hooks, calls on_remove, and recomputes stats.
-- Safe to call multiple times; silently returns if not present.
function Charges.remove_track(e, id)
  local c = e._charges and e._charges[id]; if not c then return end

  if c._unsub then
    c._unsub()
  elseif c._hook and c._stats and c._stats.derived_hooks then
    local hooks = c._stats.derived_hooks
    for i = #hooks, 1, -1 do
      if hooks[i] == c._hook then
        table.remove(hooks, i); break
      end
    end
  end

  if c.on_remove then c.on_remove(e) end
  e._charges[id] = nil
  if e.stats and e.stats.recompute then e.stats:recompute() end
end

-- Increment stacks (default +1) with cap at `max`. Triggers on_change when changed.
-- Typical call site: on hit/crit/kill events, based on skill logic.
function Charges.on_hit(e, id, add)
  local c = e._charges and e._charges[id]; if not c then return end
  local before = c.stacks or 0
  c.stacks = math.min(c.max, before + (add or 1))
  if c.on_change and c.stacks ~= before then c.on_change(e, c.stacks) end
end

-- Force stacks to a specific value (clamped [0, max]). Triggers on_change if changed.
-- Useful for UI-driven respecs or scripted effects that set exact stack counts.
function Charges.set(e, id, stacks)
  local c = e._charges and e._charges[id]; if not c then return end
  local before = c.stacks or 0
  c.stacks = util.clamp(stacks or 0, 0, c.max or 0)
  if c.on_change and c.stacks ~= before then c.on_change(e, c.stacks) end
end

-- Per-tick decay for all charge tracks on an entity. Called from Systems.update.
-- Decay math: stacks = max(0, stacks - decay * dt)
-- Note: This keeps fractional stacks; round in on_change if you require integers.
function Charges.update(e, dt)
  if not e._charges then return end
  for _, c in pairs(e._charges) do
    if (c.decay or 0) > 0 then
      local before = c.stacks or 0
      c.stacks = math.max(0, before - c.decay * dt)
      if c.on_change and c.stacks ~= before then c.on_change(e, c.stacks) end
    end
  end
end

--[[----------------------------------------------------------------------------
CHANNEL — Periodic actions with energy drain (simple channeled effects)
Design:
  • Channel.start installs a record on e._channel keyed by `id`.
  • Each update:
      - Consumes `drain_per_sec * dt` energy; stops if insufficient.
      - If `now >= next`, runs tick(ctx, e) and schedules next = now + period.
Usage patterns:
  • Channeled auras, beam spells, toggled toggles: pair with UI on/off.
  • Combine with Auras reservation if you want upfront capacity reduction and
    runtime drain; this module only handles the runtime drain.

Rename suggestions:
  • Channel.start → Channel.begin / Channel.start_drain
  • Channel.stop  → Channel.end / Channel.stop_drain
----------------------------------------------------------------------------]]--
-- Channeling registry: drains energy while active; run a tick effect
local Channel = {}
function Channel.start(ctx, e, id, drain_per_sec, tick, period)
  e._channel = e._channel or {}
  e._channel[id] = { drain = drain_per_sec, tick = tick, period = period or 0.5, next = ctx.time.now }
end

function Channel.stop(e, id) if e._channel then e._channel[id] = nil end end

-- Called each frame/tick. If energy insufficient to pay this frame’s cost, the
-- channel is stopped silently. Consider emitting an event if you want UX feedback.
function Channel.update(ctx, e, dt)
  if not e._channel then return end
  for id, c in pairs(e._channel) do
    local need = c.drain * dt
    if (e.energy or 0) < need then
      e._channel[id] = nil
    else
      e.energy = e.energy - need
      if ctx.time.now >= (c.next or 0) then
        if c.tick then c.tick(ctx, e) end
        c.next = ctx.time.now + c.period
      end
    end
  end
end

-- Glue update
-- Processes both sides’ rosters (ctx.side1/ctx.side2) and advances Charges & Channel.
-- Assumptions:
--   • ctx.side1 / ctx.side2 are arrays of entities participating in combat.
--   • Caller drives Systems.update(dt) from the main loop.
-- Potential extension:
--   • Add ctx.neutrals or ctx.parties to generalize beyond two sides.
--   • Early-out skip for dead entities or non-combatants if desired.
function Systems.update(ctx, dt)
  local function step(list)
    for i = 1, #list do
      local e = list[i]
      Charges.update(e, dt)
      Channel.update(ctx, e, dt)
    end
  end
  step(ctx.side1 or {}); step(ctx.side2 or {})
end

Systems.Charges = Charges
Systems.Channel = Channel


--[[============================================================================
PETS_AND_SETS — Pets helpers & item set bonus recomputation (comments only)
==============================================================================
Pets
  • spawn_pet(ctx, owner, spec) constructs a pet using a provided/known factory:
      ctor(name, defs, attach_attribute_derivations) -> entity
    Then:
      - sets ownership & side
      - inherits a fraction of owner’s all_damage_pct (linear add_pct scaling)
      - recomputes stats and inserts into the owner’s side roster

  Spec knobs (informal):
    spec.name                — display name
    spec.inherit_damage_mult — fraction [0..1] of owner’s all_damage_pct to grant (default 0.6)

Sets
  • recompute_sets(ctx, e) rebuilds set piece counts from e.equipped and
    applies “best tier” bonus for each present set_id.
  • Each bonus may:
      - return “undo” info via bonus.effects(ctx, e) → stored as bonus._applied (optional)
      - install mutators (tracked in bonus._muts) for cleanup

Notes
  • To fully undo stat effects in _remove_set_bonus, have bonus.effects return
    inverse records (like ItemSystem does) or a cleanup function and invoke it here.
  • When items are equipped/unequipped, call PetsAndSets.recompute_sets to keep
    set bonuses in sync (the ItemSystem.unequip already calls this).
==============================================================================]]

local function add_to_side(ctx, ent, side)
  local roster = (side == 1) and ctx.side1 or ctx.side2
  roster[#roster+1] = ent
end

-- Simple pet spawner: you plug your entity factory here
-- Contract:
--   • ctor(name, defs, attach) must return a usable actor/entity object
--   • defs  should be a stat definition table (from StatDef.make)
--   • attach should install attribute derivations (e.g., Content.attach_attribute_derivations)
-- Ownership & inheritance:
--   • Pet gets owner’s side and owner reference.
--   • Pet inherits a fraction of owner’s all_damage_pct via add_pct (linear).
-- Balance guidance:
--   • Consider capping inherited % to avoid extreme scaling from late-game buffs.
function PetsAndSets.spawn_pet(ctx, owner, spec)
  spec = spec or {}
  local ctor   = owner._make_actor or ctx._make_actor or make_actor
  local defs   = owner._defs       or ctx._defs
  local attach = owner._attach     or ctx._attach     or Content.attach_attribute_derivations

  assert(type(ctor)   == "function", "spawn_pet: missing actor constructor")
  assert(type(defs)   == "table",    "spawn_pet: missing stat defs")
  assert(type(attach) == "function", "spawn_pet: missing attach function")

  local pet = ctor(spec.name or "Pet", defs, attach)
  pet.side, pet.owner = owner.side, owner

  -- inherit portion of owner's all_damage_pct
  local owner_all = (owner.stats and owner.stats:get("all_damage_pct")) or 0
  local mult = (spec.inherit_damage_mult ~= nil) and spec.inherit_damage_mult or 0.6
  if owner_all ~= 0 and mult ~= 0 then
    pet.stats:add_add_pct("all_damage_pct", owner_all * mult)
  end
  pet.stats:recompute()

  add_to_side(ctx, pet, owner.side)  -- <-- explicit, no ambiguity
  return pet
end



-- Item sets
-- _apply_set_bonus installs effects and mutators; it stores references for later removal.
-- Expectation:
--   bonus.effects(ctx, e) may return a cleanup function or records (optional).
--   bonus.mutators is a map sid -> wrap(orig)->fn; these are inserted with pr=0.
local function _apply_set_bonus(ctx, e, bonus)
  if bonus.effects then
    bonus._applied = bonus.effects(ctx, e) -- return undo fn or applied records (optional)
  end
  if bonus.mutators then
    for sid, wrap in pairs(bonus.mutators) do
      e.spell_mutators = e.spell_mutators or {}
      local bucket = e.spell_mutators[sid] or {}; e.spell_mutators[sid] = bucket
      local rec = { pr = 0, wrap = wrap }; table.insert(bucket, rec)
      bonus._muts = bonus._muts or {}; table.insert(bonus._muts, { sid = sid, ref = rec })
    end
  end
end

-- _remove_set_bonus undoes mutators and (optionally) stat effects if records exist.
-- Enhancement idea:
--   • If bonus._applied is a function, pcall it here for cleanup symmetry.
local function _remove_set_bonus(e, bonus)
  if bonus._muts and e.spell_mutators then
    for i = #bonus._muts, 1, -1 do
      local m = bonus._muts[i]; local b = e.spell_mutators[m.sid]
      if b then
        for j = #b, 1, -1 do if b[j] == m.ref then
            table.remove(b, j)
            break
          end end
        if #b == 0 then e.spell_mutators[m.sid] = nil end
      end
    end
  end
  bonus._muts = nil
  -- undo stat effects if you returned records
end

-- Recompute best set-bonus tier per set_id based on current equipment.
-- Strategy:
--   • Count pieces per set_id.
--   • Find highest `pieces` threshold met in Content.Sets[set_id].bonuses[].
--   • If best tier differs from current, remove current and apply best.
-- Side effects:
--   • e._active_sets[set_id] = active bonus spec (or nil if no tier met)
function PetsAndSets.recompute_sets(ctx, e)
  -- build counts
  local cnt = {}
  for slot, it in pairs(e.equipped or {}) do
    if it.set_id then cnt[it.set_id] = (cnt[it.set_id] or 0) + 1 end
  end
  -- walk all sets present, apply best tier
  e._active_sets = e._active_sets or {}
  for set_id, pieces in pairs(cnt) do
    local spec = Content.Sets and Content.Sets[set_id]
    if spec then
      local best = nil
      for i = 1, #spec.bonuses do
        local b = spec.bonuses[i]
        if pieces >= b.pieces then best = b end
      end
      local cur = e._active_sets[set_id]
      if cur ~= best then
        if cur then _remove_set_bonus(e, cur) end
        e._active_sets[set_id] = best
        if best then _apply_set_bonus(ctx, e, best) end
      end
    end
  end
end






-- ============================================================================
-- Status engine + world tick
-- StatusEngine.update_entity:
--   - Expires timed buffs (calls entry.remove if present, emits 'OnStatusExpired')
--   - Ticks DoTs: on each tick, deals dps as instantaneous damage
-- World.update:
--   - Ticks global time, updates all entities on both sides, emits 'OnTick'
-- ----------------------------------------------------------------------------
-- Rename suggestion (comment only): 
--   • StatusEngine.update_entity -> StatusEngine.tick_entity (clearer “per-entity tick”)
--   • World.update               -> World.tick
--   • e (entity param)           -> ent (or actor) for readability
--   • dt                         -> delta or dt_sec
--   • kept                       -> remaining (within local scopes)
--   • b (status bucket)          -> status_bucket
--   • d (dot entry)              -> dot_entry
--   • r (rr entry)               -> rr_entry
-- ============================================================================
StatusEngine.update_entity = function(ctx, e, dt)
  -- Expire timed buffs --------------------------------------------------------
  -- Every status is stored as e.statuses[id] = { entries = { <entry...> } }.
  -- We rebuild the list by keeping entries whose .until_time is nil (permanent)
  -- or still in the future. Expired entries call entry.remove(e) if present,
  -- then we emit 'OnStatusExpired' for observers (UI, logs, gameplay).
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
  -- Active resistance-reduction entries live under e.active_rr[type] = { list }.
  -- We prune expired entries similarly to statuses (nil until_time means permanent).
  if e.active_rr then
    for t, bucket in pairs(e.active_rr) do
      local kept = {}
      for i = 1, #bucket do
        local r = bucket[i]
        if (not r.until_time) or r.until_time > ctx.time.now then kept[#kept + 1] = r end
      end
      e.active_rr[t] = kept
    end
  end

  -- Tick DoTs -----------------------------------------------------------------
  -- DoT model: each dot stores dps, tick interval, and next_tick time.
  -- On each tick we apply “instant damage” via Effects.deal_damage using the
  -- saved `source` (attacker) and current target `e`, letting the full damage
  -- pipeline handle resists, armor, DR, block, absorbs, etc.
  -- Note: This can trigger retaliation and other “OnHitResolved” listeners.
  --       Be mindful of potential proc loops if your retaliations add more DoTs.
  if e.dots then
    local kept = {}
    for _, d in ipairs(e.dots) do
      if d.until_time and d.until_time <= ctx.time.now then
        ctx.bus:emit('OnDotExpired', { entity = e, dot = d })
      else
        if ctx.time.now >= (d.next_tick or ctx.time.now) then
          local tick = d.tick or 1.0
          Effects.deal_damage { components = { { type = d.type, amount = (d.dps or 0) * tick } } } (ctx, d.source, e)
          d.next_tick = (d.next_tick or ctx.time.now) + (d.tick or 1.0)
        end
        kept[#kept + 1] = d
      end
    end
    e.dots = kept
  end
end

World.update = function(ctx, dt)
  -- Advance the shared clock first so all time-based checks compare against
  -- the post-tick timestamp (e.g., status expiry, next_tick scheduling, cooldowns).
  ctx.time:tick(dt)

  -- Per-entity regeneration & energy capacity pass.
  -- This runs after StatusEngine.update_entity so freshly expired statuses
  -- don’t contribute regen/bonuses this frame.
  local function regen(ent)
    if not ent.stats then return end

    -- HP
    -- hp is clamped between 0 and max_health (which defaults to Stats 'health').
    local maxhp = ent.max_health or ent.stats:get('health')
    local hpr   = ent.stats:get('health_regen') or 0
    if hpr ~= 0 then
      ent.hp = util.clamp((ent.hp or maxhp) + hpr * dt, 0, maxhp)
    end

    -- ENERGY (recompute every tick so spirit/items/buffs/aura reservations reflect)
    -- Effective max energy = base from stats, minus any absolute reservation,
    -- then apply percent reservation if present. This ensures auras (which
    -- reserve capacity) and channels (which subtract current energy) coexist.
    local baseMaxE = ent.stats:get('energy') or 0
    local reservedAbs = ent._energy_reserved or 0
    -- If you later add percent reservations, subtract them here too:
    local reservedPct = ent._reserved_pct or 0
    local effMaxE = math.max(0, baseMaxE * (1 - reservedPct / 100) - reservedAbs)

    -- First-time init / clamp if caps moved
    if ent.max_energy == nil then ent.max_energy = effMaxE end
    ent.max_energy = effMaxE
    if ent.energy == nil then ent.energy = effMaxE end
    if ent.energy > ent.max_energy then ent.energy = ent.max_energy end

    -- Regen
    local epr = ent.stats:get('energy_regen') or 0
    if epr ~= 0 then
      ent.energy = util.clamp(ent.energy + epr * dt, 0, ent.max_energy)
    end
  end

  -- Process both sides: expiry → DoT tick (via StatusEngine) → regen.
  -- Rename suggestion: each -> tick_side
  local function each(L)
    for _, ent in ipairs(L or {}) do
      StatusEngine.update_entity(ctx, ent, dt)
      regen(ent)
    end
  end

  each(ctx.side1)
  each(ctx.side2)

  -- Systems glue tick (Charges decay, Channel drains & ticks).
  -- Runs after per-entity status & regen so stacks/energy reflect the latest.
  Systems.update(ctx, dt)

  -- Global heartbeat for UI/schedulers/AI: use this to time animations, etc.
  ctx.bus:emit('OnTick', { dt = dt, now = ctx.time.now })
end


-- ============================================================================
-- Demo
-- Provides a runnable demonstration of the system:
--   - Creates hero + ogre actors with stats
--   - Hooks up EventBus listeners to print combat logs
--   - Executes: basic attack, EmberStrike chance, Fireball, Poison Dart with DoT ticks
--   - Demonstrates a custom trigger ("OnProvoke") causing counter-attack
-- ----------------------------------------------------------------------------
-- Rename suggestions:
--   • make_actor -> new_actor or spawn_actor (factory naming)
--   • Demo.run   -> Demo.run_scenario or Demo.playthrough
--   • ctx.debug  -> ctx.dev_debug (if you later add player-facing debug)
--   • combat     -> core (created but not used in this demo)
--   • FB/PD locals -> fireball / poison_dart (expanded names)
--   • FlamebandPlus -> FlamebrandPlus (typo?)  -- keeping as-is by request
-- ============================================================================
local function make_actor(name, defs, attach)
  -- Creates a fresh Stats instance, applies attribute derivations via `attach`,
  -- and snapshots initial HP/Energy as both current and max. The actor also
  -- carries helpers for pet creation (so PetsAndSets.spawn_pet can reuse them).
  local s = Stats.new(defs)
  attach(s)
  s:recompute()
  local hp = s:get('health')
  local en = s:get('energy')

  return {
    name             = name,
    stats            = s,
    hp               = hp,
    max_health       = hp,
    energy           = en,
    max_energy       = en,
    gear_conversions = {},
    tags             = {},
    timers           = {},

    -- add these so spawn_pet can reuse them
    _defs            = defs,
    _attach          = attach,
    _make_actor      = make_actor,
  }
end



-- ================================

local Demo = {}

function Demo.run()
  math.randomseed(os.time())

  -- Core context --------------------------------------------------------------
  local bus       = EventBus.new()
  local time      = Time.new()
  local defs, DTS = StatDef.make()
  local combat    = Combat.new(RR, DTS) -- NOTE: available as ctx.combat if you want later use

  -- After creating bus, hook devotions
  -- Subscriptions capture the upvalue 'ctx' which is defined a bit later; this
  -- is OK in Lua because the function body resolves the upvalue at call-time.
  for _, evn in ipairs({ 'OnHitResolved', 'OnBasicAttack', 'OnCrit', 'OnDeath', 'OnDodge' }) do
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
  ]] --

  local ctx = {
    _make_actor    = make_actor, -- Factory for creating actors
    debug          = true,    -- Set to true for verbose debug output
    bus            = bus,
    time           = time,
    combat         = combat,

    -- Side-aware accessors (hero is side1, ogre is side2).
    get_enemies_of = function(a) return a.side == 1 and ctx.side2 or ctx.side1 end,
    get_allies_of  = function(a) return a.side == 1 and ctx.side1 or ctx.side2 end,
  }

  -- Create actors -------------------------------------------------------------
  -- Hero: balanced early-game stats with some lifesteal and weapon damage.
  local hero = make_actor('Hero', defs, Content.attach_attribute_derivations)
  hero.side = 1
  hero.level_curve = 'fast_start' -- Example curve, default curve used otherwise
  hero.stats:add_base('physique', 16)
  hero.stats:add_base('cunning', 14)
  hero.stats:add_base('spirit', 10)
  hero.stats:add_base('weapon_min', 12)
  hero.stats:add_base('weapon_max', 18)
  hero.stats:add_base('life_steal_pct', 12)
  
  -- give high value to allow hits
  hero.stats:add_base('offensive_ability', 100)
  hero.stats:recompute()

  -- Ogre: tougher target with armor, DA, and fire resistance.
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
  -- Minimal combat log for hits, heals, DoT application, counters, RR, and misses.
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
  -- 1. Basic attack (vanilla weapon hit)
  Effects.deal_damage { weapon = true, scale_pct = 100 } (ctx, hero, ogre)

  --    Ember Strike proc chance (one-shot demonstration outside of full WPS flow)
  if util.rand() * 100.0 < (Content.Traits.EmberStrike.chance or 0) then
    Content.Traits.EmberStrike.effects(ctx, hero, ogre)
  end

  util.dump_stats(ogre, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

  -- 2. Cast Fireball (direct call to spell.effects; Cast.cast demo appears later)
  local FB = Content.Spells.Fireball
  for _, t in ipairs(FB.targeter({ source = hero, target = ogre, get_enemies_of = ctx.get_enemies_of })) do
    FB.effects(ctx, hero, t)
  end

  util.dump_stats(ogre, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

  -- 3. Cast Poison Dart and tick DoTs
  local PD = Content.Spells.PoisonDart
  for _, t in ipairs(PD.targeter({ source = hero, target = ogre, get_enemies_of = ctx.get_enemies_of })) do
    PD.effects(ctx, hero, t)
  end
  for i = 1, 6 do
    World.update(ctx, 1.0)
  end

  -- check that ogre RR from fireball has disappeared
  -- Fireball RR duration = 4s; simulated 6s ticks, so it should be gone.
  util.dump_stats(ogre, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

  -- 4. Custom trigger: provoke (forces counter-attack)
  bus:on('OnProvoke', function(ev)
    print(string.format('[%s] provoked [%s]!', ev.source.name, ev.target.name))
    Effects.force_counter_attack { scale_pct = 40 } (ctx, ev.target, ev.source)
  end)

  ctx.bus:emit('OnProvoke', { source = hero, target = ogre })


  -- try item equip
  -- Notes:
  --   • Ability mods on FlamebandPlus affect Fireball when cast via Cast.cast.
  --   • ThunderSeal mutates Fireball into weapon-based Lightning damage.
  --   • Flamebrand grants Fireball and adds a basic-attack proc.
  --   • ItemSystem.equip triggers a recompute; unequip reverses changes.

  -- Example sword giving Fireball +20% damage and -0.5s cooldown, -10% cost
  local FlamebandPlus = {
    id = 'flameband_plus',
    slot = 'sword1',
    requires = { attribute = 'cunning', value = 12, mode = 'sole' },
    mods = { { stat = 'weapon_min', base = 6 }, { stat = 'weapon_max', base = 10 } },

    ability_mods = {
      Fireball = { dmg_pct = 20, cd_add = -0.5, cost_pct = -10 },
    },
  }

  -- spell-mutator
  local ThunderSeal = {
    id = 'thunder_seal',
    slot = 'amulet',
    mods = {},  -- normal stat mods if you want
    -- Change Fireball to deal 100% weapon as lightning instead of fire.
    spell_mutators = {
      Fireball = {
        {
          pr = 0,               -- mutator priority, 0=first, higher=later
          wrap = function(orig) -- pass the original effects fn
            -- return a new function that replaces the original behavior
            return function(ctx, src, tgt)
              -- replace base behavior fully:
              Effects.deal_damage {
                weapon = true, scale_pct = 200,
                skill_conversions = { { from = 'physical', to = 'lightning', pct = 100 } }
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
    id = 'flamebrand',
    slot = 'sword1',
    requires = { attribute = 'cunning', value = 12, mode = 'sole' },

    mods = {
      { stat = 'weapon_min',      base = 6 },
      { stat = 'weapon_max',      base = 10 },
      { stat = 'fire_modifier_pct', add_pct = 15 },
    },

    conversions = {
      { from = 'physical', to = 'fire', pct = 25 }
    },

    procs = {
      {
        trigger = 'OnBasicAttack',
        chance = 70,
        effects = Effects.deal_damage {
          components = { { type = 'fire', amount = 40 } },
          tags = { ability = true }
        },
      },
    },

    granted_spells = { 'Fireball' },
    
  }

  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

  assert(ItemSystem.equip(ctx, hero, Flamebrand))
  
-- -------------------------------- new tests ------------------------------- --
  
  local CinderCharm = {
    id='cinder_charm', slot='amulet',
    mods = {
      { stat='penetration_fire_pct', base = 20 }, -- 0 base stat will reset any add_pct values, so we use base.
      { stat='damage_taken_reduction_pct', base = 8 },
    }
  }
  
  assert(ItemSystem.equip(ctx, hero, CinderCharm))
  
  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
  
  Effects.modify_stat { id='ice_skin', name='max_cold_resist_cap_pct', add_pct_add=15, duration=6 }
  
  Effects.modify_stat { id='boss_hide', name='damage_taken_physical_reduction_pct', add_pct_add=30, duration=10 }

  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
  
  local Scorched = Effects.status{
    id = 'scorched', duration = 5, stack = { mode='time_extend' },
    apply = function(e) e.stats:add_add_pct('fire_resist_pct', -10) end,
    remove= function(e) e.stats:add_add_pct('fire_resist_pct', 10) end
  }
  -- Use it in any effect chain:
  local exampleChain = Effects.seq { Effects.deal_damage{components = { { type = 'fire', amount = 40 } }, tags = { ability = true }}, Scorched }
  
  exampleChain(ctx, hero, ogre)
  util.dump_stats(ogre, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
  Effects.deal_damage { weapon = true, scale_pct = 100 } (ctx, hero, ogre)
  Effects.deal_damage { weapon = true, scale_pct = 100 } (ctx, hero, ogre)
  
  -- upgrading items
  Items.upgrade(ctx, hero, Flamebrand, {
    level_up = 1,
    add_mods = { { stat='fire_modifier_pct', add_pct=5 } }
  })
  
  
 --test: single unified hook API for ad-hoc gameplay code:

  local removeHook = Core.hook(ctx, 'OnHitResolved', {
        icd = 0.5, -- internal cooldown to avoid double-firing on multi-hit attacks. advance time to see it reset.
        filter = function(ev) return ev and ev.did_damage and ev.source == hero end,
        run = function(ctx, ev) Effects.heal{flat=(ev.damage or 0)*0.05}(ctx, ev.source, ev.source) end
  })
  
  -- do some damage to trigger the hook
  local chain = Effects.seq { Effects.deal_damage{components = { { type = 'fire', amount = 40 } }, tags = { ability = true }}, Scorched }
  chain(ctx, hero, ogre)
  Effects.deal_damage { weapon = true, scale_pct = 100 } (ctx, hero, ogre)
  Effects.deal_damage { weapon = true, scale_pct = 100 } (ctx, hero, ogre)
  
  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
  
-- call `removeHook()` to remove
  removeHook()
  
  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
  
  -- test: (Example proc that keys off reason and damage:)
  --  > Arbitrary item effects (full freedom) + pass ev into item procs

local ReactiveBalm = {
  id='reactive_balm', slot='medal',
  procs = {
    {
      trigger = 'OnHitResolved',
      chance  = 100,
      filter  = function(ev) return ev and ev.target and ev.did_damage end,
      effects = function(ctx, wearer, _, ev)
        if ev.reason == 'weapon' and (ev.damage or 0) > 50 then
          -- big hits apply an instant heal for 10% of the damage received
          Effects.heal { flat = (ev.damage or 0) * 0.10 } (ctx, wearer, wearer)
        end
      end
    }
  }
}

-- equip balm
assert(ItemSystem.equip(ctx, hero, ReactiveBalm))

util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

-- do some damage to trigger the proc
chain = Effects.seq { Effects.deal_damage{components = { { type = 'physical', amount = 120 } }, tags = { ability = true }}, Scorched }

util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
chain(ctx, ogre, hero)

util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
Effects.deal_damage { weapon = true, scale_pct = 100, reason = "weapon" } (ctx, hero, ogre)

util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
-- -------------------------------- end test -------------------------------- --

  assert(ItemSystem.equip(ctx, hero, FlamebandPlus))

  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

  assert(ItemSystem.equip(ctx, hero, ThunderSeal))

  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

  -- Trigger basic-attack procs a few times (tests Flamebrand’s proc path).
  ctx.bus:emit('OnBasicAttack', { source = hero, target = ogre })
  ctx.bus:emit('OnBasicAttack', { source = hero, target = ogre })
  ctx.bus:emit('OnBasicAttack', { source = hero, target = ogre })


  -- (1) Player presses key: cast Fireball at a chosen enemy now
  -- Uses Cast.cast so cooldown/cost/ability_mods & mutators are applied.
  local ok, why = Cast.cast(ctx, hero, 'Fireball', ogre)

  -- (2) Item-granted active with its own cooldown unaffected by CDR:
  -- mark the spell once at init-time:
  -- NOTE: Fireball already has item_granted=true in Content.Spells; this line
  -- is redundant in the demo but shows how to toggle that flag at runtime.
  Content.Spells.Fireball.item_granted = true

  util.dump_stats(ogre, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

  -- (3) A ground-targeted or self-targeted buff:
  -- just pass the appropriate primary_target, or leave nil and let targeter select.



  -- leveling & granted spells
  ctx.bus:on('OnLevelUp', function(ev)
    local e = ev.entity
    -- Auto-allocate Physique each level:
    e.stats:add_base('physique', 1)
    e.stats:recompute()

    -- NOTE: log_debug is not defined in this demo; if you want this line to
    -- print, replace with print(...) or define log_debug elsewhere.
    log_debug("Level up!", e.name, "now at level", e.level, "with", e.attr_points, "attribute points and", e
    .skill_points, "skill points.")

    -- Unlock Fireball at level 3:
    if e.level == 3 then
      e.granted_spells = e.granted_spells or {}
      e.granted_spells['Fireball'] = true
    end
  end)

  -- Grant EXP twice; with fast_start curve, expect 1+ level ups and OnLevelUp side effects.
  Leveling.grant_exp(ctx, hero, 1500) -- grant some exp to level up
  Leveling.grant_exp(ctx, hero, 1500) -- grant some exp to level up

  -- Final stats dump
  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
  util.dump_stats(ogre, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
end


--[[===========================================================================
Demo.run_full
Purpose:
  • End-to-end showcase of the combat framework with items, skills, devotions,
    auras, WPS, charges/channeling, sets, leveling, and logging.
  • Useful as a regression sandbox and reference for API usage/order-of-ops.

High-level flow:
  1) Build core systems: EventBus, Time, StatDef, Combat context (RR, damage types).
  2) Create ctx (combat arena), wire side accessors, hook devotion dispatcher.
  3) Spawn actors (hero, ogre) and seed stats.
  4) Register rich event logging for observability.
  5) Define items: conversions, procs, mutators, granted spells, ability mods.
  6) Equip/replace items; set ability levels; run openers and RR demos.
  7) Cast spells with build+mutator+mods; apply DoTs and tick world.
  8) Demonstrate barrier/heal, provoke/counter, cooldown/cost interactions.
  9) Leveling pipeline with granted spells on level 3.
 10) Status stacking modes (replace, time_extend, count) and cleanse mechanics.
 11) Composition helpers: par/seq/chance/scale_by_stat + conversion order check.
 12) Exclusive aura toggle with energy reservation.
 13) Skill modifiers & transmuters + WPS default-attack pipeline.
 14) Devotion attach + ICD behavior.
 15) Charges and Channel systems; Pets and Sets (apply/unapply).
 16) Equip rule failures; CDR exclusion for item-granted spells; ability_mods on build path.
 17) Cleanup ticks and final dumps.

Rename suggestions (comments only):
  • Demo.run_full -> Demo.play_all or Demo.sandbox_full
  • combat (local) -> core or combat_ctx (it’s passed into ctx.combat)
  • on(bus, ...) helper -> log_event (semantic name)
  • display/resolve helpers -> stringify_value / resolve_value
  • FlamebandPlus -> FlamebrandPlus (if that’s what you meant; keeping as-is)
  • RingOfWard -> RingOfWard(s) (if plural intended)
  • local ctx forward declaration: avoid double 'local ctx' (see note below)
Caveats:
  • There are two 'local ctx' declarations in this scope. In Lua, re-declaring
    a local in the same block shadows the earlier one. Because callbacks are
    installed *after* the table assignment, they will close over the later ctx.
    If you intended a true forward-declared upvalue, prefer:
      local ctx; ctx = { ... }
    (Not changing code here—just documenting intent.)
  • ogre.damage_taken_reduction_pct = 2000 will flip damage to large negative
    in the reducer stage, effectively healing the ogre. This is fine for stress
    testing the pipeline; just be aware for “real” balancing.
===========================================================================]]--
function Demo.run_full()
  math.randomseed(12345)

  local bus       = EventBus.new()
  local time      = Time.new()
  local defs, DTS = StatDef.make()
  local combat    = Combat.new(RR, DTS)  -- carries RR + DAMAGE_TYPES; stored on ctx.combat


  local ctx -- declare ahead so locals can capture it
  -- NOTE: This is immediately shadowed by the next line's 'local ctx'. If you want
  -- true forward-declaration, remove 'local' on the second one and assign into this.
  -- (Left untouched by request.)
  
  local ctx = {
    _make_actor    = make_actor, -- Factory for creating actors
    debug          = true,       -- verbose debug prints across systems
    bus            = bus,        -- shared event bus for this arena
    time           = time,       -- shared clock for statuses/DoTs/cooldowns
    combat         = combat      -- optional bundle for RR+damage types, if needed
  }
  
  -- add side-aware accessors to ctx
  -- Used by targeters and AI; these close over 'ctx' (safe here).
  ctx.get_enemies_of = function(a) return a.side == 1 and ctx.side2 or ctx.side1 end
  ctx.get_allies_of  = function(a) return a.side == 1 and ctx.side1 or ctx.side2 end

  -- After creating bus, hook devotions
  -- All selected events will be forwarded into Devotion.handle_event; that function
  -- internally checks per-entity devotion tables and triggers specs when conditions match.
  for _, evn in ipairs({ 'OnHitResolved', 'OnBasicAttack', 'OnCrit', 'OnDeath', 'OnDodge' }) do
    bus:on(evn, function(ev) Devotion.handle_event(ctx, evn, ev) end)
  end

  -- Actors
  -- Hero baseline: some OA/Cunning/Spirit, crit damage, CDR, cost reduction, and atk/cast speed.
  local hero = make_actor('Hero', defs, Content.attach_attribute_derivations)
  hero.side = 1
  hero.level_curve = 'fast_start'
  hero.stats:add_base('physique', 16)
  hero.stats:add_base('cunning', 18)
  hero.stats:add_base('spirit', 12)
  hero.stats:add_base('weapon_min', 18)
  hero.stats:add_base('weapon_max', 25)
  hero.stats:add_base('life_steal_pct', 10)
  hero.stats:add_base('crit_damage_pct', 50) -- +50% crit damage
  hero.stats:add_base('cooldown_reduction', 20)
  hero.stats:add_base('skill_energy_cost_reduction', 15)
  hero.stats:add_base('attack_speed', 1.0)
  hero.stats:add_base('cast_speed', 1.0)
  hero.stats:recompute()

  -- Ogre: tougher target with defense layers and reactive behaviors (reflect/retaliation/block).
  local ogre = make_actor('Ogre', defs, Content.attach_attribute_derivations)
  ogre.side = 2
  ogre.stats:add_base('health', 400)
  ogre.stats:add_base('defensive_ability', 95)
  ogre.stats:add_base('armor', 50)
  ogre.stats:add_base('armor_absorption_bonus_pct', 20)
  ogre.stats:add_base('fire_resist_pct', 40)
  ogre.stats:add_base('dodge_chance_pct', 10)
  -- ogre.stats:add_base('deflect_chance_pct', 8) -- (deflection not currently used)
  ogre.stats:add_base('reflect_damage_pct', 5)
  ogre.stats:add_base('retaliation_fire', 8)
  ogre.stats:add_base('retaliation_fire_modifier_pct', 25)
  ogre.stats:add_base('block_chance_pct', 30)
  ogre.stats:add_base('block_amount', 60)
  ogre.stats:add_base('block_recovery_reduction_pct', 25)
  ogre.stats:add_base('damage_taken_reduction_pct',2000) -- stress test: massive DR → negative damage (healing)
  ogre.stats:recompute()

  ctx.side1 = { hero }
  ctx.side2 = { ogre }
  
  -- attach defs/derivations to ctx for easy access later for pets
  ctx._defs       = defs
  ctx._attach     = Content.attach_attribute_derivations
  ctx._make_actor = make_actor


  -- Event logging
  -- Pretty-printer for event field values
  -- Suggestion: this helper isn't used below (we use 'resolve'); keep if you plan to
  -- log heterogeneous payloads elsewhere.
  local function display(v)
    local tv = type(v)
    if tv == "string" or tv == "number" or tv == "boolean" then
      return tostring(v)
    elseif tv == "table" then
      -- Respect custom __tostring if present
      local mt = getmetatable(v)
      if mt and mt.__tostring then return tostring(v) end
      -- Common human-readable fallbacks
      if v.name then return tostring(v.name) end
      if v.id then return tostring(v.id) end
      if v.label then return tostring(v.label) end
      -- Last resort: compact table tag
      return "<tbl:" .. (tostring(v):match("0x[%da-fA-F]+") or "?") .. ">"
    else
      return tostring(v)
    end
  end

  -- Translate values for compact logs—prefers names/ids over table dumps.
  local function resolve(v)
    if type(v) == "table" then
      if v.name then return v.name end -- prefer entity name
      if v.id then return v.id end     -- fallback id if you have one
      return "<tbl>"                   -- last-resort placeholder
    elseif type(v) == "boolean" then
      return v and "true" or "false"
    elseif v == nil then
      return "nil"
    else
      return v
    end
  end

  -- Generic logger: subscribes to an event and prints a formatted line with chosen fields.
  -- Tip: extend with on(..., { fields }, extras_resolver) if you later want custom suffixes.
  local function on(bus, name, fmt, fields)
    bus:on(name, function(e)
      local vals = {}
      for _, k in ipairs(fields or {}) do
        vals[#vals + 1] = resolve(e[k])
      end

      local line = ("[EVT] %-16s " .. fmt):format(name, table.unpack(vals))

      -- Append tag/reason if present (keeps existing fmt untouched)
      local extra = {}
      if e.tag ~= nil then extra[#extra + 1] = "tag=" .. tostring(resolve(e.tag)) end
      if e.reason ~= nil then extra[#extra + 1] = "reason=" .. tostring(resolve(e.reason)) end
      if #extra > 0 then
        line = line .. " (" .. table.concat(extra, " ") .. ")"
      end

      print(line)
    end)
  end


  on(bus, 'OnHitResolved', "[%s] -> [%s] dmg=%.1f crit=%s PTH=%.1f", { 'source', 'target', 'damage', 'crit', 'pth' })
  on(bus, 'OnHealed', "[%s] +%.1f", { 'target', 'amount' })
  on(bus, 'OnCounterAttack', "[%s] countered %s", { 'source', 'target' })
  on(bus, 'OnRRApplied', "%s RR %s=%.1f%%", { 'damage_type', 'rr_kind', 'amount' })

  on(bus, 'OnMiss', "[%s] missed %s", { 'source', 'target' })
  on(bus, 'OnDodge', "%s dodged %s", { 'target', 'source' })
  on(bus, 'OnStatusExpired', "status expired: %s", { 'id' })
  on(bus, 'OnDotApplied', "dot %s on %s", { 'dot', 'target' })
  on(bus, 'OnDotExpired', "dot expired on %s", { 'entity' })
  on(bus, 'OnDeath', "%s died (killer=%s)", { 'entity', 'killer' })
  on(bus, 'OnExperienceGained', "XP +%.1f (levels+%d)", { 'amount', 'levels' })
  on(bus, 'OnLevelUp', "Level up: %s", { 'entity' })
  on(bus, 'OnStatusRemoved', "status removed: %s (by=%s)", { 'id', 'source' })


  -- Items: conversions, procs, mutators, granted spells, ability mods
  -- Flamebrand: adds fire scaling, a basic-attack fire proc, physical→fire conversion, and grants Fireball.
  local Flamebrand = {
    id = 'flamebrand',
    slot = 'sword1',
    requires = { attribute = 'cunning', value = 12, mode = 'sole' },
    mods = {
      { stat = 'weapon_min',      base = 6 },
      { stat = 'weapon_max',      base = 10 },
      { stat = 'fire_modifier_pct', add_pct = 15 },
    },
    conversions = { { from = 'physical', to = 'fire', pct = 25 } },
    procs = {
      {
        trigger = 'OnBasicAttack',
        chance = 70,
        effects = Effects.deal_damage {
          components = { { type = 'fire', amount = 40 } }, tags = { ability = true }
        },
      },
    },
    granted_spells = { 'Fireball' },
  }

  -- FlamebandPlus: demonstrates ability_mods affecting a named spell (dmg%, cd_add, cost_pct).
  -- Note: Replaces the current sword when equipped.
  local FlamebandPlus = {
    id = 'flameband_plus',
    slot = 'sword1',
    requires = { attribute = 'cunning', value = 12, mode = 'sole' },
    mods = { { stat = 'weapon_min', base = 4 }, { stat = 'weapon_max', base = 8 } },
    ability_mods = { Fireball = { dmg_pct = 20, cd_add = -0.5, cost_pct = -10 }, },
  }

  -- ThunderSeal: illustrates a spell mutator wrapping Fireball to add a big lightning weapon hit.
  -- This shows "augment" style (calls orig) rather than full replace.
  local ThunderSeal = {
    id = 'thunder_seal',
    slot = 'amulet',
    spell_mutators = {
      Fireball = {
        {
          pr = 0,
          wrap = function(orig)
            return function(ctx, src, tgt)
              if orig then orig(ctx, src, tgt) end
              Effects.deal_damage {
                weapon = true, scale_pct = 200,
                skill_conversions = { { from = 'physical', to = 'lightning', pct = 100 } }
              } (ctx, src, tgt)
            end
          end
        }
      }
    }
  }
  
  -- RingOfWard: demonstrates on_equip custom status application with persistent barrier
  -- via Effects._entry_of to build a manual entry, then apply_status directly.
  -- The returned cleanup removes the status on unequip.
  local RingOfWard = {
    id='ring_of_ward', slot='ring',
    on_equip = function(ctx, e)
      local entry = Effects._entry_of[Effects.grant_barrier { amount = 30, duration = 999999 }](ctx, {exclusive=false})
      entry.id = "ring_of_ward_barrier"
      entry.until_time = nil  -- persistent while worn
      apply_status(e, entry)
      return function(ent)
        -- remove when unequipped
        if ent.statuses and ent.statuses[entry.id] then
          for i,en in ipairs(ent.statuses[entry.id].entries) do if en.remove then en.remove(ent) end end
          ent.statuses[entry.id] = nil
        end
      end
    end
  }

  print("\n== Equip sequence ==")
  util.dump_stats(hero, ctx, { conv = true, timers = true, spells = true })
  assert(ItemSystem.equip(ctx, hero, Flamebrand))
  util.dump_stats(hero, ctx, { conv = true, timers = true, spells = true })
  assert(ItemSystem.equip(ctx, hero, FlamebandPlus)) -- replaces sword
  util.dump_stats(hero, ctx, { conv = true, timers = true, spells = true })
  assert(ItemSystem.equip(ctx, hero, ThunderSeal))
  util.dump_stats(hero, ctx, { conv = true, timers = true, spells = true })

  -- Ability level & mods
  -- set_ability_level writes per-entity level; ability_mods are read during Cast.cast build path.
  set_ability_level(hero, 'Fireball', 3)

  print("\n== Openers ==")
  Effects.deal_damage { weapon = true, scale_pct = 100 } (ctx, hero, ogre)
  ctx.bus:emit('OnBasicAttack', { source = hero, target = ogre }) -- proc check

  -- RR tier tests (rr1, rr2, rr3) — show order-of-ops and strongest-pick behavior for rr2/rr3.
  Content.Spells.ViperSigil.effects(ctx, hero, ogre)     -- rr2
  Content.Spells.ElementalStorm.effects(ctx, hero, ogre) -- rr3
  util.dump_stats(ogre, ctx, { rr = true, timers = true })

  print("\n== Fireball cast (with mutator, level, and item mods) ==")
  local ok, why = Cast.cast(ctx, hero, 'Fireball', ogre)
  if not ok then print("Cast failed:", why) end
  util.dump_stats(ogre, ctx, { rr = true, dots = true, statuses = true, timers = true })

  print("\n== Poison DoT + tick ==")
  Cast.cast(ctx, hero, 'PoisonDart', ogre)
  for i = 1, 5 do World.update(ctx, 1.0) end
  util.dump_stats(ogre, ctx, { rr = true, dots = true, timers = true })

  print("\n== Barrier & Heal ==")
  -- grant_barrier is just a convenience wrapper around a flat_absorb buff; heal scales with healing_received_pct.
  Effects.grant_barrier { amount = 50, duration = 3 } (ctx, hero, hero)
  Effects.heal { percent_of_max = 15 } (ctx, hero, hero)
  util.dump_stats(hero, ctx, { statuses = true, timers = true })

  print("\n== Provoke & counter chain ==")
  -- OnProvoke has a handler (set elsewhere) that forces a counter-attack.
  bus:emit('OnProvoke', { source = hero, target = ogre }) -- your handler forces counter

  print("\n== Cooldowns & costs ==")
  -- Demonstrates Cast.cast path interacting with CDR and cost reductions.
  -- Note: item_granted spells ignore CDR by policy (see Cast.cast).
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
  util.dump_stats(hero, ctx, { timers = true })

  print("\n== Leveling & granted spell at level 3 ==")
  -- Adds a second OnLevelUp listener specific to this demo (distinct from earlier global ones).
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
  util.dump_stats(hero, ctx, { spells = true })



  print("\n== Status stacking modes ==")
  -- Demonstrates: default replace, time_extend extending duration, and count-based stacks with cap.
  Effects.modify_stat { id = 'buffA', name = 'fire_modifier_pct', add_pct_add = 10, duration = 2 } (ctx, hero, hero) -- replace default
  Effects.modify_stat { id = 'buffA', name = 'fire_modifier_pct', add_pct_add = 5, duration = 4, stack = { mode = 'time_extend' } } (
  ctx, hero, hero)
  Effects.modify_stat { id = 'buffB', name = 'cunning', base_add = 1, duration = 3, stack = { mode = 'count', max = 3 } } (
  ctx, hero, hero)
  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
  for i = 1, 5 do
    World.update(ctx, 1.0)
    util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
  end

  print("\n== Cleanse by id/predicate ==")
  -- Cleanse removes by id or predicate; emits OnStatusRemoved with reason='cleanse'.
  Effects.modify_stat { id = 'burning', name = 'percent_absorb_pct', add_pct_add = 5, duration = 10 } (ctx, hero, hero)

  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
  Effects.cleanse { ids = { burning = true }, predicate = function(id, entry) return false end } (ctx, hero, hero)

  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

  print("\n== par / seq / chance / scale_by_stat ==")
  -- Composition example: run fire burst + conditional RR, then a pierce hit scaled by Cunning.
  local burst = Effects.seq {
    Effects.par {
      Effects.deal_damage { components = { { type = 'fire', amount = 30 } } },
      Effects.chance(50, Effects.apply_rr { kind = 'rr1', damage = 'fire', amount = 10, duration = 2 })
    },
    Effects.scale_by_stat('cunning', 0.5, function(x)
      return function(ctx, src, tgt) Effects.deal_damage { components = { { type = 'pierce', amount = x } } } (ctx, src,
          tgt) end
    end)
  }
  burst(ctx, hero, ogre)

  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
  print("\n== Conversions ordering (skill before gear) ==")
  -- Skill-stage conversions should be applied before gear-stage conversions (Conv.apply).
  hero.gear_conversions = { { from = 'physical', to = 'fire', pct = 50 } }
  Effects.deal_damage {
    components = { { type = 'physical', amount = 100 } },
    skill_conversions = { { from = 'physical', to = 'cold', pct = 50 } }
  } (ctx, hero, ogre)

  print("\n== Exclusive aura toggle & reservation ==")
  -- Toggle an exclusive aura: applies a permanent (while toggled) stat entry and reserves energy.
  Skills.SkillTree.set_rank(hero, 'PossessionLike', 5)
  Skills.SkillTree.toggle_exclusive(hero, 'PossessionLike')
  Auras.toggle_exclusive(ctx, hero, Skills, 'PossessionLike')
  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

  print("\n== Modifier & Transmuter application ==")
  -- Modifiers wrap the base skill behavior; transmuters are exclusive variants altering the core hit.
  Skills.SkillTree.set_rank(hero, 'FireStrike', 8)
  Skills.SkillTree.set_rank(hero, 'ExplosiveStrike', 6)     -- modifier
  Skills.SkillTree.enable_transmuter(hero, 'SearingStrike') -- transmuter
  WPS.handle_default_attack(ctx, hero, ogre, Skills)

  print("\n== Devotion trigger w/ ICD ==")
  -- Attaches a devotion that heals the source for 20% of dealt damage on OnHitResolved, respecting an ICD.
  local devo = {
    -- heal for 20% of dealt damage, only if damage > 0
    id       = 'BloodMender',
    trigger  = 'OnHitResolved',
    chance   = 100,
    icd      = 0.0,
    condition = function(ctx, ev)
      return ev and (ev.did_damage == true) and (ev.damage or 0) > 0
    end,
    effects  = function(ctx, src, tgt, ev)
      local heal = (ev.damage or 0) * 0.20
      Effects.heal { flat = heal } (ctx, src, src)
    end
  }
  Devotion.attach(hero, devo)
  bus:on('OnHitResolved', function(ev) Devotion.handle_event(ctx, 'OnHitResolved', ev) end)
  Effects.deal_damage { weapon = true, scale_pct = 100 } (ctx, hero, ogre)
  World.update(ctx, 0.5); Effects.deal_damage { weapon = true, scale_pct = 100 } (ctx, hero, ogre) -- should be on ICD
  World.update(ctx, 1.5); Effects.deal_damage { weapon = true, scale_pct = 100 } (ctx, hero, ogre) -- off ICD

  print("\n== Charges & Channel ==")
  -- Charges: attach from skill spec (OverheatWithRank adjusts cap by rank).
  -- Channel: drains energy over time and fires periodic ticks until stopped or out of energy.
  -- Systems.Charges.add_track(hero, 'Heat', 10, 2, function(e, stacks)
  --   e.stats:recompute() -- in real code: add/remove marks then recompute
  -- end)
  local chargeRemoveHandle = Systems.Charges.add_track(hero, Skills.DB.OverheatWithRank)
  Systems.Charges.on_hit(hero, 'Heat', 5)
  Systems.Channel.start(ctx, hero, 'Beam', 8,
    function(ctx, e) Effects.deal_damage { components = { { type = 'aether', amount = 15 } } } (ctx, e, ogre) end, 0.5)
  for i = 1, 5 do World.update(ctx, 0.5) end
  Systems.Channel.stop(hero, 'Beam')
  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
  chargeRemoveHandle.remove() -- remove the charge track

  print("\n== Pets & Sets (apply/unapply) ==")
  -- Pet spawns reuse ctx/_defs/_attach/_make_actor to mirror owner’s derivation pipeline.
  Content.Sets = {
    EmberSet = {
      bonuses = {
        { pieces = 2, mutators = { Fireball = function(orig) return function(ctx, src, tgt) if orig then orig(ctx, src,
                tgt) end end end } },
        {
          pieces = 3,
          effects = function(ctx, e)
            e.stats:add_add_pct('fire_modifier_pct', 10)
            return function(ent) ent.stats:add_add_pct('fire_modifier_pct', -10) end
          end
        },
      }
    }
  }
  local pet = PetsAndSets.spawn_pet(ctx, hero, { name = 'Imp', inherit_damage_mult = 0.6 })
  local item2 = { id = 'E1', slot = 'ring', set_id = 'EmberSet' }
  local item3 = { id = 'E2', slot = 'amulet', set_id = 'EmberSet' }
  ItemSystem.equip(ctx, hero, item2); PetsAndSets.recompute_sets(ctx, hero)
  ItemSystem.equip(ctx, hero, item3); PetsAndSets.recompute_sets(ctx, hero)
  ItemSystem.unequip(ctx, hero, 'amulet'); PetsAndSets.recompute_sets(ctx, hero)

  print("\n== Equip rules failure paths ==")
  -- Items.can_equip validates attribute threshold + slot allowlist per attribute/mode.
  local bad = { id = 'HeavyAxe', slot = 'axe2', requires = { attribute = 'physique', value = 999, mode = 'sole' } }
  local ok, why = ItemSystem.equip(ctx, hero, bad); print("Equip heavy axe:", ok, why or "")

  print("\n== CDR exclusion: item-granted vs native ==")
  -- Demonstrates that item-granted actives ignore cooldown_reduction (per Cast.cast policy).
  Content.Spells.Fireball.cooldown = 3.0
  hero.granted_spells = { Fireball = true } -- item-granted: CDR should NOT apply
  hero.stats:add_add_pct('cooldown_reduction', 50)
  Cast.cast(ctx, hero, 'Fireball', ogre)
  local ok2, why2 = Cast.cast(ctx, hero, 'Fireball', ogre)
  print("Immediate recast (should be on CD, ignoring CDR):", ok2, why2 or "")

  print("\n== Ability level + item ability_mods (build path) ==")
  -- ability_mods (e.g., from ring) are folded into the spell’s .build knobs at cast time.
  set_ability_level(hero, 'Fireball', 4)
  hero.equipped.ring = { ability_mods = { Fireball = { dmg_pct = 30, cd_add = -0.5, cost_pct = -10 } } } 
  Cast.cast(ctx, hero, 'Fireball', ogre) -- on cooldown


  print("\n== Cleanup ticks ==")
  for i = 1, 5 do World.update(ctx, 1.0) end
  util.dump_stats(ogre, ctx, { rr = true, dots = true, statuses = true, timers = true })
end

-- Module exposure
-- Notes:
--  • The Core table is pulled from a preloaded 'part1_core' if present; otherwise it
--    falls back to the current Core in scope.
--  • Returning { Core = _core, Game = _game } lets consumers do:
--        local M = dofile("..."); local Core, Game = M.Core, M.Game
--    preserving separations of systems vs. demo harness.
local _core = dofile and package and package.loaded and package.loaded['part1_core'] or nil
if not _core then _core = (function() return Core end)() end
local _game = (function()
  return {
    Effects = Effects,
    Combat = Combat,
    Items = Items,
    Leveling = Leveling,
    Content =
        Content,
    StatusEngine = StatusEngine,
    World = World,
    ItemSystem = ItemSystem,
    Cast = Cast,
    WPS = WPS,
    Skills = Skills,
    Auras = Auras,
    Systems = Systems,
    PetsAndSets = PetsAndSets,
    Demo = Demo
  }
end)()

return { Core = _core, Game = _game }
