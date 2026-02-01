local Spells = {}

local combat = require("descent.combat")
local player = require("descent.player")
local Map = require("descent.map")

Spells.SPELL = {
  MAGIC_MISSILE = "magic_missile",
  HEAL = "heal",
  BLINK = "blink",
}

Spells.ORDER = {
  Spells.SPELL.MAGIC_MISSILE,
  Spells.SPELL.HEAL,
  Spells.SPELL.BLINK,
}

local spell_defs = {
  magic_missile = {
    id = "magic_missile",
    name = "Magic Missile",
    mp_cost = 2,
    range = 6,
    requires_los = true,
    base_damage = 4,
    type = "damage",
  },
  heal = {
    id = "heal",
    name = "Heal",
    mp_cost = 3,
    range = 0,
    requires_los = false,
    heal_amount = 6,
    type = "heal",
  },
  blink = {
    id = "blink",
    name = "Blink",
    mp_cost = 4,
    range = 5,
    requires_los = false,
    type = "teleport",
  },
}

local function chebyshev_distance(a, b)
  return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end

local function get_rng(ctx)
  if ctx and ctx.rng then
    return ctx.rng
  end
  return require("descent.rng")
end

function Spells.get(spell_id)
  return spell_defs[spell_id]
end

function Spells.list()
  local list = {}
  for _, id in ipairs(Spells.ORDER) do
    table.insert(list, spell_defs[id])
  end
  return list
end

function Spells.offer_spell(state)
  for _, id in ipairs(Spells.ORDER) do
    if not player.knows_spell(state, id) then
      if player.add_spell(state, id) then
        return id
      end
    end
  end
  return nil
end

function Spells.bind_player(player_module)
  local module = player_module or player
  module.on_spell_select(function(state)
    Spells.offer_spell(state)
  end)
end

function Spells.can_cast(spell_id, caster, target, ctx)
  local spell = spell_defs[spell_id]
  if not spell then
    return false, "unknown_spell"
  end

  if caster.mp == nil or caster.mp < spell.mp_cost then
    return false, "not_enough_mp"
  end

  if spell.type ~= "heal" and not target then
    return false, "no_target"
  end

  if spell.range and target then
    local distance = (ctx and ctx.distance_fn) and ctx.distance_fn(caster, target) or chebyshev_distance(caster, target)
    if distance > spell.range then
      return false, "out_of_range"
    end
  end

  if spell.requires_los then
    local has_los = nil
    if ctx and ctx.has_los then
      has_los = ctx.has_los(caster, target)
    elseif ctx and ctx.fov and ctx.fov.is_visible then
      has_los = ctx.fov.is_visible(target.x, target.y)
    end
    if has_los == false then
      return false, "no_los"
    end
  end

  return true, nil
end

function Spells.cast(spell_id, caster, target, ctx)
  local spell = spell_defs[spell_id]
  if not spell then
    return { success = false, reason = "unknown_spell", cost = 0 }
  end

  local ok, reason = Spells.can_cast(spell_id, caster, target, ctx)
  if not ok then
    return { success = false, reason = reason, cost = 0 }
  end

  caster.mp = caster.mp - spell.mp_cost

  if spell.type == "damage" then
    local raw = combat.magic_raw_damage({
      spell_base = spell.base_damage,
      int = caster.int or 0,
      species_multiplier = caster.species_multiplier or 1,
    })
    local final = combat.apply_armor(raw, target or {})

    if target and target.hp then
      target.hp = math.max(0, target.hp - final)
    end

    return {
      success = true,
      type = "damage",
      damage = final,
      cost = spell.mp_cost,
    }
  end

  if spell.type == "heal" then
    local receiver = target or caster
    local before = receiver.hp or 0
    local max_hp = receiver.hp_max or receiver.hp or before
    receiver.hp = math.min(max_hp, before + spell.heal_amount)

    return {
      success = true,
      type = "heal",
      amount = receiver.hp - before,
      cost = spell.mp_cost,
    }
  end

  if spell.type == "teleport" then
    local map = ctx and ctx.map
    if not map then
      return { success = false, reason = "no_map", cost = spell.mp_cost }
    end

    local candidates = {}
    for dx = -spell.range, spell.range do
      for dy = -spell.range, spell.range do
        local distance = math.max(math.abs(dx), math.abs(dy))
        if distance <= spell.range then
          local x = caster.x + dx
          local y = caster.y + dy
          if Map.in_bounds(map, x, y) and Map.is_walkable(map, x, y) then
            if not Map.is_occupied(map, x, y) then
              table.insert(candidates, { x = x, y = y })
            end
          end
        end
      end
    end

    if #candidates == 0 then
      return { success = false, reason = "no_destination", cost = spell.mp_cost }
    end

    local rng = get_rng(ctx)
    local pick = rng.choice and rng.choice(candidates) or candidates[1]
    caster.x = pick.x
    caster.y = pick.y

    return {
      success = true,
      type = "teleport",
      destination = { x = pick.x, y = pick.y },
      cost = spell.mp_cost,
    }
  end

  return { success = false, reason = "unsupported", cost = 0 }
end

return Spells
