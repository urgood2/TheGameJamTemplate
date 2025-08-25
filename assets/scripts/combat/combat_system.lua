
local Core = {}

local util = {}

local Effects, Combat, Items, Leveling, Content, StatusEngine, World = {}, {}, {}, {}, {}, {}, {}
local ItemSystem = {}

function util.copy(t)
  local r = {}
  for k, v in pairs(t) do
    r[k] = (type(v) == 'table') and util.copy(v) or v
  end
  return r
end

function util.shallow_copy(t)
  local r = {}
  for k, v in pairs(t) do
    r[k] = v
  end
  return r
end

function util.clamp(x, a, b)
  if x < a then return a elseif x > b then return b else return x end
end

function util.rand() return math.random() end

function util.choice(list) return list[math.random(1, #list)] end

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

local function get_spell_id(spell_ref)
  local s = (type(spell_ref) == 'table') and spell_ref or Content.Spells[spell_ref]
  return (s and (s.id or s.name)) or tostring(spell_ref)
end

local function is_item_granted(caster, spell_ref)
  local id = get_spell_id(spell_ref)
  return caster and caster.granted_spells and caster.granted_spells[id] == true
end

local function get_ability_level(e, spell_ref)
  local id = get_spell_id(spell_ref)
  return (e.ability_levels and e.ability_levels[id]) or 1
end

local function set_ability_level(e, spell_ref, lvl)
  e.ability_levels = e.ability_levels or {}
  e.ability_levels[get_spell_id(spell_ref)] = math.max(1, math.floor(lvl or 1))
end

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

local function apply_spell_mutators(caster, ctx, spell_ref, effects_fn)
  local id = get_spell_id(spell_ref)
  local muts = caster and caster.spell_mutators and caster.spell_mutators[id]

  if muts and #muts > 0 then
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
  local function fmt_pct(n) return string.format("%d%%", math.floor(G(n) + 0.5)) end
  local function nonzero(v) return v ~= 0 and v ~= nil end
  local function join(arr, sep)
    local s, t = "", arr or {}
    for i = 1, #t do
      s = s .. (i > 1 and (sep or " ") or "") .. tostring(t[i])
    end
    return s
  end

  local lines = {}
  local function add(line) lines[#lines + 1] = line end

  local name = e.name or "Entity"
  local maxhp = e.max_health or G("health")
  local hp = e.hp or maxhp
  add(("==== %s ===="):format(name))
  local maxe = e.max_energy or G("energy")
  local ene  = (e.energy ~= nil) and e.energy or maxe
  add(("HP %d/%d | Energy %.0f/%.0f"):format(
    math.floor(hp + 0.5), math.floor(maxhp + 0.5), ene, maxe))

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

  do
    local eq = e.equipped or {}
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

  do
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

  add("Attr   | " .. join({
    ("physique=%d"):format(gi("physique")),
    ("cunning=%d"):format(gi("cunning")),
    ("spirit=%d"):format(gi("spirit")),
  }, "  "))

  add("Off    | " .. join({
    ("OA=%d"):format(gi("offensive_ability")),
    ("AtkSpd=%.1f"):format(gf("attack_speed")),
    ("CastSpd=%.1f"):format(gf("cast_speed")),
    ("CritDmg=%s"):format(fmt_pct("crit_damage_pct")),
    ("Wpn=%d-%d"):format(gi("weapon_min"), gi("weapon_max")),
  }, "  "))

  local block_line = ("Block=%s/%d"):format(fmt_pct("block_chance_pct"), gi("block_amount"))
  add("Def    | " .. join({
    ("DA=%d"):format(gi("defensive_ability")),
    ("Armor=%d"):format(gi("armor")),
    block_line,
    ("Dodge=%s"):format(fmt_pct("dodge_chance_pct")),
    ("Absorb=%%=%s flat=%d"):format(fmt_pct("percent_absorb_pct"), gi("flat_absorb")),
  }, "  "))

  do
    local mods = {}
    for _, t in ipairs(Core.DAMAGE_TYPES) do
      local v = G(t .. "_modifier_pct")
      if nonzero(v) then mods[#mods + 1] = ("%s=%d%%"):format(t, math.floor(v + 0.5)) end
    end
    if #mods > 0 then add("DmgMod | " .. join(mods, "  ")) end
  end

  do
    local res = {}
    for _, t in ipairs(Core.DAMAGE_TYPES) do
      local v = G(t .. "_resist_pct")
      if nonzero(v) then res[#res + 1] = ("%s=%d%%"):format(t, math.floor(v + 0.5)) end
    end
    if #res > 0 then add("Resist | " .. join(res, "  ")) end
  end
  
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

  local cvs = {}
  local list = e.gear_conversions or {}
  for i = 1, #list do
    local c = list[i]
    cvs[#cvs + 1] = string.format("%s->%s:%d%%", c.from, c.to, c.pct or 0)
  end
  if #cvs > 0 then add("Conv   | " .. join(cvs, "  ")) end

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

  do
    local parts = {}

    local desired = e.skills and e.skills.toggled_exclusive or nil
    if desired then parts[#parts + 1] = "desired=" .. tostring(desired) end

    local active = e._active_exclusive and e._active_exclusive.id or nil
    if active then parts[#parts + 1] = "active=" .. tostring(active) end

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

  add(("============"):rep(2))
  print(table.concat(lines, "\n"))
end

Core.util = util

function Core.on(ctx, ev, fn, pr)
  local bus = ctx.bus
  bus:on(ev, fn, pr)
  return function()
    local b = bus.listeners[ev]
    if not b then return end
    for i = #b, 1, -1 do if b[i].fn == fn then
        table.remove(b, i)
        break
      end end
  end
end

function Core.hook(ctx, evname, opts)
  local pr = opts.pr or 0
  local fn = function(ev)
    if opts.filter and not opts.filter(ev) then return end
    if opts.condition and not opts.condition(ctx, ev) then return end
    if opts.icd then
      opts._next = opts._next or 0
      if ctx.time.now < opts._next then return end
      opts._next = ctx.time.now + opts.icd
    end
    return opts.run(ctx, ev)
  end
  ctx.bus:on(evname, fn, pr)
  return function()
    local b = ctx.bus.listeners[evname]; if not b then return end
    for i=#b,1,-1 do if b[i].fn == fn then table.remove(b,i); break end end
  end
end

local EventBus = {}
EventBus.__index = EventBus

function EventBus.new()
  return setmetatable({ listeners = {} }, EventBus)
end

function EventBus:on(name, fn, pr)
  local bucket = self.listeners[name] or {}
  table.insert(bucket, { fn = fn, pr = pr or 0 })
  table.sort(bucket, function(a, b) return a.pr < b.pr end)
  self.listeners[name] = bucket
end

function EventBus:emit(name, ctx)
  local bucket = self.listeners[name]
  if not bucket then return end
  for i = 1, #bucket do
    bucket[i].fn(ctx)
  end
end

Core.EventBus = EventBus

local Time = {}
Time.__index = Time

function Time.new()
  return setmetatable({ now = 0 }, Time)
end

function Time:tick(dt)
  self.now = self.now + dt
end

function Time:is_ready(tbl, key)
  return (tbl[key] or -1) <= self.now
end

function Time:set_cooldown(tbl, key, d)
  tbl[key] = self.now + d
end

Core.Time = Time



local StatDef = {}

local DAMAGE_TYPES = {
  'physical', 'pierce', 'bleed', 'trauma',
  'fire', 'cold', 'lightning', 'acid',
  'vitality', 'aether', 'chaos',
  'burn', 'frostburn', 'electrocute', 'poison', 'vitality_decay'
}

local function add_basic(defs, name)
  defs[name] = { base = 0, add_pct = 0, mul_pct = 0 }
end

function StatDef.make()
  local defs = {}

  add_basic(defs, 'physique')
  add_basic(defs, 'cunning')
  add_basic(defs, 'spirit')

  add_basic(defs, 'offensive_ability')
  add_basic(defs, 'defensive_ability')
  add_basic(defs, 'level')
  add_basic(defs, 'experience_gained_pct')

  add_basic(defs, 'health')
  add_basic(defs, 'health_regen')
  add_basic(defs, 'energy')
  add_basic(defs, 'energy_regen')

  add_basic(defs, 'attack_speed')
  add_basic(defs, 'cast_speed')
  add_basic(defs, 'run_speed')
  add_basic(defs, 'crit_damage_pct')
  add_basic(defs, 'all_damage_pct')

  add_basic(defs, 'weapon_min')
  add_basic(defs, 'weapon_max')
  add_basic(defs, 'weapon_damage_pct')
  add_basic(defs, 'block_chance_pct')
  add_basic(defs, 'block_amount')
  add_basic(defs, 'block_recovery_reduction_pct')

  add_basic(defs, 'dodge_chance_pct')
  add_basic(defs, 'deflect_chance_pct')
  add_basic(defs, 'percent_absorb_pct')
  add_basic(defs, 'flat_absorb')

  add_basic(defs, 'armor')
  add_basic(defs, 'armor_absorption_bonus_pct')

  add_basic(defs, 'life_steal_pct')
  add_basic(defs, 'healing_received_pct')

  for _, dt in ipairs(DAMAGE_TYPES) do
    add_basic(defs, dt .. '_damage')
    add_basic(defs, dt .. '_modifier_pct')
    add_basic(defs, dt .. '_resist_pct')

    if dt == 'bleed' or dt == 'trauma'
        or dt == 'burn' or dt == 'frostburn'
        or dt == 'electrocute' or dt == 'poison'
        or dt == 'vitality_decay' then
      add_basic(defs, dt .. '_duration_pct')
    end
  end

  add_basic(defs, 'reflect_damage_pct')
  for _, dt in ipairs(DAMAGE_TYPES) do
    add_basic(defs, 'retaliation_' .. dt)
    add_basic(defs, 'retaliation_' .. dt .. '_modifier_pct')
  end

  for _, cc in ipairs({
    'stun', 'disruption', 'leech_life', 'leech_energy',
    'trap', 'petrify', 'freeze', 'sleep', 'slow', 'reflect'
  }) do
    add_basic(defs, cc .. '_resist_pct')
  end

  add_basic(defs, 'cooldown_reduction')
  add_basic(defs, 'skill_energy_cost_reduction')
  
  add_basic(defs, 'penetration_all_pct')
  for _, dt in ipairs(DAMAGE_TYPES) do
    add_basic(defs, 'penetration_' .. dt .. '_pct')
  end

  add_basic(defs, 'max_resist_cap_pct')
  add_basic(defs, 'min_resist_cap_pct')
  for _, dt in ipairs(DAMAGE_TYPES) do
    add_basic(defs, 'max_' .. dt .. '_resist_cap_pct')
    add_basic(defs, 'min_' .. dt .. '_resist_cap_pct')
  end

  add_basic(defs, 'damage_taken_reduction_pct')
  for _, dt in ipairs(DAMAGE_TYPES) do
    add_basic(defs, 'damage_taken_' .. dt .. '_reduction_pct')
  end

  add_basic(defs, 'armor_penetration_pct')


  return defs, DAMAGE_TYPES
end

local Stats = {}
Stats.__index = Stats

function Stats.new(defs)
  local t = {
    defs = defs,
    values = {},
    derived_hooks = {},
    _derived_marks = {},
  }
  for n, d in pairs(defs) do
    t.values[n] = { base = d.base, add_pct = 0, mul_pct = 0 }
  end
  return setmetatable(t, Stats)
end

function Stats:_mark(kind, n, amt)
  self._derived_marks[#self._derived_marks + 1] = { kind, n, amt }
end

function Stats:derived_add_base(n, a)
  self.values[n].base = self.values[n].base + a; self:_mark('base', n, a)
end

function Stats:derived_add_add_pct(n, a)
  self.values[n].add_pct = self.values[n].add_pct + a; self:_mark('add_pct', n, a)
end

function Stats:derived_add_mul_pct(n, a)
  self.values[n].mul_pct = self.values[n].mul_pct + a; self:_mark('mul_pct', n, a)
end

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

function Stats:get_raw(n)
  return self.values[n]
end

function Stats:get(n)
  local v = self.values[n] or { base = 0, add_pct = 0, mul_pct = 0 }
  return v.base * (1 + v.add_pct / 100) * (1 + v.mul_pct / 100)
end

function Stats:add_base(n, a)
  self.values[n].base = self.values[n].base + a
end

function Stats:add_add_pct(n, a)
  self.values[n].add_pct = self.values[n].add_pct + a
end

function Stats:add_mul_pct(n, a)
  self.values[n].mul_pct = self.values[n].mul_pct + a
end

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

function Stats:recompute()
  self:_clear_derived()
  for _, fn in ipairs(self.derived_hooks) do
    fn(self)
  end
end

local RR = {}

local function pick_highest(tbl)
  local best = nil
  for _, e in ipairs(tbl) do
    if (not best) or e.amount > best.amount then
      best = e
    end
  end
  return best
end

function RR.apply_all(base, list)
  local r = base
  local rr1, rr2, rr3 = {}, {}, {}

  for _, e in ipairs(list or {}) do
    if e.kind == 'rr1' then
      rr1[#rr1 + 1] = e
    elseif e.kind == 'rr2' then
      rr2[#rr2 + 1] = e
    elseif e.kind == 'rr3' then
      rr3[#rr3 + 1] = e
    end
  end

  local sum1 = 0
  for _, e in ipairs(rr1) do
    sum1 = sum1 + e.amount
  end
  r = r - sum1

  if #rr2 > 0 then
    local hi = pick_highest(rr2)
    r = r * (1 - hi.amount / 100)
    if r < 0 then r = 0 end
  end

  if #rr3 > 0 then
    r = r - pick_highest(rr3).amount
  end

  return r
end

local Conv = {}

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

  for k, v in pairs(map) do
    out[k] = v
  end
  return out
end

function Conv.apply(components, skill_bucket, gear_bucket)
  local m = {}
  for _, c in ipairs(components) do
    m[c.type] = (m[c.type] or 0) + c.amount
  end

  m = apply_bucket(m, skill_bucket)
  m = apply_bucket(m, gear_bucket)

  local out = {}
  for t, amt in pairs(m) do
    out[#out + 1] = { type = t, amount = amt }
  end
  return out
end


local Targeters = {}

function Targeters.self(ctx)
  return { ctx.source }
end

function Targeters.target_enemy(ctx)
  return { ctx.target }
end

function Targeters.all_enemies(ctx)
  return util.copy(ctx.get_enemies_of(ctx.source))
end

function Targeters.all_allies(ctx)
  return util.copy(ctx.get_allies_of(ctx.source))
end

function Targeters.random_enemy(ctx)
  local es = ctx.get_enemies_of(ctx.source)
  if #es == 0 then return {} end
  return { util.choice(es) }
end

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


local Cond = {}

function Cond.always() return true end

function Cond.has_tag(tag)
  return function(e)
    return e.tags and e.tags[tag]
  end
end

function Cond.stat_below(stat, th)
  return function(e)
    return e.stats:get(stat) < th
  end
end

function Cond.chance(pct)
  return function(ctx, ev, src, tgt) return math.random() * 100 <= pct end
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





local util, EventBus, Time, StatDef, Stats, RR, Conv, Targeters, Cond, DAMAGE_TYPES =
    Core.util, Core.EventBus, Core.Time, Core.StatDef, Core.Stats, Core.RR, Core.Conv, Core.Targeters, Core.Cond,
    Core.DAMAGE_TYPES


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


Effects.par = function(list)
  return function(ctx, src, tgt)
    for i = 1, #list do list[i](ctx, src, tgt) end
  end
end

Effects.cleanse = function(p)
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
            ctx.bus:emit('OnStatusExpired', { entity = tgt, id = id })
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

Effects.cast_spell = function(p)
  return function(ctx, src, tgt)
    local spell_id = p.id
    if not spell_id then return end

    local ov = src._item_skill_overrides and src._item_skill_overrides[spell_id] or nil
    local wpct = p.weapon_pct or (ov and ov.weapon_pct) or 0

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
Effects.status = function(def)
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



Effects.resurrect = function(p)
  return function(ctx, src, tgt)
    if tgt.dead then
      tgt.dead = false
      local maxhp = tgt.max_health or tgt.stats:get('health')
      tgt.hp = maxhp * ((p.hp_pct or 50) / 100)
      ctx.bus:emit('OnResurrect', { source = src, target = tgt, hp = tgt.hp })
    end
  end
end

Effects.summon = function(p)
  return function(ctx, src, tgt)
    if not ctx.spawn_entity then return end
    for i = 1, (p.count or 1) do ctx.spawn_entity(ctx, p.blueprint, p.side_of == 'target' and tgt or src) end
  end
end

Effects.grant_extra_turn = function(p)
  return function(ctx, src, tgt)
    ctx.bus:emit('OnExtraTurnGranted', { entity = tgt or src })
  end
end

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


Effects._entry_of = Effects._entry_of or setmetatable({}, { __mode = "k" })


Effects.modify_stat = function(p)
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
  end

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

Effects.deal_damage = function(p)
  return function(ctx, src, tgt)
    local reason = p.reason or "unknown"
    local tags   = p.tags or {}

    local function dbg(fmt, ...)
      if ctx.debug then print(string.format("[DEBUG][deal_damage] " .. fmt, ...)) end
    end

    local function _round1(x) return (x ~= nil) and tonumber(string.format("%.1f", x)) or x end

    local function _comps_to_string(comps)
      if not ctx.debug then return "" end
      local tmp = {}
      for i = 1, #comps do
        local c = comps[i]
        tmp[#tmp + 1] = string.format("%s=%0.1f", tostring(c.type), _round1(c.amount))
      end
      table.sort(tmp)
      return table.concat(tmp, ", ")
    end

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
        local tleft = (r.until_time and (r.until_time - ctx.time.now)) or nil
        if tleft and tleft < 0 then tleft = 0 end
        parts[#parts + 1] = string.format("%s:%s=%0.1f%s",
          tostring(r.kind), tostring(r.damage), _round1(r.amount),
          tleft and string.format(" (%.1fs)", _round1(tleft)) or "")
      end
      return table.concat(parts, ", ")
    end

    local comps = {}

    if p.weapon then
      local min         = src.stats:get('weapon_min')
      local max         = src.stats:get('weapon_max')
      local base        = math.random() * (max - min) + min
      local scale       = (p.scale_pct or 100) / 100

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

    comps = Conv.apply(comps, p.skill_conversions, src.gear_conversions)
    dbg("After conversions: %s", _comps_to_string(comps))

    local function pth(OA, DA)
      local term1 = 3.15 * (OA / (3.5 * OA + DA))
      local term2 = 0.0002275 * (OA - DA)
      return (term1 + term2 + 0.2) * 100
    end

    local OA  = src.stats:get('offensive_ability')
    local DA  = tgt.stats:get('defensive_ability')
    local PTH = util.clamp(pth(OA, DA), 60, 140)
    dbg("Hit check: OA=%.1f DA=%.1f PTH=%.1f%%", OA, DA, PTH)

    if math.random() * 100 > PTH then
      dbg("Attack missed!")
      ctx.bus:emit('OnMiss', { source = src, target = tgt, pth = PTH })
      return
    end

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

    local dodge = tgt.stats:get('dodge_chance_pct') or 0
    if math.random() * 100 < dodge then
      dbg("Target dodged!")
      ctx.bus:emit('OnDodge', { source = src, target = tgt, pth = PTH })
      return
    end

    tgt.timers      = tgt.timers or {}
    local blocked   = false
    local block_amt = 0
    local blk_chance = (tgt.stats:get('block_chance_pct') or 0)
                       - (src.stats:get('block_chance_pierce_pct') or 0)
    blk_chance = math.max(0, blk_chance)

    if ctx.time:is_ready(tgt.timers, 'block')
        and math.random() * 100 < blk_chance then
      blocked    = true
      block_amt  = tgt.stats:get('block_amount')

      local blk_amt_pierce = (src.stats:get('block_amount_pierce_pct') or 0)
      if blk_amt_pierce ~= 0 then
        block_amt = block_amt * math.max(0, 1 - blk_amt_pierce / 100)
      end

      local base = 1.0
      local rec  = base * (1 - tgt.stats:get('block_recovery_reduction_pct') / 100)
      ctx.time:set_cooldown(tgt.timers, 'block', math.max(0.1, rec))
      dbg("Block triggered: chance=%.1f%% amt=%.1f next_ready=%.2f",
        blk_chance, block_amt, tgt.timers['block'] or -1)
    end

    local sums = {}
    for _, c in ipairs(comps) do
      sums[c.type] = (sums[c.type] or 0) + c.amount
    end
    for t, amt in pairs(sums) do
      sums[t] = amt * crit_mult
    end
    dbg("Post-crit sums: %s", _sums_to_string(sums))

    local allpct = 1 + src.stats:get('all_damage_pct') / 100
    for t, amt in pairs(sums) do
      sums[t] = amt * allpct * (1 + src.stats:get(t .. '_modifier_pct') / 100)
    end
    dbg("After attacker mods: %s", _sums_to_string(sums))

    local dealt = 0

    for t, amt in pairs(sums) do
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

      if t == 'physical' then
        local armor = tgt.stats:get('armor')
        local apen  = (src.stats:get('armor_penetration_pct') or 0)
        local armor_eff = armor * math.max(0, 1 - apen / 100)
        local abs   = 0.70 * (1 + tgt.stats:get('armor_absorption_bonus_pct') / 100)
        local mit   = math.min(amt, armor_eff) * abs
        amt         = amt - mit
        dbg("  Armor: armor=%.1f apen=%.1f%% eff=%.1f abs=%.2f mit=%.1f remain=%.1f",
            armor, apen, armor_eff, abs, mit, amt)
      end

      local pen_all = (src.stats:get('penetration_all_pct') or 0)
      local pen_t   = (src.stats:get('penetration_' .. t .. '_pct') or 0)
      local pen     = pen_all + pen_t

      local max_cap = 100 + (tgt.stats:get('max_resist_cap_pct') or 0)
                           + (tgt.stats:get('max_' .. t .. '_resist_cap_pct') or 0)
      local min_cap = -100 + (tgt.stats:get('min_resist_cap_pct') or 0)
                            + (tgt.stats:get('min_' .. t .. '_resist_cap_pct') or 0)

      local res_after_pen = res_after_rr - pen
      local res_final     = util.clamp(res_after_pen, min_cap, max_cap)

      dbg("Type %s: start=%.1f base_res=%.1f after_rr=%.1f pen=%.1f caps=[%d,%d] -> final_res=%.1f | RR: %s",
          t, amt, base_res, res_after_rr, pen, math.floor(max_cap+0.5), math.floor(min_cap+0.5),
          res_final, _rr_bucket_to_string(alive_rr))

      local after_resisted = amt * (1 - res_final / 100)

      local dr_t = (tgt.stats:get('damage_taken_' .. t .. '_reduction_pct') or 0)
      local dr_g = (tgt.stats:get('damage_taken_reduction_pct') or 0)
      local after_dr = after_resisted * (1 - dr_t / 100) * (1 - dr_g / 100)

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

    local maxhp = tgt.max_health or tgt.stats:get('health')
    tgt.hp = util.clamp((tgt.hp or maxhp) - dealt, 0, maxhp)
    dbg("Damage dealt total=%.1f, Target HP=%.1f/%.1f", dealt, tgt.hp, maxhp)

    if tgt.hp <= 0 and not tgt.dead then
      tgt.dead = true
      ctx.bus:emit('OnDeath', { entity = tgt, killer = src })
    end

    local ls = src.stats:get('life_steal_pct') or 0
    if ls > 0 then
      local heal = dealt * (ls / 100)
      local smax = src.max_health or src.stats:get('health')
      src.hp = util.clamp((src.hp or smax) + heal, 0, smax)
      dbg("Lifesteal: +%.1f, Attacker HP=%.1f/%.1f", heal, src.hp, smax)
    end

    local ref = tgt.stats:get('reflect_damage_pct') or 0
    if ref > 0 then
      local re   = dealt * (ref / 100)
      local smax = src.max_health or src.stats:get('health')
      src.hp     = util.clamp((src.hp or smax) - re, 0, smax)
      dbg("Reflect: -%.1f, Attacker HP=%.1f/%.1f", re, src.hp, smax)
    end


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
      Effects.deal_damage { components = ret_components } (ctx, tgt, src)
    end

    ctx.bus:emit('OnHitResolved', {
      source     = src,
      target     = tgt,
      damage     = dealt,
      did_damage = (dealt or 0) > 0,
      crit       = (crit_mult > 1.0) or false,
      pth        = PTH or nil,
      reason     = reason,
      tags       = tags,
      components = sums,
    })
  end
end

Effects.heal = function(p)
  return function(ctx, src, tgt)
    local maxhp = tgt.max_health or tgt.stats:get('health')
    local amt   = (p.flat or 0) + (p.percent_of_max and maxhp * (p.percent_of_max / 100) or 0)
    amt         = amt * (1 + tgt.stats:get('healing_received_pct') / 100)

    tgt.hp      = util.clamp((tgt.hp or maxhp) + amt, 0, maxhp)
    ctx.bus:emit('OnHealed', { source = src, target = tgt, amount = amt })
  end
end

Effects.grant_barrier = function(p)
  return Effects.modify_stat {
    id       = 'barrier',
    name     = 'flat_absorb',
    base_add = p.amount,
    duration = p.duration
  }
end

Effects.seq = function(list)
  return function(ctx, src, tgt)
    for _, e in ipairs(list) do
      e(ctx, src, tgt)
    end
  end
end

Effects.chance = function(pct, eff)
  return function(ctx, src, tgt)
    if math.random() * 100 <= pct then
      eff(ctx, src, tgt)
    end
  end
end

Effects.scale_by_stat = function(stat, f, build)
  return function(ctx, src, tgt)
    local s = src.stats:get(stat) * f
    build(s)(ctx, src, tgt)
  end
end


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

Effects.force_counter_attack = function(p)
  p = p or {}
  local scale = p.scale_pct or 100

  return function(ctx, src, tgt)
    if not src or src.dead or not tgt or tgt.dead then return end

    Effects.deal_damage { weapon = true, scale_pct = scale } (ctx, src, tgt)

    if ctx and ctx.bus and ctx.bus.emit then
      ctx.bus:emit('OnCounterAttack', { source = src, target = tgt, scale_pct = scale, is_counter = true })
    end
  end
end


Combat.new = function(rr, dts)
  return { RR = rr, DAMAGE_TYPES = dts }
end

function Combat.get_penetration(src, t)
  return ((src.stats:get('penetration_all_pct') or 0) + (src.stats:get('penetration_'..t..'_pct') or 0))
end

function Combat.get_caps(def, t)
  local max_cap = 100 + (def.stats:get('max_resist_cap_pct') or 0)
                       + (def.stats:get('max_'..t..'_resist_cap_pct') or 0)
  local min_cap = -100 + (def.stats:get('min_resist_cap_pct') or 0)
                        + (def.stats:get('min_'..t..'_resist_cap_pct') or 0)
  return min_cap, max_cap
end


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

  return true
end

function Items.upgrade(ctx, e, item, spec)
  item.level = (item.level or 0) + (spec.level_up or 0)
  for _, m in ipairs(spec.add_mods or {}) do
    item.mods = item.mods or {}
    table.insert(item.mods, m)
  end
  if e and e.equipped and e.equipped[item.slot] == item then
    ItemSystem.unequip(ctx, e, item.slot)
    ItemSystem.equip(ctx, e, item)
  end
  return item
end


Leveling.curves = Leveling.curves or {}

function Leveling.register_curve(id, fn)
  Leveling.curves[id] = fn
end

function Leveling.xp_to_next(ctx, e, L)
  local level = L or (e.level or 1)
  local curve_id = e.level_curve or 'default'
  local fn = Leveling.curves[curve_id] or Leveling.curves['default']
  return (fn and fn(level)) or (1000 * level)
end

Leveling.register_curve('default', function(level)
  return 1000 * level
end)

Leveling.register_curve('fast_start', function(level)
  return math.floor(600 + (level - 1) * 800)
end)

Leveling.register_curve('veteran', function(level)
  return math.floor(1200 + (level - 1) * 1100)
end)

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
      Leveling.level_up(ctx, e)
      e.level = e.level or (levels_gained + 2)
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

Content = {}

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

Content.Spells = {

  Fireball = {
    id           = 'Fireball',
    name         = 'Fireball',
    class        = 'pyromancy',
    trigger      = 'OnCast',
    item_granted = true,
    targeter     = function(ctx) return { ctx.target } end,

    build        = function(level, mods)
      level           = level or 1
      mods            = mods or { dmg_pct = 0 }

      local base      = 120 + (level - 1) * 40
      local rr        = 20 + (level - 1) * 5
      local dmg_scale = 1 + (mods.dmg_pct or 0) / 100


      return function(ctx, src, tgt)
        Effects.deal_damage { components = { { type = 'fire', amount = base * dmg_scale } } } (ctx, src, tgt)
        Effects.apply_rr { kind = 'rr1', damage = 'fire', amount = rr, duration = 4 } (ctx, src, tgt)
      end
    end,

    effects      = function(ctx, src, tgt)
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

Content.Traits = {
  EmberStrike = {
    name     = 'Ember Strike',
    class    = 'weapon_proc',
    trigger  = 'OnBasicAttack',
    chance   = 35,
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

function ItemSystem.equip(ctx, e, item)
  if ctx.debug then
    print(string.format("[DEBUG][ItemSystem] Attempting to equip item '%s' into slot '%s'", item.id or "?",
      item.slot or "?"))
  end

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
  
  if type(item.on_equip) == "function" then
    item._cleanup = item.on_equip(ctx, e) or item._cleanup
  end


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

  item._unsubs = {}
  for _, p in ipairs(item.procs or {}) do
    local handler = function(ev)
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


  if item.spell_mutators then
    e.spell_mutators = e.spell_mutators or {}
    item._mut_applied = {}

    for spell_key, list in pairs(item.spell_mutators) do
      local sid = get_spell_id(spell_key)
      local bucket = e.spell_mutators[sid]
      if not bucket then
        bucket = {}
        e.spell_mutators[sid] = bucket
      end

      for _, entry in ipairs(list) do
        local mut
        if type(entry) == 'function' then
          mut = { pr = 0, wrap = entry }
        else
          mut = { pr = entry.pr or 0, wrap = entry.wrap }
        end
        table.insert(bucket, mut)
        item._mut_applied[#item._mut_applied + 1] = { sid = sid, ref = mut }
      end
    end
  end


  if item.granted_spells then
    e.granted_spells = e.granted_spells or {}
    for _, id in ipairs(item.granted_spells) do
      e.granted_spells[id] = true
      if ctx.debug then
        print(string.format("[DEBUG][ItemSystem] Granted spell: %s", id))
      end
    end
  end

  e.equipped[item.slot] = item
  e.stats:recompute()
  if ctx.debug then
    print(string.format("[DEBUG][ItemSystem] Equipped '%s' into slot '%s'. Stats recomputed.", item.id or "?",
      item.slot or "?"))
  end
  return true
end

function ItemSystem.unequip(ctx, e, slot)
  local item = e.equipped and e.equipped[slot]
  if not item then return false, 'empty_slot' end

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
    for i = item._conv_end, item._conv_start + 1, -1 do
      table.remove(e.gear_conversions, i)
    end
    item._conv_start, item._conv_end = nil, nil
  end

  if item._mut_applied and e.spell_mutators then
    for i = 1, #item._mut_applied do
      local rec = item._mut_applied[i]
      local bucket = e.spell_mutators[rec.sid]
      if bucket then
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

  for _, un in ipairs(item._unsubs or {}) do
    un()
  end

  if item.granted_spells and e.granted_spells then
    for _, id in ipairs(item.granted_spells) do
      e.granted_spells[id] = nil
    end
  end
  
  if type(item._cleanup) == "function" then
    pcall(item._cleanup, e); item._cleanup = nil
  end
  if type(item.on_unequip) == "function" then
    pcall(item.on_unequip, ctx, e)
  end


  e.equipped[slot] = nil
  e.stats:recompute()
  return true
end




local Cast = {}

local function _get(S, name)
  local ok = S and S.get
  if not ok then return 0 end
  return S:get(name) or 0
end

function Cast.cast(ctx, caster, spell_ref, primary_target)
  local spell = (type(spell_ref) == 'table') and spell_ref or Content.Spells[spell_ref]
  if not spell then return false, 'unknown_spell' end

  local spell_id = get_spell_id(spell)
  caster.timers  = caster.timers or {}
  local key      = 'cd:' .. spell_id
  local cd       = spell.cooldown or 0

  local lvl      = get_ability_level(caster, spell)
  local mods     = collect_ability_mods(caster, spell)

  if not is_item_granted(caster, spell) then
    local cdr = _get(caster.stats, 'cooldown_reduction')
    cd = cd * math.max(0, 1 - cdr / 100)
  end
  cd = math.max(0, cd + (mods.cd_add or 0))

  if not ctx.time:is_ready(caster.timers, key) then
    return false, 'cooldown'
  end

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
    spell_id = spell_id,
    target   = primary_target
  })

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

  local eff = spell.effects
  if spell.build then
    eff = spell.build(lvl, mods)
  end
  eff = apply_spell_mutators(caster, ctx, spell, eff)

  for _, t in ipairs(tgt_list or {}) do
    eff(ctx, caster, t)
  end

  ctx.time:set_cooldown(caster.timers, key, cd)
  return true
end

local Skills = {}


local function _lerp(a, b, t) return a + (b - a) * t end
local function _dim_return(x, knee, min_mult)
  if x <= knee then return 1 end
  local over = x - knee
  return math.max(min_mult or 0.5, 1 / (1 + 0.15 * over))
end

Skills.DB = {
  FireStrike = {
    id = 'FireStrike',
    kind = 'active',
    is_dar = true,
    soft_cap = 12,
    ult_cap = 26,
    scale       = function(rank)
      local m = _dim_return(rank, 12, 0.6)
      local flat = 6 + 2.5 * rank
      local wpn = 100 + 8 * rank
      return { flat_fire = flat * m, weapon_scale_pct = wpn * m }
    end,
    wps_unlocks = {
      AmarastasQuickCut = { min_rank = 4, chance = 20 },
    },
    energy_cost = function(rank) return 0 end,
    cooldown    = function(rank) return 0 end,
  },

  ExplosiveStrike = {
    id = 'ExplosiveStrike',
    kind = 'modifier',
    base = 'FireStrike',
    soft_cap = 12,
    ult_cap = 22,
    apply_mutator = function(rank)
      local radius = 1.8 + 0.05 * rank
      local pct    = 30 + 3 * rank
      return function(orig)
        return function(ctx, src, tgt)
          if orig then orig(ctx, src, tgt) end
          local allies = ctx.get_enemies_of(src)
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

  SearingStrike = {
    id = 'SearingStrike',
    kind = 'transmuter',
    base = 'FireStrike',
    exclusive = true,
    apply_mutator = function()
      return function(orig)
        return function(ctx, src, tgt)
          Effects.deal_damage {
            weapon = true, scale_pct = 100,
            skill_conversions = { { from = 'physical', to = 'fire', pct = 100 } }
          } (ctx, src, tgt)
          if orig then orig(ctx, src, tgt) end
        end
      end
    end
  },

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

  PossessionLike = {
    id = 'PossessionLike',
    kind = 'exclusive_aura',
    reservation_pct = 25,
    apply_aura = function(ctx, src, rank)
      return Effects.modify_stat { id = 'possess_aura', name = 'chaos_modifier_pct', add_pct_add = 8 + 2 * rank }
    end
  },

  Overheat = {
    id               = 'Overheat',
    kind             = 'passive',
    charges          = {
      id = 'Heat',
      max = 10,
      decay = 2,
      derived = function(S, e, stacks)
        S:derived_add_add_pct('fire_modifier_pct', 2 * stacks)
      end,
      on_change = function(e, stacks)
        e.stats:recompute()
      end,
      on_remove = function(e)
      end
    }
    
  },
    OverheatWithRank = { id = 'Overheat', kind = 'passive', 
      charges = function(rank) 
      rank = tonumber(rank) or 0
      return { id = 'Heat', max = 8 +
      math.floor(rank / 2), decay = 2, derived = function(S, e, s) S:derived_add_add_pct('fire_modifier_pct', 1.5 * s) end, on_change = function(
          e) e.stats:recompute() end } end }

}

local SkillTree = {}

function SkillTree.create_state()
  return {
    ranks = {},
    enabled_transmuter = {},
    toggled_exclusive = nil,
    dar_override = nil,
    _mutators = {},
    _passive_marks = {},
  }
end

local function _apply_passive(e, id, rank, node)
  local S = e.stats; if not S then return end
  local before = { #S._derived_marks }
  if node.apply_stats then node.apply_stats(S, rank) end
  e.skills._passive_marks[id] = { start = before[1] + 1 }
  S:recompute()
end

local function _clear_passive(e, id)
  local mark = e.skills._passive_marks[id]; if not mark then return end
end

local function _attach_mutator(e, base_id, wrap)
  e.spell_mutators = e.spell_mutators or {}
  local bucket = e.spell_mutators[base_id] or {}
  e.spell_mutators[base_id] = bucket
  local rec = { pr = 0, wrap = wrap }
  bucket[#bucket + 1] = rec
  e.skills._mutators[base_id] = e.skills._mutators[base_id] or {}
  table.insert(e.skills._mutators[base_id], rec)
end

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

local Charges = {}

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

  if node.is_dar and rank > 0 then
    e.skills.dar_override = id
  end
  
  if node.charges then
    e.skills = e.skills or {}
    e.skills._charge_handles = e.skills._charge_handles or {}

    local old = e.skills._charge_handles[id]
    if old then old.remove(); e.skills._charge_handles[id] = nil end

    if rank > 0 then
      e.skills._charge_handles[id] =
        Charges.add_track(e, node, nil, nil, nil, { rank = rank })
    end
  end

  return true
end

function SkillTree.enable_transmuter(e, id)
  local node = Skills.DB[id]; if not (node and node.kind == 'transmuter') then return false, 'not_transmuter' end
  e.skills.enabled_transmuter[node.base] = id
  _apply_transmuter(e, node)
  return true
end

function SkillTree.toggle_exclusive(e, id)
  local node = Skills.DB[id]; if not (node and node.kind == 'exclusive_aura') then return false, 'not_exclusive' end
  e.skills.toggled_exclusive = (e.skills.toggled_exclusive == id) and nil or id
  return true
end

Skills.SkillTree = SkillTree


local WPS = {}

WPS.DB = {
  AmarastasQuickCut = {
    id = 'AmarastasQuickCut',
    chance = 20,
    effects = function(ctx, src, tgt)
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

function WPS.handle_default_attack(ctx, src, tgt, Skills)
  local seen = {}
  local function deal(p, meta)
    local q = {}
    for k, v in pairs(p) do q[k] = v end
    meta      = meta or {}
    q.reason  = meta.reason or q.reason
    q.tag     = meta.tag or q.tag

    local key = meta.key or (tostring(q.reason) .. "|" .. tostring(q.tag) ..
      "|" .. (q.weapon and ("WD:" .. tostring(q.scale_pct or 100))
        or ("CMP:" .. (q.components and #q.components or 0))))
    if seen[key] then return end
    seen[key] = true

    Effects.deal_damage(q)(ctx, src, tgt)
  end

  local sid = src.skills and src.skills.dar_override
  if not sid then
    deal({ weapon = true, scale_pct = 100 }, {
      reason = "weapon",
      tag    = "DefaultAttack",
      key    = "basic:main"
    })
  else
    local node  = Skills.DB[sid]
    local r     = (src.skills.ranks and src.skills.ranks[sid]) or 1
    local knobs = node.scale and node.scale(r) or { weapon_scale_pct = 100 }

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

    deal({ weapon = true, scale_pct = knobs.weapon_scale_pct or 100 }, {
      reason = "weapon",
      tag    = sid,
      key    = "dar:" .. sid .. ":main"
    })

    if knobs.flat_fire and knobs.flat_fire > 0 then
      deal({ components = { { type = 'fire', amount = knobs.flat_fire } } }, {
        reason = "modifier",
        tag    = (node.mod_tag or (sid .. ":flat_fire")),
        key    = "dar:" .. sid .. ":mod:fire"
      })
    end
  end

  local wps_list = WPS.collect_for(src, Skills)
  if #wps_list > 0 then
    local pick = _roll(wps_list)
    if pick and pick.effects then
      pick.effects(ctx, src, tgt)
    end
  end
end

local Auras = {}

local function _reserve(e, pct)
  local maxE = e.max_energy or (e.stats and e.stats:get('energy')) or 0
  local need = maxE * (pct / 100)
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

function Auras.toggle_exclusive(ctx, e, Skills, id)
  local node = Skills.DB[id]
  if not node or node.kind ~= 'exclusive_aura' then return false, 'not_exclusive' end

  if e._active_exclusive and e._active_exclusive.entry then
    e._active_exclusive.remove_fn(e)
    _unreserve_all(e)
    e._active_exclusive = nil
  end

  if e.skills and e.skills.toggled_exclusive == id then
    local r   = (e.skills.ranks and e.skills.ranks[id]) or 1
    local eff = node.apply_aura and node.apply_aura(ctx, e, r)
    if not eff then return true end

    local entry
    if type(eff) == "table" then
      entry = eff
    elseif type(eff) == "function" and Effects._entry_of and Effects._entry_of[eff] then
      entry = Effects._entry_of[eff](ctx, { exclusive = true })
    else
      return false, "bad_aura_entry"
    end

    entry.id         = 'exclusive:' .. id
    entry.until_time = nil
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



local Devotion = {}

function Devotion.attach(e, spec)
  e._devotion = e._devotion or {}
  e._devotion[spec.id] = { spec = spec, next_ok = 0 }
end

local function _try_fire(ctx, e, ev, rec)
  local now = ctx.time.now
  if now < (rec.next_ok or 0) then return end
  local spec = rec.spec
  if spec.filter and not spec.filter(ev) then return end
  if spec.condition and not spec.condition(ctx, ev, e) then return end
  if math.random() * 100 > (spec.chance or 100) then return end
  local src = ev.source or e
  local tgt = ev.target or e
  spec.effects(ctx, src, tgt, ev)
  rec.next_ok = now + (spec.icd or 0)
end

function Devotion.handle_event(ctx, evname, ev)
  local function handle(e)
    if not (e and e._devotion) then return end
    for _, rec in pairs(e._devotion) do
      local spec = rec.spec
      if spec.trigger == evname then _try_fire(ctx, e, ev, rec) end
    end
  end
  handle(ev.source); handle(ev.target)
end


local Systems = {}

local function _fail(msg) error("Charges.add_track: "..msg) end

local function _validate_spec(spec)
  if type(spec) ~= "table" then _fail("spec is not a table") end
  if type(spec.id) ~= "string" or spec.id == "" then _fail("spec.id missing") end
  spec.max   = tonumber(spec.max   or 0) or 0
  spec.decay = tonumber(spec.decay or 0) or 0
  return spec
end

local function _normalize_spec(e, what, max_stacks, decay_per_sec, on_change, opts)
  opts = opts or {}

  if type(what) == "string" then
    return _validate_spec{
      id = what, max = max_stacks or 0, decay = decay_per_sec or 0, on_change = on_change
    }
  end

  local skill_id = (type(what) == "table" and what.id) or nil

  if type(what) == "table" and what.charges then
    local c = what.charges
    if type(c) == "function" then
      local r = (opts and opts.rank) or 0
      local ok, res = pcall(c, r, e, opts)
      if not ok then
        _fail(("charges() for skill '%s' threw: %s"):format(tostring(skill_id or "?"), tostring(res)))
      end
      what = res
    else
      what = c
    end
  end

  if type(what) == "table" then
    local id = what.id or what.charge_id or what.name
              or (skill_id and (tostring(skill_id)..":charges"))
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


function Charges.add_track(e, spec_or_skill, max_stacks, decay_per_sec, on_change, opts)
  e._charges = e._charges or {}
  local spec = _normalize_spec(e, spec_or_skill, max_stacks, decay_per_sec, on_change, opts)
  assert(spec and spec.id, "Charges.add_track: spec.id required")

  if e._charges[spec.id] then Charges.remove_track(e, spec.id) end

  local rec = {
    stacks = 0,
    max = spec.max or 0,
    decay = spec.decay or 0,
    on_change = spec.on_change,
    on_remove = spec.on_remove
  }
  e._charges[spec.id] = rec

  if spec.derived and e.stats and e.stats.on_recompute then
    local hook = function(S)
      local c = e._charges and e._charges[spec.id]; if not c then return end
      local s = c.stacks or 0
      if s > 0 then spec.derived(S, e, s) end
    end
    local unsub = e.stats:on_recompute(hook)
    rec._unsub, rec._hook, rec._stats = unsub, hook, e.stats
  end

  if rec.on_change then rec.on_change(e, rec.stacks) end

  return { remove = function() Charges.remove_track(e, spec.id) end }
end

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

function Charges.on_hit(e, id, add)
  local c = e._charges and e._charges[id]; if not c then return end
  local before = c.stacks or 0
  c.stacks = math.min(c.max, before + (add or 1))
  if c.on_change and c.stacks ~= before then c.on_change(e, c.stacks) end
end

function Charges.set(e, id, stacks)
  local c = e._charges and e._charges[id]; if not c then return end
  local before = c.stacks or 0
  c.stacks = util.clamp(stacks or 0, 0, c.max or 0)
  if c.on_change and c.stacks ~= before then c.on_change(e, c.stacks) end
end

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

local Channel = {}
function Channel.start(ctx, e, id, drain_per_sec, tick, period)
  e._channel = e._channel or {}
  e._channel[id] = { drain = drain_per_sec, tick = tick, period = period or 0.5, next = ctx.time.now }
end

function Channel.stop(e, id) if e._channel then e._channel[id] = nil end end

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


local PetsAndSets = {}

local function add_to_side(ctx, ent, side)
  local roster = (side == 1) and ctx.side1 or ctx.side2
  roster[#roster+1] = ent
end

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

  local owner_all = (owner.stats and owner.stats:get("all_damage_pct")) or 0
  local mult = (spec.inherit_damage_mult ~= nil) and spec.inherit_damage_mult or 0.6
  if owner_all ~= 0 and mult ~= 0 then
    pet.stats:add_add_pct("all_damage_pct", owner_all * mult)
  end
  pet.stats:recompute()

  add_to_side(ctx, pet, owner.side)
  return pet
end



local function _apply_set_bonus(ctx, e, bonus)
  if bonus.effects then
    bonus._applied = bonus.effects(ctx, e)
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
end

function PetsAndSets.recompute_sets(ctx, e)
  local cnt = {}
  for slot, it in pairs(e.equipped or {}) do
    if it.set_id then cnt[it.set_id] = (cnt[it.set_id] or 0) + 1 end
  end
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

StatusEngine.update_entity = function(ctx, e, dt)
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
  ctx.time:tick(dt)

  local function regen(ent)
    if not ent.stats then return end

    local maxhp = ent.max_health or ent.stats:get('health')
    local hpr   = ent.stats:get('health_regen') or 0
    if hpr ~= 0 then
      ent.hp = util.clamp((ent.hp or maxhp) + hpr * dt, 0, maxhp)
    end

    local baseMaxE = ent.stats:get('energy') or 0
    local reservedAbs = ent._energy_reserved or 0
    local reservedPct = ent._reserved_pct or 0
    local effMaxE = math.max(0, baseMaxE * (1 - reservedPct / 100) - reservedAbs)

    if ent.max_energy == nil then ent.max_energy = effMaxE end
    ent.max_energy = effMaxE
    if ent.energy == nil then ent.energy = effMaxE end
    if ent.energy > ent.max_energy then ent.energy = ent.max_energy end

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

  Systems.update(ctx, dt)

  ctx.bus:emit('OnTick', { dt = dt, now = ctx.time.now })
end


local function make_actor(name, defs, attach)
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

    _defs            = defs,
    _attach          = attach,
    _make_actor      = make_actor,
  }
end




local Demo = {}

function Demo.run()
  math.randomseed(os.time())

  local bus       = EventBus.new()
  local time      = Time.new()
  local defs, DTS = StatDef.make()
  local combat    = Combat.new(RR, DTS)

  for _, evn in ipairs({ 'OnHitResolved', 'OnBasicAttack', 'OnCrit', 'OnDeath', 'OnDodge' }) do
    bus:on(evn, function(ev) Devotion.handle_event(ctx, evn, ev) end)
  end



  local ctx = {
    _make_actor    = make_actor,
    debug          = true,
    bus            = bus,
    time           = time,
    combat         = combat,

    get_enemies_of = function(a) return a.side == 1 and ctx.side2 or ctx.side1 end,
    get_allies_of  = function(a) return a.side == 1 and ctx.side1 or ctx.side2 end,
  }

  local hero = make_actor('Hero', defs, Content.attach_attribute_derivations)
  hero.side = 1
  hero.level_curve = 'fast_start'
  hero.stats:add_base('physique', 16)
  hero.stats:add_base('cunning', 14)
  hero.stats:add_base('spirit', 10)
  hero.stats:add_base('weapon_min', 12)
  hero.stats:add_base('weapon_max', 18)
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

  Effects.deal_damage { weapon = true, scale_pct = 100 } (ctx, hero, ogre)

  if util.rand() * 100.0 < (Content.Traits.EmberStrike.chance or 0) then
    Content.Traits.EmberStrike.effects(ctx, hero, ogre)
  end

  util.dump_stats(ogre, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

  local FB = Content.Spells.Fireball
  for _, t in ipairs(FB.targeter({ source = hero, target = ogre, get_enemies_of = ctx.get_enemies_of })) do
    FB.effects(ctx, hero, t)
  end

  util.dump_stats(ogre, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

  local PD = Content.Spells.PoisonDart
  for _, t in ipairs(PD.targeter({ source = hero, target = ogre, get_enemies_of = ctx.get_enemies_of })) do
    PD.effects(ctx, hero, t)
  end
  for i = 1, 6 do
    World.update(ctx, 1.0)
  end

  util.dump_stats(ogre, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

  bus:on('OnProvoke', function(ev)
    print(string.format('[%s] provoked [%s]!', ev.source.name, ev.target.name))
    Effects.force_counter_attack { scale_pct = 40 } (ctx, ev.target, ev.source)
  end)

  ctx.bus:emit('OnProvoke', { source = hero, target = ogre })



  local FlamebandPlus = {
    id = 'flameband_plus',
    slot = 'sword1',
    requires = { attribute = 'cunning', value = 12, mode = 'sole' },
    mods = { { stat = 'weapon_min', base = 6 }, { stat = 'weapon_max', base = 10 } },

    ability_mods = {
      Fireball = { dmg_pct = 20, cd_add = -0.5, cost_pct = -10 },
    },
  }

  local ThunderSeal = {
    id = 'thunder_seal',
    slot = 'amulet',
    mods = {},
    spell_mutators = {
      Fireball = {
        {
          pr = 0,
          wrap = function(orig)
            return function(ctx, src, tgt)
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

  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

  assert(ItemSystem.equip(ctx, hero, FlamebandPlus))

  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

  assert(ItemSystem.equip(ctx, hero, ThunderSeal))

  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

  ctx.bus:emit('OnBasicAttack', { source = hero, target = ogre })
  ctx.bus:emit('OnBasicAttack', { source = hero, target = ogre })
  ctx.bus:emit('OnBasicAttack', { source = hero, target = ogre })



  local ok, why = Cast.cast(ctx, hero, 'Fireball', ogre)

  Content.Spells.Fireball.item_granted = true

  util.dump_stats(ogre, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })




  ctx.bus:on('OnLevelUp', function(ev)
    local e = ev.entity
    e.stats:add_base('physique', 1)
    e.stats:recompute()

    log_debug("Level up!", e.name, "now at level", e.level, "with", e.attr_points, "attribute points and", e
    .skill_points, "skill points.")

    if e.level == 3 then
      e.granted_spells = e.granted_spells or {}
      e.granted_spells['Fireball'] = true
    end
  end)

  Leveling.grant_exp(ctx, hero, 1500)
  Leveling.grant_exp(ctx, hero, 1500)

  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
  util.dump_stats(ogre, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
end

function Demo.run_full()
  math.randomseed(12345)

  local bus       = EventBus.new()
  local time      = Time.new()
  local defs, DTS = StatDef.make()
  local combat    = Combat.new(RR, DTS)


  local ctx
  
  local ctx = {
    _make_actor    = make_actor,
    debug          = true,
    bus            = bus,
    time           = time,
    combat         = combat
  }
  
  ctx.get_enemies_of = function(a) return a.side == 1 and ctx.side2 or ctx.side1 end
  ctx.get_allies_of  = function(a) return a.side == 1 and ctx.side1 or ctx.side2 end

  for _, evn in ipairs({ 'OnHitResolved', 'OnBasicAttack', 'OnCrit', 'OnDeath', 'OnDodge' }) do
    bus:on(evn, function(ev) Devotion.handle_event(ctx, evn, ev) end)
  end

  local hero = make_actor('Hero', defs, Content.attach_attribute_derivations)
  hero.side = 1
  hero.level_curve = 'fast_start'
  hero.stats:add_base('physique', 16)
  hero.stats:add_base('cunning', 18)
  hero.stats:add_base('spirit', 12)
  hero.stats:add_base('weapon_min', 18)
  hero.stats:add_base('weapon_max', 25)
  hero.stats:add_base('life_steal_pct', 10)
  hero.stats:add_base('crit_damage_pct', 50)
  hero.stats:add_base('cooldown_reduction', 20)
  hero.stats:add_base('skill_energy_cost_reduction', 15)
  hero.stats:add_base('attack_speed', 1.0)
  hero.stats:add_base('cast_speed', 1.0)
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
  ogre.stats:add_base('damage_taken_reduction_pct', 100)
  ogre.stats:recompute()

  ctx.side1 = { hero }
  ctx.side2 = { ogre }
  
  ctx._defs       = defs
  ctx._attach     = Content.attach_attribute_derivations
  ctx._make_actor = make_actor


  local function display(v)
    local tv = type(v)
    if tv == "string" or tv == "number" or tv == "boolean" then
      return tostring(v)
    elseif tv == "table" then
      local mt = getmetatable(v)
      if mt and mt.__tostring then return tostring(v) end
      if v.name then return tostring(v.name) end
      if v.id then return tostring(v.id) end
      if v.label then return tostring(v.label) end
      return "<tbl:" .. (tostring(v):match("0x[%da-fA-F]+") or "?") .. ">"
    else
      return tostring(v)
    end
  end

  local function resolve(v)
    if type(v) == "table" then
      if v.name then return v.name end
      if v.id then return v.id end
      return "<tbl>"
    elseif type(v) == "boolean" then
      return v and "true" or "false"
    elseif v == nil then
      return "nil"
    else
      return v
    end
  end

  local function on(bus, name, fmt, fields)
    bus:on(name, function(e)
      local vals = {}
      for _, k in ipairs(fields or {}) do
        vals[#vals + 1] = resolve(e[k])
      end

      local line = ("[EVT] %-16s " .. fmt):format(name, table.unpack(vals))

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

  local FlamebandPlus = {
    id = 'flameband_plus',
    slot = 'sword1',
    requires = { attribute = 'cunning', value = 12, mode = 'sole' },
    mods = { { stat = 'weapon_min', base = 4 }, { stat = 'weapon_max', base = 8 } },
    ability_mods = { Fireball = { dmg_pct = 20, cd_add = -0.5, cost_pct = -10 }, },
  }

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
  
  local RingOfWard = {
    id='ring_of_ward', slot='ring',
    on_equip = function(ctx, e)
      local entry = Effects._entry_of[Effects.grant_barrier { amount = 30, duration = 999999 }](ctx, {exclusive=false})
      entry.id = "ring_of_ward_barrier"
      entry.until_time = nil
      apply_status(e, entry)
      return function(ent)
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
  assert(ItemSystem.equip(ctx, hero, FlamebandPlus))
  util.dump_stats(hero, ctx, { conv = true, timers = true, spells = true })
  assert(ItemSystem.equip(ctx, hero, ThunderSeal))
  util.dump_stats(hero, ctx, { conv = true, timers = true, spells = true })

  set_ability_level(hero, 'Fireball', 3)

  print("\n== Openers ==")
  Effects.deal_damage { weapon = true, scale_pct = 100 } (ctx, hero, ogre)
  ctx.bus:emit('OnBasicAttack', { source = hero, target = ogre })

  Content.Spells.ViperSigil.effects(ctx, hero, ogre)
  Content.Spells.ElementalStorm.effects(ctx, hero, ogre)
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
  Effects.grant_barrier { amount = 50, duration = 3 } (ctx, hero, hero)
  Effects.heal { percent_of_max = 15 } (ctx, hero, hero)
  util.dump_stats(hero, ctx, { statuses = true, timers = true })

  print("\n== Provoke & counter chain ==")
  bus:emit('OnProvoke', { source = hero, target = ogre })

  print("\n== Cooldowns & costs ==")
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
  Effects.modify_stat { id = 'buffA', name = 'fire_modifier_pct', add_pct_add = 10, duration = 2 } (ctx, hero, hero)
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
  Effects.modify_stat { id = 'burning', name = 'percent_absorb_pct', add_pct_add = 5, duration = 10 } (ctx, hero, hero)

  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
  Effects.cleanse { ids = { burning = true }, predicate = function(id, entry) return false end } (ctx, hero, hero)

  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

  print("\n== par / seq / chance / scale_by_stat ==")
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
  hero.gear_conversions = { { from = 'physical', to = 'fire', pct = 50 } }
  Effects.deal_damage {
    components = { { type = 'physical', amount = 100 } },
    skill_conversions = { { from = 'physical', to = 'cold', pct = 50 } }
  } (ctx, hero, ogre)

  print("\n== Exclusive aura toggle & reservation ==")
  Skills.SkillTree.set_rank(hero, 'PossessionLike', 5)
  Skills.SkillTree.toggle_exclusive(hero, 'PossessionLike')
  Auras.toggle_exclusive(ctx, hero, Skills, 'PossessionLike')
  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })

  print("\n== Modifier & Transmuter application ==")
  Skills.SkillTree.set_rank(hero, 'FireStrike', 8)
  Skills.SkillTree.set_rank(hero, 'ExplosiveStrike', 6)
  Skills.SkillTree.enable_transmuter(hero, 'SearingStrike')
  WPS.handle_default_attack(ctx, hero, ogre, Skills)

  print("\n== Devotion trigger w/ ICD ==")
  local devo = {
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
  World.update(ctx, 0.5); Effects.deal_damage { weapon = true, scale_pct = 100 } (ctx, hero, ogre)
  World.update(ctx, 1.5); Effects.deal_damage { weapon = true, scale_pct = 100 } (ctx, hero, ogre)

  print("\n== Charges & Channel ==")
  local chargeRemoveHandle = Systems.Charges.add_track(hero, Skills.DB.OverheatWithRank)
  Systems.Charges.on_hit(hero, 'Heat', 5)
  Systems.Channel.start(ctx, hero, 'Beam', 8,
    function(ctx, e) Effects.deal_damage { components = { { type = 'aether', amount = 15 } } } (ctx, e, ogre) end, 0.5)
  for i = 1, 5 do World.update(ctx, 0.5) end
  Systems.Channel.stop(hero, 'Beam')
  util.dump_stats(hero, ctx, { rr = true, dots = true, statuses = true, conv = true, spells = true, tags = true, timers = true })
  chargeRemoveHandle.remove()

  print("\n== Pets & Sets (apply/unapply) ==")
  local pet = PetsAndSets.spawn_pet(ctx, hero, { name = 'Imp', inherit_damage_mult = 0.6 })
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
  local item2 = { id = 'E1', slot = 'ring', set_id = 'EmberSet' }
  local item3 = { id = 'E2', slot = 'amulet', set_id = 'EmberSet' }
  ItemSystem.equip(ctx, hero, item2); PetsAndSets.recompute_sets(ctx, hero)
  ItemSystem.equip(ctx, hero, item3); PetsAndSets.recompute_sets(ctx, hero)
  ItemSystem.unequip(ctx, hero, 'amulet'); PetsAndSets.recompute_sets(ctx, hero)

  print("\n== Equip rules failure paths ==")
  local bad = { id = 'HeavyAxe', slot = 'axe2', requires = { attribute = 'physique', value = 999, mode = 'sole' } }
  local ok, why = ItemSystem.equip(ctx, hero, bad); print("Equip heavy axe:", ok, why or "")

  print("\n== CDR exclusion: item-granted vs native ==")
  Content.Spells.Fireball.cooldown = 3.0
  hero.granted_spells = { Fireball = true }
  hero.stats:add_add_pct('cooldown_reduction', 50)
  Cast.cast(ctx, hero, 'Fireball', ogre)
  local ok2, why2 = Cast.cast(ctx, hero, 'Fireball', ogre)
  print("Immediate recast (should be on CD, ignoring CDR):", ok2, why2 or "")

  print("\n== Ability level + item ability_mods (build path) ==")
  set_ability_level(hero, 'Fireball', 4)
  hero.equipped.ring = { ability_mods = { Fireball = { dmg_pct = 30, cd_add = -0.5, cost_pct = -10 } } } 
  Cast.cast(ctx, hero, 'Fireball', ogre)


  print("\n== Cleanup ticks ==")
  for i = 1, 5 do World.update(ctx, 1.0) end
  util.dump_stats(ogre, ctx, { rr = true, dots = true, statuses = true, timers = true })
end

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
