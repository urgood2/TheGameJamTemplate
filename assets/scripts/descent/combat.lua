local M = {}

local spec = require("descent.spec")

local function clamp(value, min_value, max_value)
  if value < min_value then return min_value end
  if value > max_value then return max_value end
  return value
end

local function entity_label(entity)
  if not entity then
    return "entity:unknown"
  end
  local kind = entity.type or entity.kind or entity.name or "entity"
  local id = entity.id or entity.entity_id or entity.instance_id or entity.uid or "unknown"
  return tostring(kind) .. ":" .. tostring(id)
end

local function require_non_negative(entity, field, value)
  if value == nil then
    return
  end
  if value < 0 then
    error(string.format("[Combat] Negative %s for %s", tostring(field), entity_label(entity)), 2)
  end
end

local function resolve_rng(rng)
  if rng then
    return rng
  end
  return require("descent.rng")
end

--------------------------------------------------------------------------------
-- Hit chance
--------------------------------------------------------------------------------

function M.melee_hit_chance(attacker, defender)
  local cfg = spec.combat.melee.hit_chance
  local dex = attacker.dex or 0
  local enemy_evasion = defender.evasion or defender.enemy_evasion or 0

  require_non_negative(attacker, "dex", dex)
  require_non_negative(defender, "enemy_evasion", enemy_evasion)

  local raw = cfg.base + (dex * cfg.dex_mult) - (enemy_evasion * cfg.enemy_evasion_mult)
  return clamp(raw, cfg.clamp_min, cfg.clamp_max)
end

function M.magic_hit_chance(attacker)
  local cfg = spec.combat.magic.hit_chance
  local skill = attacker.skill or attacker.magic_skill or 0

  require_non_negative(attacker, "skill", skill)

  local raw = cfg.base + (skill * cfg.skill_mult)
  return clamp(raw, cfg.clamp_min, cfg.clamp_max)
end

--------------------------------------------------------------------------------
-- Damage
--------------------------------------------------------------------------------

function M.melee_raw_damage(attacker)
  local weapon_base = attacker.weapon_base or 0
  local str = attacker.str or attacker.str_modifier or 0
  local species_bonus = attacker.species_bonus or 0

  require_non_negative(attacker, "weapon_base", weapon_base)
  require_non_negative(attacker, "str", str)
  require_non_negative(attacker, "species_bonus", species_bonus)

  local raw = weapon_base + str + species_bonus
  return math.floor(raw)
end

function M.magic_raw_damage(attacker)
  local spell_base = attacker.spell_base or 0
  local int_stat = attacker.int or attacker.intellect or 0
  local species_multiplier = attacker.species_multiplier or 1

  require_non_negative(attacker, "spell_base", spell_base)
  require_non_negative(attacker, "int", int_stat)
  require_non_negative(attacker, "species_multiplier", species_multiplier)

  local raw = spell_base * (1 + int_stat * 0.05) * species_multiplier
  return math.floor(raw)
end

function M.apply_armor(raw_damage, defender)
  local armor = defender.armor or defender.armor_value or 0
  require_non_negative(defender, "armor", armor)

  local reduced = math.floor(raw_damage - armor)
  if reduced < 0 then
    return 0
  end
  return reduced
end

--------------------------------------------------------------------------------
-- Resolution helpers
--------------------------------------------------------------------------------

function M.roll_hit(chance, rng)
  local rng_impl = resolve_rng(rng)
  local roll = rng_impl.random(1, 100)
  return roll <= chance, roll
end

function M.resolve_melee(attacker, defender, rng)
  local chance = M.melee_hit_chance(attacker, defender)
  local hit, roll = M.roll_hit(chance, rng)

  if not hit then
    return {
      hit = false,
      roll = roll,
      chance = chance,
      raw_damage = 0,
      damage = 0,
    }
  end

  local raw = M.melee_raw_damage(attacker)
  local final = M.apply_armor(raw, defender)

  return {
    hit = true,
    roll = roll,
    chance = chance,
    raw_damage = raw,
    damage = final,
  }
end

function M.resolve_magic(attacker, defender, rng)
  local chance = M.magic_hit_chance(attacker)
  local hit, roll = M.roll_hit(chance, rng)

  if not hit then
    return {
      hit = false,
      roll = roll,
      chance = chance,
      raw_damage = 0,
      damage = 0,
    }
  end

  local raw = M.magic_raw_damage(attacker)
  local final = M.apply_armor(raw, defender)

  return {
    hit = true,
    roll = roll,
    chance = chance,
    raw_damage = raw,
    damage = final,
  }
end

--------------------------------------------------------------------------------
-- Scripted RNG for deterministic tests
--------------------------------------------------------------------------------

function M.scripted_rng(sequence)
  local idx = 1
  return {
    random = function(min, max)
      local value = sequence[idx] or sequence[#sequence]
      idx = idx + 1
      if min and max then
        local span = max - min + 1
        local normalized = ((value - min) % span) + min
        return normalized
      end
      if min and not max then
        return ((value - 1) % min) + 1
      end
      return value
    end,
  }
end

return M
