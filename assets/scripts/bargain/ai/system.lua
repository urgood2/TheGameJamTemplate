-- assets/scripts/bargain/ai/system.lua

local combat = require("bargain.sim.combat")
local events = require("bargain.sim.events")
local victory = require("bargain.victory")
local death = require("bargain.death")
local constants = require("bargain.sim.constants")
local chase = require("bargain.ai.chase")
local ordering = require("bargain.ai.ordering")
local boss_ai = require("bargain.enemies.boss")

local ai = {}

local function get_player(world)
    if not world.entities or not world.entities.by_id then
        return nil
    end
    return world.entities.by_id[world.player_id]
end

function ai.order_enemies(world)
    return ordering.enemy_order(world)
end

function ai.choose_action(world, enemy_id)
    local enemy = world.entities.by_id[enemy_id]
    local player = get_player(world)
    if not enemy or not player then
        return { type = "wait" }
    end
    if enemy.is_boss or enemy.behavior == "boss" then
        return boss_ai.choose_action(world, enemy, player)
    end
    return chase.choose_action(world, enemy, player)
end

function ai.step_enemy(world, enemy_id)
    local enemy = world.entities.by_id[enemy_id]
    if not enemy or (enemy.hp or 0) <= 0 then
        return nil
    end

    local action = ai.choose_action(world, enemy_id)
    if action.type == "attack" then
        combat.apply_attack(world, enemy_id, action.target_id)
    elseif action.type == "chase" then
        local from_x = enemy.pos.x
        local from_y = enemy.pos.y
        enemy.pos.x = enemy.pos.x + action.dx
        enemy.pos.y = enemy.pos.y + action.dy
        events.emit(world, {
            type = "move",
            entity_id = enemy_id,
            from = { x = from_x, y = from_y },
            to = { x = enemy.pos.x, y = enemy.pos.y },
        })
    end

    death.check(world)
    victory.check(world)

    return action
end

function ai.step_enemies(world)
    local ordered = ai.order_enemies(world)
    local actions = {}
    for _, enemy_id in ipairs(ordered) do
        local action = ai.step_enemy(world, enemy_id)
        if action then
            actions[#actions + 1] = { id = enemy_id, action = action }
        end
        if world.run_state ~= constants.RUN_STATES.RUNNING then
            break
        end
    end
    return actions
end

return ai
