-- assets/scripts/bargain/scripts/s1.lua

return {
    id = "S1",
    description = "Basic run with move, attack, and wait.",
    setup = function(world)
        local spawn = require("bargain.enemies.spawn")
        local boss = require("bargain.enemies.boss")
        world.floor_num = 7

        local player = world.entities.by_id[world.player_id]
        player.pos.x = 1
        player.pos.y = 1

        local enemy = spawn.create_enemy(world, "rat", { x = 1, y = 2 })
        if enemy then
            enemy.hp = 1
        end

        local b = boss.spawn(world, { x = 2, y = 2 })
        if b then
            b.hp = 0
        end
    end,
    inputs = {
        { type = "move", dx = 1, dy = 0 },
        { type = "attack", dx = 0, dy = 1 },
        { type = "wait" },
    },
}
