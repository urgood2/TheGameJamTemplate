-- assets/scripts/descent/enemy.lua
-- Base enemy model + AI decision helper for Descent.

local Enemy = {}

local spec = require("descent.spec")
local pathfinding = require("descent.pathfinding")

--------------------------------------------------------------------------------
-- Enemy Templates
-- Stats needed by combat.lua: weapon_base, str, dex, armor, evasion, species_bonus
--------------------------------------------------------------------------------

local TEMPLATES = {
  goblin = {
    name = "Goblin",
    hp = 8,
    str = 4,
    dex = 12,
    int = 3,
    weapon_base = 3,
    armor = 0,
    evasion = 10,
    species_bonus = 0,
    xp_value = 5,
    speed = "normal",
    ai_type = "melee",
  },
  skeleton = {
    name = "Skeleton",
    hp = 12,
    str = 6,
    dex = 8,
    int = 2,
    weapon_base = 4,
    armor = 2,
    evasion = 5,
    species_bonus = 0,
    xp_value = 8,
    speed = "normal",
    ai_type = "melee",
  },
  orc = {
    name = "Orc",
    hp = 18,
    str = 10,
    dex = 6,
    int = 4,
    weapon_base = 6,
    armor = 3,
    evasion = 3,
    species_bonus = 2,
    xp_value = 12,
    speed = "normal",
    ai_type = "melee",
  },
  mage = {
    name = "Mage",
    hp = 10,
    str = 3,
    dex = 8,
    int = 14,
    weapon_base = 2,
    spell_base = 8,
    armor = 0,
    evasion = 8,
    species_bonus = 0,
    skill = 10,
    species_multiplier = 1.0,
    xp_value = 15,
    speed = "normal",
    ai_type = "magic",
  },
  troll = {
    name = "Troll",
    hp = 30,
    str = 14,
    dex = 4,
    int = 2,
    weapon_base = 8,
    armor = 5,
    evasion = 2,
    species_bonus = 3,
    xp_value = 20,
    speed = "slow",
    ai_type = "melee",
    regen_per_turn = 2,
  },
  -- Boss template
  boss = {
    name = "Dark Lord",
    hp = 100,
    str = 16,
    dex = 10,
    int = 12,
    weapon_base = 20,
    armor = 8,
    evasion = 5,
    species_bonus = 5,
    xp_value = 100,
    speed = "slow",
    ai_type = "boss",
    is_boss = true,
  },
}

-- Unique ID counter for deterministic enemy creation
local _next_enemy_id = 1

local function is_adjacent(ax, ay, bx, by)
  local dx = math.abs(ax - bx)
  local dy = math.abs(ay - by)
  return dx <= 1 and dy <= 1 and (dx + dy) > 0
end

local function resolve_visibility(enemy, player, ctx)
  if ctx then
    if type(ctx.is_visible) == "function" then
      return ctx.is_visible(enemy, player, ctx) == true
    end
    if type(ctx.is_visible) == "boolean" then
      return ctx.is_visible
    end
    if ctx.fov and type(ctx.fov.is_visible) == "function" then
      return ctx.fov.is_visible(player.x, player.y) == true
    end
  end
  return false
end

local function resolve_pathfinder(ctx)
  if ctx and ctx.pathfinding and type(ctx.pathfinding.find_path) == "function" then
    return ctx.pathfinding
  end
  return pathfinding
end

local function resolve_diagonal(ctx)
  if ctx and ctx.allow_diagonal ~= nil then
    return ctx.allow_diagonal
  end
  return spec.movement and spec.movement.eight_way ~= false
end

--- Create an enemy from a template
--- @param template_id string Template name (e.g., "goblin", "skeleton")
--- @param x number Spawn X position
--- @param y number Spawn Y position
--- @param overrides table|nil Optional stat overrides
--- @return table Enemy entity
function Enemy.create(template_id, x, y, overrides)
  -- Handle legacy single-table call: Enemy.create({ ... })
  if type(template_id) == "table" then
    local def = template_id
    return {
      id = def.id or def.entity_id or def.name or ("enemy_" .. _next_enemy_id),
      type = def.type or "enemy",
      name = def.name or "Enemy",
      x = def.x or 0,
      y = def.y or 0,
      hp = def.hp or 1,
      hp_max = def.hp_max or def.hp or 1,
      str = def.str or 5,
      dex = def.dex or 5,
      int = def.int or 5,
      weapon_base = def.weapon_base or def.damage or 3,
      armor = def.armor or 0,
      evasion = def.evasion or 0,
      species_bonus = def.species_bonus or 0,
      xp_value = def.xp_value or 5,
      alive = true,
      entity_id = def.entity_id or def.id or ("enemy_" .. _next_enemy_id),
    }
  end

  -- Template-based creation
  local template = TEMPLATES[template_id]
  if not template then
    -- Unknown template - create with defaults
    template = {
      name = template_id or "Enemy",
      hp = 5,
      str = 5,
      dex = 5,
      int = 5,
      weapon_base = 3,
      armor = 0,
      evasion = 5,
      species_bonus = 0,
      xp_value = 5,
    }
  end

  -- Generate unique ID
  local enemy_id = "enemy_" .. _next_enemy_id
  _next_enemy_id = _next_enemy_id + 1

  -- Build enemy from template
  local enemy = {
    id = enemy_id,
    entity_id = enemy_id,
    type = "enemy",
    template_id = template_id,
    name = template.name,
    x = x or 0,
    y = y or 0,
    hp = template.hp,
    hp_max = template.hp,
    str = template.str,
    dex = template.dex,
    int = template.int,
    weapon_base = template.weapon_base,
    armor = template.armor,
    evasion = template.evasion,
    species_bonus = template.species_bonus or 0,
    species_multiplier = template.species_multiplier or 1.0,
    spell_base = template.spell_base,
    skill = template.skill,
    xp_value = template.xp_value or 5,
    speed = template.speed or "normal",
    ai_type = template.ai_type or "melee",
    is_boss = template.is_boss or false,
    regen_per_turn = template.regen_per_turn,
    alive = true,
  }

  -- Apply overrides
  if overrides then
    for k, v in pairs(overrides) do
      enemy[k] = v
    end
  end

  return enemy
end

--- Reset enemy ID counter (for determinism between runs)
function Enemy.reset_id_counter()
  _next_enemy_id = 1
end

--- Get a template by ID
--- @param template_id string Template name
--- @return table|nil Template or nil
function Enemy.get_template(template_id)
  return TEMPLATES[template_id]
end

--- Get all available template IDs
--- @return table Array of template IDs
function Enemy.get_template_ids()
  local ids = {}
  for id in pairs(TEMPLATES) do
    table.insert(ids, id)
  end
  table.sort(ids)
  return ids
end

-- Deterministic ordering for enemy processing.
-- Primary: id (string compare). Tie-breakers: y then x.
function Enemy.sort_for_turn(enemies)
  table.sort(enemies, function(a, b)
    local ida = tostring(a.id or a.entity_id or "")
    local idb = tostring(b.id or b.entity_id or "")
    if ida == idb then
      if a.y == b.y then
        return (a.x or 0) < (b.x or 0)
      end
      return (a.y or 0) < (b.y or 0)
    end
    return ida < idb
  end)
  return enemies
end

-- Decide an AI action for an enemy.
-- ctx expects: map, player, (optional) is_visible/fov, (optional) pathfinding, allow_diagonal
-- Returns action table: { type = "attack"|"move"|"idle", ... }
function Enemy.decide_action(enemy, ctx)
  local player = ctx and ctx.player or nil
  local map = ctx and ctx.map or nil
  if not player or not map then
    return { type = "idle", reason = "missing_context" }
  end

  if is_adjacent(enemy.x, enemy.y, player.x, player.y) then
    return { type = "attack", target = "player" }
  end

  local visible = resolve_visibility(enemy, player, ctx)
  if not visible then
    return { type = "idle", reason = "not_visible" }
  end

  local pf = resolve_pathfinder(ctx)
  local allow_diagonal = resolve_diagonal(ctx)
  local path = pf.find_path(map, enemy.x, enemy.y, player.x, player.y, {
    allow_diagonal = allow_diagonal,
  })

  if not path or #path < 2 then
    return { type = "idle", reason = "no_path" }
  end

  local next_step = path[2]
  return { type = "move", x = next_step.x, y = next_step.y }
end

return Enemy
