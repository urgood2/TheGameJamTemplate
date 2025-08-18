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

local Core = {}

-- Utility Helpers -----------------------------------------------------
local util = {}
function util.copy(t)
  local r = {}
  for k, v in pairs(t) do r[k] = type(v) == 'table' and util.copy(v) or v end
  return r
end

function util.shallow_copy(t)
  local r = {}
  for k, v in pairs(t) do r[k] = v end
  return r
end

function util.clamp(x, a, b) if x < a then return a elseif x > b then return b else return x end end

function util.rand() return math.random() end

function util.choice(list) return list[math.random(1, #list)] end

function util.weighted_choice(entries)
  local sum = 0
  for _, e in ipairs(entries) do sum = sum + (e.w or 0) end
  local r = math.random() * sum
  local acc = 0
  for _, e in ipairs(entries) do
    acc = acc + (e.w or 0)
    if r <= acc then return e.item end
  end
  return entries[#entries].item
end

-- EventBus ------------------------------------------------------------
local EventBus = {}; EventBus.__index = EventBus
function EventBus.new() return setmetatable({ listeners = {} }, EventBus) end

function EventBus:on(name, fn, pr)
  local b = self.listeners[name] or {}; table.insert(b, { fn = fn, pr = pr or 0 }); table.sort(b,
    function(a, b) return a.pr < b.pr end); self.listeners[name] = b
end

function EventBus:emit(name, ctx)
  local b = self.listeners[name]; if not b then return end
  for i = 1, #b do b[i].fn(ctx) end
end

-- Time (cooldowns/durations) -----------------------------------------
local Time = {}; Time.__index = Time
function Time.new() return setmetatable({ now = 0 }, Time) end

function Time:tick(dt) self.now = self.now + dt end

function Time:is_ready(tbl, key) return (tbl[key] or -1) <= self.now end

function Time:set_cooldown(tbl, key, d) tbl[key] = self.now + d end

-- Stats Definitions ---------------------------------------------------
local StatDef = {}
local DAMAGE_TYPES = {
  'physical', 'pierce', 'bleed', 'trauma', 'fire', 'cold', 'lightning', 'acid', 'vitality', 'aether', 'chaos',
  'burn', 'frostburn', 'electrocute', 'poison', 'vitality_decay'
}
local function add_basic(defs, name) defs[name] = { base = 0, add_pct = 0, mul_pct = 0 } end
function StatDef.make()
  local defs = {}
  -- core attributes
  add_basic(defs, 'physique'); add_basic(defs, 'cunning'); add_basic(defs, 'spirit')
  -- abilities/meta
  add_basic(defs, 'offensive_ability'); add_basic(defs, 'defensive_ability'); add_basic(defs, 'level'); add_basic(defs,
    'experience_gained_pct')
  -- health/energy and regen
  add_basic(defs, 'health'); add_basic(defs, 'health_regen'); add_basic(defs, 'energy'); add_basic(defs, 'energy_regen')
  -- speeds, crit, all-damage
  add_basic(defs, 'attack_speed'); add_basic(defs, 'cast_speed'); add_basic(defs, 'run_speed'); add_basic(defs,
    'crit_damage_pct'); add_basic(defs, 'all_damage_pct')
  -- weapon & shield
  add_basic(defs, 'weapon_min'); add_basic(defs, 'weapon_max'); add_basic(defs, 'weapon_damage_pct');
  add_basic(defs, 'block_chance_pct'); add_basic(defs, 'block_amount'); add_basic(defs, 'block_recovery_reduction_pct')
  -- avoidance & absorption
  add_basic(defs, 'dodge_chance_pct'); add_basic(defs, 'deflect_chance_pct'); add_basic(defs, 'percent_absorb_pct'); add_basic(
  defs, 'flat_absorb')
  -- armor
  add_basic(defs, 'armor'); add_basic(defs, 'armor_absorption_bonus_pct')
  -- lifesteal/healing
  add_basic(defs, 'life_steal_pct'); add_basic(defs, 'healing_received_pct')
  -- per-type packs
  for _, dt in ipairs(DAMAGE_TYPES) do
    add_basic(defs, dt .. '_damage'); add_basic(defs, dt .. '_modifier_pct'); add_basic(defs, dt .. '_resist_pct')
    if dt == 'bleed' or dt == 'trauma' or dt == 'burn' or dt == 'frostburn' or dt == 'electrocute' or dt == 'poison' or dt == 'vitality_decay' then
      add_basic(defs, dt .. '_duration_pct')
    end
  end
  -- reflect/retaliation
  add_basic(defs, 'reflect_damage_pct')
  for _, dt in ipairs(DAMAGE_TYPES) do
    add_basic(defs, 'retaliation_' .. dt); add_basic(defs, 'retaliation_' .. dt .. '_modifier_pct')
  end
  -- CC resists (names kept short)
  for _, cc in ipairs({ 'stun', 'disruption', 'leech_life', 'leech_energy', 'trap', 'petrify', 'freeze', 'sleep', 'slow', 'reflect' }) do
    add_basic(defs, cc .. '_resist_pct') end
  return defs, DAMAGE_TYPES
end

-- Stats ---------------------------------------------------------------
local Stats = {}; Stats.__index = Stats
function Stats.new(defs)
  local t = { defs = defs, values = {}, derived_hooks = {}, cached = {} }; for n, d in pairs(defs) do t.values[n] = { base =
    d.base, add_pct = 0, mul_pct = 0 } end; return setmetatable(t, Stats)
end

function Stats:get_raw(n) return self.values[n] end

function Stats:get(n)
  local v = self.values[n] or { base = 0, add_pct = 0, mul_pct = 0 }; return v.base * (1 + v.add_pct / 100) *
  (1 + v.mul_pct / 100)
end

function Stats:add_base(n, a) self.values[n].base = self.values[n].base + a end

function Stats:add_add_pct(n, a) self.values[n].add_pct = self.values[n].add_pct + a end

function Stats:add_mul_pct(n, a) self.values[n].mul_pct = self.values[n].mul_pct + a end

function Stats:on_recompute(fn) table.insert(self.derived_hooks, fn) end

function Stats:recompute() for _, fn in ipairs(self.derived_hooks) do fn(self) end end

-- Resistance Reduction (types 1/2/3, correct order) ------------------
local RR = {}
local function pick_highest(tbl)
  local best = nil
  for _, e in ipairs(tbl) do if (not best) or e.amount > best.amount then best = e end end
  return best
end
function RR.apply_all(base, list)
  local r = base; local rr1, rr2, rr3 = {}, {}, {}
  for _, e in ipairs(list or {}) do if e.kind == 'rr1' then rr1[#rr1 + 1] = e elseif e.kind == 'rr2' then rr2[#rr2 + 1] =
      e elseif e.kind == 'rr3' then rr3[#rr3 + 1] = e end end
  local sum1 = 0
  for _, e in ipairs(rr1) do sum1 = sum1 + e.amount end
  r = r - sum1                                                                              -- can go below 0
  if #rr2 > 0 then
    local hi = pick_highest(rr2); r = r * (1 - hi.amount / 100); if r < 0 then r = 0 end
  end                                                                                       -- multiplicative, floor at 0
  if #rr3 > 0 then r = r - pick_highest(rr3).amount end                                     -- flat, below zero allowed
  return r
end

-- Conversions (skill then gear) --------------------------------------
local Conv = {}
local function apply_bucket(m, bucket)
  if not bucket or #bucket == 0 then return m end
  local out = {}
  local map = util.shallow_copy(m)
  for _, cv in ipairs(bucket) do
    local avail = map[cv.from] or 0; local move = avail * (cv.pct / 100); map[cv.from] = avail - move; map[cv.to] = (map[cv.to] or 0) +
    move
  end
  for k, v in pairs(map) do out[k] = v end
  return out
end
function Conv.apply(components, skill_bucket, gear_bucket)
  local m = {}
  for _, c in ipairs(components) do m[c.type] = (m[c.type] or 0) + c.amount end
  m = apply_bucket(m, skill_bucket)
  m = apply_bucket(m, gear_bucket)
  local out = {}
  for t, amt in pairs(m) do out[#out + 1] = { type = t, amount = amt } end
  return out
end

-- Targeters -----------------------------------------------------------
local Targeters = {}
function Targeters.self(ctx) return { ctx.source } end

function Targeters.target_enemy(ctx) return { ctx.target } end

function Targeters.all_enemies(ctx) return util.copy(ctx.get_enemies_of(ctx.source)) end

function Targeters.all_allies(ctx) return util.copy(ctx.get_allies_of(ctx.source)) end

function Targeters.random_enemy(ctx)
  local es = ctx.get_enemies_of(ctx.source); if #es == 0 then return {} end
  return { util.choice(es) }
end

function Targeters.enemies_with(predicate) return function(ctx)
    local out = {}
    for _, e in ipairs(ctx.get_enemies_of(ctx.source)) do if predicate(e) then out[#out + 1] = e end end
    return out
  end end

-- Conditions ----------------------------------------------------------
local Cond = {}
function Cond.always() return true end

function Cond.has_tag(tag) return function(e) return e.tags and e.tags[tag] end end

function Cond.stat_below(stat, th) return function(e) return e.stats:get(stat) < th end end

-- Expose Core ---------------------------------------------------------
Core.util = util; Core.EventBus = EventBus; Core.Time = Time; Core.StatDef = StatDef; Core.Stats = Stats; Core.RR = RR; Core.Conv =
Conv; Core.Targeters = Targeters; Core.Cond = Cond; Core.DAMAGE_TYPES = DAMAGE_TYPES

local Effects, Combat, Items, Leveling, Content, StatusEngine, World = {}, {}, {}, {}, {}, {}, {}

local util, EventBus, Time, StatDef, Stats, RR, Conv, Targeters, Cond, DAMAGE_TYPES =
    Core.util, Core.EventBus, Core.Time, Core.StatDef, Core.Stats, Core.RR, Core.Conv, Core.Targeters, Core.Cond,
    Core.DAMAGE_TYPES

-- Effects -------------------------------------------------------------
-- status helper
local function apply_status(target, status)
  target.statuses = target.statuses or {}
  local b = target.statuses[status.id] or { entries = {} }
  target.statuses[status.id] = b
  b.entries[1] = status -- simple replace; extend if you need stacking
  if status.apply then status.apply(target) end
end

Effects.apply_rr = function(p)
  return function(ctx, src, tgt)
    tgt.active_rr = tgt.active_rr or {}; tgt.active_rr[p.damage] = tgt.active_rr[p.damage] or {}
    table.insert(tgt.active_rr[p.damage],
      { kind = p.kind, damage = p.damage, amount = p.amount, until_time = ctx.time.now + (p.duration or 0) })
    ctx.bus:emit('OnRRApplied', { source = src, target = tgt, rr = p })
  end
end

Effects.modify_stat = function(p)
  return function(ctx, src, tgt)
    local entry = {
      id = p.id or ('buff:' .. p.name),
      until_time = p.duration and (ctx.time.now + p.duration) or nil,
      apply = function(e)
        if p.base_add then e.stats:add_base(p.name, p.base_add) end
        if p.add_pct_add then e.stats:add_add_pct(p.name, p.add_pct_add) end
        if p.mul_pct_add then e.stats:add_mul_pct(p.name, p.mul_pct_add) end
      end,
      remove = function(e)
        if p.base_add then e.stats:add_base(p.name, -p.base_add) end
        if p.add_pct_add then e.stats:add_add_pct(p.name, -p.add_pct_add) end
        if p.mul_pct_add then e.stats:add_mul_pct(p.name, -p.mul_pct_add) end
      end
    }
    apply_status(tgt, entry); ctx.bus:emit('OnBuffApplied', { source = src, target = tgt, name = p.name })
  end
end

Effects.deal_damage = function(p)
  return function(ctx, src, tgt)
    -- build components
    local comps = {}
    if p.weapon then
      local min, max = src.stats:get('weapon_min'), src.stats:get('weapon_max')
      local base = math.random() * (max - min) + min
      local scale = (p.scale_pct or 100) / 100
      comps[#comps + 1] = { type = 'physical', amount = base * scale }
      for _, dt in ipairs(DAMAGE_TYPES) do
        local flat = src.stats:get(dt .. '_damage'); if flat ~= 0 then comps[#comps + 1] = { type = dt, amount = flat *
          scale } end
      end
    else
      for _, c in ipairs(p.components or {}) do comps[#comps + 1] = { type = c.type, amount = c.amount } end
    end
    comps = Conv.apply(comps, p.skill_conversions, src.gear_conversions)

    -- hit/crit and defense
    local function pth(OA, DA)
      local term1 = 3.15 * (OA / (3.5 * OA + DA)); local term2 = 0.0002275 * (OA - DA); return (term1 + term2 + 0.2) *
      100
    end
    local OA, DA = src.stats:get('offensive_ability'), tgt.stats:get('defensive_ability')
    local PTH = util.clamp(pth(OA, DA), 60, 140)
    if math.random() * 100 > PTH then
      ctx.bus:emit('OnMiss', { source = src, target = tgt, pth = PTH }); return
    end
    local crit_mult = (PTH < 75) and (PTH / 75) or
    (PTH < 90 and 1.0 or (PTH < 105 and 1.1 or (PTH < 120 and 1.2 or (PTH < 130 and 1.3 or (PTH < 135 and 1.4 or (1.5 + (PTH - 135) * 0.005))))))

    -- shield block
    tgt.timers = tgt.timers or {}; local blocked = false; local block_amt = 0
    if ctx.time:is_ready(tgt.timers, 'block') and math.random() * 100 < tgt.stats:get('block_chance_pct') then
      blocked = true; block_amt = tgt.stats:get('block_amount'); local base = 1.0; local rec = base *
      (1 - tgt.stats:get('block_recovery_reduction_pct') / 100); ctx.time:set_cooldown(tgt.timers, 'block',
        math.max(0.1, rec))
    end

    -- aggregate per type and apply crit
    local sums = {}
    for _, c in ipairs(comps) do sums[c.type] = (sums[c.type] or 0) + c.amount end
    for t, amt in pairs(sums) do sums[t] = amt * crit_mult end

    -- apply modifiers
    local allpct = 1 + src.stats:get('all_damage_pct') / 100
    for t, amt in pairs(sums) do sums[t] = amt * allpct * (1 + src.stats:get(t .. '_modifier_pct') / 100) end

    -- defenses (RR, armor, resist, absorbs, block)
    local dealt = 0
    for t, amt in pairs(sums) do
      local base_res = tgt.stats:get(t .. '_resist_pct')
      local alive_rr = {}
      if tgt.active_rr and tgt.active_rr[t] then for _, e in ipairs(tgt.active_rr[t]) do if (not e.until_time) or e.until_time > ctx.time.now then alive_rr[#alive_rr + 1] =
            e end end end
      local res = RR.apply_all(base_res, alive_rr)
      -- armor for physical
      if t == 'physical' then
        local armor = tgt.stats:get('armor'); local abs = 0.70 * (1 + tgt.stats:get('armor_absorption_bonus_pct') / 100); local mit =
        math.min(amt, armor) * abs; amt = amt - mit
      end
      local after_res = amt * (1 - res / 100)
      local after_pct = after_res * (1 - tgt.stats:get('percent_absorb_pct') / 100)
      local after_block = after_pct
      if blocked then
        local used = math.min(block_amt, after_pct); after_block = after_pct - used; block_amt = block_amt - used
      end
      local after_flat = math.max(0, after_block - tgt.stats:get('flat_absorb'))
      dealt = dealt + after_flat
    end

    -- apply
    local maxhp = tgt.max_health or tgt.stats:get('health')
    tgt.hp = util.clamp((tgt.hp or maxhp) - dealt, 0, maxhp)

    -- lifesteal
    local ls = src.stats:get('life_steal_pct') or 0
    if ls > 0 then
      local heal = dealt * (ls / 100); local smax = src.max_health or src.stats:get('health'); src.hp = util.clamp(
      (src.hp or smax) + heal, 0, smax)
    end

    -- reflect + retaliation (flat sum)
    local ref = tgt.stats:get('reflect_damage_pct') or 0
    if ref > 0 then
      local re = dealt * (ref / 100); local smax = src.max_health or src.stats:get('health'); src.hp = util.clamp(
      (src.hp or smax) - re, 0, smax)
    end
    local ret = 0
    for _, dt in ipairs(DAMAGE_TYPES) do
      local base = tgt.stats:get('retaliation_' .. dt) or 0; local mod = 1 +
      (tgt.stats:get('retaliation_' .. dt .. '_modifier_pct') or 0) / 100; ret = ret + base * mod
    end
    if ret > 0 then
      local smax = src.max_health or src.stats:get('health'); src.hp = util.clamp((src.hp or smax) - ret, 0, smax)
    end

    ctx.bus:emit('OnHitResolved', { source = src, target = tgt, damage = dealt, crit = (crit_mult > 1.0), pth = PTH })
  end
end

Effects.heal = function(p) return function(ctx, src, tgt)
    local maxhp = tgt.max_health or tgt.stats:get('health'); local amt = (p.flat or 0) +
    (p.percent_of_max and maxhp * (p.percent_of_max / 100) or 0); amt = amt *
    (1 + tgt.stats:get('healing_received_pct') / 100); tgt.hp = util.clamp((tgt.hp or maxhp) + amt, 0, maxhp); ctx.bus
        :emit('OnHealed', { source = src, target = tgt, amount = amt })
  end end
Effects.grant_barrier = function(p) return Effects.modify_stat { id = 'barrier', name = 'flat_absorb', base_add = p.amount, duration = p.duration } end
Effects.seq = function(list) return function(ctx, src, tgt) for _, e in ipairs(list) do e(ctx, src, tgt) end end end
Effects.chance = function(pct, eff) return function(ctx, src, tgt) if math.random() * 100 <= pct then eff(ctx, src, tgt) end end end
Effects.scale_by_stat = function(stat, f, build) return function(ctx, src, tgt)
    local s = src.stats:get(stat) * f; build(s)(ctx, src, tgt)
  end end

-- Custom Effects/Targeters/Triggers ----------------------------------
Effects.apply_dot = function(p) return function(ctx, src, tgt)
    tgt.dots = tgt.dots or {}; table.insert(tgt.dots,
      { type = p.type, dps = p.dps, tick = p.tick or 1.0, until_time = ctx.time.now + (p.duration or 0), next_tick = ctx
      .time.now + (p.tick or 1.0), source = src }); ctx.bus:emit('OnDotApplied', { source = src, target = tgt, dot = p })
  end end
Effects.force_counter_attack = function(p) return function(ctx, src, tgt)
    if not tgt or tgt.dead then return end
    Effects.deal_damage { weapon = true, scale_pct = p.scale_pct or 100 } (ctx, tgt, src); ctx.bus:emit(
    'OnCounterAttack', { source = tgt, target = src })
  end end
-- New targeter example already in Core: Targeters.enemies_with(predicate)
-- New trigger example: emit 'OnProvoke' from your game layer when taunted, etc.

-- Combat --------------------------------------------------------------
Combat.new = function(rr, dts) return { RR = rr, DAMAGE_TYPES = dts } end

-- Items (equip gates, minimal) ---------------------------------------
Items.equip_rules = {
  sole = { physique = { 'helm', 'shoulders', 'chest', 'gloves', 'belt', 'pants', 'boots', 'axe1', 'axe2', 'mace1', 'mace2', 'sword2', 'shield' }, cunning = { 'sword1', 'bow1', 'bow2', 'gun1', 'gun2' }, spirit = { 'offhand', 'ring', 'amulet', 'medal' } },
  with_other = { physique = { 'caster_helm', 'caster_chest', 'scepter' }, cunning = { 'dagger' }, spirit = { 'caster_helm', 'caster_chest', 'dagger', 'scepter' } },
}
function Items.can_equip(e, item)
  if not item.requires then return true end
  local req = item.requires; if e.stats:get(req.attribute) < (req.value or 0) then return false, 'attribute_too_low' end
  local allowed = Items.equip_rules[req.mode or 'sole'][req.attribute]
  if allowed then
    for _, slot in ipairs(allowed) do if slot == item.slot then return true end end; return false, 'slot_not_allowed'
  end
  return true
end

-- Leveling ------------------------------------------------------------
function Leveling.grant_exp(ctx, e, base)
  local bonus = 1 + e.stats:get('experience_gained_pct') / 100; e.xp = (e.xp or 0) + base * bonus; while e.xp >= ((e.level or 1) * 1000) do
    e.xp = e.xp - ((e.level or 1) * 1000); Leveling.level_up(ctx, e)
  end
end

function Leveling.level_up(ctx, e)
  e.level = (e.level or 1) + 1; e.attr_points = (e.attr_points or 0) + 1; e.skill_points = (e.skill_points or 0) + 3; e.masteries =
  math.min(2, (e.masteries or 0) + 1); e.stats:add_base('offensive_ability', 10); e.stats:add_base('defensive_ability',
    10); ctx.bus:emit('OnLevelUp', { entity = e })
end

-- Content (spells/traits) --------------------------------------------
Content = {}
function Content.attach_attribute_derivations(S)
  S:on_recompute(function(S)
    local p = S:get_raw('physique').base; local c = S:get_raw('cunning').base; local s = S:get_raw('spirit').base
    S:add_base('health', 100 + p * 10)
    local extra = math.max(0, p - 10); S:add_base('health_regen', extra * 0.2)
    S:add_base('offensive_ability', c * 1)
    local chunks_c = math.floor(c / 5); S:add_add_pct('physical_modifier_pct', chunks_c * 1); S:add_add_pct(
    'pierce_modifier_pct', chunks_c * 1); S:add_add_pct('bleed_duration_pct', chunks_c * 1); S:add_add_pct(
    'trauma_duration_pct', chunks_c * 1)
    S:add_base('health', s * 2); S:add_base('energy', s * 10); S:add_base('energy_regen', s * 0.5)
    local chunks_s = math.floor(s / 5)
    for _, t in ipairs({ 'fire', 'cold', 'lightning', 'acid', 'vitality', 'aether', 'chaos' }) do S:add_add_pct(
      t .. '_modifier_pct', chunks_s * 1) end
    for _, t in ipairs({ 'burn', 'frostburn', 'electrocute', 'poison', 'vitality_decay' }) do S:add_add_pct(
      t .. '_duration_pct', chunks_s * 1) end
  end)
end

Content.Spells = {
  Fireball = { name = 'Fireball', class = 'pyromancy', trigger = 'OnCast', targeter = function(ctx) return { ctx.target } end, effects = Effects.seq { Effects.deal_damage { components = { { type = 'fire', amount = 120 } } }, Effects.apply_rr { kind = 'rr1', damage = 'fire', amount = 20, duration = 4 } } },
  ViperSigil = { name = 'Viper Sigil', class = 'hex', trigger = 'OnCast', targeter = function(ctx) return Core.Targeters
    .all_enemies(ctx) end, effects = Effects.apply_rr { kind = 'rr2', damage = 'cold', amount = 20, duration = 3 } },
  ElementalStorm = { name = 'Elemental Storm', class = 'aura', trigger = 'OnCast', targeter = function(ctx) return Core
    .Targeters.all_enemies(ctx) end, effects = Effects.apply_rr { kind = 'rr3', damage = 'cold', amount = 32, duration = 2 } },
  PoisonDart = { name = 'Poison Dart', class = 'toxic', trigger = 'OnCast', targeter = function(ctx) return { ctx.target } end, effects = Effects.apply_dot { type = 'poison', dps = 20, duration = 5, tick = 1 } },
}

Content.Traits = {
  EmberStrike = { name = 'Ember Strike', class = 'weapon_proc', trigger = 'OnBasicAttack', chance = 35, targeter = function(
      ctx) return { ctx.target } end, effects = Effects.deal_damage { weapon = true, scale_pct = 60, skill_conversions = { { from = 'physical', to = 'fire', pct = 50 } } } },
  RetaliatoryInstinct = { name = 'Retaliatory Instinct', class = 'counter', trigger = 'OnHitResolved', handler = function(
      ctx)
    local ev = ctx.event; if ev and ev.target and ev.source and util.rand() * 100 < 25 then Effects.force_counter_attack { scale_pct = 50 } (
      ctx, ev.target, ev.source) end
  end },
}

-- Status engine + world tick ----------------------------------------
StatusEngine.update_entity = function(ctx, e, dt)
  -- expire timed buffs
  if e.statuses then for id, b in pairs(e.statuses) do
      local kept = {}
      for _, entry in ipairs(b.entries) do if (not entry.until_time) or entry.until_time > ctx.time.now then kept[#kept + 1] =
          entry else
          if entry.remove then entry.remove(e) end
          ctx.bus:emit('OnStatusExpired', { entity = e, id = id })
        end end
      b.entries = kept
    end end
  -- tick DoTs
  if e.dots then
    local kept = {}
    for _, d in ipairs(e.dots) do if d.until_time and d.until_time <= ctx.time.now then else
        if ctx.time.now >= (d.next_tick or ctx.time.now) then
          Effects.deal_damage { components = { { type = d.type, amount = d.dps } } } (ctx, d.source, e); d.next_tick = (d.next_tick or ctx.time.now) +
          (d.tick or 1.0)
        end
        kept[#kept + 1] = d
      end end
    e.dots = kept
  end
end

World.update = function(ctx, dt)
  ctx.time:tick(dt); local function each(L) for _, ent in ipairs(L or {}) do StatusEngine.update_entity(ctx, ent, dt) end end; each(
  ctx.side1); each(ctx.side2); ctx.bus:emit('OnTick', { dt = dt, now = ctx.time.now })
end

-- Demo ---------------------------------------------------------------
local function make_actor(name, defs, attach)
  local s = Stats.new(defs); attach(s); s:recompute(); local hp = s:get('health')
  return { name = name, stats = s, hp = hp, max_health = hp, gear_conversions = {}, tags = {}, timers = {} }
end

local Demo = {}
function Demo.run()
  math.randomseed(os.time())
  local bus = EventBus.new(); local time = Time.new(); local defs, DTS = StatDef.make(); local combat = Combat.new(RR,
    DTS)
  local ctx = {
    bus = bus,
    time = time,
    combat = combat,
    get_enemies_of = function(a) return a.side == 1 and ctx.side2 or ctx.side1 end,
    get_allies_of = function(a) return a.side == 1 and ctx.side1 or ctx.side2 end
  }

  local hero = make_actor('Hero', defs, Content.attach_attribute_derivations); hero.side = 1; hero.stats:add_base(
  'physique', 16); hero.stats:add_base('cunning', 14); hero.stats:add_base('spirit', 10); hero.stats:add_base(
  'weapon_min', 12); hero.stats:add_base('weapon_max', 18); hero.stats:add_base('life_steal_pct', 12); hero.stats
      :recompute()
  local ogre = make_actor('Ogre', defs, Content.attach_attribute_derivations); ogre.side = 2; ogre.stats:add_base(
  'health', 260); ogre.stats:add_base('defensive_ability', 95); ogre.stats:add_base('armor', 40); ogre.stats:add_base(
  'armor_absorption_bonus_pct', 20); ogre.stats:add_base('fire_resist_pct', 50); ogre.stats:recompute()
  ctx.side1 = { hero }; ctx.side2 = { ogre }

  bus:on('OnHitResolved',
    function(ev) print(string.format('[%s] hit [%s] for %.1f (crit=%s, PTH=%.1f%%)  HP: %.1f/%.1f', ev.source.name,
        ev.target.name, ev.damage, tostring(ev.crit), ev.pth, ev.target.hp, ev.target.max_health)) end)
  bus:on('OnHealed',
    function(ev) print(string.format('[%s] healed %.1f  HP: %.1f/%.1f', ev.target.name, ev.amount, ev.target.hp,
        ev.target.max_health)) end)
  bus:on('OnDotApplied',
    function(ev) print(string.format('[%s] applied DOT %s to [%s]', ev.source.name, ev.dot.type, ev.target.name)) end)
  bus:on('OnCounterAttack',
    function(ev) print(string.format('[%s] counter-attacked [%s]!', ev.source.name, ev.target.name)) end)

  -- Basic attack then Ember proc chance
  Effects.deal_damage { weapon = true, scale_pct = 100 } (ctx, hero, ogre)
  if util.rand() * 100.0 < (Content.Traits.EmberStrike.chance or 0) then Content.Traits.EmberStrike.effects(ctx, hero,
      ogre) end

  -- Cast Fireball
  local FB = Content.Spells.Fireball; for _, t in ipairs(FB.targeter({ source = hero, target = ogre, get_enemies_of = ctx.get_enemies_of })) do
    FB.effects(ctx, hero, t) end

  -- Poison Dart and advance world time to tick DoT
  local PD = Content.Spells.PoisonDart; for _, t in ipairs(PD.targeter({ source = hero, target = ogre, get_enemies_of = ctx.get_enemies_of })) do
    PD.effects(ctx, hero, t) end
  for i = 1, 6 do World.update(ctx, 1.0) end

  -- Custom trigger example: provoke
  bus:on('OnProvoke',
    function(ev)
      print(string.format('[%s] provoked [%s]!', ev.source.name, ev.target.name)); Effects.force_counter_attack { scale_pct = 40 } (
      ctx, ev.target, ev.source)
    end)
  ctx.bus:emit('OnProvoke', { source = hero, target = ogre })
end

---------------------------
-- Items & Actives: ItemSystem (equip/unequip, procs, granted actives)
---------------------------
local ItemSystem = {}

local function _listen(bus, name, fn, pr)
  bus:on(name, fn, pr)
  return function()
    local b = bus.listeners[name]; if not b then return end
    for i = #b, 1, -1 do if b[i].fn == fn then
        table.remove(b, i); break
      end end
  end
end

function ItemSystem.equip(ctx, e, item)
  local ok, err = Items.can_equip(e, item); if not ok then return false, err end
  e.equipped = e.equipped or {}
  if e.equipped[item.slot] then ItemSystem.unequip(ctx, e, item.slot) end

  -- stat mods
  item._applied = {}
  for _, m in ipairs(item.mods or {}) do
    local n = m.stat
    if m.base then
      e.stats:add_base(n, m.base); table.insert(item._applied, { 'base', n, m.base })
    end
    if m.add_pct then
      e.stats:add_add_pct(n, m.add_pct); table.insert(item._applied, { 'add_pct', n, m.add_pct })
    end
    if m.mul_pct then
      e.stats:add_mul_pct(n, m.mul_pct); table.insert(item._applied, { 'mul_pct', n, m.mul_pct })
    end
  end

  -- gear-wide conversions
  if item.conversions then
    e.gear_conversions = e.gear_conversions or {}
    item._conv_start = #e.gear_conversions
    for _, cv in ipairs(item.conversions) do table.insert(e.gear_conversions, cv) end
    item._conv_end = #e.gear_conversions
  end

  -- passive procs (event listeners)
  item._unsubs = {}
  for _, p in ipairs(item.procs or {}) do
    local handler = function(ev)
      -- default filter: only when this entity is the source
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

  -- granted actives
  if item.granted_spells then
    e.granted_spells = e.granted_spells or {}
    for _, id in ipairs(item.granted_spells) do e.granted_spells[id] = true end
  end

  e.equipped[item.slot] = item
  e.stats:recompute()
  return true
end

function ItemSystem.unequip(ctx, e, slot)
  local item = e.equipped and e.equipped[slot]; if not item then return false, 'empty_slot' end
  for _, ap in ipairs(item._applied or {}) do
    local kind, n, amt = ap[1], ap[2], ap[3]
    if kind == 'base' then
      e.stats:add_base(n, -amt)
    elseif kind == 'add_pct' then
      e.stats:add_add_pct(n, -amt)
    elseif kind == 'mul_pct' then
      e.stats:add_mul_pct(n, -amt)
    end
  end
  if item._conv_start then
    for i = item._conv_end, item._conv_start + 1, -1 do table.remove(e.gear_conversions, i) end
    item._conv_start, item._conv_end = nil, nil
  end
  for _, un in ipairs(item._unsubs or {}) do un() end
  if item.granted_spells and e.granted_spells then
    for _, id in ipairs(item.granted_spells) do e.granted_spells[id] = nil end
  end
  e.equipped[slot] = nil
  e.stats:recompute()
  return true
end

--[[ Example item (commented):
local Flamebrand = {
  id='flamebrand', slot='sword1',
  requires={attribute='cunning', value=12, mode='sole'},
  mods = {
    {stat='weapon_min', base=6}, {stat='weapon_max', base=10},
    {stat='fire_modifier_pct', add_pct=15},
  },
  conversions = { {from='physical', to='fire', pct=25} },
  procs = {
    { trigger='OnBasicAttack', chance=30,
      effects = Effects.deal_damage{ components={{type='fire', amount=40}}, tags={ability=true} } },
  },
  granted_spells = {'Fireball'},
}
-- usage: assert(ItemSystem.equip(ctx, hero, Flamebrand))
]]

---------------------------
-- Direct Casting: Cast (costs, cooldowns, OnCast emission)
---------------------------
local Cast = {}

local function _get(S, name)
  -- Stats:get returns 0 for undefined names via our fallback; this just guards nil.
  local ok = S and S.get
  if not ok then return 0 end
  return S:get(name) or 0
end

function Cast.cast(ctx, caster, spell_ref, primary_target)
  local spell = type(spell_ref) == 'string' and Content.Spells[spell_ref] or spell_ref
  if not spell then return false, 'unknown_spell' end

  caster.timers = caster.timers or {}
  local key     = 'cd:' .. (spell.id or spell.name or 'spell')
  local cd      = spell.cooldown or 0
  if not spell.item_granted then
    local cdr = _get(caster.stats, 'cooldown_reduction')
    cd = cd * math.max(0, 1 - cdr / 100)
  end
  if not ctx.time:is_ready(caster.timers, key) then return false, 'cooldown' end

  if spell.cost then
    local red = _get(caster.stats, 'skill_energy_cost_reduction')
    local cost = spell.cost * math.max(0, 1 - red / 100)
    caster.energy = caster.energy or _get(caster.stats, 'energy')
    if caster.energy < cost then return false, 'no_energy' end
    caster.energy = caster.energy - cost
  end

  -- fire uniform trigger for listeners (SAP-style "ability used")
  ctx.bus:emit('OnCast', { ctx = ctx, source = caster, spell = spell, target = primary_target })

  local tgt_list
  if primary_target then
    tgt_list = { primary_target }
  else
    tgt_list = spell.targeter({
      source = caster,
      target = primary_target,
      get_enemies_of = ctx.get_enemies_of,
      get_allies_of = ctx.get_allies_of,
    })
  end
  for _, t in ipairs(tgt_list or {}) do spell.effects(ctx, caster, t) end

  ctx.time:set_cooldown(caster.timers, key, cd)
  return true
end

local _core = dofile and package and package.loaded and package.loaded['part1_core'] or nil
if not _core then _core = (function() return Core end)() end
local _game = (function() return { Effects = Effects, Combat = Combat, Items = Items, Leveling = Leveling, Content =
  Content, StatusEngine = StatusEngine, World = World, ItemSystem = ItemSystem, Cast = Cast, Demo = Demo } end)()

return { Core = _core, Game = _game }
