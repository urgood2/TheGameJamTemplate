-- assets/scripts/descent/enemy.lua
-- Base enemy model + AI decision helper for Descent.

local Enemy = {}

local spec = require("descent.spec")
local pathfinding = require("descent.pathfinding")

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

function Enemy.create(def)
  def = def or {}
  return {
    id = def.id or def.entity_id or def.name or "enemy",
    type = def.type or "enemy",
    x = def.x or 0,
    y = def.y or 0,
    hp = def.hp or 1,
    hp_max = def.hp_max or def.hp or 1,
    armor = def.armor or 0,
    evasion = def.evasion or 0,
    damage = def.damage or 1,
  }
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
