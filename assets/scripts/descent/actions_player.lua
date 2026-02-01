-- assets/scripts/descent/actions_player.lua
-- Resolve player intents into concrete actions (move vs bump-attack).

local ActionsPlayer = {}

local Input = require("descent.input")
local TurnManager = require("descent.turn_manager")

local function find_enemy_at(enemies, x, y)
  if not enemies then return nil end
  for _, enemy in ipairs(enemies) do
    if enemy.x == x and enemy.y == y then
      return enemy
    end
  end
  return nil
end

local function is_walkable(map, x, y)
  if map and type(map.is_walkable) == "function" then
    return map.is_walkable(x, y)
  end
  if map and type(map.get_tile) == "function" then
    local tile = map.get_tile(x, y)
    return tile and tile ~= "wall" and tile ~= "#"
  end
  return false
end

function ActionsPlayer.resolve_action(player, intent, ctx)
  if not player or not intent then
    return nil
  end

  if intent.type == "wait" then
    return { type = "wait" }
  end

  if intent.type == "move" then
    local dx = intent.dx or 0
    local dy = intent.dy or 0
    if dx == 0 and dy == 0 then
      return nil
    end

    local map = ctx and ctx.map or nil
    local enemies = ctx and ctx.enemies or nil
    local target_x = player.x + dx
    local target_y = player.y + dy

    local enemy = find_enemy_at(enemies, target_x, target_y)
    if enemy then
      return {
        type = "attack",
        target = enemy,
        target_x = target_x,
        target_y = target_y,
      }
    end

    if map and is_walkable(map, target_x, target_y) then
      return {
        type = "move",
        dx = dx,
        dy = dy,
        to_x = target_x,
        to_y = target_y,
      }
    end

    return nil
  end

  return nil
end

function ActionsPlayer.process_input(ctx)
  ctx = ctx or {}
  local tm = ctx.turn_manager
  if not tm and TurnManager and TurnManager.get_state and TurnManager.get_state().initialized then
    tm = TurnManager
  end

  if tm and type(tm.is_player_turn) == "function" then
    if not tm.is_player_turn() then
      return { action = nil, consumed = false, reason = "not_player_turn" }
    end
    if tm.get_state and tm.get_state().has_pending_action then
      return { action = nil, consumed = false, reason = "pending_action" }
    end
  end

  local intent = Input.poll(ctx.input or ctx.input_state or ctx)
  if not intent then
    return { action = nil, consumed = false, reason = "no_input" }
  end

  local action = ActionsPlayer.resolve_action(ctx.player, intent, ctx)
  if not action then
    return { action = nil, consumed = false, reason = "illegal" }
  end

  if tm and type(tm.submit_action) == "function" then
    local ok = tm.submit_action(action)
    return { action = ok and action or nil, consumed = ok or false, reason = ok and "submitted" or "rejected" }
  end

  return { action = action, consumed = true, reason = "resolved" }
end

return ActionsPlayer
